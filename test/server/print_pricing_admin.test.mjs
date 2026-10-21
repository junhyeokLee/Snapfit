import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {createPrintPricingAdminHandler} from '../../supabase/functions/_shared/print-pricing-admin.ts'
const actor='11111111-1111-4111-8111-111111111111',version='22222222-2222-4222-8222-222222222222'
const metrics={retailPrice:49900,shippingBudget:3500,packagingBudget:0,paymentFeeReserve:2495,reprintReserve:2495,operationsReserve:3000,estimatedContribution:17180,contributionRate:17180/49900}
const row={productId:'REDP_200_SOFT',productName:'discard supplied name',pageCount:20,coverType:'SOFT',source:{revision:'a'.repeat(64),supplyPrice:19300,vatPrice:1930,totalPrice:21230,
 currency:'KRW',source:'WEBSITE',observedAt:'2026-10-19T00:00:00Z',evidence:'Synthetic fixture evidence',options:{coverPaper:'ART300',coverFinish:'matte',interiorPaper:'Glossy285',interiorPrint:'duplex',apiSecret:'never-forward'}},
 recommended:metrics,effective:{...metrics,priceVersion:'PRINT_PLANNED_V1',retailPriceStatus:'PLANNED'},override:null,locked:false}
const request=(body,auth='Bearer synthetic',method='POST')=>new Request('https://edge.invalid/print-pricing-admin',{method,headers:auth?{Authorization:auth}:{},...(method==='POST'?{body:typeof body==='string'?body:JSON.stringify(body)}:{})})
const save={action:'save',productId:row.productId,pageCount:20,reviewedSourceRevision:row.source.revision,expectedPriceVersion:row.effective.priceVersion,retailPrice:59900,shippingBudget:3500,packagingBudget:0,note:'Reviewed new price'}
const reset={action:'reset',productId:row.productId,pageCount:20,reviewedSourceRevision:row.source.revision,expectedPriceVersion:row.effective.priceVersion,note:'Restore recommendation'}
function fixture({role='admin',data,dbError,getUser}={}){const calls=[];let privileged=0
 const handler=createPrintPricingAdminHandler({getUser:getUser??(async()=>({id:actor,app_metadata:{role},user_metadata:{role:'admin'}})),createAdminDatabase:()=>{privileged++;return {rpc:async(name,params)=>{
  calls.push({name,params});return {data:data??(name==='read_print_pricing_admin'?[{...row,apiSecret:'never-forward',enabled:true}]:row),error:dbError??null}}}}})
 return {handler,calls,privileged:()=>privileged}
}
test('authentication and current admin authorization precede every privileged read or mutation',async()=>{
 for(const body of [{action:'overview'},save,reset]){
  const missing=fixture();assert.equal((await missing.handler(request(body,null))).status,401);assert.equal(missing.privileged(),0)
  const customer=fixture({role:'customer'});assert.equal((await customer.handler(request(body))).status,403);assert.equal(customer.privileged(),0)
  const expired=fixture({getUser:async()=>{throw Error('expired')}});assert.equal((await expired.handler(request(body))).status,401);assert.equal(expired.privileged(),0)
 }
})
test('overview passes verified actor, projects private price facts and denies server secrets and production toggles',async()=>{
 const f=fixture(),response=await f.handler(request({action:'overview'}));assert.equal(response.status,200);assert.equal(response.headers.get('Cache-Control'),'no-store')
 const result=await response.json();assert.equal(result.productionEnabled,false);assert.equal(result.canOpenSales,false);assert.equal(result.rows[0].productName,'20×20cm 소프트커버 포토북')
 assert.equal(result.rows[0].source.totalPrice,21230);assert.equal(result.rows[0].effective.estimatedContribution,17180);assert.equal(result.rows[0].source.options.apiSecret,undefined)
 assert.equal(result.rows[0].apiSecret,undefined);assert.equal(result.rows[0].enabled,undefined);assert.deepEqual(f.calls,[{name:'read_print_pricing_admin',params:{p_actor_id:actor}}])
 assert.equal(result.constants.minimumContributionRate,.2)
})
test('save and reset forward only exact-source/CAS values with verified actor and required audit reason',async()=>{
 const f=fixture();assert.equal((await f.handler(request({...save,note:'  Reviewed new price  '}))).status,200)
 assert.deepEqual(f.calls[0],{name:'mutate_print_pricing_admin',params:{p_actor_id:actor,p_action:'save',p_product_id:row.productId,p_page_count:20,p_source_revision:row.source.revision,
  p_expected_price_version:row.effective.priceVersion,p_retail_price:59900,p_shipping_budget:3500,p_packaging_budget:0,p_note:'Reviewed new price'}})
 const r=fixture();assert.equal((await r.handler(request(reset))).status,200)
 assert.equal(r.calls[0].params.p_retail_price,null);assert.equal(r.calls[0].params.p_shipping_budget,null);assert.equal(r.calls[0].params.p_packaging_budget,null)
})
test('client flags, private supplier cost, forged actor and malformed source/version/money cannot reach the database',async()=>{
 for(const extra of [{enabled:true},{productionEnabled:true},{retailFinal:true},{supplierCostConfirmed:true},{actorId:'forged'},{estimatedPrintCost:1},{apiSecret:'x'},{paymentStatus:'PAID'},
  {note:''},{note:' '.repeat(3)},{note:'x'.repeat(1001)},{retailPrice:0},{retailPrice:1.5},{retailPrice:100000001},{shippingBudget:-1},{packagingBudget:10000001},
  {reviewedSourceRevision:'bad'},{expectedPriceVersion:null},{pageCount:21},{pageCount:82},{productId:'UNKNOWN'}]){
  const f=fixture();assert.equal((await f.handler(request({...save,...extra}))).status,400,JSON.stringify(extra));assert.equal(f.privileged(),0)
 }
 const extraReset=fixture();assert.equal((await extraReset.handler(request({...reset,retailPrice:1}))).status,400);assert.equal(extraReset.privileged(),0)
})
test('invalid JSON, arrays, oversized request and unknown read actions do not allocate a privileged client',async()=>{
 for(const body of ['{','[]','null',JSON.stringify({action:'overview',extra:true}),JSON.stringify({action:'list'}),' '.repeat(8193)]){
  const f=fixture();assert.equal((await f.handler(request(body))).status,400);assert.equal(f.privileged(),0)
 }
 const f=fixture();assert.equal((await f.handler(request({},null,'OPTIONS'))).status,200);assert.equal(f.privileged(),0)
 assert.equal((await f.handler(request({},'Bearer synthetic','GET'))).status,405)
})
test('stale override remains visible beside recommendation and effective price with no automatic reapproval',async()=>{
 const f=fixture({data:[{...row,override:{version,sourceRevision:'b'.repeat(64),retailPrice:59900,shippingBudget:4000,packagingBudget:500,note:'Old source price',
  updatedAt:'2026-10-19T00:00:00Z',updatedBy:actor,stale:true}}]})
 const response=await (await f.handler(request({action:'overview'}))).json();assert.equal(response.rows[0].override.stale,true);assert.equal(response.rows[0].effective.retailPrice,49900)
 assert.equal(response.rows[0].override.retailPrice,59900);assert.equal(response.canOpenSales,false)
})
test('RPC conflicts and safe validation errors preserve specific actionable codes; database details are never returned',async()=>{
 for(const [code,status]of [['print_pricing_conflict',409],['print_pricing_source_changed',409],['print_pricing_locked',409],['print_pricing_margin_too_low',400],['invalid_print_pricing',400],
  ['print_pricing_source_unavailable',404],['forbidden',403],['internal secret failure',503]]){
  const f=fixture({dbError:{message:code,details:'private SQL context',hint:'private hint'}}),response=await f.handler(request(save))
  assert.equal(response.status,status);assert.deepEqual(await response.json(),{error:status===503?'print_pricing_unavailable':code})
 }
})
test('malformed stored records fail closed rather than suggesting success, FINAL approval or a zero price',async()=>{
 for(const corrupt of [{...row,effective:{...row.effective,retailPrice:0}},{...row,source:{...row.source,totalPrice:21231}},{...row,locked:true},
  {...row,effective:{...row.effective,retailPriceStatus:'PENDING'}},{...row,source:{...row.source,revision:'x'}},{...row,recommended:{...metrics,contributionRate:null}}]){
  const f=fixture({data:[corrupt]}),response=await f.handler(request({action:'overview'}));assert.equal(response.status,503);assert.deepEqual(await response.json(),{error:'print_pricing_unavailable'})
 }
})
test('Edge entry point has no supplier/payment clients and preserves JWT gateway with explicit Auth role guard',()=>{
 const wrapper=readFileSync(new URL('../../supabase/functions/print-pricing-admin/index.ts',import.meta.url),'utf8')
 assert.match(wrapper,/createPrintPricingAdminHandler/);assert.doesNotMatch(wrapper,/PortOne|fetch\(|redprinting-client|payment-confirm|Deno\.env/)
 const config=readFileSync(new URL('../../supabase/config.toml',import.meta.url),'utf8');assert.match(config,/\[functions\.print-pricing-admin\][\s\S]*?verify_jwt = true/)
})

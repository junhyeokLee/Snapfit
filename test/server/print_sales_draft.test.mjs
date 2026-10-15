import assert from 'node:assert/strict'
import {test} from 'node:test'
import {createPrintSalesDraftHandler,printDraftContribution} from '../../supabase/functions/_shared/print-sales-draft.ts'
const actor='11111111-1111-4111-8111-111111111111',version='22222222-2222-4222-8222-222222222222',now='2026-10-14T00:00:00Z'
const row={productId:'REDP_200X150_SOFT',pageCount:20,observedPrintCost:21230,observedAt:now,sourceRevision:'a'.repeat(64),locked:false,draft:null}
const request=b=>new Request('https://edge.invalid',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify(b)})
const save={action:'save',productId:row.productId,pageCount:20,reviewedSourceRevision:row.sourceRevision,expectedDraftVersion:null,retailPrice:49900,shippingBudget:3500,packagingBudget:500,note:'synthetic draft'}
function fixture(role='admin'){const calls=[];let privileged=0
 const deps={getUser:async()=>({id:actor,app_metadata:{role},user_metadata:{role:'admin'}}),createAdminDatabase:()=>{privileged++;return {rpc:async(name,p)=>{
  calls.push({name,p});return {data:name==='read_print_sales_draft_candidates'?[{...row,apiSecret:'private-secret',actualApproval:true,orderCode:'private-code'}]:
    {...row,draft:{version,retailPrice:49900,shippingBudget:3500,packagingBudget:500,estimatedContribution:16680,note:'synthetic draft',sourceRevision:'b'.repeat(64),updatedAt:now}},error:null}}}}}
 return {handler:createPrintSalesDraftHandler(deps),calls,privileged:()=>privileged}
}
test('draft API requires a signed current admin before privileged DB; body approvals cannot authorize it',async()=>{
 const f=fixture('customer');assert.equal((await f.handler(request({action:'overview'}))).status,403);assert.equal(f.privileged(),0)
 const admin=fixture();assert.equal((await admin.handler(new Request('https://edge.invalid',{method:'POST',body:'{}',headers:{'x-admin-key':'synthetic'}}))).status,401)
 assert.equal(admin.privileged(),0)
})
test('draft overview projects approved development cost without secrets and never claims sales opening',async()=>{
 const f=fixture(),r=await (await f.handler(request({action:'overview'}))).json()
 assert.equal(r.productionEnabled,false);assert.equal(r.canOpenSales,false);assert.equal(r.candidates[0].defaultRetailPrice,49900)
 assert.equal(r.candidates[0].apiSecret,undefined);assert.equal(r.candidates[0].orderCode,undefined);assert.equal(r.candidates[0].actualApproval,undefined)
 assert.equal(r.paymentFeeRate,.05);assert.equal(r.minimumContribution,10000)
})
test('save forwards only draft budgets and source/version CAS; stale source draft remains visible',async()=>{
 const f=fixture(),response=await f.handler(request(save));assert.equal(response.status,200)
 const r=await response.json();assert.equal(r.candidate.sourceRevision,'a'.repeat(64));assert.equal(r.candidate.draft.sourceRevision,'b'.repeat(64))
 assert.equal(r.canOpenSales,false);assert.deepEqual(f.calls[0].p,{p_product_id:row.productId,p_page_count:20,p_source_revision:row.sourceRevision,p_expected_version:null,
  p_retail_price:49900,p_shipping_budget:3500,p_packaging_budget:500,p_note:'synthetic draft'})
})
test('global flags, credentials, client supplier costs, PAID evidence and approval booleans are not writable',async()=>{
 for(const extra of [{businessReady:true},{enabled:true},{sampleApproved:true},{apiSecret:'fake'},{supplierPrintCost:1},{status:'PAID'},{paymentReceipt:{}}]){
  const f=fixture();assert.equal((await f.handler(request({...save,...extra}))).status,400);assert.equal(f.privileged(),0)}
 for(const changes of [{expectedDraftVersion:undefined},{retailPrice:1.5},{shippingBudget:-1},{reviewedSourceRevision:'bad'},{pageCount:21}]){
  const f=fixture();assert.equal((await f.handler(request({...save,...changes}))).status,400);assert.equal(f.privileged(),0)}
})
test('known source/version/locked conflicts are safe and preserve input instead of faking save success',async()=>{
 for(const code of ['print_sales_draft_locked','print_sales_draft_conflict','print_sales_draft_source_changed']){
  const h=createPrintSalesDraftHandler({getUser:async()=>({id:actor,app_metadata:{role:'admin'}}),createAdminDatabase:()=>({rpc:async()=>({data:null,error:{code:'23514',message:code,details:'private'}})})})
  const r=await h(request(save));assert.equal(r.status,409);assert.deepEqual(await r.json(),{error:code})}
})
test('integer 5 percent reserve matches SQL and Dart without binary floating rounding, including low-margin budgets',()=>{
 assert.equal(printDraftContribution(49900,21230,3500,500),16680)
 assert.equal(printDraftContribution(159900,101860,3500,500),35050)
 assert.equal(printDraftContribution(69900,21230,3500,500),34680)
 assert.equal(printDraftContribution(49901,21230,3500,500),16679)
 assert.ok(printDraftContribution(21230,21230,3500,500)<10000)
})

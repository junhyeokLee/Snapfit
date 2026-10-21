import assert from 'node:assert/strict'
import {test} from 'node:test'
import {createProductionPrintCheckoutHandler,printCheckoutRevision,printCheckoutSpecRevision,canonicalPrintReview,reconcileProductionPrintPayment} from '../../supabase/functions/_shared/production-print-checkout.ts'
import {PortOnePrintPaymentError,queryPortOnePrintPaymentState} from '../../supabase/functions/_shared/portone-print-payment.ts'
import {printCheckoutConsent} from '../../supabase/functions/_shared/print-checkout-consent.ts'
const owner='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',requestId='33333333-3333-4333-8333-333333333333'
const product={id:'REDP_200X150_SOFT',trimWidthMm:200,trimHeightMm:150}
const spec={id:product.id,verified:true,specVersion:'SYNTHETIC_APPROVED_V1',coverType:'SOFT',pageCount:20,dpi:300,colorSpace:'sRGB',layoutFit:'contain',minimumPhotoPpi:150,
  minInteriorPages:20,maxInteriorPages:80,pageMultiple:2,spineMm:7.22,interior:{trimWidthMm:200,trimHeightMm:150,bleedMm:5},
  cover:{widthMm:417.22,heightMm:160,back:{xMm:5,yMm:5,widthMm:200,heightMm:150},front:{xMm:212.22,yMm:5,widthMm:200,heightMm:150}}}
const costs={estimatedPrintCost:21230,estimatedShippingCost:3500,estimatedPackagingCost:500,paymentFeeRate:.04,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000}
const recipient={name:'테스트',phone:'01000000000',zipCode:'12345',addressLine1:'테스트 주소',addressLine2:'',deliveryMemo:''}
const config={enabled:true,environment:'live',storeId:'store-synthetic-live',channelKey:'channel-key-synthetic-live',apiSecret:'synthetic-server-only-secret',supabaseUrl:'https://synthetic-project.supabase.co'}
const snapshot={album:{id:1,owner_id:owner,title:'synthetic album',ratio:'4:3',cover_theme:null,cover_layers_json:JSON.stringify({printProduct:product,pages:Array.from({length:20},(_,index)=>({index,isCover:index===0,layers:[]}))})},pages:[]}
const quote={pageCount:20,amount:49900,sourcePageCount:19,addedBlankPageCount:1,productCode:product.id,printProduct:product,pricingVersion:'PRINT_REDP_COVERTYPE_V3',pricePolicyVersion:'SYNTHETIC_FINAL_V1',retailPriceStatus:'FINAL',priceIsEstimate:false,spec}
const paidReceipt=i=>({provider:'PORTONE',version:'V2',status:'PAID',paymentId:i.payment_id,transactionId:`tx_${i.payment_id}`,storeId:i.store_id,channelKey:i.channel_key,amount:i.amount,
  paidAmount:i.amount,discountAmount:0,currency:'KRW',paidAt:'2026-10-14T00:00:00Z',environment:'live',isTest:false})
function fixture(overrides={}){
  const ctx={snapshot:structuredClone(snapshot),sourceDigest:'a'.repeat(64),quote:structuredClone(quote),canPay:true,configuration:{store_id:config.storeId,channel_key:config.channelKey},
    combination:{approved_spec:structuredClone(spec),cost_snapshot:structuredClone(costs)},allowedAssetOwners:[owner]},rows=[],calls=[]
  let commits=0
  const db={async rpc(name,p){calls.push({name,p})
    if(name==='load_owned_print_checkout_context')return p.p_actor===owner&&p.p_album_id===1?{data:ctx,error:null}:{data:null,error:{code:'42501',message:'album_access_denied'}}
    if(name==='get_owned_print_checkout'||name==='get_owned_print_checkout_by_order'){
      const i=rows.find(v=>v.user_id===p.p_actor&&(p.p_payment_id===v.payment_id||p.p_request_id===v.request_id||p.p_order_id===v.order_id))
      return i?{data:{...structuredClone(i),launch_ready:ctx.canPay},error:null}:{data:null,error:{code:'P0002',message:'print_checkout_not_found'}}
    }
    if(name==='record_print_checkout_consent'){assert.deepEqual(p.p_consent,printCheckoutConsent);return{data:true,error:null}}
    if(name==='prepare_production_print_checkout_with_consent'){
      assert.deepEqual(p.p_consent,printCheckoutConsent)
      const i={id:'55555555-5555-4555-8555-555555555555',user_id:p.p_actor,request_id:p.p_request_id,payment_id:'SFP_55555555-5555-4555-8555-555555555555',order_id:'ordp_55555555-5555-4555-8555-555555555555',
        album_id:p.p_album_id,amount:p.p_expected_amount,page_count:p.p_page_count,environment:'live',currency:'KRW',store_id:config.storeId,channel_key:config.channelKey,status:'PREPARED',
        expires_at:'2026-10-15T00:00:00Z',reviewed_revision:p.p_reviewed_revision,reviewed_spec_revision:p.p_reviewed_spec_revision,delivery_snapshot:p.p_recipient,payment_receipt:null,verified_at:null,print_file_source:'APP_UPLOADED',prepayment_package_ready:false,prepayment_package_id:null,sdk_issued_at:null}
      rows.push(i);return{data:structuredClone(i),error:null}
    }
    if(name==='authorize_print_app_pdf_checkout'){const i=rows.find(v=>v.user_id===p.p_actor&&v.payment_id===p.p_payment_id);assert.equal(i.prepayment_package_ready,true);i.sdk_issued_at='2026-10-14T00:00:00Z';return{data:{...structuredClone(i),launch_ready:ctx.canPay},error:null}}
    assert.equal(name,'commit_production_print_payment');commits++
    const i=rows.find(v=>v.payment_id===p.p_payment_id&&v.user_id===p.p_actor);i.status=p.p_unpaid?(p.p_receipt.status==='FAILED'?'FAILED':'CANCELED'):'PAID';i.payment_receipt=p.p_receipt;i.verified_at='2026-10-14T00:01:00Z'
    return{data:structuredClone(i),error:null}
  }}
  const deps={getUser:async()=>{calls.push('getUser');return{id:owner}},createAdminDatabase:()=>{calls.push('db');return db},configuration:()=>{calls.push('config');return{...config}},
    queryPayment:async e=>{calls.push({lookup:e});return{kind:'paid',receipt:paidReceipt(rows.find(i=>i.payment_id===e.paymentId))}},now:()=>Date.parse('2026-10-14T00:00:00Z'),...overrides}
  return{handler:createProductionPrintCheckoutHandler(deps),confirm:createProductionPrintCheckoutHandler(deps,true),deps,db,ctx,rows,calls,get commits(){return commits}}
}
const request=(body,auth='Bearer synthetic-user')=>new Request('https://example.invalid/checkout',{method:'POST',headers:auth?{authorization:auth}:{},body:JSON.stringify(body)})
const result=async promise=>{const r=await promise;return{status:r.status,body:await r.json()}}
const prepareBody=async(f,changes={})=>({action:'prepare',albumId:1,requestId,expectedAmount:49900,reviewedRevision:await printCheckoutRevision(f.ctx.snapshot),reviewedSpecRevision:await printCheckoutSpecRevision(f.ctx.quote.spec),recipient,consent:{...printCheckoutConsent},...changes})
const prepare=async(f,changes={})=>result(f.handler(request(await prepareBody(f,changes))))

test('separate policy and custom-production consent must be affirmative and exactly versioned before any privileged checkout read',async()=>{
 for(const consent of [undefined,null,{},[],{...printCheckoutConsent,policyAccepted:false},{...printCheckoutConsent,orderReviewed:false},
  {...printCheckoutConsent,customProductionAccepted:false},{...printCheckoutConsent,policyVersion:'old'},
  {...printCheckoutConsent,customProductionNotice:'no refunds'},{...printCheckoutConsent,acceptedAt:'forged-client-time'}]){
  const f=fixture();const response=await prepare(f,{consent});assert.equal(response.status,400);assert.equal(response.body.error,'print_checkout_consent_required');
  assert.equal(f.calls.includes('db'),false);assert.equal(f.rows.length,0)
 }
})

test('Dart/JS reviewed source has the same stable IEEE754 SHA256; numeric types normalize without losing precision',async()=>{
  const cover={pages:[{index:0,layers:[{x:1,y:.125,rotation:0,text:'숫자 · emoji 🖼',nested:{z:Math.PI,a:1}}]}]}
  const s={album:{id:9,title:'여행 기록',cover_layers_json:JSON.stringify(cover)},pages:[]}
  assert.equal(await printCheckoutRevision(s),'5e92bae5e676a7bae1356194370ced6b69aa5d74780b30544e8d94761781419e')
  assert.deepEqual(canonicalPrintReview(1),canonicalPrintReview(1.0));assert.notDeepEqual(canonicalPrintReview(1),canonicalPrintReview(1.0000000000000002))
  const reordered={album:{cover_layers_json:JSON.stringify({pages:cover.pages}),title:'여행 기록',id:9},pages:[]}
  assert.equal(await printCheckoutRevision(s),await printCheckoutRevision(reordered))
})
test('unauthorized, malformed or forged callbacks cannot read private configuration or advance a payment',async()=>{
  for(const [override,auth]of [[{},null],[{getUser:async()=>null},'Bearer stale']]){const f=fixture(override),r=await result(f.handler(request({action:'readiness',albumId:1},auth)));assert.equal(r.status,401);assert.equal(f.calls.includes('db'),false);assert.equal(f.calls.includes('config'),false)}
  const f=fixture();for(const b of [{action:'prepare',albumId:1,userId:other},{action:'status',paymentId:'SFPGT_55555555-5555-4555-8555-555555555555'},{action:'status',requestId,paymentId:'SFP_55555555-5555-4555-8555-555555555555'}])assert.equal((await result(f.handler(request(b)))).status,400)
  assert.equal((await result(f.confirm(request({paymentId:'SFP_55555555-5555-4555-8555-555555555555',success:true,paid:true,amount:1})))).status,400);assert.equal(f.commits,0)
})
test('ready public quotation requires FINAL exact geometry, profitable costs, supported source and LIVE server config',async()=>{
  const f=fixture();const r=await result(f.handler(request({action:'readiness',albumId:1})));assert.equal(r.body.canPay,true);assert.equal(r.body.quote.spec.verified,true)
  assert.doesNotMatch(JSON.stringify(r.body),/synthetic-server-only-secret|cost_snapshot|estimatedPrintCost|store_id|channel_key|owner_id/)
  for(const mutate of [x=>{x.ctx.canPay=false},x=>{x.ctx.quote.retailPriceStatus='PLANNED'},x=>{x.ctx.quote.amount=0;x.ctx.quote.retailPriceStatus='PENDING_SUPPLIER_QUOTE'},
    x=>{x.ctx.combination.approved_spec.interior.bleedMm=0},x=>{x.ctx.combination.cost_snapshot.estimatedPrintCost=49000},
    x=>{x.ctx.snapshot.album.cover_layers_json=JSON.stringify({imageUrl:'https://external.invalid/photo.jpg'})}]){
    const item=fixture();mutate(item);const response=await result(item.handler(request({action:'readiness',albumId:1})));assert.equal(response.status,200);assert.equal(response.body.canPay,false);assert.equal(response.body.status,'PREPARING')
  }
  for(const cfg of [{...config,enabled:false},{...config,environment:'test'},{...config,channelKey:'channel-key-34782ac7-e644-4234-ad27-2767b6904f88'}]){
    const item=fixture({configuration:()=>cfg});assert.equal((await result(item.handler(request({action:'readiness',albumId:1})))).body.canPay,false);assert.equal((await prepare(item)).status,409);assert.equal(item.rows.length,0)
  }
})
test('public spec keeps exact geometry while removing private nested approval/cost/source notes',async()=>{
  const f=fixture()
  f.ctx.quote.printProduct={...f.ctx.quote.printProduct,supplierOrderCode:'private-code',approval:{secret:'private-token'}}
  f.ctx.quote.spec={...f.ctx.quote.spec,coverType:'HARD',geometrySource:'private operator correspondence',approval_evidence:'private evidence',costSnapshot:{supplierCost:999},
    interior:{...f.ctx.quote.spec.interior,sourceURL:'https://private.invalid'},cover:{...f.ctx.quote.spec.cover,approval:{privateSecret:'private-token'},front:{...f.ctx.quote.spec.cover.front,operatorPrivate:'private-token'}},
    reviewRequired:[{privateSecret:'private-token'},'private operator notes','physical_sample']}
  const response=await result(f.handler(request({action:'readiness',albumId:1}))),s=response.body.quote.spec
  assert.equal(s.geometrySource,'승인된 공식 표지 템플릿');assert.equal(s.cover.front.xMm,212.22);assert.deepEqual(s.reviewRequired,[])
  assert.doesNotMatch(JSON.stringify(s),/private|supplierCost|sourceURL|approval_evidence|costSnapshot/)
  assert.doesNotMatch(JSON.stringify(response.body.quote.printProduct),/private|supplierOrderCode|approval/)
  assert.equal(response.body.reviewedSpecRevision,await printCheckoutSpecRevision(s))
})
test('prepare persists authoritative expectations, recovers the same UUID after response loss, rejects address/amount/revision changes',async()=>{
  const f=fixture(),first=await prepare(f);assert.equal(first.status,200);assert.equal(first.body.sdkRequest,null);assert.equal(first.body.printPackageReady,false);assert.equal(first.body.environment,'production');assert.equal(first.body.verifiedPaid,false)
  assert.deepEqual(first.body.recipient,recipient);assert.equal(f.rows.length,1)
  const replay=await prepare(f);assert.equal(replay.body.paymentId,first.body.paymentId);assert.equal(replay.body.sdkRequest,null);assert.equal(f.rows.length,1)
  f.rows[0].prepayment_package_ready=true;f.rows[0].prepayment_package_id='66666666-6666-4666-8666-666666666666';
  const ready=await prepare(f);assert.equal(ready.body.paymentId,first.body.paymentId);assert.equal(ready.body.sdkRequest.status,'READY');assert.equal(ready.body.printPackageReady,true)
  for(const change of [{recipient:{...recipient,addressLine1:'changed'}},{expectedAmount:1},{reviewedRevision:'b'.repeat(64)},{reviewedSpecRevision:'b'.repeat(64)}])assert.equal((await prepare(f,change)).status,409)
  const recovered=await result(f.handler(request({action:'status',requestId})));assert.equal(recovered.body.paymentId,first.body.paymentId);assert.equal(recovered.body.sdkRequest,null)
  f.ctx.canPay=false;assert.equal((await prepare(f)).body.sdkRequest,null)
  const owned=fixture({getUser:async()=>({id:other})});assert.equal((await result(owned.handler(request({action:'readiness',albumId:1})))).status,403)
})
test('source revision/page count/quote mismatches prevent a charge before an invoice is stored',async()=>{
  for(const change of [{reviewedRevision:'b'.repeat(64)},{reviewedSpecRevision:'b'.repeat(64)},{expectedAmount:1},{pageCount:22}]){const f=fixture();assert.equal((await prepare(f,change)).status,409);assert.equal(f.rows.length,0)}
})
test('order-history recovery on another device reads the owned frozen invoice without SDK, provider or mutation',async()=>{
  const f=fixture(),invoice=(await prepare(f)).body
  const start=f.calls.length
  const recovered=await result(f.handler(request({action:'status',orderId:invoice.orderId})))
  assert.equal(recovered.status,200);assert.equal(recovered.body.orderId,invoice.orderId)
  assert.equal(recovered.body.paymentId,invoice.paymentId);assert.equal(recovered.body.requestId,requestId)
  assert.equal(recovered.body.sdkRequest,null);assert.deepEqual(recovered.body.recipient,recipient)
  assert.deepEqual(f.calls.slice(start).filter(call=>call?.name),[{name:'get_owned_print_checkout_by_order',p:{p_actor:owner,p_order_id:invoice.orderId}}])
  assert.equal(f.calls.slice(start).some(call=>call?.lookup),false);assert.equal(f.commits,0)
  assert.equal((await result(f.handler(request({action:'status',orderId:invoice.orderId,paymentId:invoice.paymentId})))).status,400)
  assert.equal((await result(f.handler(request({action:'status',orderId:'ordp_invalid'})))).status,400)
  f.deps.getUser=async()=>({id:other})
  const unrelated=createProductionPrintCheckoutHandler(f.deps)
  assert.equal((await result(unrelated(request({action:'status',orderId:invoice.orderId})))).status,404)
})
test('provider LIVE PAID readback commits once and survives duplicate confirmations without SDK callback proof',async()=>{
  const f=fixture(),p=(await prepare(f)).body,r=await result(f.confirm(request({paymentId:p.paymentId})));assert.equal(r.body.verifiedPaid,true);assert.equal(r.body.status,'PAYMENT_COMPLETED');assert.equal(f.commits,1)
  const second=await result(f.confirm(request({paymentId:p.paymentId})));assert.equal(second.body.verifiedPaid,true);assert.equal(f.commits,1)
  assert.deepEqual(f.calls.find(c=>c.lookup).lookup,{paymentId:p.paymentId,storeId:config.storeId,channelKey:config.channelKey,amount:49900,currency:'KRW',environment:'live'})
})
test('stopping new sales preserves GET-only recovery of an already charged frozen LIVE invoice',async()=>{
  const f=fixture(),p=(await prepare(f)).body
  const i=await reconcileProductionPrintPayment(f.db,{...config,enabled:false},{userId:owner,paymentId:p.paymentId},undefined,f.deps.queryPayment)
  assert.equal(i.status,'PAID');assert.equal(f.commits,1)
})
test('TEST receipt, unknown response, timeout and 404 do not create paid/unpaid completion or release the original payment ID',async()=>{
  for(const queryPayment of [async()=>({kind:'unknown'}),async()=>{throw new PortOnePrintPaymentError('payment_not_found',404,true)},async()=>{throw new PortOnePrintPaymentError('payment_lookup_timeout',503,true)},
    async e=>({kind:'paid',receipt:{...paidReceipt({payment_id:e.paymentId,store_id:e.storeId,channel_key:e.channelKey,amount:e.amount}),isTest:true,environment:'test'}})]){
    const f=fixture({queryPayment}),p=(await prepare(f)).body,r=await result(f.confirm(request({paymentId:p.paymentId})));assert.notEqual(r.body.verifiedPaid,true);assert.notEqual(r.body.verifiedUnpaid,true);assert.equal(f.commits,0)
    assert.equal((await result(f.handler(request({action:'status',requestId})))).body.paymentId,p.paymentId)
  }
})
test('authoritative FAILED/full CANCELLED terminal observations allow a fresh checkout; closure/expiry alone never does',async()=>{
  for(const status of ['FAILED','CANCELLED']){
    const f=fixture({queryPayment:async e=>({kind:'verified_unpaid',receipt:{...paidReceipt({payment_id:e.paymentId,store_id:e.storeId,channel_key:e.channelKey,amount:e.amount}),status,
      paidAmount:status==='FAILED'?0:49900,cancelledAmount:status==='FAILED'?0:49900,verifiedUnpaid:true}})})
    const p=(await prepare(f)).body,r=await result(f.confirm(request({paymentId:p.paymentId})));assert.equal(r.body.verifiedUnpaid,true);assert.equal(r.body.verifiedPaid,false);assert.equal(r.body.sdkRequest,null)
  }
})
test('PortOne terminal observer requires exact route and proven zero/full-refund amounts',async()=>{
  const expected={paymentId:'SFP_55555555-5555-4555-8555-555555555555',storeId:config.storeId,channelKey:config.channelKey,amount:49900,currency:'KRW',environment:'live'}
  const provider={id:expected.paymentId,transactionId:'synthetic-tx',storeId:expected.storeId,version:'V2',channel:{key:expected.channelKey,type:'LIVE'},currency:'KRW',status:'FAILED',amount:{total:49900,paid:0,cancelled:0}}
  const lookup=p=>queryPortOnePrintPaymentState(expected,{apiSecret:config.apiSecret,fetcher:async()=>Response.json(p)})
  assert.equal((await lookup(provider)).kind,'verified_unpaid')
  assert.equal((await lookup({...provider,status:'CANCELLED',amount:{total:49900,paid:49900,cancelled:49900}})).kind,'verified_unpaid')
  for(const state of ['READY','PENDING','PAY_PENDING'])assert.equal((await lookup({...provider,status:state})).kind,'unknown')
  assert.equal((await lookup({...provider,status:'CANCELLED',amount:{total:49900,paid:49900,cancelled:20000}})).kind,'unknown')
  await assert.rejects(lookup({...provider,channel:{key:expected.channelKey,type:'TEST'}}),/payment_environment_mismatch/)
})

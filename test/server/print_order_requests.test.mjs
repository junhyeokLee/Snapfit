import assert from 'node:assert/strict'
import {test} from 'node:test'
import {createPrintOrderRequestHandler,createPrintOrderResolverHandler,resolvePrintOrderRequest} from '../../supabase/functions/_shared/print-order-request.ts'
import {requestFullPrintRefund,queryFullPrintRefund} from '../../supabase/functions/_shared/print-order-refund-provider.ts'
import {PortOnePrintPaymentError,queryPortOnePrintPaymentState} from '../../supabase/functions/_shared/portone-print-payment.ts'
import {RedprintingError} from '../../supabase/functions/_shared/redprinting.ts'
const actor='11111111-1111-4111-8111-111111111111',owner='22222222-2222-4222-8222-222222222222',rid='33333333-3333-4333-8333-333333333333',iid='44444444-4444-4444-8444-444444444444'
const pid=`SFP_${iid}`,order=`ordp_${iid}`,now='2026-10-14T00:00:00Z'
const expected={paymentId:pid,storeId:'store-synthetic',channelKey:'channel-synthetic-live',amount:49900,currency:'KRW',environment:'live'}
const paid={provider:'PORTONE',version:'V2',status:'PAID',...expected,transactionId:'tx-synthetic',paidAmount:44910,discountAmount:4990,paidAt:now,isTest:false}
const refunded={...paid,status:'CANCELLED',cancelledAmount:49900,cancelledAt:now,cancellationIds:['cancel-synthetic'],verifiedFullRefund:true};delete refunded.paidAt
const config={enabled:true,environment:'live',apiSecret:'synthetic-server-secret',vendorReady:true}
const publicRow={requestId:rid,checkoutRequestId:iid,type:'CANCEL',status:'REQUESTED',resolution:'NONE',replacementAllowed:false,orderId:order,paymentId:pid,createdAt:now,updatedAt:now}
const req=b=>new Request('https://edge.invalid',{method:'POST',headers:{Authorization:'Bearer synthetic', 'Content-Type':'application/json'},body:JSON.stringify(b)})
function fixture(changes={}){
  const calls=[];const row={...publicRow};const c={request:row,id:rid,owner,leaseUntil:now,productionStarted:false,supplierNeverAttempted:true,supplierCancelAttempted:false,pgCancelAttempted:false,
    supplierOrderNum:`SFO_${iid.replaceAll('-','')}`,supplierOrderSeq:1,intent:{id:iid,user_id:actor,payment_id:pid,store_id:expected.storeId,channel_key:expected.channelKey,
      amount:49900,currency:'KRW',environment:'live',status:'PAID',payment_receipt:paid},...changes}
  const db={rpc:async(name,p)=>{calls.push({name,p});if(name==='claim_print_order_request')return {data:c,error:null}
    if(name==='advance_print_order_request'){if(p.p_step==='PG_ATTEMPT'){c.pgCancelAttempted=true;return {data:{...row,pgAttemptId:owner},error:null}}
      if(p.p_step==='SUPPLIER_ATTEMPT'){c.supplierCancelAttempted=true;return {data:{...row,supplierAttemptId:owner},error:null}}
      if(p.p_step==='SUPPLIER_CANCELED')c.supplierCancelEvidence=p.p_evidence
      if(['WAITING','REVIEW'].includes(p.p_step))row.status=p.p_step==='WAITING'?'WAITING_PROVIDER':'REVIEW_REQUIRED'
      if(p.p_step==='PRODUCTION_REVIEW')row.status='REVIEW_REQUIRED'
      if(['REFUND','UNPAID'].includes(p.p_step)){row.status='COMPLETED';row.resolution=p.p_step==='REFUND'?'REFUNDED_FULL':'CANCELLED_UNPAID';row.replacementAllowed=true}
      return {data:{...row},error:null}}
    if(name==='commit_production_print_payment'){c.intent={...c.intent,status:p.p_unpaid?'FAILED':'PAID',payment_receipt:p.p_receipt};return {data:c.intent,error:null}}
    return {data:{...row,apiSecret:'never-public',privateCost:21230},error:null}}}
  const vendor={status:async()=>({statusCode:'PGS_07',statusCodeOrg:'PGS_03',fileProcessYn:'N',courier:'',trackingNumber:''}),cancel:async()=>{calls.push({name:'vendor-cancel'})}}
  return {c,db,vendor,calls,row}
}
test('request endpoint authenticates before privileged database; customer metadata cannot invoke resolver',async()=>{
  let privileged=0
  const deps={getUser:async()=>({id:actor,user_metadata:{role:'admin'},app_metadata:{role:'customer'}}),createAdminDatabase:()=>{privileged++;throw Error('unexpected')}}
  const h=createPrintOrderRequestHandler(deps),anonymous=new Request('https://edge.invalid',{method:'POST',body:'{}'})
  assert.equal((await h(anonymous)).status,401)
  const admin=createPrintOrderResolverHandler({...deps,configuration:()=>config,vendor:()=>({})})
  assert.equal((await admin(req({requestId:rid}))).status,403);assert.equal(privileged,0)
})
test('owned create/status supports lost-prepare selector and projects only public request fields',async()=>{
  const f=fixture(),h=createPrintOrderRequestHandler({getUser:async()=>({id:actor}),createAdminDatabase:()=>f.db})
  const res=await h(req({action:'create',requestId:rid,type:'CANCEL',checkoutRequestId:iid,reason:'주소를 바꾸려고 해요'}))
  assert.equal(res.status,200);const b=await res.json();assert.equal(b.replacementAllowed,false);assert.equal(b.checkoutRequestId,iid)
  assert.equal(b.apiSecret,undefined);assert.equal(b.privateCost,undefined)
  assert.equal(f.calls[0].p.p_actor,actor);assert.equal(f.calls[0].p.p_checkout_request_id,iid)
  for(const bad of [{action:'create',requestId:rid,type:'CANCEL',reason:'x',paymentId:pid,orderId:order},
    {action:'create',requestId:rid,type:'CANCEL',reason:'x',orderId:order,amount:1},
    {action:'status',paymentId:pid,checkoutRequestId:iid}])assert.equal((await h(req(bad))).status,400)
})
test('TEST or disabled refund runtime makes no database or provider call',async()=>{
  const f=fixture()
  assert.equal((await resolvePrintOrderRequest(f.db,{...config,environment:'test'},rid,owner,f.vendor)).enabled,false)
  assert.equal((await resolvePrintOrderRequest(f.db,{...config,enabled:false},rid,owner,f.vendor)).enabled,false)
  assert.equal(f.calls.length,0)
})
test('pending READY/404 and production start never claim refund or replacement',async()=>{
  const f=fixture({intent:{...fixture().c.intent,status:'PREPARED',payment_receipt:null}})
  const r=await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,{queryPayment:async()=>{throw new PortOnePrintPaymentError('payment_not_found',404,true)}})
  assert.equal(r.request.status,'WAITING_PROVIDER');assert.equal(r.request.replacementAllowed,false)
  assert.equal(f.calls.some(c=>c.p?.p_step==='PG_ATTEMPT'),false)
  const known=fixture({productionStarted:true}),review=await resolvePrintOrderRequest(known.db,config,rid,owner,known.vendor)
  assert.equal(review.request.status,'REVIEW_REQUIRED');assert.equal(known.calls.length,2)
})
test('unattempted supplier + fresh LIVE PAID commits full refund only after actual GET evidence',async()=>{
  const f=fixture();let lookups=0,posts=0
  const result=await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,{observeRefund:async()=>++lookups===1?null:refunded,
    observePaid:async()=>paid,refund:async(e,r,a)=>{assert.equal(e.paymentId,pid);assert.equal(r.paidAmount,44910);assert.equal(a,owner);posts++}})
  assert.equal(result.request.resolution,'REFUNDED_FULL');assert.equal(posts,1);assert.equal(lookups,2)
  assert.deepEqual(f.calls.filter(c=>c.name==='advance_print_order_request').map(c=>c.p.p_step),['PG_ATTEMPT','REFUND'])
})
test('unknown refund response persists attempt and a retry only observes GET, never re-POST',async()=>{
  const f=fixture();let posts=0
  const dep={observeRefund:async()=>null,observePaid:async()=>paid,refund:async()=>{posts++;throw new Error('uncertain')}}
  assert.equal((await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,dep)).request.status,'WAITING_PROVIDER')
  assert.equal((await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,dep)).request.status,'WAITING_PROVIDER')
  assert.equal(posts,1);assert.equal(f.calls.filter(c=>c.p?.p_step==='PG_ATTEMPT').length,1)
})
test('supplier cancellation is confirmed via exact status before refund; uncertain response never re-POSTs',async()=>{
  const f=fixture({supplierNeverAttempted:false});let cancel=0,refund=0
  f.vendor.cancel=async()=>{cancel++;throw new RedprintingError('vendor_cancel_uncertain',502,true)}
  const dep={observeRefund:async()=>null,observePaid:async()=>paid,refund:async()=>{refund++}}
  await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,dep);await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,dep)
  assert.equal(cancel,1);assert.equal(refund,0);assert.equal(f.row.status,'WAITING_PROVIDER')
  f.vendor.status=async()=>({statusCode:'PGS_01',statusCodeOrg:'PGS_02',fileProcessYn:'N',courier:'',trackingNumber:''})
  const result=await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,{...dep,observeRefund:async()=>refunded})
  assert.equal(result.request.resolution,'REFUNDED_FULL');assert.equal(cancel,1)
})
test('full cancellation POST omits amount, uses promotion-aware consistency and stable quoted idempotency key',async()=>{
  let seen
  await requestFullPrintRefund(expected,paid,owner,{apiSecret:'synthetic-server-secret',fetcher:async(url,init)=>{seen={url:String(url),init};return Response.json({cancellation:{status:'REQUESTED'}})}})
  const body=JSON.parse(seen.init.body);assert.equal(body.amount,undefined);assert.equal(body.currentCancellableAmount,49900)
  assert.equal(body.requester,'CUSTOMER');assert.equal(seen.init.headers['Idempotency-Key'],`"${owner}"`)
  assert.equal(seen.url,`https://api.portone.io/payments/${pid}/cancel`);assert.equal(seen.init.redirect,'error')
  await assert.rejects(requestFullPrintRefund({...expected,environment:'test'},paid,owner,{apiSecret:'synthetic-server-secret'}),/refund_expectation_invalid/)
})
test('refund GET requires same LIVE transaction and full succeeded cancellations, rejecting partial/forged totals',async()=>{
  const raw={id:pid,storeId:expected.storeId,transactionId:paid.transactionId,version:'V2',status:'CANCELLED',channel:{key:expected.channelKey,type:'LIVE'},currency:'KRW',
    amount:{total:49900,paid:44910,discount:4990,cancelled:49900},cancelledAt:now,cancellations:[{id:'cancel-synthetic',status:'SUCCEEDED',totalAmount:49900}]}
  const opts=v=>({apiSecret:'synthetic-server-secret',fetcher:async()=>Response.json(v)})
  assert.equal((await queryFullPrintRefund(expected,paid,opts(raw))).verifiedFullRefund,true)
  await assert.rejects(queryFullPrintRefund(expected,paid,opts({...raw,status:'PARTIAL_CANCELLED',amount:{...raw.amount,cancelled:10000}})),/refund_partial_review_required/)
  for(const forged of [{...raw,channel:{...raw.channel,type:'TEST'}},{...raw,transactionId:'different'},
    {...raw,amount:{...raw.amount,cancelled:10000}},{...raw,cancellations:[{id:'cancel-synthetic',status:'REQUESTED',totalAmount:49900}]}])
    await assert.rejects(queryFullPrintRefund(expected,paid,opts(forged)),/refund_/)
})
test('unsettled provider READY without selected channel stays UNKNOWN, preserving late-paid recovery',async()=>{
 const state=await queryPortOnePrintPaymentState(expected,{apiSecret:'synthetic-server-secret',fetcher:async()=>Response.json({id:pid,storeId:expected.storeId,version:'V2',status:'READY'})})
 assert.deepEqual(state,{kind:'unknown'})
 await assert.rejects(queryPortOnePrintPaymentState(expected,{apiSecret:'synthetic-server-secret',fetcher:async()=>Response.json({id:pid,storeId:'other',version:'V2',status:'READY'})}),/payment_identity_mismatch/)
})
test('trusted tick observes pending requests; overview is admin-only and keeps internal receipt/cost fields private',async()=>{
 const f=fixture();let factory=0
 const db={rpc:async(name,p)=>name==='list_print_order_requests'?{data:[{...publicRow,reason:'synthetic customer request',privateCost:1,apiSecret:'private'}],error:null}:
   name==='claim_print_order_request'?{data:{...f.c,owner:p.p_owner},error:null}:f.db.rpc(name,p)}
 const deps={getUser:async()=>({id:actor,app_metadata:{role:'admin'}}),createAdminDatabase:()=>{factory++;return db},configuration:()=>config,vendor:()=>f.vendor,
  observeRefund:async()=>null,observePaid:async()=>paid,refund:async()=>{throw Error('unknown')}}
 const h=createPrintOrderResolverHandler(deps)
 const overview=await (await h(req({action:'overview',orderId:order}))).json()
 assert.equal(overview.requests[0].reason,'synthetic customer request');assert.equal(overview.requests[0].privateCost,undefined);assert.equal(overview.requests[0].apiSecret,undefined)
 const tick=await (await h(req({action:'tick',limit:1}))).json();assert.equal(tick.processed,1);assert.equal(tick.waiting,1);assert.equal(tick.completed,0)
 assert.equal((await h(req({action:'tick',limit:4}))).status,400)
 const workerHandler=createPrintOrderResolverHandler({...deps,getUser:async()=>({id:actor,app_metadata:{role:'print_worker'}})})
 const before=factory;assert.equal((await workerHandler(req({action:'overview'}))).status,403);assert.equal(factory,before)
})
test('late LIVE PAID on a held prepared invoice is recorded then fully refunded without ever submitting to supplier',async()=>{
 const f=fixture({intent:{...fixture().c.intent,status:'PREPARED',payment_receipt:null}});let n=0
 const result=await resolvePrintOrderRequest(f.db,{...config,vendorReady:false},rid,owner,f.vendor,{queryPayment:async()=>({kind:'paid',receipt:paid}),
   observeRefund:async()=>++n===1?null:refunded,observePaid:async()=>paid,refund:async()=>{}})
 assert.equal(result.request.resolution,'REFUNDED_FULL')
 assert.equal(f.calls.some(c=>c.name==='commit_production_print_payment'&&c.p.p_unpaid===false),true)
 assert.equal(f.calls.some(c=>c.name==='vendor-cancel'||c.p?.p_step==='SUPPLIER_ATTEMPT'),false)
})
test('supplier production observed after held CONFIRM is sent to proof-backed tracking recovery without cancellation or refund POST',async()=>{
 const f=fixture({supplierNeverAttempted:false});let posts=0
 f.vendor.status=async()=>({statusCode:'PGS_20',statusCodeOrg:'PGS_40',fileProcessYn:'Y',courier:'',trackingNumber:''})
 f.vendor.cancel=async()=>{posts++}
 const result=await resolvePrintOrderRequest(f.db,config,rid,owner,f.vendor,{observeRefund:async()=>null,observePaid:async()=>paid,refund:async()=>{posts++}})
 assert.equal(result.request.status,'REVIEW_REQUIRED');assert.equal(result.request.replacementAllowed,false);assert.equal(posts,0)
 const patch=f.calls.find(v=>v.p?.p_step==='PRODUCTION_REVIEW')
 assert.deepEqual(patch.p.p_evidence,{orderNum:f.c.supplierOrderNum,orderSeq:1,statusCode:'PGS_20',statusCodeOrg:'PGS_40',courier:'',trackingNumber:''})
})

import { corsHeaders } from './cors.ts'
import { assertPrintWorker, PrintWorkerAuthError, type PrintWorkerUserLookup } from './print-worker-auth.ts'
import { queryPortOnePrintPayment, queryPortOnePrintPaymentState, PortOnePrintPaymentError, type ExpectedPortOnePrintPayment, type PortOnePrintPaymentObservation } from './portone-print-payment.ts'
import { queryFullPrintRefund, requestFullPrintRefund } from './print-order-refund-provider.ts'
import { RedprintingError } from './redprinting.ts'
import { supplierProgress } from './print-fulfillment-vendor.ts'
import type { PrintCancellationVendor } from './print-order-cancel-vendor.ts'

type Database={rpc(name:string,params:Record<string,unknown>):PromiseLike<{data:unknown;error:unknown}>}
export type PrintRequestConfiguration={enabled:boolean;environment:string;apiSecret:string;vendorReady:boolean}
export type PrintOrderRequestDependencies={getUser:PrintWorkerUserLookup;createAdminDatabase():Database}
export type PrintOrderResolverDependencies=PrintOrderRequestDependencies & {configuration():PrintRequestConfiguration;vendor(db:Database):PrintCancellationVendor;
  queryPayment?:typeof queryPortOnePrintPaymentState;observePaid?:typeof queryPortOnePrintPayment;observeRefund?:typeof queryFullPrintRefund;refund?:typeof requestFullPrintRefund}
class PrintOrderRequestError extends Error {constructor(readonly code:string,readonly status=409,readonly retryable=false){super(code)}}
const object=(v:unknown):Record<string,any>=>v&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,any>:{}
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v)
const paymentId=(v:unknown):v is string=>typeof v==='string'&&v.startsWith('SFP_')&&uuid(v.slice(4))
const orderId=(v:unknown):v is string=>typeof v==='string'&&v.startsWith('ordp_')&&uuid(v.slice(5))
const keys=(b:Record<string,any>,allowed:string[])=>Object.keys(b).every(k=>allowed.includes(k))
const response=(v:unknown,status=200)=>Response.json(v,{status,headers:{...corsHeaders,'Cache-Control':'no-store'}})
async function rpc(db:Database,name:string,params:Record<string,unknown>){
  const r=await db.rpc(name,params)
  if(r.error){const e=object(r.error),message=String(e.message??'')
    if(e.code==='P0002')throw new PrintOrderRequestError(message==='print_checkout_not_found'?'print_checkout_not_found':'print_order_request_not_found',404)
    if(e.code==='23505')throw new PrintOrderRequestError('print_order_request_already_exists')
    const safe=new Set(['print_order_request_conflict','print_order_request_already_exists','print_order_request_busy','print_order_request_lease_lost',
      'print_order_request_review_required','print_order_request_proof_required','print_supplier_cancel_proof_required','print_order_request_proof_conflict',
      'print_order_request_attempt_already_recorded','print_customer_request_hold'])
    if(safe.has(message))throw new PrintOrderRequestError(message,409)
    if(e.code==='22023')throw new PrintOrderRequestError('invalid_print_order_request',400)
    throw new PrintOrderRequestError('print_order_request_storage_unavailable',503,true)
  }return r.data
}
function publicRequest(raw:unknown){
  const r=object(raw)
  if(!uuid(r.requestId)||!uuid(r.checkoutRequestId)||!orderId(r.orderId)||!paymentId(r.paymentId)||!['CANCEL','REFUND','GENERAL'].includes(r.type)||
    !['REQUESTED','WAITING_PROVIDER','REVIEW_REQUIRED','COMPLETED'].includes(r.status)||!['NONE','CANCELLED_UNPAID','REFUNDED_FULL','PRE_SDK_ABORTED'].includes(r.resolution)||
    !Number.isFinite(Date.parse(r.createdAt))||!Number.isFinite(Date.parse(r.updatedAt)))throw new PrintOrderRequestError('print_order_request_record_invalid',503)
  const completed=r.status==='COMPLETED'&&['CANCELLED_UNPAID','REFUNDED_FULL','PRE_SDK_ABORTED'].includes(r.resolution)&&r.type!=='GENERAL'
  const preSdkAbortVerified=r.resolution==='PRE_SDK_ABORTED'&&r.preSdkAbortVerified===true
  const replacementAllowed=completed&&(r.resolution!=='PRE_SDK_ABORTED'||preSdkAbortVerified)
  if(r.replacementAllowed!==replacementAllowed||(r.status==='COMPLETED')!==completed||
    r.resolution==='PRE_SDK_ABORTED'&&typeof r.preSdkAbortVerified!=='boolean')throw new PrintOrderRequestError('print_order_request_record_invalid',503)
  const message=r.resolution==='REFUNDED_FULL'?'전액 환불을 확인했어요. 결제수단에 반영되는 시간은 결제사에 따라 달라요.':
    r.resolution==='CANCELLED_UNPAID'?'결제가 청구되지 않은 상태로 취소를 확인했어요.':
    r.resolution==='PRE_SDK_ABORTED'?(preSdkAbortVerified?'결제창을 열기 전 준비 주문을 취소했어요. 앨범을 수정해 새 주문을 준비할 수 있어요.':'준비 취소 후 확인된 결제 내역을 담당자가 확인해야 해요.'):
    r.status==='REVIEW_REQUIRED'?'요청을 접수했어요. 제작·결제 상태를 담당자가 확인하고 안내할게요.':
    r.status==='WAITING_PROVIDER'?'요청을 접수했어요. 업체·결제사의 처리 결과를 확인하고 있어요.':'요청을 접수했어요. 확인 후 안내할게요.'
  return {requestId:r.requestId,checkoutRequestId:r.checkoutRequestId,type:r.type,status:r.status,resolution:r.resolution,replacementAllowed,preSdkAbortVerified,orderId:r.orderId,paymentId:r.paymentId,
    createdAt:r.createdAt,updatedAt:r.updatedAt,message}
}
async function body(request:Request){const text=await request.text();if(text.length>8192)throw new PrintOrderRequestError('invalid_print_order_request',400)
  let value:unknown;try{value=JSON.parse(text)}catch{throw new PrintOrderRequestError('invalid_print_order_request',400)}
  if(!value||typeof value!=='object'||Array.isArray(value))throw new PrintOrderRequestError('invalid_print_order_request',400);return object(value)
}
async function actor(request:Request,lookup:PrintWorkerUserLookup){
  if(!/^Bearer [^\s]+$/i.test(request.headers.get('Authorization')??''))throw new PrintOrderRequestError('authentication_required',401)
  let user:Awaited<ReturnType<PrintWorkerUserLookup>>;try{user=await lookup(request)}catch{throw new PrintOrderRequestError('invalid_session',401)}
  if(!uuid(user?.id))throw new PrintOrderRequestError('invalid_session',401);return user.id
}
function selector(b:Record<string,any>,allowRequestId=false){
  const names=allowRequestId?['requestId','orderId','paymentId','checkoutRequestId']:['orderId','paymentId','checkoutRequestId']
  if(names.filter(k=>b[k]!=null).length!==1||(b.orderId!=null&&!orderId(b.orderId))||(b.paymentId!=null&&!paymentId(b.paymentId))||
    (b.checkoutRequestId!=null&&!uuid(b.checkoutRequestId))||(allowRequestId&&b.requestId!=null&&!uuid(b.requestId)))throw new PrintOrderRequestError('invalid_print_order_request',400)
  return {p_order_id:b.orderId??null,p_payment_id:b.paymentId??null,p_checkout_request_id:b.checkoutRequestId??null,...(allowRequestId?{p_request_id:b.requestId??null}:{})}
}
function errorResponse(e:unknown){
  if(e instanceof PrintOrderRequestError||e instanceof PortOnePrintPaymentError||e instanceof PrintWorkerAuthError||e instanceof RedprintingError)
    return response({error:e.code,retryable:'retryable' in e?e.retryable:false},e.status)
  return response({error:'print_order_request_unavailable',retryable:true},503)
}
export function createPrintOrderRequestHandler(deps:PrintOrderRequestDependencies){return async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  if(request.method!=='POST')return response({error:'method_not_allowed'},405)
  try{
    const user=await actor(request,deps.getUser),b=await body(request)
    if(b.action==='create'){
      if(!keys(b,['action','requestId','type','reason','orderId','paymentId','checkoutRequestId'])||!uuid(b.requestId)||!['CANCEL','REFUND','GENERAL'].includes(b.type)||
        typeof b.reason!=='string'||b.reason.trim().length<1||b.reason.trim().length>1000)throw new PrintOrderRequestError('invalid_print_order_request',400)
      const target=selector(b),db=deps.createAdminDatabase()
      return response(publicRequest(await rpc(db,'create_owned_print_order_request',{p_actor:user,p_request_id:b.requestId,p_type:b.type,p_reason:b.reason.trim(),...target})))
    }
    if(b.action==='status'&&keys(b,['action','requestId','orderId','paymentId','checkoutRequestId'])){
      const target=selector(b,true),db=deps.createAdminDatabase()
      return response(publicRequest(await rpc(db,'get_owned_print_order_request',{p_actor:user,...target})))
    }
    throw new PrintOrderRequestError('invalid_print_order_request',400)
  }catch(e){return errorResponse(e)}
}}

/**
 * Trusted, bounded resolution. Durable attempt markers precede external writes.
 * An uncertain supplier/PG write is followed only by GET, including later runs.
 * Sales closure does not prevent a refund, but TEST credentials never qualify.
 */
export async function resolvePrintOrderRequest(db:Database,config:PrintRequestConfiguration,requestId:string,owner:string,vendor:PrintCancellationVendor,
  deps:Pick<PrintOrderResolverDependencies,'queryPayment'|'observePaid'|'observeRefund'|'refund'>={}){
  if(!uuid(requestId)||!uuid(owner))throw new PrintOrderRequestError('invalid_print_order_request',400)
  if(config.enabled!==true||config.environment!=='live'||!/^[\x21-\x7e]{8,2048}$/.test(config.apiSecret))return {enabled:false,processed:false,status:'DISABLED'}
  const c=object(await rpc(db,'claim_print_order_request',{p_request_id:requestId,p_owner:owner}))
  if(c.completed===true)return {enabled:true,processed:false,request:publicRequest(c.request)}
  if(!uuid(c.id)||c.owner!==owner||!Number.isFinite(Date.parse(c.leaseUntil)))throw new PrintOrderRequestError('print_order_request_record_invalid',503)
  const advance=async(step:string,evidence:unknown={})=>rpc(db,'advance_print_order_request',{p_id:c.id,p_owner:owner,p_step:step,p_evidence:evidence})
  const wait=async(code:string,review=false)=>({enabled:true,processed:true,request:publicRequest(await advance(review?'REVIEW':'WAITING',{code}))})
  const productionReview=async(status:Awaited<ReturnType<PrintCancellationVendor['status']>>)=>({enabled:true,processed:true,
    request:publicRequest(await advance('PRODUCTION_REVIEW',{orderNum:c.supplierOrderNum,orderSeq:1,statusCode:status.statusCode,
      statusCodeOrg:status.statusCodeOrg,courier:status.courier,trackingNumber:status.trackingNumber}))})
  if(c.productionStarted===true)return wait('production_review_required',true)
  let i=object(c.intent)
  const expected:ExpectedPortOnePrintPayment={paymentId:i.payment_id,storeId:i.store_id,channelKey:i.channel_key,amount:i.amount,currency:'KRW',environment:'live'}
  if(!uuid(i.user_id)||!paymentId(i.payment_id)||i.environment!=='live'||i.currency!=='KRW'||!Number.isSafeInteger(i.amount)||i.amount<=0||
    i.channel_key==='channel-key-34782ac7-e644-4234-ad27-2767b6904f88'||typeof i.store_id!=='string'||typeof i.channel_key!=='string'||
    !['PREPARED','PAID','FAILED','CANCELED'].includes(i.status)||c.supplierOrderNum!==`SFO_${String(i.id).replaceAll('-','')}`||c.supplierOrderSeq!==1)
    return wait('payment_identity_review_required',true)
  const options={apiSecret:config.apiSecret}
  try{
    if(i.status==='PREPARED'){
      let observation:Awaited<ReturnType<typeof queryPortOnePrintPaymentState>>
      try { observation=await (deps.queryPayment??queryPortOnePrintPaymentState)(expected,options) }
      catch(error){
        if(i.print_file_source==='APP_UPLOADED'&&i.sdk_issued_at==null&&error instanceof PortOnePrintPaymentError&&error.code==='payment_not_found'&&error.status===404){
          // A 404 alone never releases money or an issued invoice. Only an
          // atomic SDK-never-issued/private-attempt check plus this fresh GET
          // may complete a preparation withdrawal, without a fake PG receipt.
          const aborted=object(await rpc(db,'abort_print_pre_sdk_request',{p_request_id:requestId,p_owner:owner,p_pg_observation:{
            provider:'PORTONE',version:'V2',status:'NOT_FOUND',paymentId:i.payment_id,storeId:i.store_id,channelKey:i.channel_key,
            amount:i.amount,currency:'KRW',environment:'live',httpStatus:404,observedAt:new Date().toISOString()}}))
          if(aborted.aborted===true)return {enabled:true,processed:true,request:publicRequest(aborted.request)}
          return wait('payment_result_pending')
        }
        throw error
      }
      if(observation.kind==='unknown')return wait('payment_result_pending')
      i=object(await rpc(db,'commit_production_print_payment',{p_actor:i.user_id,p_payment_id:i.payment_id,p_receipt:observation.receipt,p_unpaid:observation.kind==='verified_unpaid'}))
    }
    if(['FAILED','CANCELED'].includes(i.status))return {enabled:true,processed:true,request:publicRequest(await advance('UNPAID'))}
    const original=object(i.payment_receipt) as PortOnePrintPaymentObservation
    if(original.status!=='PAID'||original.environment!=='live'||original.isTest!==false)return wait('payment_identity_review_required',true)
    const refunded=await (deps.observeRefund??queryFullPrintRefund)(expected,original,options)
    if(!refunded&&!c.pgCancelAttempted){
      // Validate money before changing a supplier order, not only before PG POST.
      // Partial/refund-pending/route mismatches require operator review.
      const current=await (deps.observePaid??queryPortOnePrintPayment)(expected,options)
      if(current.transactionId!==original.transactionId||current.paidAmount!==original.paidAmount||current.discountAmount!==original.discountAmount)return wait('payment_identity_review_required',true)
    }
    if(c.supplierNeverAttempted!==true&&!c.supplierCancelEvidence){
      if(!config.vendorReady)return wait('supplier_configuration_pending')
      let status=await vendor.status(c.supplierOrderNum,1),progress=supplierProgress(status)
      if(progress.productionStarted)return productionReview(status)
      if(!progress.canceled){
        if(c.supplierCancelAttempted===true)return wait('supplier_cancel_pending')
        await advance('SUPPLIER_ATTEMPT')
        try{await vendor.cancel(c.supplierOrderNum,1)}catch(e){return wait(e instanceof RedprintingError&&e.code==='vendor_cancel_not_confirmed'?'supplier_cancel_review_required':'supplier_cancel_pending',e instanceof RedprintingError&&e.code==='vendor_cancel_not_confirmed')}
        status=await vendor.status(c.supplierOrderNum,1);progress=supplierProgress(status)
        if(progress.productionStarted)return productionReview(status)
        if(!progress.canceled)return wait('supplier_cancel_pending')
      }
      await advance('SUPPLIER_CANCELED',{orderNum:c.supplierOrderNum,orderSeq:1,statusCode:status.statusCode,statusCodeOrg:status.statusCodeOrg})
    }
    if(refunded)return {enabled:true,processed:true,request:publicRequest(await advance('REFUND',refunded))}
    if(c.pgCancelAttempted===true)return wait('payment_refund_pending')
    // Fresh PAID confirms no pending/partial cancellation before initiating a
    // first refund; the SQL step rechecks supplier/hold eligibility atomically.
    const fresh=await (deps.observePaid??queryPortOnePrintPayment)(expected,options)
    if(fresh.transactionId!==original.transactionId||fresh.paidAmount!==original.paidAmount||fresh.discountAmount!==original.discountAmount)return wait('payment_identity_review_required',true)
    const attempt=object(await advance('PG_ATTEMPT'))
    if(!uuid(attempt.pgAttemptId))throw new PrintOrderRequestError('print_order_request_record_invalid',503)
    try{await (deps.refund??requestFullPrintRefund)(expected,original,attempt.pgAttemptId,options)}catch{return wait('payment_refund_pending')}
    const observed=await (deps.observeRefund??queryFullPrintRefund)(expected,original,options)
    return observed?{enabled:true,processed:true,request:publicRequest(await advance('REFUND',observed))}:wait('payment_refund_pending')
  }catch(e){
    const uncertain=e instanceof PortOnePrintPaymentError?e.retryable||['payment_not_found','payment_not_paid'].includes(e.code):e instanceof RedprintingError?e.uncertain||e.status===404:false
    if(e instanceof PrintOrderRequestError&&e.code==='print_order_request_lease_lost')throw e
    return wait(uncertain?'provider_result_pending':'request_review_required',!uncertain)
  }
}
export function createPrintOrderResolverHandler(deps:PrintOrderResolverDependencies){return async(request:Request)=>{
  if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  if(request.method!=='POST')return response({error:'method_not_allowed'},405)
  try{const current=await assertPrintWorker(request,deps.getUser);const b=await body(request),config=deps.configuration()
    const enabled=config.enabled&&config.environment==='live'&&/^[\x21-\x7e]{8,2048}$/.test(config.apiSecret)
    if(b.action==='overview'){
      if(current.role!=='admin')throw new PrintOrderRequestError('forbidden',403)
      if(!keys(b,['action','orderId','limit'])||(b.orderId!=null&&!orderId(b.orderId))||(b.limit!=null&&(!Number.isSafeInteger(b.limit)||b.limit<1||b.limit>50)))throw new PrintOrderRequestError('invalid_print_order_request',400)
      const rows=await rpc(deps.createAdminDatabase(),'list_print_order_requests',{p_limit:b.limit??50,p_order_id:b.orderId??null,p_pending_only:false})
      if(!Array.isArray(rows))throw new PrintOrderRequestError('print_order_request_record_invalid',503)
      return response({enabled,requests:rows.map(v=>({...publicRequest(v),reason:typeof v.reason==='string'?v.reason.slice(0,1000):''}))})
    }
    if(b.action==='tick'){
      if(!keys(b,['action','limit'])||(b.limit!=null&&(!Number.isSafeInteger(b.limit)||b.limit<1||b.limit>3)))throw new PrintOrderRequestError('invalid_print_order_request',400)
      const summary={enabled,processed:0,waiting:0,completed:0,reviewRequired:0}
      if(!enabled)return response(summary)
      const db=deps.createAdminDatabase(),rows=await rpc(db,'list_print_order_requests',{p_limit:b.limit??1,p_order_id:null,p_pending_only:true})
      if(!Array.isArray(rows))throw new PrintOrderRequestError('print_order_request_record_invalid',503)
      for(const raw of rows){const row=publicRequest(raw)
        try{const result=await resolvePrintOrderRequest(db,config,row.requestId,crypto.randomUUID(),deps.vendor(db),deps)
          if(!result.processed)continue;summary.processed++
          const r=object(result.request);if(r.status==='COMPLETED')summary.completed++;else if(r.status==='REVIEW_REQUIRED')summary.reviewRequired++;else summary.waiting++
        }catch(e){if(!(e instanceof PrintOrderRequestError&&e.code==='print_order_request_busy'))throw e}}
      return response(summary)
    }
    if(!keys(b,['requestId'])||!uuid(b.requestId))throw new PrintOrderRequestError('invalid_print_order_request',400)
    const db=deps.createAdminDatabase()
    return response(await resolvePrintOrderRequest(db,config,b.requestId,crypto.randomUUID(),deps.vendor(db),deps))
  }catch(e){return errorResponse(e)}
}}

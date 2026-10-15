import { PortOnePrintPaymentError, type ExpectedPortOnePrintPayment, type PortOnePrintPaymentObservation } from './portone-print-payment.ts'

// Current primary contracts: https://developers.portone.io/api/schema/v2/openapi.json
// and https://developers.portone.io/api/rest-v2/overview (2026-10-14).
// No callback, browser flag or cancellation POST response is a refund receipt.
export type FullPrintRefund = {
  provider: 'PORTONE'; version: 'V2'; status: 'CANCELLED'; paymentId: string; transactionId: string;
  storeId: string; channelKey: string; amount: number; paidAmount: number; discountAmount: number;
  cancelledAmount: number; currency: 'KRW'; environment: 'live'; isTest: false;
  cancelledAt: string; cancellationIds: string[]; verifiedFullRefund: true;
}
type Options = { apiSecret: string; fetcher?: typeof fetch; timeoutMs?: number }
const object = (v: unknown): Record<string, any> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, any> : {}
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0
const identifier = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(v)
const timestamp = (v: unknown): v is string => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(v) && Number.isFinite(Date.parse(v))
function expectation(v: ExpectedPortOnePrintPayment, original: PortOnePrintPaymentObservation) {
  if (!identifier(v.paymentId) || !v.paymentId.startsWith('SFP_') || !identifier(v.storeId) || !identifier(v.channelKey) ||
      v.environment !== 'live' || v.currency !== 'KRW' || !integer(v.amount) || v.amount <= 0 ||
      original.provider !== 'PORTONE' || original.version !== 'V2' || original.status !== 'PAID' || original.environment !== 'live' || original.isTest !== false ||
      original.paymentId !== v.paymentId || original.storeId !== v.storeId || original.channelKey !== v.channelKey || original.amount !== v.amount ||
      !identifier(original.transactionId) || !integer(original.paidAmount) || original.paidAmount <= 0 || !integer(original.discountAmount) ||
      original.paidAmount + original.discountAmount !== v.amount) throw new PortOnePrintPaymentError('refund_expectation_invalid')
}
async function request(expected: ExpectedPortOnePrintPayment, options: Options, method: 'GET'|'POST', idempotencyKey?: string, body?: unknown) {
  if (!options || typeof options.apiSecret !== 'string' || !/^[\x21-\x7e]{8,2048}$/.test(options.apiSecret)) throw new PortOnePrintPaymentError('payment_provider_unconfigured',503)
  const timeoutMs = options.timeoutMs ?? (method === 'POST' ? 60000 : 15000)
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 60000) throw new PortOnePrintPaymentError('invalid_payment_timeout',400)
  const url = new URL(`/payments/${encodeURIComponent(expected.paymentId)}${method === 'POST'?'/cancel':''}`,'https://api.portone.io')
  if (method === 'GET') url.searchParams.set('storeId',expected.storeId)
  const controller = new AbortController(),timer = setTimeout(()=>controller.abort(),timeoutMs)
  try {
    const response = await (options.fetcher ?? fetch)(url,{method,redirect:'error',signal:controller.signal,
      headers:{Authorization:`PortOne ${options.apiSecret}`,Accept:'application/json',...(method === 'POST'?{'Content-Type':'application/json','Idempotency-Key':`"${idempotencyKey}"`}:{})},
      ...(body === undefined?{}:{body:JSON.stringify(body)})})
    if (!response.ok) {
      await response.body?.cancel().catch(()=>{})
      throw new PortOnePrintPaymentError(method==='POST'?'refund_response_uncertain':response.status===404?'payment_not_found':'payment_provider_unavailable',response.status===404?404:503,true)
    }
    const limit=1024*1024,length=response.headers.get('Content-Length')
    if (length!=null && (!/^\d+$/.test(length) || Number(length)>limit)) {await response.body?.cancel().catch(()=>{});throw new PortOnePrintPaymentError('invalid_refund_response',502,true)}
    if (!response.body) throw new PortOnePrintPaymentError('invalid_refund_response',502,true)
    const reader=response.body.getReader(),decoder=new TextDecoder('utf-8',{fatal:true});let count=0,text=''
    try {for (;;) {const c=await reader.read();if(c.done)break;count+=c.value.byteLength;if(count>limit){await reader.cancel().catch(()=>{});throw new PortOnePrintPaymentError('invalid_refund_response',502,true)}text+=decoder.decode(c.value,{stream:true})}text+=decoder.decode()}
    finally {reader.releaseLock()}
    try {return JSON.parse(text)}catch {throw new PortOnePrintPaymentError('invalid_refund_response',502,true)}
  } catch(e) {if(e instanceof PortOnePrintPaymentError)throw e;throw new PortOnePrintPaymentError(method==='POST'?'refund_response_uncertain':'payment_provider_unavailable',503,true)}
  finally {clearTimeout(timer)}
}
export async function queryFullPrintRefund(expected: ExpectedPortOnePrintPayment, original: PortOnePrintPaymentObservation, options: Options): Promise<FullPrintRefund|null> {
  expectation(expected,original)
  const p=object(await request(expected,options,'GET')),channel=object(p.channel),a=object(p.amount)
  if(p.id!==expected.paymentId || p.storeId!==expected.storeId || p.version!=='V2' || p.transactionId!==original.transactionId ||
      channel.key!==expected.channelKey || channel.type!=='LIVE' || p.currency!=='KRW') throw new PortOnePrintPaymentError('refund_identity_mismatch')
  if (!['total','paid','discount','cancelled'].every(k=>integer(a[k])) || a.total!==expected.amount || a.paid!==original.paidAmount || a.discount!==original.discountAmount) throw new PortOnePrintPaymentError('refund_amount_mismatch')
  if (p.status==='PARTIAL_CANCELLED') throw new PortOnePrintPaymentError('refund_partial_review_required')
  if (p.status!=='CANCELLED') return null
  if(a.cancelled<original.paidAmount || a.cancelled>expected.amount || !timestamp(p.cancelledAt) || !Array.isArray(p.cancellations) || !p.cancellations.length) throw new PortOnePrintPaymentError('refund_not_fully_verified')
  let sum=0;const ids:string[]=[]
  for(const raw of p.cancellations){const c=object(raw);if(c.status!=='SUCCEEDED'||!identifier(c.id)||!integer(c.totalAmount)||(c.cancelledAt!=null&&!timestamp(c.cancelledAt))||ids.includes(c.id))throw new PortOnePrintPaymentError('refund_not_fully_verified');sum+=c.totalAmount;ids.push(c.id)}
  if (!Number.isSafeInteger(sum)||sum!==a.cancelled) throw new PortOnePrintPaymentError('refund_amount_mismatch')
  return {provider:'PORTONE',version:'V2',status:'CANCELLED',paymentId:expected.paymentId,transactionId:original.transactionId,storeId:expected.storeId,
    channelKey:expected.channelKey,amount:expected.amount,paidAmount:original.paidAmount,discountAmount:original.discountAmount,cancelledAmount:a.cancelled,
    currency:'KRW',environment:'live',isTest:false,cancelledAt:p.cancelledAt,cancellationIds:ids,verifiedFullRefund:true}
}
/** Caller must have durably claimed this exact attempt and confirmed no manufacturing. Never replay after an uncertain response. */
export async function requestFullPrintRefund(expected: ExpectedPortOnePrintPayment, original: PortOnePrintPaymentObservation, attemptId: string, options: Options): Promise<void> {
  expectation(expected,original)
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(attemptId)) throw new PortOnePrintPaymentError('refund_attempt_invalid')
  // amount omitted means full cancellation, including provider promotions.
  // The provider's promotion policy measures the cancellation balance before
  // promotion discounts. A newly observed PAID receipt has zero cancellations.
  // Customer money returned is original.paidAmount; retail amount is never sent
  // as an explicit requested refund amount.
  await request(expected,options,'POST',attemptId,{storeId:expected.storeId,reason:'스냅핏 제작 전 고객 취소 요청',requester:'CUSTOMER',currentCancellableAmount:expected.amount})
}

import { corsHeaders } from './cors.ts'
import { frozenPrintSpec, calculateContribution, sha256 } from './print-contract.ts'
import { OrderPaymentError } from './order-types.ts'
import { assertFulfillmentAssetSources } from './print-fulfillment-assets.ts'
import { queryPortOnePrintPaymentState, PortOnePrintPaymentError } from './portone-print-payment.ts'
import { publicPrintSpec as publicSpec, publicPrintQuoteField } from './print-public-quote.ts'
import { validPrintCheckoutConsent } from './print-checkout-consent.ts'

export type ProductionPrintDatabase = { rpc(name: string, params: Record<string, unknown>): PromiseLike<{data: unknown; error: unknown}> }
export type ProductionPrintPaymentConfiguration = { enabled: boolean; environment: string; storeId: string; channelKey: string; apiSecret: string; supabaseUrl?: string }
export type ProductionPrintCheckoutDependencies = {
  getUser(request: Request): Promise<{id?: unknown} | null>
  createAdminDatabase(): ProductionPrintDatabase
  configuration(): ProductionPrintPaymentConfiguration
  queryPayment?: typeof queryPortOnePrintPaymentState
  now?: () => number
}
export class ProductionPrintCheckoutError extends Error {
  constructor(readonly code: string, readonly status = 409, readonly retryable = false) { super(code) }
}
const uuid = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v)
const paymentId = (v: unknown): v is string => typeof v === 'string' && v.startsWith('SFP_') && uuid(v.slice(4))
const orderId = (v: unknown): v is string => typeof v === 'string' && v.startsWith('ordp_') && uuid(v.slice(5))
const object = (v: unknown): Record<string, any> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, any> : {}
const identifier = (v: unknown) => typeof v === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(v)
const integer = (v: unknown, min = 1) => Number.isSafeInteger(v) && Number(v) >= min
const keys = (v: Record<string, unknown>, allowed: string[]) => Object.keys(v).every(k => allowed.includes(k))
const testChannel = 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88'
const reply = (body: unknown, status = 200) => Response.json(body, {status, headers: {...corsHeaders, 'Cache-Control': 'no-store'}})
const safeDbErrors = new Set(['print_checkout_request_conflict','print_sales_not_ready','print_album_changed','print_quote_changed',
  'invalid_print_checkout_request','invalid_delivery_address','print_delivery_quote_required','print_payment_receipt_invalid',
  'print_payment_receipt_conflict','print_payment_state_changed','print_checkout_immutable','print_files_not_ready',
  'print_checkout_consent_required','print_checkout_consent_conflict'])
async function rpc(db: ProductionPrintDatabase, name: string, params: Record<string, unknown>) {
  const {data,error} = await db.rpc(name,params)
  if (error) {
    const e=object(error), m=String(e.message??'')
    if (m==='album_access_denied' || e.code==='42501') throw new ProductionPrintCheckoutError('album_access_denied',403)
    if (m==='print_checkout_not_found' || e.code==='P0002') throw new ProductionPrintCheckoutError('print_checkout_not_found',404)
    if (safeDbErrors.has(m)) throw new ProductionPrintCheckoutError(m, m.startsWith('invalid_')?400:409)
    if (e.code==='23505') throw new ProductionPrintCheckoutError('print_payment_receipt_conflict')
    if (e.code==='22023') throw new ProductionPrintCheckoutError('print_album_not_supported',400)
    throw new ProductionPrintCheckoutError('print_checkout_storage_unavailable',503,true)
  }
  return data
}
const document = (value: unknown): unknown => {
  if (typeof value !== 'string') return value ?? null
  try { return JSON.parse(value) } catch { return value }
}
/** Numbers use IEEE754 bytes in both Dart and JS, including integral doubles. */
export function canonicalPrintReview(value: unknown): unknown {
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new ProductionPrintCheckoutError('invalid_print_snapshot',409)
    const bytes = new Uint8Array(8); new DataView(bytes.buffer).setFloat64(0,value,false)
    return {$number64: Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('')}
  }
  if (Array.isArray(value)) return value.map(canonicalPrintReview)
  if (value && typeof value==='object') return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonicalPrintReview((value as Record<string,unknown>)[k])]))
  return value ?? null
}
export async function printCheckoutRevision(snapshot: unknown): Promise<string> {
  const s=object(snapshot),a=object(s.album)
  const tree={albumId:a.id??null,title:a.title??null,ratio:a.ratio??null,coverTheme:a.cover_theme??null,
    cover:document(a.cover_layers_json),printProduct:s.printProduct??null,
    pages:(Array.isArray(s.pages)?s.pages:[]).filter(v=>v&&typeof v==='object'&&!Array.isArray(v)).map(v=>({
      index:v.page_number??v.page_index??null,content:document(v.layers_json)}))}
  return sha256(new TextEncoder().encode(JSON.stringify(canonicalPrintReview(tree))))
}
/** Same source policy as the renderer: project assets owned at freeze time or bundled files. */
export function assertCheckoutSourceSupport(snapshot: unknown, owners: string[], supabaseUrl: string) {
  if (!/^https:\/\//.test(supabaseUrl) || owners.some(v=>!uuid(v))) throw new ProductionPrintCheckoutError('print_source_review_required')
  try { assertFulfillmentAssetSources(snapshot,supabaseUrl,owners) }
  catch { throw new ProductionPrintCheckoutError('print_source_review_required') }
}
const publicQuoteKeys=['pageCount','amount','basePages','basePrice','extraPageCount','extraPagePrice','pricePerTwoPages','sourcePageCount',
  'addedBlankPageCount','productCode','productName','printProduct','coverType','coverLabel','trimWidthMm','trimHeightMm','shippingIncluded',
  'maxPages','layoutFit','pricingVersion','pricePolicyVersion','retailPriceStatus','priceIsEstimate','supplierCostVerified','shippingCostVerified',
  'packagingCostVerified','specMissing','printPdfAvailable','printTemplateStatus','priceNotice','spec']
function publicQuote(value: unknown) {
  const q=object(value)
  if (!integer(q.amount,0)||!integer(q.pageCount,20)||q.pageCount>80||q.pageCount%2||!integer(q.sourcePageCount,0)||q.sourcePageCount>q.pageCount||
      q.pricingVersion!=='PRINT_REDP_COVERTYPE_V3'||!['FINAL','PLANNED','PENDING_SUPPLIER_QUOTE'].includes(q.retailPriceStatus)) {
    throw new ProductionPrintCheckoutError('print_quote_unavailable',503)
  }
  return Object.fromEntries(publicQuoteKeys.filter(k=>Object.hasOwn(q,k)).map(k=>[k,publicPrintQuoteField(k,q[k])]))
}
export async function printCheckoutSpecRevision(spec: unknown) {
  return sha256(new TextEncoder().encode(JSON.stringify(canonicalPrintReview(publicSpec(spec)))))
}
function liveConfig(config: ProductionPrintPaymentConfiguration) {
  return config.enabled===true && config.environment==='live' && identifier(config.storeId) && identifier(config.channelKey) &&
    config.channelKey!==testChannel && typeof config.apiSecret==='string' && /^[\x21-\x7e]{8,2048}$/.test(config.apiSecret)
}
function existingLivePaymentObservable(config: ProductionPrintPaymentConfiguration) {
  // Stopping new sales must not prevent recovery of money already charged.
  // This is GET-only; route and amount are taken from the owned frozen invoice.
  return config.environment==='live' && typeof config.apiSecret==='string' && /^[\x21-\x7e]{8,2048}$/.test(config.apiSecret)
}
function approvedContext(ctx: Record<string,any>,config: ProductionPrintPaymentConfiguration) {
  const q=object(ctx.quote),combo=object(ctx.combination),stored=object(ctx.configuration)
  if (!ctx.canPay || !liveConfig(config) || stored.store_id!==config.storeId || stored.channel_key!==config.channelKey ||
      q.retailPriceStatus!=='FINAL'||q.priceIsEstimate!==false) return false
  try {
    if (JSON.stringify(canonicalPrintReview(q.spec))!==JSON.stringify(canonicalPrintReview(combo.approved_spec))) return false
    const record={checkout_flow:'PORTONE_V2_V1',page_count:q.pageCount,amount:q.amount,pricing_version:'PRINT_REDP_COVERTYPE_V3',
      print_product_snapshot:q.printProduct,print_content_snapshot:{...ctx.snapshot,printProduct:q.printProduct},
      print_spec_snapshot:combo.approved_spec,print_cost_snapshot:combo.cost_snapshot}
    frozenPrintSpec(record)
    const cost=object(combo.cost_snapshot)
    if (!['paymentFeeRate','reprintReserveRate'].every(k=>typeof cost[k]==='number'&&Number.isFinite(cost[k])&&cost[k]>=0&&cost[k]<1)||
        !integer(cost.operationsReserve,3000)||!integer(cost.minimumContribution,10000)) return false
    calculateContribution(record,{actualPrintCost:cost.estimatedPrintCost,actualShippingCost:cost.estimatedShippingCost,actualPackagingCost:cost.estimatedPackagingCost})
    assertCheckoutSourceSupport(ctx.snapshot,ctx.allowedAssetOwners,config.supabaseUrl??'')
    return true
  } catch { return false }
}
function checkedIntent(value: unknown,actor: string) {
  const i=object(value)
  if (i.user_id!==actor||!paymentId(i.payment_id)||!uuid(i.request_id)||typeof i.order_id!=='string'||!i.order_id.startsWith('ordp_')) {
    throw new ProductionPrintCheckoutError('print_checkout_not_found',404)
  }
  if (i.environment!=='live'||i.currency!=='KRW'||!integer(i.amount)||!integer(i.album_id)||!integer(i.page_count,20)||i.page_count>80||i.page_count%2||
      !['PREPARED','PAID','FAILED','CANCELED'].includes(i.status)||!identifier(i.store_id)||!identifier(i.channel_key)||i.channel_key===testChannel||
      !Number.isFinite(Date.parse(i.expires_at))||!/^[a-f0-9]{64}$/.test(i.reviewed_revision)||!/^[a-f0-9]{64}$/.test(i.reviewed_spec_revision)) throw new ProductionPrintCheckoutError('print_checkout_record_invalid',503)
  const receipt=object(i.payment_receipt)
  if (i.status!=='PREPARED' && (!i.verified_at||receipt.environment!=='live'||receipt.isTest!==false||receipt.paymentId!==i.payment_id||
      receipt.amount!==i.amount||receipt.provider!=='PORTONE'||receipt.storeId!==i.store_id||receipt.channelKey!==i.channel_key||
      receipt.version!=='V2'||!identifier(receipt.transactionId)||!Number.isFinite(Date.parse(i.verified_at))||
      (i.status==='PAID'?receipt.status!=='PAID':receipt.verifiedUnpaid!==true||receipt.status!==(i.status==='FAILED'?'FAILED':'CANCELLED')))) throw new ProductionPrintCheckoutError('print_checkout_record_invalid',503)
  return i
}
function envelope(i: Record<string,any>,config: ProductionPrintPaymentConfiguration,now: number,launch=false) {
  const refunded=i.refunded_full===true
  const printPackageReady=i.print_file_source==='APP_UPLOADED'&&i.prepayment_package_ready===true&&uuid(i.prepayment_package_id)
  const canLaunch=launch&&printPackageReady&&i.sdk_issued_at!=null&&i.request_hold!==true&&i.launch_ready===true&&i.status==='PREPARED'&&Date.parse(i.expires_at)>now&&liveConfig(config)&&i.store_id===config.storeId&&i.channel_key===config.channelKey
  return {orderId:i.order_id,paymentId:i.payment_id,requestId:i.request_id,albumId:i.album_id,totalAmount:i.amount,environment:'production',
    status:refunded?'CANCELED':i.status==='PAID'?'PAYMENT_COMPLETED':i.status,verifiedPaid:i.status==='PAID'&&!refunded,verifiedUnpaid:refunded||['FAILED','CANCELED'].includes(i.status),
    refundedFull:refunded,customerRequestHold:i.request_hold===true,printPackageReady,
    prepaymentPackageId:uuid(i.prepayment_package_id)?i.prepayment_package_id:null,maxFileBytes:500000000,
    maxCoverFileBytes:150000000,maxStorageObjectBytes:50000000,printPartBytes:16000000,
    paidAt:i.status==='PAID'?i.verified_at:null,reviewedRevision:i.reviewed_revision,reviewedSpecRevision:i.reviewed_spec_revision,recipient:i.delivery_snapshot,
    sdkRequest:canLaunch?{paymentId:i.payment_id,storeId:i.store_id,channelKey:i.channel_key,orderName:'스냅핏 포토북',totalAmount:i.amount,
      currency:'KRW',environment:'production',status:'READY'}:null}
}
export async function reconcileProductionPrintPayment(db: ProductionPrintDatabase,config: ProductionPrintPaymentConfiguration,
  identity: {userId: string;paymentId: string},fetcher?: typeof fetch,queryPayment= queryPortOnePrintPaymentState) {
  if (!uuid(identity.userId)||!paymentId(identity.paymentId)) throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400)
  const i=checkedIntent(await rpc(db,'get_owned_print_checkout',{p_actor:identity.userId,p_payment_id:identity.paymentId,p_request_id:null}),identity.userId)
  if (i.status!=='PREPARED') return i
  if (!existingLivePaymentObservable(config)) throw new ProductionPrintCheckoutError('print_payment_configuration_unavailable',503,true)
  // An existing invoice uses its frozen route even if the current sales catalog is closed or changed.
  const result=await queryPayment({paymentId:i.payment_id,storeId:i.store_id,channelKey:i.channel_key,amount:i.amount,currency:'KRW',environment:'live'},
    {apiSecret:config.apiSecret,fetcher})
  if (result.kind==='unknown') return i
  if (result.receipt.environment!=='live'||result.receipt.isTest!==false) throw new ProductionPrintCheckoutError('payment_environment_mismatch')
  return checkedIntent(await rpc(db,'commit_production_print_payment',{p_actor:identity.userId,p_payment_id:i.payment_id,p_receipt:result.receipt,
    p_unpaid:result.kind==='verified_unpaid'}),identity.userId)
}
function parseRecipient(value: unknown) {
  const r=object(value)
  if (!keys(r,['name','phone','zipCode','addressLine1','addressLine2','deliveryMemo']) || typeof r.name!=='string'||!r.name.trim()||r.name.trim().length>80||
      typeof r.phone!=='string'||!/^\d{10,11}$/.test(r.phone)||typeof r.zipCode!=='string'||!/^\d{5}$/.test(r.zipCode)||
      typeof r.addressLine1!=='string'||!r.addressLine1.trim()||r.addressLine1.trim().length>300||
      (r.addressLine2!=null && typeof r.addressLine2!=='string')||(r.deliveryMemo!=null && typeof r.deliveryMemo!=='string')||
      String(r.addressLine2??'').length>300||String(r.deliveryMemo??'').length>300) throw new ProductionPrintCheckoutError('invalid_delivery_address',400)
  return {name:r.name.trim(),phone:r.phone,zipCode:r.zipCode,addressLine1:r.addressLine1.trim(),addressLine2:String(r.addressLine2??'').trim(),deliveryMemo:String(r.deliveryMemo??'').trim()}
}
async function authenticated(request: Request,lookup: ProductionPrintCheckoutDependencies['getUser']) {
  if (!/^Bearer [^\s]+$/i.test(request.headers.get('Authorization')??'')) throw new ProductionPrintCheckoutError('authentication_required',401)
  let user: {id?:unknown}|null
  try { user=await lookup(request) } catch { throw new ProductionPrintCheckoutError('invalid_session',401) }
  if (!uuid(user?.id)) throw new ProductionPrintCheckoutError('invalid_session',401)
  return user.id
}
export function createProductionPrintCheckoutHandler(deps: ProductionPrintCheckoutDependencies,confirmOnly=false) {
  return async(request: Request)=>{
    if (request.method==='OPTIONS') return new Response('ok',{headers:corsHeaders})
    if (request.method!=='POST') return reply({error:'method_not_allowed'},405)
    try {
      const actor=await authenticated(request,deps.getUser),text=await request.text()
      if (text.length>8192) throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400)
      let body: Record<string,any>;try { body=object(JSON.parse(text)) } catch { throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400) }
      const action=confirmOnly?'confirm':body.action
      if (confirmOnly ? !keys(body,['paymentId'])||!paymentId(body.paymentId) : !['prepare','readiness','status'].includes(action)) throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400)
      if (action==='status' && (!keys(body,['action','paymentId','requestId','orderId'])||
        [body.paymentId,body.requestId,body.orderId].filter(value=>value!=null).length!==1||
        (body.paymentId!=null&&!paymentId(body.paymentId))||(body.requestId!=null&&!uuid(body.requestId))||
        (body.orderId!=null&&!orderId(body.orderId)))) throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400)
      if (action==='readiness'||action==='prepare') {
        if (!keys(body,action==='readiness'?['action','albumId','pageCount']:['action','albumId','pageCount','requestId','reviewedRevision','reviewedSpecRevision','expectedAmount','recipient','consent'])||
          !integer(body.albumId)||(body.pageCount!=null&&(!integer(body.pageCount,20)||body.pageCount>80||body.pageCount%2))||
          (action==='prepare'&&(!uuid(body.requestId)||!/^[a-f0-9]{64}$/.test(body.reviewedRevision)||!/^[a-f0-9]{64}$/.test(body.reviewedSpecRevision)||!integer(body.expectedAmount)))) throw new ProductionPrintCheckoutError('invalid_print_checkout_request',400)
        if (action==='prepare'&&!validPrintCheckoutConsent(body.consent)) throw new ProductionPrintCheckoutError('print_checkout_consent_required',400)
      }
      const db=deps.createAdminDatabase(),config=deps.configuration(),now=deps.now?.()??Date.now()
      if (action==='status') {
        const i=checkedIntent(body.orderId!=null ?
          await rpc(db,'get_owned_print_checkout_by_order',{p_actor:actor,p_order_id:body.orderId}) :
          await rpc(db,'get_owned_print_checkout',{p_actor:actor,p_payment_id:body.paymentId??null,p_request_id:body.requestId??null}),actor)
        return reply(envelope(i,config,now)) // No SDK launch via recovery/status. Explicit same-ID prepare may resume an unstarted invoice.
      }
      if (action==='confirm') {
        const i=await reconcileProductionPrintPayment(db,config,{userId:actor,paymentId:body.paymentId},undefined,deps.queryPayment)
        return reply(envelope(i,config,now))
      }
      const recipient=action==='prepare'?parseRecipient(body.recipient):null
      if (action==='prepare') {
        // Replay frozen values, including the original reviewed address, before reading a mutable album/catalog.
        let existing: Record<string,any>|null=null
        try { existing=checkedIntent(await rpc(db,'get_owned_print_checkout',{p_actor:actor,p_payment_id:null,p_request_id:body.requestId}),actor) }
        catch(e) { if (!(e instanceof ProductionPrintCheckoutError&&e.code==='print_checkout_not_found')) throw e }
        if (existing) {
          if (existing.album_id!==body.albumId||existing.reviewed_revision!==body.reviewedRevision||existing.reviewed_spec_revision!==body.reviewedSpecRevision||existing.amount!==body.expectedAmount||
              (body.pageCount!=null&&existing.page_count!==body.pageCount)||JSON.stringify(canonicalPrintReview(existing.delivery_snapshot))!==JSON.stringify(canonicalPrintReview(recipient))) {
            throw new ProductionPrintCheckoutError('print_checkout_request_conflict')
          }
          await rpc(db,'record_print_checkout_consent',{p_actor:actor,p_payment_id:existing.payment_id,p_consent:body.consent})
          if(existing.print_file_source==='APP_UPLOADED'&&existing.prepayment_package_ready===true&&existing.launch_ready===true&&
              existing.status==='PREPARED'&&existing.request_hold!==true&&Date.parse(existing.expires_at)>now&&liveConfig(config)) {
            existing=checkedIntent(await rpc(db,'authorize_print_app_pdf_checkout',{p_actor:actor,p_payment_id:existing.payment_id}),actor)
          }
          return reply(envelope(existing,config,now,true))
        }
      }
      const ctx=object(await rpc(db,'load_owned_print_checkout_context',{p_actor:actor,p_album_id:body.albumId})),quote=publicQuote(ctx.quote)
      if (body.pageCount!=null&&quote.pageCount!==body.pageCount) throw new ProductionPrintCheckoutError('print_quote_changed')
      const revision=await printCheckoutRevision(ctx.snapshot),specRevision=await printCheckoutSpecRevision(quote.spec),canPay=approvedContext(ctx,config)
      if (action==='readiness') return reply({canPay,status:canPay?'READY':'PREPARING',reasonCode:canPay?null:'print_sales_not_ready',
        message:canPay?'배송지를 확인하고 결제해 주세요.':'인쇄 주문을 준비하고 있어요. 정식 주문이 열리면 결제할 수 있어요.',
        quote,reviewedRevision:revision,reviewedSpecRevision:specRevision,paymentProvider:'PORTONE',environment:canPay?'production':'unavailable'})
      if (!canPay) throw new ProductionPrintCheckoutError('print_sales_not_ready')
      if (body.reviewedRevision!==revision) throw new ProductionPrintCheckoutError('print_album_changed')
      if (body.reviewedSpecRevision!==specRevision) throw new ProductionPrintCheckoutError('print_quote_changed')
      if (body.expectedAmount!==quote.amount) throw new ProductionPrintCheckoutError('print_quote_changed')
      const i=checkedIntent(await rpc(db,'prepare_production_print_checkout_with_consent',{p_actor:actor,p_request_id:body.requestId,p_album_id:body.albumId,
        p_source_digest:ctx.sourceDigest,p_reviewed_revision:revision,p_reviewed_spec_revision:specRevision,p_expected_amount:quote.amount,p_page_count:quote.pageCount,p_recipient:recipient,p_consent:body.consent}),actor)
      return reply(envelope({...i,launch_ready:canPay},config,now,true))
    } catch(error) {
      if (error instanceof ProductionPrintCheckoutError||error instanceof PortOnePrintPaymentError) return reply({error:error.code,retryable:error.retryable},error.status)
      if (error instanceof OrderPaymentError) return reply({error:'print_album_not_supported'},error.status)
      return reply({error:'print_checkout_unavailable',retryable:true},503)
    }
  }
}

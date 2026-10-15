import { OrderPaymentError } from './order-types.ts'
import { queryPortOnePrintPayment, PortOnePrintPaymentError, type ExpectedPortOnePrintPayment,
  type PortOnePrintPaymentObservation } from './portone-print-payment.ts'
import { RedprintingClient, RedprintingError, assertDevelopment, assertReadySettings, hasVendorFileError,
  orderAcceptance, testOrderPayload, vendorCodeDetail, vendorDevelopmentQuote, vendorTestRecipient,
  type RedprintingEnvironment, type RedprintingSettings } from './redprinting.ts'
import { createPrintFileDeliveryUrl, readPrintFileDelivery, type PrintFileKind } from './print-file-delivery.ts'

export const PRINT_DEV_PAYMENT_ROUTE = { storeId: 'store-33df409e-0ad9-4953-8194-70db7e32efae',
  channelKey: 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88' } as const
export const PRINT_DEV_ORDER_CODE = 'C8E9D98C73536387071'
export type PrintDevConfiguration = {
  enabled: boolean; paymentEnvironment: string; storeId: string; channelKey: string; paymentApiSecret: string;
  vendor: RedprintingEnvironment; deliverySecret: string; supabaseUrl: string
}
export type PrintDevFulfillmentClaim = {
  job: { id: string; checkout_id: string; event_type: 'PAYMENT' | 'SUBMIT' | 'POLL'; state: 'CLAIMED'; lease_owner: string; lease_until: string;
    payload: { vendorOrderNum: string; vendorOrderSeq: 1; queryOnly?: boolean } }
  checkout: Record<string, any>; package: Record<string, any>; paymentExpectation: ExpectedPortOnePrintPayment
}
export type PrintDevTickResult = { enabled: boolean; checked: number; advanced: number; errors: number; stage: string | null }
type Dependencies = {
  vendor: Pick<RedprintingClient, 'call' | 'status'>
  sender(): Promise<RedprintingSettings>
  paymentLookup?: (expected: ExpectedPortOnePrintPayment) => Promise<PortOnePrintPaymentObservation>
  now?: () => number
  randomUUID?: () => string
}
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(value)
const hash = (value: unknown) => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value)
const canonical = (value: any): string => JSON.stringify(value, (_, child) => child && typeof child === 'object' && !Array.isArray(child) ?
  Object.fromEntries(Object.entries(child).sort(([a], [b]) => a.localeCompare(b))) : child)
const code = (failure: unknown) => {
  const raw = failure instanceof PortOnePrintPaymentError || failure instanceof RedprintingError ? failure.code :
    failure instanceof OrderPaymentError ? failure.message : 'print_dev_fulfillment_unavailable'
  return /^[a-z0-9_]{1,80}$/.test(raw) ? raw : 'print_dev_fulfillment_unavailable'
}
const terminal = (value: string) => /^(?:invalid_print_dev_|payment_(?:identity|channel|environment|amount|currency|version)_mismatch|payment_reversed|payment_cancellation_review_required|vendor_order_canceled)/.test(value)
async function rpc<T>(db: any, name: string, args: Record<string, unknown>): Promise<T> {
  const result = await db.rpc(name, args)
  if (result.error) throw new OrderPaymentError('print_dev_database_unavailable', 503)
  return result.data as T
}
function configured(configuration: PrintDevConfiguration, now: number) {
  if (configuration.enabled !== true) return false
  if (configuration.paymentEnvironment !== 'test' || configuration.storeId !== PRINT_DEV_PAYMENT_ROUTE.storeId ||
      configuration.channelKey !== PRINT_DEV_PAYMENT_ROUTE.channelKey || !/^[\x21-\x7e]{8,2048}$/.test(configuration.paymentApiSecret) ||
      !hash(configuration.deliverySecret)) throw new OrderPaymentError('print_dev_configuration_unavailable', 503)
  assertDevelopment(configuration.vendor, now)
  return true
}

function checkedClaim(value: PrintDevFulfillmentClaim, owner: string, now: number) {
  const job = value?.job, checkout = value?.checkout, pack = value?.package, payment = value?.paymentExpectation
  if (!job || !checkout || !pack || !payment || !uuid(job.id) || !uuid(checkout.id) || job.checkout_id !== checkout.id ||
      job.state !== 'CLAIMED' || job.lease_owner !== owner || !['PAYMENT', 'SUBMIT', 'POLL'].includes(job.event_type) ||
      !Number.isFinite(Date.parse(job.lease_until)) || Date.parse(job.lease_until) <= now ||
      !/^SFD[a-f0-9]{32}$/.test(job.payload?.vendorOrderNum ?? '') || job.payload.vendorOrderSeq !== 1 ||
      !uuid(checkout.owner_id) || !uuid(checkout.request_id) || typeof checkout.order_id !== 'string' || !checkout.order_id.startsWith('ordp_') ||
      !uuid(checkout.order_id.slice(5)) || !uuid(pack.id) || checkout.package_id !== pack.id || pack.checkout_id !== checkout.id ||
      pack.state !== 'READY' || !hash(pack.source_fingerprint) || checkout.environment !== 'test' || checkout.currency !== 'KRW' ||
      checkout.total_amount !== 159900 || checkout.order_code !== PRINT_DEV_ORDER_CODE || checkout.product?.id !== 'REDP_300_HARD' ||
      checkout.spec?.id !== 'REDP_300_HARD' || checkout.spec?.pageCount !== 80 ||
      !['READY', 'PAYMENT_VERIFIED', 'SUBMITTING', 'UNKNOWN', 'ACCEPTED', 'FILE_CHECKED'].includes(checkout.status) ||
      !Number.isFinite(Date.parse(checkout.sdk_issued_at ?? '')) || !/^SFPGT_[a-f0-9-]{36}$/.test(checkout.payment_id ?? '') ||
      !uuid(checkout.payment_id.slice(6)) || payment.paymentId !== checkout.payment_id || payment.environment !== 'test' ||
      payment.storeId !== PRINT_DEV_PAYMENT_ROUTE.storeId || payment.channelKey !== PRINT_DEV_PAYMENT_ROUTE.channelKey ||
      payment.amount !== 159900 || payment.currency !== 'KRW' ||
      pack.pdf_manifest?.sourceFingerprint !== pack.source_fingerprint || canonical(pack.pdf_manifest?.spec) !== canonical(checkout.spec) ||
      canonical(pack.pdf_manifest?.cover) !== canonical(pack.cover_result) || canonical(pack.pdf_manifest?.interior) !== canonical(pack.interior_result) ||
      pack.pdf_manifest?.vendorReady !== false ||
      pack.cover_path !== `${checkout.order_id}/${pack.id}/cover.pdf` || pack.interior_path !== `${checkout.order_id}/${pack.id}/interior.pdf` ||
      pack.manifest_path !== `${checkout.order_id}/${pack.id}/manifest.json`) throw new OrderPaymentError('invalid_print_dev_claim', 503)
  vendorTestRecipient(checkout.recipient)
  const parts = pack.file_parts ?? {}
  if (Object.keys(parts).length && canonical(pack.pdf_manifest.fileTransport) !== canonical({ version: 'CHUNKED_V1', files: parts })) {
    throw new OrderPaymentError('invalid_print_dev_package', 503)
  }
  return value
}

/** Exactly one leased phase. TEST receipts never enter customer-order tables. */
export async function runPrintDevFulfillmentTick(db: any, configuration: PrintDevConfiguration, dependencies: Dependencies): Promise<PrintDevTickResult> {
  const result: PrintDevTickResult = { enabled: configuration.enabled === true, checked: 0, advanced: 0, errors: 0, stage: null }
  const now = dependencies.now ?? Date.now
  if (!configured(configuration, now())) return result
  const owner = dependencies.randomUUID?.() ?? crypto.randomUUID()
  if (!uuid(owner)) throw new OrderPaymentError('invalid_print_dev_worker', 503)
  const raw = await rpc<PrintDevFulfillmentClaim | null>(db, 'claim_print_dev_fulfillment_job', { p_worker_id: owner, p_limit: 1, p_lease_seconds: 120 })
  if (!raw) return result
  result.checked = 1
  let claim: PrintDevFulfillmentClaim
  try { claim = checkedClaim(raw, owner, now()) }
  catch { result.errors = 1; return result }
  result.stage = claim.job.event_type
  const current = async () => checkedClaim(await rpc<PrintDevFulfillmentClaim>(db, 'get_print_dev_fulfillment_job',
    { p_id: claim.job.id, p_owner: owner }), owner, now())
  const finish = (value: Record<string, unknown>) => rpc(db, 'finish_print_dev_fulfillment_job', {
    p_id: claim.job.id, p_owner: owner, p_result: { availableAt: new Date(now() + 120_000).toISOString(), ...value },
  })
  const payment = async () => {
    const receipt = await (dependencies.paymentLookup?.(claim.paymentExpectation) ?? queryPortOnePrintPayment(claim.paymentExpectation,
      { apiSecret: configuration.paymentApiSecret }))
    if (receipt.environment !== 'test' || receipt.isTest !== true || receipt.status !== 'PAID' || receipt.provider !== 'PORTONE' || receipt.version !== 'V2' ||
        receipt.paymentId !== claim.checkout.payment_id || receipt.storeId !== PRINT_DEV_PAYMENT_ROUTE.storeId ||
        receipt.channelKey !== PRINT_DEV_PAYMENT_ROUTE.channelKey || receipt.amount !== 159900 || receipt.currency !== 'KRW') {
      throw new OrderPaymentError('payment_environment_mismatch', 409)
    }
    return receipt
  }
  const observed = async () => {
    const status = await dependencies.vendor.status(claim.job.payload.vendorOrderNum, 1)
    const canceled = status.statusCode === 'PGS_01' || ['PGS_01', 'PGS_02'].includes(status.statusCodeOrg)
    if (canceled) throw new OrderPaymentError('vendor_order_canceled', 409)
    const failed = hasVendorFileError(status), fileChecked = status.fileProcessYn === 'Y' && !failed
    await finish({ nextStage: fileChecked ? 'DONE' : 'POLL', status: fileChecked ? 'FILE_CHECKED' : 'ACCEPTED', vendorStatus: status,
      ...(failed ? { errorCode: 'vendor_file_processing_error' } : {}) })
  }
  try {
    if (claim.job.event_type === 'PAYMENT') {
      const receipt = await payment()
      await current()
      await rpc(db, 'commit_print_dev_payment', { p_id: claim.job.id, p_owner: owner, p_receipt: receipt })
      await finish({ nextStage: 'SUBMIT', status: 'PAYMENT_VERIFIED', availableAt: new Date(now()).toISOString() })
    } else if (claim.job.event_type === 'POLL' || claim.job.payload.queryOnly === true || Boolean(claim.checkout.submitted_at)) {
      // Once a submission could have reached the supplier, even repeated 404
      // means GET-only recovery. Never reuse the same identity for another POST.
      await observed()
    } else {
      await payment()
      const detail = vendorCodeDetail(await dependencies.vendor.call('/v1/code/detail', { order_code: claim.checkout.order_code }), claim.checkout.order_code)
      if (detail.useYn !== 'Y') throw new OrderPaymentError('vendor_order_code_not_approved', 409)
      vendorDevelopmentQuote(await dependencies.vendor.call('/v1/code/price', { order_code: claim.checkout.order_code, qty: 1 }), configuration.vendor)
      const settings = await dependencies.sender(); assertReadySettings(settings)
      const files = {} as Record<PrintFileKind, string>
      for (const kind of ['cover', 'interior'] as PrintFileKind[]) {
        const reference = { orderId: claim.checkout.order_id as string, packageId: claim.package.id as string, kind, sha256: claim.package[`${kind}_result`]?.sha256 }
        const delivery = await readPrintFileDelivery(db, reference, true)
        if (canonical(delivery.result) !== canonical(claim.package[`${kind}_result`]) ||
            canonical(delivery.parts) !== canonical(claim.package.file_parts?.[kind] ?? [])) throw new OrderPaymentError('invalid_print_dev_package', 503)
        files[kind] = await createPrintFileDeliveryUrl(reference, { development: true, supabaseUrl: configuration.supabaseUrl,
          secret: configuration.deliverySecret, now: now() })
      }
      const payload = testOrderPayload({ recipient: claim.checkout.recipient, order_num: claim.job.payload.vendorOrderNum,
        order_code: claim.checkout.order_code }, settings, files)
      await current()
      // The service RPC commits queryOnly=true before the only external POST.
      await rpc(db, 'record_print_dev_submission_attempt', { p_id: claim.job.id, p_owner: owner })
      const accepted = orderAcceptance(await dependencies.vendor.call('/v1/code/order', payload), claim.job.payload.vendorOrderNum, 1)
      if (!accepted.accepted && !accepted.acknowledged) throw new OrderPaymentError('vendor_order_response_uncertain', 503)
      await observed()
    }
    result.advanced = 1
  } catch (failure) {
    result.errors = 1
    await rpc(db, 'fail_print_dev_fulfillment_job', { p_id: claim.job.id, p_owner: owner, p_error_code: code(failure),
      p_available_at: new Date(now() + 120_000).toISOString(), p_terminal: terminal(code(failure)) })
  }
  return result
}

import { adminClient } from '../_shared/supabase.ts'
import { createPrintOrderSchedulerHandler, createPrintSchedulerRequestFetch } from '../_shared/print-order-scheduler.ts'
import { reconcileProductionPrintPayment } from '../_shared/production-print-checkout.ts'
import { PrintFulfillmentWorker, type FulfillmentConfiguration } from '../_shared/print-fulfillment-worker.ts'
import { RedprintingFulfillmentClient } from '../_shared/print-fulfillment-vendor.ts'
import { resolvePrintOrderRequest } from '../_shared/print-order-request.ts'
import { RedprintingCancellationClient } from '../_shared/print-order-cancel-vendor.ts'
import { RedprintingError, type RedprintingSettings } from '../_shared/redprinting.ts'
import { queryPortOnePrintPayment, queryPortOnePrintPaymentState } from '../_shared/portone-print-payment.ts'
import { queryFullPrintRefund, requestFullPrintRefund } from '../_shared/print-order-refund-provider.ts'
import { PRINT_BUCKET } from '../_shared/print-contract.ts'
import { runPrintDevFulfillmentTick } from '../_shared/print-dev-fulfillment.ts'
import { RedprintingClient } from '../_shared/redprinting.ts'

const bool = (name: string) => Deno.env.get(name) === 'true'
const text = (name: string) => Deno.env.get(name) ?? ''
const paymentConfiguration = () => ({ enabled: bool('PRINT_PORTONE_PRODUCTION_ENABLED'), environment: text('PRINT_PORTONE_ENVIRONMENT') || 'disabled',
  storeId: text('PRINT_PORTONE_STORE_ID'), channelKey: text('PRINT_PORTONE_CHANNEL_KEY'), apiSecret: text('PRINT_PORTONE_V2_API_SECRET') })
const vendorReady = () => bool('PRINT_REDP_PRODUCTION_ENABLED') && bool('PRINT_REDP_PRODUCTION_APPROVED') &&
  Boolean(text('PRINT_REDP_PRODUCTION_USER_ID')) && Boolean(text('PRINT_REDP_PRODUCTION_API_KEY'))
const fulfillmentConfiguration = (): FulfillmentConfiguration => ({ enabled: bool('PRINT_FULFILLMENT_ENABLED'),
  environment: text('PRINT_PORTONE_ENVIRONMENT') || 'disabled', depositEnabled: bool('PRINT_REDP_DEPOSIT_ENABLED'),
  supabaseUrl: text('SUPABASE_URL'), paymentApiSecret: text('PRINT_PORTONE_V2_API_SECRET'), vendorReady: vendorReady(),
  deliverySecret: text('PRINT_ORDER_SCHEDULER_SECRET') })
const vendorConfiguration = () => ({ enabled: bool('PRINT_REDP_PRODUCTION_ENABLED'),
  environment: bool('PRINT_REDP_PRODUCTION_ENABLED') ? 'production' as const : 'disabled' as const,
  productionApproved: bool('PRINT_REDP_PRODUCTION_APPROVED'), depositEnabled: bool('PRINT_REDP_DEPOSIT_ENABLED'),
  userId: text('PRINT_REDP_PRODUCTION_USER_ID'), apiKey: text('PRINT_REDP_PRODUCTION_API_KEY') })
const check = (result: any) => { if (result.error) throw new RedprintingError('vendor_configuration_unavailable', 503); return result.data }
async function acquireRate(database: any) {
  const owner = crypto.randomUUID(), started = Date.now()
  for (;;) {
    const delay = Number(check(await database.rpc('redprinting_dev_acquire_slot', { p_owner: owner })))
    if (delay === 0) break
    if (!Number.isFinite(delay) || delay < 0 || Date.now() - started > 10_000) throw new RedprintingError('vendor_api_busy', 429)
    await new Promise(resolve => setTimeout(resolve, Math.min(delay, 1200)))
  }
  return async () => { check(await database.rpc('redprinting_dev_release_slot', { p_owner: owner })) }
}
async function sender(database: any): Promise<RedprintingSettings> {
  const row = check(await database.from('redprinting_dev_settings').select('sender_name,sender_tel,sender_zipcode,sender_address,sender_address_detail').eq('id', 1).single())
  return { senderName: row.sender_name, senderTel: row.sender_tel, senderZipcode: row.sender_zipcode,
    senderAddress: row.sender_address, senderAddressDetail: row.sender_address_detail } as RedprintingSettings
}
async function developmentSender(database: any): Promise<RedprintingSettings> {
  const row = check(await database.from('redprinting_dev_settings').select('*').eq('id', 1).single())
  return { senderName: row.sender_name ?? '스냅핏', senderTel: row.sender_tel ?? '', senderZipcode: row.sender_zipcode ?? '',
    senderAddress: row.sender_address ?? '', senderAddressDetail: row.sender_address_detail ?? '',
    colorMode: row.color_mode ?? 'UNCONFIRMED', colorApprovalNote: row.color_approval_note ?? '', colorApprovedAt: row.color_approved_at ?? null,
    testDepositEnabled: row.test_deposit_enabled === true, developmentRgbTestAcknowledged: row.development_rgb_test_acknowledged === true,
    developmentGeometryTestAcknowledged: row.development_geometry_test_acknowledged === true }
}

// Gateway JWT is disabled only for this dedicated server-capability endpoint.
// A fresh HMAC known to Cron/Vault and the Edge runtime is mandatory on every
// POST. The long-lived key is never sent and private nonces prevent replay.
// No endpoint accepts credentials, test/live overrides or business references.
Deno.serve(request => {
  // Each invocation owns its deadline. A slow earlier request cannot expire the
  // next Cron run or let database/Storage traffic outlive a provider timeout.
  const providerFetch = createPrintSchedulerRequestFetch(fetch, 115_000, request.signal)
  return createPrintOrderSchedulerHandler({
  secret: () => text('PRINT_ORDER_SCHEDULER_SECRET'), createAdminDatabase: () => adminClient({ fetch: providerFetch }),
  configuration: () => {
    const payment = paymentConfiguration(), fulfillment = fulfillmentConfiguration()
    const paymentObservable = payment.environment === 'live' && /^[\x21-\x7e]{8,2048}$/.test(payment.apiSecret) &&
      /^store-[A-Za-z0-9-]+$/.test(payment.storeId) && /^channel-key-[A-Za-z0-9-]+$/.test(payment.channelKey) &&
      payment.channelKey !== 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88'
    return { enabled: bool('PRINT_ORDER_SCHEDULER_ENABLED'), paymentObservable,
      refundsEnabled: bool('PRINT_ORDER_REFUNDS_ENABLED'), fulfillmentReady: fulfillment.enabled && fulfillment.environment === 'live' &&
        fulfillment.depositEnabled && fulfillment.vendorReady && paymentObservable }
  },
  development: database => {
    const paymentEnvironment = text('PRINT_PORTONE_ENVIRONMENT') || 'disabled'
    // Switching to LIVE also disables the isolated TEST queue, even if its
    // feature flag was left on. A stale TEST flag cannot starve LIVE work.
    if (!bool('PRINT_DEV_CHECKOUT_ENABLED') || paymentEnvironment !== 'test') {
      return Promise.resolve({ enabled: false, checked: 0, advanced: 0, errors: 0, stage: null })
    }
    const vendor = { environment: text('REDPRINTING_ENVIRONMENT') || 'disabled', enabled: bool('REDPRINTING_ENABLED'),
      userId: text('REDPRINTING_USER_ID'), apiKey: text('REDPRINTING_DEV_API_KEY'), expiresAt: text('REDPRINTING_DEV_KEY_EXPIRES_AT') }
    return runPrintDevFulfillmentTick(database, { enabled: true,
      paymentEnvironment, storeId: text('PRINT_PORTONE_STORE_ID'),
      channelKey: text('PRINT_PORTONE_CHANNEL_KEY'), paymentApiSecret: text('PRINT_PORTONE_V2_API_SECRET'),
      vendor, deliverySecret: text('PRINT_ORDER_SCHEDULER_SECRET'), supabaseUrl: text('SUPABASE_URL') }, {
        vendor: new RedprintingClient(vendor, { acquire: () => acquireRate(database), fetch: providerFetch }),
        sender: () => developmentSender(database), paymentLookup: expected => queryPortOnePrintPayment(expected,
          { apiSecret: text('PRINT_PORTONE_V2_API_SECRET'), fetcher: providerFetch, timeoutMs: 12_000 }),
      })
  },
  reconcile: async (database, payment) => {
    const intent = await reconcileProductionPrintPayment(database, paymentConfiguration(), payment, providerFetch)
    return { verifiedPaid: intent.status === 'PAID', verifiedUnpaid: intent.status === 'FAILED' || intent.status === 'CANCELED' }
  },
  resolve: async (database, requestId, owner) => {
    const result = await resolvePrintOrderRequest(database, { enabled: bool('PRINT_ORDER_REFUNDS_ENABLED'),
      environment: text('PRINT_PORTONE_ENVIRONMENT') || 'disabled', apiSecret: text('PRINT_PORTONE_V2_API_SECRET'), vendorReady: vendorReady() },
      requestId, owner, new RedprintingCancellationClient(vendorConfiguration(), () => acquireRate(database), providerFetch), {
        queryPayment: (expected, options) => queryPortOnePrintPaymentState(expected, { ...options, fetcher: providerFetch, timeoutMs: 12_000 }),
        observePaid: (expected, options) => queryPortOnePrintPayment(expected, { ...options, fetcher: providerFetch, timeoutMs: 12_000 }),
        observeRefund: (expected, original, options) => queryFullPrintRefund(expected, original, { ...options, fetcher: providerFetch, timeoutMs: 12_000 }),
        refund: (expected, original, attemptId, options) => requestFullPrintRefund(expected, original, attemptId, { ...options, fetcher: providerFetch, timeoutMs: 12_000 }),
      })
    return { processed: result.processed, request: result.request }
  },
  advance: (database, jobId, owner) => new PrintFulfillmentWorker(database, fulfillmentConfiguration(),
    new RedprintingFulfillmentClient(vendorConfiguration(), () => acquireRate(database), providerFetch), () => sender(database), {
      assetFetch: providerFetch,
      paymentLookup: expectation => queryPortOnePrintPayment(expectation, { apiSecret: text('PRINT_PORTONE_V2_API_SECRET'), fetcher: providerFetch, timeoutMs: 12_000 }),
    }).advance(jobId, owner),
  removeFiles: async (database, paths) => {
    const result = await (database as any).storage.from(PRINT_BUCKET).remove(paths)
    return !result.error
  },
  })(request)
})

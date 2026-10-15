import { adminClient, getUser } from '../_shared/supabase.ts'
import { createPrintFulfillmentWorkerHandler } from '../_shared/print-fulfillment-worker.ts'
import { RedprintingFulfillmentClient } from '../_shared/print-fulfillment-vendor.ts'
import { RedprintingError, type RedprintingSettings } from '../_shared/redprinting.ts'

// Both the gateway's signed JWT and current Auth role are mandatory. Credentials
// are read only here; the renderer runner receives signed artwork URLs, no keys.
const bool = (name: string) => Deno.env.get(name) === 'true'
const check = (result: any) => { if (result.error) throw new RedprintingError('vendor_configuration_unavailable', 503); return result.data }
const pause = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))
async function acquireRate(db: any) {
  const owner = crypto.randomUUID(), started = Date.now()
  for (;;) {
    // This shared account limiter is also used by development tools. It admits
    // no more than two calls a second across concurrent workers and dashboards.
    const delay = Number(check(await db.rpc('redprinting_dev_acquire_slot', { p_owner: owner })))
    if (delay === 0) break
    if (!Number.isFinite(delay) || delay < 0 || Date.now() - started > 10_000) throw new RedprintingError('vendor_api_busy', 429)
    await pause(Math.min(delay, 1200))
  }
  return async () => { check(await db.rpc('redprinting_dev_release_slot', { p_owner: owner })) }
}

Deno.serve(createPrintFulfillmentWorkerHandler({
  getUser, createAdminDatabase: adminClient,
  configuration: () => ({ enabled: bool('PRINT_FULFILLMENT_ENABLED'), environment: Deno.env.get('PRINT_PORTONE_ENVIRONMENT') ?? 'disabled',
    depositEnabled: bool('PRINT_REDP_DEPOSIT_ENABLED'), supabaseUrl: Deno.env.get('SUPABASE_URL') ?? '',
    paymentApiSecret: Deno.env.get('PRINT_PORTONE_V2_API_SECRET') ?? '',
    deliverySecret: Deno.env.get('PRINT_ORDER_SCHEDULER_SECRET') ?? '',
    vendorReady: bool('PRINT_REDP_PRODUCTION_ENABLED') && bool('PRINT_REDP_PRODUCTION_APPROVED') &&
      Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID')) && Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY')) }),
  vendor: db => new RedprintingFulfillmentClient({ enabled: bool('PRINT_REDP_PRODUCTION_ENABLED'),
    environment: bool('PRINT_REDP_PRODUCTION_ENABLED') ? 'production' : 'disabled',
    productionApproved: bool('PRINT_REDP_PRODUCTION_APPROVED'), depositEnabled: bool('PRINT_REDP_DEPOSIT_ENABLED'),
    userId: Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID') ?? '', apiKey: Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY') ?? '',
  }, () => acquireRate(db)),
  sender: async db => {
    const row = check(await db.from('redprinting_dev_settings').select('sender_name,sender_tel,sender_zipcode,sender_address,sender_address_detail').eq('id', 1).single())
    return { senderName: row.sender_name, senderTel: row.sender_tel, senderZipcode: row.sender_zipcode,
      senderAddress: row.sender_address, senderAddressDetail: row.sender_address_detail } as RedprintingSettings
  },
}))

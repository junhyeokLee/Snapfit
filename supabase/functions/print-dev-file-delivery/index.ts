import { adminClient } from '../_shared/supabase.ts'
import { createPrintFileDeliveryHandler } from '../_shared/print-file-delivery.ts'

// Separate TEST/DEV receipt authority and HMAC namespace. Production downloads
// keep the original LIVE-only RPC; neither endpoint accepts an environment flag.
Deno.serve(createPrintFileDeliveryHandler({
  development: true,
  secret: () => Deno.env.get('PRINT_DEV_CHECKOUT_ENABLED') === 'true' ? Deno.env.get('PRINT_ORDER_SCHEDULER_SECRET') ?? '' : '',
  supabaseUrl: () => Deno.env.get('SUPABASE_URL') ?? '',
  createAdminDatabase: adminClient,
}))

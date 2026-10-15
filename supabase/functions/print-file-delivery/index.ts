import { adminClient } from '../_shared/supabase.ts'
import { createPrintFileDeliveryHandler } from '../_shared/print-file-delivery.ts'

// Redprinting downloads a normal URL and cannot attach a customer JWT. A
// one-hour HMAC tied to a paid immutable package replaces gateway JWT here.
// The service-only read RPC repeats receipt/package/hold checks on every GET.
Deno.serve(createPrintFileDeliveryHandler({
  secret: () => Deno.env.get('PRINT_ORDER_SCHEDULER_SECRET') ?? '',
  supabaseUrl: () => Deno.env.get('SUPABASE_URL') ?? '',
  createAdminDatabase: adminClient,
}))

import { getUser, adminClient } from '../_shared/supabase.ts'
import { createPrintPaymentTestHandler } from '../_shared/print-payment-test.ts'

// Test-only server configuration. No key or raw provider response is returned.
Deno.serve(createPrintPaymentTestHandler({
  getUser,
  createAdminDatabase: adminClient,
  configuration: () => ({
    environment: Deno.env.get('PRINT_PORTONE_ENVIRONMENT') ?? 'disabled',
    storeId: Deno.env.get('PRINT_PORTONE_STORE_ID') ?? '',
    channelKey: Deno.env.get('PRINT_PORTONE_CHANNEL_KEY') ?? '',
    apiSecret: Deno.env.get('PRINT_PORTONE_V2_API_SECRET') ?? '',
  }),
}))

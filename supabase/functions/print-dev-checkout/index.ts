import { adminClient, getUser } from '../_shared/supabase.ts'
import { createPrintDevCheckoutHandler } from '../_shared/print-dev-checkout.ts'

Deno.serve(createPrintDevCheckoutHandler({
  getUser, createAdminDatabase: adminClient,
  configuration: () => ({
    enabled: Deno.env.get('PRINT_DEV_CHECKOUT_ENABLED') === 'true',
    paymentEnvironment: Deno.env.get('PRINT_PORTONE_ENVIRONMENT') ?? 'disabled',
    storeId: Deno.env.get('PRINT_PORTONE_STORE_ID') ?? '',
    channelKey: Deno.env.get('PRINT_PORTONE_CHANNEL_KEY') ?? '',
    supabaseUrl: Deno.env.get('SUPABASE_URL') ?? '',
    vendor: { environment: Deno.env.get('REDPRINTING_ENVIRONMENT') ?? 'disabled',
      enabled: Deno.env.get('REDPRINTING_ENABLED') === 'true',
      userId: Deno.env.get('REDPRINTING_USER_ID') ?? '',
      apiKey: Deno.env.get('REDPRINTING_DEV_API_KEY') ?? '',
      expiresAt: Deno.env.get('REDPRINTING_DEV_KEY_EXPIRES_AT') ?? '' },
  }),
}))

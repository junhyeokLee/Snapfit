import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.4'
import { createPrintCheckoutStatusHandler } from '../_shared/print-checkout.ts'

// This endpoint needs only the public client key. The caller's Authorization
// header scopes both getUser and the quotation RPC; no privileged client exists.
Deno.serve(createPrintCheckoutStatusHandler((request) => {
  const url = Deno.env.get('SUPABASE_URL')
  const clientKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !clientKey) throw new Error('print_checkout_configuration_missing')
  return createClient(url, clientKey, {
    global: { headers: { Authorization: request.headers.get('Authorization') ?? '' } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
}))

import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  return jsonResponse({
    error: 'native_iap_required',
    message: 'Mobile subscriptions are handled through Google Play Billing / App Store and iap-verify. Legacy external subscription billing is disabled.',
  }, 410)
})

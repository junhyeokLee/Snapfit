import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  return jsonResponse({
    error: 'legacy_billing_disabled',
    message: 'Subscriptions are not offered. Consumable points use Google Play Billing / App Store with iap-verify. This legacy billing endpoint is disabled.',
  }, 410)
})

import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

// External physical-order payments have been removed. Keep a non-mutating
// response for older clients; point purchases use the native store IAP flow.
Deno.serve((req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  return jsonResponse({ error: 'physical_order_payments_disabled' }, 410)
})

import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  // TODO: port Snapfit-BackEnd webhook signature verification and replay guard.
  return jsonResponse({ ok: false, error: 'billing_webhook_not_implemented_yet' }, 501)
})

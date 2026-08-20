import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  // TODO: port print package generation/PDF/ZIP/vendor submission from Snapfit-BackEnd OrderService.
  return jsonResponse({ ok: false, error: 'order_confirm_payment_not_implemented_yet' }, 501)
})

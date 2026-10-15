import { adminClient, getUser } from '../_shared/supabase.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { RedprintingAdmin } from '../_shared/redprinting-admin.ts'
import { RedprintingError, type RedprintingEnvironment } from '../_shared/redprinting.ts'
import { OrderPaymentError } from '../_shared/order-types.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError } from '../_shared/redprinting-admin-auth.ts'

const headers = { ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers })

function environment(): RedprintingEnvironment {
  return { environment: Deno.env.get('REDPRINTING_ENVIRONMENT') ?? 'disabled', enabled: Deno.env.get('REDPRINTING_ENABLED') === 'true',
    userId: Deno.env.get('REDPRINTING_USER_ID') ?? '', apiKey: Deno.env.get('REDPRINTING_DEV_API_KEY') ?? '',
    expiresAt: Deno.env.get('REDPRINTING_DEV_KEY_EXPIRES_AT') ?? '' }
}

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  try {
    const actor = await assertRedprintingAdmin(req, getUser)
    const body = await req.json().catch(() => null)
    if (!body || typeof body !== 'object' || Array.isArray(body)) return json({ error: 'invalid_body' }, 400)
    const admin = new RedprintingAdmin(adminClient(), environment(), actor)
    return json(await admin.action(String(body.action ?? '').trim(), body))
  } catch (error) {
    // Vendor replies can echo credentials, signed URLs, or recipient data.
    // Return only internal stable codes; never log the raw error object/body.
    if (error instanceof RedprintingAdminAuthError) return json({ error: error.code }, error.status)
    if (error instanceof RedprintingError) return json({ error: error.code, uncertain: error.uncertain }, error.status)
    if (error instanceof OrderPaymentError) {
      const code = error.message
      if (/^print_[a-z0-9_]+$|^invalid_print_[a-z0-9_]+$|^encrypted_print_pdf$|^active_print_pdf_not_allowed$/.test(code)) return json({ error: code }, Number(error.status) || 409)
    }
    return json({ error: 'redprinting_operation_failed' }, 503)
  }
})

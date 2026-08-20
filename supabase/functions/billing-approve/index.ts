import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({}))
    const orderId = String(body.orderId ?? '').trim()
    if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
    const supabase = adminClient()
    const { data: order, error } = await supabase
      .from('billing_orders')
      .select('*')
      .eq('order_id', orderId)
      .eq('user_id', user.id)
      .single()
    if (error || !order) return jsonResponse({ error: 'order_not_found' }, 404)
    if (order.status === 'APPROVED') return jsonResponse(await subscriptionStatus(supabase, user.id))
    if (order.status !== 'READY') return jsonResponse({ error: 'order_not_ready' }, 409)

    // TODO: real Toss/Inicis verification. Current implementation mirrors backend mock-mode.
    if (Deno.env.get('SNAPFIT_BILLING_MOCK_MODE') === 'false') {
      return jsonResponse({ error: 'real_payment_provider_not_configured' }, 501)
    }

    const now = new Date()
    const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60_000)
    await supabase.from('billing_orders').update({
      status: 'APPROVED',
      transaction_id: body.paymentKey ?? body.transactionId ?? `MOCK-${Date.now()}`,
      reserve_id: body.reserveId ?? null,
      approved_at: now.toISOString(),
    }).eq('order_id', orderId)

    await supabase.from('subscriptions').upsert({
      user_id: user.id,
      plan_code: order.plan_code,
      status: 'ACTIVE',
      started_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      next_billing_at: expiresAt.toISOString(),
      last_order_id: orderId,
    })

    await supabase.from('orders').update({
      status: 'PAYMENT_COMPLETED',
      progress: 0.32,
      payment_confirmed_at: now.toISOString(),
    }).eq('order_id', orderId).eq('user_id', user.id)

    return jsonResponse(await subscriptionStatus(supabase, user.id))
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})

async function subscriptionStatus(supabase: ReturnType<typeof adminClient>, userId: string) {
  const { data } = await supabase.from('subscriptions').select('*').eq('user_id', userId).maybeSingle()
  return {
    userId,
    planCode: data?.plan_code ?? null,
    status: data?.status ?? 'INACTIVE',
    startedAt: data?.started_at ?? null,
    expiresAt: data?.expires_at ?? null,
    nextBillingAt: data?.next_billing_at ?? null,
    isActive: data?.status === 'ACTIVE',
  }
}

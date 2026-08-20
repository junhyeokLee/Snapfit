import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

const PLAN_PRO_MONTHLY = 'SNAPFIT_PRO_MONTHLY'

function buildOrderId(provider: string) {
  const prefix = provider.includes('INICIS') ? 'INI' : 'TOS'
  return `${prefix}-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({}))
    const planCode = body.planCode ?? PLAN_PRO_MONTHLY
    const provider = body.provider ?? 'TOSS_NAVERPAY'
    const supabase = adminClient()

    const { data: plan, error: planError } = await supabase
      .from('billing_plans')
      .select('*')
      .eq('plan_code', planCode)
      .single()
    if (planError || !plan) return jsonResponse({ error: 'plan_not_found' }, 404)

    const orderId = buildOrderId(provider)
    const publicBaseUrl = Deno.env.get('SNAPFIT_PUBLIC_FUNCTION_BASE_URL') ?? ''
    const checkoutUrl = publicBaseUrl
      ? `${publicBaseUrl}/functions/v1/billing-approve?orderId=${encodeURIComponent(orderId)}`
      : ''

    const { error: insertError } = await supabase.from('billing_orders').insert({
      order_id: orderId,
      user_id: user.id,
      plan_code: plan.plan_code,
      provider,
      status: 'READY',
      amount: plan.amount,
      currency: plan.currency,
      checkout_url: checkoutUrl,
    })
    if (insertError) throw insertError

    await supabase.from('orders').insert({
      order_id: orderId,
      user_id: user.id,
      title: 'SnapFit Pro 월간 구독',
      amount: plan.amount,
      status: 'PAYMENT_PENDING',
      progress: 0.18,
    })

    return jsonResponse({
      orderId,
      planCode: plan.plan_code,
      provider,
      amount: plan.amount,
      currency: plan.currency,
      checkoutUrl,
      successUrl: `snapfit://billing/success?orderId=${encodeURIComponent(orderId)}`,
      failUrl: `snapfit://billing/fail?orderId=${encodeURIComponent(orderId)}`,
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
      isMock: Deno.env.get('SNAPFIT_BILLING_MOCK_MODE') !== 'false',
    })
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})

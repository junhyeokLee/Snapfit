import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

const allowedProviders = new Set(['TOSS_PAYMENTS', 'NAVERPAY', 'KG_INICIS'])

function text(value: unknown) {
  return String(value ?? '').trim()
}

function appendQuery(base: string, query: Record<string, string>) {
  const url = new URL(base)
  for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value)
  return url.toString()
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)

  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({})) as Record<string, unknown>
    const orderId = text(body.orderId)
    const provider = text(body.provider).toUpperCase()
    if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
    if (!allowedProviders.has(provider)) return jsonResponse({ error: 'unsupported_payment_provider' }, 400)

    const supabase = adminClient()
    const { data: order, error } = await supabase
      .from('orders')
      .select('*')
      .eq('order_id', orderId)
      .maybeSingle()
    if (error) throw error
    if (!order) return jsonResponse({ error: 'order_not_found' }, 404)
    if (order.user_id !== user.id && user.app_metadata?.role !== 'admin') {
      return jsonResponse({ error: 'forbidden' }, 403)
    }
    if (String(order.status ?? '') !== 'PAYMENT_PENDING') {
      return jsonResponse({ error: 'order_not_payable', status: order.status }, 409)
    }

    const checkoutBaseUrl = text(Deno.env.get('SNAPFIT_ORDER_CHECKOUT_BASE_URL'))
    if (!checkoutBaseUrl) {
      return jsonResponse({
        error: 'order_checkout_provider_not_configured',
        message: 'SNAPFIT_ORDER_CHECKOUT_BASE_URL is required before external order payments can be opened.',
      }, 503)
    }

    const returnUrl = text(body.returnUrl) || `snapfit://order/success?orderId=${encodeURIComponent(orderId)}`
    const failUrl = text(body.failUrl) || `snapfit://order/fail?orderId=${encodeURIComponent(orderId)}`
    const checkoutUrl = appendQuery(checkoutBaseUrl, {
      orderId,
      provider,
      amount: String(order.amount ?? 0),
      title: String(order.title ?? 'SnapFit 주문'),
      returnUrl,
      failUrl,
    })

    return jsonResponse({ checkoutUrl })
  } catch (e) {
    const message = String(e?.message ?? e)
    return jsonResponse({ error: message }, message.includes('Unauthorized') ? 401 : 500)
  }
})

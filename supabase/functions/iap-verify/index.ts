import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({}))
    const platform = String(body.platform ?? '').toUpperCase()
    const productId = String(body.productId ?? '').trim()
    const transactionId = String(body.transactionId ?? '').trim()
    const requestedPlanCode = String(body.planCode ?? 'SNAPFIT_PRO_MONTHLY').trim()
    const purchaseToken = body.purchaseToken?.toString()
    const receiptData = body.receiptData?.toString()
    if (!['GOOGLE_PLAY', 'APP_STORE'].includes(platform)) return jsonResponse({ error: 'invalid_platform' }, 400)
    if (!productId || !transactionId) return jsonResponse({ error: 'productId_transactionId_required' }, 400)
    const productPlanMap: Record<string, string> = {
      snapfit_pro_monthly: 'SNAPFIT_PRO_MONTHLY',
      SNAPFIT_PRO_MONTHLY: 'SNAPFIT_PRO_MONTHLY',
    }
    const planCode = productPlanMap[productId] ?? requestedPlanCode

    // TODO: Real verification:
    // - GOOGLE_PLAY: Android Publisher API purchases.subscriptionsv2.get
    // - APP_STORE: App Store Server API transaction/receipt verification
    // For now, only allow mock verification when explicitly enabled.
    if (Deno.env.get('SNAPFIT_IAP_MOCK_VERIFY') !== 'true') {
      return jsonResponse({ error: 'iap_provider_verification_not_configured' }, 501)
    }

    const supabase = adminClient()
    const now = new Date()
    const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60_000)
    const receiptHash = receiptData
      ? Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(receiptData))))
          .map((b) => b.toString(16).padStart(2, '0')).join('')
      : null

    const { error: purchaseError } = await supabase.from('store_purchases').upsert({
      user_id: user.id,
      platform,
      product_id: productId,
      transaction_id: transactionId,
      original_transaction_id: body.originalTransactionId ?? transactionId,
      purchase_token: purchaseToken ?? null,
      receipt_hash: receiptHash,
      status: 'VERIFIED',
      plan_code: planCode,
      purchased_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      raw_response: { mock: true },
    }, { onConflict: 'platform,transaction_id' })
    if (purchaseError) throw purchaseError

    await supabase.from('subscriptions').upsert({
      user_id: user.id,
      plan_code: planCode,
      status: 'ACTIVE',
      started_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      next_billing_at: expiresAt.toISOString(),
      last_order_id: transactionId,
    })

    return jsonResponse({
      userId: user.id,
      planCode: planCode,
      status: 'ACTIVE',
      startedAt: now.toISOString(),
      expiresAt: expiresAt.toISOString(),
      nextBillingAt: expiresAt.toISOString(),
      isActive: true,
    })
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})

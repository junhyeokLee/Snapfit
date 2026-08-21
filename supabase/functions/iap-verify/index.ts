import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

type VerificationResult = {
  platform: 'GOOGLE_PLAY' | 'APP_STORE'
  productId: string
  transactionId: string
  originalTransactionId: string
  status: 'VERIFIED' | 'EXPIRED' | 'REFUNDED' | 'FAILED'
  purchasedAt: string
  expiresAt: string | null
  rawResponse: Record<string, unknown>
}

const text = (value: unknown) => String(value ?? '').trim()

function base64UrlEncode(input: Uint8Array | string) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function base64UrlDecodeJson(segment: string): Record<string, unknown> {
  const normalized = segment.replace(/-/g, '+').replace(/_/g, '/')
  const padded = normalized + '='.repeat((4 - normalized.length % 4) % 4)
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return JSON.parse(new TextDecoder().decode(bytes))
}

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('')
}

function productPlanCode(productId: string, requestedPlanCode: string) {
  const defaultMap: Record<string, string> = {
    snapfit_pro_monthly: 'SNAPFIT_PRO_MONTHLY',
    SNAPFIT_PRO_MONTHLY: 'SNAPFIT_PRO_MONTHLY',
  }
  const configured = text(Deno.env.get('SNAPFIT_IAP_PRODUCT_PLAN_MAP'))
  if (configured) {
    try {
      return { ...defaultMap, ...JSON.parse(configured) }[productId] ?? requestedPlanCode
    } catch (_e) {
      console.warn('Invalid SNAPFIT_IAP_PRODUCT_PLAN_MAP; using defaults')
    }
  }
  return defaultMap[productId] ?? requestedPlanCode
}

async function importGooglePrivateKey(pem: string) {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const binary = atob(body)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

async function signGoogleJwt(serviceAccount: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`
  const key = await importGooglePrivateKey(serviceAccount.private_key)
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput))
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`
}

async function googleAccessToken() {
  const rawJson = text(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'))
  const clientEmail = text(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL'))
  const privateKey = text(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY')).replace(/\\n/g, '\n')
  const serviceAccount = rawJson
    ? JSON.parse(rawJson)
    : { client_email: clientEmail, private_key: privateKey }
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new Error('google_play_credentials_not_configured')
  }
  const assertion = await signGoogleJwt(serviceAccount)
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(`google_oauth_failed:${JSON.stringify(data)}`)
  return text(data.access_token)
}

async function verifyGooglePlay(body: Record<string, unknown>): Promise<VerificationResult> {
  const packageName = text(body.packageName || Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME'))
  const productId = text(body.productId)
  const purchaseToken = text(body.purchaseToken)
  if (!packageName) throw new Error('google_play_package_name_required')
  if (!purchaseToken) throw new Error('purchaseToken_required')

  const token = await googleAccessToken()
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`
  const response = await fetch(url, { headers: { authorization: `Bearer ${token}` } })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(`google_play_verify_failed:${response.status}:${JSON.stringify(data)}`)

  const lineItems = Array.isArray(data.lineItems) ? data.lineItems : []
  const matchingItem = lineItems.find((item: Record<string, unknown>) => {
    const offerDetails = item?.offerDetails as Record<string, unknown> | undefined
    return text(item?.productId || offerDetails?.basePlanId || offerDetails?.offerId) === productId || text(item?.productId) === productId
  }) ?? lineItems[0] ?? {}
  const expiry = text((matchingItem as Record<string, unknown>).expiryTime)
  const start = text(data.startTime) || new Date().toISOString()
  const state = text(data.subscriptionState)
  const acknowledgementState = text(data.acknowledgementState)
  const canceled = Boolean(data.canceledStateContext)
  const expired = expiry ? new Date(expiry).getTime() <= Date.now() : false
  const validStates = new Set(['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_ON_HOLD'])
  const status: VerificationResult['status'] = canceled
    ? 'REFUNDED'
    : expired
      ? 'EXPIRED'
      : validStates.has(state) || acknowledgementState === 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
        ? 'VERIFIED'
        : 'FAILED'

  return {
    platform: 'GOOGLE_PLAY',
    productId,
    transactionId: text(body.transactionId) || text(data.latestOrderId) || purchaseToken,
    originalTransactionId: text(body.originalTransactionId) || text(data.latestOrderId) || purchaseToken,
    status,
    purchasedAt: start,
    expiresAt: expiry || null,
    rawResponse: data,
  }
}

async function importApplePrivateKey(pem: string) {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const binary = atob(body)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
}

async function appleServerJwt() {
  const issuerId = text(Deno.env.get('APP_STORE_ISSUER_ID'))
  const keyId = text(Deno.env.get('APP_STORE_KEY_ID'))
  const bundleId = text(Deno.env.get('APP_STORE_BUNDLE_ID'))
  const privateKey = text(Deno.env.get('APP_STORE_PRIVATE_KEY')).replace(/\\n/g, '\n')
  if (!issuerId || !keyId || !bundleId || !privateKey) throw new Error('app_store_credentials_not_configured')
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' }
  const payload = { iss: issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1', bid: bundleId }
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`
  const key = await importApplePrivateKey(privateKey)
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(signingInput))
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`
}

async function fetchAppleTransaction(transactionId: string, bearer: string) {
  const env = text(Deno.env.get('APP_STORE_ENVIRONMENT')).toLowerCase()
  const bases = env === 'sandbox'
    ? ['https://api.storekit-sandbox.itunes.apple.com']
    : env === 'production'
      ? ['https://api.storekit.itunes.apple.com']
      : ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com']
  let lastError = ''
  for (const base of bases) {
    const response = await fetch(`${base}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { authorization: `Bearer ${bearer}` },
    })
    const data = await response.json().catch(() => ({}))
    if (response.ok) return data
    lastError = `${response.status}:${JSON.stringify(data)}`
  }
  throw new Error(`app_store_verify_failed:${lastError}`)
}

async function verifyAppStore(body: Record<string, unknown>): Promise<VerificationResult> {
  const transactionId = text(body.transactionId)
  if (!transactionId) throw new Error('transactionId_required')
  const bearer = await appleServerJwt()
  const data = await fetchAppleTransaction(transactionId, bearer)
  const signed = text(data.signedTransactionInfo)
  if (!signed) throw new Error('app_store_missing_signed_transaction_info')
  const payload = base64UrlDecodeJson(signed.split('.')[1] ?? '')
  const expectedBundleId = text(Deno.env.get('APP_STORE_BUNDLE_ID'))
  const productId = text(payload.productId)
  const requestedProductId = text(body.productId)
  const bundleId = text(payload.bundleId)
  if (expectedBundleId && bundleId !== expectedBundleId) throw new Error('app_store_bundle_id_mismatch')
  if (requestedProductId && productId !== requestedProductId) throw new Error('app_store_product_id_mismatch')

  const expiresMs = Number(payload.expiresDate ?? 0)
  const purchasedMs = Number(payload.purchaseDate ?? Date.now())
  const revoked = Boolean(payload.revocationDate)
  const expired = expiresMs > 0 && expiresMs <= Date.now()
  const status: VerificationResult['status'] = revoked ? 'REFUNDED' : expired ? 'EXPIRED' : 'VERIFIED'
  return {
    platform: 'APP_STORE',
    productId,
    transactionId: text(payload.transactionId) || transactionId,
    originalTransactionId: text(payload.originalTransactionId) || transactionId,
    status,
    purchasedAt: new Date(purchasedMs).toISOString(),
    expiresAt: expiresMs > 0 ? new Date(expiresMs).toISOString() : null,
    rawResponse: { appStoreResponse: data, transactionPayload: payload },
  }
}

async function mockVerification(body: Record<string, unknown>): Promise<VerificationResult> {
  const now = new Date()
  const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60_000)
  const platform = text(body.platform).toUpperCase() as 'GOOGLE_PLAY' | 'APP_STORE'
  return {
    platform,
    productId: text(body.productId),
    transactionId: text(body.transactionId),
    originalTransactionId: text(body.originalTransactionId) || text(body.transactionId),
    status: 'VERIFIED',
    purchasedAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    rawResponse: { mock: true },
  }
}

async function verifyPurchase(body: Record<string, unknown>) {
  const platform = text(body.platform).toUpperCase()
  if (!['GOOGLE_PLAY', 'APP_STORE'].includes(platform)) throw new Error('invalid_platform')
  if (!text(body.productId) || !text(body.transactionId)) throw new Error('productId_transactionId_required')

  if (Deno.env.get('SNAPFIT_IAP_MOCK_VERIFY') === 'true') return mockVerification(body)
  if (platform === 'GOOGLE_PLAY') return verifyGooglePlay(body)
  return verifyAppStore(body)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({})) as Record<string, unknown>
    const requestedPlanCode = text(body.planCode) || 'SNAPFIT_PRO_MONTHLY'
    const verification = await verifyPurchase(body)
    const planCode = productPlanCode(verification.productId, requestedPlanCode)
    const receiptSource = text(body.receiptData) || text(body.purchaseToken)
    const receiptHash = receiptSource ? await sha256Hex(receiptSource) : null
    const supabase = adminClient()

    const { error: purchaseError } = await supabase.from('store_purchases').upsert({
      user_id: user.id,
      platform: verification.platform,
      product_id: verification.productId,
      transaction_id: verification.transactionId,
      original_transaction_id: verification.originalTransactionId,
      purchase_token: text(body.purchaseToken) || null,
      receipt_hash: receiptHash,
      status: verification.status,
      plan_code: planCode,
      purchased_at: verification.purchasedAt,
      expires_at: verification.expiresAt,
      raw_response: verification.rawResponse,
      fail_reason: verification.status === 'VERIFIED' ? null : verification.status.toLowerCase(),
    }, { onConflict: 'platform,transaction_id' })
    if (purchaseError) throw purchaseError

    if (verification.status !== 'VERIFIED') {
      return jsonResponse({
        userId: user.id,
        planCode,
        status: verification.status,
        startedAt: verification.purchasedAt,
        expiresAt: verification.expiresAt,
        nextBillingAt: verification.expiresAt,
        isActive: false,
      })
    }

    const expiresAt = verification.expiresAt ?? new Date(Date.now() + 30 * 24 * 60 * 60_000).toISOString()
    const { error: subscriptionError } = await supabase.from('subscriptions').upsert({
      user_id: user.id,
      plan_code: planCode,
      status: 'ACTIVE',
      started_at: verification.purchasedAt,
      expires_at: expiresAt,
      next_billing_at: expiresAt,
      last_order_id: verification.transactionId,
    })
    if (subscriptionError) throw subscriptionError

    return jsonResponse({
      userId: user.id,
      planCode,
      status: 'ACTIVE',
      startedAt: verification.purchasedAt,
      expiresAt,
      nextBillingAt: expiresAt,
      isActive: true,
    })
  } catch (e) {
    console.error(e)
    const message = String(e?.message ?? e)
    const status = message.includes('Unauthorized') ? 401
      : message.includes('required') || message.includes('invalid_') || message.includes('mismatch') ? 400
        : message.includes('not_configured') ? 503
          : 500
    return jsonResponse({ error: message }, status)
  }
})

import { adminClient, getUser } from './supabase.ts'
import { corsHeaders } from './cors.ts'
import { observeWebPointPayment, pointRecord, readPointBody, WebPointError } from './web-point-topup-provider.ts'

// Source release gate. An environment switch cannot enable live checkout.
export const WEB_POINT_TOPUP_LIVE_RELEASED = false;
const approvedTestRoute = {
  storeId: 'store-33df409e-0ad9-4953-8194-70db7e32efae',
  channelKey: 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88',
};
type Database = ReturnType<typeof adminClient>;
const uuid = (v: unknown): v is string => typeof v === 'string' &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v);
const paymentId = (v: unknown): v is string => typeof v === 'string' && /^SFPT[TL]_/.test(v) && uuid(v.slice(6));
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) > 0;
const response = (body: unknown, status = 200) => Response.json(body, {
  status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
});
const configuration = () => ({
  testEnabled: Deno.env.get('WEB_POINT_TOPUP_TEST_ENABLED') === 'true',
  environment: Deno.env.get('PRINT_PORTONE_ENVIRONMENT') ?? 'disabled',
  storeId: Deno.env.get('PRINT_PORTONE_STORE_ID') ?? '',
  channelKey: Deno.env.get('PRINT_PORTONE_CHANNEL_KEY') ?? '',
  apiSecret: Deno.env.get('PRINT_PORTONE_V2_API_SECRET') ?? '',
  liveEnabled: Deno.env.get('WEB_POINT_TOPUP_LIVE_ENABLED') === 'true',
  liveStoreId: Deno.env.get('WEB_POINT_TOPUP_LIVE_STORE_ID') ?? '',
  liveChannelKey: Deno.env.get('WEB_POINT_TOPUP_LIVE_CHANNEL_KEY') ?? '',
  liveApiSecret: Deno.env.get('WEB_POINT_TOPUP_LIVE_API_SECRET') ?? '',
});
type Configuration = ReturnType<typeof configuration>;
function testReady(config: Configuration) {
  return config.testEnabled && config.environment === 'test' &&
    config.storeId === approvedTestRoute.storeId && config.channelKey === approvedTestRoute.channelKey &&
    /^[\x21-\x7e]{8,2048}$/.test(config.apiSecret);
}
function liveObservable(config: Configuration) {
  return WEB_POINT_TOPUP_LIVE_RELEASED && /^store-[A-Za-z0-9-]{8,100}$/.test(config.liveStoreId) &&
    /^channel-key-[A-Za-z0-9-]{8,100}$/.test(config.liveChannelKey) &&
    config.liveChannelKey !== approvedTestRoute.channelKey && /^[\x21-\x7e]{8,2048}$/.test(config.liveApiSecret);
}
function storedRoute(config: Configuration, environment: unknown) {
  if (environment === 'test' && testReady(config)) return { storeId: config.storeId, channelKey: config.channelKey, apiSecret: config.apiSecret };
  // Closing new sales must not disable observation of already-paid live orders.
  if (environment === 'live' && liveObservable(config)) return { storeId: config.liveStoreId, channelKey: config.liveChannelKey, apiSecret: config.liveApiSecret };
  return null;
}
type Permission = { test: boolean; live: boolean };
const safeCodes = new Set(['web_point_not_found','web_point_pending_exists','web_point_request_conflict',
  'web_point_product_unavailable','web_point_price_changed','web_point_launch_not_available',
  'web_point_receipt_invalid','web_point_receipt_conflict','web_point_review_required','web_point_live_closed']);
async function rpc(db: Database, name: string, input: Record<string, unknown>) {
  const result = await db.rpc(name, input);
  if (result.error) {
    const code = safeCodes.has(result.error.message) ? result.error.message : 'web_point_storage_unavailable';
    throw new WebPointError(code, code === 'web_point_not_found' ? 404 : code === 'web_point_storage_unavailable' ? 503 : 409);
  }
  return result.data;
}
async function ownedRow(db: Database, id: string, owner?: string) {
  let query = db.from('web_point_topups').select('*').eq('payment_id', id);
  if (owner != null) query = query.eq('owner_id', owner);
  const result = await query.maybeSingle();
  if (result.error) throw new WebPointError('web_point_storage_unavailable', 503);
  if (!result.data) throw new WebPointError('web_point_not_found', 404);
  return pointRecord(result.data);
}
function publicSession(row: Record<string, unknown>, permission: Permission = { test: false, live: false }) {
  const isTest = row.environment === 'test';
  if (!paymentId(row.payment_id) || !['test','live'].includes(String(row.environment)) || row.currency !== 'KRW' ||
      (isTest && (row.store_id !== approvedTestRoute.storeId || row.channel_key !== approvedTestRoute.channelKey || !String(row.payment_id).startsWith('SFPTT_'))) ||
      (!isTest && (row.channel_key === approvedTestRoute.channelKey || !String(row.payment_id).startsWith('SFPTL_') ||
        !/^store-[A-Za-z0-9-]{8,100}$/.test(String(row.store_id)) || !/^channel-key-[A-Za-z0-9-]{8,100}$/.test(String(row.channel_key)))) ||
      !integer(row.points) || !integer(row.total_amount)) throw new WebPointError('web_point_record_invalid', 503);
  return { paymentId: row.payment_id, ownerId: row.owner_id, environment: row.environment, isTest,
    productionApproved: !isTest && WEB_POINT_TOPUP_LIVE_RELEASED, productId: row.product_id, title: row.title, points: row.points,
    totalAmount: row.total_amount, currency: 'KRW', status: row.status,
    storeId: row.store_id, channelKey: row.channel_key, createdAt: row.created_at,
    expiresAt: row.expires_at, sdkStartedAt: row.sdk_started_at, verifiedAt: row.verified_at,
    refundedAt: row.refunded_at,
    // Renew an unopened invoice in place; expiry never proves no charge.
    canLaunch: (isTest ? permission.test : permission.live) && row.status === 'PREPARED' && row.sdk_started_at == null,
    serverVerified: row.verified_at != null,
    testGrantedPoints: isTest && row.status === 'VERIFIED_TEST' ? row.points : 0,
    realPointsGranted: !isTest && row.status === 'CREDITED' ? row.points : 0 };
}

/** Idempotent observer shared by customer confirm, signed webhook and recovery.
 * status/history alone do not contact PG. A callback is never payment evidence.
 */
async function recover(db: Database, config: Configuration, id: string, owner?: string, requireFresh = false) {
  const current = await ownedRow(db, id, owner);
  const route = storedRoute(config, current.environment);
  if (!route || current.store_id !== route.storeId || current.channel_key !== route.channelKey) {
    return current;
  }
  const claim = pointRecord(await rpc(db, 'claim_web_point_topup_reconcile', {
    p_payment_id: id, p_owner: owner ?? null,
  }));
  if (!claim.payment_id) {
    // Do not consume a signed cancellation hint during a short lease/cooldown.
    // A retry must observe PG rather than wait for the daily paid reconciliation.
    if (requireFresh && current.sdk_started_at != null &&
        !['FAILED','VOIDED','REFUNDED'].includes(String(current.status))) {
      throw new WebPointError('web_point_observation_busy', 503);
    }
    return current;
  }
  let errorCode: string | null = null;
  try {
    const receipt = await observeWebPointPayment({ paymentId: id, storeId: String(claim.store_id),
      channelKey: String(claim.channel_key), totalAmount: Number(claim.total_amount), currency: 'KRW',
      environment: current.environment === 'test' ? 'test' : 'live' }, route.apiSecret);
    if (receipt) await rpc(db, 'apply_web_point_topup_observation', { p_payment_id: id, p_receipt: receipt });
  } catch (error) {
    errorCode = error instanceof WebPointError ? error.code : 'web_point_recovery_pending';
    throw error;
  } finally {
    await rpc(db, 'finish_web_point_topup_reconcile', { p_payment_id: id,
      p_lease_id: claim.reconcile_lease_id, p_error: errorCode });
  }
  return ownedRow(db, id, owner);
}

function fail(error: unknown) {
  return error instanceof WebPointError
    ? response({ error: error.code, liveCheckoutReleased: false }, error.status)
    : response({ error: 'web_point_unavailable', liveCheckoutReleased: false }, 503);
}
export async function handleWebPointTopup(request: Request) {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return response({ error: 'method_not_allowed' }, 405);
  try {
    if (!/^Bearer [^\s]+$/i.test(request.headers.get('Authorization') ?? '')) throw new WebPointError('authentication_required', 401);
    let user: Awaited<ReturnType<typeof getUser>>;
    try { user = await getUser(request); } catch { throw new WebPointError('invalid_session', 401); }
    const body = pointRecord(JSON.parse(await readPointBody(request, 4096))), action = body.action;
    const config = configuration(), canTest = user.app_metadata?.role === 'admin' && testReady(config);
    const canLive = config.liveEnabled && liveObservable(config), permission = { test: canTest, live: canLive };
    const db = adminClient();
    if (action === 'catalog' && Object.keys(body).length === 1) {
      const result = await db.from('point_products').select('product_id,title,points,amount,currency')
        .eq('is_active', true).eq('currency', 'KRW').gt('amount', 0).lte('amount', 1000000).order('amount').limit(50);
      if (result.error) throw new WebPointError('web_point_catalog_unavailable', 503);
      return response({ available: canLive || canTest, environment: canLive ? 'live' : canTest ? 'test' : 'disabled',
        testAvailable: canTest, liveAvailable: canLive,
        liveCheckoutReleased: WEB_POINT_TOPUP_LIVE_RELEASED, isTest: !canLive && canTest,
        products: (result.data ?? []).map(p => ({ productId: p.product_id, title: p.title,
          points: p.points, totalAmount: p.amount, currency: p.currency })) });
    }
    if (action === 'history' && Object.keys(body).length === 1) {
      const result = await db.from('web_point_topups').select('*').eq('owner_id', user.id)
        .order('created_at', { ascending: false }).limit(50);
      if (result.error) throw new WebPointError('web_point_storage_unavailable', 503);
      return response({ liveCheckoutReleased: WEB_POINT_TOPUP_LIVE_RELEASED,
        topups: (result.data ?? []).map(row => publicSession(pointRecord(row), permission)) });
    }
    if (action === 'prepare' && Object.keys(body).every(k => ['action','requestId','productId','expectedAmount','expectedPoints','environment'].includes(k)) &&
        uuid(body.requestId) && typeof body.productId === 'string' && /^[A-Za-z0-9_-]{1,100}$/.test(body.productId) &&
        integer(body.expectedAmount) && integer(body.expectedPoints)) {
      const environment = body.environment;
      if (environment !== 'test' && environment !== 'live' || !(environment === 'test' ? canTest : canLive)) throw new WebPointError('web_point_checkout_closed', 403);
      const route = storedRoute(config, environment)!;
      const row = pointRecord(await rpc(db, 'prepare_web_point_topup', { p_owner: user.id,
        p_request_id: body.requestId, p_product_id: body.productId, p_store_id: route.storeId,
        p_channel_key: route.channelKey, p_expected_amount: body.expectedAmount, p_expected_points: body.expectedPoints,
        p_environment: environment }));
      return response(publicSession(row, permission));
    }
    if (['status','confirm','launch'].includes(String(action)) &&
        Object.keys(body).every(k => ['action','paymentId'].includes(k)) && paymentId(body.paymentId)) {
      if (action === 'status') return response(publicSession(await ownedRow(db, body.paymentId, user.id), permission));
      if (action === 'launch') {
        const owned = await ownedRow(db, body.paymentId, user.id);
        const allowed = owned.environment === 'test' ? canTest : canLive;
        const route = storedRoute(config, owned.environment);
        if (!allowed || !route || owned.store_id !== route.storeId || owned.channel_key !== route.channelKey) throw new WebPointError('web_point_checkout_closed', 403);
        const row = pointRecord(await rpc(db, 'start_web_point_topup', { p_owner: user.id, p_payment_id: body.paymentId }));
        return response({ ...publicSession(row, permission), sdkLaunchAuthorized: true });
      }
      return response(publicSession(await recover(db, config, body.paymentId, user.id), permission));
    }
    throw new WebPointError('web_point_request_invalid', 400);
  } catch (error) {
    if (error instanceof SyntaxError) return response({ error: 'web_point_request_invalid' }, 400);
    return fail(error);
  }
}

// Standard Webhooks HMAC-SHA256. The exact raw body and attempt metadata are
// signed; a valid event remains only a hint to GET the stored payment from PG.
async function verifyWebhook(request: Request, raw: string, environment: 'test' | 'live') {
  const id = request.headers.get('webhook-id') ?? '', timestamp = request.headers.get('webhook-timestamp') ?? '';
  const signatures = request.headers.get('webhook-signature') ?? '';
  const secret = Deno.env.get(environment === 'test' ? 'WEB_POINT_TOPUP_WEBHOOK_SECRET' : 'WEB_POINT_TOPUP_LIVE_WEBHOOK_SECRET') ?? '';
  if (!/^[A-Za-z0-9_-]{1,200}$/.test(id) || !/^\d{1,12}$/.test(timestamp) ||
      Math.abs(Date.now() / 1000 - Number(timestamp)) > 300 || signatures.length > 2048 || !secret.startsWith('whsec_')) {
    throw new WebPointError('web_point_webhook_invalid', 401);
  }
  try {
    const bytes = Uint8Array.from(atob(secret.slice(6)), c => c.charCodeAt(0));
    if (bytes.length < 24 || bytes.length > 64) throw new Error();
    const key = await crypto.subtle.importKey('raw', bytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    for (const token of signatures.split(' ')) {
      const [version, encoded] = token.split(',');
      if (version !== 'v1' || !encoded) continue;
      let signature: Uint8Array; try { signature = Uint8Array.from(atob(encoded), c => c.charCodeAt(0)); } catch { continue; }
      if (await crypto.subtle.verify('HMAC', key, signature, new TextEncoder().encode(`${id}.${timestamp}.${raw}`))) return;
    }
  } catch { /* Secrets, raw bodies and provider messages never enter logs. */ }
  throw new WebPointError('web_point_webhook_invalid', 401);
}
export async function handleWebPointTopupWebhook(request: Request) {
  if (request.method !== 'POST') return response({ error: 'method_not_allowed' }, 405);
  try {
    const raw = await readPointBody(request, 65536);
    const event = pointRecord(JSON.parse(raw)), data = pointRecord(event.data);
    if (!paymentId(data.paymentId)) return response({ received: true, ignored: true });
    const environment = data.paymentId.startsWith('SFPTT_') ? 'test' : 'live';
    await verifyWebhook(request, raw, environment);
    if (!['Transaction.Paid','Transaction.Cancelled','Transaction.PartialCancelled','Transaction.Failed','Transaction.CancelPending'].includes(String(event.type))) {
      return response({ received: true, ignored: true });
    }
    const config = configuration(), route = storedRoute(config, environment);
    if (!route) throw new WebPointError('web_point_recovery_disabled', 503);
    if (data.storeId !== route.storeId) return response({ received: true, ignored: true });
    try { await recover(adminClient(), config, data.paymentId, undefined, true); }
    catch (error) { if (!(error instanceof WebPointError && error.code === 'web_point_not_found')) throw error; }
    return response({ received: true });
  } catch (error) { return fail(error); }
}

export async function handleWebPointTopupReconcile(request: Request) {
  if (request.method !== 'POST') return response({ error: 'method_not_allowed' }, 405);
  try {
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const dedicated = Deno.env.get('WEB_POINT_TOPUP_RECONCILE_SECRET') ?? '';
    const supplied = request.headers.get('Authorization') ?? '';
    const matches = (secret: string) => {
      if (!secret || supplied.length !== secret.length + 7) return false;
      const target = `Bearer ${secret}`; let difference = 0;
      for (let i = 0; i < target.length; i++) difference |= target.charCodeAt(i) ^ supplied.charCodeAt(i);
      return difference === 0;
    };
    if (!matches(serviceKey) && !(dedicated.length >= 32 && matches(dedicated))) throw new WebPointError('forbidden', 403);
    const body = pointRecord(JSON.parse(await readPointBody(request, 1024)));
    if (Object.keys(body).length !== 0) throw new WebPointError('web_point_request_invalid', 400);
    const config = configuration(), environments = [testReady(config) ? 'test' : null, liveObservable(config) ? 'live' : null].filter((v): v is string => v !== null);
    if (environments.length === 0) return response({ enabled: false, checked: 0 });
    const db = adminClient();
    const result = await db.from('web_point_topups').select('payment_id').in('environment', environments)
      .not('sdk_started_at', 'is', null).not('status', 'in', '(FAILED,VOIDED,REFUNDED)')
      .lte('reconcile_after', new Date().toISOString()).order('reconcile_after').limit(8);
    if (result.error) throw new WebPointError('web_point_storage_unavailable', 503);
    let checked = 0, pending = 0;
    for (const row of result.data ?? []) {
      try { await recover(db, config, row.payment_id); checked++; } catch { pending++; }
    }
    return response({ enabled: true, checked, pending, liveCheckoutReleased: false });
  } catch (error) { return fail(error); }
}

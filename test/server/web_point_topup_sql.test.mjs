// All state below belongs to a fresh in-memory PostgreSQL fixture. No production
// credentials, provider calls, prices, release gates or migrations are changed.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const migration = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8');
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const id = n => `aaaaaaaa-aaaa-4aaa-8aaa-${String(n).padStart(12, '0')}`;
const product = 'snapfit_points_2500';
const testStore = 'store-33df409e-0ad9-4953-8194-70db7e32efae';
const testChannel = 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88';
const liveStore = 'store-isolated-live-fixture';
const liveChannel = 'channel-key-isolated-live-fixture';

async function fixture({isolatedLiveBranch = false} = {}) {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema extensions;
    create function extensions.gen_random_uuid() returns uuid language sql as $$select pg_catalog.gen_random_uuid()$$;
    create table auth.users(id uuid primary key);
    insert into auth.users values('${a}'),('${b}');
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    -- Supabase's service role has these platform defaults and bypasses RLS.
    -- This does not replace any wallet, ledger or payment function under test.
    alter default privileges in schema public grant all on tables to service_role;
    alter default privileges in schema public grant all on sequences to service_role;
    create function public.is_admin() returns boolean language sql stable as $$select false$$;
    create function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end;$$;
    create table public.billing_plans(plan_code text primary key,title text,amount integer,currency text,provider text,is_active boolean not null default true);
    insert into public.billing_plans(plan_code) values('FREE'),('SNAPFIT_PRO_MONTHLY');
    create table public.subscriptions(user_id uuid primary key references auth.users,plan_code text references public.billing_plans,status text);
    insert into public.subscriptions values('${a}','SNAPFIT_PRO_MONTHLY','ACTIVE');
  `);
  for (const file of [
    '20260820161000_store_iap_entitlements.sql',
    '20260905113000_ai_album_points.sql',
    '20260905193000_ai_album_hybrid_pricing.sql',
    '20260905201000_fix_grant_point_purchase_ambiguity.sql',
    '20260905203000_ai_album_profit_pricing.sql',
    '20260905212500_fix_admin_point_operations_lint.sql',
    '20260908094449_point_only_iap_atomic_grants.sql',
    '20260908095746_point_purchase_refund_reconciliation.sql',
    '20261015101953_web_point_topup_preparation.sql',
  ]) await db.exec(migration(file));
  if (isolatedLiveBranch) {
    // Test-only branch coverage in this new DB. The migration remains select false.
    await db.exec(`create or replace function public.web_point_topup_live_release_ready()returns boolean
      language sql immutable security invoker set search_path='' as $$select true$$`);
  }
  await role(db, 'service_role');
  return db;
}
async function role(db, name = 'service_role', viewer = a) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [viewer ?? '']);
  await db.exec(`set role ${name}`);
}
const scalar = async (db, sql, args = []) => (await db.query(sql, args)).rows[0]?.value;
const prepare = (db, patch = {}) => scalar(db, 'select public.prepare_web_point_topup($1,$2,$3,$4,$5,$6,$7,$8)value', [
  patch.owner ?? a, patch.request ?? id(1), patch.product ?? product,
  patch.store ?? (patch.environment === 'live' ? liveStore : testStore),
  patch.channel ?? (patch.environment === 'live' ? liveChannel : testChannel),
  patch.amount ?? 2200, patch.points ?? 2500, patch.environment ?? 'test',
]);
const start = (db, row, owner = row.owner_id) => scalar(db, 'select public.start_web_point_topup($1,$2)value', [owner, row.payment_id]);
const claim = (db, row, owner = row.owner_id) => scalar(db, 'select public.claim_web_point_topup_reconcile($1,$2)value', [row.payment_id, owner]);
const finish = (db, row, lease, error = null) => db.query('select public.finish_web_point_topup_reconcile($1,$2,$3)', [row.payment_id, lease, error]);
const observe = (db, row, patch = {}) => scalar(db, 'select public.apply_web_point_topup_observation($1,$2::jsonb)value', [row.payment_id, JSON.stringify(receipt(row, patch))]);
const receipt = (row, patch = {}) => ({
  provider: 'PORTONE', version: 'V2', paymentId: row.payment_id,
  storeId: row.store_id, channelKey: row.channel_key, environment: row.environment,
  isTest: row.environment === 'test', currency: 'KRW', totalAmount: row.total_amount,
  state: 'paid', paidAmount: row.total_amount, discountAmount: 0, cancelledAmount: 0,
  transactionId: `provider-${row.payment_id}`, paidAt: '2026-10-29T01:00:00Z',
  ...patch,
});
const cancellation = row => ({state: 'cancelled', cancelledAmount: row.total_amount,
  cancelledAt: '2026-10-29T02:00:00Z', fullCancellationVerified: true});
const wallet = (db, owner = a) => scalar(db, 'select coalesce((select balance from public.point_wallets where user_id=$1),0)value', [owner]);
const counts = async db => (await db.query(`select
  (select count(*)::int from public.point_ledger)real_ledger,
  (select count(*)::int from public.web_point_topup_test_ledger)test_ledger,
  (select count(*)::int from public.web_point_topups)topups,
  (select count(*)::int from public.store_purchases)native_purchases`)).rows[0];
const state = (db, row) => scalar(db, 'select to_jsonb(t)value from public.web_point_topups t where payment_id=$1', [row.payment_id]);
async function nativeCredit(db) {
  await db.query('select * from public.grant_verified_point_purchase($1,$2::jsonb)', [a, JSON.stringify({
    platform: 'GOOGLE_PLAY', productId: product, transactionId: 'isolated-native-token',
    purchaseToken: 'isolated-native-token', originalTransactionId: 'isolated-native-order', storeAccountId: a,
    purchasedAt: '2026-10-29T00:00:00Z', rawResponse: {},
  })]);
}

test('production SQL release gate stays closed and public roles cannot read ledgers or execute topup RPCs', async () => {
  const db = await fixture();
  try {
    assert.equal(await scalar(db, 'select public.web_point_topup_live_release_ready()value'), false);
    await assert.rejects(() => prepare(db, {environment: 'live'}), /web_point_live_closed/);
    const row = await prepare(db);
    for (const name of ['anon', 'authenticated']) {
      await role(db, name);
      for (const call of [
        () => prepare(db), () => start(db, row), () => claim(db, row),
        () => finish(db, row, id(90)), () => observe(db, row),
        () => db.query('select public.web_point_topup_live_release_ready()'),
        () => db.query('select * from public.web_point_topups'),
        () => db.query('select * from public.web_point_topup_test_ledger'),
      ]) await assert.rejects(call, /permission denied/);
    }
    await role(db);
    assert.deepEqual(await counts(db), {real_ledger: 0, test_ledger: 0, topups: 1, native_purchases: 0});
  } finally { await db.close(); }
});

test('prepare retries retain one invoice, reject changed request identity and block another pending invoice even after expiry', async () => {
  const db = await fixture();
  try {
    const row = await prepare(db);
    assert.deepEqual(await prepare(db), row);
    assert.equal(row.total_amount, 2200); assert.equal(row.points, 2500);
    assert.match(row.payment_id, /^SFPTT_/);
    await assert.rejects(() => prepare(db, {product: 'snapfit_points_8000'}), /web_point_request_conflict/);
    await assert.rejects(() => prepare(db, {request: id(2)}), /web_point_pending_exists/);
    await db.query("update public.web_point_topups set expires_at=now()-interval'1 day'where id=$1", [row.id]);
    await assert.rejects(() => prepare(db, {request: id(2)}), /web_point_pending_exists/);
    assert.equal((await prepare(db)).payment_id, row.payment_id);
    assert.equal((await counts(db)).topups, 1);
    await assert.rejects(() => prepare(db, {owner: b, request: id(3), store: 'store-untrusted'}), /web_point_test_route_required/);
    await assert.rejects(() => prepare(db, {owner: b, request: id(3), channel: 'channel-key-untrusted'}), /web_point_test_route_required/);
    await assert.rejects(() => prepare(db, {owner: b, request: id(3), amount: 1}), /web_point_price_changed/);
    await assert.rejects(() => prepare(db, {owner: b, request: id(3), points: 999999}), /web_point_price_changed/);
    await assert.rejects(() => prepare(db, {owner: b, request: id(3), product: 'retired-subscription'}), /web_point_product_unavailable/);
  } finally { await db.close(); }
});

test('launch is owner-bound, renews the unopened identity and cannot be run twice', async () => {
  const db = await fixture();
  try {
    const row = await prepare(db);
    assert.equal(await claim(db, row), null);
    await assert.rejects(() => start(db, row, b), /web_point_not_found/);
    await db.query("update public.web_point_topups set expires_at=now()-interval'1 day'where id=$1", [row.id]);
    const launched = await start(db, row);
    assert.equal(launched.id, row.id); assert.equal(launched.payment_id, row.payment_id);
    assert.equal(launched.status, 'PENDING'); assert.ok(launched.sdk_started_at);
    assert.ok(Date.parse(launched.expires_at) > Date.now());
    await assert.rejects(() => start(db, row), /web_point_launch_not_available/);
    assert.equal((await counts(db)).topups, 1);
  } finally { await db.close(); }
});

test('reconciliation claims have one lease, owner scope, throttle and exact completion identity', async () => {
  const db = await fixture();
  try {
    const row = await start(db, await prepare(db));
    assert.equal(await claim(db, row, b), null);
    const claimed = await claim(db, row);
    assert.ok(claimed.reconcile_lease_id);
    assert.equal(await claim(db, row), null);
    await finish(db, row, id(99), 'wrong-lease');
    assert.equal((await state(db, row)).reconcile_lease_id, claimed.reconcile_lease_id);
    await finish(db, row, claimed.reconcile_lease_id, 'temporary provider problem');
    const finished = await state(db, row);
    assert.equal(finished.reconcile_lease_id, null); assert.equal(finished.last_error, 'temporary provider problem');
    assert.ok(Date.parse(finished.reconcile_after) > Date.now() + 4 * 60_000);
    assert.equal(await claim(db, row), null);
    await db.query("update public.web_point_topups set last_observed_at=now()-interval'1 minute',reconcile_lease_until=now()-interval'1 minute'where id=$1", [row.id]);
    const reclaimed = await claim(db, row);
    assert.notEqual(reclaimed.reconcile_lease_id, claimed.reconcile_lease_id);
    await finish(db, row, claimed.reconcile_lease_id);
    assert.equal((await state(db, row)).reconcile_lease_id, reclaimed.reconcile_lease_id);
    await finish(db, row, reclaimed.reconcile_lease_id);
    assert.equal((await state(db, row)).last_error, null);
  } finally { await db.close(); }
});

test('TEST paid and refunded replays use only the separate test ledger and never modify a real wallet', async () => {
  const db = await fixture();
  try {
    await nativeCredit(db); const before = await wallet(db); assert.equal(before, 2500);
    const row = await start(db, await prepare(db));
    const replies = await Promise.all(Array.from({length: 5}, () => observe(db, row)));
    assert.ok(replies.every(item => item.status === 'VERIFIED_TEST'));
    assert.equal(replies[0].grant_ledger_id, null);
    assert.equal(await wallet(db), before);
    assert.deepEqual(await counts(db), {real_ledger: 1, test_ledger: 1, topups: 1, native_purchases: 1});
    const refunded = await observe(db, row, cancellation(row));
    assert.equal(refunded.status, 'REFUNDED'); assert.equal(refunded.refund_ledger_id, null);
    await observe(db, row, cancellation(row)); await observe(db, row);
    assert.deepEqual((await db.query('select kind,amount_delta from public.web_point_topup_test_ledger order by id')).rows,
      [{kind: 'GRANT', amount_delta: 2500}, {kind: 'REVERSAL', amount_delta: -2500}]);
    assert.equal(await wallet(db), before);
    assert.deepEqual(await counts(db), {real_ledger: 1, test_ledger: 2, topups: 1, native_purchases: 1});
    assert.equal(await claim(db, row), null);
  } finally { await db.close(); }
});

test('untrusted provider, route, amount, state and incomplete payment identities never grant', async () => {
  const db = await fixture();
  try {
    const row = await start(db, await prepare(db));
    const patches = [
      {provider: 'OTHER'}, {version: 'V1'}, {paymentId: 'another-invoice'},
      {storeId: 'store-untrusted'}, {channelKey: 'channel-key-untrusted'},
      {environment: 'live'}, {isTest: false}, {currency: 'USD'}, {totalAmount: 1},
      {state: 'unknown'}, {state: null}, {paidAmount: -1}, {discountAmount: -1},
      {paidAmount: 2201}, {paidAmount: 1}, {cancelledAmount: 1},
      {transactionId: ''}, {transactionId: null}, {paidAt: null},
      {state: 'cancelled', cancelledAmount: 1, cancelledAt: '2026-10-29T02:00:00Z', fullCancellationVerified: true},
      {state: 'cancelled', cancelledAmount: 2200, cancelledAt: '2026-10-29T02:00:00Z', fullCancellationVerified: false},
    ];
    for (const patch of patches) await assert.rejects(() => observe(db, row, patch), /web_point_receipt_invalid/);
    assert.equal((await state(db, row)).status, 'PENDING');
    assert.deepEqual(await counts(db), {real_ledger: 0, test_ledger: 0, topups: 1, native_purchases: 0});
    assert.equal(await wallet(db), 0);
  } finally { await db.close(); }
});

test('provider transaction identity cannot move between invoices and failed atomic writes leave no test grant', async () => {
  const db = await fixture();
  try {
    const first = await start(db, await prepare(db));
    await observe(db, first, {transactionId: 'shared-provider-transaction'});
    await assert.rejects(() => observe(db, first, {transactionId: 'replacement-transaction'}), /web_point_receipt_conflict/);
    await assert.rejects(() => observe(db, first, {...cancellation(first), transactionId: 'replacement-transaction'}), /web_point_receipt_conflict/);
    const second = await start(db, await prepare(db, {owner: b, request: id(2)}));
    await assert.rejects(() => observe(db, second, {transactionId: 'shared-provider-transaction'}), /duplicate key value|unique constraint/);
    assert.equal((await state(db, second)).status, 'PENDING');
    assert.equal((await counts(db)).test_ledger, 1);
    assert.equal((await counts(db)).real_ledger, 0);
  } finally { await db.close(); }
});

test('prepared quotes stay immutable across catalog changes and new requests require the current price', async () => {
  const db = await fixture();
  try {
    const row = await prepare(db);
    await db.query('update public.point_products set amount=2400,points=3000 where product_id=$1', [product]);
    const retry = await prepare(db);
    assert.equal(retry.payment_id, row.payment_id); assert.equal(retry.total_amount, 2200); assert.equal(retry.points, 2500);
    await assert.rejects(() => prepare(db, {owner: b, request: id(2)}), /web_point_price_changed/);
    const current = await prepare(db, {owner: b, request: id(2), amount: 2400, points: 3000});
    assert.equal(current.total_amount, 2400); assert.equal(current.points, 3000);
    await start(db, row); const paid = await observe(db, row);
    assert.equal(paid.total_amount, 2200); assert.equal(paid.points, 2500);
    assert.equal(await scalar(db, 'select amount_delta value from public.web_point_topup_test_ledger where topup_id=$1', [row.id]), 2500);
    await db.query('update public.point_products set is_active=false where product_id=$1', [product]);
    assert.equal((await prepare(db)).payment_id, row.payment_id);
  } finally { await db.close(); }
});

test('partial or uncertain cancellation enters REVIEW; full cancellation before credit cannot later grant', async () => {
  const db = await fixture();
  try {
    const review = await start(db, await prepare(db));
    const partial = await observe(db, review, {state: 'review', cancelledAmount: 1000});
    assert.equal(partial.status, 'REVIEW'); assert.equal(partial.verified_at, null);
    await assert.rejects(() => observe(db, review), /web_point_review_required/);
    await assert.rejects(() => prepare(db, {request: id(2)}), /web_point_pending_exists/);
    assert.equal((await counts(db)).test_ledger, 0);
    const voided = await observe(db, review, cancellation(review));
    assert.equal(voided.status, 'VOIDED');
    assert.equal((await observe(db, review)).status, 'VOIDED');
    assert.equal((await observe(db, review, cancellation(review))).status, 'VOIDED');
    const paid = await start(db, await prepare(db, {request: id(2)}));
    await observe(db, paid);
    assert.equal((await observe(db, paid, {state: 'review', cancelledAmount: 1000})).status, 'REVIEW');
    assert.equal((await counts(db)).test_ledger, 1);
    assert.equal((await observe(db, paid, cancellation(paid))).status, 'REFUNDED');
    assert.equal((await counts(db)).test_ledger, 2);
    assert.equal(await wallet(db), 0);
  } finally { await db.close(); }
});

test('failed observations cannot later auto-credit and cannot overwrite an already paid purchase', async () => {
  const db = await fixture();
  try {
    const failed = await start(db, await prepare(db));
    assert.equal((await observe(db, failed, {state: 'failed', paidAmount: 0, paidAt: null})).status, 'FAILED');
    await assert.rejects(() => observe(db, failed), /web_point_review_required/);
    assert.equal(await claim(db, failed), null);
    const paid = await start(db, await prepare(db, {request: id(2)})); await observe(db, paid);
    await assert.rejects(() => observe(db, paid, {state: 'failed', paidAmount: 0}), /web_point_receipt_conflict/);
    assert.equal((await state(db, paid)).status, 'VERIFIED_TEST');
    assert.equal((await counts(db)).test_ledger, 1);
  } finally { await db.close(); }
});

test('isolated live branch grants once, uses real spending RPCs and records refunded spent points as debt', async () => {
  const db = await fixture({isolatedLiveBranch: true});
  try {
    const row = await start(db, await prepare(db, {environment: 'live'}));
    assert.match(row.payment_id, /^SFPTL_/);
    const paid = await observe(db, row, {paidAmount: 2000, discountAmount: 200});
    assert.equal(paid.status, 'CREDITED'); assert.ok(paid.grant_ledger_id);
    await observe(db, row, {paidAmount: 2000, discountAmount: 200});
    assert.equal(await wallet(db), 2500); assert.equal(await wallet(db, b), 0);
    assert.deepEqual(await counts(db), {real_ledger: 1, test_ledger: 0, topups: 1, native_purchases: 0});
    await role(db, 'authenticated');
    const spend = async key => (await db.query('select * from public.record_ai_album_draft_success($1,700)', [key])).rows[0];
    assert.equal((await spend('first-free')).used_free_credit, true);
    for (let index = 0; index < 3; index++) assert.equal((await spend(`spent-${index}`)).charged_points, 700);
    await role(db); assert.equal(await wallet(db), 400);
    const refund = {state: 'cancelled', paidAmount: 2000, discountAmount: 200,
      cancelledAmount: 2000, cancelledAt: '2026-10-29T02:00:00Z', fullCancellationVerified: true};
    const refunded = await observe(db, row, refund);
    assert.equal(refunded.status, 'REFUNDED'); assert.ok(refunded.refund_ledger_id);
    assert.equal(await wallet(db), -2100);
    await observe(db, row, refund); await observe(db, row, {paidAmount: 2000, discountAmount: 200});
    assert.equal(await wallet(db), -2100);
    const ledgers = (await db.query("select reason,count(*)::int n,sum(amount_delta)::int delta from public.point_ledger group by reason order by reason")).rows;
    assert.deepEqual(ledgers, [
      {reason: 'AI_ALBUM_DRAFT_CHARGE', n: 3, delta: -2100},
      {reason: 'AI_ALBUM_DRAFT_FREE', n: 1, delta: 0},
      {reason: 'POINT_PURCHASE', n: 1, delta: 2500},
      {reason: 'POINT_PURCHASE_REFUND', n: 1, delta: -2500},
    ]);
    assert.equal(await scalar(db, 'select sum(amount_delta)::int value from public.point_ledger'), await wallet(db));
    assert.equal((await counts(db)).test_ledger, 0);
    assert.equal((await counts(db)).native_purchases, 0);
    assert.equal(await scalar(db, 'select count(*)::int value from public.subscriptions'), 1);
  } finally { await db.close(); }
});

// Integration smoke: replay the deployed baseline plus this task's migrations
// in one isolated database, then exercise IAP, retired print payments and notifications.
// No network, Supabase credentials, production data or real provider calls.
// PGLITE_MODULE=/path/to/@electric-sql/pglite/dist/index.js node --test this-file
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync, readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const { PGlite } = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href
  : '@electric-sql/pglite');
const migrationDir = new URL('../../supabase/migrations/', import.meta.url);
const releaseMigrations = [
  '20260908094302_secure_print_order_payments.sql',
  '20260908094449_point_only_iap_atomic_grants.sql',
  '20260908094551_targeted_push_notifications.sql',
  '20260908095746_point_purchase_refund_reconciliation.sql',
  '20260908105146_remove_external_print_payment_integration.sql',
  '20260908111001_digital_point_shop.sql',
  '20260908112124_complete_digital_point_shop_schema.sql',
];
const alice = '11111111-1111-4111-8111-111111111111';
const bob = '22222222-2222-4222-8222-222222222222';
const tokenA = 'combined-alice-device-token';
const tokenB = 'combined-bob-device-token';

async function combinedDatabase() {
  const db = new PGlite();
  try {
    // Supabase-owned auth/storage primitives and typical API-role default
    // privileges. Public app tables, functions, policies and triggers below are
    // all created by actual repository migrations, not reduced hand-built DDL.
    await db.exec(`
      create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth; create schema storage; create schema extensions;
      create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      create function auth.role() returns text language sql stable as $$
        select current_setting('request.jwt.claim.role',true) $$;
      create function auth.jwt() returns jsonb language sql stable as $$
        select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
      grant usage on schema auth,public to anon,authenticated,service_role;
      grant execute on all functions in schema auth to anon,authenticated,service_role;
      alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
      alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
      alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
      create table storage.buckets(id text primary key,name text,public boolean,
        file_size_limit bigint,allowed_mime_types text[]);
      create table storage.objects(id uuid primary key default gen_random_uuid(),
        bucket_id text references storage.buckets(id),name text,created_at timestamptz default now());
      alter table storage.objects enable row level security;
      create function storage.foldername(name text) returns text[] language sql immutable as $$
        select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
      create function storage.extension(name text) returns text language sql immutable as $$
        select reverse(split_part(reverse(name),'.',1)) $$;
      -- PGlite 0.3.14 does not bundle pgcrypto. These local-only helpers replace
      -- that extension's random IDs, never payment verification or app SQL.
      create function extensions.gen_random_uuid() returns uuid language sql volatile as $$
        select pg_catalog.gen_random_uuid() $$;
      create function extensions.gen_random_bytes(n integer) returns bytea language sql volatile as $$
        select decode(substr(replace(gen_random_uuid()::text,'-','') ||
          replace(gen_random_uuid()::text,'-',''),1,n*2),'hex') $$;
    `);
    // Unrelated in-progress print-contract migrations belong to a separate task.
    const files = readdirSync(migrationDir).filter(file => file.endsWith('.sql') &&
      (file < releaseMigrations[0] || releaseMigrations.includes(file))).sort();
    assert.deepEqual(files.filter(file => releaseMigrations.includes(file)), releaseMigrations);
    for (const file of files) {
      let sql = readFileSync(new URL(file, migrationDir), 'utf8');
      if (file === '20260820140500_initial_snapfit_schema.sql') {
        sql = sql.replace('create extension if not exists pgcrypto with schema extensions;', '-- pgcrypto primitives supplied by this isolated fixture');
      }
      try { await db.exec(sql); }
      catch (error) { throw new Error(`Migration replay failed at ${file}: ${error.message}`, { cause: error }); }
    }
    return { db, migrationCount: files.length };
  } catch (error) {
    await db.close();
    throw error;
  }
}

test('release migrations preserve points/private push while external print approvals are retired', async t => {
  const { db, migrationCount } = await combinedDatabase();
  t.diagnostic(`Replayed ${migrationCount} actual migrations, including payment/push release and external-payment retirement.`);
  const login = async user => db.exec(`reset role; set role authenticated;
    select set_config('request.jwt.claim.sub','${user}',false);
    select set_config('request.jwt.claim.role','authenticated',false);
    select set_config('request.jwt.claims','{"sub":"${user}","role":"authenticated","app_metadata":{}}',false);`);
  const server = async () => db.exec(`reset role; set role service_role;
    select set_config('request.jwt.claim.role','service_role',false);`);
  const grant = async (id = 'combined-google-purchase') => (await db.query(
    'select * from grant_verified_point_purchase($1,$2::jsonb)', [alice, JSON.stringify({
      platform: 'GOOGLE_PLAY', productId: 'snapfit_points_2500', transactionId: id,
      purchaseToken: id, storeAccountId: alice, purchasedAt: '2026-09-08T00:00:00Z',
      rawResponse: { purchaseStateContext: { purchaseState: 'PURCHASED' } },
    })])).rows[0];
  const counts = async () => (await db.query(`select
    (select count(*)::integer from notifications) notifications,
    (select count(*)::integer from push_outbox) outbox,
    (select count(*)::integer from point_ledger) ledger`)).rows[0];
  try {
    await db.exec(`insert into auth.users values ('${alice}'),('${bob}');
      insert into profiles(id) values ('${alice}'),('${bob}');
      insert into albums(id,owner_id,title) values (1,'${alice}','Combined test album');
      insert into album_pages(album_id,page_index,layers_json)
        select 1,n-1,'[]'::jsonb from generate_series(1,16) n;`);
    await login(alice);
    await db.query("select register_push_device($1,'android',540,true)", [tokenA]);
    await login(bob);
    await db.query("select register_push_device($1,'iOS',540,true)", [tokenB]);

    await server();
    assert.equal((await grant()).remaining_balance, 2500);
    assert.equal((await grant()).already_granted, true);
    assert.deepEqual(await counts(), { notifications: 0, outbox: 0, ledger: 1 });

    await login(alice);
    for (const call of [
      () => grant(),
      () => db.query("select revoke_verified_point_purchase('GOOGLE_PLAY','combined-google-purchase')"),
      () => db.query('select * from claim_point_purchase_reconciliation(20)'),
      () => db.query('select * from claim_push_deliveries(20)'),
    ]) await assert.rejects(call, /permission denied/);
    await assert.rejects(() => db.exec("update orders set status='PAYMENT_COMPLETED'"), /permission denied/);
    // RLS hides non-writable rows for UPDATE, so denial is a zero-row update.
    assert.equal((await db.query("update point_wallets set balance=999999 returning user_id")).rows.length, 0);
    assert.equal((await db.query('select balance from point_wallets')).rows[0].balance, 2500);

    await assert.rejects(() => db.query(`select create_print_order(1,16,39700,'TOSS_PAYMENTS',
      'Alice','01012345678','12345','Test address','','') o`), /permission denied/);
    await server();
    const order = (await db.query(`insert into orders(user_id,album_id,title,amount,status)
      values($1,1,'Unpaid historical order',39700,'PAYMENT_PENDING') returning *`, [alice])).rows[0];
    assert.deepEqual(await counts(), { notifications: 0, outbox: 0, ledger: 1 });
    await assert.rejects(() => db.query("select confirm_verified_print_payment($1,$1,39700,'KRW')", [order.order_id]), /does not exist/);
    await assert.rejects(() => db.query("update orders set status='PAYMENT_COMPLETED' where order_id=$1", [order.order_id]), /physical_order_payments_disabled/);
    await assert.rejects(() => db.query("update orders set verified_payment_id='forged',verified_payment_provider='forged',payment_confirmed_at=now() where order_id=$1", [order.order_id]), /physical_order_payments_disabled/);
    await assert.rejects(() => db.query("update orders set status='DELIVERED' where order_id=$1", [order.order_id]), /invalid_order_status_transition/);
    assert.equal((await db.query('select claim_print_package($1,gen_random_uuid()) o',[order.order_id])).rows[0].o,null);
    assert.deepEqual(await counts(), { notifications: 0, outbox: 0, ledger: 1 });
    await db.query("update orders set status='CANCELED' where order_id=$1", [order.order_id]);
    await db.query("update orders set status='CANCELED' where order_id=$1", [order.order_id]);
    assert.deepEqual(await counts(), { notifications: 1, outbox: 1, ledger: 1 });
    const deliveries = (await db.query('select user_id,token from push_outbox')).rows;
    assert.ok(deliveries.every(row => row.user_id === alice && row.token === tokenA));

    // Debit spent points then reverse the purchase. The order-trigger/outbox
    // policies must not interfere with the independent atomic refund ledger.
    await db.query('update point_wallets set balance=500 where user_id=$1', [alice]);
    await db.query(`insert into point_ledger(user_id,amount_delta,reason,idempotency_key)
      values($1,-2000,'AI_ALBUM_DRAFT_CHARGE','combined-spend')`, [alice]);
    const reverse = () => db.query("select * from revoke_verified_point_purchase('GOOGLE_PLAY','combined-google-purchase','{}')");
    assert.equal((await reverse()).rows[0].remaining_balance, -2000);
    assert.equal((await reverse()).rows[0].already_revoked, true);
    assert.equal((await grant('combined-next-purchase')).remaining_balance, 500);
    assert.deepEqual(await counts(), { notifications: 1, outbox: 1, ledger: 4 });

    // Claim both worker queues under the same service role and verify that each
    // keeps its own leases without exposing either claim operation to clients.
    const pushClaims = (await db.query('select * from claim_push_deliveries(20)')).rows;
    const pointClaims = (await db.query('select * from claim_point_purchase_reconciliation(20)')).rows;
    assert.equal(pushClaims.length, 1);
    assert.equal(pointClaims.length, 1);
    assert.equal(pointClaims[0].transaction_id, 'combined-next-purchase');
    assert.equal((await db.query('select * from claim_push_deliveries(20)')).rows.length, 0);
    assert.equal((await db.query('select * from claim_point_purchase_reconciliation(20)')).rows.length, 0);

    await login(bob);
    assert.equal((await db.query('select * from notifications')).rows.length, 0);
    assert.equal((await db.query('select * from store_purchases')).rows.length, 0);
    assert.equal((await db.query('select * from orders')).rows.length, 0);
    await assert.rejects(() => db.query('select * from notification_inbox'), /permission denied/);
    await login(alice);
    assert.equal((await db.query('select * from notifications')).rows.length, 1);
    await db.exec('update notifications set is_read=true,read_at=now()');
    await assert.rejects(() => db.exec("update notifications set title='forged'"), /permission denied/);
    await server();
    assert.equal((await db.query("select is_active from billing_plans where plan_code='SNAPFIT_PRO_MONTHLY'")).rows[0].is_active, false);
    // The digital shop shares the verified IAP wallet and preserves both refund
    // debt accounting and private notification policies. Prices exist only in
    // this isolated fixture, never in the production migration.
    await db.exec(`reset role;
      insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)
      values('frame:combined-fixture','combined-fixture','frame','Local fixture',300,true);`);
    await login(alice);
    const digital = () => db.query("select purchase_point_shop_product('frame:combined-fixture',300) r");
    const purchased = (await digital()).rows[0].r;
    assert.equal(purchased.owned,true);
    assert.equal(purchased.charged_points,300);
    assert.equal(purchased.remaining_balance,200);
    assert.equal((await digital()).rows[0].r.charged_points,0);
    await login(bob);
    assert.equal((await db.query('select * from point_shop_ownership')).rows.length,0);
    await server();
    assert.deepEqual(await counts(), { notifications: 1, outbox: 1, ledger: 5 });
    assert.equal((await db.query("select amount_delta from point_ledger where reason='DIGITAL_ITEM_PURCHASE'")).rows[0].amount_delta,-300);
    t.diagnostic('Confirmed point debt/re-credit and digital ownership debit; retired payment approval; one targeted cancellation notification; owner-only rows; independent worker leases; client mutations/RPCs denied.');
  } finally { await db.close(); }
});

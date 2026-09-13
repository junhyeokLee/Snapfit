// Offline PGlite tests: actual wallet/catalog RPC SQL, no store or remote calls.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const { PGlite } = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const migration = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8')
const shopSql = migration('20260908111001_digital_point_shop.sql')
const completionSql = migration('20260908112124_complete_digital_point_shop_schema.sql')
const alice = '11111111-1111-4111-8111-111111111111'
const bob = '22222222-2222-4222-8222-222222222222'

async function fixture({withShop = true} = {}) {
  const db = new PGlite()
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function auth.jwt() returns jsonb language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    grant execute on all functions in schema auth to anon,authenticated,service_role;
    alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
    alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
    alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
    insert into auth.users values('${alice}'),('${bob}');
  `)
  const initial = migration('20260820140500_initial_snapfit_schema.sql')
  await db.exec(initial.slice(initial.indexOf('create or replace function public.set_updated_at()'), initial.indexOf('-- Profiles mirror')))
  await db.exec(migration('20260905113000_ai_album_points.sql'))
  // Existing refund migration permits negative balances. Full release replay is
  // covered separately in combined_payments_push_sql.test.mjs.
  await db.exec('alter table point_wallets drop constraint point_wallets_balance_check')
  if (withShop) await db.exec(shopSql)
  return db
}

async function login(db, user = alice, admin = false, userMetadataAdmin = false) {
  await db.exec('reset role; set role authenticated')
  await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)", [user ?? '', JSON.stringify({
    sub:user, app_metadata: admin ? {role:'admin'} : {}, user_metadata:userMetadataAdmin ? {role:'admin'} : {},
  })])
}
async function guest(db) {
  await db.exec("reset role; set role anon; select set_config('request.jwt.claim.sub','',false),set_config('request.jwt.claims','{}',false)")
}
async function product(db, key = 'template:-123', price = 100, active = true) {
  await login(db, alice, true)
  const [kind, asset] = key.split(':')
  return db.query(`insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)
    values($1,$2,$3,'Fixture asset',$4,$5)`, [key,asset,kind,price,active])
}
async function fund(db, amount = 500, user = alice) {
  await db.exec('reset role')
  await db.query('insert into point_wallets(user_id,balance) values($1,$2) on conflict(user_id) do update set balance=excluded.balance', [user,amount])
}
const access = async (db,key='template:-123') => (await db.query('select get_point_shop_access($1) result',[key])).rows[0].result
const buy = async (db,key='template:-123',price=100) => (await db.query('select purchase_point_shop_product($1,$2) result',[key,price])).rows[0].result
async function counts(db) {
  await db.exec('reset role')
  return (await db.query(`select
    (select count(*)::integer from point_wallets) wallets,
    (select count(*)::integer from point_ledger) ledger,
    (select count(*)::integer from point_shop_ownership) ownership`)).rows[0]
}

test('guests retain existing free assets and can see declared unavailable or paid items', async () => {
  const db = await fixture()
  try {
    await product(db)
    await product(db,'phrase:draft',null,false)
    await product(db,'sticker:free',0,true)
    await guest(db)
    assert.deepEqual(await access(db,'frame:legacy'), {product_key:'frame:legacy',title:null,point_price:0,available:true,is_free:true,owned:false,remaining_balance:0})
    assert.equal((await access(db)).is_free,false)
    assert.equal((await access(db,'phrase:draft')).available,false)
    assert.equal((await access(db,'sticker:free')).is_free,true)
    assert.equal((await db.query('select * from point_shop_products')).rows.length,3)
    await assert.rejects(buy(db),/permission denied/)
    await login(db,null)
    await assert.rejects(buy(db),/authentication_required/)
    assert.deepEqual(await counts(db),{wallets:0,ledger:0,ownership:0})
  } finally { await db.close() }
})

test('only administrator app_metadata configures the catalog; unsafe keys/prices cannot publish', async () => {
  const db = await fixture()
  try {
    await login(db,alice,false,true)
    await assert.rejects(db.query("insert into point_shop_products values('frame:test','test','frame','Frame',100,true,now())"),/row-level security/)
    await product(db)
    await login(db,bob)
    assert.equal((await db.query('update point_shop_products set point_price=0 returning product_key')).rows.length,0)
    assert.equal((await db.query('delete from point_shop_products returning product_key')).rows.length,0)
    await login(db,alice,true)
    for (const [key,asset,kind,price,active] of [
      ['order:test','test','order',100,true], ['template:test','other','template',100,true],
      ['frame:test','test','frame',-1,true], ['frame:test','test','frame',null,true],
      ['phrase:bad key','bad key','phrase',1,true], [`sticker:${'x'.repeat(181)}`,'x'.repeat(181),'sticker',1,true],
    ]) await assert.rejects(db.query(`insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)
      values($1,$2,$3,'Invalid fixture',$4,$5)`,[key,asset,kind,price,active]),/check constraint/)
    await db.query("update point_shop_products set point_price=0,title='Free title' where product_key='template:-123'")
    await db.query("delete from point_shop_products where product_key='template:-123'")
    assert.equal((await db.query('select * from point_shop_products')).rows.length,0)
    for(const key of ['order:physical','Template:1','frame:bad key','template:',null]) {
      await assert.rejects(access(db,key),/invalid_point_shop_product_key/)
      await assert.rejects(buy(db,key,1),/invalid_point_shop_product_key/)
    }
  } finally { await db.close() }
})

test('paid purchase debits server price and creates one durable ownership/ledger entry under retries', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db)
    const results = await Promise.all([buy(db),buy(db),buy(db)])
    assert.equal(results.filter(r=>r.charged_points===100).length,1)
    assert.ok(results.every(r=>r.owned && !r.is_free && r.remaining_balance===400))
    assert.equal(results.filter(r=>r.already_owned).length,2)
    const ownership=(await db.query('select * from point_shop_ownership')).rows[0]
    const ledger=(await db.query('select * from point_ledger')).rows[0]
    assert.equal(ownership.point_price,100); assert.equal(ownership.ledger_id,ledger.id)
    assert.equal(ledger.amount_delta,-100); assert.equal(ledger.reason,'DIGITAL_ITEM_PURCHASE')
    assert.equal(ledger.metadata.product_key,'template:-123')
    assert.deepEqual(await counts(db),{wallets:1,ledger:1,ownership:1})
  } finally { await db.close() }
})

test('different products share one wallet budget and cannot overspend', async () => {
  const db = await fixture()
  try {
    await product(db,'sticker:assets/sticker/paper.png',100)
    await product(db,'frame:soft',100)
    await fund(db,150); await login(db)
    const results=await Promise.allSettled([buy(db,'sticker:assets/sticker/paper.png'),buy(db,'frame:soft')])
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1)
    assert.match(results.find(r=>r.status==='rejected').reason.message,/insufficient_points/)
    assert.equal((await access(db)).remaining_balance,50)
    assert.deepEqual(await counts(db),{wallets:1,ledger:1,ownership:1})
  } finally { await db.close() }
})

test('insufficient funds roll back wallet creation, and refund debt never buys paid items', async () => {
  const db = await fixture()
  try {
    await product(db); await login(db)
    await assert.rejects(buy(db),/insufficient_points/)
    assert.deepEqual(await counts(db),{wallets:0,ledger:0,ownership:0})
    await fund(db,-200); await product(db,'phrase:free',0); await login(db)
    await assert.rejects(buy(db),/insufficient_points/)
    assert.equal((await buy(db,'phrase:free',0)).is_free,true)
    assert.equal((await buy(db,'sticker:legacy',0)).charged_points,0)
    assert.equal((await access(db)).remaining_balance,-200)
    assert.deepEqual(await counts(db),{wallets:1,ledger:0,ownership:0})
  } finally { await db.close() }
})

test('changed price requires fresh consent, while delisted ownership stays usable without another debit', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db,alice,true)
    await db.query('update point_shop_products set point_price=150')
    await login(db)
    await assert.rejects(buy(db),/point_shop_price_changed/)
    assert.equal((await access(db)).remaining_balance,500)
    assert.equal((await buy(db,'template:-123',150)).charged_points,150)
    await login(db,alice,true)
    await db.query('update point_shop_products set is_active=false,point_price=null')
    await assert.rejects(db.query('delete from point_shop_products'),/foreign key constraint/)
    await login(db)
    const replay=await buy(db,'template:-123',100)
    assert.equal(replay.charged_points,0); assert.equal(replay.already_owned,true)
    assert.equal(replay.available,true); assert.equal(replay.owned,true); assert.equal(replay.remaining_balance,350)
    await login(db,bob)
    assert.equal((await access(db)).available,false)
    await assert.rejects(buy(db),/point_shop_product_unavailable/)
    assert.deepEqual(await counts(db),{wallets:1,ledger:1,ownership:1})
  } finally { await db.close() }
})

test('ownership is owner-only and no API role can insert, transfer, or erase a grant', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db); await buy(db)
    await login(db,bob,true)
    assert.equal((await db.query('select * from point_shop_ownership')).rows.length,0)
    assert.equal((await access(db)).owned,false)
    for(const sql of [
      "update point_shop_ownership set product_key='frame:forged'",
      'delete from point_shop_ownership',
      `insert into point_shop_ownership(user_id,product_key,point_price,ledger_id) values('${bob}','template:-123',100,1)`,
    ]) await assert.rejects(db.exec(sql),/permission denied/)
    await assert.rejects(db.query(`insert into point_ledger(user_id,amount_delta,reason,idempotency_key)
      values($1,-100,'DIGITAL_ITEM_PURCHASE','forged')`,[bob]),/row-level security/)
    await db.exec('reset role; set role service_role')
    await assert.rejects(db.query(`insert into point_shop_ownership(user_id,product_key,point_price,ledger_id)
      values($1,'template:-123',100,1)`,[bob]),/permission denied/)
    await db.exec('reset role')
    await assert.rejects(db.query('update point_shop_ownership set user_id=$1',[bob]),/point_shop_ownership_immutable/)
    await assert.rejects(db.query('delete from point_shop_ownership'),/point_shop_ownership_immutable/)
    await assert.rejects(db.query('update point_ledger set amount_delta=-1'),/digital_point_ledger_immutable/)
    await assert.rejects(db.query('delete from point_ledger'),/digital_point_ledger_immutable/)
    await assert.rejects(db.query(`insert into point_shop_ownership(user_id,product_key,point_price,ledger_id)
      values($1,'template:-123',1,1)`,[bob]),/point_shop_ledger_mismatch/)
  } finally { await db.close() }
})

test('failure after debit rolls back ledger and wallet as well as ownership', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db)
    await db.exec(`create function public.inject_shop_failure() returns trigger language plpgsql as $$
      begin raise exception 'injected_storage_failure'; end; $$;
      create trigger zz_shop_failure before insert on point_shop_ownership for each row execute function inject_shop_failure();`)
    await login(db)
    await assert.rejects(buy(db),/injected_storage_failure/)
    assert.equal((await access(db)).remaining_balance,500)
    assert.deepEqual(await counts(db),{wallets:1,ledger:0,ownership:0})
    await db.exec('drop trigger zz_shop_failure on point_shop_ownership')
    await login(db)
    assert.equal((await buy(db)).remaining_balance,400)
  } finally { await db.close() }
})

test('account deletion cascades owned items and debit ledger without deleting the catalog', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db); await buy(db)
    await db.exec('reset role')
    await db.query('delete from auth.users where id=$1',[alice])
    assert.deepEqual(await counts(db),{wallets:0,ledger:0,ownership:0})
    assert.equal((await db.query('select * from point_shop_products')).rows.length,1)
    assert.equal((await db.query('select * from auth.users')).rows[0].id,bob)
  } finally { await db.close() }
})

test('forward completion skips a complete fresh schema and preserves existing purchase data/ACLs', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db); await buy(db)
    await db.exec('reset role')
    const snapshot = async () => ({
      ownership:(await db.query('select * from point_shop_ownership')).rows,
      wallets:(await db.query('select * from point_wallets')).rows,
      ledger:(await db.query('select * from point_ledger')).rows,
      tables:(await db.query("select oid,relname,relacl from pg_class where relname in ('point_shop_products','point_shop_ownership') order by relname")).rows,
      functions:(await db.query("select oid,proname,proacl from pg_proc where proname in ('get_point_shop_access','purchase_point_shop_product','guard_point_shop_ownership','guard_digital_point_ledger') order by proname")).rows,
    })
    const before = await snapshot()
    await db.exec(completionSql)
    await db.exec(completionSql)
    assert.deepEqual(await snapshot(),before)
    await login(db)
    assert.equal((await buy(db)).charged_points,0)
  } finally { await db.close() }
})

test('forward completion installs after empty recorded history without rewriting history, then enforces purchase/RLS', async () => {
  const db = await fixture({withShop:false})
  try {
    await db.exec(`create schema supabase_migrations;
      create table supabase_migrations.schema_migrations(version text primary key,statements text[]);
      insert into supabase_migrations.schema_migrations values('20260908111001',null);`)
    await db.exec(completionSql)
    assert.deepEqual((await db.query('select * from supabase_migrations.schema_migrations')).rows,
      [{version:'20260908111001',statements:null}])
    await guest(db)
    assert.equal((await access(db,'frame:legacy')).is_free,true)
    await assert.rejects(buy(db),/permission denied/)
    await product(db); await fund(db); await login(db)
    const result = await buy(db)
    assert.equal(result.owned,true); assert.equal(result.remaining_balance,400)
    assert.equal((await buy(db)).charged_points,0)
    await login(db,bob)
    assert.equal((await db.query('select * from point_shop_ownership')).rows.length,0)
    await assert.rejects(db.query("insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active) values('frame:fake','fake','frame','Fake',0,true)"),/row-level security/)
    await assert.rejects(db.query('delete from point_shop_ownership'),/permission denied/)
    assert.deepEqual(await counts(db),{wallets:1,ledger:1,ownership:1})
  } finally { await db.close() }
})

test('forward completion refuses partial tables instead of concealing a bad schema', async () => {
  const db = await fixture({withShop:false})
  try {
    await db.exec('create table point_shop_products(partial_fixture integer)')
    await assert.rejects(db.exec(completionSql),/partial_point_shop_schema_requires_review/)
    assert.equal((await db.query("select to_regclass('public.point_shop_ownership') r")).rows[0].r,null)
    assert.equal((await db.query("select to_regprocedure('public.get_point_shop_access(text)') r")).rows[0].r,null)
    assert.equal((await db.query("select column_name from information_schema.columns where table_name='point_shop_products'")).rows[0].column_name,'partial_fixture')
  } finally { await db.close() }
})

test('forward completion refuses a missing function in an otherwise populated schema', async () => {
  const db = await fixture()
  try {
    await product(db); await fund(db); await login(db); await buy(db)
    await db.exec('reset role; drop function get_point_shop_access(text)')
    await assert.rejects(db.exec(completionSql),/partial_point_shop_schema_requires_review/)
    assert.equal((await db.query('select balance from point_wallets')).rows[0].balance,400)
    assert.equal((await db.query('select * from point_shop_ownership')).rows.length,1)
  } finally { await db.close() }
})

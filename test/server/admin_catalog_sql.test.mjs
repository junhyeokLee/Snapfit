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

test('protected admin catalog grants only configuration columns; ownership and catalog identities stay protected', async () => {
  const db = await fixture()
  try {
    await db.exec(migration('20260908124132_admin_point_catalog_writes.sql'))
    await db.exec('set role service_role')
    await db.exec("insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active) values('template:-123','-123','template','Bundled template',null,false)")
    await db.exec("update point_shop_products set point_price=100,is_active=true,title='Published' where product_key='template:-123'")
    assert.equal((await db.query("select point_price from point_shop_products where product_key='template:-123'")).rows[0].point_price,100)
    await assert.rejects(db.exec("update point_shop_products set product_key='template:other',asset_id='other'"),/permission denied/)
    await assert.rejects(db.exec("update point_shop_products set kind='frame'"),/permission denied/)
    await assert.rejects(db.exec("delete from point_shop_products"),/permission denied/)
    await assert.rejects(db.exec("insert into point_shop_ownership(user_id,product_key,point_price,ledger_id) values('11111111-1111-4111-8111-111111111111','template:-123',100,1)"),/permission denied/)
    await assert.rejects(db.exec("update point_shop_products set point_price=null,is_active=true"),/check constraint/)
    await db.exec('reset role;set role authenticated')
    assert.equal((await db.query("update point_shop_products set point_price=0 returning product_key")).rows.length,0)
    await db.exec('reset role')
    assert.equal((await db.query('select count(*)::int n from point_shop_ownership')).rows[0].n,0)
    assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n,0)
  } finally { await db.close() }
})

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import { PGlite } from '@electric-sql/pglite'

const sql = readFileSync(new URL('../../supabase/releases/20261103_sensory_products.sql', import.meta.url), 'utf8')
async function fixture() {
  const db = new PGlite()
  await db.exec(`create table point_shop_products(product_key text primary key,kind text,asset_id text,title text,point_price integer,is_active boolean,extra jsonb default '{"keep":true}');
    insert into point_shop_products values('frame:existing','frame','existing','Existing',700,true,'{"preserve":1}');
    create table customer_sentinel(id integer primary key,wallet integer,album jsonb);
    insert into customer_sentinel values(1,1500,'{"original":"photo-font-layer"}');`)
  return db
}

test('registers 18 exact rows idempotently and preserves unrelated prices and customer records', async t => {
  const db = await fixture();t.after(() => db.close())
  const before = (await db.query('select * from customer_sentinel')).rows
  const existing = (await db.query("select * from point_shop_products where product_key='frame:existing'")).rows
  await db.exec(sql);await db.exec(sql)
  const rows = (await db.query("select * from point_shop_products where product_key<>'frame:existing'")).rows
  assert.equal(rows.length,18);assert.equal(rows.filter(r => r.point_price===0).length,10)
  assert.ok(rows.every(r=>r.is_active));assert.equal(rows.find(r=>r.product_key==='template:story-night-city-archive').point_price,1800)
  assert.deepEqual((await db.query('select * from customer_sentinel')).rows,before)
  assert.deepEqual((await db.query("select * from point_shop_products where product_key='frame:existing'")).rows,existing)
})

test('an existing conflicting tier aborts without modifying that product or inserting others', async t => {
  const db = await fixture();t.after(() => db.close())
  await db.exec("insert into point_shop_products(product_key,kind,asset_id,title,point_price,is_active) values('template:story-coffee-notebook','template','story-coffee-notebook','Unexpected paid book',500,true)")
  const before = (await db.query('select * from point_shop_products order by product_key')).rows
  await assert.rejects(db.exec(sql),/sensory_release_existing_product_conflict/)
  await db.exec('rollback')
  assert.deepEqual((await db.query('select * from point_shop_products order by product_key')).rows,before)
})

test('even an unintended trigger change to an unrelated product rolls the release back', async t => {
  const db = await fixture();t.after(() => db.close())
  await db.exec(`create function tamper_existing() returns trigger language plpgsql as $$begin
    update point_shop_products set point_price=0 where product_key='frame:existing';return new;end;$$;
    create trigger tamper_existing after insert on point_shop_products for each row execute function tamper_existing();`)
  await assert.rejects(db.exec(sql),/sensory_release_unrelated_catalog_changed/)
  await db.exec('rollback')
  const rows = (await db.query('select product_key,point_price from point_shop_products')).rows
  assert.deepEqual(rows,[{product_key:'frame:existing',point_price:700}])
})

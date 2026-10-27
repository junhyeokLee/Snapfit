import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'

const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const migration = readFileSync(new URL('../../supabase/migrations/20261022134610_retire_legacy_store_template_rows.sql', import.meta.url), 'utf8')
const legacy = [
  [46, '제주의 기록'], [48, '가족의 주말'], [49, '우리의 기념일'],
  [50, 'Wedding Editorial'], [51, 'Scrapbook'], [52, 'SAVE THE DATE'],
  [53, '화이트 에디토리얼'], [54, '필름 다이어리'], [55, '소프트 베이비북'],
]

test('data-only retirement deletes exactly matched rows and likes while retaining albums and current products', async () => {
  const db = new PGlite()
  try {
    await db.exec(`
      create table templates(id bigint primary key,title text,template_json jsonb);
      create table template_likes(id bigint primary key,template_id bigint references templates(id) on delete cascade);
      create table albums(id bigint primary key,cover_layers_json jsonb);
      create table point_shop_products(product_key text primary key);
      create table point_shop_ownership(id bigint primary key);
      create table point_ledger(id bigint primary key);
      insert into templates values(47,'제주의 기록',null),(999999,'보존할 현행 디자인',null);
      insert into template_likes values(47,47);
      insert into albums values(1,'{"savedTemplateTitle":"제주의 기록","layers":[{"text":"우리의 기념일"}]}');
      insert into point_shop_products select 'template:current-'||n from generate_series(1,68) n;
      insert into point_shop_ownership select n from generate_series(1,3) n;
      insert into point_ledger select n from generate_series(1,9) n;
    `)
    for (const [id, title] of legacy) {
      await db.query('insert into templates(id,title) values($1,$2)', [id, title])
      await db.query('insert into template_likes values($1,$1)', [id])
    }
    const customerData = (await db.query('select * from albums')).rows
    const products = (await db.query('select * from point_shop_products order by product_key')).rows
    await db.exec(migration)
    assert.deepEqual((await db.query('select id::int as id,title from templates order by id')).rows,
      [{ id: 47, title: '제주의 기록' }, { id: 999999, title: '보존할 현행 디자인' }])
    assert.deepEqual((await db.query('select id::int as id from template_likes')).rows, [{ id: 47 }])
    assert.deepEqual((await db.query('select * from albums')).rows, customerData)
    assert.deepEqual((await db.query('select * from point_shop_products order by product_key')).rows, products)
    assert.equal((await db.query('select * from point_shop_ownership')).rows.length, 3)
    assert.equal((await db.query('select * from point_ledger')).rows.length, 9)
    await db.exec(migration)
    assert.equal((await db.query('select * from templates')).rows.length, 2)
    await db.query('insert into templates(id,title) values($1,$2)', [46, '동일 번호의 다른 현행 디자인'])
    await db.exec(migration)
    assert.equal((await db.query('select * from templates where id=46')).rows.length, 1)
  } finally { await db.close() }
})

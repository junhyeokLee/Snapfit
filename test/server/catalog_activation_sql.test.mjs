// Offline verification of an explicitly exported release; never contacts Supabase.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'

const directory = process.env.POINT_SHOP_RELEASE_DIR
const { PGlite } = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')

async function fixture() {
  const db = new PGlite()
  await db.exec(`
    create table point_shop_products (
      product_key text primary key, asset_id text not null, kind text not null,
      title text not null, point_price integer check (point_price >= 0),
      is_active boolean not null default false,
      check (not is_active or point_price is not null)
    );
    create table point_wallets (user_id text primary key, balance integer);
    create table point_shop_ownership (user_id text, product_key text, point_price integer);
    insert into point_wallets values ('fixture-owner', 9000);
    insert into point_shop_ownership values ('fixture-owner', 'frame:storyVowGate', 375);
  `)
  return db
}

async function seed(db, key, price, active, kind = key.split(':')[0]) {
  await db.query(`insert into point_shop_products
    (product_key, asset_id, kind, title, point_price, is_active)
    values ($1,$2,$3,'Existing title',$4,$5)`, [key, key.split(':')[1], kind, price, active])
}

test('approved activation preserves live prices, purchases and unreviewed items', {
  skip: !directory,
}, async () => {
  const manifest = JSON.parse(readFileSync(join(directory, 'application.json'), 'utf8'))
  const activation = readFileSync(join(directory, 'activate-products.sql'), 'utf8')
  const verification = readFileSync(join(directory, 'verify-activation.sql'), 'utf8')
  assert.equal(manifest.status, 'prepared-not-executed')
  assert.equal(manifest.remoteVerified, false)
  assert.equal(manifest.previouslyHeldProductKeys.length, 44)
  const db = await fixture()
  try {
    await seed(db, 'template:velvet-vow-archive', 3210, true)
    await seed(db, 'frame:storyVowGate', 375, false)
    await seed(db, 'frame:unreviewed-release-draft', null, false)
    await db.exec(activation)
    await db.exec(activation)
    const check = (await db.query(verification)).rows
    assert.equal(check.length, manifest.activeProductCount)
    assert.ok(check.every(row => row.matches_expected === true))
    assert.equal(check.find(row => row.product_key === 'template:velvet-vow-archive').point_price, 3210)
    assert.equal(check.find(row => row.product_key === 'frame:storyVowGate').point_price, 375)
    assert.deepEqual((await db.query("select is_active,point_price from point_shop_products where product_key = 'frame:unreviewed-release-draft'")).rows, [
      {is_active:false,point_price:null},
    ])
    assert.deepEqual((await db.query('select * from point_wallets')).rows, [{user_id:'fixture-owner',balance:9000}])
    assert.deepEqual((await db.query('select * from point_shop_ownership')).rows, [{user_id:'fixture-owner',product_key:'frame:storyVowGate',point_price:375}])
    assert.equal((await db.query('select count(*)::integer as count from point_shop_products')).rows[0].count, manifest.activeProductCount + 1)
  } finally {
    await db.close()
  }
})

for (const scenario of ['identity-conflict', 'free-price-conflict']) {
  test(`activation rolls back every row on ${scenario}`, {skip: !directory}, async () => {
    const db = await fixture()
    try {
      const identityConflict = scenario === 'identity-conflict'
      await seed(db, identityConflict ? 'frame:storyVowGate' : 'frame:studioGallery', 150, false, identityConflict ? 'sticker' : 'frame')
      await assert.rejects(db.exec(readFileSync(join(directory, 'activate-products.sql'), 'utf8')),
        identityConflict ? /catalog_identity_or_active_template_changed/ : /free_catalog_paid_price_conflict/)
      await db.exec('rollback')
      assert.equal((await db.query('select count(*)::integer as count from point_shop_products')).rows[0].count, 1)
      assert.equal((await db.query('select is_active from point_shop_products')).rows[0].is_active, false)
      assert.equal((await db.query('select balance from point_wallets')).rows[0].balance, 9000)
    } finally {
      await db.close()
    }
  })
}

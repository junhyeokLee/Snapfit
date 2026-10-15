// Isolated in-memory Postgres, no vendor or Supabase network requests.
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const migration = readFileSync(new URL('../../supabase/migrations/20261008064729_redprinting_development_tests.sql', import.meta.url), 'utf8')
const owner = '11111111-1111-4111-8111-111111111111', other = '22222222-2222-4222-8222-222222222222'
async function setup() {
  const db = new PGlite()
  await db.exec('create role anon; create role authenticated; create role service_role bypassrls; create schema auth; create table auth.users(id uuid primary key); grant usage on schema public,auth to service_role,authenticated,anon;')
  await db.exec(migration)
  return db
}
test('development tables seed all 310 exact specs and are private even to signed-in users', async () => {
  const db = await setup()
  try {
    assert.equal((await db.query('select count(*)::int as total from redprinting_dev_mappings')).rows[0].total, 310)
    assert.equal((await db.query("select count(*)::int as total from redprinting_dev_settings where environment='development' and color_mode='UNCONFIRMED' and not test_deposit_enabled and not development_rgb_test_acknowledged")).rows[0].total, 1)
    await db.exec('set role authenticated;')
    for (const table of ['settings','codes','mappings','tests','api_gate']) await assert.rejects(() => db.query(`select * from public.redprinting_dev_${table}`), /permission denied/)
    await assert.rejects(() => db.query(`select public.redprinting_dev_acquire_slot('${owner}')`), /permission denied/)
    await db.exec('reset role;')
    const rls = await db.query("select relname,relrowsecurity from pg_class where relname like 'redprinting_dev_%' and relkind='r'")
    assert.equal(rls.rows.length, 5); assert.ok(rls.rows.every(row => row.relrowsecurity))
    const functions = await db.query("select prosecdef from pg_proc where proname like 'redprinting_dev_%'")
    assert.ok(functions.rows.every(row => !row.prosecdef))
  } finally { await db.close() }
})
test('database rejects live mode, invalid page counts and one code mapped to distinct specifications', async () => {
  const db = await setup()
  try {
    await db.exec('set role service_role;')
    await assert.rejects(() => db.exec("update redprinting_dev_settings set environment='production' where id=1"), /check constraint/)
    await assert.rejects(() => db.exec("insert into redprinting_dev_mappings(product_id,page_count) values('REDP_200_SOFT',21)"), /check constraint/)
    await db.exec("insert into redprinting_dev_codes(order_code) values('fixture-code'); update redprinting_dev_mappings set order_code='fixture-code' where product_id='REDP_200_SOFT' and page_count=20")
    await assert.rejects(() => db.exec("update redprinting_dev_mappings set order_code='fixture-code' where product_id='REDP_200_SOFT' and page_count=22"), /unique constraint/)
  } finally { await db.close() }
})
test('cross-invocation API leases space calls and cannot be released by another caller', async () => {
  const db = await setup()
  try {
    await db.exec('set role service_role;')
    assert.equal((await db.query(`select redprinting_dev_acquire_slot('${owner}') as wait`)).rows[0].wait, 0)
    await db.query(`select redprinting_dev_release_slot('${other}')`)
    assert.ok((await db.query(`select redprinting_dev_acquire_slot('${other}') as wait`)).rows[0].wait > 30000)
    await db.query(`select redprinting_dev_release_slot('${owner}')`)
    const wait = (await db.query(`select redprinting_dev_acquire_slot('${other}') as wait`)).rows[0].wait
    assert.ok(wait > 0 && wait <= 600)
    await db.exec("update redprinting_dev_api_gate set next_call_at=clock_timestamp()-interval '1 second'")
    assert.equal((await db.query(`select redprinting_dev_acquire_slot('${other}') as wait`)).rows[0].wait, 0)
  } finally { await db.close() }
})
test('test order identities and work leases survive retries without allowing parallel requests', async () => {
  const db = await setup()
  try {
    await db.exec('set role service_role;')
    await db.exec(`insert into redprinting_dev_tests(id,request_id,product_id,page_count,order_num,recipient) values('${owner}','${other}','REDP_200_SOFT',20,'SFDfixture','{}')`)
    await assert.rejects(() => db.exec(`insert into redprinting_dev_tests(request_id,product_id,page_count,order_num,recipient) values('${other}','REDP_200_SOFT',20,'SFDnew','{}')`), /unique constraint/)
    assert.equal((await db.query(`select redprinting_dev_acquire_test('${owner}','${owner}') as claimed`)).rows[0].claimed, true)
    assert.equal((await db.query(`select redprinting_dev_acquire_test('${owner}','${other}') as claimed`)).rows[0].claimed, false)
    await db.query(`select redprinting_dev_release_test('${owner}','${other}')`)
    assert.equal((await db.query(`select redprinting_dev_acquire_test('${owner}','${other}') as claimed`)).rows[0].claimed, false)
    await db.query(`select redprinting_dev_release_test('${owner}','${owner}')`)
    assert.equal((await db.query(`select redprinting_dev_acquire_test('${owner}','${other}') as claimed`)).rows[0].claimed, true)
  } finally { await db.close() }
})

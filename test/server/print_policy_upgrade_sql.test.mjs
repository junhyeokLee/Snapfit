// Execute both versions against real local PostgreSQL with synthetic orders.
// No remote data, PG calls, live configuration changes or production files.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { fixture, prepare, commit, owner } from './fixtures/app_pdf_database.mjs'
import { printCheckoutConsent } from '../../supabase/functions/_shared/print-checkout-consent.ts'

const readMigration = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8')
const oldMigration = readMigration('20261018183536_print_public_catalog_and_order_consent.sql')
const upgrade = readMigration('20261030090711_print_commerce_registered_seller_point_policy.sql')

async function setup(approved = true) {
  const db = await fixture(approved)
  await db.exec(`
    create table private.print_supplier_quotes(product_id text,page_count integer,confirmed boolean,quantity integer);
    create table public.redprinting_dev_codes(order_code text primary key,use_yn text);
    create table public.redprinting_dev_mappings(product_id text,page_count integer,order_code text,exact_match_confirmed boolean,vendor_use_yn text,vendor_order_yn text);
  `)
  await db.exec(oldMigration)
  return db
}

const current = async db => (await db.query('select private.current_print_checkout_consent() value')).rows[0].value
const policies = async db => (await db.query('select version,documents from private.print_commerce_policy_versions order by version')).rows
const record = (db, intent, consent) => db.query('select public.record_print_checkout_consent($1,$2,$3)', [owner, intent.payment_id, consent])
const issue = (db, intent) => db.query('update private.print_checkout_intents set sdk_issued_at=now() where id=$1', [intent.id])

test('policy upgrade preserves old immutable evidence and requires a fresh acceptance before first SDK issuance', async t => {
  const db = await setup();t.after(() => db.close())
  const oldConsent = await current(db), oldPolicies = await policies(db)
  const pending = await prepare(db)
  await record(db, pending, oldConsent)
  const before = (await db.query('select * from private.print_checkout_consents where intent_id=$1', [pending.id])).rows[0]
  await db.exec(upgrade)
  assert.deepEqual(await current(db), printCheckoutConsent)
  const versions = await policies(db)
  assert.equal(versions.length, 2)
  assert.deepEqual(versions[0], oldPolicies[0])
  assert.equal(versions[1].version, printCheckoutConsent.policyVersion)
  assert.equal(versions[1].documents.bundleVersion, printCheckoutConsent.policyVersion)
  assert.deepEqual((await db.query('select * from private.print_checkout_consents where intent_id=$1', [pending.id])).rows[0], before)
  await assert.rejects(issue(db, pending), /print_checkout_consent_required/)
  await assert.rejects(record(db, pending, oldConsent), /print_checkout_consent_required/)
  await assert.rejects(record(db, pending, printCheckoutConsent), /print_checkout_consent_conflict/)
  await assert.rejects(db.exec('update private.print_commerce_policy_versions set documents=\'{}\''), /print_policy_version_immutable/)
  await assert.rejects(db.exec('delete from private.print_checkout_consents'), /print_consent_immutable/)
  const fresh = await prepare(db, {request:'55555555-5555-4555-8555-555555555555'})
  await record(db, fresh, printCheckoutConsent)
  await issue(db, fresh)
  const saved = (await db.query('select policy_snapshot from private.print_checkout_consents where intent_id=$1', [fresh.id])).rows[0]
  assert.deepEqual(saved.policy_snapshot, versions[1].documents)
})

test('already-issued old SDK payment can still reconcile through the unchanged receipt RPC after policy upgrade', async t => {
  const db = await setup();t.after(() => db.close())
  const oldConsent = await current(db), intent = await prepare(db)
  await record(db, intent, oldConsent)
  await issue(db, intent)
  const before = (await db.query('select * from private.print_checkout_consents where intent_id=$1', [intent.id])).rows[0]
  await db.exec(upgrade)
  const paid = await commit(db, intent)
  assert.equal(paid.status, 'PAID')
  assert.equal(paid.payment_receipt.isTest, false) // Synthetic receipt in local DB only.
  const order = (await db.query('select status,verified_payment_id from orders where order_id=$1', [intent.order_id])).rows[0]
  assert.equal(order.status, 'PAYMENT_COMPLETED')
  assert.equal(order.verified_payment_id, intent.payment_id)
  assert.deepEqual((await db.query('select * from private.print_checkout_consents where intent_id=$1', [intent.id])).rows[0], before)
  assert.equal((await db.query('select count(*)::integer n from private.print_checkout_consents')).rows[0].n, 1)
})

test('upgrading policy does not open any sales gate or broaden consent/snapshot access', async t => {
  const db = await setup(false);t.after(() => db.close())
  const before = (await db.query('select to_jsonb(c) value from private.print_sales_configuration c')).rows[0].value
  await db.exec(upgrade)
  assert.deepEqual((await db.query('select to_jsonb(c) value from private.print_sales_configuration c')).rows[0].value, before)
  assert.equal(before.enabled, false)
  for (const role of ['anon','authenticated']) {
    await db.exec(`set role ${role}`)
    for (const sql of ['select private.current_print_checkout_consent()', 'select * from private.print_commerce_policy_versions', 'select * from private.print_checkout_consents']) {
      await assert.rejects(db.exec(sql), /permission denied/)
    }
    await db.exec('reset role')
  }
  await db.exec('set role service_role')
  assert.deepEqual(await current(db), printCheckoutConsent)
  await db.exec('reset role')
})

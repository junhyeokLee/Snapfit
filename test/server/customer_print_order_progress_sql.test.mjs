import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite')
const migration = readFileSync(new URL('../../supabase/migrations/20261015050304_customer_print_order_progress.sql', import.meta.url), 'utf8')
const owner = '11111111-1111-4111-8111-111111111111', other = '22222222-2222-4222-8222-222222222222'
const now = '2026-10-15T00:00:00Z', fingerprint = 'a'.repeat(64)
const manifest = { cover: { sha256: 'b'.repeat(64), pageCount: 1 }, interior: { sha256: 'c'.repeat(64), pageCount: 80 },
  sourceFingerprint: fingerprint, spec: { specVersion: 'SYNTHETIC_V1' } }
async function fixture() {
  const db = new PGlite()
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema private;
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to authenticated;
    create table public.orders(order_id text primary key,user_id uuid,status text,page_count integer,
      print_manifest jsonb,print_upload_fingerprint text,print_spec_snapshot jsonb,print_spec_confirmed_at timestamptz,
      print_cover_pdf_path text,print_interior_pdf_path text,print_fulfillment_status text,print_vendor text,
      print_vendor_order_id text,print_submitted_at timestamptz,print_package_generated_at timestamptz,
      print_accepted_at timestamptz,print_file_checked_at timestamptz,print_requires_action boolean default false,
      print_customer_request_hold boolean default false,print_preparation_aborted_at timestamptz,payment_confirmed_at timestamptz,
      shipped_at timestamptz,courier text,tracking_number text);
    alter table public.orders enable row level security;
    create policy own_order_read on public.orders for select to authenticated using(user_id=auth.uid());
    grant select on public.orders to authenticated;
    create table private.print_checkout_intents(user_id uuid,order_id text,payment_id text);
    alter table private.print_checkout_intents enable row level security;
    grant usage on schema private,public to service_role;grant select on private.print_checkout_intents to service_role;
    create function public.get_owned_print_checkout(p_actor uuid,p_payment_id text,p_request_id uuid) returns jsonb
    language sql stable security invoker as $$select jsonb_build_object('paymentId',i.payment_id,'orderId',i.order_id)
      from private.print_checkout_intents i where i.user_id=p_actor and i.payment_id=p_payment_id$$;
    revoke all on function public.get_owned_print_checkout(uuid,text,uuid) from public,anon,authenticated;
    grant execute on function public.get_owned_print_checkout(uuid,text,uuid) to service_role;`)
  await db.exec(migration)
  await db.query(`insert into public.orders(order_id,user_id,status,page_count,print_manifest,print_upload_fingerprint,print_spec_snapshot,
    print_spec_confirmed_at,print_cover_pdf_path,print_interior_pdf_path,print_fulfillment_status,print_vendor,print_package_generated_at)
    values('owned-order',$1,'PAYMENT_COMPLETED',80,$2,$3,$4,$5,'private/cover.pdf','private/interior.pdf','READY','REDPRINTING',$5)`,
    [owner, manifest, fingerprint, { specVersion: 'SYNTHETIC_V1' }, now])
  await db.exec(`select set_config('request.jwt.claim.sub','${owner}',false);set role authenticated;`)
  return db
}
const progress = async db => (await db.query("select public.fetch_my_print_order_progress('owned-order') value")).rows[0].value
async function patch(db, sql) {
  await db.exec(`reset role;update public.orders set ${sql} where order_id='owned-order';set role authenticated;`)
}

test('a verified client PDF waits for automatic submission without implying supplier acceptance', async () => {
  const db = await fixture()
  try {
    const value = await progress(db)
    assert.equal(value.customerStage, 'FILES_READY')
    assert.equal(value.preflightPassed, true)
    assert.equal(value.vendorAcceptedAt, null)
    assert.equal(value.fileCheckedAt, null)
    assert.doesNotMatch(JSON.stringify(value), /private\/|sha256|sourceFingerprint|specVersion|amount|cost|recipient/)
    // A timestamp or file-analysis bit alone cannot turn a pending/unknown
    // supplier request into a received order.
    await patch(db, `print_submitted_at='${now}',print_file_checked_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'FILES_READY')
    assert.equal((await progress(db)).vendorAcceptedAt, null)
    await patch(db, "print_upload_fingerprint='wrong'")
    assert.equal((await progress(db)).preflightPassed, false)
    assert.notEqual((await progress(db)).customerStage, 'FILES_READY')
  } finally { await db.close() }
})

test('verified supplier receipt, analysis, manufacture and tracking progress keep distinct evidence', async () => {
  const db = await fixture()
  try {
    await patch(db, `print_fulfillment_status='SUBMITTED',print_vendor_order_id='SFO_33333333333343338333333333333333',print_submitted_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'FILE_CHECKING')
    assert.equal((await progress(db)).fileCheckedAt, null)
    await patch(db, `print_file_checked_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'PRODUCTION_PENDING')
    assert.equal((await progress(db)).productionStartedAt, null)
    await patch(db, `status='IN_PRODUCTION',print_fulfillment_status='ACCEPTED',print_accepted_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'PRODUCTION')
    assert.ok((await progress(db)).productionStartedAt)
    await patch(db, `courier='TEST_COURIER',tracking_number='SYNTHETIC_TRACKING'`)
    assert.equal((await progress(db)).trackingNumber, null)
    await patch(db, `status='SHIPPING',shipped_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'SHIPPING')
    assert.equal((await progress(db)).trackingNumber, 'SYNTHETIC_TRACKING')
    await patch(db, "status='DELIVERED'")
    assert.equal((await progress(db)).customerStage, 'DELIVERED')
  } finally { await db.close() }
})

test('cancellation hold, reviewed exceptions and proven preparation abort are visible without hiding physical tracking', async () => {
  const db = await fixture()
  try {
    await patch(db, 'print_customer_request_hold=true')
    assert.equal((await progress(db)).customerStage, 'HOLD')
    assert.equal((await progress(db)).requiresAction, true)
    await patch(db, 'print_customer_request_hold=false,print_requires_action=true')
    assert.equal((await progress(db)).customerStage, 'REVIEW_REQUIRED')
    await patch(db, "status='SHIPPING',print_customer_request_hold=true")
    assert.equal((await progress(db)).customerStage, 'SHIPPING')
    await patch(db, `status='PAYMENT_PENDING',print_preparation_aborted_at='${now}',payment_confirmed_at=null`)
    assert.equal((await progress(db)).customerStage, 'CANCELED')
    await patch(db, `payment_confirmed_at='${now}'`)
    assert.equal((await progress(db)).customerStage, 'HOLD')
    await patch(db, "status='CANCELED',print_requires_action=false")
    assert.equal((await progress(db)).customerStage, 'CANCELED')
    assert.equal((await progress(db)).requiresAction, false)
  } finally { await db.close() }
})

test('the progress function keeps RLS and ownership checks and never grants anonymous access', async () => {
  const db = await fixture()
  try {
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`)
    await assert.rejects(progress(db), /order_access_denied/)
    await db.exec("select set_config('request.jwt.claim.sub','',false);")
    await assert.rejects(progress(db), /authentication_required/)
    await db.exec('reset role;set role anon;')
    await assert.rejects(progress(db), /permission denied/)
    await db.exec('reset role;')
    assert.equal((await db.query("select prosecdef from pg_proc where proname='fetch_my_print_order_progress'")).rows[0].prosecdef, false)
    assert.doesNotMatch(migration, /update\s+(?:private\.)?print_sales|PRINT_.*ENABLED|security\s+definer/i)
  } finally { await db.close() }
})

test('service-only order-history recovery checks the purchaser before delegating to the existing frozen-invoice read', async () => {
  const db = await fixture()
  const orderId = 'ordp_33333333-3333-4333-8333-333333333333', paymentId = 'SFP_44444444-4444-4444-8444-444444444444'
  try {
    await db.exec('reset role;')
    await db.query('insert into private.print_checkout_intents values($1,$2,$3)', [owner, orderId, paymentId])
    await db.exec('set role service_role;')
    assert.deepEqual((await db.query('select get_owned_print_checkout_by_order($1,$2) value', [owner, orderId])).rows[0].value,
      { orderId, paymentId })
    await assert.rejects(db.query('select get_owned_print_checkout_by_order($1,$2)', [other, orderId]), /print_checkout_not_found/)
    await assert.rejects(db.query('select get_owned_print_checkout_by_order($1,$2)', [owner, 'ordp_invalid']), /invalid_print_checkout_request/)
    for (const role of ['anon', 'authenticated']) {
      await db.exec(`reset role;set role ${role};`)
      await assert.rejects(db.query('select get_owned_print_checkout_by_order($1,$2)', [owner, orderId]), /permission denied/)
    }
    await db.exec('reset role;')
    assert.equal((await db.query("select prosecdef from pg_proc where proname='get_owned_print_checkout_by_order'")).rows[0].prosecdef, false)
  } finally { await db.close() }
})

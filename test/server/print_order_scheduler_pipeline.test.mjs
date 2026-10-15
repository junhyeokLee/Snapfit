import assert from 'node:assert/strict'
import { test } from 'node:test'
import { existsSync, readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { createHmac, randomUUID } from 'node:crypto'
import { createPrintOrderSchedulerHandler, printSchedulerSignedPayload } from '../../supabase/functions/_shared/print-order-scheduler.ts'
import { PrintFulfillmentWorker } from '../../supabase/functions/_shared/print-fulfillment-worker.ts'
import { createPdfInspector, validatePrintPdf } from '../../supabase/functions/_shared/print-package.ts'
import { getPrintSpec, sha256, sourceFingerprint } from '../../supabase/functions/_shared/print-contract.ts'
import { makeFixture, owner } from './fixtures/print_worker_fixture.mjs'

/**
 * Local provider/database adapters only. These synthetic LIVE observations are
 * strictly in-memory unit fixtures, never inserted into Supabase or sent to PG.
 * The real Flutter PDF bytes pass the production PDF inspector before payment.
 */
test('uploaded real Flutter PDF survives app closure: Cron verifies money then submits/confirms/tracks, without a renderer process', async t => {
  const base = new URL('../../output/pdf/print-worker-fixture-2026-10-14/', import.meta.url)
  if (!existsSync(new URL('cover.pdf', base)) || !existsSync(new URL('interior.pdf', base))) {
    t.skip('Generate the actual Flutter soft20 fixture first'); return
  }
  const pdfLib = (await import(process.env.PDF_LIB_MODULE ? pathToFileURL(process.env.PDF_LIB_MODULE).href : 'pdf-lib')).default
  const inspect = createPdfInspector(pdfLib), spec = JSON.parse(readFileSync(new URL('fixture.json', base), 'utf8')).spec
  const source = JSON.parse(readFileSync(new URL('fixture.json', base), 'utf8')).snapshot
  const cover = new Uint8Array(readFileSync(new URL('cover.pdf', base))), interior = new Uint8Array(readFileSync(new URL('interior.pdf', base)))
  const f = makeFixture({ spec, snapshot: source, inspectPdf: inspect, cover, interior })
  const verifiedSpec = getPrintSpec(f.order)
  await validatePrintPdf(cover, 1, verifiedSpec.cover.widthMm, verifiedSpec.cover.heightMm, inspect, verifiedSpec.cover.trim)
  await validatePrintPdf(interior, 20, verifiedSpec.interior.trimWidthMm + verifiedSpec.interior.bleedMm * 2,
    verifiedSpec.interior.trimHeightMm + verifiedSpec.interior.bleedMm * 2, inspect)
  // Simulate the atomic transfer of already verified prepayment artwork into
  // its paid immutable order. No PDF regeneration occurs after this point.
  const uploadId = '44444444-4444-4444-8444-444444444444'
  Object.assign(f.order, { status: 'PAYMENT_PENDING', verified_payment_id: 'SFP_33333333-3333-4333-8333-333333333333',
    print_upload_id: uploadId, print_fulfillment_status: 'READY', print_spec_confirmed_at: '2026-10-15T00:00:00Z' })
  f.expected.paymentId = f.order.verified_payment_id; f.receipt.paymentId = f.order.verified_payment_id
  f.order.print_cover_pdf_path = `${f.order.order_id}/${uploadId}/cover.pdf`
  f.order.print_interior_pdf_path = `${f.order.order_id}/${uploadId}/interior.pdf`
  f.files.set(f.order.print_cover_pdf_path, cover); f.files.set(f.order.print_interior_pdf_path, interior)
  f.order.print_manifest = { spec: verifiedSpec, sourceFingerprint: await sourceFingerprint(f.order),
    cover: { byteLength: cover.byteLength, sha256: await sha256(cover) }, interior: { byteLength: interior.byteLength, sha256: await sha256(interior) } }
  f.job.event_type = 'SUBMIT'; f.job.payload.queryOnly = false
  const events = []; let pendingPayment = true, appClosed = false
  const legacy = f.db.rpc.bind(f.db)
  const database = { ...f.db, async rpc(name, args) {
    events.push(name)
    if (name === 'consume_print_order_scheduler_nonce') return { data: true, error: null }
    if (name === 'record_print_order_scheduler_heartbeat') return { data: null, error: null }
    if (name === 'claim_production_print_payment_rechecks') return { data: pendingPayment ? [{ user_id: owner, payment_id: f.order.verified_payment_id }] : [], error: null }
    if (name === 'list_print_order_requests') return { data: [], error: null }
    if (name === 'claim_print_app_pdf_fulfillment_job') {
      if (f.order.status === 'PAYMENT_PENDING') return { data: null, error: null }
      assert.ok(['SUBMIT', 'CONFIRM', 'POLL'].includes(f.job.event_type))
      assert.equal(f.order.print_manifest.cover.sha256, await sha256(cover))
      return legacy('claim_print_fulfillment_job', args)
    }
    return legacy(name, args)
  } }
  const fulfillment = new PrintFulfillmentWorker(database, f.config, f.vendor, f.sender, {
    inspectPdf: inspect, now: f.now, paymentLookup: f.paymentLookup,
  })
  const secret = 'a'.repeat(64), handler = createPrintOrderSchedulerHandler({
    secret: () => secret, createAdminDatabase: () => database,
    configuration: () => ({ enabled: true, paymentObservable: true, refundsEnabled: true, fulfillmentReady: true }),
    async reconcile(db, payment) {
      assert.equal(appClosed, true)
      assert.equal(payment.paymentId, f.order.verified_payment_id)
      const observed = await f.paymentLookup()
      assert.equal(observed.isTest, false); assert.equal(observed.amount, f.order.amount)
      pendingPayment = false; f.order.status = 'PAYMENT_COMPLETED'
      return { verifiedPaid: true }
    },
    async resolve() { throw new Error('There is no cancellation in this fixture') },
    advance: (db, id, worker) => fulfillment.advance(id, worker), now: f.now, randomUUID: () => owner,
  })
  const tick = async () => {
    f.advanceTime(2000000)
    const timestamp = Math.floor(f.now() / 1000), nonce = randomUUID()
    const signature = createHmac('sha256', secret).update(printSchedulerSignedPayload(timestamp, nonce)).digest('hex')
    const response = await handler(new Request('https://local-fixture.invalid/scheduler', {
      method: 'POST', headers: { 'X-Snapfit-Scheduler-Timestamp': String(timestamp), 'X-Snapfit-Scheduler-Nonce': nonce,
        'X-Snapfit-Scheduler-Signature': signature }, body: '{}',
    }))
    assert.equal(response.status, 200)
    const result = await response.json()
    assert.equal(result.fulfillment.errors, 0)
    return result
  }
  appClosed = true
  const paid = await tick()
  assert.equal(paid.payments.verifiedPaid, 1)
  assert.equal(f.order.print_fulfillment_status, 'SUBMITTED')
  assert.equal(f.job.event_type, 'POLL')
  Object.assign(f.status, { statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileProcessYn: 'Y', fileError: false })
  await tick(); assert.equal(f.job.event_type, 'CONFIRM')
  await tick(); assert.equal(f.order.status, 'IN_PRODUCTION')
  Object.assign(f.status, { statusCode: 'PGS_55', statusCodeOrg: 'PGS_55', courier: '로컬 모의 배송사', trackingNumber: 'LOCAL-STUB-ONLY' })
  await tick(); assert.equal(f.order.status, 'SHIPPING')
  assert.equal(f.order.tracking_number, 'LOCAL-STUB-ONLY')
  assert.equal(f.calls.filter(call => call?.supplierSubmit).length, 1)
  assert.equal(f.calls.filter(call => call === 'supplier-deposit').length, 1)
  assert.equal(events.some(name => /render|snapshot|uploads|renew/.test(name)), false)
  assert.equal(f.order.status === 'DELIVERED', false)
})

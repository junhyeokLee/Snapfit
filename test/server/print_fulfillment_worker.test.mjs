import assert from 'node:assert/strict'
import { test } from 'node:test'
import { PrintFulfillmentWorker, createPrintFulfillmentWorkerHandler } from '../../supabase/functions/_shared/print-fulfillment-worker.ts'
import { assertFulfillmentAssetSources } from '../../supabase/functions/_shared/print-fulfillment-assets.ts'
import { getPrintSpec, ceilMoneyRate, calculateContribution } from '../../supabase/functions/_shared/print-contract.ts'
import { supplierProgress, nextSupplierPoll, RedprintingFulfillmentClient, vendorDepositBalance } from '../../supabase/functions/_shared/print-fulfillment-vendor.ts'
import { PortOnePrintPaymentError } from '../../supabase/functions/_shared/portone-print-payment.ts'
import { RedprintingError, orderStatus } from '../../supabase/functions/_shared/redprinting.ts'
import { makeFixture, owner, jobId } from './fixtures/print_worker_fixture.mjs'
import { workerTick, rendererEnvironment, WorkerTransport } from '../../tool/print_fulfillment/run_worker.mjs'

const worker = f => new PrintFulfillmentWorker(f.db, f.config, f.vendor, f.sender, { now: f.now, paymentLookup: f.paymentLookup, inspectPdf: f.inspectPdf })
const ready = f => { f.order.print_fulfillment_status = 'READY'; f.order.print_spec_confirmed_at = '2026-10-14T00:30:00Z'; f.job.event_type = 'SUBMIT'; f.job.payload.queryOnly = true }

test('fee reserves match exact decimal PostgreSQL ceil, including binary rounding and scientific rates', () => {
  assert.equal(Math.ceil(69900 * .07), 4894)
  assert.equal(ceilMoneyRate(69900, .07), 4893)
  assert.equal(ceilMoneyRate(49900, .05), 2495)
  assert.equal(ceilMoneyRate(49901, .05), 2496)
  assert.equal(ceilMoneyRate(49900, 1e-7), 1)
  assert.equal(ceilMoneyRate(49900, 0), 0)
  const f = makeFixture()
  const costs = calculateContribution({ ...f.order, amount: 69900, print_cost_snapshot: { ...f.costSnapshot, paymentFeeRate: .07 } },
    { actualPrintCost: 21230, actualShippingCost: 3500, actualPackagingCost: 0 })
  assert.equal(costs.payment_fee_reserve, 4893)
})

test('frozen approved spec is used exactly; missing approval never falls back to inferred geometry', () => {
  const f = makeFixture()
  assert.deepEqual(getPrintSpec(f.order), f.order.print_spec_snapshot)
  const legacy = getPrintSpec({ ...f.order, checkout_flow: null })
  assert.equal(legacy.verified, false)
  for (const update of [undefined, { ...f.order.print_spec_snapshot, verified: false },
    { ...f.order.print_spec_snapshot, pageCount: 22 }, { ...f.order.print_spec_snapshot, cover: { ...f.order.print_spec_snapshot.cover, widthMm: 1 } }]) {
    assert.throws(() => getPrintSpec({ ...f.order, print_spec_snapshot: update }), /frozen_print_spec/)
  }
})

test('source policy allows only frozen owners in current project storage or bundled artwork', () => {
  assert.doesNotThrow(() => assertFulfillmentAssetSources({ textFillImageUrl: '@photo-layer-1',
    originalUrl: `supabase://album-assets/${owner}/photo.jpg` }, 'https://fixture.supabase.co', [owner]))
  for (const url of [`https://fixture.supabase.co/storage/v1/object/public/album-assets/${owner}/photo.jpg`,
    `supabase://album-assets/${owner}/photo.jpg`, 'asset:assets/sticker/studio/pressed_cosmos.png']) {
    assert.doesNotThrow(() => assertFulfillmentAssetSources({ originalUrl: url }, 'https://fixture.supabase.co', [owner]))
  }
  for (const url of ['http://127.0.0.1/private', 'http://169.254.169.254/latest/meta-data', 'https://localhost/private',
    'file:///etc/passwd', 'https://external.invalid/photo.jpg', 'data:image/png;base64,fixture',
    `https://other.supabase.co/storage/v1/object/public/album-assets/${owner}/photo.jpg`,
    `supabase://album-assets/${owner}/../secret`, 'asset:assets/sticker/../../.env',
    'asset:assets/fonts/private.txt', 'supabase://album-assets/22222222-2222-4222-8222-222222222222/photo.jpg']) {
    assert.throws(() => assertFulfillmentAssetSources({ layers_json: JSON.stringify([{ originalUrl: url }]) }, 'https://fixture.supabase.co', [owner]), /print_asset_access_requires_review/)
    for (const key of ['cover_original_url', 'cover_image_url', 'cover_preview_url', 'cover_thumbnail_url']) {
      assert.throws(() => assertFulfillmentAssetSources({ album: { [key]: url } }, 'https://fixture.supabase.co', [owner]), /print_asset_access_requires_review/)
    }
  }
})

test('revoked exact supplier/file/sample approval holds new rendering and manufacture without swapping specifications', async () => {
  for (const stage of ['RENDER', 'SUBMIT', 'CONFIRM']) {
    const f = makeFixture(), w = worker(f)
    if (stage !== 'RENDER') ready(f)
    f.job.event_type = stage; f.job.payload.queryOnly = false; f.approvalCurrent = false
    if (stage === 'CONFIRM') { f.order.print_fulfillment_status = 'SUBMITTED'; f.status.fileProcessYn = 'Y'; f.order.print_file_checked_at = '2026-10-14T00:40:00Z' }
    await w.claim(owner)
    await assert.rejects(stage === 'RENDER' ? w.snapshot(jobId, owner) : w.advance(jobId, owner), /print_spec_approval_revoked/)
    assert.equal(f.job.state, 'FAILED')
    assert.equal(f.calls.some(call => call?.supplierSubmit || call === 'supplier-deposit'), false)
    assert.equal(f.order.print_spec_snapshot.specVersion, 'LOCAL_STUB_APPROVED_SOFT20_V1')
  }
})

test('disabled runtime cannot publish readiness or claim a paid order', async () => {
  for (const configuration of [{ enabled: false }, { environment: 'test' }, { depositEnabled: false }, { vendorReady: false }, { paymentApiSecret: '' }]) {
    const f = makeFixture({ configuration })
    assert.equal(await worker(f).claim(owner), null)
    assert.equal(f.calls[0].args.p_runtime_ready, false)
    assert.equal(f.calls.includes('latest-live-payment'), false)
  }
})

test('active lease is required for all purchased snapshots and cannot be borrowed by another runner', async () => {
  const f = makeFixture(), w = worker(f)
  await w.claim(owner)
  await assert.rejects(w.snapshot(jobId, '33333333-3333-4333-8333-333333333333'), /print_worker_database_unavailable/)
  f.advanceTime(121000)
  await assert.rejects(w.uploads(jobId, owner), /print_worker_database_unavailable/)
  assert.equal(f.order.print_fulfillment_status, 'AWAITING_RENDER')
})

test('HTTP 200 with an unmatched per-item response stays unknown and recovery never reposts', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.job.payload.queryOnly = false
  f.order.print_manifest = {}; f.order.print_upload_id = 'fixture-upload'
  // Exercise acceptance/recovery independently of the separately tested PDFs.
  w.fileLinks = async () => ({ cover: 'https://fixture.invalid/cover.pdf', interior: 'https://fixture.invalid/interior.pdf' })
  f.vendor.submit = async () => { f.calls.push('supplier-post'); return { success: true, data: [] } }
  await w.claim(owner)
  await assert.rejects(w.advance(jobId, owner), /supplier_submission_unknown/)
  assert.equal(f.job.state, 'UNKNOWN'); assert.equal(f.job.payload.queryOnly, true)
  assert.equal(f.order.print_fulfillment_status, 'READY')
  await w.claim(owner); await w.advance(jobId, owner)
  assert.equal(f.order.print_fulfillment_status, 'SUBMITTED')
  assert.equal(f.calls.filter(call => call === 'supplier-post').length, 1)
})

test('official success/message summary acknowledges the request but only matching status proves receipt', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.job.payload.queryOnly = false
  w.fileLinks = async () => ({ cover: 'https://fixture.invalid/cover.pdf', interior: 'https://fixture.invalid/interior.pdf' })
  f.vendor.submit = async () => { f.calls.push('supplier-post'); return { success: true, message: '' } }
  await w.claim(owner); await w.advance(jobId, owner)
  assert.equal(f.calls.filter(call => call === 'supplier-post').length, 1)
  assert.ok(f.calls.includes('supplier-status'))
  assert.equal(f.order.print_fulfillment_status, 'SUBMITTED')
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  assert.equal(f.order.print_file_checked_at, undefined)
  assert.equal(f.order.print_accepted_at, undefined)
  assert.equal(f.calls.includes('supplier-deposit'), false)
})

test('acknowledged summary followed by status 404 remains query-only without a second POST', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.job.payload.queryOnly = false
  w.fileLinks = async () => ({ cover: 'https://fixture.invalid/cover.pdf', interior: 'https://fixture.invalid/interior.pdf' })
  f.vendor.submit = async () => { f.calls.push('supplier-post'); return { success: true, message: '' } }
  f.vendor.status = async () => { f.calls.push('supplier-status'); throw new RedprintingError('vendor_http_404', 404) }
  const stable = f.job.payload.vendorOrderNum
  for (let attempts = 0; attempts < 3; attempts++) {
    await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /vendor_http_404/)
  }
  assert.equal(f.calls.filter(call => call === 'supplier-post').length, 1)
  assert.equal(f.calls.filter(call => call === 'supplier-status').length, 3)
  assert.equal(f.job.payload.vendorOrderNum, stable)
  assert.equal(f.job.payload.queryOnly, true)
  assert.equal(f.job.state, 'UNKNOWN')
  assert.equal(f.order.print_fulfillment_status, 'READY')
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
})

test('submission timeout stores stable identity and repeated 404 polling never creates a second order', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.job.payload.queryOnly = false
  w.fileLinks = async () => ({ cover: 'https://fixture.invalid/cover.pdf', interior: 'https://fixture.invalid/interior.pdf' })
  f.vendor.submit = async () => { f.calls.push('supplier-post'); throw new RedprintingError('vendor_request_uncertain', 502, true) }
  f.vendor.status = async () => { throw new RedprintingError('vendor_http_404', 404) }
  const stable = f.job.payload.vendorOrderNum
  for (let attempt = 0; attempt < 3; attempt++) {
    await w.claim(owner); await assert.rejects(w.advance(jobId, owner))
  }
  assert.equal(f.job.payload.vendorOrderNum, stable)
  assert.equal(f.calls.filter(call => call === 'supplier-post').length, 1)
  assert.equal(f.job.state, 'UNKNOWN')
})

test('production-blocking org06 or unknown API06 holds even when error detail is blank', async () => {
  for (const original of ['PGS_06', '']) {
    const f = makeFixture(), w = worker(f)
    ready(f); f.status.statusCode = 'PGS_06'; f.status.statusCodeOrg = original; f.status.fileProcessYn = 'Y'
    await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /supplier_file_error/)
    assert.equal(f.job.state, 'FAILED'); assert.equal(f.order.status, 'PAYMENT_COMPLETED')
    assert.equal(f.order.print_file_checked_at, undefined)
    assert.equal(f.calls.includes('supplier-deposit'), false)
  }
})

test('org05 warning with Y and no explicit detail allows confirmation but never fabricates production or sample approval', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f)
  Object.assign(f.status, { statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileProcessYn: 'Y', fileError: false, fileErrorSummary: '' })
  const progress = supplierProgress(f.status)
  assert.equal(progress.fileWarning, true)
  assert.equal(progress.fileChecked, true)
  assert.equal(progress.needsAttention, false)
  assert.equal(progress.productionStarted, false)
  assert.equal(progress.shipped, false)
  assert.equal(progress.customerStage, 'FILE_CHECKED')
  await w.claim(owner); await w.advance(jobId, owner)
  assert.equal(f.job.event_type, 'CONFIRM')
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  assert.ok(f.order.print_file_checked_at)
  assert.equal(f.order.print_accepted_at, undefined)
  let confirmations = 0
  f.vendor.confirm = async () => { confirmations++; return { success: true } }
  await w.claim(owner); await w.advance(jobId, owner)
  // A confirmation response and the same internal warning still do not prove
  // production. Durable deposit markers continue to protect later poll cycles.
  await w.claim(owner); await w.advance(jobId, owner)
  assert.equal(confirmations, 1)
  assert.equal(f.job.payload.depositAttempted, true)
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  assert.equal(f.order.print_accepted_at, undefined)
  assert.equal(f.order.print_fulfillment_status, 'SUBMITTED')
  assert.equal(f.calls.some(call => call?.supplierSubmit), false)
  assert.ok(f.calls.includes('latest-live-payment'))
})

test('org05 explicit errors remain blocked and PGS07 N waits without confirmation', async () => {
  const f = makeFixture(), w = worker(f)
  const normalized = orderStatus({ success: true, order_status: [{ order_num: f.job.payload.vendorOrderNum, order_seq: 1,
    status_code: 'PGS_06', status_code_org: 'PGS_05', file_process_yn: 'Y', file_error_log: '확인된 인쇄 파일 오류' }] }, f.job.payload.vendorOrderNum, 1)
  assert.equal(supplierProgress(normalized).needsAttention, true)
  assert.equal(supplierProgress(normalized).fileChecked, false)
  ready(f); Object.assign(f.status, normalized)
  await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /supplier_file_error/)
  assert.equal(f.calls.includes('supplier-deposit'), false)
  const pending = makeFixture(), pendingWorker = worker(pending)
  ready(pending); pending.status.statusCode = 'PGS_07'; pending.status.statusCodeOrg = 'PGS_07'; pending.status.fileProcessYn = 'N'
  await pendingWorker.claim(owner); await pendingWorker.advance(jobId, owner)
  assert.equal(pending.job.event_type, 'POLL')
  assert.equal(pending.order.print_file_checked_at, undefined)
  assert.equal(pending.order.print_accepted_at, undefined)
  assert.equal(pending.calls.includes('supplier-deposit'), false)
})

test('an internal warning cannot restore revoked sample/spec approval or confirm an N file', async () => {
  for (const fileProcessYn of ['Y', 'N']) {
    const f = makeFixture(), w = worker(f)
    ready(f); f.order.print_fulfillment_status = 'SUBMITTED'; f.job.event_type = 'POLL'; f.approvalCurrent = false
    Object.assign(f.status, { statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileProcessYn, fileError: false, fileErrorSummary: '' })
    await w.claim(owner); await w.advance(jobId, owner)
    assert.equal(f.approvalCurrent, false)
    assert.equal(f.job.event_type, 'POLL')
    assert.equal(f.order.status, 'PAYMENT_COMPLETED')
    assert.equal(f.order.print_accepted_at, undefined)
    assert.equal(Boolean(f.order.print_file_checked_at), fileProcessYn === 'Y')
    assert.equal(f.calls.includes('supplier-deposit'), false)
  }
})

test('fresh canceled or partially canceled payment prevents any supplier POST or deposit', async () => {
  for (const stage of ['SUBMIT','CONFIRM']) {
    const f = makeFixture(), w = worker(f)
    ready(f); f.job.event_type = stage; f.job.payload.queryOnly = false
    f.status.fileProcessYn = 'Y'; f.order.print_file_checked_at = '2026-10-14T00:40:00Z'
    f.paymentLookup = async () => { throw new PortOnePrintPaymentError('payment_reversed') }
    w.options.paymentLookup = f.paymentLookup
    await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /payment_reversed/)
    assert.equal(f.job.state, 'FAILED')
    assert.equal(f.calls.some(call => call?.supplierSubmit || call === 'supplier-deposit'), false)
  }
})

test('uncertain deposit is durably recorded BEFORE POST and never charged again across poll cycles', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.order.print_fulfillment_status = 'SUBMITTED'; f.job.event_type = 'CONFIRM'; f.job.payload.queryOnly = false
  f.status.fileProcessYn = 'Y'; f.order.print_file_checked_at = '2026-10-14T00:40:00Z'
  let deposits = 0
  f.vendor.confirm = async () => {
    assert.equal(f.job.payload.depositAttempted, true)
    deposits++; throw new RedprintingError('vendor_request_uncertain', 502, true)
  }
  await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /vendor_request_uncertain/)
  for (let attempt = 0; attempt < 3; attempt++) { await w.claim(owner); await w.advance(jobId, owner) }
  assert.equal(deposits, 1)
  assert.equal(f.job.event_type, 'POLL'); assert.equal(f.job.payload.depositAttempted, true)
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
})

test('supplier balance requires explicit success and exact nonnegative KRW; missing or private failures never become zero', () => {
  for (const raw of [0, 24730, '24730']) assert.equal(vendorDepositBalance({ success: true, total_balance: raw }), Number(raw))
  for (const value of [null, [], { success: false, total_balance: 24730, message: 'private-account' },
    { success: true }, { success: true, total_balance: -1 }, { success: true, total_balance: 2.5 },
    { success: true, total_balance: true }, { success: true, total_balance: ' 24730' },
    { success: true, total_balance: '2.473e4' }, { success: true, total_balance: Number.MAX_SAFE_INTEGER + 1 }]) {
    assert.throws(() => vendorDepositBalance(value), error => error.code === 'supplier_deposit_unavailable' && !error.message.includes('private'))
  }
})

test('low or unknown supplier balance holds BEFORE durable deposit and resumes the same order after funding', async () => {
  for (const unavailable of [false, true]) {
    const f = makeFixture(), w = worker(f)
    ready(f); f.order.print_fulfillment_status = 'SUBMITTED'; f.job.event_type = 'CONFIRM'; f.job.payload.queryOnly = false
    f.status.fileProcessYn = 'Y'; f.order.print_file_checked_at = '2026-10-14T00:40:00Z'
    const stable = f.job.payload.vendorOrderNum
    f.vendor.depositBalance = async () => { if (unavailable) throw Error('private account text'); return 24729 }
    await w.claim(owner)
    await assert.rejects(w.advance(jobId, owner), unavailable ? /supplier_deposit_unavailable/ : /supplier_deposit_insufficient/)
    assert.equal(f.job.state, 'PENDING'); assert.equal(f.job.payload.queryOnly, false); assert.equal(f.job.payload.depositAttempted, undefined)
    assert.equal(f.calls.some(call => call?.name === 'record_print_fulfillment_attempt'), false)
    assert.equal(f.calls.includes('supplier-deposit'), false)
    f.vendor.depositBalance = async () => 24730
    await w.claim(owner); await w.advance(jobId, owner)
    assert.equal(f.job.payload.vendorOrderNum, stable)
    assert.equal(f.calls.filter(call => call === 'supplier-deposit').length, 1)
    assert.equal(f.order.status, 'IN_PRODUCTION')
  }
})

test('HTTP 200 success false from supplier confirmation is uncertain, never production or another financial POST', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.order.print_fulfillment_status = 'SUBMITTED'; f.job.event_type = 'CONFIRM'; f.job.payload.queryOnly = false
  f.status.fileProcessYn = 'Y'; f.order.print_file_checked_at = '2026-10-14T00:40:00Z'
  let attempts = 0
  f.vendor.confirm = async () => { attempts++; return { success: false, message: 'private supplier text' } }
  await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /supplier_confirmation_unknown/)
  assert.equal(f.job.state, 'UNKNOWN'); assert.equal(f.job.payload.depositAttempted, true)
  assert.equal(f.order.status, 'PAYMENT_COMPLETED')
  for (let cycle = 0; cycle < 3; cycle++) { await w.claim(owner); await w.advance(jobId, owner) }
  assert.equal(attempts, 1); assert.equal(f.order.status, 'PAYMENT_COMPLETED')
})

test('production balance lookup shares rate slots, uses GET without payload and never exposes deposit history', async () => {
  const calls = [], releases = []
  const client = new RedprintingFulfillmentClient({ enabled: true, environment: 'production', productionApproved: true,
    depositEnabled: false, userId: 'fixture-account', apiKey: 'private-fixture' },
    async () => { calls.push('rate-slot'); return async () => releases.push('released') }, async (url, init) => {
      calls.push({ url, init })
      return url.endsWith('/v1/auth/token') ? Response.json({ success: true, token: 'private-fixture-token-long-enough' }) :
        Response.json({ success: true, total_balance: 24730, deposit_list: [{ privateHistory: 'private-history' }] })
    })
  assert.equal(await client.depositBalance(), 24730)
  const request = calls.find(call => call?.url?.endsWith('/v1/code/deposit'))
  assert.equal(request.init.method, 'GET'); assert.equal(request.init.body, undefined); assert.equal(request.init.redirect, 'error')
  assert.equal(releases.length, 2)
})

test('supplier already processing or confirming deposit cannot trigger an additional financial call', async () => {
  for (const statusCodeOrg of ['PGS_11', 'PGS_12']) {
    const f = makeFixture(), w = worker(f)
    ready(f); f.order.print_fulfillment_status = 'SUBMITTED'; f.job.event_type = 'CONFIRM'; f.job.payload.queryOnly = false
    f.status.fileProcessYn = 'Y'; f.status.statusCodeOrg = statusCodeOrg; f.order.print_file_checked_at = '2026-10-14T00:40:00Z'
    for (let cycle = 0; cycle < 2; cycle++) { await w.claim(owner); await w.advance(jobId, owner) }
    assert.equal(f.calls.includes('supplier-deposit'), false)
    assert.equal(f.job.event_type, 'POLL')
  }
})

test('missing or malformed lock timestamps cannot satisfy an active render lease', async () => {
  const f = makeFixture(), w = worker(f)
  const claim = await w.claim(owner)
  for (const value of [null, undefined, '', 'not-a-timestamp']) {
    assert.throws(() => w.checkedClaim({ ...claim, job: { ...claim.job, lease_until: value } }, owner), /invalid_print_worker_claim/)
    assert.throws(() => w.checkedClaim({ ...claim, order: { ...claim.order, print_package_lock_until: value } }, owner), /invalid_print_worker_claim/)
  }
})

test('positive price, frozen shipping/packaging evidence and margin are checked before submitting', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.job.payload.queryOnly = false
  f.vendor.price = async () => ({ totalPrice: 101860 })
  await w.claim(owner); await assert.rejects(w.advance(jobId, owner), /supplier_price_changed/)
  assert.equal(f.calls.some(call => call?.supplierSubmit), false)
  assert.equal(f.job.state, 'FAILED')
})

test('supplier dispatch is SHIPPING only; file Y and production are distinct milestones', () => {
  const f = makeFixture()
  assert.equal(supplierProgress(f.status).fileChecked, false)
  assert.equal(supplierProgress({ ...f.status, fileProcessYn: 'Y' }).customerStage, 'FILE_CHECKED')
  assert.equal(supplierProgress({ ...f.status, statusCode: 'PGS_20' }).productionStarted, true)
  const shipped = supplierProgress({ ...f.status, statusCode: 'PGS_55', courier: '검수택배', trackingNumber: '123456789' })
  assert.equal(shipped.customerStage, 'SHIPPING')
  assert.equal(supplierProgress({ ...f.status, statusCode: 'PGS_55' }).shipped, false)
  assert.equal(nextSupplierPoll(Date.parse('2026-10-16T08:50:00Z')), '2026-10-19T00:00:00.000Z')
})

test('a request or later payment review cannot hide supplier tracking after independently recorded manufacture', async () => {
  const f = makeFixture(), w = worker(f)
  ready(f); f.order.status = 'IN_PRODUCTION'; f.order.print_fulfillment_status = 'ACCEPTED'
  f.order.print_accepted_at = '2026-10-14T00:45:00Z'; f.job.event_type = 'POLL'
  f.order.print_customer_request_hold = true; f.order.print_requires_action = true
  Object.assign(f.status, { statusCode: 'PGS_55', statusCodeOrg: 'PGS_55', fileProcessYn: 'Y', courier: '검수택배', trackingNumber: '123456789' })
  w.options.paymentLookup = async () => { throw new PortOnePrintPaymentError('payment_reversed') }
  await w.claim(owner); await w.advance(jobId, owner)
  assert.equal(f.order.status, 'SHIPPING'); assert.equal(f.order.tracking_number, '123456789')
  assert.equal(f.calls.includes('supplier-deposit'), false); assert.equal(f.calls.includes('latest-live-payment'), false)
  assert.equal(f.order.print_requires_action, true); assert.equal(f.order.print_customer_request_hold, true)
  assert.notEqual(f.order.status, 'DELIVERED')
})

test('verified worker auth occurs before privileged configuration and unknown request fields cannot assert paid data', async () => {
  let dbCalls = 0
  const f = makeFixture()
  const handler = user => createPrintFulfillmentWorkerHandler({ getUser: async () => user,
    createAdminDatabase: () => { dbCalls++; return f.db }, configuration: () => f.config, vendor: () => f.vendor, sender: f.sender })
  const request = body => new Request('https://fixture.invalid/worker', { method: 'POST', headers: { Authorization: 'Bearer fixture' }, body: JSON.stringify(body) })
  for (const user of [null, { id: owner, user_metadata: { role: 'admin' } }, { id: owner, app_metadata: { role: 'customer' } }]) {
    assert.ok([401,403].includes((await handler(user)(request({ action: 'claim', workerId: owner }))).status))
  }
  assert.equal(dbCalls, 0)
  assert.equal((await handler({ id: owner, app_metadata: { role: 'print_worker' } })(request({ action: 'claim', workerId: owner, paid: true }))).status, 400)
  assert.equal(dbCalls, 0)
})

test('admin exact-order overview passes a private filter and is independent of the recent-50 list', async () => {
  const f = makeFixture(), lookups = [], oldOrder = 'ordp_11111111-1111-4111-8111-111111111111'
  const handler = createPrintFulfillmentWorkerHandler({ getUser: async () => ({ id: owner, app_metadata: { role: 'admin' } }),
    createAdminDatabase: () => ({ async rpc(name, args) {
      lookups.push({ name, args })
      return { data: args.p_order_id ? [{ order_id: oldOrder, event_type: 'POLL', state: 'FAILED', last_error_code: 'supplier_file_error' }] : [], error: null }
    } }), configuration: () => f.config, vendor: () => f.vendor, sender: f.sender })
  const request = body => new Request('https://fixture.invalid/worker', { method: 'POST', headers: { Authorization: 'Bearer fixture' }, body: JSON.stringify(body) })
  assert.deepEqual((await (await handler(request({ action: 'overview' }))).json()).jobs, [])
  const result = await (await handler(request({ action: 'overview', orderId: oldOrder }))).json()
  assert.equal(result.jobs[0].order_id, oldOrder)
  assert.deepEqual(lookups[1], { name: 'list_print_fulfillment_jobs', args: { p_limit: 50, p_order_id: oldOrder } })
  assert.doesNotMatch(JSON.stringify(result), /local-stub-no-network|store-fixture|channel-key-fixture/)
  for (const orderId of [null, '', 'other-order', 'ordp_not-uuid', 'x'.repeat(101)]) {
    assert.equal((await handler(request({ action: 'overview', orderId }))).status, 400)
  }
  assert.equal(lookups.length, 2)
})

test('renderer subprocess environment contains no worker, payment, database or provider secrets', () => {
  const child = rendererEnvironment({ PATH: '/bin', HOME: '/tmp', SNAPFIT_PRINT_WORKER_JWT: 'private-jwt', PRINT_PORTONE_V2_API_SECRET: 'private-portone', SUPABASE_SERVICE_ROLE_KEY: 'private-database', PRINT_REDP_PRODUCTION_API_KEY: 'private-supplier' }, '/tmp/input', '/tmp/output')
  assert.doesNotMatch(JSON.stringify(child), /private-|JWT|SECRET|SERVICE_ROLE|API_KEY/)
  assert.equal(child.SNAPFIT_RENDER_OUTPUT, '/tmp/output')
})

test('runner reconciles app-closed paid intents first and never renders while server gate is closed', async () => {
  const calls = []
  const transport = { url: 'https://fixture.supabase.co', async call(endpoint, body) {
    calls.push({ endpoint, body }); return endpoint === 'print-payment-reconcile' ? { enabled: false, checked: 0 } : { enabled: false, claim: null }
  } }
  assert.deepEqual(await workerTick({ transport, workerId: owner, renderer: async () => assert.fail('disabled renderer called') }), {
    enabled: false, processed: 0, requestResolution: { enabled: false, processed: 0, waiting: 0, completed: 0, reviewRequired: 0 },
  })
  assert.equal(calls[0].endpoint, 'print-payment-reconcile')
  assert.equal(calls[1].endpoint, 'print-order-request-resolve')
  assert.deepEqual(calls[1].body, { action: 'tick', limit: 1 })
  assert.equal(calls[2].body.action, 'claim')
})

test('worker upload cannot send credentials to external URL or overwrite a published object', async () => {
  const calls = []
  const transport = new WorkerTransport({ url: 'https://fixture.supabase.co', publishableKey: 'public-fixture', jwt: 'private-fixture',
    fetcher: async (url, init) => { calls.push({ url, init }); return Response.json({}) } })
  await assert.rejects(transport.upload({ signedUrl: 'https://external.invalid/file?token=fixture' }, Buffer.from('fixture')), /print_upload_failed/)
  assert.equal(calls.length, 0)
  await transport.upload({ signedUrl: 'https://fixture.supabase.co/storage/v1/object/upload/sign/print-packages/file.pdf?token=fixture' }, Buffer.from('fixture'))
  assert.equal(calls[0].init.headers['x-upsert'], 'false'); assert.equal(calls[0].init.redirect, 'error')
})

test('disabled production supplier client performs no HTTP request even for read/confirmation attempts', async () => {
  let calls = 0
  const client = new RedprintingFulfillmentClient({ enabled: false, environment: 'disabled', productionApproved: false,
    depositEnabled: false, userId: '', apiKey: '' }, async () => async () => {}, async () => { calls++; assert.fail() })
  await assert.rejects(client.submit({}), /production_vendor_not_configured/)
  await assert.rejects(client.confirm('SFO_fixture'), /production_vendor_not_configured/)
  await assert.rejects(client.status('SFO_fixture', 1), /production_vendor_not_configured/)
  await assert.rejects(client.depositBalance(), /production_vendor_not_configured/)
  assert.equal(calls, 0)
})

test('runner can restart with server-only account credentials and keeps rotated sessions in memory', async () => {
  const calls = []
  const transport = new WorkerTransport({ url: 'https://fixture.supabase.co', publishableKey: 'public-fixture',
    email: 'worker-fixture@example.invalid', password: 'private-worker-fixture', fetcher: async (url, init) => {
      calls.push({ url, init })
      if (url.includes('/auth/')) return Response.json({ access_token: 'rotated-private-session', refresh_token: 'rotated-private-refresh' })
      return Response.json({ enabled: false, claim: null })
    } })
  await transport.call('print-fulfillment-worker', { action: 'claim', workerId: owner })
  assert.match(calls[0].url, /grant_type=password$/)
  assert.equal(calls[1].init.headers.Authorization, 'Bearer rotated-private-session')
  assert.equal(transport.refreshToken, 'rotated-private-refresh')
  assert.equal(calls[1].init.body.includes('private-worker-fixture'), false)
})

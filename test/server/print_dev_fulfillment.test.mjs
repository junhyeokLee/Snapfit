import assert from 'node:assert/strict'
import { test } from 'node:test'
import { runPrintDevFulfillmentTick, PRINT_DEV_ORDER_CODE, PRINT_DEV_PAYMENT_ROUTE } from '../../supabase/functions/_shared/print-dev-fulfillment.ts'
import { testPrintSpec, RedprintingError } from '../../supabase/functions/_shared/redprinting.ts'
import { PRINT_PRODUCTS } from '../../supabase/functions/_shared/print-contract.ts'
import { PortOnePrintPaymentError } from '../../supabase/functions/_shared/portone-print-payment.ts'

const workerId = '11111111-1111-4111-8111-111111111111', checkoutId = '22222222-2222-4222-8222-222222222222',
  packageId = '33333333-3333-4333-8333-333333333333', requestId = '44444444-4444-4444-8444-444444444444',
  jobId = '55555555-5555-4555-8555-555555555555', paymentId = 'SFPGT_66666666-6666-4666-8666-666666666666',
  orderId = 'ordp_77777777-7777-4777-8777-777777777777'
const clone = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value))
function fixture(options = {}) {
  let clock = Date.parse('2026-10-15T03:00:00Z')
  const spec = testPrintSpec('REDP_300_HARD', 80)
  const result = { pageCount: 1, widthMm: 681.2, heightMm: 346, byteLength: 1200, sha256: 'a'.repeat(64) },
    interior = { pageCount: 80, widthMm: 310, heightMm: 310, byteLength: 2200, sha256: 'b'.repeat(64) }
  const pack = { id: packageId, checkout_id: checkoutId, state: 'READY', source_fingerprint: 'c'.repeat(64), file_parts: {},
    cover_path: `${orderId}/${packageId}/cover.pdf`, interior_path: `${orderId}/${packageId}/interior.pdf`, manifest_path: `${orderId}/${packageId}/manifest.json`,
    cover_result: result, interior_result: interior, pdf_manifest: { spec, sourceFingerprint: 'c'.repeat(64), cover: result, interior, vendorReady: false } }
  const checkout = { id: checkoutId, owner_id: workerId, request_id: requestId, order_id: orderId, payment_id: paymentId,
    package_id: packageId, environment: 'test', currency: 'KRW', total_amount: 159900, order_code: PRINT_DEV_ORDER_CODE,
    product: PRINT_PRODUCTS.REDP_300_HARD, spec, status: 'READY', sdk_issued_at: new Date(clock).toISOString(), submitted_at: null,
    recipient: { name: '개발 검수', tel: '01000000001', zipcode: '12345', address: '개발 검수 주소', addressDetail: '개발 검수 상세', message: '' },
    vendor_status: {} }
  const job = { id: jobId, checkout_id: checkoutId, event_type: 'PAYMENT', state: 'PENDING',
    payload: { vendorOrderNum: 'SFD00000000000040008000000000000001', vendorOrderSeq: 1, queryOnly: false } }
  const paymentExpectation = { ...PRINT_DEV_PAYMENT_ROUTE, paymentId, amount: 159900, currency: 'KRW', environment: 'test' }
  const receipt = { ...paymentExpectation, provider: 'PORTONE', version: 'V2', status: 'PAID', paidAmount: 159900, discountAmount: 0,
    paidAt: new Date(clock).toISOString(), isTest: true, transactionId: 'fixture_actual_test_transaction' }
  const calls = [], configuration = { enabled: true, paymentEnvironment: 'test', ...PRINT_DEV_PAYMENT_ROUTE,
    paymentApiSecret: 'fixture-private-portone-key', deliverySecret: 'd'.repeat(64), supabaseUrl: 'https://fixture.supabase.co',
    vendor: { environment: 'development', enabled: true, userId: 'fixture_development', apiKey: 'fixture-private-development-key', expiresAt: '2026-11-11' },
    ...options.config }
  let status = { statusCode: 'PGS_07', statusCodeOrg: 'PGS_07', fileProcessYn: 'N', fileError: false, fileErrorSummary: '', fileErrorDetailPresent: false }
  const envelope = () => clone({ job, checkout, package: pack, paymentExpectation })
  const db = { async rpc(name, args) {
    calls.push({ rpc: name, args: clone(args) })
    if (name === 'claim_print_dev_fulfillment_job') {
      if (['DONE', 'FAILED', 'CLAIMED'].includes(job.state)) return { data: null, error: null }
      job.state = 'CLAIMED'; job.lease_owner = args.p_worker_id; job.lease_until = new Date(clock + 120000).toISOString()
      const claimed = envelope(); options.mutateClaim?.(claimed)
      return { data: claimed, error: null }
    }
    if (name === 'read_print_dev_file_delivery') {
      assert.equal(args.p_order_id, orderId); assert.equal(args.p_package_id, packageId)
      return { data: { orderId, packageId, kind: args.p_kind, result: pack[`${args.p_kind}_result`], parts: [] }, error: null }
    }
    if (args.p_id !== job.id || args.p_owner !== job.lease_owner || job.state !== 'CLAIMED' || Date.parse(job.lease_until) <= clock) {
      return { data: null, error: { message: 'fixture lease unavailable' } }
    }
    if (name === 'get_print_dev_fulfillment_job') return { data: envelope(), error: null }
    if (name === 'commit_print_dev_payment') { assert.equal(args.p_receipt.isTest, true); checkout.status = 'PAYMENT_VERIFIED'; return { data: clone(checkout), error: null } }
    if (name === 'record_print_dev_submission_attempt') {
      job.payload.queryOnly = true; checkout.status = 'SUBMITTING'; checkout.submitted_at = new Date(clock).toISOString()
      return { data: clone(job), error: null }
    }
    if (name === 'finish_print_dev_fulfillment_job') {
      const result = args.p_result
      checkout.status = result.status; checkout.vendor_status = clone(result.vendorStatus ?? checkout.vendor_status)
      checkout.error_code = result.errorCode ?? null
      job.state = result.nextStage === 'DONE' ? 'DONE' : 'PENDING'
      if (result.nextStage !== 'DONE') job.event_type = result.nextStage
      job.lease_owner = job.lease_until = null
      return { data: clone(job), error: null }
    }
    if (name === 'fail_print_dev_fulfillment_job') {
      checkout.error_code = args.p_error_code
      job.state = args.p_terminal ? 'FAILED' : job.payload.queryOnly ? 'UNKNOWN' : 'PENDING'
      if (args.p_terminal) checkout.status = 'FAILED'
      else if (job.payload.queryOnly) checkout.status = 'UNKNOWN'
      job.lease_owner = job.lease_until = null
      return { data: clone(job), error: null }
    }
    throw new Error('Unexpected development RPC')
  } }
  const vendor = {
    async call(path, body) {
      calls.push({ vendor: path, body: clone(body) })
      if (path === '/v1/code/detail') return { success: true, data: { order_code: PRINT_DEV_ORDER_CODE, use_yn: options.useYn ?? 'Y' } }
      if (path === '/v1/code/price') return { success: true, orderYn: 'Y', priceInfo: { qty: 1, supplyPrice: 92600, vatPrice: 9260, totalPrice: options.price ?? 101860 } }
      if (path === '/v1/code/order') { if (options.submitError) throw options.submitError; return options.submitResponse ?? { success: true, message: '' } }
      throw new Error('No confirmation/deposit or production calls are supported')
    },
    async status(number, sequence) {
      calls.push({ vendorStatus: number, sequence })
      if (options.statusError) throw options.statusError
      return clone(status)
    },
  }
  const deps = { vendor, randomUUID: () => workerId, now: () => clock,
    async sender() { calls.push('sender'); return { senderName: '스냅핏', senderTel: '01000000002', senderZipcode: '12345', senderAddress: '검수 발송지', senderAddressDetail: '검수 상세',
      colorMode: 'UNCONFIRMED', colorApprovalNote: '', colorApprovedAt: null, developmentRgbTestAcknowledged: true, developmentGeometryTestAcknowledged: true, testDepositEnabled: false } },
    async paymentLookup(expected) { calls.push({ payment: clone(expected) }); if (options.paymentError) throw options.paymentError; return { ...receipt, ...options.receipt } },
  }
  return { calls, db, deps, configuration, job, checkout, pack, tick: () => runPrintDevFulfillmentTick(db, configuration, deps),
    setStatus(value) { status = { ...status, ...value } }, advance(ms) { clock += ms } }
}

test('disabled TEST flag does no RPC, payment or supplier work; LIVE/mismatched channels and vendor production environment fail closed', async () => {
  const disabled = fixture({ config: { enabled: false } }); assert.deepEqual(await disabled.tick(), { enabled: false, checked: 0, advanced: 0, errors: 0, stage: null })
  assert.equal(disabled.calls.length, 0)
  for (const config of [{ paymentEnvironment: 'live' }, { storeId: 'store-other' }, { channelKey: 'channel-key-other' },
    { paymentApiSecret: '' }, { deliverySecret: '' }, { vendor: { environment: 'production' } }]) {
    const f = fixture({ config }); await assert.rejects(f.tick()); assert.equal(f.calls.length, 0)
  }
})
test('after app closure, separate leased TEST payment, DEV submission and file poll complete without a production/deposit call', async () => {
  const f = fixture()
  assert.deepEqual(await f.tick(), { enabled: true, checked: 1, advanced: 1, errors: 0, stage: 'PAYMENT' })
  assert.equal(f.job.event_type, 'SUBMIT'); assert.equal(f.checkout.status, 'PAYMENT_VERIFIED')
  assert.equal(f.calls.some(call => call.vendor), false)
  assert.equal((await f.tick()).advanced, 1); assert.equal(f.checkout.status, 'ACCEPTED'); assert.equal(f.job.event_type, 'POLL')
  const posts = f.calls.filter(call => call.vendor === '/v1/code/order')
  assert.equal(posts.length, 1)
  const payload = posts[0].body.order_data[0]
  assert.equal(payload.order_code, PRINT_DEV_ORDER_CODE); assert.equal(payload.qty, 1); assert.equal(payload.send_name, '스냅핏')
  assert.match(payload.file_url1, /print-dev-file-delivery\/cover\.pdf/); assert.match(payload.file_url2, /print-dev-file-delivery\/interior\.pdf/)
  const attemptAt = f.calls.findIndex(call => call.rpc === 'record_print_dev_submission_attempt')
  assert.ok(attemptAt >= 0 && attemptAt < f.calls.findIndex(call => call.vendor === '/v1/code/order'))
  f.setStatus({ statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileProcessYn: 'Y' })
  assert.equal((await f.tick()).advanced, 1); assert.equal(f.checkout.status, 'FILE_CHECKED'); assert.equal(f.job.state, 'DONE')
  assert.equal((await f.tick()).checked, 0)
  assert.equal(f.calls.filter(call => call.vendor === '/v1/code/order').length, 1)
  assert.equal(f.calls.some(call => call.vendor?.includes('deposit') || /production|commit_production|print_app_pdf/.test(call.rpc ?? '')), false)
})
test('LIVE, wrong identity/channel/amount and reversed TEST observations can never authorize receipt commit or DEV order', async () => {
  for (const receipt of [{ environment: 'live', isTest: false }, { paymentId: 'SFP_other' }, { channelKey: 'channel-key-other' },
    { storeId: 'store-other' }, { amount: 1 }, { provider: 'OTHER' }, { version: 'V1' }]) {
    const f = fixture({ receipt }); const result = await f.tick(); assert.equal(result.errors, 1)
    assert.equal(f.calls.some(call => call.rpc === 'commit_print_dev_payment' || call.vendor), false)
  }
  const reversed = fixture({ paymentError: new PortOnePrintPaymentError('payment_reversed') }); await reversed.tick()
  assert.equal(reversed.job.state, 'FAILED'); assert.equal(reversed.calls.some(call => call.vendor), false)
})
test('Cron may observe an unfinished TEST checkout before approval without terminal failure or a vendor call', async () => {
  for (const paymentError of [new PortOnePrintPaymentError('payment_not_paid'),
    new PortOnePrintPaymentError('payment_not_found', 404, true),
    new PortOnePrintPaymentError('payment_provider_unavailable', 503, true)]) {
    const f = fixture({ paymentError })
    for (let attempt = 0; attempt < 2; attempt++) {
      const observed = await f.tick()
      assert.equal(observed.errors, 1); assert.equal(observed.advanced, 0)
      assert.equal(f.job.state, 'PENDING'); assert.equal(f.job.event_type, 'PAYMENT')
      assert.equal(f.checkout.status, 'READY'); assert.equal(f.checkout.submitted_at, null)
      assert.equal(f.calls.some(call => call.rpc === 'commit_print_dev_payment' || call.vendor), false)
      f.advance(120000)
    }
  }
})
test('lost submit response and repeated status 404 retain stable identity and perform GET-only recovery', async () => {
  const f = fixture({ submitError: new RedprintingError('vendor_request_uncertain', 502, true),
    statusError: new RedprintingError('vendor_http_404', 404, false, 404) })
  await f.tick(); await f.tick()
  assert.equal(f.job.state, 'UNKNOWN'); assert.equal(f.job.payload.queryOnly, true); assert.ok(f.checkout.submitted_at)
  await f.tick(); await f.tick()
  assert.equal(f.calls.filter(call => call.vendor === '/v1/code/order').length, 1)
  assert.equal(f.calls.filter(call => call.vendorStatus).length, 2)
  assert.equal(f.checkout.status, 'UNKNOWN')
})
test('HTTP200 summary acknowledgement plus status404 is not acceptance and cannot issue another submit', async () => {
  const f = fixture({ statusError: new RedprintingError('vendor_http_404', 404, false, 404) })
  await f.tick(); await f.tick(); await f.tick()
  assert.equal(f.checkout.status, 'UNKNOWN'); assert.equal(f.calls.filter(call => call.vendor === '/v1/code/order').length, 1)
})
test('malformed leases, borrowed refs, changed PDF/spec and missing SDK issuance never touch providers', async () => {
  for (const mutateClaim of [claim => { claim.job.lease_until = '2000-01-01' }, claim => { claim.job.lease_owner = checkoutId },
    claim => { claim.checkout.package_id = checkoutId }, claim => { claim.paymentExpectation.environment = 'live' },
    claim => { claim.checkout.sdk_issued_at = null }, claim => { claim.package.pdf_manifest.sourceFingerprint = 'd'.repeat(64) },
    claim => { claim.package.pdf_manifest.cover.sha256 = 'e'.repeat(64) }, claim => { claim.checkout.spec.pageCount = 20 },
    claim => { claim.package.interior_path = 'somebody-else/interior.pdf' }]) {
    const f = fixture({ mutateClaim }); assert.equal((await f.tick()).errors, 1)
    assert.equal(f.calls.some(call => call.vendor || call.payment), false)
  }
})
test('unapproved or zero-priced code stops before the durable submission marker and external order POST', async () => {
  for (const options of [{ useYn: 'N' }, { price: 0 }]) {
    const f = fixture(options); await f.tick(); assert.equal((await f.tick()).errors, 1)
    assert.equal(f.calls.some(call => call.rpc === 'record_print_dev_submission_attempt' || call.vendor === '/v1/code/order'), false)
  }
})
test('org06/explicit file errors stay visible for review; canceled vendor order is terminal, never a test deposit', async () => {
  for (const value of [{ statusCode: 'PGS_06', statusCodeOrg: 'PGS_06', fileProcessYn: 'Y' },
    { statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileProcessYn: 'Y', fileErrorDetailPresent: true }]) {
    const f = fixture(); await f.tick(); f.setStatus(value); await f.tick()
    assert.equal(f.checkout.status, 'ACCEPTED'); assert.equal(f.checkout.error_code, 'vendor_file_processing_error'); assert.equal(f.job.event_type, 'POLL')
  }
  const canceled = fixture(); await canceled.tick(); canceled.setStatus({ statusCode: 'PGS_01', statusCodeOrg: 'PGS_01' }); await canceled.tick()
  assert.equal(canceled.job.state, 'FAILED'); assert.equal(canceled.checkout.error_code, 'vendor_order_canceled')
})

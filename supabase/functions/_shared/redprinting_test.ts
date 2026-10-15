import assert from 'node:assert/strict'
import { RedprintingClient, RedprintingError, assertDevelopment, assertReadySettings, orderAcceptance, orderStatus, redprintingMatrix,
  testPrintSpec, validateTestSpec, validateSettings, vendorCodeList, vendorPrice, vendorDevelopmentQuote, submissionDiagnostic, safeSubmissionDiagnostic, hasVendorFileError, hasVendorFileWarning, type RedprintingEnvironment,
} from './redprinting.ts'
import { RedprintingAdmin, testJson } from './redprinting-admin.ts'
import { validateHardCoverGeometry } from './print-contract.ts'

const config: RedprintingEnvironment = { environment: 'development', enabled: true, userId: 'local-fixture-account', apiKey: 'local-only-api-key', expiresAt: '2099-11-07' }
const id = '11111111-1111-4111-8111-111111111111', uploadId = '22222222-2222-4222-8222-222222222222'
const receiver = { name: '테스트', tel: '01000000000', zipcode: '12345', address: '테스트 주소', addressDetail: '개발 테스트', message: '' }
const settings = { id: 1, sender_name: '스냅핏', sender_tel: '01000000000', sender_zipcode: '00000', sender_address: '테스트 주소', sender_address_detail: '반송 테스트',
  color_mode: 'UNCONFIRMED', color_approval_note: '', color_approved_at: null, test_deposit_enabled: false,
  development_rgb_test_acknowledged: true, development_geometry_test_acknowledged: true }
const mapping = { product_id: 'REDP_200_SOFT', page_count: 20, order_code: 'fixture-code', exact_match_confirmed: true, vendor_use_yn: 'Y', vendor_order_yn: 'Y', verified_at: '2026-10-08',
  price_snapshot: { supplyPrice: 10000, vatPrice: 1000, totalPrice: 11000, orderYn: 'Y' } }
const initialTest = () => ({ id, request_id: '33333333-3333-4333-8333-333333333333', environment: 'development', product_id: 'REDP_200_SOFT', page_count: 20,
  order_num: 'SFDfixture1', order_seq: 1, order_code: null, label: 'mock', recipient: receiver, status: 'FILES_READY', upload_id: uploadId,
  cover_path: `${id}/${uploadId}/cover.pdf`, interior_path: `${id}/${uploadId}/interior.pdf`, pdf_manifest: { validatedAt: '2026-10-08' }, vendor_status: {}, created_at: '2026-10-08' })
class Query {
  filters: ((row: any) => boolean)[] = []
  op = 'select'; value: any; one = false; size = 1000
  constructor(private rows: any[]) {}
  select(..._args: any[]) { return this }
  order(..._args: any[]) { return this }
  limit(size: number) { this.size = size; return this }
  range(..._args: any[]) { return this }
  eq(key: string, value: any) { this.filters.push(row => row[key] === value); return this }
  not(key: string, _op: string, _value: any) { this.filters.push(row => row[key] != null); return this }
  single() { this.one = true; return this }
  maybeSingle() { this.one = true; return this }
  update(value: any) { this.op = 'update'; this.value = value; return this }
  insert(value: any) { this.op = 'insert'; this.value = value; return this }
  upsert(value: any) { this.op = 'upsert'; this.value = value; return this }
  then(onfulfilled: any, onrejected: any) {
    let found = this.rows.filter(row => this.filters.every(filter => filter(row)))
    if (this.op === 'insert') {
      if (this.rows.some(row => row.request_id === this.value.request_id)) return Promise.resolve({ data: null, error: { code: '23505' } }).then(onfulfilled, onrejected)
      const row = { environment: 'development', status: 'DRAFT', created_at: '2026-10-08', vendor_status: {}, ...this.value }
      this.rows.push(row); found = [row]
    } else if (this.op === 'upsert') {
      const row = this.rows.find(row => row.order_code === this.value.order_code)
      if (row) Object.assign(row, this.value); else this.rows.push(this.value)
      found = [row ?? this.value]
    } else if (this.op === 'update') found.forEach(row => Object.assign(row, this.value))
    const data = found.slice(0, this.size)
    return Promise.resolve({ data: this.one ? data[0] ?? null : data, count: data.length, error: null }).then(onfulfilled, onrejected)
  }
}
class Database {
  tables: Record<string, any[]> = { redprinting_dev_settings: [structuredClone(settings)], redprinting_dev_mappings: [structuredClone(mapping)], redprinting_dev_codes: [], redprinting_dev_tests: [initialTest()] }
  locks = new Set<string>(); signed: string[] = []
  from(table: string) { if (!this.tables[table]) throw new Error('unexpected_customer_table_access'); return new Query(this.tables[table]) }
  async rpc(name: string, args: any) {
    if (name === 'redprinting_dev_acquire_test') { if (this.locks.has(args.p_id)) return { data: false }; this.locks.add(args.p_id); return { data: true } }
    if (name === 'redprinting_dev_release_test') { this.locks.delete(args.p_id); return { data: null } }
    if (name === 'redprinting_dev_acquire_slot') return { data: 0 }
    return { data: null }
  }
  storage = { getBucket: async (_bucket: string) => ({ data: { public: false }, error: null }), from: (_bucket: string) => ({
    createSignedUrl: async (path: string) => { this.signed.push(path); return { data: { signedUrl: `https://storage-fixture.test/${path}?fixture=1` }, error: null } },
    createSignedUploadUrl: async (path: string) => ({ data: { signedUrl: `https://storage-fixture.test/${path}`, token: 'local-upload-fixture' } }),
  }) }
}
const detailResponse = { success: true, data: [{ order_code: 'fixture-code', goods_desc: '20x20cm 소프트커버 20쪽', product_name: '포토북', work_size: '210x210', cut_size: '200x200', use_yn: 'Y' }] }
const priceResponse = { success: true, orderYn: 'Y', priceInfo: { supplyPrice: 10000, vatPrice: 1000, totalPrice: 11000 } }
const unpricedDevelopmentResponse = { success: true, orderYn: 'Y', priceInfo: { qty: 1, totalPrice: 0 }, productsInfo: '개발 테스트 사양' }
function fixture(db = new Database(), overrides: { call?: (path: string, body: any) => Promise<any>; status?: () => Promise<any>; config?: RedprintingEnvironment } = {}) {
  const calls: { path: string; body: any }[] = []
  const vendor = { async call(path: string, body: any) { calls.push({ path, body }); if (overrides.call) return overrides.call(path, body)
    if (path.endsWith('/detail')) return detailResponse
    if (path.endsWith('/price')) return priceResponse
    if (path.endsWith('/order')) return { success: true, data: [{ success: true, order_num: 'SFDfixture1', order_seq: 1, result_id: 'result-fixture' }] }
    return { success: true }
  }, async status() { calls.push({ path: 'status', body: {} }); return overrides.status ? overrides.status() : { statusCode: '10', statusName: '접수', fileProcessYn: 'Y' } } }
  return { db, calls, run: new RedprintingAdmin(db, overrides.config ?? config, null, { vendor: vendor as unknown as RedprintingClient }) }
}

Deno.test('release readiness cannot enable customer orders from a verified development code, quote, or request flags', async () => {
  const f = fixture(), before = structuredClone(f.db.tables)
  const overview = await f.run.action('overview', { ready: true, canAcceptCustomerOrders: true, productionApproved: true }) as any
  const readiness = overview.releaseReadiness
  assert.equal(readiness.ready, false); assert.equal(readiness.canAcceptCustomerOrders, false)
  assert.equal(readiness.developmentReadySpecCount, 1); assert.equal(readiness.financialQuotesConfirmedCount, 1)
  assert.equal(readiness.totalSpecCount, 310); assert.equal(readiness.uncertainSubmissionCount, 0)
  const item = (id: string) => readiness.items.find((item: any) => item.id === id)
  assert.equal(item('approved_specs').status, 'ready'); assert.equal(item('supplier_cost').status, 'ready')
  for (const id of ['customer_payment', 'production_api', 'automatic_pdf', 'customer_fulfillment', 'automatic_tracking']) assert.equal(item(id).status, 'missing')
  for (const id of ['business_contract', 'physical_sample', 'development_receipt']) assert.equal(item(id).status, 'unconfirmed')
  assert.equal(overview.productionEnabled, false); assert.equal(overview.pollGuidance.automatic, false)
  assert.deepEqual(f.db.tables, before); assert.equal(f.calls.length, 0); assert.equal(f.db.signed.length, 0)
  assert.equal(JSON.stringify(readiness).includes(config.apiKey), false)
})

Deno.test('release readiness counts unpriced approvals separately and unresolved submissions beyond displayed history', async () => {
  const f = fixture(undefined, { call: async path => path.endsWith('/detail') ? detailResponse : unpricedDevelopmentResponse })
  f.db.tables.redprinting_dev_mappings[0].price_snapshot = { environment: 'development', developmentOnly: true, financialQuoteConfirmed: false,
    developmentQuote: { environment: 'development', developmentOnly: true, responseSuccess: true, orderYn: 'Y', qty: 1, quantityConfirmed: true,
      developmentPriceTotal: 0, financialQuoteConfirmed: false, observedAt: '2026-10-12T00:00:00.000Z' } }
  f.db.tables.redprinting_dev_mappings.push({ ...structuredClone(mapping), product_id: 'REDP_300_HARD', page_count: 80, order_code: 'another-fixture-code' },
    { ...structuredClone(mapping), page_count: 22, exact_match_confirmed: false })
  f.db.tables.redprinting_dev_tests = Array.from({ length: 60 }, (_, index) => ({ ...initialTest(), id: `fixture-${index}`, status: 'FILES_READY' }))
  f.db.tables.redprinting_dev_tests.push({ ...initialTest(), id: 'older-unknown', status: 'UNKNOWN', error_code: 'vendor_pre_registration_confirmation_required' },
    { ...initialTest(), id: 'older-submitting', status: 'SUBMITTING' })
  const callsBefore = f.calls.length, before = structuredClone(f.db.tables)
  const overview = await f.run.action('overview', {}) as any, readiness = overview.releaseReadiness
  assert.equal(overview.tests.length, 50)
  assert.equal(readiness.developmentReadySpecCount, 1); assert.equal(readiness.financialQuotesConfirmedCount, 1)
  assert.equal(readiness.uncertainSubmissionCount, 2); assert.equal(readiness.preRegistrationHoldCount, 1)
  assert.equal(readiness.items.find((item: any) => item.id === 'supplier_cost').status, 'ready')
  assert.equal(readiness.items.find((item: any) => item.id === 'development_receipt').status, 'unconfirmed')
  assert.equal(readiness.ready, false); assert.equal(readiness.canAcceptCustomerOrders, false)
  assert.equal(overview.mappings[0].price, null); assert.equal(overview.mappings[0].financialQuoteConfirmed, false)
  assert.equal(overview.mappings[0].verified, false); assert.equal(overview.mappings[0].developmentOrderReady, false)
  assert.deepEqual(f.db.tables, before); assert.equal(f.calls.length, callsBefore)
})

Deno.test('all 310 exact specifications provide stable geometry; real out of bounds stays rejected', () => {
  const matrix = redprintingMatrix()
  assert.equal(matrix.length, 310); assert.equal(new Set(matrix.map(row => `${row.productId}:${row.pageCount}`)).size, 310)
  for (const row of matrix) {
    const spec = testPrintSpec(row.productId, row.pageCount)
    assert.equal(spec.pageCount, row.pageCount); assert.equal(spec.interior.trimWidthMm, row.widthMm); assert.equal(spec.verified, false)
    if (row.coverType === 'HARD') assert.ok(spec.cover.widthMm > 2 * row.widthMm)
  }
  const hard = structuredClone(testPrintSpec('REDP_200X150_HARD', 36).cover) as any
  hard.front.widthMm += .01
  assert.throws(() => validateHardCoverGeometry(hard), /invalid_hardcover_geometry/)
  for (const pages of [19,21,81,NaN,20.5]) assert.throws(() => validateTestSpec('REDP_200_SOFT', pages), /invalid_test_spec/)
  assert.throws(() => validateTestSpec('unknown', 20), /invalid_test_spec/)
})
Deno.test('live, disabled, expired, and missing keys cannot execute vendor calls', async () => {
  for (const cfg of [{ ...config, environment: 'production' }, { ...config, enabled: false }, { ...config, expiresAt: '2020-01-01' }, { ...config, apiKey: '' }]) {
    assert.throws(() => assertDevelopment(cfg), RedprintingError)
    const f = fixture(undefined, { config: cfg })
    await assert.rejects(() => f.run.action('submitTest', { id }), RedprintingError)
    assert.equal(f.calls.length, 0)
  }
})
Deno.test('development acknowledgments never fabricate vendor color approval; sender and CMYK guards hold', () => {
  const parsed = validateSettings({ senderName: '스냅핏', senderTel: '01000000000', senderZipcode: '00000', senderAddress: '주소', senderAddressDetail: '상세',
    colorMode: 'UNCONFIRMED', developmentRgbTestAcknowledged: true, developmentGeometryTestAcknowledged: true })
  assert.equal(parsed.colorApprovedAt, null); assert.equal(parsed.colorApprovalNote, ''); assertReadySettings(parsed)
  assert.throws(() => assertReadySettings({ ...parsed, developmentRgbTestAcknowledged: false }), /development_rgb/)
  assert.throws(() => assertReadySettings({ ...parsed, senderAddressDetail: '' }), /sender_details/)
  assert.throws(() => assertReadySettings({ ...parsed, colorMode: 'CMYK' }), /cmyk_renderer/)
  assert.throws(() => validateSettings({ senderName: 'SnapFit' }), /sender_brand/)
  assert.throws(() => validateSettings({ colorMode: 'RGB', colorApprovalNote: '' }), /vendor_color_approval/)
})
Deno.test('API auth uses Bearer API key then Authorization Token JWT; fixed origin and spacing lease apply', async () => {
  const calls: { url: string; options: RequestInit }[] = [], phases: string[] = []
  const localToken = 'local-fixture-jwt-token-for-auth-tests'
  const client = new RedprintingClient(config, { acquire: async () => { phases.push('acquire'); return async () => { phases.push('release') } },
    fetch: (async (url: string | URL | Request, options: RequestInit) => {
      calls.push({ url: String(url), options })
      return Response.json(String(url).endsWith('/auth/token') ? { success: true, token: localToken } : { success: true, data: [] })
    }) as typeof fetch,
  })
  await client.call('/v1/code/list', {})
  assert.equal(calls[0].url, 'https://redapi.redprinting.net/v1/auth/token')
  assert.equal((calls[0].options.headers as any)['x-api-key'], 'Bearer local-only-api-key')
  assert.deepEqual(JSON.parse(String(calls[0].options.body)), { id: config.userId, expired: '1h' })
  assert.equal((calls[1].options.headers as any).Authorization, `Token ${localToken}`)
  assert.equal((calls[1].options.headers as any).futureAuthorization, undefined)
  assert.deepEqual(phases, ['acquire','release','acquire','release'])
  await assert.rejects(() => client.call('/v1/code/evil'), /invalid_vendor_api_path/)
})
Deno.test('vendor errors cannot leak key, recipient, or PDF URL text', async () => {
  const client = new RedprintingClient(config, { acquire: async () => async () => {}, fetch: (async () => new Response('secret / recipient / signed-url', { status: 400 })) as typeof fetch })
  await assert.rejects(() => client.call('/v1/code/list', {}), error => error instanceof RedprintingError && error.message === 'vendor_http_400')
})
Deno.test('supplier submission diagnostics persist only a fixed safe shape and survive status refresh', async () => {
  const sensitive = 'fixture-private-marker-no-output'
  const response = { success: false, message: `${sensitive} https://private.test/file.pdf?token=${sensitive}`, [sensitive]: sensitive,
    data: [{ order_num: `wrong-${sensitive}`, order_seq: 1, success: false, message: sensitive, recipient: sensitive, token: sensitive }],
    order_data: { secret: sensitive }, result: null,
    results: [{ order_num: 'SFDfixture1', order_seq: 1, success: false, file_url1: sensitive }] }
  const expected = submissionDiagnostic(response, 'SFDfixture1', 1)
  assert.equal(expected.topSuccess, false); assert.equal(expected.messagePresent, true)
  assert.deepEqual(expected.fields.data, { present: true, type: 'array', rowCount: 1, matchingRowCount: 0 })
  assert.deepEqual(expected.fields.orderData, { present: true, type: 'object', rowCount: 0, matchingRowCount: 0 })
  assert.equal(expected.fields.result.type, 'null'); assert.equal(expected.fields.results.matchingRowCount, 1)
  const f = fixture(undefined, { call: async path => path.endsWith('/detail') ? detailResponse : path.endsWith('/price') ? priceResponse : response,
    status: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  const result = await f.run.action('submitTest', { id }) as any
  assert.equal(result.status, 'UNKNOWN'); assert.equal(result.errorCode, 'vendor_order_response_uncertain')
  assert.deepEqual(result.submissionDiagnostic, expected)
  assert.deepEqual(f.db.tables.redprinting_dev_tests[0].vendor_status.submissionDiagnostic, expected)
  assert.equal(JSON.stringify(result).includes(sensitive), false)
  assert.equal(JSON.stringify(f.db.tables.redprinting_dev_tests[0]).includes(sensitive), false)
  await assert.rejects(() => f.run.action('refreshTest', { id }), /vendor_pre_registration_confirmation_required/)
  const missing = await f.run.action('getTest', { id }) as any
  assert.equal(missing.errorCode, 'vendor_pre_registration_confirmation_required'); assert.deepEqual(missing.submissionDiagnostic, expected)
  const found = fixture(f.db)
  const refreshed = await found.run.action('refreshTest', { id }) as any
  assert.equal(refreshed.status, 'ACCEPTED'); assert.deepEqual(refreshed.submissionDiagnostic, expected)
  assert.deepEqual(refreshed.vendorStatus.submissionDiagnostic, expected)
  const polluted = { ...expected, message: sensitive, [sensitive]: sensitive,
    fields: { ...expected.fields, data: { ...expected.fields.data, message: sensitive, token: sensitive }, [sensitive]: sensitive } }
  assert.equal(JSON.stringify(safeSubmissionDiagnostic(polluted)).includes(sensitive), false)
  assert.equal(JSON.stringify(testJson({ ...initialTest(), vendor_status: { submissionDiagnostic: polluted } })).includes(sensitive), false)
  assert.equal(safeSubmissionDiagnostic({ ...expected, fields: { ...expected.fields, data: { ...expected.fields.data, type: sensitive } } }), null)
  assert.equal(submissionDiagnostic({ success: sensitive, message: sensitive, data: sensitive }, 'SFDfixture1', 1).topSuccess, null)
})
Deno.test('test recipient editing changes only an unsubmitted recipient; a status 404 after an attempt does not authorize editing', async () => {
  const next = { ...receiver, name: '다른 개발 수령인', zipcode: '23456', addressDetail: '변경한 개발 주소' }
  const invariantKeys = ['id', 'request_id', 'environment', 'product_id', 'page_count', 'order_num', 'order_seq', 'order_code',
    'label', 'status', 'upload_id', 'cover_path', 'interior_path', 'pdf_manifest', 'source_fingerprint', 'submitted_at']
  for (const status of ['DRAFT', 'FILES_READY']) {
    const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]; row.status = status
    const before = structuredClone(row)
    const result = await f.run.action('updateTestRecipient', { id, recipient: next, orderNum: 'new-forbidden-order', status: 'ACCEPTED' }) as any
    assert.deepEqual(result.recipient, next); assert.equal(f.calls.length, 0)
    for (const key of invariantKeys) assert.deepEqual(row[key], before[key])
  }
  const f = fixture(undefined, { status: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  const row = f.db.tables.redprinting_dev_tests[0]
  Object.assign(row, { status: 'UNKNOWN', submitted_at: '2026-10-12T00:00:00Z', order_code: 'fixture-code', source_fingerprint: 'immutable-fixture-fingerprint' })
  const before = structuredClone(row)
  await assert.rejects(() => f.run.action('updateTestRecipient', { id, recipient: next }), /vendor_pre_registration_confirmation_required/)
  assert.deepEqual(row.recipient, receiver); assert.equal(row.error_code, 'vendor_pre_registration_confirmation_required')
  assert.deepEqual(f.calls.map(call => call.path), ['status'])
  for (const key of invariantKeys) assert.deepEqual(row[key], before[key])
  const uncertain = fixture(f.db, { status: async () => { throw new RedprintingError('vendor_request_uncertain', 502, true) } })
  await assert.rejects(() => uncertain.run.action('updateTestRecipient', { id, recipient: receiver }), /uncertain/)
  assert.deepEqual(row.recipient, receiver)
  const alreadyExists = fixture(f.db)
  await assert.rejects(() => alreadyExists.run.action('updateTestRecipient', { id, recipient: receiver }), /test_recipient_edit_not_allowed/)
  assert.deepEqual(row.recipient, receiver); assert.equal(row.order_num, before.order_num)
  for (const error of [new RedprintingError('vendor_http_500', 502, true, 500), new RedprintingError('vendor_order_status_unknown', 502, true),
    new RedprintingError('vendor_http_404', 404, false, 0)]) {
    const blocked = fixture(f.db, { status: async () => { throw error } })
    await assert.rejects(() => blocked.run.action('updateTestRecipient', { id, recipient: receiver }), RedprintingError)
    assert.deepEqual(row.recipient, receiver)
  }
  const rejected = fixture(undefined, { status: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  rejected.db.tables.redprinting_dev_tests[0].status = 'REJECTED'
  await assert.rejects(() => rejected.run.action('updateTestRecipient', { id, recipient: next }), /vendor_pre_registration_confirmation_required/)
  assert.deepEqual(rejected.calls.map(call => call.path), ['status'])
  assert.equal(rejected.db.tables.redprinting_dev_tests[0].status, 'REJECTED')
  assert.deepEqual(rejected.db.tables.redprinting_dev_tests[0].recipient, receiver)
})
Deno.test('recipient edits cannot change accepted, canceled, confirmed, busy, or production orders', async () => {
  for (const patch of [{ status: 'ACCEPTED' }, { status: 'CONFIRMED' }, { status: 'CANCELED' }, { status: 'SUBMITTING' },
    { confirmed_at: '2026-10-12' }, { canceled_at: '2026-10-12' }]) {
    const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]; Object.assign(row, patch)
    await assert.rejects(() => f.run.action('updateTestRecipient', { id, recipient: { ...receiver, name: '변경 요청' } }), /edit_not_allowed/)
    assert.deepEqual(row.recipient, receiver); assert.equal(f.calls.length, 0)
  }
  const busy = fixture(); busy.db.locks.add(id)
  await assert.rejects(() => busy.run.action('updateTestRecipient', { id, recipient: receiver }), /operation_in_progress/)
  const live = fixture(undefined, { config: { ...config, environment: 'production' } })
  await assert.rejects(() => live.run.action('updateTestRecipient', { id, recipient: receiver }), /live_environment/)
  assert.equal(live.calls.length, 0)
})
Deno.test('PDF-only recipient placeholder remains valid for file preparation but never reaches the supplier', async () => {
  const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]
  row.recipient = { ...receiver, zipcode: '00000' }
  const created = await f.run.action('createTest', { requestId: row.request_id, productId: row.product_id, pageCount: row.page_count, recipient: row.recipient }) as any
  assert.equal(created.id, id)
  await f.run.action('getTestSnapshot', { id })
  await assert.rejects(() => f.run.action('submitTest', { id }), /test_vendor_recipient_required/)
  assert.equal(row.status, 'FILES_READY'); assert.equal(row.submitted_at, undefined)
  assert.equal(f.calls.length, 0); assert.equal(f.db.signed.length, 0)
  await f.run.action('updateTestRecipient', { id, recipient: receiver })
  const result = await f.run.action('submitTest', { id }) as any
  assert.equal(result.status, 'ACCEPTED'); assert.equal(result.id, created.id); assert.equal(result.orderNum, created.orderNum)
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
})
Deno.test('item acceptance ignores top-level partial failure and rejects absent/mismatched identities', () => {
  assert.equal(orderAcceptance({ success: false, data: [{ success: true, order_num: 'one', order_seq: 1 }] }, 'one', 1).accepted, true)
  assert.equal(orderAcceptance({ success: true, data: [{ success: true, order_num: 'two', order_seq: 1 }] }, 'one', 1).accepted, false)
  assert.throws(() => orderStatus({ success: true, order_status: [] }, 'one', 1), /status_unknown/)
  assert.throws(() => vendorPrice({ ...priceResponse, orderYn: 'N' }), /not_approved/)
  assert.throws(() => vendorCodeList({ success: true }), /response_invalid/)
})
Deno.test('production-blocking or unresolved file codes remain errors even after analysis completes', () => {
  const row = { order_num: 'one', order_seq: 1, status_code: 'PGS_07', status_name: '주문완료', status_code_org: 'PGS_07',
    file_process_yn: 'Y', file_error_log: '', invoice_number: '', delivery: '' }
  for (const codes of [{ status_code: 'PGS_06' }, { status_code: 'PGS_05' },
    { status_code_org: 'PGS_06' }]) {
    const result = orderStatus({ success: true, order_status: [{ ...row, ...codes }] }, 'one', 1)
    assert.equal(result.fileError, true); assert.equal(result.fileProcessYn, 'Y')
  }
  const normal = orderStatus({ success: true, order_status: [row] }, 'one', 1)
  assert.equal(normal.fileError, false); assert.equal(normal.statusCode, 'PGS_07'); assert.equal(normal.statusName, '주문완료')
  assert.equal(normal.fileProcessYn, 'Y'); assert.equal(normal.statusCodeOrg, 'PGS_07')
  assert.equal(orderStatus({ success: true, order_status: [{ ...row, file_error_log: '업체 파일 오류' }] }, 'one', 1).fileError, true)
})
Deno.test('original PGS05 without a detail is an inspection warning, not a production-blocking file error', () => {
  for (const processed of ['Y', 'N']) {
    const result = orderStatus({ success: true, order_status: [{ order_num: 'one', order_seq: 1,
      status_code: 'PGS_06', status_name: '파일오류', status_code_org: 'PGS_05', file_process_yn: processed, file_error_log: '' }] }, 'one', 1)
    assert.equal(result.fileError, false); assert.equal(result.fileWarning, true)
    assert.equal(result.fileProcessYn, processed); assert.equal(result.statusCodeOrg, 'PGS_05')
    assert.equal(result.fileErrorSummary, ''); assert.ok(result.fileWarningSummary.includes('주의'))
  }
  assert.equal(hasVendorFileError({ statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileError: true, fileErrorSummary: '' }), false)
  assert.equal(hasVendorFileWarning({ statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileError: true }), true)
  assert.equal(hasVendorFileError({ statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileErrorDetailPresent: true }), true)
  assert.equal(hasVendorFileWarning({ statusCode: 'PGS_06', statusCodeOrg: 'PGS_05', fileErrorSummary: '수정 요청' }), false)
})
Deno.test('matching file error diagnostics explain a CMYK rejection without changing supplier state', () => {
  const row = { order_num: 'one', order_seq: 1, status_code: 'PGS_06', status_name: '파일오류', status_code_org: 'PGS_05',
    file_process_yn: 'N', file_error_log: '내지 1페이지 RGB 색상 오류. CMYK 변환 후 재업로드 필요.' }
  const result = orderStatus({ success: true, order_status: [{ ...row, order_num: 'other', file_error_log: '다른 주문 오류' }, row] }, 'one', 1)
  assert.equal(result.fileErrorSummary, row.file_error_log)
  assert.equal(result.statusName, `파일오류: ${row.file_error_log}`)
  assert.equal(result.statusCode, 'PGS_06'); assert.equal(result.statusCodeOrg, 'PGS_05')
  assert.equal(result.fileProcessYn, 'N'); assert.equal(result.fileError, true)
  assert.equal(JSON.stringify(result).includes('다른 주문 오류'), false)
})
Deno.test('supplier diagnostic redacts URLs credentials contact details and identifiers before truncation', () => {
  const secretUrl = 'https://storage-fixture.test/private.pdf?token=private-signed-token-fixture'
  const secretToken = 'long-authentication-token-fixture'
  const email = 'private-fixture@example.test', phone = '010-0000-1234'
  const orderCode = 'short-id-fixture'
  const row = { order_num: 'one', order_seq: 1, status_code: 'PGS_06', status_name: '파일오류', file_process_yn: 'N',
    file_error_log: `CMYK 오류\u0000\n ${secretUrl} ${secretToken} ${email} ${phone} order_code=${orderCode} Token short-secret ${'설명 '.repeat(100)}` }
  const result = orderStatus({ success: true, order_status: [row] }, 'one', 1)
  assert.ok(result.fileErrorSummary.startsWith('CMYK 오류 ')); assert.ok(result.fileErrorSummary.length <= 200)
  assert.equal(/[\u0000-\u001f\u007f-\u009f]/.test(result.fileErrorSummary), false)
  for (const privateText of [secretUrl, 'storage-fixture.test', 'private-signed', secretToken, email, phone, orderCode, 'short-secret']) {
    assert.equal(JSON.stringify(result).includes(privateText), false)
  }
  assert.ok(result.fileErrorSummary.includes('[URL]')); assert.ok(result.fileErrorSummary.includes('[연락처]'))
  assert.ok(result.fileErrorSummary.includes('[인증정보]')); assert.ok(result.fileErrorSummary.includes('[식별정보]'))
  const nearLimit = { ...row, file_error_log: `${'오류 '.repeat(65)}${secretUrl}` }
  const limited = orderStatus({ success: true, order_status: [nearLimit] }, 'one', 1)
  assert.equal(limited.fileErrorSummary.includes('https'), false)
})
Deno.test('absent or non-text diagnostics do not invent a supplier file error reason', () => {
  for (const log of [undefined, null, '', ' \n\t ', { message: 'CMYK' }, 123]) {
    const row = { order_num: 'one', order_seq: 1, status_code: 'PGS_06', status_name: '파일오류', file_process_yn: 'N', file_error_log: log }
    const result = orderStatus({ success: true, order_status: [row] }, 'one', 1)
    assert.equal(result.fileError, true); assert.equal(result.fileErrorSummary, ''); assert.equal(result.statusName, '파일오류')
  }
  const normal = orderStatus({ success: true, order_status: [{ order_num: 'one', order_seq: 1,
    status_code: 'PGS_07', status_name: '주문완료', status_code_org: 'PGS_07', file_process_yn: 'Y', file_error_log: '' }] }, 'one', 1)
  assert.deepEqual(normal, { statusCode: 'PGS_07', statusName: '주문완료', statusCodeOrg: 'PGS_07',
    fileProcessYn: 'Y', trackingNumber: '', courier: '', fileErrorDetailPresent: false,
    fileError: false, fileErrorSummary: '', fileWarning: false, fileWarningSummary: '' })
})
Deno.test('file error receipt cannot pass readiness or call deposit despite file processing Y', async () => {
  for (const codes of [{ statusCode: 'PGS_06' }, { statusCodeOrg: 'PGS_06' }, { fileError: true }]) {
    const status = { statusCode: 'PGS_07', statusName: '파일오류', statusCodeOrg: 'PGS_07', fileProcessYn: 'Y', fileError: false, ...codes }
    const f = fixture(undefined, { status: async () => status }), row = f.db.tables.redprinting_dev_tests[0]
    Object.assign(row, { status: 'ACCEPTED', submitted_at: '2026-10-13', last_status_at: '2026-10-13', vendor_result_id: 'accepted-error-fixture', vendor_status: status })
    f.db.tables.redprinting_dev_settings[0].test_deposit_enabled = true
    const receipt = (await f.run.action('overview', {}) as any).releaseReadiness.items.find((item: any) => item.id === 'development_receipt')
    assert.equal(receipt.status, 'unconfirmed')
    await assert.rejects(() => f.run.action('confirmTest', { id, confirm: true }), /vendor_file_processing_error/)
    assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
    assert.equal(row.status, 'ACCEPTED'); assert.equal(row.confirmed_at, undefined)
    assert.equal(row.error_code, 'vendor_file_processing_error')
  }
})
Deno.test('PGS05 warning permits development confirmation only after analysis Y and never grants production approval', async () => {
  for (const processed of ['N', 'Y']) {
    const status = { statusCode: 'PGS_06', statusName: '파일오류', statusCodeOrg: 'PGS_05', fileProcessYn: processed,
      fileError: true, fileErrorSummary: '' }
    const f = fixture(undefined, { status: async () => status }), row = f.db.tables.redprinting_dev_tests[0]
    Object.assign(row, { status: 'ACCEPTED', submitted_at: '2026-10-13', last_status_at: '2026-10-13',
      vendor_status: status, error_code: 'vendor_file_processing_error' })
    const view = await f.run.action('getTest', { id }) as any
    assert.equal(view.vendorStatus.fileWarning, true); assert.equal(view.vendorStatus.fileError, false)
    assert.equal(view.errorCode, null); assert.equal(view.lastStatusAt, '2026-10-13')
    assert.equal(row.error_code, 'vendor_file_processing_error', 'View correction must not pretend a fresh supplier query')
    f.db.tables.redprinting_dev_settings[0].test_deposit_enabled = true
    if (processed === 'N') {
      await assert.rejects(() => f.run.action('confirmTest', { id, confirm: true }), /vendor_file_processing_incomplete/)
      assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
    } else {
      const confirmed = await f.run.action('confirmTest', { id, confirm: true }) as any
      assert.equal(confirmed.status, 'CONFIRMED'); assert.equal(confirmed.productionApproved, false)
      assert.equal(f.calls.filter(call => call.path.endsWith('/order-deposit')).length, 1)
    }
  }
})
Deno.test('documented summary-only success confirms receipt through the exact order status, with no invented result ID', async () => {
  const summary = { success: true, message: '' }
  const acceptance = orderAcceptance(summary, 'SFDfixture1', 1)
  assert.equal(acceptance.acknowledged, true); assert.equal(acceptance.accepted, false); assert.equal(acceptance.resultId, null)
  assert.equal(orderAcceptance({ success: false, message: '' }, 'SFDfixture1', 1).acknowledged, false)
  assert.equal(orderAcceptance({ success: true, data: [] }, 'SFDfixture1', 1).acknowledged, false)
  const f = fixture(undefined, { call: async path => path.endsWith('/detail') ? detailResponse : path.endsWith('/price') ? priceResponse : summary })
  const result = await f.run.action('submitTest', { id }) as any
  assert.equal(result.status, 'ACCEPTED'); assert.equal(result.vendorResultId, null); assert.ok(result.lastStatusAt)
  await f.run.action('submitTest', { id })
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
  assert.equal(f.calls.filter(call => call.path === 'status').length, 1)
  assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
})
Deno.test('matching positive status lookup verifies receipt without inventing a missing supplier result id', async () => {
  const raw = { success: true, order_status: [{ order_num: 'SFDfixture1', order_seq: 1, status_code: 'PGS_07', status_name: '주문완료',
    status_code_org: 'PGS_07', file_process_yn: 'Y', file_error_log: '' }] }
  const f = fixture(undefined, { status: async () => orderStatus(raw, 'SFDfixture1', 1) }), row = f.db.tables.redprinting_dev_tests[0]
  Object.assign(row, { status: 'UNKNOWN', submitted_at: '2026-10-13', vendor_result_id: null })
  await f.run.action('refreshTest', { id })
  assert.equal(row.status, 'ACCEPTED'); assert.equal(row.vendor_result_id, null); assert.ok(row.last_status_at)
  const receipt = async () => (await f.run.action('overview', {}) as any).releaseReadiness.items.find((item: any) => item.id === 'development_receipt')
  assert.equal((await receipt()).status, 'ready')
  row.status = 'UNKNOWN'
  assert.equal((await receipt()).status, 'unconfirmed')
  row.status = 'FILES_READY'
  assert.equal((await receipt()).status, 'unconfirmed')
  row.status = 'CANCELED'
  assert.equal((await receipt()).status, 'unconfirmed')
  row.status = 'ACCEPTED'; row.last_status_at = null
  assert.equal((await receipt()).status, 'unconfirmed')
})
Deno.test('accepted PDFs cannot be replaced or resent after the supplier clears the file error', async () => {
  for (const action of ['createTestUploads', 'reuploadTest']) {
    const f = fixture(undefined, { status: async () => ({ statusCode: 'PGS_07', fileProcessYn: 'Y', fileError: false }) })
    const row = f.db.tables.redprinting_dev_tests[0]
    Object.assign(row, { status: 'ACCEPTED', submitted_at: '2026-10-13', vendor_status: { statusCode: 'PGS_06', fileError: true } })
    const files = structuredClone({ uploadId: row.upload_id, cover: row.cover_path, interior: row.interior_path, manifest: row.pdf_manifest })
    await assert.rejects(() => f.run.action(action, { id }), /vendor_file_error_required/)
    assert.deepEqual({ uploadId: row.upload_id, cover: row.cover_path, interior: row.interior_path, manifest: row.pdf_manifest }, files)
    assert.deepEqual(f.calls.map(call => call.path), ['status']); assert.equal(f.db.signed.length, 0)
  }
})
Deno.test('corrected PDF preparation preserves the prior validated file evidence', async () => {
  const f = fixture(undefined, { status: async () => ({ statusCode: 'PGS_06', fileProcessYn: 'Y', fileError: true }) })
  const row = f.db.tables.redprinting_dev_tests[0]
  Object.assign(row, { status: 'ACCEPTED', submitted_at: '2026-10-13', pdf_manifest: {
    validatedAt: '2026-10-13', cover: { sha256: 'old-cover-fixture' }, interior: { sha256: 'old-interior-fixture' },
  } })
  const before = structuredClone(row)
  const prepared = await f.run.action('createTestUploads', { id }) as any
  assert.notEqual(prepared.uploadId, uploadId); assert.equal(row.status, 'ACCEPTED')
  assert.equal(row.cover_path, null); assert.equal(row.interior_path, null); assert.equal(row.pdf_manifest.validatedAt, undefined)
  const prior = row.pdf_manifest.previousVersions[0]
  assert.equal(prior.uploadId, before.upload_id); assert.equal(prior.coverPath, before.cover_path)
  assert.equal(prior.interiorPath, before.interior_path); assert.deepEqual(prior.cover, before.pdf_manifest.cover)
  assert.deepEqual(prior.interior, before.pdf_manifest.interior); assert.ok(prior.replacedAt)
  assert.deepEqual(f.calls.map(call => call.path), ['status'])
})
Deno.test('corrected file transfer keeps the order identity and never submits a new order or deposit', async () => {
  const f = fixture(undefined, { status: async () => ({ statusCode: 'PGS_06', fileProcessYn: 'Y', fileError: true }) })
  const row = f.db.tables.redprinting_dev_tests[0]
  Object.assign(row, { status: 'ACCEPTED', submitted_at: '2026-10-13' })
  const result = await f.run.action('reuploadTest', { id }) as any
  assert.equal(result.orderNum, 'SFDfixture1'); assert.equal(result.status, 'ACCEPTED')
  assert.deepEqual(f.calls.map(call => call.path), ['status', '/v1/code/file-reupload'])
  assert.equal(f.calls[1].body.order_num, 'SFDfixture1'); assert.equal(f.calls[1].body.order_seq, 1)
  assert.equal(f.db.signed.length, 2); assert.deepEqual(row.vendor_status, {}); assert.equal(row.last_status_at, null)
})
Deno.test('zero or incomplete development price is a supplier error and never authorizes a test order', () => {
  assert.throws(() => vendorPrice(unpricedDevelopmentResponse), /not_approved/)
  for (const response of [unpricedDevelopmentResponse, { ...unpricedDevelopmentResponse, priceInfo: { qty: 1, totalPrice: 11000 } },
    { ...priceResponse, priceInfo: { ...priceResponse.priceInfo, totalPrice: 0 } },
    ...[null, false, ''].map(supplyPrice => ({ ...priceResponse, priceInfo: { ...priceResponse.priceInfo, supplyPrice } }))]) {
    assert.throws(() => vendorDevelopmentQuote(response, config), /vendor_(financial_quote_unconfirmed|development_quote_invalid)/)
  }
  const complete = vendorDevelopmentQuote(priceResponse, config)
  assert.deepEqual(complete.price, vendorPrice(priceResponse)); assert.equal(complete.priceError, null)
  assert.equal(complete.developmentQuote.financialQuoteConfirmed, true)
  const oneCopy = vendorDevelopmentQuote({ ...priceResponse, priceInfo: { ...priceResponse.priceInfo, qty: 1 } }, config)
  assert.equal(oneCopy.developmentQuote.quantityConfirmed, true); assert.equal(oneCopy.developmentQuote.qty, 1)
  assert.throws(() => vendorDevelopmentQuote(unpricedDevelopmentResponse, { ...config, environment: 'production' }), /live_environment/)
})
Deno.test('approved code with zero price cannot be mapped or freshly submitted even with caller readiness flags', async () => {
  const f = fixture(undefined, { call: async path => path.endsWith('/detail') ? detailResponse : path.endsWith('/price') ? unpricedDevelopmentResponse :
    { success: true, data: [{ success: true, order_num: 'SFDfixture1', order_seq: 1, result_id: 'result-fixture' }] } })
  const detail = await f.run.action('codeDetail', { orderCode: 'fixture-code' }) as any
  assert.equal(detail.detail.useYn, 'Y'); assert.equal(detail.approvalReady, false); assert.equal(detail.developmentOrderReady, false)
  assert.equal(detail.price, null); assert.equal(detail.financialQuoteConfirmed, false); assert.equal(detail.productionApproved, false)
  assert.equal(detail.priceError, 'vendor_financial_quote_unconfirmed')
  assert.deepEqual(f.calls.find(call => call.path.endsWith('/price'))!.body, { order_code: 'fixture-code', qty: 1 })
  const before = structuredClone(f.db.tables)
  await assert.rejects(() => f.run.action('saveMapping', { productId: 'REDP_200_SOFT', pageCount: 20, orderCode: 'fixture-code', matchConfirmed: true,
    developmentOrderReady: true, note: '개발 사양 20쪽 일치 확인하였습니다.' }), /not_approved/)
  await assert.rejects(() => f.run.action('submitTest', { id, developmentOrderReady: true }), /not_approved/)
  assert.deepEqual(f.db.tables.redprinting_dev_mappings, before.redprinting_dev_mappings)
  assert.deepEqual(f.db.tables.redprinting_dev_tests, before.redprinting_dev_tests)
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 0); assert.equal(f.db.signed.length, 0)
  assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
  await assert.rejects(() => f.run.action('confirmTest', { id, confirm: true }), /confirmation_disabled/)
  const production = fixture(f.db, { config: { ...config, environment: 'production' } })
  for (const action of ['codeDetail', 'saveMapping', 'submitTest']) {
    await assert.rejects(() => production.run.action(action, { id, orderCode: 'fixture-code', productId: 'REDP_200_SOFT', pageCount: 20,
      matchConfirmed: true, developmentOrderReady: true, note: '개발 사양 확인 완료하였습니다.' }), /live_environment/)
  }
  assert.equal(production.calls.length, 0)
})
Deno.test('development response must authorize the code, echo one copy, and report only valid nonnegative amounts', async () => {
  const invalid = [
    { ...unpricedDevelopmentResponse, success: false }, { ...unpricedDevelopmentResponse, orderYn: 'N' },
    { ...unpricedDevelopmentResponse, priceInfo: { qty: 2, totalPrice: 0 } },
    { ...unpricedDevelopmentResponse, priceInfo: { totalPrice: 0 } },
    ...[-1, null, '', false, 'unavailable', Infinity].map(totalPrice => ({ ...unpricedDevelopmentResponse, priceInfo: { qty: 1, totalPrice } })),
    { ...unpricedDevelopmentResponse, priceInfo: { qty: 1, totalPrice: 0, vatPrice: -1 } },
    { ...priceResponse, priceInfo: { ...priceResponse.priceInfo, qty: 2 } },
  ]
  for (const response of invalid) {
    assert.throws(() => vendorDevelopmentQuote(response, config), RedprintingError)
    const f = fixture(undefined, { call: async path => path.endsWith('/detail') ? detailResponse : response })
    const detail = await f.run.action('codeDetail', { orderCode: 'fixture-code', developmentOrderReady: true }) as any
    assert.equal(detail.developmentOrderReady, false); assert.equal(detail.price, null)
    await assert.rejects(() => f.run.action('saveMapping', { productId: 'REDP_200_SOFT', pageCount: 20, orderCode: 'fixture-code', matchConfirmed: true,
      developmentOrderReady: true, note: '이 입력 값으로 검증을 우회할 수 없습니다.' }), /not_approved/)
    await assert.rejects(() => f.run.action('submitTest', { id, developmentOrderReady: true }), /not_approved/)
    assert.equal(f.calls.some(call => call.path.endsWith('/order')), false); assert.equal(f.db.signed.length, 0)
    assert.equal(f.db.tables.redprinting_dev_tests[0].status, 'FILES_READY')
  }
})
Deno.test('supplier code approval and a successful development price response are both required independently', async () => {
  const disabled = fixture(undefined, { call: async path => path.endsWith('/detail') ?
    { ...detailResponse, data: [{ ...detailResponse.data[0], use_yn: 'N' }] } : unpricedDevelopmentResponse })
  const detail = await disabled.run.action('codeDetail', { orderCode: 'fixture-code' }) as any
  assert.equal(detail.detail.useYn, 'N'); assert.equal(detail.developmentOrderReady, false)
  await assert.rejects(() => disabled.run.action('submitTest', { id }), /not_approved/)
  const failed = fixture(undefined, { call: async path => {
    if (path.endsWith('/detail')) return detailResponse
    throw new RedprintingError('vendor_http_500', 502, true, 500)
  } })
  const unavailable = await failed.run.action('codeDetail', { orderCode: 'fixture-code' }) as any
  assert.equal(unavailable.detail.useYn, 'Y'); assert.equal(unavailable.developmentOrderReady, false)
  assert.equal(unavailable.priceError, 'vendor_http_500'); assert.equal(unavailable.developmentQuote, null)
  await assert.rejects(() => failed.run.action('submitTest', { id }), /not_approved/)
  for (const f of [disabled, failed]) assert.equal(f.calls.some(call => call.path.endsWith('/order')), false)
})
Deno.test('submitted test has immutable identity and exact approved code, server files, sender snapshot', async () => {
  const f = fixture()
  const result = await f.run.action('submitTest', { id }) as any
  assert.equal(result.status, 'ACCEPTED')
  const order = f.calls.find(call => call.path.endsWith('/order'))!.body.order_data[0]
  assert.equal(order.order_num, 'SFDfixture1'); assert.equal(order.order_seq, 1); assert.equal(order.order_code, 'fixture-code'); assert.equal(order.send_name, '스냅핏')
  for (const field of ['send_tel','send_zipcode','send_address','send_address_detail']) assert.ok(order[field])
  assert.equal(f.db.signed.length, 2); assert.ok(f.db.signed.every(path => path.startsWith(`${id}/${uploadId}/`)))
  await f.run.action('submitTest', { id })
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
  assert.equal(f.db.tables.redprinting_dev_tests[0].settings_snapshot.colorApprovedAt, null)
})
Deno.test('unapproved or manually unmatched code cannot submit any order', async () => {
  for (const patch of [{ vendor_use_yn: 'N' }, { vendor_order_yn: 'N' }, { exact_match_confirmed: false }, { verified_at: null }]) {
    const f = fixture(); Object.assign(f.db.tables.redprinting_dev_mappings[0], patch)
    await assert.rejects(() => f.run.action('submitTest', { id }), /exact_order_code/)
    assert.equal(f.calls.length, 0)
  }
  const f = fixture()
  await assert.rejects(() => f.run.action('saveMapping', { productId: 'REDP_200_SOFT', pageCount: 20, orderCode: 'fixture-code', matchConfirmed: false, note: '설정 사양 확인하였습니다.' }), /exact_spec/)
})
Deno.test('uncertain response forces status first; neither unknown status nor explicit 404 permits reposting', async () => {
  const f = fixture(undefined, { call: async path => {
    if (path.endsWith('/detail')) return detailResponse
    if (path.endsWith('/price')) return priceResponse
    throw new RedprintingError('vendor_request_uncertain', 502, true)
  }, status: async () => { throw new RedprintingError('vendor_order_status_unknown', 502, true) } })
  const first = await f.run.action('submitTest', { id }) as any
  assert.equal(first.status, 'UNKNOWN'); assert.equal(first.orderNum, 'SFDfixture1')
  await assert.rejects(() => f.run.action('submitTest', { id }), /status_unknown/)
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
  const pending = fixture(f.db, { status: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  await assert.rejects(() => pending.run.action('submitTest', { id }), /vendor_pre_registration_confirmation_required/)
  const next = await pending.run.action('getTest', { id }) as any
  assert.equal(next.status, 'UNKNOWN'); assert.equal(next.orderNum, first.orderNum)
  assert.equal(pending.calls[0].path, 'status'); assert.equal(pending.calls.filter(call => call.path.endsWith('/order')).length, 0)
})
Deno.test('explicit supplier failure evidence preserves the original attempt and locks its order number', async () => {
  const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]
  const diagnostic = submissionDiagnostic({ success: true }, row.order_num, row.order_seq)
  Object.assign(row, { status: 'UNKNOWN', submitted_at: new Date(Date.now() - 60000).toISOString(),
    error_code: 'vendor_pre_registration_confirmation_required', order_code: 'fixture-code', source_fingerprint: 'original-fixture-fingerprint',
    vendor_status: { submissionDiagnostic: diagnostic } })
  const before = structuredClone(row), evidence = { reason: 'vendor_pricing_error', sourceType: 'vendor_email',
    reference: '1a132994ef0f3b9d', confirmedAt: new Date(Date.now() - 30000).toISOString() }
  const result = await f.run.action('recordVendorFailure', { id, evidence }) as any
  assert.equal(result.status, 'REJECTED'); assert.equal(result.errorCode, 'vendor_pricing_failure_confirmed')
  assert.deepEqual(result.submissionDiagnostic, diagnostic); assert.deepEqual(result.vendorStatus.submissionDiagnostic, diagnostic)
  assert.equal(result.vendorStatus.previousErrorCode, before.error_code)
  assert.deepEqual(Object.keys(result.vendorStatus.vendorFailureEvidence).sort(), ['confirmedAt', 'reason', 'recordedAt', 'reference', 'sourceType'])
  assert.equal(result.vendorStatus.vendorFailureEvidence.recordedBy, undefined)
  for (const key of ['id', 'request_id', 'order_num', 'order_seq', 'order_code', 'recipient', 'upload_id', 'cover_path', 'interior_path',
    'pdf_manifest', 'source_fingerprint', 'submitted_at', 'last_status_at', 'confirmed_at', 'canceled_at']) assert.deepEqual(row[key], before[key])
  const resolved = structuredClone(row)
  assert.equal((await f.run.action('recordVendorFailure', { id, evidence }) as any).status, 'REJECTED')
  assert.deepEqual(row, resolved)
  await assert.rejects(() => f.run.action('recordVendorFailure', { id, evidence: { ...evidence, reference: '1a132994ef0f3b9e' } }), /evidence_conflict/)
  f.db.tables.redprinting_dev_settings[0].test_deposit_enabled = true
  for (const action of ['submitTest', 'refreshTest', 'updateTestRecipient', 'cancelTest', 'confirmTest', 'reuploadTest', 'createTestUploads', 'finalizeTestFiles']) {
    await assert.rejects(() => f.run.action(action, { id, recipient: receiver, confirm: true, uploadId }), /vendor_failure_order_locked/)
  }
  assert.equal((await f.run.action('getTest', { id }) as any).orderNum, before.order_num)
  assert.equal((await f.run.action('listTests', {}) as any).items[0].status, 'REJECTED')
  assert.equal((await f.run.action('overview', {}) as any).releaseReadiness.uncertainSubmissionCount, 0)
  assert.deepEqual(row, resolved); assert.equal(f.calls.length, 0); assert.equal(f.db.signed.length, 0)
})
Deno.test('supplier failure recording requires bounded email evidence and rejects impossible confirmation times without mutations', async () => {
  const confirmedAt = new Date(Date.now() - 30000).toISOString(), evidence = { reason: 'vendor_pricing_error', sourceType: 'vendor_email',
    reference: '1a132994ef0f3b9d', confirmedAt }
  const invalid = [undefined, {}, { ...evidence, reason: 'status_404' }, { ...evidence, sourceType: 'vendor_portal' },
    { ...evidence, reference: 'private recipient / signed URL' }, { ...evidence, reference: '1a132994ef0f3b9d '.repeat(50) },
    { ...evidence, confirmedAt: '2026-02-30T00:00:00.000Z' }, { ...evidence, confirmedAt: new Date(Date.now() + 60000).toISOString() },
    { ...evidence, confirmedAt: new Date(Date.now() - 120000).toISOString() }, { ...evidence, message: 'raw-private-mail-body' },
    { ...evidence, recordedBy: 'caller-forged-actor' }]
  for (const rejected of invalid) {
    const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]
    Object.assign(row, { status: 'UNKNOWN', submitted_at: new Date(Date.now() - 60000).toISOString(), error_code: 'vendor_order_response_uncertain' })
    const before = structuredClone(f.db.tables)
    await assert.rejects(() => f.run.action('recordVendorFailure', { id, evidence: rejected }), /vendor_failure_evidence_required/)
    assert.deepEqual(f.db.tables, before); assert.equal(f.calls.length, 0); assert.equal(f.db.locks.size, 0)
  }
})
Deno.test('supplier failure evidence cannot alter accepted, confirmed, pending, unsubmitted, canceled, or processing orders', async () => {
  const evidence = { reason: 'vendor_pricing_error', sourceType: 'vendor_email', reference: '1a132994ef0f3b9d', confirmedAt: new Date(Date.now() - 30000).toISOString() }
  for (const patch of [{ status: 'ACCEPTED' }, { status: 'CONFIRMED' }, { status: 'SUBMITTING' }, { status: 'DRAFT' }, { status: 'FILES_READY' },
    { status: 'CANCELED' }, { confirmed_at: '2026-10-12' }, { canceled_at: '2026-10-12' }, { vendor_result_id: 'supplier-receipt' },
    { vendor_status: { fileProcessYn: 'Y' } }, { vendor_status: { statusCode: '10' } }, { vendor_status: { statusCode: 10 } },
    { vendor_status: { statusName: '접수' } }, { vendor_status: { statusCodeOrg: 'received' } }, { vendor_status: { trackingNumber: 'fixture-tracking' } },
    { error_code: 'arbitrary-error' }]) {
    const f = fixture(), row = f.db.tables.redprinting_dev_tests[0]
    Object.assign(row, { status: 'UNKNOWN', submitted_at: new Date(Date.now() - 60000).toISOString(), error_code: 'vendor_order_response_uncertain' }, patch)
    const before = structuredClone(f.db.tables)
    await assert.rejects(() => f.run.action('recordVendorFailure', { id, evidence }), /vendor_failure_record_not_allowed/)
    assert.deepEqual(f.db.tables, before); assert.equal(f.calls.length, 0)
  }
  const unsubmitted = fixture()
  unsubmitted.db.tables.redprinting_dev_tests[0].status = 'UNKNOWN'
  await assert.rejects(() => unsubmitted.run.action('recordVendorFailure', { id, evidence }), /vendor_failure_evidence_required/)
  const busy = fixture(); busy.db.locks.add(id)
  await assert.rejects(() => busy.run.action('recordVendorFailure', { id, evidence }), /test_operation_in_progress/)
  const production = fixture(undefined, { config: { ...config, environment: 'production' } })
  await assert.rejects(() => production.run.action('recordVendorFailure', { id, evidence }), /live_environment/)
  assert.equal(production.calls.length, 0)
})
Deno.test('resolved historical failure permits a fresh order identity and verified receipt without enabling production', async () => {
  const f = fixture(undefined, { call: async (path, body) => {
    if (path.endsWith('/detail')) return detailResponse
    if (path.endsWith('/price')) return { ...priceResponse, priceInfo: { ...priceResponse.priceInfo, qty: 1 } }
    return { success: true, data: [{ success: true, order_num: body.order_data[0].order_num, order_seq: 1, result_id: 'new-result-fixture' }] }
  } }), old = f.db.tables.redprinting_dev_tests[0]
  Object.assign(old, { status: 'UNKNOWN', submitted_at: new Date(Date.now() - 60000).toISOString(), error_code: 'vendor_pre_registration_confirmation_required' })
  await f.run.action('recordVendorFailure', { id, evidence: { reason: 'vendor_pricing_error', sourceType: 'vendor_email', reference: '1a132994ef0f3b9d',
    confirmedAt: new Date(Date.now() - 30000).toISOString() } })
  const fresh = await f.run.action('createTest', { requestId: '44444444-4444-4444-8444-444444444444', productId: old.product_id, pageCount: old.page_count, recipient: receiver }) as any
  assert.notEqual(fresh.id, old.id); assert.notEqual(fresh.orderNum, old.order_num)
  const next = f.db.tables.redprinting_dev_tests.find(row => row.id === fresh.id)
  Object.assign(next, { status: 'FILES_READY', upload_id: uploadId, cover_path: `${fresh.id}/${uploadId}/cover.pdf`,
    interior_path: `${fresh.id}/${uploadId}/interior.pdf`, pdf_manifest: { validatedAt: '2026-10-12' } })
  assert.equal((await f.run.action('submitTest', { id: fresh.id }) as any).status, 'ACCEPTED')
  await f.run.action('refreshTest', { id: fresh.id })
  const readiness = (await f.run.action('overview', {}) as any).releaseReadiness
  assert.equal(readiness.uncertainSubmissionCount, 0); assert.equal(readiness.preRegistrationHoldCount, 0)
  assert.equal(readiness.items.find((item: any) => item.id === 'development_receipt').status, 'ready')
  assert.equal(readiness.ready, false); assert.equal(readiness.canAcceptCustomerOrders, false)
  assert.equal(old.status, 'REJECTED'); assert.equal(old.order_num, 'SFDfixture1'); assert.equal(old.error_code, 'vendor_pricing_failure_confirmed')
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
  assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
})
Deno.test('development portal pre-registration plus status 404 holds submission, recipient edits, and cancellation without changing identity or files', async () => {
  let portalRegistered = false
  const f = fixture(undefined, { call: async path => {
    if (path.endsWith('/detail')) return detailResponse
    if (path.endsWith('/price')) return priceResponse
    portalRegistered = true
    // A minimal success can represent development portal registration. It
    // lacks the item identity required to prove operational acceptance.
    return { success: true, message: '' }
  }, status: async () => { assert.equal(portalRegistered, true); throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  const first = await f.run.action('submitTest', { id }) as any
  assert.equal(first.status, 'UNKNOWN'); assert.equal(first.vendorResultId, null)
  assert.equal(first.submissionDiagnostic.topSuccess, true); assert.equal(first.submissionDiagnostic.fields.data.present, false)
  const before = structuredClone(f.db.tables.redprinting_dev_tests[0]), row = f.db.tables.redprinting_dev_tests[0]
  for (const action of ['refreshTest', 'submitTest', 'updateTestRecipient', 'cancelTest']) {
    await assert.rejects(() => f.run.action(action, { id, recipient: { ...receiver, name: '변경 요청' } }),
      error => error instanceof RedprintingError && error.code === 'vendor_pre_registration_confirmation_required' && error.status === 409)
    for (const key of ['id', 'request_id', 'order_num', 'order_seq', 'order_code', 'status', 'recipient', 'upload_id',
      'cover_path', 'interior_path', 'pdf_manifest', 'source_fingerprint', 'submitted_at', 'vendor_status']) assert.deepEqual(row[key], before[key])
    assert.equal(row.canceled_at, undefined); assert.equal(row.confirmed_at, undefined)
  }
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
  assert.equal(f.calls.some(call => call.path.endsWith('/order-cancel') || call.path.endsWith('/order-deposit')), false)
  assert.equal(row.error_code, 'vendor_pre_registration_confirmation_required')
  // Once the supplier status actually finds this same order, acceptance may
  // be recovered and an explicitly successful supplier cancellation trusted.
  const found = fixture(f.db)
  assert.equal((await found.run.action('refreshTest', { id }) as any).status, 'ACCEPTED')
  assert.equal((await found.run.action('cancelTest', { id }) as any).status, 'CANCELED')
  assert.equal(found.calls.filter(call => call.path.endsWith('/order-cancel')).length, 1)
  assert.equal(found.calls.some(call => call.path.endsWith('/order')), false)
})
Deno.test('submission-history states with a missing timestamp cannot be canceled locally or resubmitted after status 404', async () => {
  for (const status of ['SUBMITTING', 'UNKNOWN', 'REJECTED']) {
    const f = fixture(undefined, { status: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
    const row = f.db.tables.redprinting_dev_tests[0]; row.status = status
    for (const action of ['submitTest', 'cancelTest']) {
      await assert.rejects(() => f.run.action(action, { id }), /vendor_pre_registration_confirmation_required/)
      assert.equal(row.status, status); assert.equal(row.canceled_at, undefined)
    }
    assert.equal(f.calls.some(call => call.path.endsWith('/order') || call.path.endsWith('/order-cancel')), false)
  }
  for (const status of ['DRAFT', 'FILES_READY']) {
    const f = fixture(); f.db.tables.redprinting_dev_tests[0].status = status
    assert.equal((await f.run.action('cancelTest', { id }) as any).status, 'CANCELED')
    assert.equal(f.calls.length, 0)
  }
})
Deno.test('lost successful reply is recovered through status without a second order', async () => {
  const f = fixture(); Object.assign(f.db.tables.redprinting_dev_tests[0], { status: 'UNKNOWN', submitted_at: '2026-10-08', order_code: 'fixture-code' })
  const result = await f.run.action('submitTest', { id }) as any
  assert.equal(result.status, 'ACCEPTED'); assert.deepEqual(f.calls.map(call => call.path), ['status'])
})
Deno.test('per-test lease prevents simultaneous duplicate submissions', async () => {
  let release!: () => void, reached!: () => void
  const pending = new Promise<void>(resolve => { release = resolve }), started = new Promise<void>(resolve => { reached = resolve })
  const f = fixture(undefined, { call: async path => {
    if (path.endsWith('/detail')) return detailResponse
    if (path.endsWith('/price')) return priceResponse
    reached(); await pending; return { success: true, data: [{ success: true, order_num: 'SFDfixture1', order_seq: 1 }] }
  } })
  const first = f.run.action('submitTest', { id }); await started
  await assert.rejects(() => f.run.action('submitTest', { id }), /test_operation_in_progress/)
  await assert.rejects(() => f.run.action('recordVendorFailure', { id, evidence: { reason: 'vendor_pricing_error', sourceType: 'vendor_email',
    reference: '1a132994ef0f3b9d', confirmedAt: new Date().toISOString() } }), /test_operation_in_progress/)
  release(); await first
  assert.equal(f.calls.filter(call => call.path.endsWith('/order')).length, 1)
})
Deno.test('confirmation is opt-in, development-only, file processing verified, and never automatic', async () => {
  const f = fixture(); await f.run.action('submitTest', { id })
  assert.equal(f.calls.some(call => call.path.endsWith('/order-deposit')), false)
  await assert.rejects(() => f.run.action('confirmTest', { id, confirm: true }), /confirmation_disabled/)
  f.db.tables.redprinting_dev_settings[0].test_deposit_enabled = true
  await assert.rejects(() => f.run.action('confirmTest', { id, confirm: false }), /confirmation_disabled/)
  const incomplete = fixture(f.db, { status: async () => ({ fileProcessYn: 'N' }) })
  await assert.rejects(() => incomplete.run.action('confirmTest', { id, confirm: true }), /file_processing_incomplete/)
  assert.equal(incomplete.calls.some(call => call.path.endsWith('/order-deposit')), false)
  const result = await f.run.action('confirmTest', { id, confirm: true }) as any
  assert.equal(result.status, 'CONFIRMED')
  await assert.rejects(() => f.run.action('cancelTest', { id }), /already_confirmed/)
})
Deno.test('test creation is idempotent across reordered JSONB recipient keys; changed spec rejects reuse', async () => {
  const f = fixture()
  const existing = f.db.tables.redprinting_dev_tests[0]
  existing.recipient = Object.fromEntries(Object.entries(receiver).reverse())
  const result = await f.run.action('createTest', { requestId: existing.request_id, productId: existing.product_id, pageCount: existing.page_count, recipient: receiver }) as any
  assert.equal(result.id, id); assert.equal(f.db.tables.redprinting_dev_tests.length, 1)
  await assert.rejects(() => f.run.action('createTest', { requestId: existing.request_id, productId: existing.product_id, pageCount: 22, recipient: receiver }), /request_id_conflict/)
})
Deno.test('code list 404 is empty normal state and invalidates old map readiness', async () => {
  const f = fixture(undefined, { call: async () => { throw new RedprintingError('vendor_http_404', 404, false, 404) } })
  const result = await f.run.action('syncCodes', {}) as any
  assert.equal(result.count, 0); assert.equal(f.db.tables.redprinting_dev_mappings[0].verified_at, null)
  assert.ok(f.db.tables.redprinting_dev_settings[0].codes_synced_at)
})

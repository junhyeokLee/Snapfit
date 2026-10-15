import { getPrintSpec, PRINT_COVER_PRICING_VERSION, PRINT_PRODUCTS } from '../../../supabase/functions/_shared/print-contract.ts'
import { RedprintingError } from '../../../supabase/functions/_shared/redprinting.ts'

export const owner = '11111111-1111-4111-8111-111111111111'
export const jobId = '22222222-2222-4222-8222-222222222222'
const product = PRINT_PRODUCTS.REDP_200X150_SOFT
const clone = value => JSON.parse(JSON.stringify(value))

export function makeFixture({ snapshot, spec, cover, interior, inspectPdf, configuration = {} } = {}) {
  // Use the same current clock as server PDF lease guards. Individual tests
  // still advance this local clock explicitly to exercise expiry and recovery.
  let clock = Date.now()
  const calls = [], files = new Map(), selectedProduct = spec ? PRINT_PRODUCTS[spec.id] : product
  if (!selectedProduct) throw new Error('Local fixture product required')
  const pageCount = spec?.pageCount ?? 20
  const stockSnapshot = { printProduct: selectedProduct, album: { id: 1, owner_id: owner, ratio: '4:3',
    cover_layers_json: JSON.stringify({ printProduct: selectedProduct }) }, pages: Array.from({ length: pageCount }, (_, i) => ({ index: i + 1, layers_json: '[]' })) }
  const order = { order_id: 'ordp_fixture', user_id: owner, album_id: 1, amount: 49900, page_count: pageCount,
    pricing_version: PRINT_COVER_PRICING_VERSION, checkout_flow: 'PORTONE_V2_V1',
    verified_payment_id: 'SFP_fixture', verified_payment_provider: 'PORTONE', payment_confirmed_at: '2026-10-14T00:00:00Z',
    payment_reversed_at: null, status: 'PAYMENT_COMPLETED', print_fulfillment_status: 'AWAITING_RENDER',
    print_content_snapshot: snapshot ? { ...snapshot, printProduct: snapshot.printProduct ?? selectedProduct } : stockSnapshot, print_product_snapshot: selectedProduct,
    recipient_name: '검수 수령인', recipient_phone: '01000000001', zip_code: '12345', address_line1: '테스트 주소', address_line2: '로컬 검수', delivery_memo: '' }
  const inferred = getPrintSpec({ ...order, checkout_flow: null })
  order.print_spec_snapshot = spec ?? { ...inferred, verified: true, specVersion: 'LOCAL_STUB_APPROVED_SOFT20_V1' }
  const costSnapshot = { estimatedPrintCost: 21230, estimatedShippingCost: 3500, estimatedPackagingCost: 0,
    paymentFeeRate: .05, reprintReserveRate: .05, minimumContribution: 10000, operationsReserve: 3000,
    fulfillmentConfirmation: { senderName: '스냅핏', senderLabelConfirmed: true, priceSlipOmittedConfirmed: true,
      promotionalMaterialsOmittedConfirmed: true, evidence: 'LOCAL FIXTURE: confirmed brand and no extra inserts; never a real approval' } }
  const job = { id: jobId, order_id: order.order_id, event_type: 'RENDER', state: 'PENDING', attempts: 0,
    payload: { vendorOrderNum: 'SFO_00000000000040008000000000000001', vendorOrderSeq: 1, queryOnly: false }, available_at: new Date(clock).toISOString() }
  const expected = { paymentId: order.verified_payment_id, storeId: 'store-fixture', channelKey: 'channel-key-fixture', amount: 49900, currency: 'KRW', environment: 'live' }
  const envelope = () => clone({ job, order, approvedSpec: order.print_spec_snapshot, orderCode: 'LOCAL_FIXTURE_CODE',
    sourceFingerprint: 'immutable-review-revision-distinct-from-pdf-fingerprint', allowedAssetOwners: [owner], paymentEnvironment: 'live', paymentExpectation: expected, costSnapshot,
    approvalCurrent: f.approvalCurrent })
  const lease = args => args.p_owner === job.lease_owner && job.state === 'CLAIMED' && Date.parse(job.lease_until) > clock
  class Query {
    constructor(table) { this.table = table; this.patch = null; this.filters = [] }
    select() { return this }
    update(value) { this.patch = value; return this }
    eq(key, value) { this.filters.push(row => row[key] === value); return this }
    gt(key, value) { this.filters.push(row => Date.parse(row[key]) > Date.parse(value)); return this }
    is(key, value) { this.filters.push(row => (row[key] ?? null) === value); return this }
    in() { return this }
    async maybeSingle() {
      if (this.table !== 'orders') return { data: null, error: null }
      if (!this.filters.every(filter => filter(order))) return { data: null, error: null }
      if (this.patch) { Object.assign(order, clone(this.patch)); calls.push({ patch: clone(this.patch) }) }
      return { data: clone(order), error: null }
    }
    then(resolve, reject) { return this.maybeSingle().then(resolve, reject) }
  }
  const db = {
    from(table) { return new Query(table) },
    storage: {
      async getBucket() { return { data: { public: false }, error: null } },
      from(bucket) { return {
        async createSignedUploadUrl(path) { return { data: { token: 'fixture', signedUrl: `https://fixture.supabase.co/storage/v1/object/upload/sign/${bucket}/${path}?token=fixture` }, error: null } },
        async createSignedUrl(path) { return { data: { signedUrl: `https://fixture.supabase.co/storage/v1/object/sign/${bucket}/${path}?token=fixture` }, error: null } },
        async upload(path, bytes) { files.set(path, typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes); return { error: null } },
        async download(path) { return files.has(path) ? { data: new Blob([files.get(path)]), error: null } : { data: null, error: { message: 'fixture missing' } } },
      } },
    },
    async rpc(name, args) {
      calls.push({ rpc: name, args: clone(args) })
      if (name === 'claim_print_fulfillment_job') {
        if (!args.p_runtime_ready || job.state === 'DONE' || job.state === 'FAILED') return { data: null, error: null }
        if (job.state === 'CLAIMED' && Date.parse(job.lease_until) > clock) return { data: null, error: null }
        job.state = 'CLAIMED'; job.lease_owner = args.p_worker_id; job.lease_until = new Date(clock + 120000).toISOString(); job.attempts++
        order.print_package_lock_token = job.lease_owner; order.print_package_lock_until = job.lease_until
        return { data: envelope(), error: null }
      }
      if (name === 'list_print_fulfillment_jobs') return { data: [clone(job)], error: null }
      if (!lease(args)) return { data: null, error: { message: 'fixture lease lost' } }
      if (name === 'get_print_fulfillment_job') return { data: envelope(), error: null }
      if (name === 'renew_print_fulfillment_job') {
        if (!args.p_runtime_ready) return { data: null, error: null }
        job.lease_until = new Date(clock + 120000).toISOString(); order.print_package_lock_until = job.lease_until
        return { data: job.lease_until, error: null }
      }
      if (name === 'record_print_fulfillment_attempt') {
        job.payload.queryOnly = true
        if (job.event_type === 'CONFIRM') job.payload.depositAttempted = true
        return { data: clone(job), error: null }
      }
      if (name === 'commit_print_fulfillment_submission') {
        if (!job.payload.queryOnly) return { data: null, error: { message: 'fixture attempt missing' } }
        Object.assign(order, { print_fulfillment_status: 'SUBMITTED', print_vendor_order_id: args.p_vendor_order_id,
          print_submitted_at: new Date(clock).toISOString(), fulfillment_method: 'DIRECT' })
        return { data: clone(order), error: null }
      }
      if (name === 'finish_print_fulfillment_job') {
        if (job.event_type !== args.p_expected_stage) return { data: null, error: { message: 'fixture stage changed' } }
        const { nextStage, availableAt, ...payload } = args.p_result
        job.event_type = nextStage === 'DONE' ? job.event_type : nextStage; job.state = nextStage === 'DONE' ? 'DONE' : 'PENDING'
        job.available_at = availableAt ?? new Date(clock).toISOString(); job.payload = { ...job.payload, ...payload }
        job.lease_owner = null; job.lease_until = null; order.print_package_lock_token = null; order.print_package_lock_until = null
        return { data: clone(job), error: null }
      }
      if (name === 'fail_print_fulfillment_job') {
        const attempted = job.payload.queryOnly || (job.event_type === 'SUBMIT' && job.payload.supplierAttemptedAt) || (job.event_type === 'CONFIRM' && job.payload.depositAttempted)
        job.state = args.p_terminal ? 'FAILED' : ['SUBMIT','CONFIRM'].includes(job.event_type) && attempted ? 'UNKNOWN' : 'PENDING'
        if (['SUBMIT','CONFIRM'].includes(job.event_type) && attempted) job.payload.queryOnly = true
        job.last_error_code = args.p_error_code; job.lease_owner = null; job.lease_until = null
        order.print_package_lock_token = null; order.print_package_lock_until = null
        return { data: clone(job), error: null }
      }
      return { data: null, error: { message: 'unknown fixture RPC' } }
    },
  }
  const status = { orderNum: job.payload.vendorOrderNum, orderSeq: 1, statusCode: 'PGS_07', statusCodeOrg: 'PGS_07',
    fileProcessYn: 'N', courier: '', trackingNumber: '', fileError: false }
  const vendor = {
    async depositBalance() { calls.push('supplier-balance'); return 1000000 },
    async price() { calls.push('supplier-price'); return { totalPrice: 21230, supplyPrice: 19300, vatPrice: 1930, orderYn: 'Y' } },
    async submit(payload) { calls.push({ supplierSubmit: clone(payload) }); return { success: true, data: [{ order_num: job.payload.vendorOrderNum, order_seq: 1, success: true, result_id: 'fixture-supplier-record' }] } },
    async status() { calls.push('supplier-status'); return clone(status) },
    async confirm() { calls.push('supplier-deposit'); Object.assign(status, { statusCode: 'PGS_20', statusCodeOrg: 'PGS_20', fileProcessYn: 'Y' }); return { success: true } },
  }
  const receipt = { provider: 'PORTONE', version: 'V2', status: 'PAID', ...expected,
    transactionId: 'fixture-transaction', paidAmount: 49900, discountAmount: 0, paidAt: '2026-10-14T00:00:00Z', isTest: false }
  const f = { db, order, job, calls, files, vendor, status, costSnapshot, expected, receipt, inspectPdf, approvalCurrent: true,
    config: { enabled: true, environment: 'live', depositEnabled: true, vendorReady: true,
      supabaseUrl: 'https://fixture.supabase.co', paymentApiSecret: 'local-stub-no-network', ...configuration },
    sender: async () => ({ senderName: '스냅핏', senderTel: '01000000002', senderZipcode: '12345', senderAddress: '테스트 발송지', senderAddressDetail: '로컬 검수' }),
    now: () => clock, advanceTime(ms) { clock += ms },
    async paymentLookup() { calls.push('latest-live-payment'); return clone(receipt) },
    async upload(uploads) { files.set(uploads.cover.path, cover); files.set(uploads.interior.path, interior) },
  }
  return f
}

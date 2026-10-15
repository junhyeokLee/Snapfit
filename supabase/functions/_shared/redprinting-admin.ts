import { RedprintingClient, RedprintingError, assertDevelopment, assertReadySettings, identifier, testId, text, record,
  validateSettings, validateTestSpec, redprintingMatrix, REDPRINTING_PRODUCTS, REDPRINTING_PDF_LIMITS,
  vendorCodeList, vendorCodeDetail, vendorPrice, vendorDevelopmentQuote, orderAcceptance, submissionDiagnostic, safeSubmissionDiagnostic, testOrderPayload, recipient, vendorTestRecipient, testPrintSpec, coverTrim, hasVendorFileError, vendorFileFlags,
  type RedprintingEnvironment, type RedprintingSettings, type VendorCode, type DevelopmentVendorQuote,
} from './redprinting.ts'
import { PRINT_BUCKET, sha256 } from './print-contract.ts'
import { validatePrintPdf, type PdfInspector } from './print-package.ts'

type Db = any
const now = () => new Date().toISOString()
const pause = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))
function check<T>(result: { data: T; error: unknown }, code = 'redprinting_database_unavailable'): T {
  if (result.error) throw new RedprintingError(code, 503)
  return result.data
}
const isMissing = (error: unknown) => error instanceof RedprintingError && error.vendorStatus === 404
const hasSubmissionHistory = (row: Record<string, any>) => Boolean(row.submitted_at) || ['SUBMITTING', 'UNKNOWN', 'REJECTED', 'ACCEPTED', 'CONFIRMED'].includes(row.status)
const vendorFailureErrorCodes = new Set(['vendor_pre_registration_confirmation_required', 'vendor_order_response_uncertain',
  'vendor_order_rejected', 'vendor_request_uncertain', 'vendor_http_400', 'vendor_order_not_found', 'vendor_http_404'])
function isoTimestamp(value: unknown): string | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value)) return null
  const milliseconds = Date.parse(value)
  if (!Number.isFinite(milliseconds)) return null
  const canonical = new Date(milliseconds).toISOString()
  return canonical === (value.includes('.') ? value : value.replace('Z', '.000Z')) ? canonical : null
}
type VendorFailureEvidence = { reason: 'vendor_pricing_error'; sourceType: 'vendor_email'; reference: string; confirmedAt: string; recordedAt: string }
function safeVendorFailureEvidence(value: unknown): VendorFailureEvidence | null {
  const raw = record(value), confirmedAt = isoTimestamp(raw.confirmedAt), recordedAt = isoTimestamp(raw.recordedAt)
  if (raw.reason !== 'vendor_pricing_error' || raw.sourceType !== 'vendor_email' || typeof raw.reference !== 'string' ||
    !/^[a-f0-9]{16,32}$/.test(raw.reference) || !confirmedAt || !recordedAt || Date.parse(confirmedAt) > Date.parse(recordedAt)) return null
  return { reason: 'vendor_pricing_error', sourceType: 'vendor_email', reference: raw.reference, confirmedAt, recordedAt }
}
const vendorFailureLocked = (row: Record<string, any>) => row.error_code === 'vendor_pricing_failure_confirmed' ||
  safeVendorFailureEvidence(record(row.vendor_status).vendorFailureEvidence) !== null
function failureEvidenceInput(value: unknown, row: Record<string, any>): Omit<VendorFailureEvidence, 'recordedAt'> {
  const raw = record(value), confirmedAt = isoTimestamp(raw.confirmedAt), submittedAt = Date.parse(row.submitted_at)
  if (Object.keys(raw).some(key => !['reason', 'sourceType', 'reference', 'confirmedAt'].includes(key)) ||
    raw.reason !== 'vendor_pricing_error' || raw.sourceType !== 'vendor_email' || typeof raw.reference !== 'string' ||
    !/^[a-f0-9]{16,32}$/.test(raw.reference) || !confirmedAt || !Number.isFinite(submittedAt) ||
    Date.parse(confirmedAt) < submittedAt || Date.parse(confirmedAt) > Date.now()) throw new RedprintingError('vendor_failure_evidence_required', 400)
  return { reason: 'vendor_pricing_error', sourceType: 'vendor_email', reference: raw.reference, confirmedAt }
}

export function settingsFromRow(row: Record<string, any>): RedprintingSettings {
  return { senderName: row.sender_name ?? '스냅핏', senderTel: row.sender_tel ?? '', senderZipcode: row.sender_zipcode ?? '',
    senderAddress: row.sender_address ?? '', senderAddressDetail: row.sender_address_detail ?? '',
    colorMode: row.color_mode ?? 'UNCONFIRMED', colorApprovalNote: row.color_approval_note ?? '', colorApprovedAt: row.color_approved_at ?? null,
    testDepositEnabled: row.test_deposit_enabled === true, developmentRgbTestAcknowledged: row.development_rgb_test_acknowledged === true,
    developmentGeometryTestAcknowledged: row.development_geometry_test_acknowledged === true,
  }
}
function settingsPatch(settings: RedprintingSettings) {
  return { sender_name: settings.senderName, sender_tel: settings.senderTel, sender_zipcode: settings.senderZipcode,
    sender_address: settings.senderAddress, sender_address_detail: settings.senderAddressDetail,
    color_mode: settings.colorMode, color_approval_note: settings.colorApprovalNote, color_approved_at: settings.colorApprovedAt,
    test_deposit_enabled: settings.testDepositEnabled, development_rgb_test_acknowledged: settings.developmentRgbTestAcknowledged,
    development_geometry_test_acknowledged: settings.developmentGeometryTestAcknowledged,
  }
}
function quoteJson(value: unknown) {
  const snapshot = record(value), saved = record(snapshot.developmentQuote)
  let price: ReturnType<typeof vendorPrice> | null = null
  try { price = vendorPrice({ success: true, orderYn: snapshot.orderYn, priceInfo: snapshot }) }
  catch (error) { if (!(error instanceof RedprintingError)) throw error }
  const savedDevelopmentQuote = saved.environment === 'development' && saved.developmentOnly === true &&
    saved.responseSuccess === true && saved.orderYn === 'Y' && saved.qty === 1 && saved.quantityConfirmed === true &&
    typeof saved.developmentPriceTotal === 'number' && Number.isFinite(saved.developmentPriceTotal) && saved.developmentPriceTotal >= 0
  const developmentQuote: (DevelopmentVendorQuote & { observedAt: string }) | null = savedDevelopmentQuote ? {
    environment: 'development', developmentOnly: true, responseSuccess: true, orderYn: 'Y', qty: 1,
    quantityConfirmed: true, developmentPriceTotal: saved.developmentPriceTotal, financialQuoteConfirmed: false,
    observedAt: text(saved.observedAt, 50),
  } : null
  return { price, financialQuoteConfirmed: price !== null, developmentQuote,
    developmentPriceTotal: developmentQuote?.developmentPriceTotal ?? null,
    priceError: !price && Object.keys(snapshot).length ? 'vendor_financial_quote_unconfirmed' : null,
    developmentOrderReady: price !== null }
}
function quoteSnapshot(checked: { price: ReturnType<typeof vendorPrice> | null; developmentQuote: DevelopmentVendorQuote | null }) {
  if (!checked.price) throw new RedprintingError('vendor_financial_quote_unconfirmed')
  return checked.price
}
function mappingJson(row: Record<string, any>) {
  const quote = quoteJson(row.price_snapshot)
  const verified = row.exact_match_confirmed === true && row.vendor_use_yn === 'Y' && row.vendor_order_yn === 'Y' && Boolean(row.verified_at) && quote.developmentOrderReady
  return { productId: row.product_id, pageCount: row.page_count, orderCode: row.order_code, note: row.note,
    verified, developmentOrderReady: verified, productionApproved: false,
    matchConfirmed: row.exact_match_confirmed === true, vendorUseYn: row.vendor_use_yn, vendorOrderYn: row.vendor_order_yn,
    detail: row.detail_snapshot, price: quote.price, financialQuoteConfirmed: quote.financialQuoteConfirmed,
    developmentQuote: quote.developmentQuote, developmentPriceTotal: quote.developmentPriceTotal, priceError: quote.priceError,
    verifiedAt: row.verified_at, updatedAt: row.updated_at }
}
export function testJson(row: Record<string, any>) {
  const { submissionDiagnostic: savedDiagnostic, vendorFailureEvidence: savedFailure, previousErrorCode: savedPreviousError, ...status } = record(row.vendor_status), quote = quoteJson(row.price_snapshot)
  const diagnostic = safeSubmissionDiagnostic(savedDiagnostic)
  const failureEvidence = safeVendorFailureEvidence(savedFailure)
  const fileFlags = vendorFileFlags(status)
  return { id: row.id, requestId: row.request_id, environment: 'development', productId: row.product_id, pageCount: row.page_count,
    orderNum: row.order_num, orderSeq: row.order_seq, orderCode: row.order_code, label: row.label, recipient: row.recipient,
    status: row.status, uploadId: row.upload_id, coverPath: row.cover_path, interiorPath: row.interior_path,
    sourceFingerprint: row.source_fingerprint, pdfManifest: row.pdf_manifest, price: quote.price,
    financialQuoteConfirmed: quote.financialQuoteConfirmed, developmentQuote: quote.developmentQuote,
    developmentPriceTotal: quote.developmentPriceTotal, priceError: quote.priceError, productionApproved: false,
    vendorResultId: row.vendor_result_id, vendorStatus: { ...status, ...fileFlags, ...(diagnostic ? { submissionDiagnostic: diagnostic } : {}),
      ...(failureEvidence ? { vendorFailureEvidence: failureEvidence } : {}),
      ...(vendorFailureErrorCodes.has(savedPreviousError) ? { previousErrorCode: savedPreviousError } : {}) },
    submissionDiagnostic: diagnostic, fileProcessYn: status.fileProcessYn ?? '',
    trackingNumber: status.trackingNumber ?? '', courier: status.courier ?? '',
    errorCode: row.error_code === 'vendor_file_processing_error' && fileFlags.fileWarning ? null : row.error_code,
    createdAt: row.created_at, updatedAt: row.updated_at, submittedAt: row.submitted_at, lastStatusAt: row.last_status_at,
    confirmedAt: row.confirmed_at, canceledAt: row.canceled_at }
}

type ReadinessItem = { id: string; label: string; status: 'ready' | 'missing' | 'unconfirmed'; reason: string }
function exactCount(result: { data: unknown; error: unknown; count: number | null }) {
  check(result)
  if (!Number.isSafeInteger(result.count) || Number(result.count) < 0) throw new RedprintingError('redprinting_database_unavailable', 503)
  return Number(result.count)
}
function releaseReadiness(mappings: ReturnType<typeof mappingJson>[], tests: Record<string, any>[], counts: {
  uncertainSubmissionCount: number; preRegistrationHoldCount: number;
}) {
  const developmentReadySpecCount = mappings.filter(row => row.verified).length
  const financialQuotesConfirmedCount = mappings.filter(row => row.verified && row.financialQuoteConfirmed).length
  const statusVerified = counts.uncertainSubmissionCount === 0 && counts.preRegistrationHoldCount === 0 && tests.some(row =>
    (row.vendor_result_id || row.last_status_at) && ['ACCEPTED', 'CONFIRMED'].includes(row.status) &&
    record(row.vendor_status).fileProcessYn === 'Y' && text(record(row.vendor_status).statusCode).length > 0 && !hasVendorFileError(row.vendor_status))
  // These capabilities describe this deployed implementation. Development
  // acknowledgements, saved prices, or request flags cannot enable commercial
  // orders. Contracts and physical sample approval have no recorded evidence
  // here, so they remain unknown rather than being reported as rejected.
  const items: ReadinessItem[] = [
    { id: 'customer_payment', label: '고객 주문·결제', status: 'missing', reason: '새 고객 주문과 실물 결제 경로가 비활성 상태입니다.' },
    { id: 'production_api', label: '운영 API·운영 키 연결', status: 'missing', reason: '이 서버는 개발 키만 사용합니다. 실제 제작 주문을 보내는 운영 연결은 없습니다.' },
    { id: 'business_contract', label: '기업회원·정식 계약', status: 'unconfirmed', reason: '기업회원 전환과 정식 계약 완료를 확인한 기록이 앱에 없습니다.' },
    { id: 'approved_specs', label: '승인 사양 연결', status: developmentReadySpecCount > 0 ? 'ready' : 'missing',
      reason: `310개 중 ${developmentReadySpecCount}개 조합이 개발용으로 연결되었습니다. 연결된 사양만 테스트할 수 있습니다.` },
    { id: 'supplier_cost', label: '실제 제작 원가', status: developmentReadySpecCount > 0 && financialQuotesConfirmedCount === developmentReadySpecCount ? 'ready' : 'unconfirmed',
      reason: `${developmentReadySpecCount}개 연결 사양 중 양수 견적 확인 ${financialQuotesConfirmedCount}개. 개발 응답의 0원은 실제 원가로 사용하지 않습니다.` },
    { id: 'development_receipt', label: '개발 접수·상태 검증', status: statusVerified ? 'ready' : 'unconfirmed',
      reason: counts.uncertainSubmissionCount || counts.preRegistrationHoldCount
        ? `접수 불확정 ${counts.uncertainSubmissionCount}건 · 사전 등록 확인 보류 ${counts.preRegistrationHoldCount}건. 추가 접수와 제작 시작은 보류합니다.`
        : statusVerified ? '개발 주문의 상태 응답과 파일 처리 완료를 확인했습니다. 실물 제작 승인은 별도입니다.'
          : '개발 주문의 정상 상태 응답과 파일 처리 완료를 아직 확인하지 못했습니다.' },
    { id: 'automatic_pdf', label: 'PDF 자동 생성 실행 환경', status: 'unconfirmed', reason: '자동 PDF 생성 기능은 준비되어 있습니다. 상시 제작 서버의 준비 상태는 실제 판매 준비 화면에서 확인합니다.' },
    { id: 'customer_fulfillment', label: '고객 주문 자동 발주 운영 준비', status: 'unconfirmed', reason: '개발 테스트와 고객 주문은 별도로 관리합니다. 운영 승인과 제작 서버가 준비되면 자동 접수·예치금 처리를 사용할 수 있습니다.' },
    { id: 'automatic_tracking', label: '주문 상태·운송장 자동 반영 실행 환경', status: 'unconfirmed', reason: '자동 반영 기능은 준비되어 있습니다. 이 개발 메뉴에서는 수동 조회하며, 상시 제작 서버 상태는 실제 판매 준비 화면에서 확인합니다.' },
    { id: 'physical_sample', label: '실물·포장·발송 표시 검수', status: 'unconfirmed', reason: '도면·색상·제본과 스냅핏 발송 표시를 확인한 실물 샘플 검수 기록이 앱에 없습니다.' },
  ]
  return { schemaVersion: 1, checkedAt: now(), ready: false, canAcceptCustomerOrders: false,
    developmentReadySpecCount, totalSpecCount: 310, financialQuotesConfirmedCount, ...counts, items }
}

export class RedprintingAdmin {
  private vendor: RedprintingClient
  constructor(private db: Db, private config: RedprintingEnvironment, private actor: string | null,
    options: { vendor?: RedprintingClient; inspectPdf?: PdfInspector } = {}) {
    this.vendor = options.vendor ?? new RedprintingClient(config, { acquire: () => this.acquireSlot() })
    this.inspectPdf = options.inspectPdf
  }
  private inspectPdf?: PdfInspector
  private async acquireSlot() {
    const owner = crypto.randomUUID(), start = Date.now()
    while (true) {
      const waitMs = check<number>(await this.db.rpc('redprinting_dev_acquire_slot', { p_owner: owner }))
      if (waitMs === 0) break
      if (!Number.isFinite(waitMs) || waitMs < 0 || Date.now() - start > 10000) throw new RedprintingError('vendor_api_busy', 429)
      await pause(Math.min(waitMs, 1200))
    }
    return async () => { check(await this.db.rpc('redprinting_dev_release_slot', { p_owner: owner })) }
  }
  private async settings() {
    const row = check<any>(await this.db.from('redprinting_dev_settings').select('*').eq('id', 1).single())
    return settingsFromRow(row)
  }
  private async test(id: string) {
    const row = check<any>(await this.db.from('redprinting_dev_tests').select('*').eq('id', id).maybeSingle())
    if (!row) throw new RedprintingError('test_not_found', 404)
    if (row.environment !== 'development') throw new RedprintingError('live_environment_not_supported', 503)
    return row
  }
  private async updateTest(id: string, patch: Record<string, any>) {
    return check<any>(await this.db.from('redprinting_dev_tests').update({ ...patch, updated_at: now() }).eq('id', id).select('*').single())
  }
  private async withTest<T>(id: string, work: (row: Record<string, any>) => Promise<T>) {
    const owner = crypto.randomUUID()
    if (check(await this.db.rpc('redprinting_dev_acquire_test', { p_id: id, p_owner: owner })) !== true) throw new RedprintingError('test_operation_in_progress', 409)
    try { return await work(await this.test(id)) }
    finally { check(await this.db.rpc('redprinting_dev_release_test', { p_id: id, p_owner: owner })) }
  }
  private async saveCode(code: VendorCode) {
    check(await this.db.from('redprinting_dev_codes').upsert({ order_code: code.orderCode, goods_desc: code.goodsDesc,
      product_name: code.productName, work_size: code.workSize, cut_size: code.cutSize, use_yn: code.useYn, synced_at: now() }))
  }
  private async codeDetail(orderCode: string) {
    const detail = vendorCodeDetail(await this.vendor.call('/v1/code/detail', { order_code: orderCode }), orderCode)
    await this.saveCode(detail)
    let price: ReturnType<typeof vendorPrice> | null = null, priceError: string | null = null, developmentQuote: DevelopmentVendorQuote | null = null
    try {
      const checked = vendorDevelopmentQuote(await this.vendor.call('/v1/code/price', { order_code: orderCode, qty: 1 }), this.config)
      price = checked.price; priceError = checked.priceError; developmentQuote = checked.developmentQuote
    }
    catch (error) { if (!(error instanceof RedprintingError)) throw error; priceError = error.code }
    return { detail, price, priceError, approvalReady: detail.useYn === 'Y' && price?.orderYn === 'Y',
      developmentOrderReady: detail.useYn === 'Y' && price !== null,
      financialQuoteConfirmed: price !== null, developmentQuote,
      developmentPriceTotal: developmentQuote?.developmentPriceTotal ?? null, productionApproved: false }
  }
  private async mapping(productId: string, pageCount: number) {
    const row = check<any>(await this.db.from('redprinting_dev_mappings').select('*').eq('product_id', productId).eq('page_count', pageCount).maybeSingle())
    if (!row || !mappingJson(row).verified || !row.order_code) throw new RedprintingError('exact_order_code_approval_required')
    return row
  }
  private async signedFiles(row: Record<string, any>) {
    if (!row.upload_id || !row.cover_path || !row.interior_path || !record(row.pdf_manifest).validatedAt) throw new RedprintingError('test_pdf_validation_required')
    const expected = `${row.id}/${row.upload_id}`
    if (row.cover_path !== `${expected}/cover.pdf` || row.interior_path !== `${expected}/interior.pdf`) throw new RedprintingError('test_pdf_path_mismatch')
    const sign = async (path: string) => {
      const { data, error } = await this.db.storage.from(PRINT_BUCKET).createSignedUrl(path, 3600)
      if (error || !data?.signedUrl) throw new RedprintingError('test_pdf_signing_failed', 503)
      return data.signedUrl
    }
    return { cover: await sign(row.cover_path), interior: await sign(row.interior_path) }
  }
  private async statusPatch(row: Record<string, any>) {
    const status = await this.vendor.status(row.order_num, row.order_seq)
    const diagnostic = safeSubmissionDiagnostic(record(row.vendor_status).submissionDiagnostic)
    return this.updateTest(row.id, { vendor_status: { ...status, ...(diagnostic ? { submissionDiagnostic: diagnostic } : {}) }, last_status_at: now(), error_code: hasVendorFileError(status) ? 'vendor_file_processing_error' : null,
      ...(['SUBMITTING', 'UNKNOWN', 'REJECTED'].includes(row.status) ? { status: 'ACCEPTED' } : {}) })
  }
  private async holdPreRegistration(row: Record<string, any>): Promise<never> {
    // Redprinting's development portal can hold a pre-registration that the
    // production/status API still reports as 404. That response never proves
    // a previous submission is absent or safe to edit, cancel, or repeat.
    await this.updateTest(row.id, { last_status_at: now(), error_code: 'vendor_pre_registration_confirmation_required' })
    throw new RedprintingError('vendor_pre_registration_confirmation_required', 409)
  }
  async action(action: string, body: Record<string, any>) {
    if (action === 'overview') {
      const settingsRow = check<any>(await this.db.from('redprinting_dev_settings').select('*').eq('id', 1).single())
      const settings = settingsFromRow(settingsRow)
      const mappings = check<any[]>(await this.db.from('redprinting_dev_mappings').select('*').order('product_id').order('page_count'))
      const codes = check<any[]>(await this.db.from('redprinting_dev_codes').select('*').order('order_code'))
      const tests = check<any[]>(await this.db.from('redprinting_dev_tests').select('*').order('created_at', { ascending: false }).limit(50))
      // Count unresolved registrations across all history, not only the most
      // recent 50 rows displayed below. No supplier call or mutation is made.
      const [unknown, submitting, held] = await Promise.all([
        this.db.from('redprinting_dev_tests').select('id', { count: 'exact', head: true }).eq('status', 'UNKNOWN'),
        this.db.from('redprinting_dev_tests').select('id', { count: 'exact', head: true }).eq('status', 'SUBMITTING'),
        this.db.from('redprinting_dev_tests').select('id', { count: 'exact', head: true }).eq('error_code', 'vendor_pre_registration_confirmation_required'),
      ])
      const mapped = mappings.map(mappingJson)
      return { settings, credential: { configured: Boolean(this.config.apiKey && this.config.userId), userId: this.config.userId,
        expiresAt: this.config.expiresAt, environment: this.config.environment, enabled: this.config.enabled,
        expired: !this.config.expiresAt || Date.now() > Date.parse(`${this.config.expiresAt}T23:59:59+09:00`) },
        products: REDPRINTING_PRODUCTS, matrix: redprintingMatrix(), pdfLimits: REDPRINTING_PDF_LIMITS, codeSync: { syncedAt: settingsRow.codes_synced_at ?? null },
        mappings: mapped, codes: codes.map(row => ({ orderCode: row.order_code, goodsDesc: row.goods_desc,
          productName: row.product_name, workSize: row.work_size, cutSize: row.cut_size, useYn: row.use_yn, syncedAt: row.synced_at })), tests: tests.map(testJson),
        releaseReadiness: releaseReadiness(mapped, tests, { uncertainSubmissionCount: exactCount(unknown) + exactCount(submitting), preRegistrationHoldCount: exactCount(held) }),
        productionEnabled: false, pollGuidance: { intervalMinutes: 60, weekdaysOnly: true, startHour: 9, endHour: 18, timezone: 'Asia/Seoul', automatic: false } }
    }
    if (action === 'saveSettings') {
      const settings = validateSettings(body.settings ?? body, await this.settings())
      check(await this.db.from('redprinting_dev_settings').update({ ...settingsPatch(settings), updated_by: this.actor, updated_at: now() }).eq('id', 1))
      return { settings }
    }
    if (action === 'listTests') {
      const page = Number.isSafeInteger(body.page) && body.page >= 0 ? Math.min(body.page, 10000) : 0
      const size = Number.isSafeInteger(body.size) && body.size > 0 ? Math.min(body.size, 50) : 50
      const result = await this.db.from('redprinting_dev_tests').select('*', { count: 'exact' }).order('created_at', { ascending: false }).range(page * size, page * size + size - 1)
      return { items: check<any[]>(result).map(testJson), page, size, total: result.count }
    }
    if (action === 'getTest') return testJson(await this.test(testId(body.id)))
    if (action === 'getTestSnapshot') {
      const row = await this.test(testId(body.id)), spec = testPrintSpec(row.product_id, row.page_count)
      const sourceFingerprint = await sha256(new TextEncoder().encode(JSON.stringify({ id: row.id, productId: row.product_id, pageCount: row.page_count, specVersion: spec.specVersion })))
      return { id: row.id, productId: row.product_id, pageCount: row.page_count, spec, sourceFingerprint, productionApproved: false }
    }
    // Every vendor call is strictly development-only, even read-only lookups.
    assertDevelopment(this.config)
    if (action === 'syncCodes') {
      let codes: VendorCode[]
      try { codes = vendorCodeList(await this.vendor.call('/v1/code/list', {})) }
      catch (error) { if (!isMissing(error)) throw error; codes = [] }
      for (const code of codes) await this.saveCode(code)
      // Disappeared/disabled codes can never retain a previously verified map.
      const present = new Set(codes.filter(code => code.useYn === 'Y').map(code => code.orderCode))
      const mappings = check<any[]>(await this.db.from('redprinting_dev_mappings').select('*').not('order_code', 'is', null))
      for (const map of mappings) if (!present.has(map.order_code)) {
        check(await this.db.from('redprinting_dev_mappings').update({ vendor_use_yn: '', verified_at: null }).eq('product_id', map.product_id).eq('page_count', map.page_count))
      }
      const syncedAt = now()
      check(await this.db.from('redprinting_dev_settings').update({ codes_synced_at: syncedAt }).eq('id', 1))
      return { codes, count: codes.length, syncedAt }
    }
    if (action === 'codeDetail') return this.codeDetail(identifier(body.orderCode, 'order_code_required'))
    if (action === 'saveMapping') {
      const { productId, pageCount } = validateTestSpec(body.productId, body.pageCount)
      const orderCode = identifier(body.orderCode, 'order_code_required')
      const note = text(body.note, 1000)
      if (body.matchConfirmed !== true || note.length < 10) throw new RedprintingError('exact_spec_confirmation_required', 400)
      const checked = await this.codeDetail(orderCode)
      if (!checked.developmentOrderReady) throw new RedprintingError('vendor_order_code_not_approved')
      const updated = await this.db.from('redprinting_dev_mappings').update({ order_code: orderCode, exact_match_confirmed: true,
        vendor_use_yn: checked.detail.useYn, vendor_order_yn: checked.developmentQuote?.orderYn, detail_snapshot: checked.detail, price_snapshot: quoteSnapshot(checked),
        note, verified_at: now(), updated_at: now(), updated_by: this.actor,
      }).eq('product_id', productId).eq('page_count', pageCount).select('*').single()
      if (updated.error?.code === '23505') throw new RedprintingError('order_code_already_mapped_to_other_spec')
      return mappingJson(check<any>(updated))
    }
    if (action === 'clearMapping') {
      const { productId, pageCount } = validateTestSpec(body.productId, body.pageCount)
      const result = check<any>(await this.db.from('redprinting_dev_mappings').update({ order_code: null, exact_match_confirmed: false,
        vendor_use_yn: '', vendor_order_yn: '', verified_at: null, note: '', updated_at: now(), updated_by: this.actor,
      }).eq('product_id', productId).eq('page_count', pageCount).select('*').single())
      return mappingJson(result)
    }
    if (action === 'createTest') {
      const requestId = testId(body.requestId), spec = validateTestSpec(body.productId, body.pageCount), receiver = recipient(body.recipient)
      const existing = check<any>(await this.db.from('redprinting_dev_tests').select('*').eq('request_id', requestId).maybeSingle())
      const ensureSame = (row: Record<string, any>) => {
        if (row.product_id !== spec.productId || row.page_count !== spec.pageCount ||
          Object.entries(receiver).some(([key, value]) => row.recipient?.[key] !== value)) throw new RedprintingError('test_request_id_conflict')
        return testJson(row)
      }
      if (existing) return ensureSame(existing)
      const id = crypto.randomUUID(), orderNum = `SFD${crypto.randomUUID().replaceAll('-', '')}`
      const inserted = await this.db.from('redprinting_dev_tests').insert({ id, request_id: requestId, product_id: spec.productId, page_count: spec.pageCount,
        order_num: orderNum, order_seq: 1, label: text(body.label, 100), recipient: receiver, created_by: this.actor }).select('*').single()
      if (inserted.error?.code === '23505') {
        const raced = check<any>(await this.db.from('redprinting_dev_tests').select('*').eq('request_id', requestId).single())
        return ensureSame(raced)
      }
      return testJson(check<any>(inserted))
    }
    const id = testId(body.id)
    return this.withTest(id, async row => {
      if (action === 'getTestDownloadLinks') {
        if (Object.keys(body).some(key => !['action', 'id'].includes(key))) throw new RedprintingError('invalid_body', 400)
        const manifest = record(row.pdf_manifest), spec = testPrintSpec(row.product_id, row.page_count)
        if (!row.upload_id || !manifest.validatedAt || manifest.specVersion !== spec.specVersion || manifest.productionApproved !== false ||
            row.cover_path !== `${row.id}/${row.upload_id}/cover.pdf` || row.interior_path !== `${row.id}/${row.upload_id}/interior.pdf`) {
          throw new RedprintingError('test_pdf_validation_required', 409)
        }
        const results: Record<string, unknown> = {}
        for (const kind of ['cover', 'interior']) {
          const stored = record(manifest[kind]), path = String(row[kind === 'cover' ? 'cover_path' : 'interior_path'])
          const file = check<any>(await this.db.storage.from(PRINT_BUCKET).download(path), 'test_pdf_upload_missing')
          if (!file || !Number.isSafeInteger(file.size) || file.size < 1 || file.size > REDPRINTING_PDF_LIMITS.upload ||
              file.size !== stored.byteLength || typeof stored.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(stored.sha256)) {
            throw new RedprintingError('test_pdf_preflight_failed', 409)
          }
          const bytes = new Uint8Array(await file.arrayBuffer())
          const checked = kind === 'cover'
            ? await validatePrintPdf(bytes, 1, spec.cover.widthMm, spec.cover.heightMm, this.inspectPdf, coverTrim(spec))
            : await validatePrintPdf(bytes, row.page_count, spec.interior.trimWidthMm + 2 * spec.interior.bleedMm,
                spec.interior.trimHeightMm + 2 * spec.interior.bleedMm, this.inspectPdf)
          if (checked.sha256 !== stored.sha256) throw new RedprintingError('test_pdf_preflight_failed', 409)
          const signed = check<any>(await this.db.storage.from(PRINT_BUCKET).createSignedUrl(path, 900), 'test_pdf_signing_failed')
          if (typeof signed?.signedUrl !== 'string') throw new RedprintingError('test_pdf_signing_failed', 503)
          results[kind] = { url: signed.signedUrl, bytes: checked.byteLength, sha256: checked.sha256 }
        }
        return { id: row.id, productId: row.product_id, pageCount: row.page_count, ...results,
          expiresAt: new Date(Date.now() + 900000).toISOString(), productionApproved: false }
      }
      if (action === 'recordVendorFailure') {
        const evidence = failureEvidenceInput(body.evidence, row)
        const previous = safeVendorFailureEvidence(record(row.vendor_status).vendorFailureEvidence)
        if (vendorFailureLocked(row)) {
          if (previous && ['reason', 'sourceType', 'reference', 'confirmedAt'].every(key => previous[key as keyof VendorFailureEvidence] === evidence[key as keyof typeof evidence])) return testJson(row)
          throw new RedprintingError('vendor_failure_evidence_conflict', 409)
        }
        const vendorStatus = record(row.vendor_status)
        if (!['UNKNOWN', 'REJECTED'].includes(row.status) || !row.submitted_at || row.confirmed_at || row.canceled_at || row.vendor_result_id ||
          vendorStatus.fileProcessYn === 'Y' || ['statusCode', 'statusName', 'statusCodeOrg', 'trackingNumber'].some(key =>
            vendorStatus[key] != null && vendorStatus[key] !== '') || !vendorFailureErrorCodes.has(row.error_code)) {
          throw new RedprintingError('vendor_failure_record_not_allowed', 409)
        }
        // Explicit supplier correspondence resolves this attempt only. It
        // never proves cancellation or authorizes reuse of this order number.
        return testJson(await this.updateTest(id, { status: 'REJECTED', error_code: 'vendor_pricing_failure_confirmed',
          vendor_status: { ...record(row.vendor_status), previousErrorCode: row.error_code,
            vendorFailureEvidence: { ...evidence, recordedAt: now(), recordedBy: this.actor } } }))
      }
      if (vendorFailureLocked(row)) throw new RedprintingError('vendor_failure_order_locked', 409)
      if (action === 'updateTestRecipient') {
        if (row.confirmed_at || row.canceled_at || !['DRAFT', 'FILES_READY', 'REJECTED', 'UNKNOWN'].includes(row.status)) {
          throw new RedprintingError('test_recipient_edit_not_allowed')
        }
        const nextRecipient = recipient(body.recipient)
        if (hasSubmissionHistory(row)) {
          // A status 404 cannot exclude development portal pre-registration.
          try { await this.vendor.status(row.order_num, row.order_seq) }
          catch (error) { if (!isMissing(error)) throw error; return this.holdPreRegistration(row) }
          throw new RedprintingError('test_recipient_edit_not_allowed')
        }
        return testJson(await this.updateTest(id, { recipient: nextRecipient }))
      }
      if (action === 'createTestUploads') {
        if (!['DRAFT', 'FILES_READY', 'REJECTED', 'ACCEPTED'].includes(row.status)) throw new RedprintingError('test_upload_not_allowed')
        if (row.confirmed_at || row.canceled_at) throw new RedprintingError('test_upload_not_allowed')
        if (row.status === 'ACCEPTED') {
          row = await this.statusPatch(row)
          if (!hasVendorFileError(row.vendor_status)) throw new RedprintingError('vendor_file_error_required')
        }
        const bucket = await this.db.storage.getBucket(PRINT_BUCKET)
        if (bucket.error || bucket.data?.public !== false) throw new RedprintingError('private_print_bucket_required', 503)
        const uploadId = crypto.randomUUID(), base = `${id}/${uploadId}`
        const create = async (name: string) => {
          const path = `${base}/${name}.pdf`, result = await this.db.storage.from(PRINT_BUCKET).createSignedUploadUrl(path, { upsert: false })
          if (result.error || !result.data?.signedUrl) throw new RedprintingError('test_upload_creation_failed', 503)
          return { path, signedUrl: result.data.signedUrl, token: result.data.token }
        }
        const cover = await create('cover'), interior = await create('interior')
        const previous = record(row.pdf_manifest)
        const previousVersions = Array.isArray(previous.previousVersions) ? previous.previousVersions.slice(-4) : []
        if (previous.validatedAt && row.cover_path && row.interior_path) previousVersions.push({
          uploadId: row.upload_id, coverPath: row.cover_path, interiorPath: row.interior_path,
          validatedAt: previous.validatedAt, cover: previous.cover, interior: previous.interior,
          replacedAt: now(),
        })
        await this.updateTest(id, { upload_id: uploadId, cover_path: null, interior_path: null, pdf_manifest: previousVersions.length ? { previousVersions } : {},
          ...(row.status === 'FILES_READY' ? { status: 'DRAFT' } : {}) })
        return { id, uploadId, bucket: PRINT_BUCKET, cover, interior }
      }
      if (action === 'finalizeTestFiles') {
        if (testId(body.uploadId) !== row.upload_id || row.confirmed_at || row.canceled_at || ['SUBMITTING', 'UNKNOWN'].includes(row.status)) throw new RedprintingError('test_upload_expired')
        const snapshot = await this.action('getTestSnapshot', { id }) as any, spec = snapshot.spec, report = record(body.report)
        if (report.iccProfileEmbedded !== true || report.colorSpace !== 'sRGB' || report.dpi !== 300 ||
          report.sourceFingerprint !== snapshot.sourceFingerprint || report.specVersion !== spec.specVersion ||
          !Array.isArray(report.missingAssets) || report.missingAssets.length || !Array.isArray(report.warnings)) throw new RedprintingError('test_pdf_preflight_failed')
        const read = async (name: string) => {
          const path = `${id}/${row.upload_id}/${name}.pdf`, file = await this.db.storage.from(PRINT_BUCKET).download(path)
          if (file.error || !file.data) throw new RedprintingError('test_pdf_upload_missing')
          if (file.data.size > REDPRINTING_PDF_LIMITS.upload) throw new RedprintingError('test_pdf_exceeds_edge_limit', 413)
          return new Uint8Array(await file.data.arrayBuffer())
        }
        const cover = await validatePrintPdf(await read('cover'), 1, spec.cover.widthMm, spec.cover.heightMm, this.inspectPdf, coverTrim(spec))
        const interior = await validatePrintPdf(await read('interior'), row.page_count,
          spec.interior.trimWidthMm + 2 * spec.interior.bleedMm, spec.interior.trimHeightMm + 2 * spec.interior.bleedMm, this.inspectPdf)
        return testJson(await this.updateTest(id, { cover_path: `${id}/${row.upload_id}/cover.pdf`, interior_path: `${id}/${row.upload_id}/interior.pdf`,
          source_fingerprint: snapshot.sourceFingerprint, pdf_manifest: { cover, interior, specVersion: spec.specVersion, validatedAt: now(), colorSpace: 'sRGB',
            previousVersions: record(row.pdf_manifest).previousVersions ?? [],
            productionApproved: false, geometryMeasured: spec.geometryMeasured ?? false }, error_code: null,
          ...(row.status === 'DRAFT' || row.status === 'REJECTED' ? { status: 'FILES_READY' } : {}) }))
      }
      if (action === 'refreshTest') {
        try { return testJson(await this.statusPatch(row)) }
        catch (error) {
          if (isMissing(error)) {
            if (hasSubmissionHistory(row)) return this.holdPreRegistration(row)
            return testJson(await this.updateTest(id, { last_status_at: now(), error_code: 'vendor_order_not_found' }))
          }
          throw error
        }
      }
      if (action === 'submitTest') {
        if (row.confirmed_at || row.canceled_at) throw new RedprintingError('test_submission_not_allowed')
        if (['ACCEPTED', 'CONFIRMED'].includes(row.status)) return testJson(row)
        // Once any call could have reached Redprinting, status comes first.
        // Even an explicit 404 can coexist with development pre-registration.
        if (hasSubmissionHistory(row)) {
          try { return testJson(await this.statusPatch(row)) }
          catch (error) { if (!isMissing(error)) throw error; return this.holdPreRegistration(row) }
        }
        const settings = await this.settings(); assertReadySettings(settings)
        vendorTestRecipient(row.recipient)
        const mapping = await this.mapping(row.product_id, row.page_count)
        const detail = await this.codeDetail(mapping.order_code)
        if (!detail.developmentOrderReady) throw new RedprintingError('vendor_order_code_not_approved')
        if (row.order_code && row.order_code !== mapping.order_code) throw new RedprintingError('submitted_order_code_change_not_allowed')
        const files = await this.signedFiles(row)
        row = await this.updateTest(id, { status: 'SUBMITTING', order_code: mapping.order_code, price_snapshot: quoteSnapshot(detail),
          settings_snapshot: settings, submitted_at: row.submitted_at ?? now(), error_code: null })
        try {
          const response = await this.vendor.call('/v1/code/order', testOrderPayload(row, settings, files))
          const acceptance = orderAcceptance(response, row.order_num, row.order_seq)
          row = await this.updateTest(id, { status: acceptance.accepted ? 'ACCEPTED' : acceptance.knownRejected ? 'REJECTED' : 'UNKNOWN',
            vendor_status: { ...record(row.vendor_status), submissionDiagnostic: submissionDiagnostic(response, row.order_num, row.order_seq) },
            vendor_result_id: acceptance.resultId, error_code: acceptance.accepted ? null : acceptance.knownRejected ? 'vendor_order_rejected' : 'vendor_order_response_uncertain' })
          if (acceptance.acknowledged) {
            // Summary-only acknowledgement is now documented. Verify this
            // exact order before reporting receipt; never create a result ID.
            try { return testJson(await this.statusPatch(row)) }
            catch (error) {
              if (!isMissing(error)) throw error
              return testJson(await this.updateTest(id, { last_status_at: now(), error_code: 'vendor_pre_registration_confirmation_required' }))
            }
          }
          return testJson(row)
        } catch (error) {
          // A duplicate 400 can follow a lost successful response. Preserve the
          // identity and force status lookup even after a deterministic error.
          const code = error instanceof RedprintingError ? error.code : 'vendor_order_response_uncertain'
          return testJson(await this.updateTest(id, { status: 'UNKNOWN', error_code: code }))
        }
      }
      if (action === 'cancelTest') {
        if (row.confirmed_at || row.status === 'CONFIRMED') throw new RedprintingError('test_already_confirmed')
        if (row.status === 'CANCELED') return testJson(row)
        if (!hasSubmissionHistory(row) && ['DRAFT', 'FILES_READY'].includes(row.status)) return testJson(await this.updateTest(id, { status: 'CANCELED', canceled_at: now(), error_code: null }))
        // A known accepted order must exist before cancellation can be trusted.
        try { row = await this.statusPatch(row) }
        catch (error) {
          if (isMissing(error)) return this.holdPreRegistration(row)
          throw error
        }
        const response = record(await this.vendor.call('/v1/code/order-cancel', { order_num: row.order_num, order_seq: row.order_seq }))
        if (response.success !== true) throw new RedprintingError('vendor_cancel_not_confirmed', 502)
        return testJson(await this.updateTest(id, { status: 'CANCELED', canceled_at: now(), error_code: null }))
      }
      if (action === 'confirmTest') {
        const settings = await this.settings(); assertReadySettings(settings)
        if (!settings.testDepositEnabled || body.confirm !== true) throw new RedprintingError('development_confirmation_disabled')
        if (row.status === 'CONFIRMED') return testJson(row)
        if (row.status === 'CANCELED' || !row.submitted_at) throw new RedprintingError('test_confirmation_not_allowed')
        row = await this.statusPatch(row)
        if (hasVendorFileError(row.vendor_status)) throw new RedprintingError('vendor_file_processing_error')
        if (record(row.vendor_status).fileProcessYn !== 'Y') throw new RedprintingError('vendor_file_processing_incomplete')
        const response = record(await this.vendor.call('/v1/code/order-deposit', { order_num: row.order_num }))
        if (response.success !== true) throw new RedprintingError('vendor_confirmation_not_confirmed', 502)
        return testJson(await this.updateTest(id, { status: 'CONFIRMED', confirmed_at: now(), error_code: null }))
      }
      if (action === 'reuploadTest') {
        if (row.confirmed_at || row.canceled_at || row.status !== 'ACCEPTED') throw new RedprintingError('test_reupload_not_allowed')
        row = await this.statusPatch(row)
        if (!hasVendorFileError(row.vendor_status)) throw new RedprintingError('vendor_file_error_required')
        const files = await this.signedFiles(row)
        const response = record(await this.vendor.call('/v1/code/file-reupload', { order_num: row.order_num, order_seq: row.order_seq, file_url1: files.cover, file_url2: files.interior }))
        if (response.success !== true) throw new RedprintingError('vendor_reupload_not_confirmed', 502)
        return testJson(await this.updateTest(id, { vendor_status: {}, last_status_at: null, error_code: null }))
      }
      throw new RedprintingError('unknown_action', 400)
    })
  }
}

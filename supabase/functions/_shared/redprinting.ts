import { PRINT_PRODUCTS, PRINT_COVER_PRICING_VERSION, getPrintSpec, type PrintRect } from './print-contract.ts'
import type { OrderRow } from './order-types.ts'

export class RedprintingError extends Error {
  constructor(public code: string, public status = 409, public uncertain = false, public vendorStatus = 0) { super(code) }
}

export type RedprintingEnvironment = { environment: string; enabled: boolean; userId: string; apiKey: string; expiresAt: string }
export type RedprintingSettings = {
  senderName: string; senderTel: string; senderZipcode: string; senderAddress: string; senderAddressDetail: string;
  colorMode: 'UNCONFIRMED' | 'RGB' | 'CMYK'; colorApprovalNote: string; colorApprovedAt: string | null;
  testDepositEnabled: boolean; developmentRgbTestAcknowledged: boolean; developmentGeometryTestAcknowledged: boolean;
}

export const REDPRINTING_API_ORIGIN = 'https://redapi.redprinting.net'
export const REDPRINTING_PDF_LIMITS = { vendorCover: 150 * 1024 * 1024, vendorInterior: 500 * 1024 * 1024, upload: 100 * 1024 * 1024 }
export const REDPRINTING_PRODUCTS = Object.entries(PRINT_PRODUCTS).map(([productId, product]) => ({
  productId, ...product, coverType: productId.endsWith('_HARD') ? 'HARD' : 'SOFT',
}))
export const redprintingMatrix = () => REDPRINTING_PRODUCTS.flatMap(product => Array.from({ length: 31 }, (_, index) => ({
  productId: product.productId, pageCount: 20 + index * 2, widthMm: product.trimWidthMm, heightMm: product.trimHeightMm,
  coverType: product.coverType, productName: product.productName,
})))

export function record(value: unknown): Record<string, any> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {}
}
export function text(value: unknown, max = 300) { return typeof value === 'string' ? value.trim().slice(0, max) : '' }
export function identifier(value: unknown, code = 'invalid_identifier') {
  const id = text(value, 120)
  if (!/^[A-Za-z0-9_-]{1,100}$/.test(id)) throw new RedprintingError(code, 400)
  return id
}
export function testId(value: unknown) {
  const id = text(value, 80)
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) throw new RedprintingError('invalid_test_id', 400)
  return id
}
export function validateTestSpec(productId: unknown, pageCount: unknown) {
  const product = PRINT_PRODUCTS[String(productId) as keyof typeof PRINT_PRODUCTS]
  if (!product || !Number.isSafeInteger(pageCount) || Number(pageCount) < 20 || Number(pageCount) > 80 || Number(pageCount) % 2) {
    throw new RedprintingError('invalid_test_spec', 400)
  }
  return { productId: product.id, pageCount: Number(pageCount), product }
}

export function testPrintSpec(productId: unknown, pageCount: unknown) {
  const { product, pageCount: pages } = validateTestSpec(productId, pageCount)
  // Reuse the exact renderer profile used by the app. This document is a QA
  // fixture, never a fabricated payment or a customer order.
  const doc = { printProduct: product, pages: Array.from({ length: pages + 1 }, (_, i) => ({ index: i, isCover: i === 0 })) }
  return getPrintSpec({ pricing_version: PRINT_COVER_PRICING_VERSION, page_count: pages, print_product_snapshot: product,
    print_content_snapshot: { printProduct: product, album: { ratio: `${product.trimWidthMm}:${product.trimHeightMm}`, cover_layers_json: doc }, pages: [] },
  } as unknown as OrderRow)
}

export function assertDevelopment(config: RedprintingEnvironment, now = Date.now()) {
  if (config.environment !== 'development') throw new RedprintingError('live_environment_not_supported', 503)
  if (!config.enabled) throw new RedprintingError('redprinting_test_disabled', 503)
  if (!config.apiKey || !/^[A-Za-z0-9_-]{1,100}$/.test(config.userId)) throw new RedprintingError('redprinting_credentials_missing', 503)
  if (!/^\d{4}-\d{2}-\d{2}$/.test(config.expiresAt)) throw new RedprintingError('redprinting_key_expiry_missing', 503)
  const expiry = Date.parse(`${config.expiresAt}T23:59:59+09:00`)
  if (!Number.isFinite(expiry) || now > expiry) throw new RedprintingError('redprinting_development_key_expired', 503)
}

function phone(value: unknown) { const v = text(value, 30); return /^[0-9+() -]{8,30}$/.test(v) ? v : '' }
function zipcode(value: unknown) { const v = text(value, 10); return /^\d{5}$/.test(v) ? v : '' }
export function validateSettings(value: unknown, previous?: RedprintingSettings, now = new Date().toISOString()): RedprintingSettings {
  const raw = record(value)
  const senderName = text(raw.senderName, 50) || '스냅핏'
  if (senderName !== '스냅핏') throw new RedprintingError('sender_brand_must_be_snapfit', 400)
  const colorMode = String(raw.colorMode ?? 'UNCONFIRMED')
  if (!['UNCONFIRMED', 'RGB', 'CMYK'].includes(colorMode)) throw new RedprintingError('invalid_color_mode', 400)
  const colorApprovalNote = text(raw.colorApprovalNote, 1000)
  if (colorMode !== 'UNCONFIRMED' && colorApprovalNote.length < 10) throw new RedprintingError('vendor_color_approval_note_required', 400)
  const sameApproval = previous?.colorMode === colorMode && previous?.colorApprovalNote === colorApprovalNote
  return { senderName, senderTel: phone(raw.senderTel), senderZipcode: zipcode(raw.senderZipcode),
    senderAddress: text(raw.senderAddress, 300), senderAddressDetail: text(raw.senderAddressDetail, 150),
    colorMode: colorMode as RedprintingSettings['colorMode'], colorApprovalNote,
    colorApprovedAt: colorMode === 'UNCONFIRMED' ? null : sameApproval ? previous?.colorApprovedAt ?? now : now,
    testDepositEnabled: raw.testDepositEnabled === true,
    developmentRgbTestAcknowledged: raw.developmentRgbTestAcknowledged === true,
    developmentGeometryTestAcknowledged: raw.developmentGeometryTestAcknowledged === true,
  }
}

export function assertReadySettings(settings: RedprintingSettings) {
  if (settings.senderName !== '스냅핏' || !phone(settings.senderTel) || !zipcode(settings.senderZipcode) ||
    !settings.senderAddress || !settings.senderAddressDetail) throw new RedprintingError('sender_details_required')
  if (settings.colorMode === 'UNCONFIRMED' && !settings.developmentRgbTestAcknowledged) throw new RedprintingError('development_rgb_test_acknowledgment_required')
  // The existing 300dpi renderer embeds sRGB. Selecting CMYK cannot turn its
  // bytes into a CMYK file or bypass the server's PDF inspection.
  if (settings.colorMode === 'CMYK') throw new RedprintingError('cmyk_renderer_not_supported')
  if (!settings.developmentGeometryTestAcknowledged) throw new RedprintingError('development_geometry_test_acknowledgment_required')
}

export function recipient(value: unknown) {
  const raw = record(value)
  const result = { name: text(raw.name, 50), tel: phone(raw.tel), zipcode: zipcode(raw.zipcode),
    address: text(raw.address, 300), addressDetail: text(raw.addressDetail, 150), message: text(raw.message, 100) }
  if (!result.name || !result.tel || !result.zipcode || !result.address || !result.addressDetail) throw new RedprintingError('test_recipient_required', 400)
  return result
}
export function vendorTestRecipient(value: unknown) {
  const result = recipient(value)
  // PDF-only fixtures may use this placeholder. It cannot be sent as a
  // supplier delivery address, even with a non-production development key.
  if (result.zipcode === '00000') throw new RedprintingError('test_vendor_recipient_required', 400)
  return result
}

export type VendorCode = { orderCode: string; goodsDesc: string; productName: string; workSize: string; cutSize: string; useYn: string }
export function normalizeCode(value: unknown): VendorCode {
  const raw = record(value)
  return { orderCode: identifier(raw.order_code, 'invalid_vendor_order_code'), goodsDesc: text(raw.goods_desc, 1500),
    productName: text(raw.product_name, 300), workSize: text(raw.work_size, 150), cutSize: text(raw.cut_size, 150), useYn: text(raw.use_yn, 1) }
}
export function vendorCodeList(value: unknown) {
  const raw = record(value)
  if (raw.success !== true) throw new RedprintingError('vendor_codes_unavailable', 502)
  const rows = Array.isArray(raw.data) ? raw.data : Array.isArray(raw.order_code_list) ? raw.order_code_list :
    Array.isArray(raw.code_list) ? raw.code_list : Array.isArray(raw.order_codes) ? raw.order_codes : null
  if (!rows) throw new RedprintingError('vendor_codes_response_invalid', 502)
  return rows.map(normalizeCode)
}
export function vendorCodeDetail(value: unknown, orderCode: string) {
  const raw = record(value)
  if (raw.success !== true) throw new RedprintingError('vendor_code_detail_unavailable', 502)
  const data = Array.isArray(raw.data) ? raw.data[0] : raw.data ?? raw.code_info ?? raw
  const normalized = normalizeCode({ ...record(data), order_code: record(data).order_code ?? orderCode })
  if (normalized.orderCode !== orderCode) throw new RedprintingError('vendor_code_identity_mismatch', 502)
  return normalized
}
export function vendorPrice(value: unknown) {
  const raw = record(value), price = record(raw.priceInfo)
  const amount = (value: unknown) => (typeof value === 'number' || typeof value === 'string' && value.trim() !== '') &&
    Number.isFinite(Number(value)) && Number(value) >= 0
  if (raw.success !== true || !['Y', true].includes(raw.orderYn) ||
    !['supplyPrice', 'vatPrice', 'totalPrice'].every(key => amount(price[key])) ||
    Number(price.totalPrice) <= 0) throw new RedprintingError('vendor_order_code_not_approved')
  return { supplyPrice: Number(price.supplyPrice), vatPrice: Number(price.vatPrice), totalPrice: Number(price.totalPrice), orderYn: 'Y' }
}

export type DevelopmentVendorQuote = {
  environment: 'development'; developmentOnly: true; responseSuccess: true; orderYn: 'Y'; qty: 1;
  quantityConfirmed: boolean; developmentPriceTotal: number; financialQuoteConfirmed: boolean;
}
export function vendorDevelopmentQuote(value: unknown, config: RedprintingEnvironment) {
  // Redprinting confirmed that zero/missing financial quotes came from a
  // pricing failure, not a supported simulated-order price. Both test orders
  // and real cost display require a complete positive quote.
  assertDevelopment(config)
  const raw = record(value), info = record(raw.priceInfo)
  const amount = (value: unknown) => (typeof value === 'number' || typeof value === 'string' && value.trim() !== '') &&
    Number.isFinite(Number(value)) && Number(value) >= 0
  if (raw.success !== true || !['Y', true].includes(raw.orderYn)) throw new RedprintingError('vendor_order_code_not_approved')
  if (!amount(info.totalPrice) || ['supplyPrice', 'vatPrice'].some(key => Object.hasOwn(info, key) && !amount(info[key]))) {
    throw new RedprintingError('vendor_development_quote_invalid')
  }
  const quantityConfirmed = Object.hasOwn(info, 'qty')
  if (quantityConfirmed && (!amount(info.qty) || Number(info.qty) !== 1)) throw new RedprintingError('vendor_development_quote_quantity_mismatch')
  let price: ReturnType<typeof vendorPrice>
  try { price = vendorPrice(value) }
  catch (error) { if (!(error instanceof RedprintingError)) throw error; throw new RedprintingError('vendor_financial_quote_unconfirmed') }
  // Requests always use qty=1. Older complete positive quotes did not echo it;
  // if the supplier echoes quantity, it must match that one-copy request.
  const developmentQuote: DevelopmentVendorQuote = { environment: 'development', developmentOnly: true,
    responseSuccess: true, orderYn: 'Y', qty: 1, quantityConfirmed,
    developmentPriceTotal: Number(info.totalPrice), financialQuoteConfirmed: true }
  return { price, developmentQuote, priceError: null }
}

export function orderAcceptance(value: unknown, orderNum: string, orderSeq: number) {
  const raw = record(value)
  const rows = Array.isArray(raw.data) ? raw.data : []
  const item = rows.find((candidate: unknown) => { const row = record(candidate); return String(row.order_num) === orderNum && Number(row.order_seq) === orderSeq })
  const row = record(item)
  // The 2026-10-14 manual documents a summary-only success response. It
  // acknowledges the request, but receipt still needs a matching status GET.
  // Keep older per-item responses compatible without inventing a result ID.
  return { accepted: row.success === true, resultId: row.success === true ? text(String(row.result_id ?? ''), 100) : null,
    knownRejected: item != null && row.success === false,
    acknowledged: raw.success === true && ['data', 'order_data', 'result', 'results'].every(key => !Object.hasOwn(raw, key)) }
}

export type SubmissionFieldDiagnostic = {
  present: boolean; type: 'missing' | 'null' | 'array' | 'object' | 'other'; rowCount: number; matchingRowCount: number;
}
export type SubmissionDiagnostic = {
  schemaVersion: 1; topSuccess: boolean | null; messagePresent: boolean;
  fields: { data: SubmissionFieldDiagnostic; orderData: SubmissionFieldDiagnostic; result: SubmissionFieldDiagnostic; results: SubmissionFieldDiagnostic };
}
export function submissionDiagnostic(value: unknown, orderNum: string, orderSeq: number): SubmissionDiagnostic {
  const raw = record(value)
  const describe = (key: string): SubmissionFieldDiagnostic => {
    const present = Object.hasOwn(raw, key), field = raw[key], rows = Array.isArray(field) ? field : []
    return { present, type: !present ? 'missing' : field === null ? 'null' : Array.isArray(field) ? 'array' : typeof field === 'object' ? 'object' : 'other',
      rowCount: rows.length, matchingRowCount: rows.filter((item: unknown) => {
        const row = record(item)
        return (typeof row.order_num === 'string' || typeof row.order_num === 'number') && String(row.order_num) === orderNum &&
          (typeof row.order_seq === 'string' || typeof row.order_seq === 'number') && Number(row.order_seq) === orderSeq
      }).length }
  }
  // A supplier error may echo private input in message, keys, or nested fields.
  // Only this fixed schema of booleans/counts/enums may leave the response.
  return { schemaVersion: 1, topSuccess: typeof raw.success === 'boolean' ? raw.success : null,
    messagePresent: typeof raw.message === 'string' && raw.message.trim().length > 0,
    fields: { data: describe('data'), orderData: describe('order_data'), result: describe('result'), results: describe('results') } }
}

export function safeSubmissionDiagnostic(value: unknown): SubmissionDiagnostic | null {
  const raw = record(value), fields = record(raw.fields)
  if (raw.schemaVersion !== 1 || ![true, false, null].includes(raw.topSuccess) || typeof raw.messagePresent !== 'boolean') return null
  const pick = (key: string): SubmissionFieldDiagnostic | null => {
    const field = record(fields[key])
    if (typeof field.present !== 'boolean' || !['missing', 'null', 'array', 'object', 'other'].includes(field.type) ||
      !Number.isSafeInteger(field.rowCount) || field.rowCount < 0 || !Number.isSafeInteger(field.matchingRowCount) ||
      field.matchingRowCount < 0 || field.matchingRowCount > field.rowCount) return null
    return { present: field.present, type: field.type, rowCount: field.rowCount, matchingRowCount: field.matchingRowCount }
  }
  const data = pick('data'), orderData = pick('orderData'), result = pick('result'), results = pick('results')
  if (!data || !orderData || !result || !results) return null
  return { schemaVersion: 1, topSuccess: raw.topSuccess, messagePresent: raw.messagePresent, fields: { data, orderData, result, results } }
}

export function hasVendorFileError(value: unknown) {
  const status = record(value)
  const original = text(status.statusCodeOrg, 50)
  const detailPresent = status.fileErrorDetailPresent === true ||
    typeof status.fileErrorSummary === 'string' && status.fileErrorSummary.trim().length > 0 ||
    Boolean(status.file_error_log && String(status.file_error_log).trim())
  // Supplier clarification: original PGS_05 is an internal inspection warning;
  // original PGS_06 is production-blocking. Old fileError=true was derived from
  // the grouped API code, so it cannot override a known PGS_05 with no detail.
  if (original === 'PGS_06' || detailPresent) return true
  if (original === 'PGS_05') return false
  return status.fileError === true || ['PGS_05', 'PGS_06'].includes(text(status.statusCode, 50))
}

export function hasVendorFileWarning(value: unknown) {
  return text(record(value).statusCodeOrg, 50) === 'PGS_05' && !hasVendorFileError(value)
}

export function vendorFileFlags(value: unknown) {
  const status = record(value), fileError = hasVendorFileError(status), fileWarning = hasVendorFileWarning(status)
  return { fileError, fileErrorSummary: fileError ? vendorFileErrorSummary(status.fileErrorSummary) : '', fileWarning,
    fileWarningSummary: fileWarning ? '업체 내부 파일검사 주의 상태입니다. 별도 수정 요청이 없으며 파일 분석 완료 후 주문을 확정할 수 있습니다.' : '' }
}

function vendorFileErrorSummary(value: unknown) {
  if (typeof value !== 'string') return ''
  // Supplier logs may echo signed file URLs or contact/authentication data.
  // Redact the full string before limiting the plain-text diagnostic, so a
  // truncation cannot leave the beginning of a sensitive value visible.
  return value.replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]/g, ' ')
    .replace(/\b(?:https?|ftp):\/\/[^\s<>"']+|\bwww\.[^\s<>"']+/gi, '[URL]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[연락처]')
    .replace(/\b(?:Bearer|Token)\s+[A-Za-z0-9._~+/=-]+/gi, '[인증정보]')
    .replace(/\b(?:order_?(?:num|seq|code)|result_?id|api_?key|user_?id)\s*[:=]\s*[^\s,;]+/gi, '[식별정보]')
    .replace(/\+?\d(?:[\s().-]*\d){7,}/g, '[연락처]')
    .replace(/\b[A-Za-z0-9_-]{16,}\b/g, '[식별정보]')
    .replace(/[^\p{L}\p{N} _()./,:;!?\[\]-]/gu, ' ')
    .replace(/\s+/g, ' ').trim().slice(0, 200)
}

export function orderStatus(value: unknown, orderNum: string, orderSeq: number) {
  const raw = record(value)
  if (raw.success !== true || !Array.isArray(raw.order_status)) throw new RedprintingError('vendor_order_status_unknown', 502, true)
  const found = raw.order_status.find((candidate: unknown) => { const row = record(candidate); return String(row.order_num) === orderNum && Number(row.order_seq) === orderSeq })
  if (!found) throw new RedprintingError('vendor_order_status_unknown', 502, true)
  const row = record(found)
  const safe = (value: unknown, max = 80) => text(String(value ?? ''), max).replace(/[^\p{L}\p{N} _()./-]/gu, '')
  const status = { statusCode: safe(row.status_code, 50), statusName: safe(row.status_name), statusCodeOrg: safe(row.status_code_org, 50),
    fileProcessYn: text(row.file_process_yn, 1), trackingNumber: safe(row.invoice_number, 100), courier: safe(row.delivery),
    fileErrorDetailPresent: Boolean(row.file_error_log && String(row.file_error_log).trim()),
  }
  const flags = vendorFileFlags({ ...status, fileErrorSummary: vendorFileErrorSummary(row.file_error_log) })
  const { fileErrorSummary } = flags
  return { ...status, ...flags,
    statusName: fileErrorSummary ? `${status.statusName || '파일오류'}: ${fileErrorSummary}` : status.statusName }
}

export function testOrderPayload(row: Record<string, any>, settings: RedprintingSettings, files: { cover: string; interior: string }) {
  const receiver = vendorTestRecipient(row.recipient)
  assertReadySettings(settings)
  return { order_data: [{ order_num: identifier(row.order_num), order_seq: 1, order_code: identifier(row.order_code), qty: 1,
    file_url1: files.cover, file_url2: files.interior,
    dlv_name: receiver.name, dlv_tel: receiver.tel, dlv_zipcode: receiver.zipcode, dlv_address: receiver.address,
    dlv_address_detail: receiver.addressDetail, dlv_msg: receiver.message,
    send_name: settings.senderName, send_tel: settings.senderTel, send_zipcode: settings.senderZipcode,
    send_address: settings.senderAddress, send_address_detail: settings.senderAddressDetail,
  }] }
}

export type RedprintingTransport = {
  fetch?: typeof fetch; acquire: () => Promise<() => Promise<void>>; now?: () => number;
}
export class RedprintingClient {
  private token = ''
  constructor(private config: RedprintingEnvironment, private transport: RedprintingTransport) {}
  private async request(path: string, method: string, body?: unknown, auth = true) {
    assertDevelopment(this.config, this.transport.now?.() ?? Date.now())
    const release = await this.transport.acquire()
    try {
      const response = await (this.transport.fetch ?? fetch)(`${REDPRINTING_API_ORIGIN}${path}`, {
        method, headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Token ${this.token}` }
          : { 'x-api-key': `Bearer ${this.config.apiKey}` }) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(auth ? 25000 : 10000), redirect: 'error',
      })
      if (!response.ok) throw new RedprintingError(`vendor_http_${response.status}`, response.status === 404 ? 404 : 502,
        response.status >= 500 || response.status === 408 || response.status === 429, response.status)
      const parsed = await response.json().catch(() => null)
      if (!parsed || typeof parsed !== 'object') throw new RedprintingError('vendor_response_invalid', 502, true)
      return parsed
    } catch (error) {
      if (error instanceof RedprintingError) throw error
      throw new RedprintingError('vendor_request_uncertain', 502, true)
    } finally { await release() }
  }
  private async authenticate() {
    if (this.token) return
    const result = record(await this.request('/v1/auth/token', 'POST', { id: this.config.userId, expired: '1h' }, false))
    if (result.success !== true || typeof result.token !== 'string' || result.token.length < 20) throw new RedprintingError('vendor_authentication_failed', 502)
    this.token = result.token
  }
  async call(path: string, body?: unknown, method = 'POST') {
    if (!/^\/v1\/code\/(list|detail|price|order|order-status|order-cancel|order-deposit|file-reupload)(?:\?|$)/.test(path)) throw new RedprintingError('invalid_vendor_api_path', 400)
    await this.authenticate()
    return this.request(path, method, body)
  }
  async status(orderNum: string, orderSeq = 1) {
    return orderStatus(await this.call(`/v1/code/order-status?order_num=${encodeURIComponent(identifier(orderNum))}&order_seq=${orderSeq}`, undefined, 'GET'), orderNum, orderSeq)
  }
}

export function coverTrim(spec: ReturnType<typeof testPrintSpec>): PrintRect {
  const cover = spec.cover as any
  return cover.trim ?? { xMm: 5, yMm: 5, widthMm: cover.widthMm - 10, heightMm: cover.heightMm - 10 }
}

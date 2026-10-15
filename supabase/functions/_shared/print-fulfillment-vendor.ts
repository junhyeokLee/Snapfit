import { RedprintingError, REDPRINTING_API_ORIGIN, hasVendorFileError, hasVendorFileWarning, identifier, orderStatus, recipient, vendorPrice, type RedprintingSettings } from './redprinting.ts'
import type { OrderRow } from './order-types.ts'

export type SupplierStatus = ReturnType<typeof orderStatus>
export type CustomerPrintStage = 'QUEUED' | 'RENDERING' | 'FILES_READY' | 'SUBMISSION_UNKNOWN' |
  'VENDOR_ACCEPTED' | 'FILE_ERROR' | 'FILE_CHECKED' | 'PRODUCTION_PENDING' | 'IN_PRODUCTION' |
  'SHIPPING' | 'CANCELED' | 'HOLD'

/** PGS_07 means an order exists, not that files or production are complete. */
export function supplierProgress(status: SupplierStatus): {
  customerStage: CustomerPrintStage; fileChecked: boolean; productionStarted: boolean;
  shipped: boolean; canceled: boolean; needsAttention: boolean; fileWarning: boolean;
} {
  const code = status.statusCode, original = status.statusCodeOrg
  const canceled = code === 'PGS_01' || ['PGS_01', 'PGS_02'].includes(original)
  const error = hasVendorFileError(status) || original === 'PGS_26' || code === 'PGS_60'
  // A supplier-confirmed internal warning is not a manufacturing failure. It
  // proves neither production nor physical sample/colour approval.
  const fileWarning = hasVendorFileWarning(status)
  const shipped = code === 'PGS_55' && Boolean(status.courier && status.trackingNumber)
  const productionStarted = ['PGS_20', 'PGS_50', 'PGS_55'].includes(code) && !error && !canceled
  const fileChecked = status.fileProcessYn === 'Y' && !error && !canceled
  const customerStage: CustomerPrintStage = canceled ? 'CANCELED' : error ? 'FILE_ERROR' : shipped ? 'SHIPPING' :
    productionStarted ? 'IN_PRODUCTION' : fileChecked ? 'FILE_CHECKED' : 'VENDOR_ACCEPTED'
  return { customerStage, fileChecked, productionStarted, shipped, canceled, needsAttention: error || canceled, fileWarning }
}

/** Pull at most twice an hour in Korea's stated weekday operating window. */
export function nextSupplierPoll(now: number, minutes = 30): string {
  if (!Number.isFinite(now) || ![30, 60].includes(minutes)) throw new RedprintingError('invalid_poll_schedule', 400)
  const offset = 9 * 60 * 60 * 1000
  const korea = new Date(now + minutes * 60 * 1000 + offset)
  for (let days = 0; days < 8; days++) {
    const day = korea.getUTCDay(), hour = korea.getUTCHours()
    if (day !== 0 && day !== 6 && hour >= 9 && hour < 18) return new Date(korea.getTime() - offset).toISOString()
    if (hour < 9 && day !== 0 && day !== 6) {
      korea.setUTCHours(9, 0, 0, 0)
    } else {
      korea.setUTCDate(korea.getUTCDate() + 1)
      korea.setUTCHours(9, 0, 0, 0)
    }
  }
  throw new RedprintingError('invalid_poll_schedule', 400)
}

export function customerOrderPayload(order: OrderRow, sender: RedprintingSettings,
  orderNum: string, orderCode: string, files: { cover: string; interior: string }) {
  const delivery = recipient({ name: order.recipient_name, tel: order.recipient_phone,
    zipcode: order.zip_code, address: order.address_line1, addressDetail: order.address_line2, message: order.delivery_memo })
  if (sender.senderName !== '스냅핏' || typeof sender.senderTel !== 'string' || !/^0\d{8,10}$/.test(sender.senderTel.replaceAll('-', '')) || !/^\d{5}$/.test(sender.senderZipcode) ||
      !sender.senderAddress || !sender.senderAddressDetail) {
    throw new RedprintingError('sender_details_required', 409)
  }
  return { order_data: [{ order_num: identifier(orderNum), order_seq: 1, order_code: identifier(orderCode), qty: 1,
    file_url1: files.cover, file_url2: files.interior,
    dlv_name: delivery.name, dlv_tel: delivery.tel, dlv_zipcode: delivery.zipcode, dlv_address: delivery.address,
    dlv_address_detail: delivery.addressDetail, dlv_msg: delivery.message,
    send_name: sender.senderName, send_tel: sender.senderTel, send_zipcode: sender.senderZipcode,
    send_address: sender.senderAddress, send_address_detail: sender.senderAddressDetail,
  }] }
}

export type FulfillmentVendorConfiguration = {
  enabled: boolean; environment: 'disabled' | 'production'; productionApproved: boolean;
  depositEnabled: boolean; userId: string; apiKey: string;
}

export interface FulfillmentVendor {
  price(orderCode: string): Promise<ReturnType<typeof vendorPrice>>
  depositBalance(): Promise<number>
  submit(payload: unknown): Promise<unknown>
  status(orderNum: string, orderSeq: number): Promise<SupplierStatus>
  confirm(orderNum: string): Promise<unknown>
}

/** Read-only account balance. Missing/failed/malformed responses are never zero. */
export function vendorDepositBalance(value: unknown): number {
  const row = value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {}
  const raw = row.total_balance
  const balance = typeof raw === 'number' ? raw : typeof raw === 'string' && /^(?:0|[1-9]\d{0,15})$/.test(raw) ? Number(raw) : NaN
  if (row.success !== true || !Number.isSafeInteger(balance) || balance < 0) {
    throw new RedprintingError('supplier_deposit_unavailable', 503, true)
  }
  return balance
}

/** Credentials remain in the Edge runtime. Rate slots are shared in the DB. */
export class RedprintingFulfillmentClient implements FulfillmentVendor {
  private token = ''
  constructor(private readonly configuration: FulfillmentVendorConfiguration,
    private readonly acquire: () => Promise<() => Promise<void>>, private readonly fetcher: typeof fetch = fetch) {}

  private configured(write = false, deposit = false) {
    const config = this.configuration
    if (!config.enabled || config.environment !== 'production' || !config.apiKey || !config.userId) {
      throw new RedprintingError('production_vendor_not_configured', 503)
    }
    if (write && !config.productionApproved) throw new RedprintingError('production_vendor_not_approved', 503)
    if (deposit && !config.depositEnabled) throw new RedprintingError('production_deposit_disabled', 503)
  }

  private async request(path: string, method: string, body?: unknown, authenticate = false): Promise<unknown> {
    this.configured()
    const release = await this.acquire()
    try {
      const response = await this.fetcher(`${REDPRINTING_API_ORIGIN}${path}`, {
        method, redirect: 'error', signal: AbortSignal.timeout(authenticate ? 10000 : 25000),
        headers: { 'Content-Type': 'application/json', ...(authenticate
          ? { 'x-api-key': `Bearer ${this.configuration.apiKey}` } : { Authorization: `Token ${this.token}` }) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      if (!response.ok) throw new RedprintingError(`vendor_http_${response.status}`, response.status === 404 ? 404 : 502,
        response.status >= 500 || response.status === 408 || response.status === 429, response.status)
      const limit = 1024 * 1024, length = response.headers.get('content-length')
      if (length && (!/^\d+$/.test(length) || Number(length) > limit)) {
        await response.body?.cancel().catch(() => {})
        throw new RedprintingError('vendor_response_invalid', 502, true)
      }
      if (!response.body) throw new RedprintingError('vendor_response_invalid', 502, true)
      const reader = response.body.getReader(), decoder = new TextDecoder('utf-8', { fatal: true })
      let text = '', count = 0
      try {
        for (;;) {
          const chunk = await reader.read()
          if (chunk.done) break
          count += chunk.value.byteLength
          if (count > limit) { await reader.cancel().catch(() => {}); throw new RedprintingError('vendor_response_invalid', 502, true) }
          text += decoder.decode(chunk.value, { stream: true })
        }
        text += decoder.decode()
      } finally { reader.releaseLock() }
      let data: unknown
      try { data = JSON.parse(text) } catch { throw new RedprintingError('vendor_response_invalid', 502, true) }
      if (!data || typeof data !== 'object' || Array.isArray(data)) throw new RedprintingError('vendor_response_invalid', 502, true)
      return data
    } catch (error) {
      if (error instanceof RedprintingError) throw error
      throw new RedprintingError('vendor_request_uncertain', 502, true)
    } finally { await release() }
  }

  private async authenticate() {
    this.configured()
    if (this.token) return
    const data = await this.request('/v1/auth/token', 'POST', { id: identifier(this.configuration.userId), expired: '1h' }, true) as Record<string, unknown>
    if (data.success !== true || typeof data.token !== 'string' || data.token.length < 20) {
      throw new RedprintingError('vendor_authentication_failed', 502)
    }
    this.token = data.token
  }

  async submit(payload: unknown) {
    this.configured(true)
    await this.authenticate()
    return this.request('/v1/code/order', 'POST', payload)
  }
  async price(orderCode: string) {
    await this.authenticate()
    return vendorPrice(await this.request('/v1/code/price', 'POST', { order_code: identifier(orderCode), qty: 1 }))
  }
  async status(orderNum: string, orderSeq: number) {
    await this.authenticate()
    return orderStatus(await this.request(`/v1/code/order-status?order_num=${encodeURIComponent(identifier(orderNum))}&order_seq=${orderSeq}`, 'GET'), orderNum, orderSeq)
  }
  async depositBalance() {
    await this.authenticate()
    return vendorDepositBalance(await this.request('/v1/code/deposit', 'GET'))
  }
  async confirm(orderNum: string) {
    this.configured(true, true)
    await this.authenticate()
    return this.request('/v1/code/order-deposit', 'POST', { order_num: identifier(orderNum) })
  }
}

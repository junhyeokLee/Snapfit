/**
 * PortOne V2 payment observation for a future server-owned checkout bridge.
 * References (checked 2026-10-14):
 * https://developers.portone.io/api/rest-v2/overview
 * https://developers.portone.io/api/rest-v2/payment
 * https://github.com/portone-io/server-sdk/tree/main/javascript/src/generated
 *
 * This module is not an Edge endpoint and is not connected to customer orders.
 * It performs GET only. A successful observation is neither an order commit nor
 * permission to manufacture: database replay protection and production release
 * checks must be implemented separately before using it for fulfillment.
 */

export type ExpectedPortOnePrintPayment = {
  paymentId: string
  storeId: string
  channelKey: string
  amount: number
  currency: 'KRW'
  environment: 'test' | 'live'
}

export type PortOnePrintPaymentObservation = Readonly<{
  provider: 'PORTONE'
  version: 'V2'
  status: 'PAID'
  paymentId: string
  transactionId: string
  storeId: string
  channelKey: string
  amount: number
  paidAmount: number
  discountAmount: number
  currency: 'KRW'
  paidAt: string
  environment: 'test' | 'live'
  isTest: boolean
}>

type LookupOptions = {
  /** V2 API Secret injected by server code, never a PG secret or client input. */
  apiSecret: string
  fetcher?: typeof fetch
  timeoutMs?: number
}

export class PortOnePrintPaymentError extends Error {
  readonly code: string
  readonly status: number
  readonly retryable: boolean
  constructor(code: string, status = 409, retryable = false) {
    // No raw response, URL, secret, identity, or provider message is retained.
    super(code)
    this.name = 'PortOnePrintPaymentError'
    this.code = code
    this.status = status
    this.retryable = retryable
  }
}

const API_ORIGIN = 'https://api.portone.io'
const MAX_RESPONSE_BYTES = 1024 * 1024
const identifier = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(value)
const integer = (value: unknown) => Number.isSafeInteger(value) && Number(value) >= 0
const object = (value: unknown): Record<string, unknown> | null =>
  value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null

function checkedExpectation(value: ExpectedPortOnePrintPayment): ExpectedPortOnePrintPayment {
  if (!value || !identifier(value.paymentId) || !identifier(value.storeId) || !identifier(value.channelKey) ||
      !integer(value.amount) || value.amount <= 0 || value.currency !== 'KRW' ||
      !['test', 'live'].includes(value.environment)) {
    throw new PortOnePrintPaymentError('invalid_payment_expectation', 400)
  }
  // Freeze primitive values before asynchronous I/O; callers cannot change the
  // expected order amount or channel while the provider response is in flight.
  return { paymentId: value.paymentId, storeId: value.storeId, channelKey: value.channelKey,
    amount: value.amount, currency: value.currency, environment: value.environment }
}

function observePayment(payload: unknown, expected: ExpectedPortOnePrintPayment): PortOnePrintPaymentObservation {
  const payment = object(payload)
  if (!payment) throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  if (payment.status !== 'PAID') throw new PortOnePrintPaymentError('payment_not_paid')
  if (payment.id !== expected.paymentId || payment.storeId !== expected.storeId) {
    throw new PortOnePrintPaymentError('payment_identity_mismatch')
  }
  if (payment.version !== 'V2') throw new PortOnePrintPaymentError('payment_version_mismatch')
  const channel = object(payment.channel)
  if (!channel || channel.key !== expected.channelKey) throw new PortOnePrintPaymentError('payment_channel_mismatch')
  const expectedChannelType = expected.environment === 'live' ? 'LIVE' : 'TEST'
  // The REST model uses channel.type, not a callback's isTest flag, as evidence.
  if (channel.type !== expectedChannelType) throw new PortOnePrintPaymentError('payment_environment_mismatch')
  if (payment.currency !== expected.currency) throw new PortOnePrintPaymentError('payment_currency_mismatch')
  const amount = object(payment.amount)
  if (!amount || !['total', 'paid', 'discount', 'cancelled', 'cancelledTaxFree'].every(key => integer(amount[key]))) {
    throw new PortOnePrintPaymentError('invalid_payment_amount', 502)
  }
  if (amount.total !== expected.amount || Number(amount.paid) <= 0 ||
      Number(amount.paid) + Number(amount.discount) !== expected.amount) {
    throw new PortOnePrintPaymentError('payment_amount_mismatch')
  }
  if (amount.cancelled !== 0 || amount.cancelledTaxFree !== 0) throw new PortOnePrintPaymentError('payment_reversed')
  // Pending or historical cancellation attempts require a separate review.
  // We do not manufacture while a cancellation response is still uncertain.
  if (payment.cancellations != null && (!Array.isArray(payment.cancellations) || payment.cancellations.length > 0)) {
    throw new PortOnePrintPaymentError('payment_cancellation_review_required')
  }
  if (!identifier(payment.transactionId) || typeof payment.paidAt !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(payment.paidAt) ||
      !Number.isFinite(Date.parse(payment.paidAt))) {
    throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  }
  return Object.freeze({
    provider: 'PORTONE', version: 'V2', status: 'PAID', paymentId: expected.paymentId,
    transactionId: payment.transactionId, storeId: expected.storeId, channelKey: expected.channelKey,
    amount: expected.amount, paidAmount: Number(amount.paid), discountAmount: Number(amount.discount),
    currency: 'KRW', paidAt: payment.paidAt, environment: expected.environment,
    isTest: channel.type === 'TEST',
  })
}

async function paymentJson(response: Response): Promise<unknown> {
  const contentLength = response.headers.get('Content-Length')
  if (contentLength != null && (!/^\d+$/.test(contentLength) || Number(contentLength) > MAX_RESPONSE_BYTES)) {
    await response.body?.cancel().catch(() => {})
    throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  }
  if (!response.body) throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  const reader = response.body.getReader(), decoder = new TextDecoder('utf-8', { fatal: true })
  let bytes = 0, text = ''
  try {
    while (true) {
      const chunk = await reader.read()
      if (chunk.done) break
      bytes += chunk.value.byteLength
      if (bytes > MAX_RESPONSE_BYTES) {
        await reader.cancel().catch(() => {})
        throw new PortOnePrintPaymentError('invalid_payment_response', 502)
      }
      try { text += decoder.decode(chunk.value, { stream: true }) }
      catch { throw new PortOnePrintPaymentError('invalid_payment_response', 502) }
    }
    try { text += decoder.decode() }
    catch { throw new PortOnePrintPaymentError('invalid_payment_response', 502) }
    try { return JSON.parse(text) }
    catch { throw new PortOnePrintPaymentError('invalid_payment_response', 502) }
  } finally { reader.releaseLock() }
}

/**
 * Expected values must come from the server's immutable order/configuration.
 * Client callback success is deliberately not an input to this function.
 */
async function readPortOnePayment(
  expectation: ExpectedPortOnePrintPayment, options: LookupOptions,
): Promise<unknown> {
  const expected = checkedExpectation(expectation)
  if (!options || typeof options.apiSecret !== 'string' || !/^[\x21-\x7e]{8,2048}$/.test(options.apiSecret)) {
    throw new PortOnePrintPaymentError('payment_provider_unconfigured', 503)
  }
  const timeoutMs = options.timeoutMs ?? 15000
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0 || timeoutMs > 15000) {
    throw new PortOnePrintPaymentError('invalid_payment_timeout', 400)
  }
  const url = new URL(`/payments/${encodeURIComponent(expected.paymentId)}`, API_ORIGIN)
  url.searchParams.set('storeId', expected.storeId)
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await (options.fetcher ?? fetch)(url, {
      method: 'GET', redirect: 'error', signal: controller.signal,
      headers: { Authorization: `PortOne ${options.apiSecret}`, Accept: 'application/json' },
    })
    if (!response.ok) {
      // Do not parse or expose private provider errors, even on authorization failure.
      await response.body?.cancel().catch(() => {})
      if (response.status === 404) throw new PortOnePrintPaymentError('payment_not_found', 404, true)
      if (response.status === 401 || response.status === 403) throw new PortOnePrintPaymentError('payment_provider_auth_failed', 503)
      if (response.status === 429 || response.status >= 500) throw new PortOnePrintPaymentError('payment_provider_unavailable', 503, true)
      throw new PortOnePrintPaymentError('payment_provider_request_failed', 502)
    }
    return await paymentJson(response)
  } catch (error) {
    if (error instanceof PortOnePrintPaymentError) throw error
    throw new PortOnePrintPaymentError(controller.signal.aborted ? 'payment_lookup_timeout' : 'payment_provider_unavailable', 503, true)
  } finally { clearTimeout(timeout) }
}

export async function queryPortOnePrintPayment(expectation: ExpectedPortOnePrintPayment, options: LookupOptions): Promise<PortOnePrintPaymentObservation> {
  const expected = checkedExpectation(expectation)
  return observePayment(await readPortOnePayment(expected, options), expected)
}

export type PortOneVerifiedUnpaidObservation = {
  provider: 'PORTONE'; version: 'V2'; status: 'FAILED' | 'CANCELLED'; paymentId: string; transactionId: string;
  storeId: string; channelKey: string; amount: number; paidAmount: number; cancelledAmount: number;
  currency: 'KRW'; environment: 'test' | 'live'; isTest: boolean; verifiedUnpaid: true;
}
export type PortOnePrintPaymentState =
  { kind: 'paid'; receipt: PortOnePrintPaymentObservation } |
  { kind: 'verified_unpaid'; receipt: PortOneVerifiedUnpaidObservation } |
  { kind: 'unknown' }

// Only authoritative no-charge terminal states release a pending checkout.
// A 404, a closed window, expiry, READY or PENDING is never proof of no charge.
export async function queryPortOnePrintPaymentState(expectation: ExpectedPortOnePrintPayment, options: LookupOptions): Promise<PortOnePrintPaymentState> {
  const expected = checkedExpectation(expectation), payment = object(await readPortOnePayment(expected, options))
  if (!payment) throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  if (payment.status === 'PAID') return { kind: 'paid', receipt: observePayment(payment, expected) }
  const channel = object(payment.channel), amount = object(payment.amount)
  if (payment.id !== expected.paymentId || payment.storeId !== expected.storeId || payment.version !== 'V2') {
    throw new PortOnePrintPaymentError('payment_identity_mismatch')
  }
  // Unsettled states may not contain a selected channel yet. They prove neither
  // charge nor non-charge; keep observing the same frozen invoice. The full
  // LIVE route/amount checks remain mandatory for every terminal receipt below.
  if (!['FAILED', 'CANCELLED'].includes(String(payment.status))) return { kind: 'unknown' }
  if (!channel || channel.key !== expected.channelKey || channel.type !== (expected.environment === 'live' ? 'LIVE' : 'TEST')) {
    throw new PortOnePrintPaymentError('payment_environment_mismatch')
  }
  if (payment.currency !== 'KRW' || !amount || !['total', 'paid', 'cancelled'].every(key => integer(amount[key])) || amount.total !== expected.amount) {
    throw new PortOnePrintPaymentError('payment_amount_mismatch')
  }
  const failed = payment.status === 'FAILED' && amount.paid === 0 && amount.cancelled === 0
  const canceled = payment.status === 'CANCELLED' && Number(amount.paid) > 0 && Number(amount.cancelled) >= Number(amount.paid) && Number(amount.cancelled) <= expected.amount
  if (!failed && !canceled) return { kind: 'unknown' }
  if (!identifier(payment.transactionId)) throw new PortOnePrintPaymentError('invalid_payment_response', 502)
  return { kind: 'verified_unpaid', receipt: { provider: 'PORTONE', version: 'V2',
    status: failed ? 'FAILED' : 'CANCELLED', paymentId: expected.paymentId, transactionId: payment.transactionId,
    storeId: expected.storeId, channelKey: expected.channelKey, amount: expected.amount, paidAmount: Number(amount.paid),
    cancelledAmount: Number(amount.cancelled), currency: 'KRW', environment: expected.environment,
    isTest: channel.type === 'TEST', verifiedUnpaid: true } }
}

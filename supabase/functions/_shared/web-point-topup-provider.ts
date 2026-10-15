/** Point-only PortOne V2 observer. No print order, SDK callback, or refund POST.
 * Official references checked 2026-10-15:
 * https://developers.portone.io/opi/ko/integration/start/v2/checkout?v=v2
 * https://developers.portone.io/opi/ko/integration/webhook/readme-v2?v=v2
 * https://developers.portone.io/api/rest-v2/payment?v=v2
 */
export type WebPointExpectation = {
  paymentId: string; storeId: string; channelKey: string; totalAmount: number;
  currency: 'KRW'; environment: 'test' | 'live';
}
export class WebPointError extends Error {
  constructor(readonly code: string, readonly status = 409) { super(code) }
}
export const pointRecord = (v: unknown): Record<string, unknown> =>
  v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, unknown> : {}
const integer = (v: unknown): v is number => Number.isSafeInteger(v) && Number(v) >= 0;
const identifier = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(v);
const timestamp = (v: unknown): v is string => typeof v === 'string' &&
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(v) && Number.isFinite(Date.parse(v));

export async function readPointBody(request: Request | Response, limit: number): Promise<string> {
  const length = request.headers.get('content-length');
  if (length != null && (!/^\d+$/.test(length) || Number(length) > limit)) {
    await request.body?.cancel().catch(() => {}); throw new WebPointError('web_point_payload_invalid', 400);
  }
  if (!request.body) throw new WebPointError('web_point_payload_invalid', 400);
  const reader = request.body.getReader(), decoder = new TextDecoder('utf-8', { fatal: true });
  let bytes = 0, text = '';
  try {
    for (;;) {
      const chunk = await reader.read(); if (chunk.done) break;
      bytes += chunk.value.byteLength;
      if (bytes > limit) { await reader.cancel(); throw new WebPointError('web_point_payload_invalid', 400); }
      text += decoder.decode(chunk.value, { stream: true });
    }
    return text + decoder.decode();
  } catch (error) {
    if (error instanceof WebPointError) throw error;
    throw new WebPointError('web_point_payload_invalid', 400);
  } finally { reader.releaseLock(); }
}

/** Returns null for unsettled/unknown states. Never equate 404/expiry with unpaid. */
export async function observeWebPointPayment(expected: WebPointExpectation, apiSecret: string,
  fetcher: typeof fetch = fetch): Promise<Record<string, unknown> | null> {
  if (!identifier(expected.paymentId) || !identifier(expected.storeId) || !identifier(expected.channelKey) ||
      !integer(expected.totalAmount) || expected.totalAmount < 1 || expected.currency !== 'KRW' ||
      !['test', 'live'].includes(expected.environment) || !/^[\x21-\x7e]{8,2048}$/.test(apiSecret)) {
    throw new WebPointError('web_point_configuration_invalid', 503);
  }
  const url = new URL(`/payments/${encodeURIComponent(expected.paymentId)}`, 'https://api.portone.io');
  url.searchParams.set('storeId', expected.storeId);
  const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 12000);
  let payload: unknown;
  try {
    const response = await fetcher(url, { method: 'GET', redirect: 'error', signal: controller.signal,
      headers: { Authorization: `PortOne ${apiSecret}`, Accept: 'application/json' } });
    if (!response.ok) {
      await response.body?.cancel().catch(() => {});
      throw new WebPointError(response.status === 404 ? 'web_point_payment_not_found' : 'web_point_provider_unavailable', 503);
    }
    try { payload = JSON.parse(await readPointBody(response, 262144)); }
    catch { throw new WebPointError('web_point_provider_response_invalid', 502); }
  } catch (error) {
    if (error instanceof WebPointError) throw error;
    throw new WebPointError('web_point_provider_unavailable', 503);
  } finally { clearTimeout(timeout); }
  const payment = pointRecord(payload), channel = pointRecord(payment.channel), amount = pointRecord(payment.amount);
  if (payment.id !== expected.paymentId || payment.storeId !== expected.storeId || payment.version !== 'V2') {
    throw new WebPointError('web_point_payment_identity_mismatch');
  }
  // Unsettled payments may not have a channel. They are never credit evidence.
  if (!['PAID','FAILED','CANCELLED','PARTIAL_CANCELLED'].includes(String(payment.status))) return null;
  if (channel.key !== expected.channelKey || channel.type !== (expected.environment === 'test' ? 'TEST' : 'LIVE') ||
      payment.currency !== 'KRW' || amount.total !== expected.totalAmount ||
      !['total','paid','discount','cancelled'].every(key => integer(amount[key])) ||
      Number(amount.paid) > expected.totalAmount || Number(amount.cancelled) > expected.totalAmount ||
      !identifier(payment.transactionId)) throw new WebPointError('web_point_payment_route_or_amount_mismatch');
  const common = { provider: 'PORTONE', version: 'V2', paymentId: expected.paymentId,
    storeId: expected.storeId, channelKey: expected.channelKey, environment: expected.environment,
    isTest: expected.environment === 'test', currency: 'KRW', totalAmount: expected.totalAmount,
    paidAmount: amount.paid, discountAmount: amount.discount, cancelledAmount: amount.cancelled,
    transactionId: payment.transactionId };
  if (payment.status === 'FAILED') {
    if (amount.paid !== 0 || amount.cancelled !== 0) throw new WebPointError('web_point_payment_amount_mismatch');
    return { ...common, state: 'failed' };
  }
  if (Number(amount.paid) <= 0 || Number(amount.paid) + Number(amount.discount) !== expected.totalAmount) {
    throw new WebPointError('web_point_payment_amount_mismatch');
  }
  if (payment.status === 'PARTIAL_CANCELLED') return { ...common, state: 'review' };
  if (payment.status === 'PAID') {
    if (amount.cancelled !== 0 || !timestamp(payment.paidAt) ||
        payment.cancellations != null && (!Array.isArray(payment.cancellations) || payment.cancellations.length > 0)) {
      return { ...common, state: 'review' };
    }
    return { ...common, state: 'paid', paidAt: payment.paidAt };
  }
  // Full cancellation requires authoritative successful cancellation records.
  if (Number(amount.cancelled) < Number(amount.paid) || !timestamp(payment.cancelledAt) ||
      !Array.isArray(payment.cancellations) || payment.cancellations.length === 0) {
    return { ...common, state: 'review' };
  }
  let sum = 0; const ids = new Set<string>();
  for (const raw of payment.cancellations) {
    const cancellation = pointRecord(raw);
    if (cancellation.status !== 'SUCCEEDED' || !identifier(cancellation.id) || ids.has(cancellation.id) ||
        !integer(cancellation.totalAmount)) return { ...common, state: 'review' };
    ids.add(cancellation.id); sum += cancellation.totalAmount;
  }
  if (!Number.isSafeInteger(sum) || sum !== amount.cancelled) return { ...common, state: 'review' };
  return { ...common, state: 'cancelled', cancelledAt: payment.cancelledAt, fullCancellationVerified: true };
}

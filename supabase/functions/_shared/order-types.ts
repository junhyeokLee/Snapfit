// Shared record/error types for existing order history and print fulfillment.
// This module does not create or verify payments.
export type OrderRow = Record<string, unknown>

export class OrderPaymentError extends Error {
  readonly status: number
  constructor(message: string, status = 400) { super(message); this.status = status }
}

export function assertExistingVerifiedPayment(order: OrderRow) {
  if (order.payment_reversed_at) throw new OrderPaymentError('payment_reversed', 409)
  if (!String(order.verified_payment_id ?? '').trim() ||
      !String(order.verified_payment_provider ?? '').trim() || !order.payment_confirmed_at) {
    throw new OrderPaymentError('verified_payment_required', 409)
  }
}

import { buildPrintPackage } from './print-package.ts'
import { OrderPaymentError, assertExistingVerifiedPayment, type OrderRow } from './order-types.ts'
import { assertPrintOrder, calculateContribution, orderPrintProduct, printCoverType, validateHardCoverGeometry } from './print-contract.ts'

type OrderDatabase = any

export async function loadOrder(supabase: OrderDatabase, orderId: string): Promise<OrderRow> {
  const { data, error } = await supabase.from('orders').select('*').eq('order_id', orderId).maybeSingle()
  if (error) throw error
  if (!data) throw new OrderPaymentError('order_not_found', 404)
  return data
}

// Call only inside the already authenticated admin endpoint. Customer-facing
// order history never joins private procurement costs or supplier correspondence.
export async function withPrintOperations(supabase: OrderDatabase, order: OrderRow): Promise<OrderRow> {
  const { data, error } = await supabase.from('print_order_operations').select('*').eq('order_id', order.order_id).maybeSingle()
  if (error) throw error
  return { ...order, ...(data ?? {}) }
}

// Claim with a bounded lease; only its current holder may publish artifacts or
// move the order forward. Payment was already committed before storage/network work.
export async function prepareVerifiedOrder(
  supabase: OrderDatabase, order: OrderRow, builder = buildPrintPackage,
): Promise<OrderRow> {
  assertExistingVerifiedPayment(order)
  if (['IN_PRODUCTION', 'PRINTING', 'SHIPPING', 'DELIVERED'].includes(String(order.status))) return order
  if (order.status !== 'PAYMENT_COMPLETED') throw new OrderPaymentError('order_not_ready_for_print', 409)
  if (order.print_fulfillment_status && order.print_fulfillment_status !== 'AWAITING_RENDER') return order
  const token = crypto.randomUUID()
  const { data: claimed, error: claimError } = await supabase.rpc('claim_print_package', { p_order_id: order.order_id, p_token: token })
  if (claimError) throw claimError
  if (!claimed) {
    const current = await loadOrder(supabase, String(order.order_id))
    if (current.payment_reversed_at) throw new OrderPaymentError('payment_reversed', 409)
    return current
  }
  try {
    const { patch } = await builder(supabase, claimed)
    const { data, error } = await supabase.from('orders').update({
      ...patch, print_package_lock_token: null, print_package_lock_until: null,
    }).eq('order_id', order.order_id).eq('status', 'PAYMENT_COMPLETED')
      .eq('print_package_lock_token', token).is('payment_reversed_at', null).select().maybeSingle()
    if (error) throw error
    const current = data ?? await loadOrder(supabase, String(order.order_id))
    if (current.payment_reversed_at) throw new OrderPaymentError('payment_reversed', 409)
    return current
  } finally {
    const { error } = await supabase.from('orders').update({ print_package_lock_token: null, print_package_lock_until: null })
      .eq('order_id', order.order_id).eq('print_package_lock_token', token)
    if (error) console.warn('order_print_claim_release_failed')
  }
}

export async function advanceVerifiedOrder(
  supabase: OrderDatabase, order: OrderRow, action: string, body: Record<string, unknown>,
): Promise<OrderRow> {
  if (action === 'preparePrintPackage') return prepareVerifiedOrder(supabase, order)
  assertExistingVerifiedPayment(order)
  const now = new Date().toISOString()
  let patch: Record<string, unknown>
  let operationsPatch: Record<string, unknown> | undefined
  if (action === 'configurePrintSpec') {
    assertPrintOrder(order)
    if (['SUBMITTED', 'ACCEPTED'].includes(String(order.print_fulfillment_status))) throw new OrderPaymentError('print_already_submitted', 409)
    const isHard = printCoverType(orderPrintProduct(order).id) === 'HARD'
    const spineMm = Number(body.spineMm), evidence = String(body.evidence ?? '').trim()
    if (evidence.length < 10) throw new OrderPaymentError('vendor_spine_evidence_required')
    if (!isHard && (!Number.isFinite(spineMm) || spineMm < .1 || spineMm > 40)) throw new OrderPaymentError('vendor_spine_evidence_required')
    const configuredSpec = isHard
      ? { coverGeometry: validateHardCoverGeometry(body.coverGeometry), templateRevision: crypto.randomUUID(), recordedAt: now }
      : { spineMm, recordedAt: now }
    operationsPatch = { print_spec_evidence: evidence, print_review_note: null }
    patch = { print_spec_override: configuredSpec, print_fulfillment_status: 'AWAITING_RENDER',
      print_upload_id: null, print_upload_fingerprint: null, print_cover_pdf_path: null, print_interior_pdf_path: null,
      print_manifest_path: null, print_manifest: null, print_spec_confirmed_at: null }
  } else if (action === 'markPrintReviewed') {
    assertPrintOrder(order)
    if (!['REVIEW_REQUIRED', 'READY'].includes(String(order.print_fulfillment_status)) || !order.print_cover_pdf_path || !order.print_interior_pdf_path) {
      throw new OrderPaymentError('print_files_not_ready', 409)
    }
    const reviewNote = String(body.reviewNote ?? '').trim()
    if (body.vendorSpecConfirmed !== true || reviewNote.length < 10) throw new OrderPaymentError('vendor_spec_review_required', 409)
    operationsPatch = { print_review_note: reviewNote }
    patch = { print_fulfillment_status: 'READY', print_spec_confirmed_at: now }
  } else if (action === 'submitPrintVendor') {
    assertPrintOrder(order)
    const vendorOrderId = String(body.vendorOrderId ?? '').trim()
    if (!vendorOrderId || vendorOrderId.length > 120 || /^(SPP-|TEST|DEMO)/i.test(vendorOrderId)) throw new OrderPaymentError('real_vendor_order_id_required')
    if (order.print_fulfillment_status === 'SUBMITTED') {
      if (vendorOrderId !== order.print_vendor_order_id) throw new OrderPaymentError('vendor_order_already_recorded', 409)
      return order
    }
    if (order.print_fulfillment_status !== 'READY' || !order.print_spec_confirmed_at) throw new OrderPaymentError('vendor_spec_review_required', 409)
    const fulfillmentMethod = String(body.fulfillmentMethod ?? '')
    if (!['DIRECT', 'REPACK'].includes(fulfillmentMethod)) throw new OrderPaymentError('fulfillment_method_required')
    if (fulfillmentMethod === 'DIRECT' && (body.senderLabelConfirmed !== true || body.priceSlipOmittedConfirmed !== true || body.promotionalMaterialsOmittedConfirmed !== true)) {
      throw new OrderPaymentError('direct_shipping_confirmation_required', 409)
    }
    const evidence = String(body.evidence ?? body.confirmationNote ?? order.print_review_note ?? '').trim()
    if (fulfillmentMethod === 'DIRECT' && evidence.length < 10) throw new OrderPaymentError('direct_shipping_evidence_required', 409)
    const costs = calculateContribution(order, body)
    patch = { print_fulfillment_status: 'SUBMITTED', print_vendor: 'REDPRINTING', print_vendor_order_id: vendorOrderId,
      print_submitted_at: now, fulfillment_method: fulfillmentMethod,
      sender_label_confirmed: body.senderLabelConfirmed === true, price_slip_omitted_confirmed: body.priceSlipOmittedConfirmed === true,
      promotional_materials_omitted_confirmed: body.promotionalMaterialsOmittedConfirmed === true }
    operationsPatch = { ...costs, fulfillment_confirmation: { senderLabelConfirmed: body.senderLabelConfirmed === true, priceSlipOmittedConfirmed: body.priceSlipOmittedConfirmed === true,
        promotionalMaterialsOmittedConfirmed: body.promotionalMaterialsOmittedConfirmed === true,
        vendorSpecConfirmed: true, evidence, recordedAt: now } }
    const { data, error } = await supabase.rpc('submit_print_vendor', { p_order_id: order.order_id, p_order_patch: patch, p_operations_patch: operationsPatch })
    if (error) throw error
    return { ...data, ...operationsPatch }
  } else if (action === 'acceptPrintVendor') {
    if (order.print_fulfillment_status === 'ACCEPTED') return order
    assertPrintOrder(order)
    if (order.print_fulfillment_status !== 'SUBMITTED' || !order.print_vendor_order_id) throw new OrderPaymentError('vendor_submission_required', 409)
    patch = { status: 'IN_PRODUCTION', print_fulfillment_status: 'ACCEPTED', print_accepted_at: now }
  } else if (action === 'shipping') {
    if (['SHIPPING', 'DELIVERED'].includes(String(order.status))) return order
    if (!['IN_PRODUCTION', 'PRINTING'].includes(String(order.status))) throw new OrderPaymentError('order_not_ready_for_shipping', 409)
    const courier = String(body.courier ?? '').trim(), trackingNumber = String(body.trackingNumber ?? '').trim()
    if (!courier || !trackingNumber) throw new OrderPaymentError('shipping_details_required')
    patch = { status: 'SHIPPING', courier, tracking_number: trackingNumber, shipped_at: now }
  } else if (action === 'delivered') {
    if (order.status === 'DELIVERED') return order
    if (order.status !== 'SHIPPING') throw new OrderPaymentError('order_not_shipped', 409)
    patch = { status: 'DELIVERED', delivered_at: now }
  } else throw new OrderPaymentError('unknown_action')
  if (operationsPatch) {
    const { error } = await supabase.from('print_order_operations').update(operationsPatch).eq('order_id', order.order_id)
    if (error) throw error
  }
  let update = supabase.from('orders').update(patch).eq('order_id', order.order_id)
    .eq('status', order.status).is('payment_reversed_at', null)
  update = order.print_fulfillment_status == null
    ? update.is('print_fulfillment_status', null)
    : update.eq('print_fulfillment_status', order.print_fulfillment_status)
  const { data, error } = await update.select().maybeSingle()
  if (error) throw error
  if (!data) throw new OrderPaymentError('print_state_changed', 409)
  return { ...order, ...data, ...(operationsPatch ?? {}) }
}

import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

function orderToJson(row: Record<string, unknown>) {
  const status = String(row.status ?? 'PAYMENT_PENDING')
  const label: Record<string, string> = {
    PAYMENT_PENDING: '결제대기',
    PAYMENT_COMPLETED: '결제완료',
    IN_PRODUCTION: '제작중',
    PRINTING: '제작중',
    SHIPPING: '배송중',
    DELIVERED: '배송완료',
    CANCELED: '취소',
    CANCELLED: '취소',
  }
  const progress: Record<string, number> = {
    PAYMENT_COMPLETED: 0.25,
    IN_PRODUCTION: 0.5,
    PRINTING: 0.5,
    SHIPPING: 0.75,
    DELIVERED: 1,
  }
  return {
    orderId: row.order_id,
    title: row.title ?? '주문',
    amount: row.amount ?? 0,
    pageCount: row.page_count,
    status,
    statusLabel: label[status] ?? '결제대기',
    progress: progress[status] ?? 0,
    orderedAt: row.ordered_at ?? row.created_at,
    albumId: row.album_id,
    recipientName: row.recipient_name,
    recipientPhone: row.recipient_phone,
    zipCode: row.zip_code,
    addressLine1: row.address_line1,
    addressLine2: row.address_line2,
    deliveryMemo: row.delivery_memo,
    paymentMethod: row.payment_method,
    courier: row.courier,
    trackingNumber: row.tracking_number,
    printVendor: row.print_vendor,
    printVendorOrderId: row.print_vendor_order_id,
    printPackageJsonUrl: row.print_package_json_url,
    printFilePdfUrl: row.print_file_pdf_url,
    printFileZipUrl: row.print_file_zip_url,
    printAssetCount: row.print_asset_count,
    paymentConfirmedAt: row.payment_confirmed_at,
    printPackageGeneratedAt: row.print_package_generated_at,
    printSubmittedAt: row.print_submitted_at,
    shippedAt: row.shipped_at,
    deliveredAt: row.delivered_at,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const user = await getUser(req)
    const body = await req.json().catch(() => ({}))
    const action = String(body.action ?? 'confirm').trim()
    const orderId = String(body.orderId ?? '').trim()
    if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
    const supabase = adminClient()

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('order_id', orderId)
      .maybeSingle()
    if (orderError) throw orderError
    if (!order) return jsonResponse({ error: 'order_not_found' }, 404)

    const isOwner = order.user_id === user.id
    const isAdmin = user.app_metadata?.role === 'admin'
    if (!isOwner && !isAdmin) return jsonResponse({ error: 'forbidden' }, 403)

    const patch: Record<string, unknown> = {}
    const now = new Date().toISOString()
    if (action === 'confirm') {
      patch.status = 'PAYMENT_COMPLETED'
      patch.payment_confirmed_at = now
    } else if (action === 'shipping') {
      if (!isAdmin) return jsonResponse({ error: 'forbidden' }, 403)
      patch.status = 'SHIPPING'
      patch.courier = body.courier ?? order.courier ?? null
      patch.tracking_number = body.trackingNumber ?? order.tracking_number ?? null
      patch.shipped_at = now
    } else if (action === 'delivered') {
      if (!isAdmin) return jsonResponse({ error: 'forbidden' }, 403)
      patch.status = 'DELIVERED'
      patch.delivered_at = now
    } else if (action === 'preparePrintPackage') {
      if (!isAdmin) return jsonResponse({ error: 'forbidden' }, 403)
      patch.status = 'IN_PRODUCTION'
      patch.print_package_generated_at = now
      patch.print_package_json_url = order.print_package_json_url ?? `supabase://print-packages/${orderId}.json`
    } else {
      return jsonResponse({ error: 'unknown_action' }, 400)
    }

    const { data: updated, error } = await supabase
      .from('orders')
      .update(patch)
      .eq('order_id', orderId)
      .select()
      .single()
    if (error) throw error
    return jsonResponse(orderToJson(updated))
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})

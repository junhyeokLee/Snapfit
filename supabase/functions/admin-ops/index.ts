import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient } from '../_shared/supabase.ts'
import { loadOrder, advanceVerifiedOrder, withPrintOperations } from '../_shared/order-fulfillment.ts'
import { getPrintSnapshot, createPrintUploads, finalizePrintPackage, getPrintDownloadLinks } from '../_shared/print-package.ts'
import { OrderPaymentError } from '../_shared/order-types.ts'
import { calculateContribution } from '../_shared/print-contract.ts'
import { adminPagination, adminSearch, exactPage, adminIdentifier, adminPointCatalog } from '../_shared/admin-catalog.ts'

async function getOptionalJwtUser(req: Request) {
  const auth = req.headers.get('Authorization') ?? ''
  if (!auth.startsWith('Bearer ')) return null
  const url = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !anonKey) return null
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  })
  const { data } = await client.auth.getUser()
  return data.user ?? null
}

async function assertAdmin(req: Request, body: Record<string, unknown>) {
  const configuredKey = Deno.env.get('SNAPFIT_ADMIN_KEY') ?? Deno.env.get('ORDER_ADMIN_KEY') ?? ''
  const suppliedKey = req.headers.get('X-Admin-Key') ?? String(body.adminKey ?? '')
  if (configuredKey && suppliedKey && configuredKey === suppliedKey) return
  const user = await getOptionalJwtUser(req)
  if (user?.app_metadata?.role === 'admin') return
  throw new Error('forbidden')
}

function statusLabel(status: string) {
  const map: Record<string, string> = {
    PAYMENT_PENDING: '결제대기', PAYMENT_COMPLETED: '결제완료', IN_PRODUCTION: '제작중', PRINTING: '제작중',
    SHIPPING: '배송중', DELIVERED: '배송완료', CANCELED: '취소', CANCELLED: '취소',
  }
  return map[status] ?? status
}

function statusProgress(status: string) {
  const map: Record<string, number> = { PAYMENT_COMPLETED: .25, IN_PRODUCTION: .5, PRINTING: .5, SHIPPING: .75, DELIVERED: 1 }
  return map[status] ?? 0
}

function orderToJson(row: Record<string, unknown>) {
  const status = String(row.status ?? 'PAYMENT_PENDING')
  return {
    orderId: row.order_id, title: row.title ?? '주문', amount: row.amount ?? 0, pageCount: row.page_count,
    pricingVersion: row.pricing_version, printProductSnapshot: row.print_product_snapshot,
    status, statusLabel: statusLabel(status), progress: statusProgress(status), orderedAt: row.ordered_at ?? row.created_at,
    albumId: row.album_id, recipientName: row.recipient_name, recipientPhone: row.recipient_phone, zipCode: row.zip_code,
    addressLine1: row.address_line1, addressLine2: row.address_line2, deliveryMemo: row.delivery_memo,
    paymentMethod: row.payment_method, courier: row.courier, trackingNumber: row.tracking_number,
    printVendor: row.print_vendor, printVendorOrderId: row.print_vendor_order_id,
    printPackageJsonUrl: row.print_package_json_url, printFilePdfUrl: row.print_file_pdf_url,
    printFileZipUrl: row.print_file_zip_url, printAssetCount: row.print_asset_count,
    paymentConfirmedAt: row.payment_confirmed_at, printPackageGeneratedAt: row.print_package_generated_at,
    printSubmittedAt: row.print_submitted_at, shippedAt: row.shipped_at, deliveredAt: row.delivered_at,
    printFulfillmentStatus: row.print_fulfillment_status, printCoverPdfPath: row.print_cover_pdf_path,
    printInteriorPdfPath: row.print_interior_pdf_path, printManifest: row.print_manifest,
    printCostSnapshot: row.print_cost_snapshot, actualPrintCost: row.actual_print_cost,
    actualShippingCost: row.actual_shipping_cost, actualPackagingCost: row.actual_packaging_cost,
    contributionMargin: row.contribution_margin, printAcceptedAt: row.print_accepted_at,
    fulfillmentMethod: row.fulfillment_method, fulfillmentConfirmation: row.fulfillment_confirmation,
    senderLabelConfirmed: row.sender_label_confirmed, priceSlipOmittedConfirmed: row.price_slip_omitted_confirmed,
    promotionalMaterialsOmittedConfirmed: row.promotional_materials_omitted_confirmed,
    printReviewNote: row.print_review_note, printSpecConfirmedAt: row.print_spec_confirmed_at,
    printSpecOverride: row.print_spec_override,

  }
}

function templateRow(row: Record<string, unknown>) {
  return {
    id: row.id, title: row.title ?? '', subTitle: row.sub_title, description: row.description,
    coverImageUrl: row.cover_image_url, previewImages: row.preview_images ?? [], pageCount: row.page_count ?? 0,
    likeCount: row.like_count ?? 0, userCount: row.user_count ?? 0, category: row.category ?? '', tags: row.tags ?? [],
    weeklyScore: row.weekly_score ?? 0, isNew: row.is_new === true, isBest: row.is_best === true,
    isPremium: row.is_premium === true, active: row.is_active !== false, templateJson: row.template_json,
    createdAt: row.created_at, newUntil: row.new_until,
  }
}

function parseJsonish(value: unknown) {
  if (Array.isArray(value) || (value && typeof value === 'object')) return value
  if (typeof value === 'string' && value.trim()) {
    try { return JSON.parse(value) } catch { return value.split(',').map((s) => s.trim()).filter(Boolean) }
  }
  return []
}

function templatePayload(payload: Record<string, unknown>) {
  return {
    ...(payload.id ? { id: Number(payload.id) } : {}),
    title: String(payload.title ?? '').trim(),
    sub_title: payload.subTitle ?? payload.subtitle ?? null,
    description: payload.description ?? null,
    cover_image_url: payload.coverImageUrl ?? null,
    preview_images: parseJsonish(payload.previewImages ?? payload.previewImagesJson),
    page_count: Number(payload.pageCount ?? 0),
    like_count: Number(payload.likeCount ?? 0),
    user_count: Number(payload.userCount ?? 0),
    category: payload.category ?? null,
    tags: parseJsonish(payload.tags ?? payload.tagsJson),
    weekly_score: Number(payload.weeklyScore ?? 0),
    is_new: payload.isNew === true,
    is_best: payload.isBest === true,
    is_premium: payload.isPremium === true,
    is_active: payload.active !== false,
    template_json: payload.templateJson ?? '{}',
    new_until: payload.newUntil ?? null,
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>
    await assertAdmin(req, body)
    const action = String(body.action ?? '').trim()
    const supabase = adminClient()
    const now = new Date().toISOString()

    if (action === 'dashboard') {
      const [users, users24, templates, templatesActive, orders, orders24, billingApproved24, billingFailed24] = await Promise.all([
        supabase.from('profiles').select('id', { count: 'exact', head: true }),
        supabase.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', new Date(Date.now() - 86400_000).toISOString()),
        supabase.from('templates').select('id', { count: 'exact', head: true }),
        supabase.from('templates').select('id', { count: 'exact', head: true }).eq('is_active', true),
        supabase.from('orders').select('order_id', { count: 'exact', head: true }),
        supabase.from('orders').select('order_id', { count: 'exact', head: true }).gte('created_at', new Date(Date.now() - 86400_000).toISOString()),
        supabase.from('billing_orders').select('id', { count: 'exact', head: true }).eq('status', 'APPROVED').gte('created_at', new Date(Date.now() - 86400_000).toISOString()),
        supabase.from('billing_orders').select('id', { count: 'exact', head: true }).eq('status', 'FAILED').gte('created_at', new Date(Date.now() - 86400_000).toISOString()),
      ])
      for (const result of [users, users24, templates, templatesActive, orders, orders24, billingApproved24, billingFailed24]) {
        if (result.error) throw result.error
        if (!Number.isSafeInteger(result.count) || Number(result.count) < 0) throw new OrderPaymentError('admin_data_unavailable', 502)
      }
      return jsonResponse({
        generatedAt: now,
        users: { total: users.count, new24h: users24.count },
        templates: { total: templates.count, active: templatesActive.count },
        orders: { total: orders.count, new24h: orders24.count },
        billing: { approved24h: billingApproved24.count, failed24h: billingFailed24.count },
      })
    }

    if (['pointProducts', 'updatePointProduct', 'upsertPointProduct'].includes(action)) return jsonResponse(await adminPointCatalog(supabase, action, body))

    if (action === 'getOrder') {
      const orderId = adminIdentifier(body.orderId, 'orderId_required')
      return jsonResponse(orderToJson(await withPrintOperations(supabase, await loadOrder(supabase, orderId))))
    }

    if (action === 'csSignals') {
      const { page, size } = adminPagination(body)
      const result = exactPage(await supabase.from('support_inquiries').select('*', { count: 'exact' }).neq('status', 'RESOLVED')
        .order('created_at', { ascending: false }).range(page * size, page * size + size - 1), page, size)
      return jsonResponse({ ...result, items: result.items.map((r) => ({ id: r.id, type: 'support', severity: 'medium', code: String(r.status ?? 'OPEN'),
        title: r.subject ?? '문의', message: r.message ?? '', orderId: r.order_id ?? '', userId: r.user_id ?? '', updatedAt: r.updated_at ?? r.created_at })) })
    }

    if (action === 'orders') {
      const { page, size } = adminPagination(body)
      let q = supabase.from('orders').select('*', { count: 'exact' })
      const allowedStatuses = ['PAYMENT_PENDING','PAYMENT_COMPLETED','IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED','CANCELED','CANCELLED']
      if (body.statuses != null && (!Array.isArray(body.statuses) || body.statuses.some(status => !allowedStatuses.includes(String(status))))) throw new OrderPaymentError('invalid_order_status')
      const statuses = Array.isArray(body.statuses) ? body.statuses.map(String) : []
      if (statuses.length) q = q.in('status', statuses)
      const search = adminSearch(body, ['order_id','title','recipient_name'])
      if (search) q = q.or(search)
      const result = exactPage(await q.order('ordered_at', { ascending: false }).order('order_id', { ascending: false }).range(page * size, page * size + size - 1), page, size)
      const items = await Promise.all(result.items.map(async row => orderToJson(await withPrintOperations(supabase, row))))
      return jsonResponse({ ...result, items })
    }

    if (['getPrintSnapshot', 'createPrintUploads', 'finalizePrintPackage', 'getPrintDownloadLinks', 'evaluatePrintCosts'].includes(action)) {
      const orderId = String(body.orderId ?? '').trim()
      if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
      const order = await withPrintOperations(supabase, await loadOrder(supabase, orderId))
      if (action === 'evaluatePrintCosts') {
        const costs = calculateContribution(order, body, false)
        const minimumContribution = Math.max(10000, Number((order.print_cost_snapshot as any)?.minimumContribution ?? 10000))
        return jsonResponse({ actualPrintCost: costs.actual_print_cost, actualShippingCost: costs.actual_shipping_cost,
          actualPackagingCost: costs.actual_packaging_cost, paymentFeeReserve: costs.payment_fee_reserve,
          reprintReserve: costs.reprint_reserve, operationsReserve: costs.operations_reserve,
          contributionMargin: costs.contribution_margin, minimumContribution, passesMinimum: costs.contribution_margin >= minimumContribution,
          minContributionMargin: minimumContribution, eligible: costs.contribution_margin >= minimumContribution })
      }
      if (action === 'getPrintSnapshot') return jsonResponse(await getPrintSnapshot(supabase, order, Deno.env.get('SUPABASE_URL') ?? ''))
      if (action === 'createPrintUploads') return jsonResponse(await createPrintUploads(supabase, order))
      if (action === 'getPrintDownloadLinks') return jsonResponse(await getPrintDownloadLinks(supabase, order))
      return jsonResponse(orderToJson(await withPrintOperations(supabase, await finalizePrintPackage(supabase, order, body))))
    }

    if (['markShipping', 'markDelivered', 'preparePrintPackage', 'markPrintReviewed', 'submitPrintVendor', 'acceptPrintVendor', 'configurePrintSpec'].includes(action)) {
      const orderId = String(body.orderId ?? '').trim()
      if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
      const order = await withPrintOperations(supabase, await loadOrder(supabase, orderId))
      const normalizedAction = action === 'markShipping' ? 'shipping' : action === 'markDelivered' ? 'delivered' : action
      const data = await advanceVerifiedOrder(supabase, order, normalizedAction, body)
      return jsonResponse(orderToJson(data))
    }

    if (action === 'templates') {
      const { page, size } = adminPagination(body)
      let q = supabase.from('templates').select('*', { count: 'exact' })
      const search = adminSearch(body, ['title'])
      if (search) q = q.or(search)
      const result = exactPage(await q.order('created_at', { ascending: false }).order('id', { ascending: false }).range(page * size, page * size + size - 1), page, size)
      const items = result.items.map(templateRow).map((t) => ({ id: t.id, title: t.title, active: t.active, pageCount: t.pageCount, category: t.category, likeCount: t.likeCount, userCount: t.userCount }))
      return jsonResponse({ ...result, items })
    }

    if (action === 'templateDetail') {
      const id = Number(body.templateId)
      const { data, error } = await supabase.from('templates').select('*').eq('id', id).single()
      if (error) throw error
      return jsonResponse(templateRow(data))
    }

    if (action === 'upsertTemplate') {
      const payload = templatePayload((body.payload ?? {}) as Record<string, unknown>)
      if (!payload.title) return jsonResponse({ error: 'title_required' }, 400)
      const { data, error } = await supabase.from('templates').upsert(payload).select().single()
      if (error) throw error
      return jsonResponse(templateRow(data))
    }

    if (action === 'setTemplateActive') {
      const id = Number(body.templateId)
      const active = body.active !== false
      const { data, error } = await supabase.from('templates').update({ is_active: active }).eq('id', id).select().single()
      if (error) throw error
      return jsonResponse(templateRow(data))
    }

    return jsonResponse({ error: 'unknown_action' }, 400)
  } catch (e) {
    console.error('admin_operation_failed', e instanceof OrderPaymentError ? e.message : 'database_or_network_error')
    const message = e instanceof Error ? e.message : String(e)
    return jsonResponse({ error: e instanceof OrderPaymentError ? e.message : message === 'forbidden' ? 'forbidden' : 'admin_operation_failed' }, e instanceof OrderPaymentError ? e.status : message === 'forbidden' ? 403 : 500)
  }
})

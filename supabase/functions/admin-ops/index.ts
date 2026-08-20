import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient } from '../_shared/supabase.ts'

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
  return map[status] ?? '결제대기'
}

function statusProgress(status: string) {
  const map: Record<string, number> = { PAYMENT_COMPLETED: .25, IN_PRODUCTION: .5, PRINTING: .5, SHIPPING: .75, DELIVERED: 1 }
  return map[status] ?? 0
}

function orderToJson(row: Record<string, unknown>) {
  const status = String(row.status ?? 'PAYMENT_PENDING')
  return {
    orderId: row.order_id, title: row.title ?? '주문', amount: row.amount ?? 0, pageCount: row.page_count,
    status, statusLabel: statusLabel(status), progress: statusProgress(status), orderedAt: row.ordered_at ?? row.created_at,
    albumId: row.album_id, recipientName: row.recipient_name, recipientPhone: row.recipient_phone, zipCode: row.zip_code,
    addressLine1: row.address_line1, addressLine2: row.address_line2, deliveryMemo: row.delivery_memo,
    paymentMethod: row.payment_method, courier: row.courier, trackingNumber: row.tracking_number,
    printVendor: row.print_vendor, printVendorOrderId: row.print_vendor_order_id,
    printPackageJsonUrl: row.print_package_json_url, printFilePdfUrl: row.print_file_pdf_url,
    printFileZipUrl: row.print_file_zip_url, printAssetCount: row.print_asset_count,
    paymentConfirmedAt: row.payment_confirmed_at, printPackageGeneratedAt: row.print_package_generated_at,
    printSubmittedAt: row.print_submitted_at, shippedAt: row.shipped_at, deliveredAt: row.delivered_at,
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
      return jsonResponse({
        generatedAt: now,
        users: { total: users.count ?? 0, new24h: users24.count ?? 0 },
        templates: { total: templates.count ?? 0, active: templatesActive.count ?? 0 },
        orders: { total: orders.count ?? 0, new24h: orders24.count ?? 0 },
        billing: { approved24h: billingApproved24.count ?? 0, failed24h: billingFailed24.count ?? 0 },
      })
    }

    if (action === 'csSignals') {
      const limit = Number(body.limit ?? 50)
      const { data } = await supabase.from('support_inquiries').select('*').neq('status', 'RESOLVED').order('created_at', { ascending: false }).limit(limit)
      return jsonResponse({ items: (data ?? []).map((r) => ({ type: 'support', severity: 'medium', code: String(r.status ?? 'OPEN'), title: r.subject ?? '문의', message: r.message ?? '', orderId: '', userId: r.user_id ?? '', updatedAt: r.updated_at ?? r.created_at })) })
    }

    if (action === 'orders') {
      const page = Number(body.page ?? 0), size = Number(body.size ?? 20)
      let q = supabase.from('orders').select('*')
      const statuses = Array.isArray(body.statuses) ? body.statuses.map(String) : []
      if (statuses.length) q = q.in('status', statuses)
      const keyword = String(body.keyword ?? '').trim()
      if (keyword) q = q.or(`order_id.ilike.%${keyword}%,title.ilike.%${keyword}%,recipient_name.ilike.%${keyword}%`)
      const { data, error } = await q.order('ordered_at', { ascending: false }).range(page * size, page * size + size - 1)
      if (error) throw error
      const items = (data ?? []).map(orderToJson)
      return jsonResponse({ items, page, size, totalPages: items.length < size ? page + 1 : page + 2, totalElements: page * size + items.length, hasNext: items.length === size })
    }

    if (action === 'markShipping' || action === 'markDelivered' || action === 'preparePrintPackage') {
      const orderId = String(body.orderId ?? '').trim()
      if (!orderId) return jsonResponse({ error: 'orderId_required' }, 400)
      const patch: Record<string, unknown> = {}
      if (action === 'markShipping') { patch.status = 'SHIPPING'; patch.courier = body.courier ?? null; patch.tracking_number = body.trackingNumber ?? null; patch.shipped_at = now }
      if (action === 'markDelivered') { patch.status = 'DELIVERED'; patch.delivered_at = now }
      if (action === 'preparePrintPackage') { patch.status = 'IN_PRODUCTION'; patch.print_package_generated_at = now; patch.print_package_json_url = `supabase://print-packages/${orderId}.json` }
      const { data, error } = await supabase.from('orders').update(patch).eq('order_id', orderId).select().single()
      if (error) throw error
      return jsonResponse(orderToJson(data))
    }

    if (action === 'templates') {
      const page = Number(body.page ?? 0), size = Number(body.size ?? 20)
      const { data, error } = await supabase.from('templates').select('*').order('created_at', { ascending: false }).range(page * size, page * size + size - 1)
      if (error) throw error
      const items = (data ?? []).map(templateRow).map((t) => ({ id: t.id, title: t.title, active: t.active, pageCount: t.pageCount, category: t.category, likeCount: t.likeCount, userCount: t.userCount }))
      return jsonResponse({ items, page, hasNext: items.length === size })
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
    console.error(e)
    const message = String(e?.message ?? e)
    return jsonResponse({ error: message }, message === 'forbidden' ? 403 : 500)
  }
})

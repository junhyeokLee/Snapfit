import { OrderPaymentError } from './order-types.ts'

export function adminPagination(body: Record<string, unknown>) {
  const page = body.page ?? 0, size = body.size ?? body.limit ?? 20
  if (!Number.isSafeInteger(page) || Number(page) < 0 || Number(page) > 10000 ||
      !Number.isSafeInteger(size) || Number(size) < 1 || Number(size) > 100) throw new OrderPaymentError('invalid_pagination')
  return { page: Number(page), size: Number(size) }
}

export function adminSearch(body: Record<string, unknown>, columns: string[]) {
  if (body.keyword != null && typeof body.keyword !== 'string') throw new OrderPaymentError('invalid_keyword')
  const keyword = String(body.keyword ?? '').trim()
  if (keyword.length > 100 || /[\x00-\x1f\x7f]/.test(keyword)) throw new OrderPaymentError('invalid_keyword')
  if (!keyword) return null
  // PostgREST quoted values keep commas, parentheses and operators inside the
  // search term. Escape LIKE wildcards independently of the filter grammar.
  const term = `%${keyword.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/[%_*]/g, '\\$&')}%`
  return columns.map(column => `${column}.ilike."${term}"`).join(',')
}

export function exactPage(result: { data: unknown; error: unknown; count: number | null }, page: number, size: number) {
  if (result.error) throw result.error
  if (!Array.isArray(result.data) || !Number.isSafeInteger(result.count) || Number(result.count) < 0) throw new OrderPaymentError('admin_data_unavailable', 502)
  const totalElements = Number(result.count)
  return { items: result.data, page, size, totalElements, totalPages: Math.ceil(totalElements / size), hasNext: (page + 1) * size < totalElements }
}

export function adminIdentifier(value: unknown, error = 'invalid_identifier') {
  if (typeof value !== 'string' || !value.trim() || value.length > 200 || /[\x00-\x1f\x7f]/.test(value)) throw new OrderPaymentError(error)
  return value.trim()
}

function pointRow(row: Record<string, unknown>) {
  return { productKey: row.product_key, assetId: row.asset_id, kind: row.kind, title: row.title,
    pointPrice: row.point_price, isActive: row.is_active, updatedAt: row.updated_at }
}
const kinds = ['template','sticker','phrase','frame']
function pointKey(value: unknown) {
  const key = adminIdentifier(value, 'invalid_point_product')
  if (!/^(template|sticker|phrase|frame):[A-Za-z0-9_-][A-Za-z0-9._/-]{0,179}$/.test(key)) throw new OrderPaymentError('invalid_point_product')
  return key
}
function pointPricing(body: Record<string, unknown>) {
  const price = body.pointPrice, active = body.isActive
  if (typeof active !== 'boolean' || !(price === null || (Number.isSafeInteger(price) && Number(price) >= 0 && Number(price) <= 2147483647)) ||
      (active && price === null)) throw new OrderPaymentError('invalid_point_product')
  return { point_price: price, is_active: active }
}

// Called only after admin-ops assertAdmin. Catalog mutations never create point
// ledger rows, ownership rows, physical payments, or a new product identifier.
export async function adminPointCatalog(supabase: any, action: string, body: Record<string, unknown>) {
  if (action === 'pointProducts') {
    const { page, size } = adminPagination(body)
    let query = supabase.from('point_shop_products').select('*', { count: 'exact' })
    if (body.kind != null && body.kind !== '') {
      if (!kinds.includes(String(body.kind))) throw new OrderPaymentError('invalid_point_product')
      query = query.eq('kind', body.kind)
    }
    const search = adminSearch(body, ['product_key','title'])
    if (search) query = query.or(search)
    const result = exactPage(await query.order('title', { ascending: true }).order('product_key', { ascending: true }).range(page * size, page * size + size - 1), page, size)
    return { ...result, items: result.items.map(pointRow) }
  }
  const key = pointKey(body.productKey), pricing = pointPricing(body)
  const { data: existing, error: readError } = await supabase.from('point_shop_products').select('*').eq('product_key', key).maybeSingle()
  if (readError) throw readError
  if (body.expectedUpdatedAt != null && (typeof body.expectedUpdatedAt !== 'string' || body.expectedUpdatedAt !== existing?.updated_at)) throw new OrderPaymentError('point_product_changed', 409)
  let query
  if (action === 'upsertPointProduct') {
    const title = adminIdentifier(body.title, 'invalid_point_product'), kind = String(body.kind ?? ''), assetId = String(body.assetId ?? '')
    if (!kinds.includes(kind) || `${kind}:${assetId}` !== key) throw new OrderPaymentError('invalid_point_product')
    if (existing) query = supabase.from('point_shop_products').update({ title, ...pricing }).eq('product_key', key).eq('updated_at', existing.updated_at)
    else query = supabase.from('point_shop_products').insert({ product_key: key, asset_id: assetId, kind, title, ...pricing })
  } else if (action === 'updatePointProduct') {
    if (!existing) throw new OrderPaymentError('point_product_not_found', 404)
    query = supabase.from('point_shop_products').update(pricing).eq('product_key', key).eq('updated_at', existing.updated_at)
  } else throw new OrderPaymentError('unknown_action')
  const { data, error } = await query.select('*').maybeSingle()
  if (error?.code === '23505') throw new OrderPaymentError('point_product_changed', 409)
  if (error) throw error
  if (!data) throw new OrderPaymentError('point_product_changed', 409)
  return pointRow(data)
}

import { corsHeaders } from './cors.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'
import { adminPagination, adminSearch, exactPage } from './admin-catalog.ts'

const reply = (data: unknown, status = 200) => Response.json(data, {
  status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
})
export function validateCuration(body: Record<string, unknown>) {
  const { placement, title, subtitle, enabled, productKeys, expectedVersion } = body
  if (!['templates','materials'].includes(String(placement)) || typeof title !== 'string' ||
      !title.trim() || [...title.trim()].length > 48 || typeof subtitle !== 'string' || [...subtitle].length > 120 ||
      typeof enabled !== 'boolean' || !Number.isSafeInteger(expectedVersion) || Number(expectedVersion) < 1 ||
      !Array.isArray(productKeys) || productKeys.length > 12 || new Set(productKeys).size !== productKeys.length ||
      productKeys.some(k => typeof k !== 'string' || k.length > 200 ||
        !(placement === 'templates' ? /^template:[A-Za-z0-9_-][A-Za-z0-9._/-]*$/ : /^(frame|sticker|phrase):[A-Za-z0-9_-][A-Za-z0-9._/-]*$/).test(k))) {
    throw new Error('invalid_curation')
  }
  return { p_placement: placement, p_title: title.trim(), p_subtitle: subtitle.trim(),
    p_enabled: enabled, p_product_keys: productKeys, p_expected_version: expectedVersion }
}
export function createStoreCurationHandler(deps: { getUser: VerifiedUserLookup; createAdminDatabase(): any }) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      await assertRedprintingAdmin(req, deps.getUser)
      const text = await req.text()
      if (text.length > 8192) return reply({ error: 'invalid_curation' }, 400)
      let body: Record<string, unknown>
      try { body = JSON.parse(text) } catch { return reply({ error: 'invalid_curation' }, 400) }
      if (!body || typeof body !== 'object' || Array.isArray(body)) return reply({ error: 'invalid_curation' }, 400)
      const db = deps.createAdminDatabase()
      if (body.action === 'overview') {
        const { data, error } = await db.from('store_curations').select('*').order('placement')
        if (error) throw error
        return reply({ items: data })
      }
      if (body.action === 'candidates') {
        if (!['templates','materials'].includes(String(body.placement))) return reply({ error: 'invalid_curation' }, 400)
        const { page, size } = adminPagination(body)
        let q = db.from('point_shop_products').select('product_key,kind,title,point_price,is_active', { count: 'exact' })
          .eq('is_active', true).not('point_price', 'is', null)
          .in('kind', body.placement === 'templates' ? ['template'] : ['frame','sticker','phrase'])
        const search = adminSearch(body, ['title','product_key'])
        if (search) q = q.or(search)
        return reply(exactPage(await q.order('title').order('product_key').range(page * size, page * size + size - 1), page, size))
      }
      if (body.action === 'save') {
        const args = validateCuration(body)
        const { data, error } = await db.rpc('save_store_curation', args).single()
        if (error) {
          if (error.message?.includes('curation_changed')) return reply({ error: 'curation_changed' }, 409)
          if (error.message?.includes('curation_product_unavailable')) return reply({ error: 'curation_product_unavailable' }, 400)
          throw error
        }
        return reply({ item: data })
      }
      return reply({ error: 'unknown_action' }, 400)
    } catch (error) {
      if (error instanceof RedprintingAdminAuthError) return reply({ error: error.code }, error.status)
      const code = error instanceof Error ? error.message : ''
      if (['invalid_curation','invalid_pagination','invalid_keyword'].includes(code)) return reply({ error: code }, 400)
      return reply({ error: 'curation_unavailable' }, 503)
    }
  }
}

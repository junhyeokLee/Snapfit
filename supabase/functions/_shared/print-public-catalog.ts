import { corsHeaders } from './cors.ts'
import { PRINT_PRODUCTS } from './print-contract.ts'

type Database = { rpc(name: string, params: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }> }
type Dependencies = { createAdminDatabase(): Database; now?: () => number }
const reply = (body: unknown, status = 200) => Response.json(body, {
  status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
})
export function createPrintPublicCatalogHandler(deps: Dependencies) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'GET') return reply({ error: 'method_not_allowed' }, 405)
    if (new URL(req.url).search) return reply({ error: 'invalid_catalog_request' }, 400)
    try {
      const { data, error } = await deps.createAdminDatabase().rpc('read_print_public_catalog', {})
      if (error || !Array.isArray(data) || data.length < 1 || data.length > 310) throw Error('unavailable')
      const seen = new Set<string>()
      const items = data.map(raw => {
        const r = raw as Record<string, unknown>, id = `${r?.productId}:${r?.pageCount}`
        if (!r || !Object.hasOwn(PRINT_PRODUCTS, String(r.productId)) ||
          !Number.isSafeInteger(r.pageCount) || Number(r.pageCount) < 20 || Number(r.pageCount) > 80 || Number(r.pageCount) % 2 ||
          !Number.isSafeInteger(r.retailPrice) || Number(r.retailPrice) < 1 || Number(r.retailPrice) > 100000000 ||
          r.shippingIncluded !== true || r.shippingFee !== 0 || r.priceIsEstimate !== true || r.priceSource !== 'SERVER_PLANNED' ||
          typeof r.orderCodeApproved !== 'boolean' || typeof r.priceVersion !== 'string' || !/^[A-Za-z0-9_.-]{1,120}$/.test(r.priceVersion) || seen.has(id)) throw Error('unavailable')
        seen.add(id)
        // Explicit allowlist: never forward database objects or new private fields.
        return { productId: r.productId, pageCount: r.pageCount, retailPrice: r.retailPrice,
          shippingFee: 0, shippingIncluded: true, priceIsEstimate: true, priceSource: 'SERVER_PLANNED',
          priceVersion: r.priceVersion, orderCodeApproved: r.orderCodeApproved }
      })
      return reply({ generatedAt: new Date(deps.now?.() ?? Date.now()).toISOString(), currency: 'KRW', salesOpen: false,
        shippingNotice: '부가세와 기본 배송비를 포함한 예정 판매가입니다. 도서산간 추가 배송비와 최종 판매가는 출시 전에 확정합니다. 현재 결제와 주문 접수는 열리지 않았습니다.', items })
    } catch {
      return reply({ error: 'print_catalog_unavailable' }, 503)
    }
  }
}

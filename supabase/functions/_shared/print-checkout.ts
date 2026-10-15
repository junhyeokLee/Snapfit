import { corsHeaders } from './cors.ts'
import { publicPrintQuoteField } from './print-public-quote.ts'

type RpcError = { code?: unknown; message?: unknown }
export type PrintCheckoutUserClient = {
  auth: {
    getUser(): Promise<{ data: { user: { id?: unknown } | null }; error: unknown }>
  }
  rpc(name: 'get_print_order_quote', parameters: {
    p_album_id: number; p_page_count: number | null
  }): PromiseLike<{ data: unknown; error: RpcError | null }>
}
export type PrintCheckoutUserClientFactory = (request: Request) => PrintCheckoutUserClient

const productIds = new Set([
  'REDP_200X150_SOFT', 'REDP_200_SOFT', 'REDP_250X200_SOFT', 'REDP_250_SOFT', 'REDP_300_SOFT',
  'REDP_200X150_HARD', 'REDP_200_HARD', 'REDP_250X200_HARD', 'REDP_250_HARD', 'REDP_300_HARD',
])
// The public quotation is deliberately separate from private procurement costs,
// supplier correspondence, payment evidence, and recipient data.
const publicQuoteFields = [
  'pageCount', 'amount', 'basePages', 'basePrice', 'extraPageCount', 'extraPagePrice', 'pricePerTwoPages',
  'sourcePageCount', 'addedBlankPageCount', 'productCode', 'productName', 'printProduct', 'coverType', 'coverLabel',
  'trimWidthMm', 'trimHeightMm', 'shippingIncluded', 'maxPages', 'layoutFit', 'pricingVersion',
  'pricePolicyVersion', 'retailPriceStatus', 'priceIsEstimate', 'supplierCostVerified',
  'shippingCostVerified', 'packagingCostVerified', 'specMissing', 'printPdfAvailable',
  'printTemplateStatus', 'priceNotice', 'spec',
] as const

function reply(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
  })
}

function input(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  const body = value as Record<string, unknown>
  if (Object.keys(body).some(key => key !== 'albumId' && key !== 'pageCount')) return null
  if (!Number.isSafeInteger(body.albumId) || Number(body.albumId) <= 0) return null
  if (body.pageCount != null && (!Number.isSafeInteger(body.pageCount) ||
      Number(body.pageCount) < 20 || Number(body.pageCount) > 80 || Number(body.pageCount) % 2 !== 0)) return null
  return { p_album_id: Number(body.albumId), p_page_count: body.pageCount == null ? null : Number(body.pageCount) }
}

function publicQuote(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  const quote = value as Record<string, unknown>
  if (!Number.isSafeInteger(quote.pageCount) || Number(quote.pageCount) < 20 || Number(quote.pageCount) > 80 ||
      Number(quote.pageCount) % 2 !== 0 || !Number.isSafeInteger(quote.amount) || Number(quote.amount) <= 0 ||
      !Number.isSafeInteger(quote.sourcePageCount) || Number(quote.sourcePageCount) < 0 ||
      Number(quote.sourcePageCount) > Number(quote.pageCount) || typeof quote.productCode !== 'string' ||
      !productIds.has(quote.productCode) || quote.pricingVersion !== 'PRINT_REDP_COVERTYPE_V3' ||
      typeof quote.pricePolicyVersion !== 'string' || !quote.pricePolicyVersion.trim() ||
      !['FINAL', 'PLANNED', 'PENDING_SUPPLIER_QUOTE'].includes(String(quote.retailPriceStatus))) return null
  return Object.fromEntries(publicQuoteFields.filter(key => Object.hasOwn(quote, key)).map(key => [key, publicPrintQuoteField(key, quote[key])]))
}

/**
 * Read-only checkout preparation. A supplier quotation, client flag, or a saved
 * development key cannot enable sales. Enabling payment requires a separate
 * verified production contract; this handler never inserts an order or pays.
 */
export function createPrintCheckoutStatusHandler(createUserClient: PrintCheckoutUserClientFactory) {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    if (!/^Bearer [^\s]+$/i.test(request.headers.get('Authorization') ?? '')) {
      return reply({ error: 'authentication_required' }, 401)
    }
    let client: PrintCheckoutUserClient
    try { client = createUserClient(request) }
    catch { return reply({ error: 'print_checkout_unavailable' }, 503) }
    try {
      // Use Auth's server lookup, never a decoded JWT, body user ID, or session
      // storage. The same user-scoped client then calls the access-checking RPC.
      const { data, error } = await client.auth.getUser()
      if (error || typeof data?.user?.id !== 'string' || !data.user.id.trim()) {
        return reply({ error: 'invalid_session' }, 401)
      }
    } catch { return reply({ error: 'invalid_session' }, 401) }

    let parameters: ReturnType<typeof input>
    try {
      const body = await request.text()
      if (body.length > 4096) return reply({ error: 'invalid_checkout_request' }, 400)
      parameters = input(JSON.parse(body))
    } catch { return reply({ error: 'invalid_checkout_request' }, 400) }
    if (!parameters) return reply({ error: 'invalid_checkout_request' }, 400)

    try {
      const { data, error } = await client.rpc('get_print_order_quote', parameters)
      if (error) {
        if (error.code === '42501' || error.code === 'P0002') return reply({ error: 'album_access_denied' }, 403)
        if (error.code === '22023') return reply({ error: 'print_album_not_supported' }, 400)
        return reply({ error: 'print_checkout_unavailable' }, 503)
      }
      const quote = publicQuote(data)
      if (!quote || Number(quote.pageCount) < (parameters.p_page_count ?? 20)) {
        return reply({ error: 'print_quote_unavailable' }, 503)
      }
      return reply({
        canPay: false,
        status: 'PREPARING',
        reasonCode: 'print_sales_not_ready',
        message: '인쇄 주문을 준비하고 있어요. 정식 주문이 열리면 결제할 수 있어요.',
        quote,
        // Recommended provider for the future integration, not a configured
        // payment channel. environment + canPay remain closed independently.
        paymentProvider: 'PORTONE',
        environment: 'unavailable',
      })
    } catch { return reply({ error: 'print_checkout_unavailable' }, 503) }
  }
}

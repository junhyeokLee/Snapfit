import { corsHeaders } from './cors.ts'
import { PRINT_PRODUCTS } from './print-contract.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'

type Database = { rpc(name: string, params: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }> }
type Dependencies = { getUser: VerifiedUserLookup; createAdminDatabase(): Database }
class PrintPricingError extends Error {
  constructor(readonly code: string, readonly status = 409) { super(code) }
}
const object = (v: unknown): Record<string, any> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, any> : {}
const money = (v: unknown, min = 0, max = 100000000): v is number => Number.isSafeInteger(v) && Number(v) >= min && Number(v) <= max
const revision = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v)
const version = (v: unknown): v is string => typeof v === 'string' && /^[A-Za-z0-9_.-]{1,120}$/.test(v)
const uuid = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v)
const timestamp = (v: unknown): v is string => typeof v === 'string' && Number.isFinite(Date.parse(v))
const keys = (b: Record<string, unknown>, allowed: string[]) => Object.keys(b).every(k => allowed.includes(k))
const reply = (v: unknown, status = 200) => Response.json(v, { status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' } })
export const printPricingConstants = { paymentFeeRate: .05, reprintReserveRate: .05, operationsReserve: 3000, minimumContribution: 10000, minimumContributionRate: .2 }
const message = '확인한 제작비에 예산을 반영한 예정 판매가예요. 변경하면 사용자 주문 화면의 새 견적에 반영되며, 이미 생성한 주문 금액과 실제 결제 개방 상태는 바뀌지 않아요. 예상 기여금은 세금·고정비·광고비 차감 전이에요.'
function invalidRecord(): never { throw new PrintPricingError('print_pricing_unavailable', 503) }
function metrics(raw: unknown) {
  const m = object(raw)
  if (!money(m.retailPrice, 1) || !money(m.shippingBudget, 0, 10000000) || !money(m.packagingBudget, 0, 10000000) ||
    !money(m.paymentFeeReserve) || !money(m.reprintReserve) || !money(m.operationsReserve) || !Number.isSafeInteger(m.estimatedContribution) ||
    typeof m.contributionRate !== 'number' || !Number.isFinite(m.contributionRate)) invalidRecord()
  return { retailPrice: m.retailPrice, shippingBudget: m.shippingBudget, packagingBudget: m.packagingBudget, paymentFeeReserve: m.paymentFeeReserve,
    reprintReserve: m.reprintReserve, operationsReserve: m.operationsReserve, estimatedContribution: m.estimatedContribution, contributionRate: m.contributionRate }
}
function row(raw: unknown) {
  const r = object(raw), s = object(r.source), e = object(r.effective), opts = object(s.options)
  if (typeof r.productId !== 'string' || !Object.hasOwn(PRINT_PRODUCTS, r.productId) || !Number.isSafeInteger(r.pageCount) || r.pageCount < 20 || r.pageCount > 80 || r.pageCount % 2 ||
    !revision(s.revision) || !money(s.supplyPrice, 1) || !money(s.vatPrice, 1) || !money(s.totalPrice, 1) || s.totalPrice !== s.supplyPrice + s.vatPrice ||
    s.currency !== 'KRW' || !['WEBSITE', 'API'].includes(s.source) || !timestamp(s.observedAt) || typeof s.evidence !== 'string' || s.evidence.length > 5000 ||
    !version(e.priceVersion) || !['PLANNED', 'FINAL'].includes(e.retailPriceStatus) || typeof r.locked !== 'boolean' || r.locked !== (e.retailPriceStatus === 'FINAL')) invalidRecord()
  let override = null
  if (r.override != null) {
    const o = object(r.override)
    if (!uuid(o.version) || !revision(o.sourceRevision) || !money(o.retailPrice, 1) || !money(o.shippingBudget, 0, 10000000) || !money(o.packagingBudget, 0, 10000000) ||
      typeof o.note !== 'string' || o.note.length > 1000 || !timestamp(o.updatedAt) || !uuid(o.updatedBy) || typeof o.stale !== 'boolean' || o.stale !== (o.sourceRevision !== s.revision)) invalidRecord()
    override = { version: o.version, sourceRevision: o.sourceRevision, retailPrice: o.retailPrice, shippingBudget: o.shippingBudget, packagingBudget: o.packagingBudget,
      note: o.note, updatedAt: o.updatedAt, updatedBy: o.updatedBy, stale: o.stale }
  }
  const options: Record<string, string> = {}
  for (const k of ['coverPaper', 'coverFinish', 'interiorPaper', 'interiorPrint', 'size', 'coverType', 'quantity']) if (typeof opts[k] === 'string' && opts[k].length <= 1000) options[k] = opts[k]
  return { productId: r.productId, productName: PRINT_PRODUCTS[r.productId as keyof typeof PRINT_PRODUCTS].productName, pageCount: r.pageCount,
    coverType: r.productId.endsWith('_HARD') ? 'HARD' : 'SOFT', source: { revision: s.revision, supplyPrice: s.supplyPrice, vatPrice: s.vatPrice, totalPrice: s.totalPrice,
      currency: 'KRW', source: s.source, observedAt: s.observedAt, evidence: s.evidence, options }, recommended: metrics(r.recommended),
    effective: { ...metrics(e), priceVersion: e.priceVersion, retailPriceStatus: e.retailPriceStatus }, override, locked: r.locked }
}
async function rpc(db: Database, name: string, params: Record<string, unknown>) {
  const response = await db.rpc(name, params)
  if (response.error) {
    const error = object(response.error), code = String(error.message ?? '')
    if (code === 'forbidden') throw new PrintPricingError(code, 403)
    if (['print_pricing_conflict', 'print_pricing_source_changed', 'print_pricing_locked'].includes(code)) throw new PrintPricingError(code)
    if (code === 'print_pricing_source_unavailable') throw new PrintPricingError(code, 404)
    if (code === 'print_pricing_margin_too_low') throw new PrintPricingError(code, 400)
    if (code === 'invalid_print_pricing' || error.code === '22023') throw new PrintPricingError('invalid_print_pricing', 400)
    throw new PrintPricingError('print_pricing_unavailable', 503)
  }
  return response.data
}
export function createPrintPricingAdminHandler(deps: Dependencies) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      const actor = await assertRedprintingAdmin(req, deps.getUser)
      if (!uuid(actor)) throw new RedprintingAdminAuthError('invalid_session', 401)
      const text = await req.text()
      if (text.length > 8192) throw new PrintPricingError('invalid_print_pricing', 400)
      let parsed: unknown
      try { parsed = JSON.parse(text) } catch { throw new PrintPricingError('invalid_print_pricing', 400) }
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new PrintPricingError('invalid_print_pricing', 400)
      const body = object(parsed)
      if (body.action === 'overview' && keys(body, ['action'])) {
        const rows = await rpc(deps.createAdminDatabase(), 'read_print_pricing_admin', { p_actor_id: actor })
        if (!Array.isArray(rows) || rows.length > 310) invalidRecord()
        return reply({ productionEnabled: false, canOpenSales: false, constants: printPricingConstants, rows: rows.map(row), message })
      }
      const save = body.action === 'save', reset = body.action === 'reset'
      if ((!save && !reset) || !keys(body, ['action', 'productId', 'pageCount', 'reviewedSourceRevision', 'expectedPriceVersion', 'note', ...(save ? ['retailPrice', 'shippingBudget', 'packagingBudget'] : [])]) ||
        typeof body.productId !== 'string' || !Object.hasOwn(PRINT_PRODUCTS, body.productId) || !Number.isSafeInteger(body.pageCount) || body.pageCount < 20 || body.pageCount > 80 || body.pageCount % 2 ||
        !revision(body.reviewedSourceRevision) || !version(body.expectedPriceVersion) || typeof body.note !== 'string' || body.note.trim().length < 1 || body.note.trim().length > 1000 ||
        (save && (!money(body.retailPrice, 1) || !money(body.shippingBudget, 0, 10000000) || !money(body.packagingBudget, 0, 10000000)))) throw new PrintPricingError('invalid_print_pricing', 400)
      const result = await rpc(deps.createAdminDatabase(), 'mutate_print_pricing_admin', { p_actor_id: actor, p_action: body.action, p_product_id: body.productId,
        p_page_count: body.pageCount, p_source_revision: body.reviewedSourceRevision, p_expected_price_version: body.expectedPriceVersion,
        p_retail_price: save ? body.retailPrice : null, p_shipping_budget: save ? body.shippingBudget : null, p_packaging_budget: save ? body.packagingBudget : null, p_note: body.note.trim() })
      return reply({ productionEnabled: false, canOpenSales: false, row: row(result), message })
    } catch (error) {
      if (error instanceof PrintPricingError || error instanceof RedprintingAdminAuthError) return reply({ error: error.code }, error.status)
      return reply({ error: 'print_pricing_unavailable' }, 503)
    }
  }
}

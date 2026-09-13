import { OrderPaymentError, assertExistingVerifiedPayment, type OrderRow } from './order-types.ts'

export const PRINT_PRICING_VERSION = 'PRINT_REDP_200_SOFT_V1'
export const PRINT_MULTI_PRICING_VERSION = 'PRINT_REDP_MULTISIZE_V2'
export const PRINT_COVER_PRICING_VERSION = 'PRINT_REDP_COVERTYPE_V3'
export const PRINT_SPEC_VERSION = 'REDP_200_SOFT_REVIEW_V1'
export const PRINT_BUCKET = 'print-packages'
export const PRINT_MAX_PDF_BYTES = 100 * 1024 * 1024

export const PRINT_PRODUCTS = {
  REDP_200X150_SOFT: { id: 'REDP_200X150_SOFT', trimWidthMm: 200, trimHeightMm: 150, productName: '20×15cm 소프트커버 포토북' },
  REDP_200_SOFT: { id: 'REDP_200_SOFT', trimWidthMm: 200, trimHeightMm: 200, productName: '20×20cm 소프트커버 포토북' },
  REDP_250X200_SOFT: { id: 'REDP_250X200_SOFT', trimWidthMm: 250, trimHeightMm: 200, productName: '25×20cm 소프트커버 포토북' },
  REDP_250_SOFT: { id: 'REDP_250_SOFT', trimWidthMm: 250, trimHeightMm: 250, productName: '25×25cm 소프트커버 포토북' },
  REDP_300_SOFT: { id: 'REDP_300_SOFT', trimWidthMm: 300, trimHeightMm: 300, productName: '30×30cm 소프트커버 포토북' },
  REDP_200X150_HARD: { id: 'REDP_200X150_HARD', trimWidthMm: 200, trimHeightMm: 150, productName: '20×15cm 하드커버 포토북' },
  REDP_200_HARD: { id: 'REDP_200_HARD', trimWidthMm: 200, trimHeightMm: 200, productName: '20×20cm 하드커버 포토북' },
  REDP_250X200_HARD: { id: 'REDP_250X200_HARD', trimWidthMm: 250, trimHeightMm: 200, productName: '25×20cm 하드커버 포토북' },
  REDP_250_HARD: { id: 'REDP_250_HARD', trimWidthMm: 250, trimHeightMm: 250, productName: '25×25cm 하드커버 포토북' },
  REDP_300_HARD: { id: 'REDP_300_HARD', trimWidthMm: 300, trimHeightMm: 300, productName: '30×30cm 하드커버 포토북' },
} as const

export const printCoverType = (id: string) => id.endsWith('_HARD') ? 'HARD' : 'SOFT'
export type PrintRect = { xMm: number; yMm: number; widthMm: number; heightMm: number }

// A casewrap is a vendor template, not two softcover pages placed side by side.
// Exact dimensions and the explicit cover TrimBox must come from that template.
export function validateHardCoverGeometry(value: unknown) {
  const geometry = parseJsonObject(value)
  if (geometry.construction !== 'casewrap' || !Number.isFinite(geometry.widthMm) || !Number.isFinite(geometry.heightMm) ||
      geometry.widthMm <= 0 || geometry.heightMm <= 0 || geometry.widthMm > 1000 || geometry.heightMm > 1000 ||
      !Number.isFinite(geometry.bleedMm) || geometry.bleedMm < 0 || geometry.bleedMm > 50) throw new OrderPaymentError('hardcover_template_required', 409)
  const readRect = (name: string): PrintRect => {
    const rect = geometry[name]
    if (!rect || !['xMm','yMm','widthMm','heightMm'].every(key => typeof rect[key] === 'number' && Number.isFinite(rect[key])) ||
        rect.xMm < 0 || rect.yMm < 0 || rect.widthMm <= 0 || rect.heightMm <= 0 ||
        rect.xMm + rect.widthMm > geometry.widthMm || rect.yMm + rect.heightMm > geometry.heightMm) throw new OrderPaymentError('invalid_hardcover_geometry', 409)
    return { xMm: rect.xMm, yMm: rect.yMm, widthMm: rect.widthMm, heightMm: rect.heightMm }
  }
  const front = readRect('front'), back = readRect('back'), trim = readRect('trim')
  if (back.xMm + back.widthMm >= front.xMm || [front,back].some(rect => rect.xMm < trim.xMm || rect.yMm < trim.yMm ||
      rect.xMm + rect.widthMm > trim.xMm + trim.widthMm || rect.yMm + rect.heightMm > trim.yMm + trim.heightMm)) throw new OrderPaymentError('invalid_hardcover_geometry', 409)
  return { widthMm: geometry.widthMm as number, heightMm: geometry.heightMm as number,
    construction: 'casewrap', bleedMm: geometry.bleedMm as number, front, back, trim }
}

export function hardCoverReviewGeometry(product: { trimWidthMm: number; trimHeightMm: number }, pageCount: number) {
  if (!Number.isSafeInteger(pageCount) || pageCount < 20 || pageCount > 80 || pageCount % 2) throw new OrderPaymentError('hardcover_template_required', 409)
  // Separate casewrap measurements from the official hardcover guides. The
  // unsampled page counts remain explicitly inferred and must be reviewed.
  const boardWidth = product.trimWidthMm + 6, boardHeight = product.trimHeightMm + 6
  const spine = Number((2.4 + .67 * pageCount / 2).toFixed(2))
  return validateHardCoverGeometry({ construction: 'casewrap', bleedMm: 20,
    widthMm: Number((2 * boardWidth + spine + 40).toFixed(2)), heightMm: boardHeight + 40,
    back: { xMm: 20, yMm: 20, widthMm: boardWidth, heightMm: boardHeight },
    front: { xMm: Number((20 + boardWidth + spine).toFixed(2)), yMm: 20, widthMm: boardWidth, heightMm: boardHeight },
    trim: { xMm: 20, yMm: 20, widthMm: Number((2 * boardWidth + spine).toFixed(2)), heightMm: boardHeight } })
}

export function validatePrintProduct(value: unknown) {
  const candidate = parseJsonObject(value)
  if (typeof candidate.id !== 'string' || !Object.hasOwn(PRINT_PRODUCTS, candidate.id)) throw new OrderPaymentError('invalid_print_product', 409)
  const product = PRINT_PRODUCTS[candidate.id as keyof typeof PRINT_PRODUCTS]
  if (!product || candidate.trimWidthMm !== product.trimWidthMm || candidate.trimHeightMm !== product.trimHeightMm) {
    throw new OrderPaymentError('invalid_print_product', 409)
  }
  return product
}

function albumRatio(value: unknown) {
  const raw = String(value ?? '').trim()
  const parts = raw.match(/^(\d+(?:\.\d+)?)\s*[:/]\s*(\d+(?:\.\d+)?)$/)
  const ratio = parts ? Number(parts[1]) / Number(parts[2]) : /^\d+(?:\.\d+)?$/.test(raw) ? Number(raw) : NaN
  if (!Number.isFinite(ratio) || ratio <= 0) throw new OrderPaymentError('unsupported_print_product', 409)
  return ratio
}

export function resolveAlbumPrintProduct(album: Record<string, any>) {
  const document = album.cover_layers_json ? parseJsonObject(album.cover_layers_json) : {}
  const ratio = albumRatio(album.ratio)
  if (document.printProduct != null) {
    const product = validatePrintProduct(document.printProduct)
    if (Math.abs(ratio - product.trimWidthMm / product.trimHeightMm) > .01) throw new OrderPaymentError('print_product_ratio_mismatch', 409)
    return product
  }
  if (Math.abs(ratio - 1) <= .01) return PRINT_PRODUCTS.REDP_200_SOFT
  if (Math.abs(ratio - 4 / 3) <= .01) return PRINT_PRODUCTS.REDP_200X150_SOFT
  throw new OrderPaymentError('unsupported_print_product', 409)
}

export function orderPrintProduct(order: OrderRow) {
  // The original purchased square contract cannot be changed by newer album
  // metadata or by adding a product selector after the purchase.
  if (order.pricing_version === PRINT_PRICING_VERSION) return PRINT_PRODUCTS.REDP_200_SOFT
  if (![PRINT_MULTI_PRICING_VERSION, PRINT_COVER_PRICING_VERSION].includes(String(order.pricing_version))) throw new OrderPaymentError('legacy_order_requires_review', 409)
  const snapshot = printSnapshot(order)
  const product = validatePrintProduct(order.print_product_snapshot)
  if (order.pricing_version === PRINT_MULTI_PRICING_VERSION && printCoverType(product.id) !== 'SOFT') throw new OrderPaymentError('print_product_version_mismatch', 409)
  if (validatePrintProduct(snapshot.printProduct).id !== product.id || resolveAlbumPrintProduct(snapshot.album).id !== product.id) {
    throw new OrderPaymentError('print_product_snapshot_mismatch', 409)
  }
  return product
}

export function parseJsonObject(value: unknown): Record<string, any> {
  if (typeof value === 'string') {
    try { value = JSON.parse(value) } catch { throw new OrderPaymentError('invalid_print_snapshot', 409) }
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new OrderPaymentError('invalid_print_snapshot', 409)
  return value as Record<string, any>
}

export function printSnapshot(order: OrderRow) {
  const snapshot = parseJsonObject(order.print_content_snapshot)
  if (!snapshot.album || !Array.isArray(snapshot.pages)) throw new OrderPaymentError('order_print_snapshot_missing', 409)
  return snapshot
}

export function sourceInteriorPageCount(snapshot: Record<string, any>): number {
  const raw = snapshot.album?.cover_layers_json
  if (raw) {
    const document = parseJsonObject(raw)
    if (Array.isArray(document.pages) && document.pages.length) {
      return document.pages.filter((page: any, index: number) => !(page.isCover ?? (Number(page.index ?? index) === 0))).length
    }
  }
  return snapshot.pages.length
}

export function assertPrintOrder(order: OrderRow) {
  assertExistingVerifiedPayment(order)
  if (order.status !== 'PAYMENT_COMPLETED') throw new OrderPaymentError('order_not_ready_for_print', 409)
  orderPrintProduct(order)
  if (!Number.isSafeInteger(order.page_count) || Number(order.page_count) < 20 || Number(order.page_count) > 80 || Number(order.page_count) % 2) {
    throw new OrderPaymentError('invalid_print_page_count', 409)
  }
  const snapshot = printSnapshot(order)
  if (sourceInteriorPageCount(snapshot) > Number(order.page_count)) throw new OrderPaymentError('print_snapshot_exceeds_paid_pages', 409)
}

// A review profile is explicit: no guessed spine is ever represented as a vendor
// approved template. A verified profile can be attached only by server configuration.
export function getPrintSpec(order: OrderRow) {
  const product = orderPrintProduct(order)
  const override = order.print_spec_override as Record<string, any> | null
  const isV3 = order.pricing_version === PRINT_COVER_PRICING_VERSION
  const coverType = printCoverType(product.id)
  if (coverType === 'HARD') {
    if (override && (!override.coverGeometry || !override.templateRevision)) throw new OrderPaymentError('hardcover_template_required', 409)
    const cover = override ? validateHardCoverGeometry(override.coverGeometry) : hardCoverReviewGeometry(product, Number(order.page_count))
    const spineMm = Number((cover.front.xMm - cover.back.xMm - cover.back.widthMm).toFixed(2))
    const geometryMeasured = !override && (Number(order.page_count) === 20 || (product.id === 'REDP_200X150_HARD' && Number(order.page_count) === 22) ||
      (product.id === 'REDP_300_HARD' && Number(order.page_count) === 80))
    return {
      id: product.id, specVersion: `${product.id}_REVIEW_V3_${override?.templateRevision ?? spineMm.toFixed(2)}`, verified: false,
      coverType, coverLabel: '하드커버', productName: product.productName, pageCount: Number(order.page_count),
      coverGeometrySource: override ? 'admin_override' : 'official_default', templateFamily: 'REDP_PHBKMYB_CASEWRAP',
      geometryMeasured,
      spineMm,
      geometrySource: override ? '관리자가 해당 규격/페이지수의 하드커버 업체 도면을 확인하여 입력'
        : geometryMeasured ? '해당 크기·페이지수 공식 하드커버 도면 측정. 보드 +6mm·감싸기20mm. 실제 제작 전 도면·색상·실물 검수 필요.'
          : '하드커버 공식 20/22/80페이지 도면 측정치에서 추정. 해당 크기·페이지수는 미측정이므로 도면과 대조 필요.',
      interior: { trimWidthMm: product.trimWidthMm, trimHeightMm: product.trimHeightMm, bleedMm: 5 }, cover,
      minInteriorPages: 20, maxInteriorPages: 80, pageMultiple: 2, dpi: 300, minimumPhotoPpi: 150, colorSpace: 'sRGB', layoutFit: 'contain',
      reviewRequired: ['vendor_casewrap_template','spine_and_hinges','bleed_and_color','physical_sample'],
    }
  }
  const spineMm = Number(override?.spineMm ?? (.52 + .67 * Number(order.page_count) / 2).toFixed(2))
  return {
    id: product.id, specVersion: `${order.pricing_version === PRINT_PRICING_VERSION ? PRINT_SPEC_VERSION : `${product.id}_REVIEW_V${isV3 ? 3 : 2}`}_${spineMm.toFixed(2)}`, verified: false,
    ...(isV3 ? { coverType, coverLabel: '소프트커버' } : {}),
    spineMm, geometrySource: override ? '관리자가 해당 페이지수 도면 확인' : order.pricing_version === PRINT_PRICING_VERSION
      ? '20/22/80페이지 공식 도면 측정치에서 추정. 해당 페이지수 도면과 대조 필요.'
      : '동일 용지의 책등 계산 추정. 해당 규격/페이지수 업체 도면과 대조 필요.',
    productName: product.productName, pageCount: Number(order.page_count),
    interior: { trimWidthMm: product.trimWidthMm, trimHeightMm: product.trimHeightMm, bleedMm: 5 },
    cover: { widthMm: 2 * product.trimWidthMm + 10 + spineMm, heightMm: product.trimHeightMm + 10,
      back: { xMm: 5, yMm: 5, widthMm: product.trimWidthMm, heightMm: product.trimHeightMm },
      front: { xMm: 5 + product.trimWidthMm + spineMm, yMm: 5, widthMm: product.trimWidthMm, heightMm: product.trimHeightMm } },
    minInteriorPages: 20, maxInteriorPages: 80, pageMultiple: 2,
    dpi: 300, minimumPhotoPpi: 150, colorSpace: 'sRGB', layoutFit: 'contain',
    reviewRequired: ['vendor_cover_template', 'spine_width', 'bleed_and_color', 'physical_sample'],
  }
}

export async function sha256(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest('SHA-256', new Uint8Array(bytes).buffer)
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('')
}

export async function sourceFingerprint(order: OrderRow) {
  const product = [PRINT_MULTI_PRICING_VERSION, PRINT_COVER_PRICING_VERSION].includes(String(order.pricing_version)) ? orderPrintProduct(order) : null
  return sha256(new TextEncoder().encode(JSON.stringify({
    orderId: order.order_id, snapshot: printSnapshot(order), pageCount: order.page_count, pricingVersion: order.pricing_version,
    ...(product ? { printProduct: { id: product.id, trimWidthMm: product.trimWidthMm, trimHeightMm: product.trimHeightMm } } : {}),
  })))
}

export function calculateContribution(order: OrderRow, body: Record<string, unknown>, enforceMinimum = true) {
  const values = ['actualPrintCost', 'actualShippingCost', 'actualPackagingCost'].map(key => {
    const value = body[key]
    if (!Number.isSafeInteger(value) || Number(value) < 0) throw new OrderPaymentError('actual_vendor_costs_required')
    return Number(value)
  })
  if (values[0] === 0) throw new OrderPaymentError('actual_vendor_costs_required')
  const snapshot = parseJsonObject(order.print_cost_snapshot)
  const feeRate = Number(snapshot.paymentFeeRate ?? .04)
  const reserveRate = Number(snapshot.reprintReserveRate ?? .05)
  const minimumContribution = Math.max(10000, Number(snapshot.minimumContribution ?? 10000))
  if (!Number.isSafeInteger(minimumContribution) || !Number.isSafeInteger(order.amount) || Number(order.amount) <= 0) throw new OrderPaymentError('invalid_cost_policy', 409)
  const operationsReserve = Number(snapshot.operationsReserve ?? 3000)
  if (!Number.isSafeInteger(operationsReserve) || operationsReserve < 3000) throw new OrderPaymentError('invalid_cost_policy', 409)
  if (![feeRate, reserveRate].every(rate => Number.isFinite(rate) && rate >= 0 && rate < 1)) throw new OrderPaymentError('invalid_cost_policy', 409)
  const paymentFeeReserve = Math.ceil(Number(order.amount) * feeRate)
  const reprintReserve = Math.ceil(Number(order.amount) * reserveRate)
  const contribution = Number(order.amount) - values.reduce((a, b) => a + b, 0) - paymentFeeReserve - reprintReserve - operationsReserve
  if (enforceMinimum && contribution < minimumContribution) throw new OrderPaymentError('print_margin_below_minimum', 409)
  return { actual_print_cost: values[0], actual_shipping_cost: values[1], actual_packaging_cost: values[2],
    contribution_margin: contribution, payment_fee_reserve: paymentFeeReserve, reprint_reserve: reprintReserve, operations_reserve: operationsReserve }
}

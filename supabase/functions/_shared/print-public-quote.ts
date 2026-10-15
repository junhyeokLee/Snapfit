type PublicRow = Record<string, any>
const object = (value: unknown): PublicRow => value && typeof value === 'object' && !Array.isArray(value) ? value as PublicRow : {}
const pick = (row: PublicRow, keys: string[]) => Object.fromEntries(keys.filter(key => Object.hasOwn(row, key)).map(key => [key, row[key]]))

/** Preserve printable geometry without disclosing supplier approval material. */
export function publicPrintSpec(value: unknown) {
  const spec = object(value)
  const result = pick(spec, ['id','specVersion','verified','coverType','coverLabel','pageCount','productName','spineMm','minInteriorPages',
    'maxInteriorPages','pageMultiple','dpi','minimumPhotoPpi','colorSpace','layoutFit','geometryMeasured','templateFamily'])
  for (const key of Object.keys(result)) if (typeof result[key] === 'object') delete result[key]
  if (Array.isArray(spec.reviewRequired)) result.reviewRequired = spec.verified === true ? [] : spec.reviewRequired.filter((value: unknown) =>
    typeof value === 'string' && ['vendor_cover_template','spine_width','bleed_and_color','physical_sample','vendor_casewrap_template','spine_and_hinges'].includes(value))
  if (spec.interior) result.interior = Object.fromEntries(Object.entries(pick(object(spec.interior), ['trimWidthMm','trimHeightMm','bleedMm']))
    .filter(([, value]) => typeof value === 'number' && Number.isFinite(value)))
  if (spec.cover) {
    result.cover = Object.fromEntries(Object.entries(pick(object(spec.cover), ['widthMm','heightMm','bleedMm','construction']))
      .filter(([, value]) => typeof value === 'number' && Number.isFinite(value) || typeof value === 'string'))
    for (const key of ['front','back','trim']) if (spec.cover[key]) result.cover[key] = Object.fromEntries(
      Object.entries(pick(object(spec.cover[key]), ['xMm','yMm','widthMm','heightMm'])).filter(([, value]) => typeof value === 'number' && Number.isFinite(value)))
  }
  if (spec.coverType === 'HARD') result.geometrySource = spec.verified === true ? '승인된 공식 표지 템플릿' : '인쇄업체 도면 확인이 필요한 검수용 규격'
  return result
}

export function publicPrintQuoteField(key: string, value: unknown) {
  if (key === 'spec') return value == null ? null : publicPrintSpec(value)
  if (key === 'printProduct') return Object.fromEntries(Object.entries(pick(object(value), ['id','trimWidthMm','trimHeightMm','productName']))
    .filter(([, field]) => typeof field === 'string' || typeof field === 'number' && Number.isFinite(field)))
  // Every other quotation field is a scalar; an unexpected nested object must
  // never carry private quotation evidence through a public whitelist.
  return value == null || ['string','boolean','number'].includes(typeof value) ? value : null
}

import { OrderPaymentError } from './order-types.ts'

// Catalog identities only. Saved customer album snapshots and shared image or
// material paths are deliberately outside this policy.
export const retiredStoreTemplateIds = [
  46, 48, 49, 50, 51, 52, 53, 54, 55,
  -1115056, -8006, -8007, -8008,
] as const

export const retiredStoreTemplateTitles = [
  '제주의 기록',
  '가족의 주말',
  '우리의 기념일',
  'Wedding Editorial',
  'Scrapbook',
  'SAVE THE DATE',
  '화이트 에디토리얼',
  '필름 다이어리',
  '소프트 베이비북',
] as const

export const retiredStoreTemplateStems = [
  'jeju_travel',
  'family_weekend',
  'anniversary_days',
  'wedding_editorial',
  'scrapbook',
  'save_the_date',
  'minimal_editorial',
  'film_diary',
  'soft_babybook',
] as const

const ids = new Set<number>(retiredStoreTemplateIds)
const normalize = (value: string) => value.toLowerCase().replace(/[^a-z0-9가-힣]/g, '')
const titles = new Set(retiredStoreTemplateTitles.map(normalize))
const stems = new Set(retiredStoreTemplateStems.map(normalize))
const versionedStem = new RegExp(`^(${[...stems].join('|')})v[0-9]+$`)

function identity(value: unknown): boolean {
  if (typeof value !== 'string') return false
  if (value === 'figma_import_1775063050456') return true
  const normalized = normalize(value)
  return stems.has(normalized) || versionedStem.test(normalized)
}

function object(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null
}

export function isRetiredStoreTemplate(payload: Record<string, unknown>): boolean {
  const id = typeof payload.id === 'number' || typeof payload.id === 'string'
    ? Number(payload.id)
    : NaN
  if (Number.isSafeInteger(id) && ids.has(id)) return true
  if (typeof payload.title === 'string' &&
      (titles.has(normalize(payload.title)) || identity(payload.title))) return true
  if (identity(payload.templateId)) return true
  let raw = payload.templateJson ?? payload.template_json
  if (typeof raw === 'string') {
    try { raw = JSON.parse(raw) } catch { return false }
  }
  const document = object(raw)
  if (document === null) return false
  if (identity(document.id) || identity(document.templateId)) return true
  const metadata = object(document.metadata)
  return metadata !== null && (identity(metadata.id) || identity(metadata.templateId))
}

// Called after admin authentication and before any templates upsert. A new
// product with no explicit ID remains valid; current published IDs are retained.
export function assertCurrentStoreTemplate(payload: Record<string, unknown>): void {
  if (isRetiredStoreTemplate(payload)) {
    throw new OrderPaymentError('retired_store_template', 400)
  }
}

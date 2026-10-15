import { OrderPaymentError } from './order-types.ts'
import { resolvePrintAssetPath } from './print-package.ts'

// These paths are loaded from Flutter's compiled asset bundle, never from disk.
// Only artwork directories and image extensions can be referenced by an album.
export function isBundledPrintArtwork(source: string): boolean {
  const path = source.startsWith('asset:') ? source.slice(6) : source
  return /^assets\/(?:cover|sticker|templates|frame_preview|catalog_thumbnails)\/[A-Za-z0-9_./ -]+\.(?:png|jpe?g|webp)$/i.test(path) &&
    !path.split('/').some(part => !part || part === '.' || part === '..') && !path.includes('\\')
}

export function printAssetSources(snapshot: unknown): string[] {
  const sources = new Set<string>()
  const visit = (value: any, key = '') => {
    if (typeof value === 'string') {
      if (/^(?:cover_layers_json|layers_json)$/.test(key)) {
        try { visit(JSON.parse(value)) } catch { throw new OrderPaymentError('invalid_print_snapshot', 409) }
      } else if (key === 'textFillImageUrl' && value.startsWith('@')) {
        // A canvas-local photo-layer link; its original image is validated
        // separately. This value is never interpreted as a download URL.
      } else if (/(?:originalUrl|previewUrl|imageUrl|textFillImageUrl|original_url|preview_url|image_url|thumbnail_url)$/.test(key) && value.trim()) sources.add(value)
    } else if (Array.isArray(value)) value.forEach(item => visit(item))
    else if (value && typeof value === 'object') Object.entries(value).forEach(([k, v]) => visit(v, k))
  }
  visit(snapshot)
  return [...sources]
}

/** Reject external URLs before charging and before starting a renderer. */
export function assertFulfillmentAssetSources(snapshot: unknown, supabaseUrl: string, allowedOwners: Iterable<string>): void {
  const owners = new Set(allowedOwners)
  for (const source of printAssetSources(snapshot)) {
    if (isBundledPrintArtwork(source)) continue
    if (!resolvePrintAssetPath(source, supabaseUrl, owners)) throw new OrderPaymentError('print_asset_access_requires_review', 409)
  }
}

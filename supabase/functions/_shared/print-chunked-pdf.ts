import { createHash } from 'node:crypto'
import { OrderPaymentError } from './order-types.ts'
import { PRINT_BUCKET } from './print-contract.ts'
import { inspectAppRasterPdfRanges, type RasterPdfRangeReader } from './print-raster-pdf-range-inspector.ts'
import type { PrintRect } from './print-contract.ts'

export const PRINT_CHUNK_BYTES = 16_000_000
export const PRINT_PDF_CACHE_BYTES = 112_000_000
export const PRINT_LARGE_FILE_BYTES = 500_000_000
export const PRINT_LARGE_COVER_BYTES = 150_000_000
export type PrintFilePart = { index: number; path: string; byteLength: number; sha256: string }
const bad = (code = 'print_prepayment_file_conflict', status = 409): never => { throw new OrderPaymentError(code, status) }
const object = (value: unknown): Record<string, any> => value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {}
const hash = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex')

/** Exact, ordered slices of an existing PDF. Splitting never changes its bytes. */
export function checkedChunkParts(pack: Record<string, any>, kind: 'cover' | 'interior', declared: Record<string, any>): PrintFilePart[] | null {
  const declarations = declared.parts
  const stored = object(pack.file_parts)[kind]
  if (declarations === undefined) {
    if (stored !== undefined && stored !== null && (!Array.isArray(stored) || stored.length !== 0)) return bad()
    return null
  }
  if (!Array.isArray(declarations) || !Array.isArray(stored) || declared.bytes <= 50_000_000 ||
      declared.bytes > (kind === 'cover' ? PRINT_LARGE_COVER_BYTES : PRINT_LARGE_FILE_BYTES) ||
      declarations.length !== Math.ceil(declared.bytes / PRINT_CHUNK_BYTES) || declarations.length !== stored.length || stored.length > 32) return bad()
  const base = `${pack.cover_path}`.replace(/\/cover\.pdf$/, '')
  if (!/\/cover\.pdf$/.test(pack.cover_path ?? '')) return bad()
  let total = 0
  return stored.map((value: unknown, index: number) => {
    const part = object(value), declaration = object(declarations[index])
    const length = Math.min(PRINT_CHUNK_BYTES, declared.bytes - index * PRINT_CHUNK_BYTES)
    const path = `${base}/${kind}/part-${String(index).padStart(3, '0')}.bin`
    if (Object.keys(part).some(key => !['index', 'path', 'byteLength', 'sha256'].includes(key)) ||
        part.index !== index || part.path !== path || part.byteLength !== length || part.sha256 !== declaration.sha256 ||
        declaration.bytes !== length || !/^[a-f\d]{64}$/.test(part.sha256 ?? '') ||
        Object.keys(declaration).some(key => !['bytes', 'sha256'].includes(key))) return bad()
    total += length
    if (index === stored.length - 1 && total !== declared.bytes) return bad()
    return { index, path, byteLength: length, sha256: part.sha256 }
  })
}

/** One small immutable object at a time, with no Blob/ArrayBuffer duplication. */
export async function downloadChunkPdfPart(db: any, part: PrintFilePart, supabaseUrl: string, fetcher: typeof fetch = fetch) {
  if (!Number.isSafeInteger(part.byteLength) || part.byteLength < 1 || part.byteLength > PRINT_CHUNK_BYTES ||
      !/^[a-f\d]{64}$/.test(part.sha256)) return bad()
  const { data, error } = await db.storage.from(PRINT_BUCKET).createSignedUrl(part.path, 120)
  if (error || !data?.signedUrl) return bad('print_upload_missing')
  let url: URL
  try { url = new URL(data.signedUrl) } catch { return bad('print_upload_missing') }
  if (url.origin !== new URL(supabaseUrl).origin || decodeURIComponent(url.pathname) !== `/storage/v1/object/sign/${PRINT_BUCKET}/${part.path}`) return bad('print_upload_missing')
  const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 50_000)
  let reader: ReadableStreamDefaultReader<Uint8Array> | null = null
  try {
    const response = await fetcher(url.href, { signal: controller.signal, redirect: 'error' })
    if (!response.ok || !response.body) return bad('print_upload_missing')
    const length = response.headers.get('content-length')
    if (length !== null && (!/^\d+$/.test(length) || Number(length) !== part.byteLength)) return bad('print_upload_size_mismatch')
    const bytes = new Uint8Array(part.byteLength)
    reader = response.body.getReader()
    let offset = 0
    for (;;) {
      const chunk = await reader.read()
      if (chunk.done) break
      if (offset + chunk.value.length > bytes.length) return bad('print_upload_size_mismatch')
      bytes.set(chunk.value, offset); offset += chunk.value.length
    }
    if (offset !== bytes.length) return bad('print_upload_size_mismatch')
    if (hash(bytes) !== part.sha256) return bad('print_upload_hash_mismatch')
    return bytes
  } catch (error) {
    if (error instanceof OrderPaymentError) throw error
    return bad('print_upload_download_unavailable', 503)
  } finally {
    clearTimeout(timeout)
    try { await reader?.cancel() } catch { /* Already closed. */ }
    reader?.releaseLock()
  }
}

export type ChunkedPdfReader = RasterPdfRangeReader & {
  sha256(): Promise<string>
  readPart(index: number): Promise<Uint8Array>
  clear(): void
}

/** A byte-bounded cache reuses verified objects across full SHA and PDF scans. */
export function createChunkedPdfReader(db: any, parts: PrintFilePart[], supabaseUrl: string, fetcher: typeof fetch = fetch): ChunkedPdfReader {
  if (!parts.length || parts.length > 32 || parts.some((part, index) => part.index !== index || part.byteLength < 1 ||
      part.byteLength > PRINT_CHUNK_BYTES || index < parts.length - 1 && part.byteLength !== PRINT_CHUNK_BYTES)) return bad()
  const byteLength = parts.reduce((sum, part) => sum + part.byteLength, 0)
  const cache = new Map<number, Uint8Array>()
  let cacheBytes = 0
  // Calls are deliberately sequential; no two uncached downloads run together.
  const readPart = async (index: number) => {
    if (!Number.isSafeInteger(index) || index < 0 || index >= parts.length) return bad('invalid_app_print_pdf')
    const found = cache.get(index)
    if (found) { cache.delete(index); cache.set(index, found); return found }
    // Evict enough verified bytes before allocating/fetching the next object.
    while (cacheBytes + parts[index].byteLength > PRINT_PDF_CACHE_BYTES && cache.size) {
      const oldest = cache.keys().next().value!
      cacheBytes -= cache.get(oldest)!.byteLength
      cache.delete(oldest)
    }
    const bytes = await downloadChunkPdfPart(db, parts[index], supabaseUrl, fetcher)
    cache.set(index, bytes)
    cacheBytes += bytes.byteLength
    return bytes
  }
  return {
    byteLength,
    readPart,
    clear: () => { cache.clear(); cacheBytes = 0 },
    async read(offset, length) {
      if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(length) || offset < 0 || length < 0 ||
          length > 32_768 || offset + length > byteLength) return bad('invalid_app_print_pdf')
      if (length === 0) return new Uint8Array()
      const firstIndex = Math.floor(offset / PRINT_CHUNK_BYTES), first = await readPart(firstIndex)
      const start = offset - firstIndex * PRINT_CHUNK_BYTES
      // Tiny parser ranges must not retain an evicted 16MB backing buffer.
      if (start + length <= first.length) return first.slice(start, start + length)
      const bytes = new Uint8Array(length), firstLength = first.length - start
      bytes.set(first.subarray(start), 0)
      bytes.set((await readPart(firstIndex + 1)).subarray(0, length - firstLength), firstLength)
      return bytes
    },
    async sha256() {
      const digest = createHash('sha256')
      for (let i = 0; i < parts.length; i++) digest.update(await readPart(i))
      return digest.digest('hex')
    },
  }
}

export async function validateChunkedPrintPdf(reader: RasterPdfRangeReader & { sha256(): Promise<string> }, pageCount: number,
  widthMm: number, heightMm: number, trim: PrintRect = { xMm: 5, yMm: 5, widthMm: widthMm - 10, heightMm: heightMm - 10 }) {
  const digest = await reader.sha256()
  const pages = await inspectAppRasterPdfRanges(reader)
  if (pages.length !== pageCount) return bad('print_pdf_page_count_mismatch')
  const mmToPt = 72 / 25.4
  if (pages.some(page => Math.abs(page.width - widthMm * mmToPt) > .2 || Math.abs(page.height - heightMm * mmToPt) > .2)) return bad('print_pdf_dimensions_mismatch')
  if (pages.some(page => Math.abs(page.trimBox.x - trim.xMm * mmToPt) > .2 ||
      Math.abs(page.trimBox.y - (heightMm - trim.yMm - trim.heightMm) * mmToPt) > .2 ||
      Math.abs(page.trimBox.width - trim.widthMm * mmToPt) > .2 || Math.abs(page.trimBox.height - trim.heightMm * mmToPt) > .2)) return bad('print_trim_box_mismatch')
  return { pageCount, widthMm, heightMm, byteLength: reader.byteLength, sha256: digest }
}

import { OrderPaymentError } from './order-types.ts'
import { createHash } from 'node:crypto'
import { downloadChunkPdfPart, PRINT_CHUNK_BYTES, PRINT_LARGE_COVER_BYTES, PRINT_LARGE_FILE_BYTES, type PrintFilePart } from './print-chunked-pdf.ts'
import { downloadPrepaymentPdf } from './print-prepayment-package.ts'

export type PrintFileKind = 'cover' | 'interior'
export type PrintFileDeliveryReference = { orderId: string; packageId: string; kind: PrintFileKind; sha256: string }
export type PrintFileDeliveryRecord = PrintFileDeliveryReference & {
  result: { pageCount: number; widthMm: number; heightMm: number; byteLength: number; sha256: string }
  parts: PrintFilePart[]
}
type Database = { rpc(name: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }> }
export type PrintFileDeliveryDependencies = {
  secret(): string
  supabaseUrl(): string
  createAdminDatabase(): Database
  fetcher?: typeof fetch
  now?: () => number
  /** Set only by the separate DEV Edge wrapper; never accepted in a request. */
  development?: true
}
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value)
const digest = (value: unknown): value is string => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value)
const object = (value: unknown): Record<string, any> => value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {}
const bad = (code = 'invalid_print_file_delivery', status = 503): never => { throw new OrderPaymentError(code, status) }
const referenceValid = (value: PrintFileDeliveryReference) => typeof value.orderId === 'string' && value.orderId.startsWith('ordp_') &&
  uuid(value.orderId.slice(5)) && uuid(value.packageId) && ['cover', 'interior'].includes(value.kind) && digest(value.sha256)

export function printFileDeliverySignedPayload(reference: PrintFileDeliveryReference, expires: number, development = false) {
  return `${development ? 'snapfit-print-dev-file:v1' : 'snapfit-print-file:v1'}\n${reference.orderId}\n${reference.packageId}\n${reference.kind}\n${reference.sha256}\n${expires}`
}
async function signingKey(secret: string, usage: 'sign' | 'verify') {
  if (!digest(secret)) return bad('print_file_delivery_unavailable')
  return crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, [usage])
}

/** Only the server's paid-package lookup may supply these fixed references. */
export async function createPrintFileDeliveryUrl(reference: PrintFileDeliveryReference,
  config: { supabaseUrl: string; secret: string; now?: number; development?: true }) {
  if (!referenceValid(reference)) return bad()
  const now = config.now ?? Date.now(), expires = Math.floor(now / 1000) + 3600
  if (!Number.isFinite(now) || !Number.isSafeInteger(expires) || expires < 1_000_000_000 || expires > 9_999_999_999) return bad()
  let origin: URL
  try { origin = new URL(config.supabaseUrl) } catch { return bad() }
  if (origin.protocol !== 'https:' || origin.pathname !== '/' || origin.search || origin.hash || origin.username || origin.password) return bad()
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', await signingKey(config.secret, 'sign'),
    new TextEncoder().encode(printFileDeliverySignedPayload(reference, expires, config.development === true))))
  const url = new URL(`/functions/v1/${config.development === true ? 'print-dev-file-delivery' : 'print-file-delivery'}/${reference.kind}.pdf`, origin)
  url.search = new URLSearchParams({ orderId: reference.orderId, packageId: reference.packageId, kind: reference.kind,
    sha256: reference.sha256, expires: String(expires), signature: Array.from(signature, value => value.toString(16).padStart(2, '0')).join('') }).toString()
  return url.href
}

/** A second shape/path check protects the stream if an RPC contract changes. */
export function checkedPrintFileDeliveryRecord(value: unknown, reference: PrintFileDeliveryReference, development = false): PrintFileDeliveryRecord {
  const row = object(value), result = object(row.result), parts = row.parts
  const direct = development === true && Array.isArray(parts) && parts.length === 0
  if (!referenceValid(reference) || row.orderId !== reference.orderId || row.packageId !== reference.packageId || row.kind !== reference.kind ||
      result.sha256 !== reference.sha256 || !digest(result.sha256) ||
      Object.keys(result).sort().join(',') !== 'byteLength,heightMm,pageCount,sha256,widthMm' ||
      !Number.isSafeInteger(result.pageCount) || (reference.kind === 'cover' ? result.pageCount !== 1 :
        result.pageCount < 20 || result.pageCount > 80 || result.pageCount % 2 !== 0) ||
      !['widthMm', 'heightMm'].every(key => typeof result[key] === 'number' && Number.isFinite(result[key]) && result[key] > 0 && result[key] <= 1000) ||
      !Number.isSafeInteger(result.byteLength) || result.byteLength < 100 || (!direct && result.byteLength <= 50_000_000) ||
      (direct && result.byteLength > 50_000_000) ||
      result.byteLength > (reference.kind === 'cover' ? PRINT_LARGE_COVER_BYTES : PRINT_LARGE_FILE_BYTES) ||
      !Array.isArray(parts) || (!direct && parts.length !== Math.ceil(result.byteLength / PRINT_CHUNK_BYTES)) || parts.length > 32) return bad()
  const checked = parts.map((value: unknown, index: number): PrintFilePart => {
    const part = object(value)
    const path = `${reference.orderId}/${reference.packageId}/${reference.kind}/part-${String(index).padStart(3, '0')}.bin`
    if (Object.keys(part).sort().join(',') !== 'byteLength,index,path,sha256' || part.index !== index || part.path !== path ||
        part.byteLength !== Math.min(PRINT_CHUNK_BYTES, result.byteLength - index * PRINT_CHUNK_BYTES) || !digest(part.sha256)) return bad()
    return { index, path, byteLength: part.byteLength, sha256: part.sha256 }
  })
  return { ...reference, result: { pageCount: result.pageCount, widthMm: result.widthMm, heightMm: result.heightMm,
    byteLength: result.byteLength, sha256: result.sha256 }, parts: checked }
}

export async function readPrintFileDelivery(database: Database, reference: PrintFileDeliveryReference, development = false) {
  if (!referenceValid(reference)) return bad()
  const result = await database.rpc(development === true ? 'read_print_dev_file_delivery' : 'read_print_file_delivery',
    { p_order_id: reference.orderId, p_package_id: reference.packageId, p_kind: reference.kind })
  if (result.error || !result.data) return bad('print_file_unavailable', 404)
  return checkedPrintFileDeliveryRecord(result.data, reference, development)
}

async function authorized(request: Request, secret: string, now: number, development = false): Promise<PrintFileDeliveryReference | null> {
  if (request.url.length > 2048 || !digest(secret)) return null
  let url: URL
  try { url = new URL(request.url) } catch { return null }
  const allowed = ['orderId', 'packageId', 'kind', 'sha256', 'expires', 'signature']
  if (Array.from(url.searchParams.keys()).length !== allowed.length || allowed.some(key => url.searchParams.getAll(key).length !== 1) ||
      Array.from(url.searchParams.keys()).some(key => !allowed.includes(key))) return null
  const reference = { orderId: url.searchParams.get('orderId')!, packageId: url.searchParams.get('packageId')!,
    kind: url.searchParams.get('kind')! as PrintFileKind, sha256: url.searchParams.get('sha256')! }
  const expiry = url.searchParams.get('expires')!, signature = url.searchParams.get('signature')!
  // The hosted relay can remove /functions/v1 before invoking Deno. Keep only
  // the two fixed function routes in either spelling, never arbitrary paths.
  const endpoint = development === true ? 'print-dev-file-delivery' : 'print-file-delivery'
  const routes = [`/functions/v1/${endpoint}`, `/${endpoint}`]
  if (!referenceValid(reference) || !/^\d{10}$/.test(expiry) || !digest(signature) || !Number.isFinite(now) ||
      !routes.some(route => url.pathname === route || url.pathname === `${route}/${reference.kind}.pdf`)) return null
  const expires = Number(expiry), seconds = Math.floor(now / 1000)
  if (!Number.isSafeInteger(expires) || expires < seconds || expires > seconds + 3600) return null
  const verified = await crypto.subtle.verify('HMAC', await signingKey(secret, 'verify'),
    Uint8Array.from(signature.match(/../g)!, value => Number.parseInt(value, 16)), new TextEncoder().encode(printFileDeliverySignedPayload(reference, expires, development)))
  return verified ? reference : null
}

function byteRange(value: string | null, byteLength: number) {
  if (value === null) return { first: 0, last: byteLength - 1, partial: false }
  const match = value.match(/^bytes=(\d*)-(\d*)$/)
  if (!match || !match[1] && !match[2]) return null
  const suffix = match[1] === '', start = suffix ? null : Number(match[1]), finish = match[2] === '' ? null : Number(match[2])
  if (start !== null && (!Number.isSafeInteger(start) || start < 0 || start >= byteLength) ||
      finish !== null && (!Number.isSafeInteger(finish) || finish < 0) || suffix && (!finish || finish < 1)) return null
  const first = suffix ? Math.max(0, byteLength - finish!) : start!, last = suffix ? byteLength - 1 : Math.min(finish ?? byteLength - 1, byteLength - 1)
  return first <= last ? { first, last, partial: true } : null
}

/**
 * Supplier-only byte delivery. Storage objects stay below the Free object cap;
 * this response joins their original bytes without producing a new PDF object.
 * No payment or supplier mutation is possible through this endpoint.
 */
export function createPrintFileDeliveryHandler(dependencies: PrintFileDeliveryDependencies) {
  return async (request: Request): Promise<Response> => {
    const error = (code: string, status: number, extra?: HeadersInit) => Response.json({ error: code }, { status,
      headers: { 'Cache-Control': 'private, no-store', ...extra } })
    if (!['GET', 'HEAD'].includes(request.method)) return error('method_not_allowed', 405, { Allow: 'GET, HEAD' })
    try {
      const development = dependencies.development === true
      const reference = await authorized(request, dependencies.secret(), (dependencies.now ?? Date.now)(), development)
      if (!reference) return error('authentication_required', 401)
      // The fixed wrapper selects a service-only RPC that independently
      // requires its corresponding actual receipt and exact sealed package.
      const database = dependencies.createAdminDatabase(), record = await readPrintFileDelivery(database, reference, development)
      const range = byteRange(request.headers.get('range'), record.result.byteLength)
      if (!range) return error('invalid_file_range', 416, { 'Content-Range': `bytes */${record.result.byteLength}` })
      const headers = new Headers({ 'Content-Type': 'application/pdf', 'Content-Length': String(range.last - range.first + 1),
        'Content-Disposition': `attachment; filename="${reference.kind}.pdf"`, 'Cache-Control': 'private, no-store',
        'X-Content-Type-Options': 'nosniff', ETag: `"${record.result.sha256}"`, 'Accept-Ranges': 'bytes' })
      if (range.partial) headers.set('Content-Range', `bytes ${range.first}-${range.last}/${record.result.byteLength}`)
      if (request.method === 'HEAD') return new Response(null, { status: range.partial ? 206 : 200, headers })

      const stop = new AbortController(), lifetime = setTimeout(() => stop.abort('print_file_delivery_expired'), 140_000)
      const direct = record.parts.length === 0
      let currentPart = direct ? 0 : Math.floor(range.first / PRINT_CHUNK_BYTES), current: Uint8Array | null = null, at = range.first, done = false
      const finish = () => { if (done) return; done = true; current = null; clearTimeout(lifetime); stop.abort() }
      const boundedFetch: typeof fetch = (input, init) => {
        const original = init?.signal ?? (input instanceof Request ? input.signal : undefined)
        const signal = AbortSignal.any([request.signal, stop.signal, ...(original ? [original] : [])])
        if (signal.aborted) return Promise.reject(signal.reason)
        return (dependencies.fetcher ?? fetch)(input, { ...init, signal })
      }
      const body = new ReadableStream<Uint8Array>({
        async pull(controller) {
          if (done) return
          try {
            if (request.signal.aborted || stop.signal.aborted) throw new Error('print_file_delivery_canceled')
            if (!current) {
              if (direct) {
                current = await downloadPrepaymentPdf(database, `${reference.orderId}/${reference.packageId}/${reference.kind}.pdf`,
                  record.result.byteLength, dependencies.supabaseUrl(), boundedFetch)
                if (createHash('sha256').update(current).digest('hex') !== record.result.sha256) throw new Error('print_file_delivery_hash_mismatch')
              } else current = await downloadChunkPdfPart(database, record.parts[currentPart], dependencies.supabaseUrl(), boundedFetch)
            }
            if (done || request.signal.aborted || stop.signal.aborted) throw new Error('print_file_delivery_canceled')
            const offset = direct ? at : at - currentPart * PRINT_CHUNK_BYTES
            // Small copied slices avoid retaining every full chunk buffer in a
            // slow downstream queue. The next object starts only on pull.
            const count = Math.min(256 * 1024, current.length - offset, range.last - at + 1)
            if (count < 1) throw new Error('invalid_print_file_delivery')
            controller.enqueue(current.slice(offset, offset + count)); at += count
            if (at > range.last) { controller.close(); finish(); return }
            if (offset + count === current.length) { current = null; currentPart++ }
          } catch { finish(); controller.error(new Error('print_file_delivery_failed')) }
        },
        cancel() { finish() },
      }, { highWaterMark: 0 })
      return new Response(body, { status: range.partial ? 206 : 200, headers })
    } catch (failure) {
      return error(failure instanceof OrderPaymentError && failure.status === 404 ? 'print_file_unavailable' : 'print_file_delivery_unavailable',
        failure instanceof OrderPaymentError && failure.status === 404 ? 404 : 503)
    }
  }
}

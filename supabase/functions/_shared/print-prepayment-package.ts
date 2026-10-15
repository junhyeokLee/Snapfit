import { corsHeaders } from './cors.ts'
import { OrderPaymentError } from './order-types.ts'
import { PRINT_BUCKET, getPrintSpec, sourceFingerprint } from './print-contract.ts'
import { getPrepaymentPrintSnapshot, validatePrintPdf, type PdfInspector } from './print-package.ts'
import { inspectAppRasterPdf } from './print-raster-pdf-inspector.ts'
import { assertFulfillmentAssetSources } from './print-fulfillment-assets.ts'
import { checkedChunkParts, createChunkedPdfReader, downloadChunkPdfPart, PRINT_CHUNK_BYTES,
  PRINT_LARGE_COVER_BYTES, PRINT_LARGE_FILE_BYTES, validateChunkedPrintPdf } from './print-chunked-pdf.ts'

export const PREPAYMENT_MAX_FILE_BYTES = 50_000_000
type FileKind = 'cover' | 'interior'
type Row = Record<string, any>
export type PrepaymentPackageDependencies = {
  getUser(request: Request): Promise<{ id?: unknown } | null>
  createAdminDatabase(): any
  configuration(): { supabaseUrl: string }
  inspectPdf?: PdfInspector
  fetcher?: typeof fetch
  now?: () => number
}
const uuid = (value: unknown): value is string => typeof value === 'string' && /^[a-f\d]{8}-[a-f\d]{4}-[1-5][a-f\d]{3}-[89ab][a-f\d]{3}-[a-f\d]{12}$/i.test(value)
const object = (value: unknown): Row => value && typeof value === 'object' && !Array.isArray(value) ? value as Row : {}
const keys = (value: Row, allowed: string[]) => Object.keys(value).every(key => allowed.includes(key))
const canonical = (value: any): string => JSON.stringify(value && typeof value === 'object' ?
  (Array.isArray(value) ? value.map(v => JSON.parse(canonical(v))) : Object.fromEntries(Object.keys(value).sort().map(key => [key, JSON.parse(canonical(value[key]))]))) : value ?? null)
const fail = (code: string, status = 409): never => { throw new OrderPaymentError(code, status) }
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' } })
const safeErrors = new Set(['print_checkout_not_found', 'print_prepayment_not_found', 'print_prepayment_state_changed',
  'print_prepayment_expired', 'print_prepayment_conflict', 'print_prepayment_manifest_conflict', 'print_prepayment_file_conflict',
  'print_prepayment_parts_incomplete',
  'print_album_changed', 'print_quote_changed', 'print_sales_not_ready', 'invalid_print_prepayment_request', 'print_request_hold_active'])
async function requestBody(request: Request) {
  const limit = 140_000, length = request.headers.get('content-length')
  if (length && /^\d+$/.test(length) && Number(length) > limit) return fail('invalid_print_prepayment_request', 413)
  if (!request.body) return fail('invalid_print_prepayment_request', 400)
  const reader = request.body.getReader(), buffer = new Uint8Array(limit)
  let offset = 0
  try {
    for (;;) {
      const chunk = await reader.read()
      if (chunk.done) break
      if (offset + chunk.value.length > limit) return fail('invalid_print_prepayment_request', 413)
      buffer.set(chunk.value, offset); offset += chunk.value.length
    }
    try { return object(JSON.parse(new TextDecoder().decode(buffer.subarray(0, offset)))) }
    catch { return fail('invalid_print_prepayment_request', 400) }
  } finally {
    try { await reader.cancel() } catch { /* Already consumed. */ }
    reader.releaseLock()
  }
}
async function rpc(db: any, params: Row) {
  const { data, error } = await db.rpc('print_prepayment_package', params)
  if (error) {
    const e = object(error), message = String(e.message ?? '')
    if (e.code === '42501') return fail('print_checkout_not_found', 404)
    if (safeErrors.has(message)) return fail(message, message.endsWith('_not_found') ? 404 : message.startsWith('invalid_') ? 400 : 409)
    return fail('print_prepayment_storage_unavailable', 503)
  }
  return object(data)
}
function refs(body: Row, actor: string) {
  if (!uuid(body.requestId) || typeof body.orderId !== 'string' || !body.orderId.startsWith('ordp_') || !uuid(body.orderId.slice(5)) ||
      typeof body.paymentId !== 'string' || !body.paymentId.startsWith('SFP_') || !uuid(body.paymentId.slice(4))) return fail('invalid_print_prepayment_request', 400)
  return { p_actor: actor, p_request_id: body.requestId, p_order_id: body.orderId, p_payment_id: body.paymentId }
}
function checkContext(value: Row, body: Row, actor: string, now: number, mutable: boolean) {
  const intent = object(value.intent), order = object(value.order), pack = value.package == null ? null : object(value.package)
  if (intent.user_id !== actor || order.user_id !== actor || intent.request_id !== body.requestId || intent.order_id !== body.orderId ||
      order.order_id !== body.orderId || intent.payment_id !== body.paymentId || order.checkout_flow !== 'PORTONE_V2_V1' ||
      intent.environment !== 'live' || intent.currency !== 'KRW' || !Number.isSafeInteger(intent.album_id) ||
      !/^[a-f\d]{64}$/.test(intent.reviewed_revision ?? '') || !/^[a-f\d]{64}$/.test(intent.reviewed_spec_revision ?? '')) return fail('print_checkout_not_found', 404)
  if (mutable && (intent.status !== 'PREPARED' || order.status !== 'PAYMENT_PENDING' || intent.request_hold === true ||
      order.payment_reversed_at || !Number.isFinite(Date.parse(intent.expires_at)) || Date.parse(intent.expires_at) <= now)) return fail('print_prepayment_state_changed')
  if (pack) {
    const base = `${order.order_id}/${pack.id}`
    if (!uuid(pack.id) || pack.cover_path !== `${base}/cover.pdf` || pack.interior_path !== `${base}/interior.pdf` ||
        pack.manifest_path !== `${base}/manifest.json` ||
        !['UPLOADING', 'FILES_VERIFIED', 'READY', 'ABANDONED', 'CLEANING', 'CLEANED'].includes(pack.state) ||
        ![PREPAYMENT_MAX_FILE_BYTES, PRINT_LARGE_FILE_BYTES].includes(pack.max_file_bytes) ||
        (pack.transport_version !== undefined && !['DIRECT_V1', 'CHUNKED_V1'].includes(pack.transport_version)) ||
        !Number.isFinite(Date.parse(pack.expires_at))) return fail('print_prepayment_record_invalid', 503)
    if (mutable && (['ABANDONED', 'CLEANING', 'CLEANED'].includes(pack.state) || Date.parse(pack.expires_at) <= now)) return fail('print_prepayment_expired')
  }
  return { intent, order, pack }
}
function output(context: ReturnType<typeof checkContext>) {
  const { intent, pack } = context
  return { orderId: intent.order_id, paymentId: intent.payment_id, requestId: intent.request_id, albumId: intent.album_id,
    reviewedRevision: intent.reviewed_revision, reviewedSpecRevision: intent.reviewed_spec_revision,
    packageId: pack?.id ?? null, packageState: pack && ['CLEANING', 'CLEANED'].includes(pack.state) ? 'ABANDONED' : pack?.state ?? 'NONE', printPackageReady: pack?.state === 'READY',
    maxFileBytes: pack?.max_file_bytes ?? PRINT_LARGE_FILE_BYTES,
    maxCoverFileBytes: Math.min(pack?.max_file_bytes ?? PRINT_LARGE_FILE_BYTES, PRINT_LARGE_COVER_BYTES),
    cover: pack?.cover_result ?? null, interior: pack?.interior_result ?? null,
    expiresAt: pack?.expires_at ?? intent.expires_at }
}
function report(value: unknown, fingerprint: string, spec: Row) {
  const manifest = object(value)
  if (manifest.renderer !== 'flutter-layer-builder-raster-v1' || manifest.sourceFingerprint !== fingerprint ||
      manifest.specVersion !== spec.specVersion || manifest.productId !== spec.id || manifest.coverType !== spec.coverType ||
      manifest.pageCount !== spec.pageCount || manifest.dpi !== 300 || manifest.colorSpace !== 'sRGB' ||
      manifest.iccProfileEmbedded !== true || manifest.pdfStandard !== 'PDF-1.4' || manifest.fit !== 'contain' ||
      !Array.isArray(manifest.missingAssets) || manifest.missingAssets.length || !Array.isArray(manifest.warnings) ||
      !manifest.warnings.every((v: unknown) => typeof v === 'string' && v.length <= 240) ||
      JSON.stringify(manifest).length > 120_000 || Object.hasOwn(manifest, 'declaredFiles') || Object.hasOwn(manifest, 'fileTransport')) return fail('print_preflight_failed')
  return manifest
}
function declaredFile(value: unknown, kind: FileKind = 'interior') {
  const file = object(value)
  if (!keys(file, ['bytes', 'sha256', 'parts']) || !Number.isSafeInteger(file.bytes) || file.bytes < 100 ||
      typeof file.sha256 !== 'string' || !/^[a-f\d]{64}$/.test(file.sha256)) return fail('invalid_print_prepayment_request', 400)
  if (file.bytes > (kind === 'cover' ? PRINT_LARGE_COVER_BYTES : PRINT_LARGE_FILE_BYTES)) return fail('print_pdf_too_large', 413)
  if (file.bytes <= PREPAYMENT_MAX_FILE_BYTES) {
    if (Object.hasOwn(file, 'parts')) return fail('invalid_print_prepayment_request', 400)
    return { bytes: file.bytes as number, sha256: file.sha256 as string }
  }
  if (!Array.isArray(file.parts) || file.parts.length !== Math.ceil(file.bytes / PRINT_CHUNK_BYTES)) return fail('invalid_print_prepayment_request', 400)
  const parts = file.parts.map((value: unknown, index: number) => {
    const part = object(value), length = Math.min(PRINT_CHUNK_BYTES, file.bytes - index * PRINT_CHUNK_BYTES)
    if (!keys(part, ['bytes', 'sha256']) || part.bytes !== length || typeof part.sha256 !== 'string' || !/^[a-f\d]{64}$/.test(part.sha256)) return fail('invalid_print_prepayment_request', 400)
    return { bytes: length, sha256: part.sha256 }
  })
  return { bytes: file.bytes as number, sha256: file.sha256 as string, parts }
}

/** Resume inspection of the same immutable bytes after a lost/limited request.
 * A partial upload cannot be regenerated over an existing package: its output
 * may have a different timestamp/hash. Only server-verified files/parts are
 * offered for recovery, and declarations, paths and upload tokens stay private.
 */
function fileRecovery(context: ReturnType<typeof checkContext>, fingerprint: string, spec: Row) {
  const pack = context.pack
  if (!pack || !['UPLOADING', 'FILES_VERIFIED'].includes(pack.state)) return {}
  const { declaredFiles, ...storedReport } = object(pack.renderer_manifest)
  const manifest = report(storedReport, fingerprint, spec)
  for (const kind of ['cover', 'interior'] as const) {
    const file = declaredFile(object(declaredFiles)[kind], kind)
    const parts = checkedChunkParts(pack, kind, file)
    if (parts) {
      if (parts.some(part => canonical(object(object(pack.part_results)[kind])[String(part.index)]) !==
          canonical({ index: part.index, byteLength: part.byteLength, sha256: part.sha256 }))) return {}
    } else {
      const result = object(pack[`${kind}_result`])
      if (result.sha256 !== file.sha256 || result.byteLength !== file.bytes ||
          result.pageCount !== (kind === 'cover' ? 1 : spec.pageCount)) return {}
    }
  }
  return { fileRecovery: { packageId: pack.id, manifest } }
}

async function sealPackage(db: any, context: ReturnType<typeof checkContext>, params: Row, body: Row, actor: string, now: number) {
  const pack = context.pack
  if (!pack || pack.state !== 'FILES_VERIFIED') return context
  const manifest = object(pack.pdf_manifest), spec = getPrintSpec(context.order)
  if (!pack.cover_result || !pack.interior_result || manifest.sourceFingerprint !== pack.source_fingerprint ||
      canonical(manifest.spec) !== canonical(spec) || canonical(manifest.cover) !== canonical(pack.cover_result) ||
      canonical(manifest.interior) !== canonical(pack.interior_result) || manifest.vendorReady !== false ||
      !Number.isFinite(Date.parse(manifest.generatedAt))) return fail('print_prepayment_record_invalid', 503)
  if (pack.transport_version === 'CHUNKED_V1' && canonical(manifest.fileTransport) !==
      canonical({ version: 'CHUNKED_V1', files: pack.file_parts })) return fail('print_prepayment_record_invalid', 503)
  const { error } = await db.storage.from(PRINT_BUCKET).upload(pack.manifest_path, JSON.stringify(manifest), { contentType: 'application/json', upsert: false })
  if (error) {
    if (String(error.statusCode) !== '409' && !/already exists|duplicate/i.test(error.message ?? '')) return fail('print_manifest_publish_unavailable', 503)
    const { data: prior, error: readError } = await db.storage.from(PRINT_BUCKET).download(pack.manifest_path)
    if (readError || !prior || prior.size > 140_000) return fail('print_manifest_conflict')
    let stored: unknown
    try { stored = JSON.parse(await prior.text()) } catch { return fail('print_manifest_conflict') }
    if (canonical(stored) !== canonical(manifest)) return fail('print_manifest_conflict')
  }
  return checkContext(await rpc(db, { ...params, p_action: 'seal', p_package_id: pack.id }), body, actor, now, true)
}

/** A bounded stream download into one preallocated buffer, never Blob + copy. */
export async function downloadPrepaymentPdf(db: any, path: string, expectedBytes: number, supabaseUrl: string, fetcher: typeof fetch = fetch) {
  if (!Number.isSafeInteger(expectedBytes) || expectedBytes < 100 || expectedBytes > PREPAYMENT_MAX_FILE_BYTES) return fail('print_pdf_too_large', 413)
  const { data, error } = await db.storage.from(PRINT_BUCKET).createSignedUrl(path, 120)
  if (error || !data?.signedUrl) return fail('print_upload_missing')
  let url: URL
  try { url = new URL(data.signedUrl) } catch { return fail('print_upload_missing') }
  if (url.origin !== new URL(supabaseUrl).origin || decodeURIComponent(url.pathname) !== `/storage/v1/object/sign/${PRINT_BUCKET}/${path}`) return fail('print_upload_missing')
  const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 50_000)
  let reader: ReadableStreamDefaultReader<Uint8Array> | null = null
  try {
    const response = await fetcher(url.href, { signal: controller.signal, redirect: 'error' })
    if (!response.ok || !response.body) return fail('print_upload_missing')
    const length = response.headers.get('content-length')
    if (length !== null && (!/^\d+$/.test(length) || Number(length) !== expectedBytes)) return fail('print_upload_size_mismatch')
    const bytes = new Uint8Array(expectedBytes)
    reader = response.body.getReader()
    let offset = 0
    for (;;) {
      const chunk = await reader.read()
      if (chunk.done) break
      if (offset + chunk.value.length > expectedBytes) return fail('print_upload_size_mismatch')
      bytes.set(chunk.value, offset); offset += chunk.value.length
    }
    if (offset !== expectedBytes) return fail('print_upload_size_mismatch')
    return bytes
  } catch (error) {
    if (error instanceof OrderPaymentError) throw error
    return fail('print_upload_download_unavailable', 503)
  } finally {
    clearTimeout(timer)
    try { await reader?.cancel() } catch { /* Already closed or network error. */ }
    reader?.releaseLock()
  }
}

export function createPrepaymentPackageHandler(deps: PrepaymentPackageDependencies) {
  // A reused Edge isolate must not hold two maximum-size PDFs concurrently.
  // Clients already finalize cover and interior sequentially; a concurrent
  // duplicate can retry the same immutable package after this short validation.
  let validating = false
  return async (request: Request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      if (!/^Bearer \S+$/i.test(request.headers.get('authorization') ?? '')) return reply({ error: 'unauthorized' }, 401)
      let user: { id?: unknown } | null
      try { user = await deps.getUser(request) } catch { return reply({ error: 'unauthorized' }, 401) }
      if (!uuid(user?.id)) return reply({ error: 'unauthorized' }, 401)
      const body = await requestBody(request)
      const action = body.action
      if (!['snapshot', 'uploads', 'finalize', 'status'].includes(action) ||
          !keys(body, ['action', 'requestId', 'orderId', 'paymentId', 'packageId', 'kind', 'partIndex', 'manifest', 'cover', 'interior'])) return fail('invalid_print_prepayment_request', 400)
      if (Object.hasOwn(body, 'partIndex') && (action !== 'finalize' || !Number.isSafeInteger(body.partIndex) || body.partIndex < 0 || body.partIndex > 31)) return fail('invalid_print_prepayment_request', 400)
      const params = refs(body, user.id), db = deps.createAdminDatabase(), config = deps.configuration(), now = (deps.now ?? Date.now)()
      const value = await rpc(db, { ...params, p_action: 'snapshot' })
      let context = checkContext(value, body, user.id, now, action !== 'status')
      if (action === 'status') return reply(output(context))
      const { order, intent } = context
      const spec = getPrintSpec(order), fingerprint = await sourceFingerprint(order)
      if (context.pack && (context.pack.source_fingerprint !== fingerprint || context.pack.spec_version !== spec.specVersion)) return fail('print_prepayment_conflict')
      if (action === 'snapshot') {
        assertFulfillmentAssetSources(intent.snapshot, config.supabaseUrl, intent.source_asset_owners ?? [])
        const source = await getPrepaymentPrintSnapshot(db, order, intent, user.id, config.supabaseUrl)
        return reply({ ...output(context), ...source, ...fileRecovery(context, fingerprint, spec) })
      }
      if (action === 'uploads') {
        const manifest = { ...report(body.manifest, fingerprint, spec), declaredFiles: { cover: declaredFile(body.cover, 'cover'), interior: declaredFile(body.interior, 'interior') } }
        context = checkContext(await rpc(db, { ...params, p_action: 'uploads', p_manifest: manifest,
          p_file_result: { sourceFingerprint: fingerprint, specVersion: spec.specVersion } }), body, user.id, now, true)
        const pack = context.pack
        if (!pack || canonical(pack.renderer_manifest) !== canonical(manifest)) return fail('print_prepayment_manifest_conflict')
        if (pack.state === 'READY') return reply({ ...output(context), uploadId: pack.id, bucket: PRINT_BUCKET, sourceFingerprint: fingerprint, spec })
        const { data: bucket, error: bucketError } = await db.storage.getBucket(PRINT_BUCKET)
        if (bucketError || !bucket || bucket.public === true) return fail('print_bucket_must_be_private', 503)
        const targets: Row = {}
        for (const kind of ['cover', 'interior'] as const) {
          const parts = checkedChunkParts(pack, kind, manifest.declaredFiles[kind])
          if (parts) {
            const signedParts: Row[] = []
            for (const part of parts) {
              const { data, error } = await db.storage.from(PRINT_BUCKET).createSignedUploadUrl(part.path, { upsert: false })
              if (error || !data?.token || !data?.signedUrl) return fail('print_upload_signing_unavailable', 503)
              signedParts.push({ ...part, token: data.token, signedUrl: data.signedUrl })
            }
            targets[kind] = { parts: signedParts }
            continue
          }
          const path = pack[`${kind}_path`]
          const { data, error } = await db.storage.from(PRINT_BUCKET).createSignedUploadUrl(path, { upsert: false })
          if (error || !data?.token || !data?.signedUrl) return fail('print_upload_signing_unavailable', 503)
          targets[kind] = { path, token: data.token, signedUrl: data.signedUrl }
        }
        return reply({ ...output(context), ...targets, uploadId: pack.id, bucket: PRINT_BUCKET, sourceFingerprint: fingerprint, spec })
      }
      if (!uuid(body.packageId) || context.pack?.id !== body.packageId || !['cover', 'interior'].includes(body.kind)) return fail('print_prepayment_conflict')
      const pack = context.pack!, kind = body.kind as FileKind, manifest = report(body.manifest, fingerprint, spec)
      const { declaredFiles, ...storedReport } = object(pack.renderer_manifest)
      if (canonical(manifest) !== canonical(storedReport)) return fail('print_prepayment_manifest_conflict')
      const file = declaredFile(object(declaredFiles)[kind], kind), parts = checkedChunkParts(pack, kind, file)
      const verifiedPart = (index: number) => {
        const part = parts?.[index], stored = object(object(pack.part_results)[kind])[String(index)]
        return part && canonical(stored) === canonical({ index, byteLength: part.byteLength, sha256: part.sha256 })
      }
      if (Object.hasOwn(body, 'partIndex')) {
        const index = body.partIndex as number, part = parts?.[index]
        if (!part) return fail('print_prepayment_conflict')
        if (!verifiedPart(index)) {
          if (validating) return fail('print_validation_busy', 429)
          validating = true
          try { await downloadChunkPdfPart(db, part, config.supabaseUrl, deps.fetcher) }
          finally { validating = false }
          context = checkContext(await rpc(db, { ...params, p_action: 'verify_part', p_package_id: pack.id, p_file_kind: kind,
            p_file_result: { index, byteLength: part.byteLength, sha256: part.sha256 }, p_manifest: pack.renderer_manifest }), body, user.id, now, true)
          const stored = object(object(context.pack?.part_results)[kind])[String(index)]
          if (canonical(stored) !== canonical({ index, byteLength: part.byteLength, sha256: part.sha256 })) return fail('print_prepayment_file_conflict')
        }
        return reply({ ...output(context), partVerified: true, partIndex: index, kind })
      }
      if (pack[`${kind}_result`]) return reply(output(await sealPackage(db, context, params, body, user.id, now))) // Retry publishing without reprocessing an immutable file.
      if (parts && parts.some(part => !verifiedPart(part.index))) return fail('print_prepayment_parts_incomplete')
      if (validating) return fail('print_validation_busy', 429)
      validating = true
      let result: Awaited<ReturnType<typeof validatePrintPdf>>
      try {
        if (parts) {
          const reader = createChunkedPdfReader(db, parts, config.supabaseUrl, deps.fetcher)
          try {
            result = kind === 'cover' ? await validateChunkedPrintPdf(reader, 1, spec.cover.widthMm, spec.cover.heightMm, spec.cover.trim) :
              await validateChunkedPrintPdf(reader, spec.pageCount, spec.interior.trimWidthMm + 2 * spec.interior.bleedMm,
                spec.interior.trimHeightMm + 2 * spec.interior.bleedMm)
          } finally { reader.clear() }
        } else {
          const bytes = await downloadPrepaymentPdf(db, pack[`${kind}_path`], file.bytes, config.supabaseUrl, deps.fetcher)
          result = kind === 'cover' ? await validatePrintPdf(bytes, 1, spec.cover.widthMm, spec.cover.heightMm,
            deps.inspectPdf ?? inspectAppRasterPdf, spec.cover.trim) : await validatePrintPdf(bytes, spec.pageCount,
            spec.interior.trimWidthMm + 2 * spec.interior.bleedMm, spec.interior.trimHeightMm + 2 * spec.interior.bleedMm, deps.inspectPdf ?? inspectAppRasterPdf)
        }
      } finally { validating = false }
      if (result.sha256 !== file.sha256 || result.byteLength !== file.bytes) return fail('print_upload_hash_mismatch')
      context = checkContext(await rpc(db, { ...params, p_action: 'finalize', p_package_id: pack.id, p_file_kind: kind,
        p_file_result: result, p_manifest: pack.renderer_manifest }), body, user.id, now, true)
      context = await sealPackage(db, context, params, body, user.id, now)
      return reply(output(context))
    } catch (error) {
      if (error instanceof OrderPaymentError) return reply({ error: error.message, retryable: error.status === 429 || error.status === 503 }, error.status)
      return reply({ error: 'print_prepayment_unavailable', retryable: true }, 503)
    }
  }
}

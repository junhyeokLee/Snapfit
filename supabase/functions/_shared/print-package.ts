import { OrderPaymentError, type OrderRow } from './order-types.ts'
import { assertPrintOrder, getPrintSpec, PRINT_BUCKET, PRINT_MAX_PDF_BYTES, printSnapshot, sha256, sourceFingerprint, type PrintRect } from './print-contract.ts'

type SupabaseAdmin = any

// Payment callbacks only queue work. The administrator renders the immutable
// document with the same Flutter canvas used by the editor. Never substitute a
// text summary PDF, a thumbnail ZIP, or missing-image placeholders for a book.
export async function buildPrintPackage(_supabase: SupabaseAdmin, order: OrderRow) {
  printSnapshot(order)
  return { patch: { print_fulfillment_status: 'AWAITING_RENDER' } }
}

export function resolvePrintAssetPath(source: string, supabaseUrl: string, allowedOwners: Set<string>): string | null {
  let url: URL
  try { url = new URL(source) } catch { return null }
  let bucket: string, path: string
  if (url.protocol === 'supabase:') {
    bucket = url.hostname
    path = decodeURIComponent(url.pathname.slice(1))
  } else {
    if (url.origin !== new URL(supabaseUrl).origin) return null
    const match = url.pathname.match(/^\/storage\/v1\/(?:object\/(?:public|sign|authenticated)|render\/image\/(?:public|sign))\/([^/]+)\/(.+)$/)
    if (!match) return null
    bucket = decodeURIComponent(match[1]); path = decodeURIComponent(match[2])
  }
  const parts = path.split('/')
  if (bucket !== 'album-assets' || !allowedOwners.has(parts[0]) || parts.some(part => !part || part === '.' || part === '..') || path.includes('\\') || /%[0-9a-f]{2}/i.test(path)) {
    throw new OrderPaymentError('print_asset_access_requires_review', 409)
  }
  return path
}

export async function getPrintSnapshot(supabase: SupabaseAdmin, order: OrderRow, supabaseUrl: string) {
  assertPrintOrder(order)
  const spec = getPrintSpec(order)
  const snapshot = printSnapshot(order)
  const allowedOwners = new Set([String(snapshot.album.owner_id ?? ''), String(order.user_id ?? '')].filter(Boolean))
  if (order.album_id != null) {
    const { data, error } = await supabase.from('album_members').select('user_id').eq('album_id', order.album_id).in('role', ['OWNER','EDITOR'])
    if (error) throw error
    for (const member of data ?? []) allowedOwners.add(member.user_id)
  }
  const sources = new Set<string>()
  const visit = (value: any, key = '') => {
    if (typeof value === 'string') {
      if (/^(?:cover_layers_json|layers_json)$/.test(key)) { try { visit(JSON.parse(value)) } catch { throw new OrderPaymentError('invalid_print_snapshot', 409) } }
      else if (/(?:originalUrl|previewUrl|imageUrl|textFillImageUrl|original_url|preview_url|image_url|thumbnail_url)$/.test(key)) sources.add(value)
    } else if (Array.isArray(value)) value.forEach(item => visit(item))
    else if (value && typeof value === 'object') Object.entries(value).forEach(([k,v]) => visit(v,k))
  }
  visit(snapshot)
  const sourceUrls: Record<string,string> = {}
  for (const source of sources) {
    const path = resolvePrintAssetPath(source, supabaseUrl, allowedOwners)
    if (!path) continue // Bundled assets/external public URLs are left to the renderer; never fetched by the server.
    const { data, error } = await supabase.storage.from('album-assets').createSignedUrl(path, 3600)
    if (error) throw new OrderPaymentError('print_asset_signing_failed', 409)
    sourceUrls[source] = data.signedUrl
  }
  return { orderId: order.order_id, snapshot, sourceUrls, spec, sourceFingerprint: await sourceFingerprint(order) }
}

async function ensureBucket(supabase: SupabaseAdmin) {
  const { data: bucket, error: readError } = await supabase.storage.getBucket(PRINT_BUCKET)
  if (bucket) {
    if (bucket.public) throw new OrderPaymentError('print_bucket_must_be_private', 503)
    return
  }
  if (readError && !['404', '400'].includes(String(readError.statusCode)) && !/not found/i.test(readError.message ?? '')) throw readError
  const { error } = await supabase.storage.createBucket(PRINT_BUCKET, {
    public: false, fileSizeLimit: PRINT_MAX_PDF_BYTES, allowedMimeTypes: ['application/pdf', 'application/json'],
  })
  if (error && !/already exists|duplicate/i.test(error.message ?? '')) throw error
}

export async function createPrintUploads(supabase: SupabaseAdmin, order: OrderRow) {
  assertPrintOrder(order)
  const spec = getPrintSpec(order)
  if (['SUBMITTED', 'ACCEPTED'].includes(String(order.print_fulfillment_status))) throw new OrderPaymentError('print_already_submitted', 409)
  await ensureBucket(supabase)
  const uploadId = crypto.randomUUID()
  const base = `${order.order_id}/${uploadId}`
  const fingerprint = await sourceFingerprint(order)
  const { data, error } = await supabase.from('orders').update({
    print_upload_id: uploadId, print_upload_fingerprint: fingerprint, print_fulfillment_status: 'RENDERING',
    print_spec_confirmed_at: null,
  }).eq('order_id', order.order_id).eq('status', 'PAYMENT_COMPLETED').is('payment_reversed_at', null)
    .eq('print_fulfillment_status', order.print_fulfillment_status ?? 'AWAITING_RENDER').select().maybeSingle()
  if (error) throw error
  if (!data) throw new OrderPaymentError('print_state_changed', 409)
  const [cover, interior] = await Promise.all(['cover.pdf', 'interior.pdf'].map(async file => {
    const path = `${base}/${file}`
    const { data, error } = await supabase.storage.from(PRINT_BUCKET).createSignedUploadUrl(path, { upsert: false })
    if (error) throw error
    return { path, token: data.token, signedUrl: data.signedUrl }
  }))
  return { uploadId, bucket: PRINT_BUCKET, cover, interior, sourceFingerprint: fingerprint, spec }
}

export type PdfInspector = (bytes: Uint8Array) => Promise<{ width: number; height: number; trimBox: { x: number; y: number; width: number; height: number } }[]>
export function createPdfInspector(pdfLib: any): PdfInspector {
  return async bytes => {
    const { PDFDocument, PDFDict, PDFName, PDFArray, PDFRawStream, decodePDFRawStream } = pdfLib
    const document = await PDFDocument.load(bytes, { ignoreEncryption: false, updateMetadata: false, throwOnInvalidObject: true })
    if (document.isEncrypted) throw new OrderPaymentError('encrypted_print_pdf', 409)
    let rgbProfileFound = false
    for (const [, object] of document.context.enumerateIndirectObjects()) {
      const dict = object instanceof PDFRawStream ? object.dict : object
      if (!(dict instanceof PDFDict)) continue
      for (const key of ['JavaScript','JS','AA','OpenAction','EmbeddedFiles','EmbeddedFile','RichMedia','AcroForm']) {
        if (dict.has(PDFName.of(key))) throw new OrderPaymentError('active_print_pdf_not_allowed', 409)
      }
      const action = dict.get(PDFName.of('S'))?.toString()
      if (['/JavaScript','/Launch','/GoToR','/SubmitForm','/ImportData'].includes(action)) throw new OrderPaymentError('active_print_pdf_not_allowed', 409)
      if (dict.get(PDFName.of('Type'))?.toString() === '/EmbeddedFile') throw new OrderPaymentError('active_print_pdf_not_allowed', 409)
      if (dict.get(PDFName.of('Subtype'))?.toString() === '/Image') {
        const colorSpace = document.context.lookup(dict.get(PDFName.of('ColorSpace')))
        if (!(colorSpace instanceof PDFArray) || colorSpace.get(0)?.toString() !== '/ICCBased') throw new OrderPaymentError('print_icc_profile_required', 409)
        const profile = document.context.lookup(colorSpace.get(1))
        if (!(profile instanceof PDFRawStream)) throw new OrderPaymentError('print_icc_profile_required', 409)
        const icc = decodePDFRawStream(profile).decode()
        // ICC signature and data color space are binary profile-header facts.
        if (icc.length < 128 || new TextDecoder().decode(icc.subarray(36,40)) !== 'acsp' ||
            new TextDecoder().decode(icc.subarray(16,20)) !== 'RGB ') throw new OrderPaymentError('invalid_print_icc_profile', 409)
        // The renderer's checked-in LittleCMS sRGB profile; a different RGB
        // monitor/press profile cannot be passed off as the declared sRGB output.
        if (await sha256(icc) !== 'b9c099b4d89b06f6105a70c8f925ea16d3eb9b1b4301ad1986fd52aa669504d3') throw new OrderPaymentError('print_srgb_profile_mismatch', 409)
        rgbProfileFound = true
      }
    }
    if (!rgbProfileFound) throw new OrderPaymentError('print_raster_content_required', 409)
    return document.getPages().map((page: any) => {
      const width = page.getWidth(), height = page.getHeight(), trim = page.getTrimBox()
      if (!page.node.has(PDFName.of('TrimBox'))) {
        throw new OrderPaymentError('print_trim_box_mismatch', 409)
      }
      if (page.getRotation().angle % 360 !== 0) throw new OrderPaymentError('print_page_rotation_not_allowed', 409)
      const xObjects = document.context.lookup(page.node.Resources()?.get(PDFName.of('XObject')))
      let fullResolutionRaster = false
      if (xObjects instanceof PDFDict) for (const [, ref] of xObjects.entries()) {
        const image = document.context.lookup(ref)
        if (!(image instanceof PDFRawStream) || image.dict.get(PDFName.of('Subtype'))?.toString() !== '/Image') continue
        const pixelWidth = Number(image.dict.get(PDFName.of('Width'))?.toString())
        const pixelHeight = Number(image.dict.get(PDFName.of('Height'))?.toString())
        if (pixelWidth >= width * 300 / 72 - 1 && pixelHeight >= height * 300 / 72 - 1) fullResolutionRaster = true
      }
      if (!fullResolutionRaster) throw new OrderPaymentError('print_raster_resolution_too_low', 409)
      return { width, height, trimBox: trim }
    })
  }
}
async function inspectPdf(bytes: Uint8Array) {
  return createPdfInspector(await import('npm:pdf-lib@1.17.1'))(bytes)
}

export async function validatePrintPdf(bytes: Uint8Array, pageCount: number, widthMm: number, heightMm: number, inspect: PdfInspector = inspectPdf,
  trim: PrintRect = { xMm: 5, yMm: 5, widthMm: widthMm - 10, heightMm: heightMm - 10 }) {
  if (bytes.length < 100 || bytes.length > PRINT_MAX_PDF_BYTES || new TextDecoder().decode(bytes.subarray(0, 5)) !== '%PDF-') {
    throw new OrderPaymentError('invalid_print_pdf', 409)
  }
  let pages
  try { pages = await inspect(bytes) } catch (error) {
    if (error instanceof OrderPaymentError) throw error
    throw new OrderPaymentError('invalid_print_pdf', 409)
  }
  if (pages.length !== pageCount) throw new OrderPaymentError('print_pdf_page_count_mismatch', 409)
  const mmToPt = 72 / 25.4
  if (pages.some(p => Math.abs(p.width - widthMm * mmToPt) > .2 || Math.abs(p.height - heightMm * mmToPt) > .2)) {
    throw new OrderPaymentError('print_pdf_dimensions_mismatch', 409)
  }
  if (pages.some(p => !p.trimBox || Math.abs(p.trimBox.x - trim.xMm * mmToPt) > .2 || Math.abs(p.trimBox.y - (heightMm - trim.yMm - trim.heightMm) * mmToPt) > .2 ||
      Math.abs(p.trimBox.width - trim.widthMm * mmToPt) > .2 || Math.abs(p.trimBox.height - trim.heightMm * mmToPt) > .2)) throw new OrderPaymentError('print_trim_box_mismatch', 409)
  return { pageCount, widthMm, heightMm, byteLength: bytes.length, sha256: await sha256(bytes) }
}

export async function finalizePrintPackage(supabase: SupabaseAdmin, order: OrderRow, body: Record<string, any>, inspect: PdfInspector = inspectPdf) {
  assertPrintOrder(order)
  if (order.print_upload_id === body.uploadId && ['REVIEW_REQUIRED','READY'].includes(String(order.print_fulfillment_status)) &&
      (order.print_manifest as any)?.sourceFingerprint === body.manifest?.sourceFingerprint) return order
  if (order.print_upload_id !== body.uploadId || order.print_fulfillment_status !== 'RENDERING') throw new OrderPaymentError('print_upload_expired', 409)
  const fingerprint = await sourceFingerprint(order), spec = getPrintSpec(order)
  const manifest = body.manifest
  if (!manifest || manifest.sourceFingerprint !== fingerprint || order.print_upload_fingerprint !== fingerprint ||
      manifest.specVersion !== spec.specVersion || manifest.pageCount !== Number(order.page_count) ||
      !Array.isArray(manifest.missingAssets) || manifest.missingAssets.length || !Array.isArray(manifest.warnings) ||
      manifest.iccProfileEmbedded !== true || manifest.colorSpace !== spec.colorSpace || manifest.dpi !== spec.dpi) {
    throw new OrderPaymentError('print_preflight_failed', 409)
  }
  const base = `${order.order_id}/${order.print_upload_id}`
  const coverPath = `${base}/cover.pdf`, interiorPath = `${base}/interior.pdf`
  // Read only server-generated object paths. Never fetch arbitrary URLs supplied
  // by a client, and never grant an overwrite token for published artifacts.
  const read = async (path: string) => {
    const { data, error } = await supabase.storage.from(PRINT_BUCKET).download(path)
    if (error || !data) throw new OrderPaymentError('print_upload_missing', 409)
    if (data.size > PRINT_MAX_PDF_BYTES) throw new OrderPaymentError('print_pdf_too_large', 413)
    return new Uint8Array(await data.arrayBuffer())
  }
  // Process sequentially to bound Edge memory for large 80-page documents.
  const cover = await validatePrintPdf(await read(coverPath), 1, spec.cover.widthMm, spec.cover.heightMm, inspect, 'trim' in spec.cover ? spec.cover.trim : undefined)
  const interior = await validatePrintPdf(await read(interiorPath), Number(order.page_count),
    spec.interior.trimWidthMm + 2 * spec.interior.bleedMm, spec.interior.trimHeightMm + 2 * spec.interior.bleedMm, inspect)
  const generatedAt = new Date().toISOString()
  let savedManifest = { ...manifest, sourceFingerprint: fingerprint, spec, cover, interior, generatedAt, vendorReady: false }
  const manifestPath = `${base}/manifest.json`
  const { error: uploadError } = await supabase.storage.from(PRINT_BUCKET).upload(manifestPath, JSON.stringify(savedManifest), { contentType: 'application/json', upsert: false })
  if (uploadError) {
    if (!/already exists|duplicate/i.test(uploadError.message ?? '') && String(uploadError.statusCode) !== '409') throw uploadError
    // A storage write can succeed before the database publish fails. Reuse only
    // the exact already-validated content on retry, without overwriting objects.
    const { data: previous, error: previousError } = await supabase.storage.from(PRINT_BUCKET).download(manifestPath)
    if (previousError || !previous) throw new OrderPaymentError('print_manifest_conflict', 409)
    const stored = JSON.parse(await previous.text())
    if (stored.sourceFingerprint !== fingerprint || stored.cover?.sha256 !== cover.sha256 ||
        stored.interior?.sha256 !== interior.sha256 || stored.spec?.specVersion !== spec.specVersion) throw new OrderPaymentError('print_manifest_conflict', 409)
    savedManifest = stored
  }
  const { data, error } = await supabase.from('orders').update({
    print_cover_pdf_path: coverPath, print_interior_pdf_path: interiorPath, print_manifest_path: manifestPath,
    print_manifest: savedManifest, print_fulfillment_status: 'REVIEW_REQUIRED', print_package_generated_at: generatedAt,
    print_asset_count: Number(order.page_count) + 1, print_vendor: 'REDPRINTING',
    print_file_pdf_url: null, print_file_zip_url: null, print_package_json_url: null,
  }).eq('order_id', order.order_id).eq('status', 'PAYMENT_COMPLETED').is('payment_reversed_at', null)
    .eq('print_upload_id', body.uploadId).eq('print_fulfillment_status', 'RENDERING').select().maybeSingle()
  if (error) throw error
  if (!data) {
    const { data: current, error: currentError } = await supabase.from('orders').select('*').eq('order_id', order.order_id).maybeSingle()
    if (!currentError && !current?.payment_reversed_at && current?.print_upload_id === body.uploadId &&
        ['REVIEW_REQUIRED','READY'].includes(String(current?.print_fulfillment_status))) return current
    throw new OrderPaymentError('print_state_changed', 409)
  }
  return data
}

export async function getPrintDownloadLinks(supabase: SupabaseAdmin, order: OrderRow) {
  if (order.payment_reversed_at) throw new OrderPaymentError('payment_reversed', 409)
  if (!order.verified_payment_id) throw new OrderPaymentError('verified_payment_required', 409)
  const entries = [['coverPdfUrl', order.print_cover_pdf_path], ['interiorPdfUrl', order.print_interior_pdf_path], ['manifestUrl', order.print_manifest_path]]
  const links: Record<string, unknown> = { expiresIn: 900 }
  for (const [key, path] of entries) {
    if (!path) throw new OrderPaymentError('print_files_not_ready', 409)
    const { data, error } = await supabase.storage.from(PRINT_BUCKET).createSignedUrl(String(path), 900, { download: true })
    if (error) throw error
    links[String(key)] = data.signedUrl
  }
  return links
}

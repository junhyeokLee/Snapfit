const BUCKET = 'print-packages'

type SupabaseAdmin = any

type PrintAsset = {
  id: string
  type: string
  pageNumber: number
  fileName: string
  originalUrl: string | null
  previewUrl: string | null
  thumbnailUrl: string | null
  fallbackUrl: string | null
  layersJson: string | null
}

type PrintPackage = {
  orderId: string
  albumId: number | null
  albumTitle: string
  ratio: string | null
  pageCount: number | null
  recipientName: string | null
  recipientPhone: string | null
  zipCode: string | null
  addressLine1: string | null
  addressLine2: string | null
  deliveryMemo: string | null
  generatedAt: string
  assets: PrintAsset[]
}

function trimOrNull(value: unknown): string | null {
  if (value == null) return null
  const text = String(value).trim()
  return text.length ? text : null
}

function firstNonBlank(...values: unknown[]): string | null {
  for (const value of values) {
    const text = trimOrNull(value)
    if (text) return text
  }
  return null
}

function asNumber(value: unknown): number | null {
  if (value == null) return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

function textBytes(text: string) {
  return new TextEncoder().encode(text)
}

function concatBytes(parts: Uint8Array[]) {
  const total = parts.reduce((sum, p) => sum + p.length, 0)
  const out = new Uint8Array(total)
  let offset = 0
  for (const part of parts) {
    out.set(part, offset)
    offset += part.length
  }
  return out
}

function u16(n: number) {
  return new Uint8Array([n & 0xff, (n >>> 8) & 0xff])
}

function u32(n: number) {
  return new Uint8Array([n & 0xff, (n >>> 8) & 0xff, (n >>> 16) & 0xff, (n >>> 24) & 0xff])
}

const crcTable = (() => {
  const table = new Uint32Array(256)
  for (let i = 0; i < 256; i++) {
    let c = i
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1)
    table[i] = c >>> 0
  }
  return table
})()

function crc32(data: Uint8Array) {
  let c = 0xffffffff
  for (const b of data) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

function dosDateTime(date = new Date()) {
  const year = Math.max(1980, date.getFullYear())
  const dosTime = (date.getHours() << 11) | (date.getMinutes() << 5) | Math.floor(date.getSeconds() / 2)
  const dosDate = ((year - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate()
  return { dosTime, dosDate }
}

function createZip(files: { name: string; bytes: Uint8Array }[]) {
  const localParts: Uint8Array[] = []
  const centralParts: Uint8Array[] = []
  let offset = 0
  const { dosTime, dosDate } = dosDateTime()

  for (const file of files) {
    const name = textBytes(file.name)
    const crc = crc32(file.bytes)
    const size = file.bytes.length
    const local = concatBytes([
      u32(0x04034b50), u16(20), u16(0), u16(0), u16(dosTime), u16(dosDate),
      u32(crc), u32(size), u32(size), u16(name.length), u16(0), name, file.bytes,
    ])
    localParts.push(local)
    centralParts.push(concatBytes([
      u32(0x02014b50), u16(20), u16(20), u16(0), u16(0), u16(dosTime), u16(dosDate),
      u32(crc), u32(size), u32(size), u16(name.length), u16(0), u16(0), u16(0), u16(0),
      u32(0), u32(offset), name,
    ]))
    offset += local.length
  }

  const central = concatBytes(centralParts)
  const end = concatBytes([
    u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length),
    u32(central.length), u32(offset), u16(0),
  ])
  return concatBytes([...localParts, central, end])
}

function escapePdfText(text: string) {
  return text.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)')
}

function createSummaryPdf(pkg: PrintPackage) {
  const lines = [
    'SnapFit print package',
    `Order: ${pkg.orderId}`,
    `Album: ${pkg.albumTitle}`,
    `Recipient: ${pkg.recipientName ?? ''}`,
    `Address: ${pkg.zipCode ?? ''} ${pkg.addressLine1 ?? ''} ${pkg.addressLine2 ?? ''}`,
    `Asset count: ${pkg.assets.length}`,
    '',
    ...pkg.assets.slice(0, 28).map((a) => `${a.fileName}: ${a.fallbackUrl ?? 'no image url'}`),
  ]
  const content = [
    'BT', '/F1 15 Tf', '72 770 Td',
    ...lines.flatMap((line, index) => [index === 0 ? '' : '0 -22 Td', `(${escapePdfText(line).slice(0, 110)}) Tj`]).filter(Boolean),
    'ET',
  ].join('\n')
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${textBytes(content).length} >>\nstream\n${content}\nendstream`,
  ]
  let pdf = '%PDF-1.4\n'
  const offsets: number[] = [0]
  for (let i = 0; i < objects.length; i++) {
    offsets.push(textBytes(pdf).length)
    pdf += `${i + 1} 0 obj\n${objects[i]}\nendobj\n`
  }
  const xref = textBytes(pdf).length
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`
  for (let i = 1; i < offsets.length; i++) pdf += `${String(offsets[i]).padStart(10, '0')} 00000 n \n`
  pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
  return textBytes(pdf)
}

async function fetchAssetBytes(asset: PrintAsset) {
  const url = asset.fallbackUrl
  if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) return null
  try {
    const res = await fetch(url, { headers: { 'User-Agent': 'SnapFit-PrintExporter/1.0' } })
    if (!res.ok) return null
    const bytes = new Uint8Array(await res.arrayBuffer())
    return bytes.length ? bytes : null
  } catch {
    return null
  }
}

function extensionOf(sourceUrl: string | null) {
  const lower = String(sourceUrl ?? '').toLowerCase().split('?')[0]
  if (lower.endsWith('.png')) return '.png'
  if (lower.endsWith('.webp')) return '.webp'
  if (lower.endsWith('.jpeg')) return '.jpeg'
  return '.jpg'
}

async function ensureBucket(supabase: SupabaseAdmin) {
  const { error } = await supabase.storage.createBucket(BUCKET, { public: false })
  if (error && !String(error.message ?? '').toLowerCase().includes('already exists')) {
    // Ignore duplicate bucket variants from Storage API; rethrow anything else.
    if (!String(error.message ?? '').toLowerCase().includes('duplicate')) throw error
  }
}

async function signedUrl(supabase: SupabaseAdmin, path: string) {
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(path, 7 * 24 * 60 * 60)
  if (error) throw error
  return data.signedUrl
}

async function uploadBytes(supabase: SupabaseAdmin, path: string, bytes: Uint8Array, contentType: string) {
  const { error } = await supabase.storage.from(BUCKET).upload(path, new Blob([bytes], { type: contentType }), {
    contentType,
    upsert: true,
  })
  if (error) throw error
  return signedUrl(supabase, path)
}

export async function buildPrintPackage(supabase: SupabaseAdmin, order: Record<string, unknown>) {
  await ensureBucket(supabase)
  const orderId = String(order.order_id ?? '')
  const albumId = asNumber(order.album_id)
  let album: Record<string, unknown> | null = null
  let pages: Record<string, unknown>[] = []

  if (albumId != null) {
    const { data: albumRow, error: albumError } = await supabase.from('albums').select('*').eq('id', albumId).maybeSingle()
    if (albumError) throw albumError
    album = albumRow as Record<string, unknown> | null
    const { data: pageRows, error: pageError } = await supabase
      .from('album_pages')
      .select('*')
      .eq('album_id', albumId)
      .order('page_number', { ascending: true })
    if (pageError) throw pageError
    pages = (pageRows ?? []) as Record<string, unknown>[]
  }

  const assets: PrintAsset[] = []
  if (album) {
    const coverOriginalUrl = trimOrNull(album.cover_original_url)
    const coverPreviewUrl = firstNonBlank(album.cover_preview_url, album.cover_image_url)
    assets.push({
      id: 'cover',
      type: 'cover',
      pageNumber: 0,
      fileName: 'cover',
      originalUrl: coverOriginalUrl,
      previewUrl: coverPreviewUrl,
      thumbnailUrl: trimOrNull(album.cover_thumbnail_url),
      fallbackUrl: firstNonBlank(coverOriginalUrl, coverPreviewUrl, album.cover_thumbnail_url),
      layersJson: trimOrNull(album.cover_layers_json),
    })

    for (const page of pages) {
      const pageNumber = asNumber(page.page_number) ?? assets.length
      const originalUrl = trimOrNull(page.original_url)
      const previewUrl = firstNonBlank(page.preview_url, page.image_url)
      assets.push({
        id: `page-${pageNumber}`,
        type: 'page',
        pageNumber,
        fileName: `page_${String(pageNumber).padStart(3, '0')}`,
        originalUrl,
        previewUrl,
        thumbnailUrl: trimOrNull(page.thumbnail_url),
        fallbackUrl: firstNonBlank(originalUrl, previewUrl, page.thumbnail_url),
        layersJson: trimOrNull(page.layers_json),
      })
    }
  }

  const generatedAt = new Date().toISOString()
  const pkg: PrintPackage = {
    orderId,
    albumId,
    albumTitle: String(album?.title ?? order.title ?? '주문'),
    ratio: trimOrNull(album?.ratio),
    pageCount: asNumber(order.page_count),
    recipientName: trimOrNull(order.recipient_name),
    recipientPhone: trimOrNull(order.recipient_phone),
    zipCode: trimOrNull(order.zip_code),
    addressLine1: trimOrNull(order.address_line1),
    addressLine2: trimOrNull(order.address_line2),
    deliveryMemo: trimOrNull(order.delivery_memo),
    generatedAt,
    assets,
  }

  const base = `${orderId}/${Date.now()}`
  const jsonBytes = textBytes(JSON.stringify(pkg, null, 2))
  const missing: string[] = []
  const imageFiles: { name: string; bytes: Uint8Array }[] = []
  for (const asset of assets) {
    const bytes = await fetchAssetBytes(asset)
    if (bytes) {
      imageFiles.push({ name: `images/${asset.fileName}${extensionOf(asset.fallbackUrl)}`, bytes })
    } else {
      missing.push(`${asset.id} - download failed or no image url: ${asset.fallbackUrl ?? ''}`)
    }
  }
  const zipBytes = createZip([
    { name: 'print-package.json', bytes: jsonBytes },
    { name: 'asset-manifest.txt', bytes: textBytes(assets.map((a) => `${a.fileName}\t${a.fallbackUrl ?? ''}`).join('\n')) },
    ...imageFiles,
    ...(missing.length ? [{ name: 'missing-assets.txt', bytes: textBytes(missing.join('\n')) }] : []),
  ])
  const pdfBytes = createSummaryPdf(pkg)

  const [jsonUrl, zipUrl, pdfUrl] = await Promise.all([
    uploadBytes(supabase, `${base}/print-package.json`, jsonBytes, 'application/json'),
    uploadBytes(supabase, `${base}/print-package.zip`, zipBytes, 'application/zip'),
    uploadBytes(supabase, `${base}/print-package.pdf`, pdfBytes, 'application/pdf'),
  ])

  return {
    package: pkg,
    patch: {
      print_package_json_url: jsonUrl,
      print_file_zip_url: zipUrl,
      print_file_pdf_url: pdfUrl,
      print_asset_count: assets.length,
      print_package_generated_at: generatedAt,
      print_vendor: 'SUPABASE_PRINT_PACKAGE',
      print_vendor_order_id: `SPP-${orderId}`,
      print_submitted_at: generatedAt,
    },
  }
}

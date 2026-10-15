import { OrderPaymentError } from './order-types.ts'
import { sha256 } from './print-contract.ts'
import type { PdfInspector } from './print-package.ts'

const decoder = new TextDecoder('ascii')
const number = '(?:0|[1-9]\\d*)(?:\\.\\d+)?'
const bad = (): never => { throw new OrderPaymentError('invalid_app_print_pdf', 409) }
const text = (bytes: Uint8Array, start: number, end: number, limit = 8192) => {
  if (start < 0 || end < start || end > bytes.length || end - start > limit) return bad()
  return decoder.decode(bytes.subarray(start, end))
}
const same = (bytes: Uint8Array, start: number, value: string) => {
  if (start < 0 || start + value.length > bytes.length) return false
  for (let i = 0; i < value.length; i++) if (bytes[start + i] !== value.charCodeAt(i)) return false
  return true
}

/** Read only JPEG metadata. Never inflate/decode a page-sized raster in Edge. */
function jpegDimensions(bytes: Uint8Array) {
  if (bytes.length < 100 || bytes[0] !== 0xff || bytes[1] !== 0xd8 ||
      bytes[bytes.length - 2] !== 0xff || bytes[bytes.length - 1] !== 0xd9) return bad()
  let offset = 2, dimensions: { width: number; height: number } | null = null
  for (let count = 0; count < 4096 && offset < bytes.length; count++) {
    if (bytes[offset++] !== 0xff) return bad()
    while (bytes[offset] === 0xff) offset++
    const marker = bytes[offset++]
    if (marker === 0xda) {
      if (!dimensions) return bad()
      return dimensions
    }
    if (marker === 0xd8 || marker === 0xd9 || marker === 0x00 || (marker >= 0xd0 && marker <= 0xd7)) return bad()
    const length = (bytes[offset] << 8) | bytes[offset + 1]
    if (length < 2 || offset + length > bytes.length) return bad()
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      // Flutter's RGB JPEG encoder emits three components and eight-bit samples.
      if (dimensions || length !== 17 || bytes[offset + 2] !== 8 || bytes[offset + 7] !== 3) return bad()
      dimensions = { height: (bytes[offset + 3] << 8) | bytes[offset + 4], width: (bytes[offset + 5] << 8) | bytes[offset + 6] }
      if (!dimensions.width || !dimensions.height) return bad()
    }
    offset += length
  }
  return bad()
}

/**
 * Closed grammar for the app's RasterPrintPdf writer. This is deliberately not
 * a general PDF parser: every object, reference, dictionary and drawing command
 * must match our flattened raster writer. Object stream ranges stay subarray
 * views of the original file, avoiding pdf-lib's copies of every JPEG stream.
 * This verifies structure/geometry/profile, not the pixels of the source album.
 */
export const inspectAppRasterPdf: PdfInspector = async bytes => {
  if (bytes.length < 100 || !same(bytes, 0, '%PDF-1.4\n') ||
      !same(bytes, 15, '%SNAPFIT-RASTER\n')) return bad()
  if ([0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a].some((value, index) => bytes[9 + index] !== value)) return bad()
  const trailer = text(bytes, Math.max(0, bytes.length - 100), bytes.length, 100)
  const tail = trailer.match(/trailer\n<< \/Size (\d+) \/Root 1 0 R >>\nstartxref\n(\d+)\n%%EOF\n$/)
  if (!tail) return bad()
  const size = Number(tail[1]), xref = Number(tail[2])
  const pageCount = (size - 4) / 3
  if (!Number.isSafeInteger(size) || !Number.isSafeInteger(xref) || !Number.isSafeInteger(pageCount) || pageCount < 1 || pageCount > 80) return bad()
  const table = text(bytes, xref, bytes.length, 8192)
  const header = `xref\n0 ${size}\n0000000000 65535 f \n`
  if (!table.startsWith(header)) return bad()
  const lines = table.slice(header.length).split('\n')
  const offsets = [0]
  for (let i = 0; i < size - 1; i++) {
    if (!/^\d{10} 00000 n $/.test(lines[i])) return bad()
    const offset = Number(lines[i].slice(0, 10))
    if (!Number.isSafeInteger(offset) || offset <= (offsets.at(-1) ?? 0) || offset >= xref) return bad()
    offsets.push(offset)
  }
  const expectedTail = `trailer\n<< /Size ${size} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
  if (lines.slice(size - 1).join('\n') !== expectedTail || offsets[1] !== 31) return bad()
  offsets.push(xref)
  const dictionary = (id: number) => {
    const prefix = `${id} 0 obj\n`, start = offsets[id], end = offsets[id + 1]
    if (!same(bytes, start, prefix) || !same(bytes, end - 8, '\nendobj\n')) return bad()
    return text(bytes, start + prefix.length, end - 8, 2048)
  }
  const stream = (id: number) => {
    const prefix = `${id} 0 obj\n`, start = offsets[id], end = offsets[id + 1]
    if (!same(bytes, start, prefix)) return bad()
    const dictStart = start + prefix.length
    let marker = -1
    for (let at = dictStart; at < Math.min(dictStart + 512, end); at++) if (same(bytes, at, '\nstream\n')) { marker = at; break }
    if (marker < 0) return bad()
    const dict = text(bytes, dictStart, marker, 512), lengthMatch = dict.match(/ \/Length (\d+) >>$/)
    if (!lengthMatch) return bad()
    const length = Number(lengthMatch[1]), dataStart = marker + 8, dataEnd = dataStart + length
    if (!Number.isSafeInteger(length) || length <= 0 || dataEnd + 18 !== end || !same(bytes, dataEnd, '\nendstream\nendobj\n')) return bad()
    return { dict, bytes: bytes.subarray(dataStart, dataEnd) }
  }
  if (dictionary(1) !== '<< /Type /Catalog /Pages 2 0 R >>') return bad()
  const kids = Array.from({ length: pageCount }, (_, i) => `${3 + i * 3} 0 R`).join(' ')
  if (dictionary(2) !== `<< /Type /Pages /Count ${pageCount} /Kids [${kids}] >>`) return bad()
  const profileId = 3 + pageCount * 3
  const profile = stream(profileId)
  if (profile.dict !== `<< /N 3 /Alternate /DeviceRGB /Length ${profile.bytes.length} >>` || profile.bytes.length < 128 || profile.bytes.length > 16_384 ||
      !same(profile.bytes, 36, 'acsp') || !same(profile.bytes, 16, 'RGB ')) throw new OrderPaymentError('invalid_print_icc_profile', 409)
  if (!['8ada55c9a812761b03ecada49d9b30672746359a516190b8ae08b9ca5c8cb473',
    'b9c099b4d89b06f6105a70c8f925ea16d3eb9b1b4301ad1986fd52aa669504d3'].includes(await sha256(profile.bytes))) {
    throw new OrderPaymentError('print_srgb_profile_mismatch', 409)
  }
  const pages = []
  for (let i = 0; i < pageCount; i++) {
    const id = 3 + i * 3
    const pattern = new RegExp(`^<< /Type /Page /Parent 2 0 R /MediaBox \\[0 0 (${number}) (${number})\\] /BleedBox \\[0 0 \\1 \\2\\] /TrimBox \\[(${number}) (${number}) (${number}) (${number})\\] /Resources << /XObject << /Im0 ${id + 1} 0 R >> >> /Contents ${id + 2} 0 R >>$`)
    const match = dictionary(id).match(pattern)
    if (!match) throw new OrderPaymentError('print_trim_box_mismatch', 409)
    const [width, height, x, y, right, top] = match.slice(1).map(Number)
    if (![width, height, x, y, right, top].every(Number.isFinite) || width <= 0 || height <= 0 || x < 0 || y < 0 || right > width || top > height || right <= x || top <= y) return bad()
    const image = stream(id + 1)
    const imageMatch = image.dict.match(new RegExp(`^<< /Type /XObject /Subtype /Image /Width (\\d+) /Height (\\d+) /ColorSpace \\[\\/ICCBased ${profileId} 0 R\\] /BitsPerComponent 8 /Filter /DCTDecode /Length ${image.bytes.length} >>$`))
    if (!imageMatch) return bad()
    const pixelWidth = Number(imageMatch[1]), pixelHeight = Number(imageMatch[2]), jpeg = jpegDimensions(image.bytes)
    if (jpeg.width !== pixelWidth || jpeg.height !== pixelHeight || pixelWidth < width * 300 / 72 - 1 || pixelHeight < height * 300 / 72 - 1 ||
        pixelWidth > width * 300 / 72 + 1 || pixelHeight > height * 300 / 72 + 1) throw new OrderPaymentError('print_raster_resolution_too_low', 409)
    const content = stream(id + 2)
    const drawing = `q\n${match[1]} 0 0 ${match[2]} 0 0 cm\n/Im0 Do\nQ\n`
    if (content.dict !== `<< /Length ${content.bytes.length} >>` || text(content.bytes, 0, content.bytes.length, 256) !== drawing) return bad()
    pages.push({ width, height, trimBox: { x, y, width: right - x, height: top - y } })
  }
  return pages
}

import { createHash } from 'node:crypto'
import { OrderPaymentError } from './order-types.ts'

export type RasterPdfRangeReader = { byteLength: number; read(offset: number, length: number): Promise<Uint8Array> }
const decoder = new TextDecoder('ascii')
const number = '(?:0|[1-9]\\d*)(?:\\.\\d+)?'
const bad = (): never => { throw new OrderPaymentError('invalid_app_print_pdf', 409) }

/** Same closed RasterPrintPdf grammar, accessed through bounded byte ranges. */
export async function inspectAppRasterPdfRanges(reader: RasterPdfRangeReader) {
  const length = reader.byteLength
  const read = async (start: number, count: number) => {
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(count) || start < 0 || count < 0 || start + count > length || count > 32_768) return bad()
    const bytes = await reader.read(start, count)
    if (!(bytes instanceof Uint8Array) || bytes.length !== count) return bad()
    return bytes
  }
  const text = async (start: number, end: number, limit = 8192) => {
    if (end < start || end - start > limit) return bad()
    return decoder.decode(await read(start, end - start))
  }
  const same = async (start: number, value: string) => await text(start, start + value.length, value.length) === value
  if (length < 100 || !await same(0, '%PDF-1.4\n') || !await same(15, '%SNAPFIT-RASTER\n')) return bad()
  const binary = await read(9, 6)
  if ([0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a].some((value, index) => binary[index] !== value)) return bad()
  const trailer = await text(Math.max(0, length - 100), length, 100)
  const tail = trailer.match(/trailer\n<< \/Size (\d+) \/Root 1 0 R >>\nstartxref\n(\d+)\n%%EOF\n$/)
  if (!tail) return bad()
  const size = Number(tail[1]), xref = Number(tail[2]), pageCount = (size - 4) / 3
  if (!Number.isSafeInteger(size) || !Number.isSafeInteger(xref) || !Number.isSafeInteger(pageCount) || pageCount < 1 || pageCount > 80) return bad()
  const table = await text(xref, length, 8192), header = `xref\n0 ${size}\n0000000000 65535 f \n`
  if (!table.startsWith(header)) return bad()
  const lines = table.slice(header.length).split('\n'), offsets = [0]
  for (let i = 0; i < size - 1; i++) {
    if (!/^\d{10} 00000 n $/.test(lines[i])) return bad()
    const offset = Number(lines[i].slice(0, 10))
    if (!Number.isSafeInteger(offset) || offset <= (offsets.at(-1) ?? 0) || offset >= xref) return bad()
    offsets.push(offset)
  }
  const expectedTail = `trailer\n<< /Size ${size} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
  if (lines.slice(size - 1).join('\n') !== expectedTail || offsets[1] !== 31) return bad()
  offsets.push(xref)
  const dictionary = async (id: number) => {
    const prefix = `${id} 0 obj\n`, start = offsets[id], end = offsets[id + 1]
    if (!await same(start, prefix) || !await same(end - 8, '\nendobj\n')) return bad()
    return text(start + prefix.length, end - 8, 2048)
  }
  const stream = async (id: number) => {
    const prefix = `${id} 0 obj\n`, start = offsets[id], end = offsets[id + 1]
    if (!await same(start, prefix)) return bad()
    const dictStart = start + prefix.length
    const segment = await text(dictStart, Math.min(dictStart + 512, end), 512), marker = segment.indexOf('\nstream\n')
    if (marker < 0) return bad()
    const dict = segment.slice(0, marker), lengthMatch = dict.match(/ \/Length (\d+) >>$/)
    if (!lengthMatch) return bad()
    const streamLength = Number(lengthMatch[1]), dataStart = dictStart + marker + 8, dataEnd = dataStart + streamLength
    if (!Number.isSafeInteger(streamLength) || streamLength <= 0 || dataEnd + 18 !== end || !await same(dataEnd, '\nendstream\nendobj\n')) return bad()
    return { dict, start: dataStart, length: streamLength }
  }
  if (await dictionary(1) !== '<< /Type /Catalog /Pages 2 0 R >>') return bad()
  const kids = Array.from({ length: pageCount }, (_, i) => `${3 + i * 3} 0 R`).join(' ')
  if (await dictionary(2) !== `<< /Type /Pages /Count ${pageCount} /Kids [${kids}] >>`) return bad()
  const profileId = 3 + pageCount * 3, profile = await stream(profileId)
  if (profile.length < 128 || profile.length > 16_384 || profile.dict !== `<< /N 3 /Alternate /DeviceRGB /Length ${profile.length} >>`) {
    throw new OrderPaymentError('invalid_print_icc_profile', 409)
  }
  const icc = await read(profile.start, profile.length)
  if (decoder.decode(icc.subarray(36, 40)) !== 'acsp' || decoder.decode(icc.subarray(16, 20)) !== 'RGB ') throw new OrderPaymentError('invalid_print_icc_profile', 409)
  if (!['8ada55c9a812761b03ecada49d9b30672746359a516190b8ae08b9ca5c8cb473',
    'b9c099b4d89b06f6105a70c8f925ea16d3eb9b1b4301ad1986fd52aa669504d3'].includes(createHash('sha256').update(icc).digest('hex'))) {
    throw new OrderPaymentError('print_srgb_profile_mismatch', 409)
  }
  const jpegDimensions = async (start: number, count: number) => {
    if (count < 100) return bad()
    const first = await read(start, 2), last = await read(start + count - 2, 2)
    if (first[0] !== 0xff || first[1] !== 0xd8 || last[0] !== 0xff || last[1] !== 0xd9) return bad()
    let offset = 2, dimensions: { width: number; height: number } | null = null
    for (let markerCount = 0; markerCount < 4096 && offset < count; markerCount++) {
      if ((await read(start + offset++, 1))[0] !== 0xff) return bad()
      while (offset < count && (await read(start + offset, 1))[0] === 0xff) offset++
      if (offset >= count) return bad()
      const marker = (await read(start + offset++, 1))[0]
      if (marker === 0xda) { if (!dimensions) return bad(); return dimensions }
      if (marker === 0xd8 || marker === 0xd9 || marker === 0x00 || marker >= 0xd0 && marker <= 0xd7 || offset + 2 > count) return bad()
      const header = await read(start + offset, 2), markerLength = (header[0] << 8) | header[1]
      if (markerLength < 2 || offset + markerLength > count) return bad()
      if ([0xc0, 0xc1, 0xc2].includes(marker)) {
        if (dimensions || markerLength !== 17) return bad()
        const sof = await read(start + offset, 17)
        if (sof[2] !== 8 || sof[7] !== 3) return bad()
        dimensions = { height: (sof[3] << 8) | sof[4], width: (sof[5] << 8) | sof[6] }
        if (!dimensions.width || !dimensions.height) return bad()
      }
      offset += markerLength
    }
    return bad()
  }
  const pages = []
  for (let i = 0; i < pageCount; i++) {
    const id = 3 + i * 3
    const pattern = new RegExp(`^<< /Type /Page /Parent 2 0 R /MediaBox \\[0 0 (${number}) (${number})\\] /BleedBox \\[0 0 \\1 \\2\\] /TrimBox \\[(${number}) (${number}) (${number}) (${number})\\] /Resources << /XObject << /Im0 ${id + 1} 0 R >> >> /Contents ${id + 2} 0 R >>$`)
    const match = (await dictionary(id)).match(pattern)
    if (!match) throw new OrderPaymentError('print_trim_box_mismatch', 409)
    const [width, height, x, y, right, top] = match.slice(1).map(Number)
    if (![width, height, x, y, right, top].every(Number.isFinite) || width <= 0 || height <= 0 || x < 0 || y < 0 || right > width || top > height || right <= x || top <= y) return bad()
    const image = await stream(id + 1)
    const imageMatch = image.dict.match(new RegExp(`^<< /Type /XObject /Subtype /Image /Width (\\d+) /Height (\\d+) /ColorSpace \\[\\/ICCBased ${profileId} 0 R\\] /BitsPerComponent 8 /Filter /DCTDecode /Length ${image.length} >>$`))
    if (!imageMatch) return bad()
    const pixelWidth = Number(imageMatch[1]), pixelHeight = Number(imageMatch[2]), jpeg = await jpegDimensions(image.start, image.length)
    if (jpeg.width !== pixelWidth || jpeg.height !== pixelHeight || pixelWidth < width * 300 / 72 - 1 || pixelHeight < height * 300 / 72 - 1 ||
        pixelWidth > width * 300 / 72 + 1 || pixelHeight > height * 300 / 72 + 1) throw new OrderPaymentError('print_raster_resolution_too_low', 409)
    const content = await stream(id + 2), drawing = `q\n${match[1]} 0 0 ${match[2]} 0 0 cm\n/Im0 Do\nQ\n`
    if (content.dict !== `<< /Length ${content.length} >>` || await text(content.start, content.start + content.length, 256) !== drawing) return bad()
    pages.push({ width, height, trimBox: { x, y, width: right - x, height: top - y } })
  }
  return pages
}

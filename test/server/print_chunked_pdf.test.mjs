import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { join } from 'node:path'
import { checkedChunkParts, createChunkedPdfReader, downloadChunkPdfPart, PRINT_CHUNK_BYTES, PRINT_PDF_CACHE_BYTES, validateChunkedPrintPdf } from '../../supabase/functions/_shared/print-chunked-pdf.ts'
import { inspectAppRasterPdfRanges } from '../../supabase/functions/_shared/print-raster-pdf-range-inspector.ts'
import { inspectAppRasterPdf } from '../../supabase/functions/_shared/print-raster-pdf-inspector.ts'

const origin = 'https://fixture.supabase.co'
const digest = bytes => createHash('sha256').update(bytes).digest('hex')
function storage(bytes) {
  const calls = [], files = new Map(), parts = []
  for (let offset = 0, index = 0; offset < bytes.length; offset += PRINT_CHUNK_BYTES, index++) {
    const value = bytes.subarray(offset, Math.min(bytes.length, offset + PRINT_CHUNK_BYTES)), path = `ordp_fixture/package/interior/part-${String(index).padStart(3, '0')}.bin`
    parts.push({ index, path, byteLength: value.length, sha256: digest(value) }); files.set(path, value)
  }
  const db = { storage: { from: () => ({ createSignedUrl: async path => ({ data: { signedUrl: `${origin}/storage/v1/object/sign/print-packages/${path}?token=fixture` } }) }) } }
  const fetcher = async url => {
    const path = new URL(url).pathname.split('/print-packages/')[1]; calls.push(path)
    const value = files.get(path)
    return value ? new Response(value, { headers: { 'content-length': String(value.length) } }) : new Response(null, { status: 404 })
  }
  return { calls, files, parts, db, fetcher, reader: () => createChunkedPdfReader(db, parts, origin, fetcher) }
}
const rangeReader = bytes => ({ byteLength: bytes.length, read: async (offset, length) => bytes.subarray(offset, offset + length) })

test('range inspector preserves the original closed grammar and rejects identical structural/profile/image tampering', async () => {
  const fixture = JSON.parse(await readFile(new URL('./fixtures/prepayment_raster_pdf.json', import.meta.url), 'utf8')), bytes = Buffer.from(fixture.base64, 'base64')
  assert.deepEqual(await inspectAppRasterPdfRanges(rangeReader(bytes)), await inspectAppRasterPdf(bytes))
  const alter = (from, to) => { assert.equal(from.length, to.length); const modified = Buffer.from(bytes), at = modified.indexOf(Buffer.from(from)); assert.ok(at >= 0); modified.set(Buffer.from(to), at); return modified }
  for (const [from, to, code] of [
    ['/Type /Catalog', '/AA   /Catalog', /invalid_app_print_pdf/],
    ['/Width 12', '/Width 99', /print_raster_resolution_too_low/],
    ['0000000031', '0000000032', /invalid_app_print_pdf/],
    ['endstream', 'endstreaX', /invalid_app_print_pdf/],
    ['/TrimBox', '/CropBox', /print_trim_box_mismatch/],
  ]) await assert.rejects(inspectAppRasterPdfRanges(rangeReader(alter(from, to))), code)
  const profile = Buffer.from(bytes), at = profile.indexOf(Buffer.from('acsp')); profile[at + 60] ^= 1
  await assert.rejects(inspectAppRasterPdfRanges(rangeReader(profile)), /print_srgb_profile_mismatch/)
  await assert.rejects(inspectAppRasterPdfRanges(rangeReader(Buffer.concat([bytes, Buffer.from('/OpenAction')]))), /invalid_app_print_pdf/)
  await assert.rejects(inspectAppRasterPdfRanges({ byteLength: bytes.length, read: async () => new Uint8Array(1) }), /invalid_app_print_pdf/)
})

test('ordered chunks hash to the exact original PDF and boundary ranges never assemble its full buffer', async () => {
  const bytes = Buffer.alloc(50_000_123)
  for (let i = 0; i < bytes.length; i += 997) bytes[i] = i % 251
  for (let i = -16; i < 16; i++) bytes[PRINT_CHUNK_BYTES + i] = i + 17
  const fixture = storage(bytes), reader = fixture.reader()
  assert.equal(await reader.sha256(), digest(bytes))
  assert.equal(fixture.calls.length, 4)
  assert.deepEqual(Buffer.from(await reader.read(PRINT_CHUNK_BYTES - 7, 23)), bytes.subarray(PRINT_CHUNK_BYTES - 7, PRINT_CHUNK_BYTES + 16))
  assert.deepEqual(Buffer.from(await reader.read(bytes.length - 100, 100)), bytes.subarray(bytes.length - 100))
  await assert.rejects(reader.read(0, 32_769), /invalid_app_print_pdf/)
  await assert.rejects(reader.read(bytes.length - 1, 2), /invalid_app_print_pdf/)
  await assert.rejects(reader.read(-1, 2), /invalid_app_print_pdf/)
  reader.clear()
})

test('chunk metadata cannot redirect another package or change length/order/hash; storage bytes are independently checked', async () => {
  const bytes = Buffer.alloc(50_000_001, 7), fixture = storage(bytes)
  const base = 'ordp_fixture/package', pack = { cover_path: `${base}/cover.pdf`, file_parts: { interior: fixture.parts } }
  const declared = { bytes: bytes.length, sha256: digest(bytes), parts: fixture.parts.map(part => ({ bytes: part.byteLength, sha256: part.sha256 })) }
  assert.deepEqual(checkedChunkParts(pack, 'interior', declared), fixture.parts)
  for (const mutation of [parts => parts[0].index = 1, parts => parts[0].path = 'other-owner/x.bin', parts => parts[0].sha256 = 'a'.repeat(64), parts => parts[0].byteLength--]) {
    const changed = structuredClone(fixture.parts); mutation(changed)
    assert.throws(() => checkedChunkParts({ ...pack, file_parts: { interior: changed } }, 'interior', declared), /print_prepayment_file_conflict/)
  }
  fixture.files.set(fixture.parts[0].path, Buffer.alloc(fixture.parts[0].byteLength, 8))
  await assert.rejects(downloadChunkPdfPart(fixture.db, fixture.parts[0], origin, fixture.fetcher), /print_upload_hash_mismatch/)
  fixture.files.delete(fixture.parts[0].path)
  await assert.rejects(downloadChunkPdfPart(fixture.db, fixture.parts[0], origin, fixture.fetcher), /print_upload_missing/)
  let fetched = false
  const malicious = { storage: { from: () => ({ createSignedUrl: async () => ({ data: { signedUrl: 'https://attacker.invalid/x' } }) }) } }
  await assert.rejects(downloadChunkPdfPart(malicious, fixture.parts[0], origin, async () => { fetched = true }), /print_upload_missing/)
  assert.equal(fetched, false)
})

test('verified-object cache is byte bounded before fetch and clear resets the budget and forces tampered bytes to be checked', async () => {
  const bytes = Buffer.alloc(PRINT_PDF_CACHE_BYTES + 50_000, 7), fixture = storage(bytes), reader = fixture.reader()
  assert.equal(fixture.parts.length, 8)
  for(let i=0;i<7;i++)await reader.readPart(i)
  assert.equal(fixture.calls.length, 7)
  await reader.readPart(0) // Move the first object to the most recently used end.
  await reader.readPart(7) // The extra 50KB must evict a 16MB object before fetch.
  assert.equal(fixture.calls.length, 8)
  await reader.readPart(2)
  assert.equal(fixture.calls.length, 8)
  await reader.readPart(1)
  assert.equal(fixture.calls.length, 9)
  reader.clear()
  const before=fixture.calls.length
  for(let i=0;i<7;i++)await reader.readPart(i)
  await reader.readPart(0)
  assert.equal(fixture.calls.length,before+7) // A stale byte counter would evict early.
  reader.clear()
  fixture.files.set(fixture.parts[0].path,Buffer.alloc(PRINT_CHUNK_BYTES,8))
  await assert.rejects(reader.readPart(0),/print_upload_hash_mismatch/)
  reader.clear()
})

const actualDirectory = process.env.SNAPFIT_CHUNKED_FIXTURE_OUTPUT
test('actual 80-page Flutter PDF above 50MB retains every byte and passes full SHA, ICC, 300dpi and all page boxes', { skip: !actualDirectory }, async () => {
  const bytes = await readFile(join(actualDirectory, 'interior.pdf'))
  assert.ok(bytes.length > 50_000_000)
  const fixture = storage(bytes), reader = fixture.reader()
  const result = await validateChunkedPrintPdf(reader, 80, 310, 310)
  assert.equal(result.byteLength, bytes.length); assert.equal(result.sha256, digest(bytes)); assert.equal(result.pageCount, 80)
  if(bytes.length<=PRINT_PDF_CACHE_BYTES)assert.equal(fixture.calls.length,fixture.parts.length)
  else assert.ok(fixture.calls.length>=fixture.parts.length)
  reader.clear()
})

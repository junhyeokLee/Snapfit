import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createHash } from 'node:crypto'
import { readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { createPrintFileDeliveryHandler, createPrintFileDeliveryUrl, checkedPrintFileDeliveryRecord } from '../../supabase/functions/_shared/print-file-delivery.ts'
import { PrintFulfillmentWorker } from '../../supabase/functions/_shared/print-fulfillment-worker.ts'
import { getPrintSpec, sourceFingerprint } from '../../supabase/functions/_shared/print-contract.ts'
import { makeFixture } from './fixtures/print_worker_fixture.mjs'

const orderId = 'ordp_11111111-1111-4111-8111-111111111111', packageId = '22222222-2222-4222-8222-222222222222'
const supabaseUrl = 'https://fixture.supabase.co', secret = 'a'.repeat(64), fixedNow = Date.parse('2026-10-15T01:00:00Z'), chunkSize = 16_000_000
const sha = bytes => createHash('sha256').update(bytes).digest('hex')
const data = new Uint8Array(50_000_001)
for (let at = 0; at < data.length; at += 7919) data[at] = at % 251
const descriptor = (bytes = data, kind = 'interior', order = orderId, pack = packageId) => ({ orderId: order, packageId: pack, kind,
  result: { pageCount: kind === 'cover' ? 1 : 80, widthMm: 310, heightMm: 310, byteLength: bytes.length, sha256: sha(bytes) },
  parts: Array.from({ length: Math.ceil(bytes.length / chunkSize) }, (_, index) => ({ index,
    path: `${order}/${pack}/${kind}/part-${String(index).padStart(3, '0')}.bin`,
    byteLength: Math.min(chunkSize, bytes.length - index * chunkSize), sha256: sha(bytes.subarray(index * chunkSize, (index + 1) * chunkSize)) })) })
const originalRecord = descriptor()
const reference = record => ({ orderId: record.orderId, packageId: record.packageId, kind: record.kind, sha256: record.result.sha256 })
async function fixture(options = {}) {
  const record = structuredClone(options.record ?? originalRecord), bytes = options.bytes ?? data
  const calls = [], db = {
    async rpc(name, args) { calls.push({ name, args }); return { data: options.missing ? null : record, error: options.databaseError ? new Error('private error') : null } },
    storage: { from(bucket) { assert.equal(bucket, 'print-packages'); return { async createSignedUrl(file, seconds) {
      calls.push({ signed: file, seconds }); return { data: { signedUrl: `${supabaseUrl}/storage/v1/object/sign/print-packages/${file}?token=fixture` }, error: null }
    } } } },
  }
  const fetcher = async (url, init) => {
    const parsed = new URL(url), matched = record.parts.find(part => parsed.pathname === `/storage/v1/object/sign/print-packages/${part.path}`)
    assert.ok(matched, 'Fetches only a fixed server-owned object'); calls.push({ fetched: matched.index })
    if (options.fetcher) return options.fetcher(matched, init)
    if (options.missingPart === matched.index) return new Response(null, { status: 404 })
    let content = bytes.subarray(matched.index * chunkSize, matched.index * chunkSize + matched.byteLength)
    if (options.corruptPart === matched.index) { content = content.slice(); content[0] ^= 1 }
    if (options.shortPart === matched.index) content = content.subarray(0, content.length - 1)
    return new Response(new ReadableStream({ start(controller) { controller.enqueue(content); controller.close() } }),
      { headers: { 'Content-Length': String(content.length) } })
  }
  const handler = createPrintFileDeliveryHandler({ secret: () => options.secret ?? secret, supabaseUrl: () => supabaseUrl,
    createAdminDatabase() { calls.push('database-created'); return db }, fetcher, now: () => options.now ?? fixedNow })
  const url = await createPrintFileDeliveryUrl(reference(record), { secret, supabaseUrl, now: fixedNow })
  return { handler, url, record, calls, db, fetcher }
}

test('signed full GET is byte-identical to the original and never stores a combined Storage object', async () => {
  const f = await fixture(), response = await f.handler(new Request(f.url))
  assert.equal(response.status, 200)
  assert.equal(response.headers.get('content-type'), 'application/pdf')
  assert.equal(response.headers.get('content-length'), String(data.length))
  assert.equal(response.headers.get('etag'), `"${originalRecord.result.sha256}"`)
  const received = new Uint8Array(await response.arrayBuffer())
  assert.equal(sha(received), originalRecord.result.sha256)
  assert.deepEqual(received, data)
  assert.deepEqual(f.calls.filter(call => call.fetched !== undefined).map(call => call.fetched), [0, 1, 2, 3])
  assert.ok(f.calls.filter(call => call.signed).every(call => /\/interior\/part-\d{3}\.bin$/.test(call.signed)))
  assert.deepEqual(f.calls.find(call => call.name), { name: 'read_print_file_delivery', args: { p_order_id: orderId, p_package_id: packageId, p_kind: 'interior' } })
})

test('modified, expired, overlong-lifetime, extra/duplicate query, wrong file and missing capability never access database', async () => {
  const f = await fixture(), urls = []
  for (const [key, value] of [['orderId', 'ordp_33333333-3333-4333-8333-333333333333'], ['packageId', orderId.slice(5)], ['kind', 'cover'],
    ['sha256', 'b'.repeat(64)], ['expires', String(Math.floor(fixedNow / 1000) - 1)], ['expires', String(Math.floor(fixedNow / 1000) + 3601)],
    ['signature', 'b'.repeat(64)], ['ownerId', 'unauthorized-owner']]) {
    const next = new URL(f.url); next.searchParams.set(key, value); urls.push(next.href)
  }
  const duplicate = new URL(f.url); duplicate.searchParams.append('kind', 'interior'); urls.push(duplicate.href)
  const wrongPath = new URL(f.url); wrongPath.pathname = '/functions/v1/print-file-delivery/cover.pdf'; urls.push(wrongPath.href)
  urls.push(`${supabaseUrl}/functions/v1/print-file-delivery`, f.url.replace('signature=', 'signature=x'))
  for (const url of urls) assert.equal((await f.handler(new Request(url))).status, 401)
  assert.equal(f.calls.length, 0)
  const disabled = await fixture({ secret: '' }); assert.equal((await disabled.handler(new Request(disabled.url))).status, 401)
  assert.equal(disabled.calls.length, 0)
})

test('only GET and HEAD are permitted; HEAD checks paid immutable DB facts without reading artwork', async () => {
  const f = await fixture(), head = await f.handler(new Request(f.url, { method: 'HEAD' }))
  assert.equal(head.status, 200); assert.equal(await head.text(), '')
  assert.equal(head.headers.get('content-length'), String(data.length))
  assert.equal(f.calls.some(call => call.signed || call.fetched !== undefined), false)
  for (const method of ['POST', 'PUT', 'DELETE', 'OPTIONS']) assert.equal((await f.handler(new Request(f.url, { method }))).status, 405)
  assert.equal(f.calls.filter(call => call.name).length, 1)
  const hosted = new URL(f.url); hosted.pathname = '/print-file-delivery/interior.pdf'
  assert.equal((await f.handler(new Request(hosted.href, { method: 'HEAD' }))).status, 200)
})

test('private RPC missing, held/unpaid, changed references, wrong hash or malformed paths fail closed', async () => {
  for (const options of [{ missing: true }, { databaseError: true }]) {
    const f = await fixture(options); assert.equal((await f.handler(new Request(f.url))).status, 404)
    assert.equal(f.calls.some(call => call.signed), false)
  }
  for (const mutate of [record => { record.orderId = 'ordp_33333333-3333-4333-8333-333333333333' },
    record => { record.packageId = orderId.slice(5) }, record => { record.kind = 'cover' }, record => { record.result.sha256 = 'b'.repeat(64) },
    record => { record.result.byteLength = 50_000_000 }, record => { record.result.byteLength = 500_000_001 },
    record => { record.result.pageCount = 81 }, record => { record.result.url = 'https://outside.invalid/secret' },
    record => { record.parts[0].path = `${orderId}/${packageId}/interior/../part-000.bin` },
    record => { record.parts[0].path = `ordp_33333333-3333-4333-8333-333333333333/${packageId}/interior/part-000.bin` },
    record => { record.parts[0].index = 1 }, record => { record.parts[0].byteLength-- }, record => { record.parts[0].sha256 = 'invalid' },
    record => { record.parts.push(record.parts[0]) }, record => { record.parts.reverse() }]) {
    const record = structuredClone(originalRecord); mutate(record)
    assert.throws(() => checkedPrintFileDeliveryRecord(record, reference(originalRecord)), /invalid_print_file_delivery/)
  }
})

test('single byte ranges across part boundaries and suffix/open ranges preserve exact original bytes', async () => {
  for (const [header, first, last] of [['bytes=15999996-16000009', 15999996, 16000009], ['bytes=-7', data.length - 7, data.length - 1],
    [`bytes=${data.length - 9}-`, data.length - 9, data.length - 1]]) {
    const f = await fixture(), response = await f.handler(new Request(f.url, { headers: { Range: header } }))
    assert.equal(response.status, 206)
    assert.equal(response.headers.get('content-length'), String(last - first + 1))
    assert.equal(response.headers.get('content-range'), `bytes ${first}-${last}/${data.length}`)
    assert.deepEqual(new Uint8Array(await response.arrayBuffer()), data.subarray(first, last + 1))
    assert.equal(f.calls.filter(call => call.fetched !== undefined).length, first < chunkSize && last >= chunkSize ? 2 : 1)
  }
  const f = await fixture()
  for (const value of ['bytes=0-1,2-3', 'bytes=-0', 'bytes=1-0', `bytes=${data.length}-`, 'bytes=9007199254740992-', 'items=1-3', 'bytes=-']) {
    const response = await f.handler(new Request(f.url, { headers: { Range: value } }))
    assert.equal(response.status, 416); assert.equal(response.headers.get('content-range'), `bytes */${data.length}`)
  }
  assert.equal(f.calls.some(call => call.signed), false)
})

test('a corrupted/missing/truncated part aborts before that part is emitted', async () => {
  for (const options of [{ corruptPart: 0 }, { missingPart: 0 }, { shortPart: 0 }]) {
    const f = await fixture(options), response = await f.handler(new Request(f.url))
    await assert.rejects(response.body.getReader().read(), /print_file_delivery_failed/)
    assert.deepEqual(f.calls.filter(call => call.fetched !== undefined).map(call => call.fetched), [0])
  }
  const f = await fixture({ corruptPart: 1 }), response = await f.handler(new Request(f.url))
  const reader = response.body.getReader(); let length = 0
  await assert.rejects(async () => { for (;;) { const item = await reader.read(); if (item.done) break; length += item.value.length } }, /print_file_delivery_failed/)
  assert.equal(length, chunkSize)
  assert.deepEqual(f.calls.filter(call => call.fetched !== undefined).map(call => call.fetched), [0, 1])
})

test('backpressure does not prefetch the next part; cancel aborts ongoing work and no later objects are read', async () => {
  const f = await fixture(), response = await f.handler(new Request(f.url))
  assert.equal(f.calls.some(call => call.signed), false)
  const reader = response.body.getReader(), first = await reader.read()
  assert.equal(first.value.length, 256 * 1024)
  assert.deepEqual(f.calls.filter(call => call.fetched !== undefined).map(call => call.fetched), [0])
  await reader.cancel()
  assert.deepEqual(f.calls.filter(call => call.fetched !== undefined).map(call => call.fetched), [0])
  const canceled = new AbortController(); canceled.abort('stopped')
  const stopped = await fixture(), stoppedResponse = await stopped.handler(new Request(stopped.url, { signal: canceled.signal }))
  await assert.rejects(stoppedResponse.body.getReader().read(), /print_file_delivery_failed/)
  assert.equal(stopped.calls.some(call => call.signed), false)
})

test('worker uses paid RPC capabilities only for large chunks, preserving direct PDF checks and immutable manifest equality', async () => {
  const f = makeFixture(), pack = packageId, directBytes = new TextEncoder().encode('previously-validated-cover-fixture')
  f.order.order_id = orderId
  const record = descriptor(data, 'interior', f.order.order_id, pack)
  const frozen = { ...f.order, print_upload_id: pack, print_cover_pdf_path: `${f.order.order_id}/${pack}/cover.pdf`, print_interior_pdf_path: `${f.order.order_id}/${pack}/interior.pdf` }
  frozen.print_manifest = { sourceFingerprint: await sourceFingerprint(frozen), spec: getPrintSpec(frozen),
    cover: { pageCount: 1, widthMm: 417.22, heightMm: 160, byteLength: directBytes.length, sha256: sha(directBytes) }, interior: record.result,
    fileTransport: { version: 'CHUNKED_V1', files: { interior: record.parts } } }
  const calls = [], db = { async rpc(name, args) { calls.push({ name, args }); return { data: record, error: null } }, storage: { from(bucket) {
    assert.equal(bucket, 'print-packages'); return { async download(file) { calls.push({ downloaded: file }); return { data: new Blob([directBytes]), error: null } },
      async createSignedUrl(file) { calls.push({ signed: file }); return { data: { signedUrl: `${supabaseUrl}/storage/v1/object/sign/print-packages/${file}?fixture=true` }, error: null } } }
  } } }
  const worker = new PrintFulfillmentWorker(db, { ...f.config, supabaseUrl, deliverySecret: secret }, f.vendor, f.sender, { now: () => fixedNow })
  const files = await worker.fileLinks({ order: frozen })
  assert.match(files.cover, /\/cover\.pdf\?/)
  assert.match(files.interior, /\/functions\/v1\/print-file-delivery\/interior\.pdf\?/)
  assert.equal(new URL(files.interior).searchParams.get('sha256'), record.result.sha256)
  assert.equal(calls.filter(call => call.downloaded).length, 1)
  assert.equal(calls.some(call => call.downloaded?.includes('interior') || call.signed?.includes('interior')), false)
  assert.deepEqual(calls.find(call => call.name), { name: 'read_print_file_delivery', args: { p_order_id: f.order.order_id, p_package_id: pack, p_kind: 'interior' } })
  const before = frozen.print_manifest.fileTransport.files.interior[0].sha256
  frozen.print_manifest.fileTransport.files.interior = structuredClone(record.parts)
  frozen.print_manifest.fileTransport.files.interior[0].sha256 = 'c'.repeat(64)
  await assert.rejects(worker.fileLinks({ order: frozen }), /print_preflight_failed/)
  frozen.print_manifest.fileTransport.files.interior[0].sha256 = before
  const noSecret = new PrintFulfillmentWorker(db, { ...f.config, supabaseUrl }, f.vendor, f.sender, { now: () => fixedNow })
  await assert.rejects(noSecret.fileLinks({ order: frozen }), /print_file_delivery_unavailable/)
})

const actualRoot = process.env.SNAPFIT_LARGE_PDF_FIXTURE_OUTPUT ?? 'output/pdf/print-worker-hard300-80-fixture-2026-10-14'
let actualExists = false
try { actualExists = (await stat(path.join(actualRoot, 'interior.pdf'))).size > 50_000_000 } catch { /* Portable unit suite still exercises an oversized binary above. */ }
test('actual 300dpi 80-page hardcover interior is delivered unchanged beyond the 50MB object cap', { skip: !actualExists }, async () => {
  const bytes = new Uint8Array(await readFile(path.join(actualRoot, 'interior.pdf'))), record = descriptor(bytes)
  const artwork = JSON.parse(await readFile(path.join(actualRoot, 'fixture.json'), 'utf8'))
  assert.equal(artwork.spec.pageCount, 80); assert.equal(artwork.spec.dpi, 300); assert.equal(artwork.spec.colorSpace, 'sRGB')
  assert.ok(bytes.length > 50_000_000)
  const f = await fixture({ bytes, record }), response = await f.handler(new Request(f.url))
  assert.equal(response.status, 200)
  const received = new Uint8Array(await response.arrayBuffer())
  assert.equal(sha(received), sha(bytes)); assert.deepEqual(received, bytes)
  assert.equal(record.parts.length, Math.ceil(bytes.length / chunkSize))
  assert.ok(record.parts.every(part => part.byteLength <= chunkSize))
})

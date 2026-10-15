import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createHash } from 'node:crypto'
import { createPrintFileDeliveryHandler, createPrintFileDeliveryUrl } from '../../supabase/functions/_shared/print-file-delivery.ts'

const orderId = 'ordp_11111111-1111-4111-8111-111111111111', packageId = '22222222-2222-4222-8222-222222222222',
  secret = 'a'.repeat(64), now = Date.parse('2026-10-15T03:00:00Z'), supabaseUrl = 'https://fixture.supabase.co'
const bytes = new Uint8Array(2048).fill(42), sha256 = createHash('sha256').update(bytes).digest('hex')
const reference = { orderId, packageId, kind: 'cover', sha256 }
const record = { ...reference, result: { pageCount: 1, widthMm: 681.2, heightMm: 346, byteLength: bytes.length, sha256 }, parts: [] }
function fixture(development = true, overrides = {}) {
  const calls = [], database = { async rpc(name, args) { calls.push({ rpc: name, args }); return { data: overrides.record ?? record, error: null } },
    storage: { from(bucket) { assert.equal(bucket, 'print-packages'); return { async createSignedUrl(path) {
      calls.push({ signed: path }); return { data: { signedUrl: `${supabaseUrl}/storage/v1/object/sign/print-packages/${path}?fixture` }, error: null }
    } } } } }
  const handler = createPrintFileDeliveryHandler({ ...(development ? { development: true } : {}), secret: () => secret,
    supabaseUrl: () => supabaseUrl, now: () => now, createAdminDatabase() { calls.push('database'); return database },
    fetcher: async () => new Response(new ReadableStream({ start(controller) { controller.enqueue(bytes); controller.close() } }), { headers: { 'Content-Length': String(bytes.length) } }) })
  return { handler, calls }
}
test('DEV direct cover uses only TEST receipt read RPC and serves unchanged bytes at a fixed private path', async () => {
  const f = fixture(), url = await createPrintFileDeliveryUrl(reference, { development: true, secret, supabaseUrl, now })
  const response = await f.handler(new Request(url)); assert.equal(response.status, 200)
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes)
  assert.deepEqual(f.calls.find(call => call.rpc), { rpc: 'read_print_dev_file_delivery', args: { p_order_id: orderId, p_package_id: packageId, p_kind: 'cover' } })
  assert.equal(f.calls.find(call => call.signed).signed, `${orderId}/${packageId}/cover.pdf`)
})
test('production and DEV HMAC domains cannot be exchanged even by changing endpoint paths', async () => {
  for (const sourceDevelopment of [true, false]) {
    const url = new URL(await createPrintFileDeliveryUrl(reference, { ...(sourceDevelopment ? { development: true } : {}), secret, supabaseUrl, now }))
    url.pathname = `/functions/v1/${sourceDevelopment ? 'print-file-delivery' : 'print-dev-file-delivery'}/cover.pdf`
    const f = fixture(!sourceDevelopment)
    assert.equal((await f.handler(new Request(url))).status, 401); assert.equal(f.calls.length, 0)
  }
})
test('request cannot select TEST authority or another delivery RPC through extra query flags', async () => {
  const url = new URL(await createPrintFileDeliveryUrl(reference, { development: true, secret, supabaseUrl, now }))
  url.searchParams.set('development', 'true')
  const f = fixture(); assert.equal((await f.handler(new Request(url))).status, 401); assert.equal(f.calls.length, 0)
})
test('DEV direct HEAD and Range retain receipt authority without treating a virtual large path as a direct object', async () => {
  const url = await createPrintFileDeliveryUrl(reference, { development: true, secret, supabaseUrl, now }), f = fixture()
  assert.equal((await f.handler(new Request(url, { method: 'HEAD' }))).headers.get('content-length'), String(bytes.length))
  assert.equal(f.calls.some(call => call.signed), false)
  const ranged = await f.handler(new Request(url, { headers: { range: 'bytes=101-111' } }))
  assert.equal(ranged.status, 206); assert.deepEqual(new Uint8Array(await ranged.arrayBuffer()), bytes.subarray(101, 112))
  const invalid = fixture(true, { record: { ...record, result: { ...record.result, byteLength: 50_000_001 } } })
  assert.equal((await invalid.handler(new Request(url))).status, 503)
  assert.equal(invalid.calls.some(call => call.signed), false)
})

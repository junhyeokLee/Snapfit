import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { test } from 'node:test'
import { createSocialMediaHandler } from '../../supabase/functions/_shared/social-media.ts'

// In-memory Storage and injected RPCs only. No deployed objects are accessed.
const owner = '11111111-1111-4111-8111-111111111111'
const work = '22222222-2222-4222-8222-222222222222'
const alias = '33333333-3333-4333-8333-333333333333'
const jobId = '44444444-4444-4444-8444-444444444444'
const oldPath = `${owner}/${work}/0.png`, newPath = `${owner}/${alias}/0.png`
const png = new Uint8Array(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64'))
const sha256 = value => createHash('sha256').update(value).digest('hex')
const ok = data => ({ data, error: null })
const failed = status => ({ data: null, error: { statusCode: String(status), message: 'PRIVATE INTERNAL PATH MUST NOT LEAK' } })
const get = (token = 'view-cap', extra = '') => new Request(`https://example.invalid/social-media?work=${work}&position=0&token=${token}${extra}`)
const post = (body = { action: 'rotate', token: 'rotate-cap' }) => new Request('https://example.invalid/social-media', { method: 'POST', body: JSON.stringify(body) })

function fixture(options = {}) {
  const calls = [], objects = new Map([[oldPath, png]])
  const job = { id: jobId, workId: work, position: 0, oldPath, newPath, expectedSize: png.length, expectedSha: null, ...options.job }
  let visible = true, mapping = oldPath, completed = false
  let removeFailures = options.removeFailures ?? 0, finishFailures = options.finishFailures ?? 0
  const storage = {
    async download(path) {
      calls.push(['download', path])
      if (options.afterDownload) options.afterDownload(path, () => visible = false)
      const bytes = objects.get(path)
      return bytes ? ok(new Blob([bytes], { type: 'image/png' })) : failed(404)
    },
    async copy(from, to) {
      calls.push(['copy', from, to])
      if (options.copyFailure) return failed(options.copyFailure)
      if (objects.has(to)) return failed(409)
      const source = objects.get(from)
      if (!source) return failed(404)
      const bytes = new Uint8Array(source)
      if (options.corruptCopy) bytes[bytes.length - 1] ^= 1
      objects.set(to, bytes)
      return ok({ path: to })
    },
    async remove(paths) {
      calls.push(['remove', paths])
      if (removeFailures-- > 0) return failed(503)
      for (const path of paths) objects.delete(path)
      return ok([])
    },
  }
  const db = { async rpc(name, params) {
    calls.push([name, params])
    if (name === 'social_media_descriptor') {
      if (params.p_token !== 'view-cap' || !visible || options.denied) return ok(null)
      return ok(options.descriptor ?? { path: mapping, mime: 'image/png' })
    }
    if (name === 'claim_social_media_rotations') {
      if (params.p_token !== 'rotate-cap') return failed(403)
      return ok(options.claim ?? (completed ? [] : [{ ...job }]))
    }
    if (name === 'mark_social_media_rotation_digest') {
      if (options.digestFailure) return ok(false)
      assert.equal(params.p_size, job.expectedSize)
      assert.equal(params.p_sha256, sha256(png))
      job.expectedSha = params.p_sha256
      return ok(true)
    }
    if (name === 'commit_social_media_rotation') {
      if (options.commitFailure) return ok(false)
      assert.equal(params.p_sha256, job.expectedSha)
      assert.equal(sha256(objects.get(newPath)), job.expectedSha)
      mapping = newPath
      return ok(true)
    }
    if (name === 'finish_social_media_rotation') {
      if (finishFailures-- > 0) return failed(503)
      assert.equal(mapping, newPath)
      assert.equal(objects.has(oldPath), false)
      completed = true
      return ok(true)
    }
    throw new Error('unexpected rpc')
  } }
  const handler = createSocialMediaHandler({ createAdminDatabase: () => db, storage: () => storage, now: options.now })
  return { handler, calls, objects, job }
}

function privateHeaders(response) {
  assert.equal(response.headers.get('Cache-Control'), 'private, no-store, max-age=0')
  assert.equal(response.headers.get('CDN-Cache-Control'), 'no-store')
  assert.equal(response.headers.get('X-Content-Type-Options'), 'nosniff')
  assert.equal(response.headers.get('Referrer-Policy'), 'no-referrer')
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), '*')
  assert.equal(response.headers.get('Location'), null)
  assert.equal(response.headers.get('ETag'), null)
}

test('GET releases only PNG bytes after checking capability and current state twice', async () => {
  const f = fixture(), response = await f.handler(get())
  assert.equal(response.status, 200)
  privateHeaders(response)
  assert.equal(response.headers.get('Content-Type'), 'image/png')
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), png)
  assert.deepEqual(f.calls.map(call => call[0]), ['social_media_descriptor', 'download', 'social_media_descriptor'])
  assert.deepEqual(f.calls[0][1], { p_work_id: work, p_position: 0, p_token: 'view-cap' })
})

test('stale capability, private content and management-only capabilities get identical no-store 404s before Storage', async () => {
  for (const [options, request] of [[{}, get('expired')], [{ denied: true }, get()], [{}, get('rotate-cap')]]) {
    const f = fixture(options), response = await f.handler(request)
    assert.equal(response.status, 404)
    privateHeaders(response)
    assert.deepEqual(await response.json(), { error: 'not_found' })
    assert.equal(f.calls.some(call => call[0] === 'download'), false)
  }
})

test('revocation during download prevents releasing previously authorized bytes', async () => {
  const f = fixture({ afterDownload: (_, revoke) => revoke() })
  const response = await f.handler(get())
  assert.equal(response.status, 404)
  assert.deepEqual(await response.json(), { error: 'not_found' })
  assert.equal(f.calls.filter(call => call[0] === 'social_media_descriptor').length, 2)
})

test('GET rejects invalid or repeated identifiers and unsupported formats without database access', async () => {
  for (const request of [
    new Request('https://example.invalid/?work=not-uuid&position=0&token=x'),
    new Request(`https://example.invalid/?work=${work}&position=20&token=x`),
    new Request(`https://example.invalid/?work=${work}&position=00&token=x`),
    get('view-cap', '&token=another'), get('view-cap', '&path=album-assets/original.jpg'),
  ]) {
    const f = fixture(), response = await f.handler(request)
    assert.equal(response.status, 404)
    assert.equal(f.calls.length, 0)
  }
  for (const descriptor of [{ path: `../${oldPath}`, mime: 'image/png' }, { path: oldPath, mime: 'image/svg+xml' }]) {
    const f = fixture({ descriptor }), response = await f.handler(get())
    assert.equal(response.status, 404)
    assert.equal(f.calls.some(call => call[0] === 'download'), false)
  }
})

test('GET rejects malformed PNG, decompression bombs and over-eight-MiB blobs', async () => {
  const badDimensions = new Uint8Array(png)
  new DataView(badDimensions.buffer).setUint32(16, 100_000)
  for (const bytes of [new Uint8Array(100), badDimensions, new Uint8Array(8 * 1024 * 1024 + 1)]) {
    const f = fixture()
    f.objects.set(oldPath, bytes)
    const response = await f.handler(get())
    assert.equal(response.status, 404)
    privateHeaders(response)
    assert.deepEqual(await response.json(), { error: 'not_found' })
  }
})

test('OPTIONS and all rejected requests carry no-store security headers', async () => {
  const f = fixture()
  const options = await f.handler(new Request('https://example.invalid', { method: 'OPTIONS' }))
  assert.equal(options.status, 204)
  privateHeaders(options)
  const method = await f.handler(new Request('https://example.invalid', { method: 'PUT' }))
  assert.equal(method.status, 405)
  privateHeaders(method)
  assert.equal(f.calls.length, 0)
})

test('rotation rejects missing, malformed, oversized and wrong-scope requests without object I/O', async () => {
  for (const body of [{ action: 'delete', token: 'rotate-cap' }, { action: 'rotate', token: '' }, { action: 'rotate', token: 'rotate-cap', path: oldPath }]) {
    const f = fixture(), response = await f.handler(post(body))
    assert.equal(response.status, 400)
    assert.equal(f.calls.length, 0)
  }
  const oversized = fixture()
  assert.equal((await oversized.handler(new Request('https://example.invalid', { method: 'POST', body: 'x'.repeat(8193) }))).status, 400)
  assert.equal(oversized.calls.length, 0)
  const wrongScope = fixture()
  assert.equal((await wrongScope.handler(post({ action: 'rotate', token: 'view-cap' }))).status, 401)
  assert.equal(wrongScope.calls.some(call => ['download', 'copy', 'remove'].includes(call[0])), false)
})

test('rotation verifies exact bytes before mapping CAS and deletes only old snapshot via Storage API', async () => {
  const f = fixture(), response = await f.handler(post())
  assert.equal(response.status, 200)
  privateHeaders(response)
  const result = await response.json()
  assert.deepEqual(result, { status: 'ok', claimed: 1, completed: 1, pending: 0, errors: 0 })
  assert.deepEqual(f.calls.map(call => call[0]), [
    'claim_social_media_rotations', 'download', 'mark_social_media_rotation_digest',
    'copy', 'download', 'commit_social_media_rotation', 'remove', 'finish_social_media_rotation',
  ])
  assert.equal(f.objects.has(oldPath), false)
  assert.deepEqual(f.objects.get(newPath), png)
  assert.equal(JSON.stringify(result).includes(owner), false)
})

test('copy conflicts are accepted only after the existing destination hashes identically', async () => {
  const valid = fixture()
  valid.objects.set(newPath, new Uint8Array(png))
  assert.equal((await (await valid.handler(post())).json()).completed, 1)
  const invalid = fixture(), corrupt = new Uint8Array(png)
  corrupt[corrupt.length - 1] ^= 1
  invalid.objects.set(newPath, corrupt)
  const response = await invalid.handler(post())
  assert.equal((await response.json()).errors, 1)
  assert.equal(invalid.objects.has(oldPath), true)
  assert.equal(invalid.calls.some(call => call[0] === 'commit_social_media_rotation' || call[0] === 'remove'), false)
})

test('failed copy verification, digest persistence or CAS never deletes old bytes', async () => {
  for (const options of [{ corruptCopy: true }, { digestFailure: true }, { commitFailure: true }, { copyFailure: 503 }, { job: { expectedSize: png.length + 1 } }, { job: { expectedSha: 'a'.repeat(64) } }]) {
    const f = fixture(options), response = await f.handler(post())
    assert.equal((await response.json()).completed, 0)
    assert.equal(f.objects.has(oldPath), true)
    assert.equal(f.calls.some(call => call[0] === 'remove'), false)
  }
})

test('a cleanup failure retries safely with persisted digest and verified copy', async () => {
  const f = fixture({ removeFailures: 1 })
  const first = await (await f.handler(post())).json()
  assert.equal(first.pending, 1)
  assert.equal(f.objects.has(oldPath), true)
  const second = await (await f.handler(post())).json()
  assert.equal(second.completed, 1)
  assert.equal(f.objects.has(oldPath), false)
  assert.equal(f.calls.filter(call => call[0] === 'copy').length, 2)
})

test('a finish failure after removal recovers from the new bytes without recopying or losing the mapping', async () => {
  const f = fixture({ finishFailures: 1 })
  assert.equal((await (await f.handler(post())).json()).pending, 1)
  assert.equal(f.objects.has(oldPath), false)
  assert.equal((await (await f.handler(post())).json()).completed, 1)
  assert.equal(f.calls.filter(call => call[0] === 'copy').length, 1)
  assert.equal((await (await f.handler(post())).json()).claimed, 0)
})

test('missing old bytes without an authenticated persisted digest cannot authorize commit or cleanup', async () => {
  const f = fixture()
  f.objects.delete(oldPath)
  f.objects.set(newPath, png)
  assert.equal((await (await f.handler(post())).json()).errors, 1)
  assert.equal(f.calls.some(call => ['commit_social_media_rotation', 'remove', 'finish_social_media_rotation'].includes(call[0])), false)
})

test('rotation validates owner scope, positions, duplicate leases and bounded claims before Storage', async () => {
  for (const options of [
    { job: { newPath: `${alias}/${work}/0.png` } }, { job: { newPath: oldPath } },
    { job: { position: 1 } }, { job: { oldPath: `../${oldPath}` } },
    { job: { expectedSize: 8 * 1024 * 1024 + 1 } },
  ]) {
    const f = fixture(options), response = await f.handler(post())
    assert.equal(response.status, 503)
    assert.equal(f.calls.some(call => ['download', 'copy', 'remove'].includes(call[0])), false)
  }
  for (const count of [2, 21]) {
    const f = fixture({ claim: Array.from({ length: count }, () => ({ id: jobId, workId: work, position: 0, oldPath, newPath, expectedSize: png.length })) })
    assert.equal((await f.handler(post())).status, 503)
    assert.equal(f.calls.some(call => call[0] === 'download'), false)
  }
})

test('deadline leaves claimed work pending and never starts new object I/O after the budget', async () => {
  let calls = 0
  const f = fixture({ now: () => calls++ ? 26_000 : 0 })
  assert.deepEqual(await (await f.handler(post())).json(), { status: 'partial', claimed: 1, completed: 0, pending: 1, errors: 0 })
  assert.equal(f.calls.some(call => call[0] === 'download'), false)
})

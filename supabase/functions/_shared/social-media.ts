type Result<T = unknown> = { data: T; error: unknown }
type Database = {
  rpc(name: string, params: Record<string, unknown>): PromiseLike<Result>
}
type Storage = {
  download(path: string): PromiseLike<Result<Blob | null>>
  copy(fromPath: string, toPath: string): PromiseLike<Result>
  remove(paths: string[]): PromiseLike<Result>
}
type Dependencies = {
  createAdminDatabase(): Database
  storage(database: Database): Storage
  now?(): number
}
type Rotation = {
  id: string
  workId: string
  position: number
  oldPath: string
  newPath: string
  expectedSize: number
  expectedSha: string | null
}

const maxBytes = 8 * 1024 * 1024
const maxJobs = 20
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Cache-Control': 'private, no-store, max-age=0',
  'CDN-Cache-Control': 'no-store',
  'Surrogate-Control': 'no-store',
  'Pragma': 'no-cache',
  'Expires': '0',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cross-Origin-Resource-Policy': 'cross-origin',
}
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)
const token = (value: unknown): value is string => typeof value === 'string' &&
  value.length > 0 && value.length <= 4096 && /^[\x21-\x7e]+$/.test(value)
const object = (value: unknown): Record<string, unknown> | null =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown> : null
const pathParts = (value: unknown): string[] | null => {
  if (typeof value !== 'string') return null
  const parts = value.split('/')
  return parts.length === 3 && uuid(parts[0]) && uuid(parts[1]) &&
    /^(?:[0-9]|1[0-9])\.png$/.test(parts[2]) ? parts : null
}
const reply = (body: unknown, status = 200) => Response.json(body, { status, headers })

async function rpc(database: Database, name: string, params: Record<string, unknown>) {
  const result = await database.rpc(name, params)
  if (result.error) throw new Error('media_operation_unavailable')
  return result.data
}

function descriptor(value: unknown): { path: string; mime: string } | null {
  const row = object(value)
  return row && pathParts(row.path) && row.mime === 'image/png'
    ? { path: row.path as string, mime: row.mime } : null
}

function validPng(bytes: Uint8Array) {
  if (bytes.length < 33 || bytes.length > maxBytes) return false
  const signature = [137, 80, 78, 71, 13, 10, 26, 10]
  if (signature.some((byte, index) => bytes[index] !== byte) ||
      bytes[12] !== 73 || bytes[13] !== 72 || bytes[14] !== 68 || bytes[15] !== 82) return false
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const width = view.getUint32(16), height = view.getUint32(20)
  return view.getUint32(8) === 13 && width > 0 && height > 0 &&
    width <= 8000 && height <= 8000 && width * height <= 32_000_000
}

async function download(storage: Storage, path: string) {
  const result = await storage.download(path)
  if (result.error || !result.data || result.data.size > maxBytes || result.data.size < 33) {
    throw new Error('media_object_unavailable')
  }
  const bytes = new Uint8Array(await result.data.arrayBuffer())
  if (!validPng(bytes)) throw new Error('media_object_unavailable')
  return bytes
}

async function digest(bytes: Uint8Array) {
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', new Uint8Array(bytes)))
  return Array.from(hash, byte => byte.toString(16).padStart(2, '0')).join('')
}

function rotation(value: unknown): Rotation | null {
  const row = object(value)
  if (!row || !uuid(row.id) || !uuid(row.workId) ||
      !Number.isInteger(row.position) || Number(row.position) < 0 || Number(row.position) > 19 ||
      !Number.isInteger(row.expectedSize) || Number(row.expectedSize) < 33 || Number(row.expectedSize) > maxBytes ||
      (row.expectedSha != null && (typeof row.expectedSha !== 'string' || !/^[0-9a-f]{64}$/.test(row.expectedSha)))) return null
  const before = pathParts(row.oldPath), after = pathParts(row.newPath)
  if (!before || !after || before[0] !== after[0] || before[1] === after[1] ||
      before[2] !== `${row.position}.png` || after[2] !== before[2]) return null
  return {
    id: row.id, workId: row.workId, position: Number(row.position),
    oldPath: row.oldPath as string, newPath: row.newPath as string,
    expectedSize: Number(row.expectedSize), expectedSha: row.expectedSha as string | null ?? null,
  }
}

const statusCode = (error: unknown): number | null => {
  const value = object(error)
  const status = Number(value?.statusCode ?? value?.status)
  return Number.isInteger(status) ? status : null
}

async function rotateOne(database: Database, storage: Storage, job: Rotation) {
  let oldBytes: Uint8Array | null = null
  try { oldBytes = await download(storage, job.oldPath) } catch {
    // A prior run can have committed and removed the old object before its
    // finish acknowledgement failed. Only the digest persisted by SQL can
    // authorize recovery without reading the old bytes again.
    if (!job.expectedSha) throw new Error('rotation_source_unavailable')
  }
  let sha = job.expectedSha
  if (oldBytes) {
    sha = await digest(oldBytes)
    if (oldBytes.length !== job.expectedSize || job.expectedSha && job.expectedSha !== sha) {
      throw new Error('rotation_source_mismatch')
    }
    if (await rpc(database, 'mark_social_media_rotation_digest', {
      p_id: job.id, p_sha256: sha, p_size: oldBytes.length,
    }) !== true) throw new Error('rotation_digest_unconfirmed')
    const copied = await storage.copy(job.oldPath, job.newPath)
    if (copied.error && statusCode(copied.error) !== 409) throw new Error('rotation_copy_unavailable')
  }
  const newBytes = await download(storage, job.newPath)
  if (newBytes.length !== job.expectedSize || await digest(newBytes) !== sha) {
    throw new Error('rotation_destination_mismatch')
  }
  if (await rpc(database, 'commit_social_media_rotation', {
    p_id: job.id, p_sha256: sha,
  }) !== true) throw new Error('rotation_commit_unconfirmed')
  // Removal always uses Storage API after the mapping CAS has acknowledged the
  // verified replacement. Never delete storage.objects directly or overwrite.
  const removed = await storage.remove([job.oldPath])
  if (removed.error && statusCode(removed.error) !== 404) throw new Error('rotation_cleanup_unavailable')
  if (await rpc(database, 'finish_social_media_rotation', {
    p_id: job.id, p_sha256: sha,
  }) !== true) throw new Error('rotation_finish_unconfirmed')
}

async function readBody(request: Request): Promise<unknown> {
  const length = request.headers.get('Content-Length')
  if (length && (!/^\d+$/.test(length) || Number(length) > 8192)) throw new Error('invalid_request')
  if (!request.body) throw new Error('invalid_request')
  const reader = request.body.getReader(), chunks: Uint8Array[] = []
  let size = 0
  try {
    while (true) {
      const chunk = await reader.read()
      if (chunk.done) break
      size += chunk.value.length
      if (size > 8192) { await reader.cancel(); throw new Error('invalid_request') }
      chunks.push(chunk.value)
    }
  } finally { reader.releaseLock() }
  const bytes = new Uint8Array(size)
  let offset = 0
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length }
  return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes))
}

export function createSocialMediaHandler(dependencies: Dependencies) {
  return async (request: Request) => {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers })
    if (request.method === 'GET') {
      try {
        const query = new URL(request.url).searchParams
        if ([...query.keys()].some(key => !['work', 'position', 'token'].includes(key)) ||
            ['work', 'position', 'token'].some(key => query.getAll(key).length !== 1) ||
            !uuid(query.get('work')) || !/^(?:[0-9]|1[0-9])$/.test(query.get('position') ?? '') ||
            !token(query.get('token'))) return reply({ error: 'not_found' }, 404)
        const params = { p_work_id: query.get('work'), p_position: Number(query.get('position')), p_token: query.get('token') }
        const database = dependencies.createAdminDatabase()
        const before = descriptor(await rpc(database, 'social_media_descriptor', params))
        if (!before) return reply({ error: 'not_found' }, 404)
        const bytes = await download(dependencies.storage(database), before.path)
        const after = descriptor(await rpc(database, 'social_media_descriptor', params))
        // Revocation, blocking, expiry, source edits and path epochs are checked
        // again after I/O, immediately before releasing any image bytes.
        if (!after || after.path !== before.path || after.mime !== before.mime) return reply({ error: 'not_found' }, 404)
        return new Response(bytes, { headers: { ...headers,
          'Content-Type': 'image/png', 'Content-Length': String(bytes.length), 'Content-Disposition': 'inline' } })
      } catch { return reply({ error: 'not_found' }, 404) }
    }
    if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    let body: Record<string, unknown> | null
    try { body = object(await readBody(request)) } catch { return reply({ error: 'invalid_request' }, 400) }
    if (!body || body.action !== 'rotate' || !token(body.token) ||
        Object.keys(body).some(key => !['action', 'token'].includes(key))) return reply({ error: 'invalid_request' }, 400)
    const started = dependencies.now?.() ?? Date.now()
    let database: Database, claimed: unknown
    try {
      database = dependencies.createAdminDatabase()
      claimed = await rpc(database, 'claim_social_media_rotations', { p_token: body.token })
    } catch { return reply({ error: 'unauthorized' }, 401) }
    if (!Array.isArray(claimed)) return reply({ error: 'unauthorized' }, 401)
    if (claimed.length > maxJobs) return reply({ error: 'rotation_unavailable' }, 503)
    const jobs = claimed.map(rotation), ids = new Set<string>(), paths = new Set<string>()
    for (const job of jobs) {
      if (!job || ids.has(job.id) || paths.has(job.oldPath) || paths.has(job.newPath)) {
        return reply({ error: 'rotation_unavailable' }, 503)
      }
      ids.add(job.id)
      paths.add(job.oldPath)
      paths.add(job.newPath)
    }
    let completed = 0, errors = 0
    let storage: Storage
    try { storage = dependencies.storage(database) } catch {
      return reply({ error: 'rotation_unavailable' }, 503)
    }
    for (const job of jobs as Rotation[]) {
      if ((dependencies.now?.() ?? Date.now()) - started >= 25_000) break
      try { await rotateOne(database, storage, job); completed++ } catch { errors++ }
    }
    return reply({ status: completed === jobs.length ? 'ok' : 'partial', claimed: jobs.length,
      completed, pending: jobs.length - completed, errors })
  }
}

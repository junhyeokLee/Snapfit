import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'
import { corsHeaders } from './cors.ts'

type Database = { rpc(name: string, params: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }> }
type AdminDependencies = { getUser: VerifiedUserLookup; createAdminDatabase(): Database }
type WorkerDependencies = { secret(): string; enabled(): boolean; createAdminDatabase(): Database; removeFiles(db: Database, paths: string[]): Promise<boolean>; now?(): number; randomUUID?(): string }
const object = (v: unknown): Record<string, any> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, any> : {}
const uuid = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(v)
const order = (v: unknown): v is string => typeof v === 'string' && v.startsWith('ordp_') && uuid(v.slice(5))
const reply = (v: unknown, status = 200) => Response.json(v, { status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' } })
async function rpc(db: Database, name: string, params: Record<string, unknown>) {
  const value = await db.rpc(name, params)
  if (value.error) throw new Error('retention_database_unavailable')
  return value.data
}
export function createPrintFileRetentionAdminHandler(deps: AdminDependencies) {
  return async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      const actor = await assertRedprintingAdmin(req, deps.getUser)
      const text = await req.text()
      if (text.length > 4096) return reply({ error: 'invalid_retention_request' }, 400)
      let parsed: unknown
      try { parsed = JSON.parse(text) } catch { return reply({ error: 'invalid_retention_request' }, 400) }
      const b = object(parsed), overview = b.action === 'overview'
      if (!uuid(actor) || !['overview', 'hold', 'release'].includes(b.action) ||
          Object.keys(b).some(k => !(overview ? ['action'] : ['action', 'orderId', 'note']).includes(k)) ||
          (!overview && (!order(b.orderId) || typeof b.note !== 'string' || b.note.trim().length < 1 || b.note.length > 1000))) {
        return reply({ error: 'invalid_retention_request' }, 400)
      }
      const result = await rpc(deps.createAdminDatabase(), 'manage_print_file_retention', { p_actor: actor, p_action: b.action,
        p_order_id: overview ? null : b.orderId, p_note: overview ? null : b.note.trim() })
      return reply({ result, productionEnabled: false, message: '인쇄 PDF 보존 관리입니다. 원본 앨범·사진과 거래·동의 기록은 삭제하지 않습니다.' })
    } catch (e) {
      return e instanceof RedprintingAdminAuthError ? reply({ error: e.code }, e.status) : reply({ error: 'retention_unavailable' }, 503)
    }
  }
}
export const printFileRetentionSignedPayload = (signedAt: number, nonce: string) => `snapfit-print-file-retention:v1\n${signedAt}\n${nonce}\n{}`
async function authorized(req: Request, secret: string, now: number) {
  const signature = req.headers.get('X-Snapfit-Retention-Signature') ?? '', timestamp = req.headers.get('X-Snapfit-Retention-Timestamp') ?? ''
  const nonce = req.headers.get('X-Snapfit-Retention-Nonce') ?? ''
  if (!/^[a-f0-9]{64}$/.test(secret) || !/^[a-f0-9]{64}$/.test(signature) || !/^\d{10}$/.test(timestamp) || !uuid(nonce)) return null
  const signedAt = Number(timestamp)
  if (!Number.isFinite(now) || Math.abs(Math.floor(now / 1000) - signedAt) > 120) return null
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const expected = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(printFileRetentionSignedPayload(signedAt, nonce))))
  const supplied = Uint8Array.from(signature.match(/../g)!, x => Number.parseInt(x, 16))
  let diff = 0
  for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ supplied[i]
  return diff === 0 ? { signedAt, nonce } : null
}
export function validatedPrintRetentionPaths(raw: unknown, owner: string): string[] | null {
  const row = object(raw)
  if (!order(row.orderId) || !uuid(row.packageId) || row.owner !== owner || !Array.isArray(row.paths) || row.paths.length < 3 || row.paths.length > 67 ||
      new Set(row.paths).size !== row.paths.length || row.paths.some((p: unknown) => typeof p !== 'string')) return null
  const base: string[] = []
  for (const path of row.paths as string[]) {
    const p = path.split('/')
    if (p[0] !== row.orderId || p[1] !== row.packageId) return null
    if (p.length === 3 && ['cover.pdf', 'interior.pdf', 'manifest.json'].includes(p[2])) { base.push(p[2]); continue }
    if (p.length !== 4 || !['cover', 'interior'].includes(p[2]) || !/^part-\d{3}\.bin$/.test(p[3])) return null
    const index = Number(p[3].slice(5, 8))
    if (index > (p[2] === 'cover' ? 9 : 31)) return null
  }
  return base.sort().join(',') === 'cover.pdf,interior.pdf,manifest.json' ? row.paths : null
}
export function createPrintFileRetentionWorkerHandler(deps: WorkerDependencies) {
  return async (req: Request) => {
    if (req.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    try {
      const started = deps.now?.() ?? Date.now()
      const auth = await authorized(req, deps.secret(), started)
      if (!auth || await req.text() !== '{}') return reply({ error: 'unauthorized' }, 401)
      const db = deps.createAdminDatabase()
      if (await rpc(db, 'consume_print_order_scheduler_nonce', { p_nonce: auth.nonce, p_signed_at: auth.signedAt }) !== true) return reply({ error: 'unauthorized' }, 401)
      if (!deps.enabled()) return reply({ enabled: false, removed: 0 })
      let count = 0
      // Deletions are small Storage metadata requests, never PDF downloads.
      // Stop early enough for the 40-second outer deadline to finish the lease.
      for (let index = 0; index < 5; index++) {
        if ((deps.now?.() ?? Date.now()) - started >= 25000) break
        const owner = deps.randomUUID?.() ?? crypto.randomUUID()
        if (!uuid(owner)) throw new Error('retention_owner_unavailable')
        const claim = object(await rpc(db, 'claim_print_file_retention', { p_owner: owner }))
        if (!Object.keys(claim).length) break
        const paths = validatedPrintRetentionPaths(claim, owner)
        if (!paths) throw new Error('retention_invalid_file_scope')
        let removed = false
        try {
          const allowed = await rpc(db, 'authorize_print_file_retention_removal', { p_order_id: claim.orderId, p_owner: owner })
          if (allowed === true) removed = await deps.removeFiles(db, paths) === true
        } catch { /* Release the lease for a safe, idempotent retry. */ }
        await rpc(db, 'finish_print_file_retention', { p_order_id: claim.orderId, p_owner: owner, p_removed: removed })
        if (!removed) break // Never spin on the same failed or newly held order.
        count++
      }
      return reply({ enabled: true, removed: count })
    } catch { return reply({ error: 'retention_unavailable' }, 503) }
  }
}

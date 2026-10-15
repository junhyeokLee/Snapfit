/**
 * Supabase Cron's bounded orchestration. The capability is server-only and is
 * unrelated to a customer JWT, payment result or supplier credential. Every
 * business reference comes from a service-only, leased database claim.
 */
export type PrintSchedulerDatabase = {
  rpc(name: string, parameters: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }>
}
export type PrintSchedulerConfiguration = {
  enabled: boolean
  paymentObservable: boolean
  refundsEnabled: boolean
  fulfillmentReady: boolean
}
export type PrintSchedulerDependencies = {
  secret(): string
  configuration(): PrintSchedulerConfiguration
  createAdminDatabase(): PrintSchedulerDatabase
  reconcile(database: PrintSchedulerDatabase, payment: { userId: string; paymentId: string }): Promise<{
    verifiedPaid?: boolean; verifiedUnpaid?: boolean
  }>
  resolve(database: PrintSchedulerDatabase, requestId: string, leaseOwner: string): Promise<{
    processed?: boolean; request?: { status?: unknown }
  }>
  advance(database: PrintSchedulerDatabase, jobId: string, leaseOwner: string): Promise<unknown>
  development?(database: PrintSchedulerDatabase): Promise<{ enabled: boolean; checked: number; advanced: number; errors: number; stage: string | null }>
  removeFiles?(database: PrintSchedulerDatabase, paths: string[]): Promise<boolean>
  now?: () => number
  randomUUID?: () => string
}
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const paymentId = (value: unknown): value is string => typeof value === 'string' && value.startsWith('SFP_') && uuid(value.slice(4))
const object = (value: unknown): Record<string, any> => value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {}
const reply = (value: unknown, status = 200) => Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } })

/** External provider calls use a smaller deadline inside Free's 150s budget. */
export function createPrintSchedulerProviderFetch(fetcher: typeof fetch = fetch, timeoutMs = 12_000): typeof fetch {
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 12_000) throw new Error('invalid_scheduler_timeout')
  return (input, init) => {
    const bounded = AbortSignal.timeout(timeoutMs)
    const original = init?.signal ?? (input instanceof Request ? input.signal : undefined)
    return fetcher(input, { ...init, signal: original ? AbortSignal.any([original, bounded]) : bounded })
  }
}

/**
 * One fresh deadline per Cron request, shared by database, Storage and providers.
 * No mutation can start after the request budget. In-flight calls are aborted
 * through their own signal; no Promise.race leaves financial work behind.
 */
export function createPrintSchedulerRequestFetch(fetcher: typeof fetch = fetch, executionMs = 115_000,
  requestSignal?: AbortSignal): typeof fetch {
  if (!Number.isSafeInteger(executionMs) || executionMs < 1 || executionMs > 115_000) throw new Error('invalid_scheduler_execution_budget')
  const deadline = AbortSignal.timeout(executionMs)
  return createPrintSchedulerProviderFetch((input, init) => {
    const original = init?.signal ?? (input instanceof Request ? input.signal : undefined)
    const signal = AbortSignal.any([deadline, ...(requestSignal ? [requestSignal] : []), ...(original ? [original] : [])])
    if (signal.aborted) return Promise.reject(signal.reason)
    return fetcher(input, { ...init, signal })
  })
}

export function printSchedulerSignedPayload(signedAt: number, nonce: string) {
  return `snapfit-print-order-scheduler:v1\n${signedAt}\n${nonce}\n{}`
}
// The queued HTTP request contains a short-lived signature, never the long-lived
// Vault/Edge secret. The private single-use nonce is consumed before any work.
async function authorized(request: Request, secret: string, now: number) {
  if (request.headers.has('X-Snapfit-Scheduler-Secret')) return null
  const supplied = request.headers.get('X-Snapfit-Scheduler-Signature') ?? ''
  const timestamp = request.headers.get('X-Snapfit-Scheduler-Timestamp') ?? ''
  const nonce = request.headers.get('X-Snapfit-Scheduler-Nonce') ?? ''
  if (!/^[a-f0-9]{64}$/.test(secret) || !/^[a-f0-9]{64}$/.test(supplied) || !/^\d{10}$/.test(timestamp) ||
      !uuid(nonce) || nonce !== nonce.toLowerCase()) return null
  const signedAt = Number(timestamp)
  if (!Number.isSafeInteger(signedAt) || !Number.isFinite(now) || Math.abs(Math.floor(now / 1000) - signedAt) > 120) return null
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const expected = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(printSchedulerSignedPayload(signedAt, nonce))))
  const actual = new Uint8Array(supplied.match(/../g)!.map(value => Number.parseInt(value, 16)))
  let difference = 0
  for (let index = 0; index < expected.length; index++) difference |= expected[index] ^ actual[index]
  return difference === 0 ? { nonce, signedAt } : null
}
async function rpc(database: PrintSchedulerDatabase, name: string, parameters: Record<string, unknown>) {
  const result = await database.rpc(name, parameters)
  if (result.error) throw new Error('print_scheduler_database_unavailable')
  return result.data
}

export function createPrintOrderSchedulerHandler(dependencies: PrintSchedulerDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return reply({ error: 'method_not_allowed' }, 405)
    const now = dependencies.now ?? Date.now, started = now()
    let authentication: { nonce: string; signedAt: number } | null
    try {
      authentication = await authorized(request, dependencies.secret(), started)
      if (!authentication) return reply({ error: 'authentication_required' }, 401)
    } catch { return reply({ error: 'authentication_required' }, 401) }
    try {
      const raw = await request.text()
      if (raw !== '{}') throw new Error()
    } catch { return reply({ error: 'invalid_print_scheduler_request' }, 400) }

    const result = { enabled: false, runtimeReady: false,
      payments: { checked: 0, verifiedPaid: 0, verifiedUnpaid: 0, pending: 0, errors: 0 },
      requests: { processed: 0, completed: 0, pending: 0, errors: 0 },
      fulfillment: { checked: 0, advanced: 0, errors: 0 }, cleanup: { checked: 0, removed: 0, errors: 0 }, budgetDeferred: false }
    try {
      const database = dependencies.createAdminDatabase()
      if (await rpc(database, 'consume_print_order_scheduler_nonce', { p_nonce: authentication.nonce, p_signed_at: authentication.signedAt }) !== true) {
        return reply({ error: 'scheduler_signature_rejected' }, 403)
      }
      const configuration = dependencies.configuration()
      result.enabled = configuration.enabled === true
      result.runtimeReady = result.enabled && configuration.fulfillmentReady === true
      // This records a separate scheduler heartbeat even while customer sales
      // are closed. It never treats a TEST configuration as production-ready.
      await rpc(database, 'record_print_order_scheduler_heartbeat', { p_runtime_ready: result.runtimeReady })
      if (!result.enabled) return reply(result)

      // TEST invoices and DEV vendor orders have their own private outbox,
      // channel allowlist and credentials. Closing LIVE sales never prevents a
      // user-authorized development checkout from completing after app closure.
      if (dependencies.development) {
        let development
        try { development = await dependencies.development(database) }
        catch { development = { enabled: true, checked: 0, advanced: 0, errors: 1, stage: null } }
        Object.assign(result, { development })
        // One TEST or LIVE phase per invocation keeps the shared 115s deadline.
        if (development.checked > 0 || development.errors > 0) return reply(result)
      }

      if (configuration.paymentObservable === true) {
        const rows = await rpc(database, 'claim_production_print_payment_rechecks', { p_limit: 1 })
        if (!Array.isArray(rows) || rows.length > 1 || rows.some(row => !uuid(row?.user_id) || !paymentId(row?.payment_id))) {
          throw new Error('invalid_scheduler_payment_claim')
        }
        for (const row of rows) {
          result.payments.checked++
          try {
            const payment = await dependencies.reconcile(database, { userId: row.user_id, paymentId: row.payment_id })
            if (payment.verifiedPaid === true && payment.verifiedUnpaid !== true) result.payments.verifiedPaid++
            else if (payment.verifiedUnpaid === true && payment.verifiedPaid !== true) result.payments.verifiedUnpaid++
            else result.payments.pending++
          } catch { result.payments.errors++ }
        }
      }
      // Do not begin another potentially financial phase after a slow lookup.
      // An already begun phase is never left running behind Promise.race.
      if (now() - started >= 35_000) { result.budgetDeferred = true; return reply(result) }

      if (configuration.refundsEnabled === true && configuration.paymentObservable === true) {
        const rows = await rpc(database, 'list_print_order_requests', { p_limit: 1, p_order_id: null, p_pending_only: true })
        if (!Array.isArray(rows) || rows.length > 1 || rows.some(row => !uuid(row?.requestId))) throw new Error('invalid_scheduler_request_claim')
        if (rows.length) {
          try {
            const resolution = await dependencies.resolve(database, rows[0].requestId, dependencies.randomUUID?.() ?? crypto.randomUUID())
            if (resolution.processed === true) {
              result.requests.processed++
              if (resolution.request?.status === 'COMPLETED') result.requests.completed++
              else result.requests.pending++
            }
          } catch { result.requests.errors++ }
          // Only one cancellation/refund or supplier phase in an invocation.
          return reply(result)
        }
      }
      if (!result.runtimeReady) return reply(result)
      const leaseOwner = dependencies.randomUUID?.() ?? crypto.randomUUID()
      if (!uuid(leaseOwner)) throw new Error('invalid_scheduler_owner')
      const claim = object(await rpc(database, 'claim_print_app_pdf_fulfillment_job', {
        p_worker_id: leaseOwner, p_limit: 1, p_lease_seconds: 120, p_runtime_ready: true,
      }))
      if (!Object.keys(claim).length) {
        // The SQL candidates prove that no uncertain/issued checkout can still
        // pay for this package. Never infer abandonment from elapsed time here.
        if (result.payments.checked === 0 && dependencies.removeFiles && now() - started < 35_000) {
          const rows = await rpc(database, 'claim_abandoned_print_prepayment_packages', { p_limit: 1 })
          if (!Array.isArray(rows) || rows.length > 1) throw new Error('invalid_scheduler_cleanup_claim')
          for (const row of rows) {
            if (!uuid(row?.id) || !Array.isArray(row.paths) || row.paths.length < 3 || row.paths.length > 67 ||
                row.paths.some((path: unknown) => typeof path !== 'string') || new Set(row.paths).size !== row.paths.length) {
              throw new Error('invalid_scheduler_cleanup_claim')
            }
            const parts = row.paths.map((path: string) => path.split('/'))
            const orderId = parts[0][0]
            const baseFiles = parts.filter((part: string[]) => part.length === 3).map((part: string[]) => part[2]).sort()
            if (!orderId.startsWith('ordp_') || !uuid(orderId.slice(5)) || parts.some((part: string[]) => {
              if (part[0] !== orderId || part[1] !== row.id) return true
              if (part.length === 3) return !['cover.pdf', 'interior.pdf', 'manifest.json'].includes(part[2])
              if (part.length !== 4 || !['cover', 'interior'].includes(part[2]) || !/^part-\d{3}\.bin$/.test(part[3])) return true
              const index = Number(part[3].slice(5, 8))
              return index > (part[2] === 'cover' ? 9 : 31)
            }) || baseFiles.join(',') !== 'cover.pdf,interior.pdf,manifest.json') {
              throw new Error('invalid_scheduler_cleanup_claim')
            }
            result.cleanup.checked++
            let removed = false
            try { removed = await dependencies.removeFiles(database, row.paths) === true } catch { /* Retry after safe lease expiry. */ }
            await rpc(database, 'finish_abandoned_print_prepayment_package', { p_id: row.id, p_removed: removed })
            if (removed) result.cleanup.removed++
            else result.cleanup.errors++
          }
        }
        return reply(result)
      }
      const job = object(claim.job)
      // The SQL claim validates attached immutable client PDFs and excludes
      // RENDER. This second check prevents ever invoking an external renderer.
      if (!uuid(job.id) || job.lease_owner !== leaseOwner || job.state !== 'CLAIMED' ||
          !['SUBMIT', 'CONFIRM', 'POLL'].includes(job.event_type) || !Number.isFinite(Date.parse(job.lease_until)) ||
          Date.parse(job.lease_until) <= now()) throw new Error('invalid_scheduler_fulfillment_claim')
      result.fulfillment.checked++
      try { await dependencies.advance(database, job.id, leaseOwner); result.fulfillment.advanced++ }
      catch { result.fulfillment.errors++ }
      return reply(result)
    } catch { return reply({ error: 'print_scheduler_unavailable' }, 503) }
  }
}

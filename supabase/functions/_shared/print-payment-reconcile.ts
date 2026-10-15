import { assertPrintWorker, PrintWorkerAuthError, type PrintWorkerUserLookup } from './print-worker-auth.ts'

type ReconcileConfiguration = {
  enabled: boolean
  environment: string
  storeId: string
  channelKey: string
  apiSecret: string
}
type PendingPayment = { user_id: string; payment_id: string }
type ReconcileDependencies = {
  getUser: PrintWorkerUserLookup
  createAdminDatabase: () => any
  configuration: () => ReconcileConfiguration
  reconcile: (db: any, configuration: ReconcileConfiguration, payment: { userId: string; paymentId: string }) => Promise<{
    verifiedPaid?: boolean; verifiedUnpaid?: boolean
  }>
}

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
}
const response = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers })
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const paymentId = (value: unknown): value is string => typeof value === 'string' &&
  value.startsWith('SFP_') && uuid(value.slice(4))

/**
 * A trusted scheduler recovers paid checkouts even when the app was closed.
 * Only the server's claimed references are inspected. A caller cannot supply
 * a payment, owner, amount, or payment result to this endpoint.
 */
export function createPrintPaymentReconcileHandler(dependencies: ReconcileDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === 'OPTIONS') return response({ ok: true })
    if (req.method !== 'POST') return response({ error: 'method_not_allowed' }, 405)
    try {
      await assertPrintWorker(req, dependencies.getUser)
    } catch (error) {
      return response({ error: error instanceof PrintWorkerAuthError ? error.code : 'invalid_session' },
        error instanceof PrintWorkerAuthError ? error.status : 401)
    }
    let limit: number
    try {
      const raw = await req.text()
      if (raw.length > 1024) throw new Error('oversize')
      const body = JSON.parse(raw)
      if (!body || typeof body !== 'object' || Array.isArray(body) ||
          Object.keys(body).some(key => key !== 'limit') ||
          !Number.isSafeInteger(body.limit ?? 3) || Number(body.limit ?? 3) < 1 || Number(body.limit ?? 3) > 3) {
        throw new Error('invalid')
      }
      limit = body.limit ?? 3
    } catch { return response({ error: 'invalid_reconcile_request' }, 400) }

    let db: any, configuration: ReconcileConfiguration
    try {
      configuration = dependencies.configuration()
      // Closing new sales must not strand a previously charged invoice. This
      // path observes frozen references with GET; it cannot open a checkout.
      if (configuration.environment !== 'live' || !configuration.apiSecret ||
          !/^store-[A-Za-z0-9-]+$/.test(configuration.storeId) ||
          !/^channel-key-[A-Za-z0-9-]+$/.test(configuration.channelKey)) {
        return response({ enabled: false, checked: 0, verifiedPaid: 0, verifiedUnpaid: 0, pending: 0, errors: 0 })
      }
      db = dependencies.createAdminDatabase()
    } catch { return response({ error: 'payment_reconcile_unavailable' }, 503) }

    let pending: PendingPayment[]
    try {
      const result = await db.rpc('claim_production_print_payment_rechecks', { p_limit: limit })
      if (result.error || !Array.isArray(result.data) || result.data.length > limit ||
          result.data.some((row: any) => !uuid(row?.user_id) || !paymentId(row?.payment_id))) {
        throw new Error('invalid_claim')
      }
      pending = result.data
    } catch { return response({ error: 'payment_reconcile_unavailable' }, 503) }

    const summary = { enabled: true, checked: 0, verifiedPaid: 0, verifiedUnpaid: 0, pending: 0, errors: 0 }
    // At most three bounded provider requests are made sequentially per tick.
    // Failed lookups remain scheduled for another observation; they never
    // create an unpaid result or replace the original payment reference.
    for (const item of pending) {
      summary.checked += 1
      try {
        const result = await dependencies.reconcile(db, configuration, { userId: item.user_id, paymentId: item.payment_id })
        if (result.verifiedPaid === true && result.verifiedUnpaid !== true) summary.verifiedPaid += 1
        else if (result.verifiedUnpaid === true && result.verifiedPaid !== true) summary.verifiedUnpaid += 1
        else summary.pending += 1
      } catch { summary.errors += 1 }
    }
    return response(summary)
  }
}

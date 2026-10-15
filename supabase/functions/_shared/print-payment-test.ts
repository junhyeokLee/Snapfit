import { corsHeaders } from './cors.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'
import { queryPortOnePrintPayment, PortOnePrintPaymentError,
  type ExpectedPortOnePrintPayment, type PortOnePrintPaymentObservation } from './portone-print-payment.ts'

type Database = { rpc(name: string, params: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }> }
export type PrintPaymentTestEnvironment = { environment: string; storeId: string; channelKey: string; apiSecret: string }
export type PrintPaymentTestDependencies = {
  getUser: VerifiedUserLookup
  createAdminDatabase: () => Database
  configuration: () => PrintPaymentTestEnvironment
  queryPayment?: typeof queryPortOnePrintPayment
  now?: () => number
}

class TestPaymentError extends Error {
  constructor(readonly code: string, readonly status = 409) { super(code) }
}
const uuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
const paymentId = (value: unknown): value is string => typeof value === 'string' && value.startsWith('SFPGT_') && uuid(value.slice(6))
const identifier = (value: unknown) => typeof value === 'string' && /^[A-Za-z0-9_-]{1,200}$/.test(value)
const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {}
// PortOne SDK routing does not have a forceTest option. These public IDs were
// verified in the console as the Toss TEST channel on 2026-10-14. Merely setting
// an environment label cannot authorize a different channel for an SDK launch.
const approvedTestRoute = {
  storeId: 'store-33df409e-0ad9-4953-8194-70db7e32efae',
  channelKey: 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88',
}
const json = (body: unknown, status = 200) => Response.json(body, {
  status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
})

function testSession(value: unknown, actor: string, now: number) {
  const row = record(value)
  if (row.owner_id !== actor || !paymentId(row.payment_id)) throw new TestPaymentError('test_payment_not_found', 404)
  if (row.environment !== 'test' || row.currency !== 'KRW' || !['PREPARED', 'VERIFIED_TEST'].includes(String(row.status)) ||
      row.store_id !== approvedTestRoute.storeId || row.channel_key !== approvedTestRoute.channelKey || typeof row.order_name !== 'string' ||
      !Number.isSafeInteger(row.total_amount) || Number(row.total_amount) <= 0 ||
      typeof row.expires_at !== 'string' || !Number.isFinite(Date.parse(row.expires_at))) {
    throw new TestPaymentError('test_payment_session_invalid', 503)
  }
  const verified = row.status === 'VERIFIED_TEST'
  if (verified && (!row.verified_at || record(row.receipt).isTest !== true || record(row.receipt).environment !== 'test')) {
    throw new TestPaymentError('test_payment_session_invalid', 503)
  }
  return {
    paymentId: row.payment_id, storeId: String(row.store_id), channelKey: String(row.channel_key),
    orderName: row.order_name, totalAmount: Number(row.total_amount), currency: 'KRW' as const, environment: 'test' as const,
    status: verified ? 'VERIFIED_TEST' : 'PREPARED', expiresAt: row.expires_at,
    canLaunch: !verified && Date.parse(row.expires_at) > now,
    verifiedAt: verified ? row.verified_at : null,
    receipt: verified ? row.receipt : null,
  }
}

const safeDatabaseCodes = new Set(['test_payment_request_conflict', 'test_payment_price_changed',
  'test_payment_receipt_invalid', 'test_payment_receipt_conflict', 'test_payment_expectation_immutable',
  'test_payment_receipt_immutable', 'test_payment_invalid_state', 'invalid_test_payment_request'])
async function rpc(db: Database, name: string, parameters: Record<string, unknown>) {
  const result = await db.rpc(name, parameters)
  if (result.error) {
    const error = record(result.error), message = String(error.message ?? '')
    if (message === 'test_payment_not_found' || error.code === 'P0002') throw new TestPaymentError('test_payment_not_found', 404)
    if (safeDatabaseCodes.has(message)) throw new TestPaymentError(message, message === 'invalid_test_payment_request' ? 400 : 409)
    if (error.code === '23505' && name === 'verify_print_payment_test') throw new TestPaymentError('test_payment_receipt_conflict')
    throw new TestPaymentError('payment_test_storage_unavailable', 503)
  }
  return result.data
}

function bodyInput(value: unknown) {
  const body = record(value), action = body.action
  if (action === 'prepare' && Object.keys(body).every(key => ['action', 'scenario', 'requestId'].includes(key)) &&
      ['SOFT_20', 'HARD_80'].includes(String(body.scenario)) && uuid(body.requestId)) {
    return { action: 'prepare' as const, scenario: String(body.scenario), requestId: body.requestId }
  }
  if ((action === 'verify' || action === 'status') && Object.keys(body).every(key => ['action', 'paymentId'].includes(key)) && paymentId(body.paymentId)) {
    return { action, paymentId: body.paymentId }
  }
  throw new TestPaymentError('invalid_test_payment_request', 400)
}

export function createPrintPaymentTestHandler(dependencies: PrintPaymentTestDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
    try {
      // Never create a privileged client or read payment secrets before this.
      const actor = await assertRedprintingAdmin(request, dependencies.getUser)
      const text = await request.text()
      if (text.length > 4096) throw new TestPaymentError('invalid_test_payment_request', 400)
      let parsed: unknown
      try { parsed = JSON.parse(text) } catch { throw new TestPaymentError('invalid_test_payment_request', 400) }
      const input = bodyInput(parsed), configuration = dependencies.configuration()
      if (configuration.environment !== 'test') throw new TestPaymentError('payment_test_environment_required', 503)
      if (input.action !== 'status' && (!identifier(configuration.storeId) || !identifier(configuration.channelKey) || !configuration.apiSecret)) {
        throw new TestPaymentError('payment_test_configuration_missing', 503)
      }
      if (input.action !== 'status' && (configuration.storeId !== approvedTestRoute.storeId ||
          configuration.channelKey !== approvedTestRoute.channelKey)) {
        throw new TestPaymentError('payment_test_route_not_approved', 503)
      }
      const db = dependencies.createAdminDatabase(), now = dependencies.now?.() ?? Date.now()
      if (input.action === 'prepare') {
        const row = await rpc(db, 'prepare_print_payment_test', { p_owner: actor, p_request_id: input.requestId,
          p_scenario: input.scenario, p_store_id: configuration.storeId, p_channel_key: configuration.channelKey })
        return json(testSession(row, actor, now))
      }
      const session = testSession(await rpc(db, 'get_print_payment_test', { p_owner: actor, p_payment_id: input.paymentId }), actor, now)
      if (input.action === 'status') return json(session)
      // Use the stored expectation, including its original channel and amount.
      // Expired sessions can still recover a successful delayed test payment.
      const expected: ExpectedPortOnePrintPayment = { paymentId: session.paymentId, storeId: session.storeId,
        channelKey: session.channelKey, amount: session.totalAmount, currency: 'KRW', environment: 'test' }
      const receipt: PortOnePrintPaymentObservation = await (dependencies.queryPayment ?? queryPortOnePrintPayment)(expected,
        { apiSecret: configuration.apiSecret })
      if (receipt.isTest !== true || receipt.environment !== 'test') throw new TestPaymentError('payment_environment_mismatch')
      const stored = await rpc(db, 'verify_print_payment_test', { p_owner: actor, p_payment_id: session.paymentId, p_receipt: receipt })
      return json(testSession(stored, actor, now))
    } catch (error) {
      if (error instanceof RedprintingAdminAuthError || error instanceof TestPaymentError) return json({ error: error.code }, error.status)
      if (error instanceof PortOnePrintPaymentError) return json({ error: error.code, retryable: error.retryable }, error.status)
      return json({ error: 'payment_test_operation_failed' }, 503)
    }
  }
}

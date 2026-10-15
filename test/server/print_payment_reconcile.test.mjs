import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import vm from 'node:vm'
import { createPrintPaymentReconcileHandler } from '../../supabase/functions/_shared/print-payment-reconcile.ts'

const owner = '11111111-1111-4111-8111-111111111111'
const references = [1, 2, 3].map(index => ({ user_id: owner,
  payment_id: `SFP_00000000-0000-4000-8000-${String(index).padStart(12, '0')}` }))
const configuration = { enabled: true, environment: 'live', storeId: 'store-fixture',
  channelKey: 'channel-key-fixture', apiSecret: 'never-return-this-secret' }

function fixture(options = {}) {
  const calls = []
  const handler = createPrintPaymentReconcileHandler({
    async getUser() {
      calls.push('auth')
      if (options.authThrows) throw new Error('private authentication error')
      return options.user === undefined ? { id: owner, app_metadata: { role: 'print_worker' } } : options.user
    },
    configuration() { calls.push('config'); return { ...configuration, ...options.configuration } },
    createAdminDatabase() {
      calls.push('database')
      return { async rpc(name, parameters) {
        calls.push({ name, parameters })
        if (options.claimThrows) throw new Error('private SQL detail')
        return { data: options.references ?? references.slice(0, parameters.p_limit), error: options.claimError ?? null }
      } }
    },
    async reconcile(db, config, payment) {
      calls.push({ payment })
      if (options.reconcile) return options.reconcile(payment)
      return { verifiedPaid: true }
    },
  })
  return { handler, calls }
}
function request(body = { limit: 3 }, authorization = 'Bearer valid-session', method = 'POST', raw = false) {
  return new Request('https://example.invalid/print-payment-reconcile', {
    method, headers: authorization ? { Authorization: authorization } : {},
    ...(method === 'POST' ? { body: raw ? body : JSON.stringify(body) } : {}),
  })
}

test('authenticated worker reconciles only server-claimed references without exposing their owner or secrets', async () => {
  const f = fixture()
  const response = await f.handler(request())
  assert.equal(response.status, 200)
  assert.equal(response.headers.get('cache-control'), 'no-store')
  const result = await response.json()
  assert.deepEqual(result, { enabled: true, checked: 3, verifiedPaid: 3, verifiedUnpaid: 0, pending: 0, errors: 0 })
  assert.deepEqual(f.calls[3], { name: 'claim_production_print_payment_rechecks', parameters: { p_limit: 3 } })
  assert.deepEqual(f.calls.slice(4).map(call => call.payment), references.map(row => ({ userId: row.user_id, paymentId: row.payment_id })))
  assert.doesNotMatch(JSON.stringify(result), /11111111|SFP_|never-return|channel-key/)
})

test('admin can operate the same reconciliation path', async () => {
  const f = fixture({ user: { id: owner, app_metadata: { role: 'admin' } } })
  assert.equal((await f.handler(request({ limit: 1 }))).status, 200)
})

test('anonymous and malformed bearer requests never reach authentication or privileged configuration', async () => {
  for (const authorization of [null, '', 'Basic fixture', 'Bearer two tokens']) {
    const f = fixture()
    assert.equal((await f.handler(request({}, authorization))).status, 401)
    assert.deepEqual(f.calls, [])
  }
})

test('unverified users and user-editable roles cannot inspect payment queues', async () => {
  for (const user of [null, { id: owner }, { id: owner, user_metadata: { role: 'admin' } },
    { id: owner, app_metadata: { role: 'customer' } }]) {
    const f = fixture({ user })
    const response = await f.handler(request())
    assert.ok([401, 403].includes(response.status))
    assert.deepEqual(f.calls, ['auth'])
  }
  const f = fixture({ authThrows: true })
  assert.equal((await f.handler(request())).status, 401)
  assert.deepEqual(f.calls, ['auth'])
})

test('caller cannot choose a payment, owner, amount, verification result, or oversized batch', async () => {
  for (const body of [null, [], { paymentId: references[0].payment_id }, { userId: owner },
    { limit: 1, amount: 49900 }, { verifiedPaid: true }, { limit: 0 }, { limit: 4 }, { limit: '3' }, { limit: 1.5 }]) {
    const f = fixture()
    assert.equal((await f.handler(request(body))).status, 400)
    assert.deepEqual(f.calls, ['auth'])
  }
})

test('malformed and excessive request bodies cannot claim queue rows', async () => {
  for (const raw of ['{invalid', ' '.repeat(1025)]) {
    const f = fixture()
    assert.equal((await f.handler(request(raw, 'Bearer valid-session', 'POST', true))).status, 400)
    assert.deepEqual(f.calls, ['auth'])
  }
})

test('disabled environment or TEST configuration never queries privileged payment data or invokes the provider', async () => {
  for (const config of [{ environment: 'disabled' }, { environment: 'test' }, { apiSecret: '' },
    { storeId: '' }, { channelKey: '' }]) {
    const f = fixture({ configuration: config })
    const result = await (await f.handler(request())).json()
    assert.equal(result.enabled, false)
    assert.equal(result.checked, 0)
    assert.deepEqual(f.calls, ['auth', 'config'])
  }
})

test('closing new sales still reconciles an existing LIVE invoice without creating a new payment', async () => {
  const f = fixture({ configuration: { enabled: false } })
  const result = await (await f.handler(request({ limit: 1 }))).json()
  assert.equal(result.enabled, true)
  assert.equal(result.verifiedPaid, 1)
  assert.equal(f.calls[3].name, 'claim_production_print_payment_rechecks')
})

test('empty due queue is a successful no-op and failed claims stay unavailable', async () => {
  const f = fixture({ references: [] })
  assert.equal((await (await f.handler(request())).json()).checked, 0)
  for (const options of [{ claimThrows: true }, { claimError: { message: 'private SQL detail' } }]) {
    const failing = fixture(options)
    const response = await failing.handler(request())
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'payment_reconcile_unavailable' })
  }
})

test('malformed claimed references fail the entire batch before any provider lookup', async () => {
  for (const rows of [[{ user_id: owner, payment_id: 'other-route' }], [{ user_id: 'not-uuid', payment_id: references[0].payment_id }], references]) {
    const f = fixture({ references: rows })
    assert.equal((await f.handler(request({ limit: 1 }))).status, 503)
    assert.equal(f.calls.some(call => call.payment), false)
  }
})

test('one lookup failure does not stop recovery of other paid or definitively unpaid checkouts', async () => {
  const f = fixture({ reconcile: async payment => {
    if (payment.paymentId === references[0].payment_id) throw new Error('private provider URL')
    return payment.paymentId === references[1].payment_id ? { verifiedPaid: true } : { verifiedUnpaid: true }
  } })
  const result = await (await f.handler(request())).json()
  assert.deepEqual(result, { enabled: true, checked: 3, verifiedPaid: 1, verifiedUnpaid: 1, pending: 0, errors: 1 })
})

test('pending or contradictory observations never declare either a paid or unpaid result', async () => {
  const f = fixture({ reconcile: async () => ({ verifiedPaid: true, verifiedUnpaid: true }) })
  const result = await (await f.handler(request())).json()
  assert.equal(result.pending, 3)
  assert.equal(result.verifiedPaid, 0)
  assert.equal(result.verifiedUnpaid, 0)
})

test('preflight and unsupported methods perform no authenticated or privileged work', async () => {
  for (const [method, status] of [['OPTIONS', 200], ['GET', 405], ['PUT', 405]]) {
    const f = fixture()
    assert.equal((await f.handler(request(null, null, method))).status, status)
    assert.deepEqual(f.calls, [])
  }
})

test('deployed wrapper turns private intent results into flags and defaults production off', async () => {
  let dependencies, served
  const source = stripTypeScriptTypes(readFileSync(new URL(
    '../../supabase/functions/print-payment-reconcile/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  let state = 'PAID'
  vm.runInNewContext(source, {
    adminClient: () => ({}), getUser: async () => ({ id: owner }),
    createPrintPaymentReconcileHandler(input) { dependencies = input; return 'handler' },
    reconcileProductionPrintPayment: async () => ({ status: state, user_id: owner, snapshot: { private: 'source' } }),
    Deno: { env: { get() { return undefined } }, serve(handler) { served = handler } },
  })
  assert.equal(served, 'handler')
  assert.equal(dependencies.configuration().enabled, false)
  assert.equal(dependencies.configuration().environment, 'disabled')
  assert.equal(dependencies.configuration().apiSecret, '')
  for (const [status, expected] of [['PAID', { verifiedPaid: true, verifiedUnpaid: false }],
    ['FAILED', { verifiedPaid: false, verifiedUnpaid: true }],
    ['CANCELED', { verifiedPaid: false, verifiedUnpaid: true }],
    ['PREPARED', { verifiedPaid: false, verifiedUnpaid: false }]]) {
    state = status
    const result = await dependencies.reconcile({}, configuration, { userId: owner, paymentId: references[0].payment_id })
    assert.deepEqual(JSON.parse(JSON.stringify(result)), expected)
  }
})

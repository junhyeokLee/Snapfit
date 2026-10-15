import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { test } from 'node:test'
import { stripTypeScriptTypes } from 'node:module'
import vm from 'node:vm'
import { createPrintPaymentTestHandler } from '../../supabase/functions/_shared/print-payment-test.ts'
import { queryPortOnePrintPayment, PortOnePrintPaymentError } from '../../supabase/functions/_shared/portone-print-payment.ts'

const owner = '11111111-1111-4111-8111-111111111111'
const other = '22222222-2222-4222-8222-222222222222'
const requestId = '33333333-3333-4333-8333-333333333333'
const route = { storeId: 'store-33df409e-0ad9-4953-8194-70db7e32efae',
  channelKey: 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88' }
const configuration = () => ({ ...route, environment: 'test', apiSecret: 'synthetic-fixture-secret' })
const observation = (paymentId, amount = 49900) => ({ provider: 'PORTONE', version: 'V2', status: 'PAID', paymentId,
  transactionId: `transaction-${paymentId}`, ...route, amount, paidAmount: amount, discountAmount: 0,
  currency: 'KRW', paidAt: '2026-10-14T00:00:00Z', environment: 'test', isTest: true })
const request = (body, { authorization = 'Bearer synthetic-admin-session', method = 'POST', raw = false } = {}) =>
  new Request('https://example.invalid/print-payment-test', { method,
    headers: authorization ? { Authorization: authorization } : {},
    ...(method === 'POST' ? { body: raw ? body : JSON.stringify(body) } : {}) })
const prepare = (changes = {}) => ({ action: 'prepare', scenario: 'SOFT_20', requestId, ...changes })

function fixture(overrides = {}) {
  const rows = new Map(), requests = new Map(), calls = []
  let nextId = 1, commits = 0
  const db = {
    async rpc(name, params) {
      calls.push({ name, params })
      if (name === 'prepare_print_payment_test') {
        const key = `${params.p_owner}/${params.p_request_id}`
        const existing = requests.get(key)
        const fingerprint = [params.p_scenario, params.p_store_id, params.p_channel_key].join('|')
        if (existing) return existing.request_fingerprint === fingerprint
          ? { data: structuredClone(existing), error: null }
          : { data: null, error: { code: '23514', message: 'test_payment_request_conflict' } }
        const id = `SFPGT_00000000-0000-4000-8000-${String(nextId++).padStart(12, '0')}`
        const row = { payment_id: id, owner_id: params.p_owner, request_id: params.p_request_id,
          scenario: params.p_scenario, request_fingerprint: fingerprint, store_id: params.p_store_id,
          channel_key: params.p_channel_key, order_name: '스냅핏 테스트 결제',
          total_amount: params.p_scenario === 'SOFT_20' ? 49900 : 159900, currency: 'KRW', environment: 'test',
          status: 'PREPARED', expires_at: '2026-10-15T00:00:00Z', receipt: null, verified_at: null }
        rows.set(id, row); requests.set(key, row)
        return { data: structuredClone(row), error: null }
      }
      const row = rows.get(params.p_payment_id)
      if (!row || row.owner_id !== params.p_owner) return { data: null, error: { code: 'P0002', message: 'test_payment_not_found' } }
      if (name === 'get_print_payment_test') return { data: structuredClone(row), error: null }
      assert.equal(name, 'verify_print_payment_test')
      if (row.status === 'VERIFIED_TEST') return JSON.stringify(row.receipt) === JSON.stringify(params.p_receipt)
        ? { data: structuredClone(row), error: null }
        : { data: null, error: { code: '23514', message: 'test_payment_receipt_conflict' } }
      if ([...rows.values()].some(otherRow => otherRow.receipt?.transactionId === params.p_receipt.transactionId)) {
        return { data: null, error: { code: '23505', message: 'private transaction details' } }
      }
      row.status = 'VERIFIED_TEST'; row.receipt = structuredClone(params.p_receipt)
      row.verified_at = '2026-10-14T00:01:00Z'; commits++
      return { data: structuredClone(row), error: null }
    },
  }
  const dependencies = {
    async getUser() { calls.push('getUser'); return { id: owner, app_metadata: { role: 'admin' } } },
    configuration() { calls.push('configuration'); return configuration() },
    createAdminDatabase() { calls.push('database'); return db },
    async queryPayment(expected, opts) { calls.push({ queryPayment: expected }); assert.equal(opts.apiSecret, 'synthetic-fixture-secret')
      return observation(expected.paymentId, expected.amount) },
    now: () => Date.parse('2026-10-14T00:00:00Z'),
    ...overrides,
  }
  return { handler: createPrintPaymentTestHandler(dependencies), dependencies, rows, calls, get commits() { return commits } }
}
const result = async response => ({ status: response.status, body: await response.json() })

test('admin prepare persists a server scenario before returning only SDK-safe TEST routing', async () => {
  const f = fixture(), response = await f.handler(request(prepare()))
  assert.equal(response.status, 200)
  assert.equal(response.headers.get('cache-control'), 'no-store')
  const body = await response.json()
  assert.match(body.paymentId, /^SFPGT_/)
  assert.equal(body.totalAmount, 49900); assert.equal(body.environment, 'test'); assert.equal(body.canLaunch, true)
  assert.equal(body.status, 'PREPARED'); assert.equal(body.receipt, null)
  assert.deepEqual(Object.keys(body).sort(), ['paymentId', 'storeId', 'channelKey', 'orderName', 'totalAmount',
    'currency', 'environment', 'status', 'expiresAt', 'canLaunch', 'verifiedAt', 'receipt'].sort())
  assert.equal(f.rows.size, 1)
  assert.deepEqual(f.calls.slice(0, 3), ['getUser', 'configuration', 'database'])
  assert.equal(f.calls[3].name, 'prepare_print_payment_test')
  assert.doesNotMatch(JSON.stringify(body), /synthetic-fixture-secret|owner_id|request_fingerprint/)
})

test('anonymous callers and regular customers cannot read configuration or create privileged clients', async () => {
  for (const [overrides, authorization, status] of [[{}, null, 401],
    [{ getUser: async () => ({ id: owner, app_metadata: { role: 'customer' }, user_metadata: { role: 'admin' } }) }, 'Bearer user', 403],
    [{ getUser: async () => null }, 'Bearer stale', 401],
    [{ getUser: async () => { throw new Error('private Auth error') } }, 'Bearer stale', 401]]) {
    const f = fixture(overrides), response = await f.handler(request(prepare(), { authorization }))
    assert.equal(response.status, status)
    assert.equal(f.rows.size, 0)
    assert.equal(f.calls.includes('configuration'), false)
    assert.equal(f.calls.includes('database'), false)
  }
})

test('malformed body, caller prices, customer data and callback success flags cannot alter stored expectations', async () => {
  for (const body of [null, [], {}, prepare({ scenario: 'soft20' }), prepare({ requestId: '' }),
    prepare({ totalAmount: 1 }), prepare({ environment: 'live' }), prepare({ storeId: 'other' }),
    prepare({ channelKey: 'other' }), prepare({ recipient: { name: 'synthetic' } }),
    { action: 'verify', paymentId: 'SFPGT_00000000-0000-4000-8000-000000000001', success: true }]) {
    const f = fixture(), response = await f.handler(request(body))
    assert.equal(response.status, 400)
    assert.deepEqual(await response.json(), { error: 'invalid_test_payment_request' })
    assert.equal(f.rows.size, 0); assert.equal(f.calls.includes('database'), false)
  }
  const f = fixture()
  assert.equal((await f.handler(request('{bad', { raw: true }))).status, 400)
})

test('LIVE, missing configuration and unverified routing are rejected before any session creation', async () => {
  for (const [changes, code] of [[{ environment: 'live' }, 'payment_test_environment_required'],
    [{ apiSecret: '' }, 'payment_test_configuration_missing'], [{ channelKey: '' }, 'payment_test_configuration_missing'],
    [{ channelKey: 'channel-key-other' }, 'payment_test_route_not_approved'],
    [{ storeId: 'store-other' }, 'payment_test_route_not_approved']]) {
    const f = fixture({ configuration: () => ({ ...configuration(), ...changes }) })
    const response = await f.handler(request(prepare()))
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: code })
    assert.equal(f.rows.size, 0); assert.equal(f.calls.includes('database'), false)
  }
})

test('same request ID is retry-safe and changed scenario cannot reuse an existing test purchase', async () => {
  const f = fixture()
  const first = await result(await f.handler(request(prepare())))
  const retry = await result(await f.handler(request(prepare())))
  assert.deepEqual(retry, first); assert.equal(f.rows.size, 1)
  const conflict = await result(await f.handler(request(prepare({ scenario: 'HARD_80' }))))
  assert.equal(conflict.status, 409); assert.equal(conflict.body.error, 'test_payment_request_conflict')
  assert.equal(f.rows.size, 1)
  const hard = await result(await f.handler(request(prepare({ scenario: 'HARD_80', requestId: '44444444-4444-4444-8444-444444444444' }))))
  assert.equal(hard.body.totalAmount, 159900)
})

test('status reads saved state only, and another admin cannot inspect or verify the owner session', async () => {
  const f = fixture(), saved = await (await f.handler(request(prepare()))).json()
  const before = f.calls.length
  const response = await f.handler(request({ action: 'status', paymentId: saved.paymentId }))
  assert.deepEqual(await response.json(), saved)
  assert.equal(f.calls.slice(before).some(call => typeof call === 'object' && call.queryPayment), false)
  f.dependencies.getUser = async () => ({ id: other, app_metadata: { role: 'admin' } })
  for (const action of ['status', 'verify']) {
    assert.deepEqual(await result(await f.handler(request({ action, paymentId: saved.paymentId }))),
      { status: 404, body: { error: 'test_payment_not_found' } })
  }
  assert.equal(f.commits, 0)
})

test('verification uses persisted expectations and only stores a successful TEST receipt after server lookup', async () => {
  const f = fixture(), saved = await (await f.handler(request(prepare()))).json()
  const response = await f.handler(request({ action: 'verify', paymentId: saved.paymentId }))
  const body = await response.json()
  assert.equal(response.status, 200); assert.equal(body.status, 'VERIFIED_TEST'); assert.equal(body.canLaunch, false)
  assert.deepEqual(body.receipt, observation(saved.paymentId)); assert.equal(f.commits, 1)
  const query = f.calls.find(call => typeof call === 'object' && call.queryPayment).queryPayment
  assert.deepEqual(query, { paymentId: saved.paymentId, ...route, amount: 49900, currency: 'KRW', environment: 'test' })
  assert.equal(f.calls.at(-1).name, 'verify_print_payment_test')
})

test('simultaneous verification retries commit one immutable receipt and timestamp', async () => {
  const f = fixture(), saved = await (await f.handler(request(prepare()))).json()
  const replies = await Promise.all([1, 2, 3].map(() => f.handler(request({ action: 'verify', paymentId: saved.paymentId })).then(result)))
  assert.ok(replies.every(reply => reply.status === 200))
  assert.deepEqual(replies[1], replies[0]); assert.deepEqual(replies[2], replies[0]); assert.equal(f.commits, 1)
  f.dependencies.queryPayment = async expected => ({ ...observation(expected.paymentId), paidAt: '2026-10-14T00:02:00Z' })
  assert.equal((await f.handler(request({ action: 'verify', paymentId: saved.paymentId }))).status, 409)
  assert.equal(f.commits, 1)
})

test('provider timeout, unpaid or missing payment leaves the prepared session available for recovery', async () => {
  for (const [code, status] of [['payment_lookup_timeout', 503], ['payment_not_paid', 409], ['payment_not_found', 404]]) {
    const f = fixture({ queryPayment: async () => { throw new PortOnePrintPaymentError(code, status, true) } })
    const saved = await (await f.handler(request(prepare()))).json()
    const response = await f.handler(request({ action: 'verify', paymentId: saved.paymentId }))
    assert.equal(response.status, status); assert.equal((await response.json()).error, code)
    const state = await (await f.handler(request({ action: 'status', paymentId: saved.paymentId }))).json()
    assert.equal(state.status, 'PREPARED'); assert.equal(state.receipt, null); assert.equal(f.commits, 0)
  }
})

test('actual adapter rejects a LIVE provider channel despite test-labeled SDK callback flags', async () => {
  const f = fixture({ queryPayment: async (expected, opts) => queryPortOnePrintPayment(expected, { ...opts,
    fetcher: async () => Response.json({ status: 'PAID', id: expected.paymentId, storeId: expected.storeId,
      version: 'V2', channel: { type: 'LIVE', key: expected.channelKey }, success: true, isTest: true }),
  }) })
  const saved = await (await f.handler(request(prepare()))).json()
  const response = await f.handler(request({ action: 'verify', paymentId: saved.paymentId }))
  assert.equal(response.status, 409); assert.equal((await response.json()).error, 'payment_environment_mismatch')
  assert.equal(f.commits, 0)
})

test('expiry prevents a new SDK launch but permits recovery of a late successful test payment', async () => {
  const f = fixture(), saved = await (await f.handler(request(prepare()))).json()
  f.rows.get(saved.paymentId).expires_at = '2026-10-13T00:00:00Z'
  const retry = await (await f.handler(request(prepare()))).json()
  assert.equal(retry.paymentId, saved.paymentId); assert.equal(retry.canLaunch, false)
  const verified = await (await f.handler(request({ action: 'verify', paymentId: saved.paymentId }))).json()
  assert.equal(verified.status, 'VERIFIED_TEST'); assert.equal(verified.canLaunch, false)
})

test('OPTIONS and wrong methods cannot access server configuration, database, or payment lookups', async () => {
  for (const [method, status] of [['OPTIONS', 200], ['GET', 405], ['DELETE', 405]]) {
    const f = fixture(), response = await f.handler(request(null, { method }))
    assert.equal(response.status, status); assert.equal(f.calls.length, 0)
  }
})

const runtime = process.env.SNAPFIT_PGLITE_ENTRY
test('isolated PostgreSQL validates permissions, price truth, immutable snapshots, replay identity and late recovery',
  { skip: !runtime }, async () => {
    const { PGlite } = await import(pathToFileURL(runtime).href)
    const db = new PGlite()
    try {
      await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
        create schema auth;create table auth.users(id uuid primary key);
        grant usage on schema public to anon,authenticated,service_role;
        create function public.print_combo_pricing_policy(text,integer) returns jsonb
        language sql immutable as $$select jsonb_build_object('supplierCostVerified',true,
          'retailPriceStatus','PLANNED','amount',case when $2=20 then 49900 else 159900 end)$$;
        revoke all on function public.print_combo_pricing_policy(text,integer) from public,anon,authenticated;
        grant execute on function public.print_combo_pricing_policy(text,integer) to service_role;`)
      const migration = readFileSync(new URL('../../supabase/migrations/20261013154850_admin_portone_test_payment_sessions.sql', import.meta.url), 'utf8')
      await db.exec(migration)
      await db.query('insert into auth.users values($1),($2)', [owner, other])
      const callPrepare = async (requestIdValue = requestId, scenario = 'SOFT_20', ownerValue = owner, key = route.channelKey) =>
        (await db.query('select public.prepare_print_payment_test($1,$2,$3,$4,$5) value',
          [ownerValue, requestIdValue, scenario, route.storeId, key])).rows[0].value
      const callVerify = async (row, receipt = observation(row.payment_id, row.total_amount), ownerValue = owner) =>
        (await db.query('select public.verify_print_payment_test($1,$2,$3::jsonb) value',
          [ownerValue, row.payment_id, JSON.stringify(receipt)])).rows[0].value
      for (const role of ['anon', 'authenticated']) {
        await db.exec(`set role ${role}`)
        await assert.rejects(callPrepare(), /permission denied/)
        await assert.rejects(db.query('select * from private.print_payment_test_sessions'), /permission denied/)
        await db.exec('reset role')
      }
      await db.exec('set role service_role')
      const first = await callPrepare()
      assert.equal(first.total_amount, 49900); assert.equal(first.environment, 'test'); assert.equal(first.status, 'PREPARED')
      assert.match(first.payment_id, /^SFPGT_/)
      assert.deepEqual(await callPrepare(), first)
      await assert.rejects(callPrepare(requestId, 'HARD_80'), /test_payment_request_conflict/)
      await assert.rejects(callPrepare(requestId, 'SOFT_20', owner, 'channel-key-unverified'), /invalid_test_payment_request/)
      await assert.rejects(db.query('select public.get_print_payment_test($1,$2)', [other, first.payment_id]), /test_payment_not_found/)
      await assert.rejects(callVerify(first, observation(first.payment_id), other), /test_payment_not_found/)
      await assert.rejects(callVerify(first, { ...observation(first.payment_id), isTest: false, environment: 'live' }), /test_payment_receipt_invalid/)
      await assert.rejects(callVerify(first, { ...observation(first.payment_id), customer: {} }), /test_payment_receipt_invalid/)
      const verified = await callVerify(first)
      assert.equal(verified.status, 'VERIFIED_TEST')
      await assert.rejects(db.query(`insert into private.print_payment_test_sessions(
        owner_id,request_id,scenario,request_fingerprint,store_id,channel_key,order_name,total_amount,
        status,receipt,verified_at) select owner_id,$1,scenario,request_fingerprint,store_id,channel_key,
        order_name,total_amount,'VERIFIED_TEST',receipt,now() from private.print_payment_test_sessions
        where payment_id=$2`, ['77777777-7777-4777-8777-777777777777', first.payment_id]), /test_payment_invalid_state/)
      assert.deepEqual(await callVerify(first), verified)
      await assert.rejects(callVerify(first, { ...observation(first.payment_id), transactionId: 'different-transaction' }), /test_payment_receipt_conflict/)
      await assert.rejects(db.query("update private.print_payment_test_sessions set total_amount=1 where payment_id=$1", [first.payment_id]), /test_payment_expectation_immutable/)
      await assert.rejects(db.query("update private.print_payment_test_sessions set receipt='{}' where payment_id=$1", [first.payment_id]), /test_payment_receipt_immutable/)
      const hard = await callPrepare('44444444-4444-4444-8444-444444444444', 'HARD_80')
      await assert.rejects(callVerify(hard, { ...observation(hard.payment_id, hard.total_amount), transactionId: verified.receipt.transactionId }), /duplicate key/)
      assert.equal((await db.query('select public.get_print_payment_test($1,$2) value', [owner, hard.payment_id])).rows[0].value.status, 'PREPARED')
      await db.exec('reset role')
      await db.exec("alter table private.print_payment_test_sessions alter column expires_at set default (now()-interval '1 day')")
      await db.exec('set role service_role')
      const late = await callPrepare('55555555-5555-4555-8555-555555555555')
      assert.ok(Date.parse(late.expires_at) < Date.now())
      assert.equal((await callVerify(late)).status, 'VERIFIED_TEST')
      await db.exec('reset role')
      await db.exec(`create or replace function public.print_combo_pricing_policy(text,integer) returns jsonb
        language sql immutable as $$select jsonb_build_object('supplierCostVerified',true,
          'retailPriceStatus','PLANNED','amount',1)$$`)
      await db.exec('set role service_role')
      await assert.rejects(callPrepare('66666666-6666-4666-8666-666666666666'), /test_payment_price_changed/)
      await db.exec('reset role')
      const permissions = (await db.query(`select
        has_table_privilege('authenticated','private.print_payment_test_sessions','SELECT') customer_table,
        has_function_privilege('authenticated','public.prepare_print_payment_test(uuid,uuid,text,text,text)','EXECUTE') customer_prepare,
        has_function_privilege('anon','public.verify_print_payment_test(uuid,text,jsonb)','EXECUTE') anon_verify,
        has_table_privilege('service_role','private.print_payment_test_sessions','DELETE') service_delete`)).rows[0]
      assert.deepEqual(permissions, { customer_table: false, customer_prepare: false, anon_verify: false, service_delete: false })
    } finally { await db.close() }
  })

test('deployed wrapper reads server payment configuration and creates admin DB only after verified admin authorization', async () => {
  const f = fixture(), calls = []; let handler
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/print-payment-test/index.ts', import.meta.url), 'utf8')
    .replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, {
    Deno: { serve: fn => { handler = fn }, env: { get: key => {
      calls.push(key)
      return { PRINT_PORTONE_ENVIRONMENT: 'test', PRINT_PORTONE_STORE_ID: route.storeId,
        PRINT_PORTONE_CHANNEL_KEY: route.channelKey, PRINT_PORTONE_V2_API_SECRET: 'synthetic-fixture-secret' }[key]
        ?? assert.fail('unexpected environment lookup')
    } } },
    getUser: async () => { calls.push('getUser'); return { id: owner, app_metadata: { role: 'admin' } } },
    adminClient: () => { calls.push('adminClient'); return f.dependencies.createAdminDatabase() },
    createPrintPaymentTestHandler,
  })
  assert.equal(calls.length, 0)
  assert.equal((await handler(request(prepare(), { authorization: null }))).status, 401)
  assert.equal(calls.length, 0)
  const response = await handler(request(prepare()))
  assert.equal(response.status, 200)
  assert.deepEqual(calls, ['getUser', 'PRINT_PORTONE_ENVIRONMENT', 'PRINT_PORTONE_STORE_ID',
    'PRINT_PORTONE_CHANNEL_KEY', 'PRINT_PORTONE_V2_API_SECRET', 'adminClient'])
  assert.doesNotMatch(JSON.stringify(await response.json()), /synthetic-fixture-secret/)
})

test('test gateway keeps JWT validation and legacy customer checkout remains HTTP 410', () => {
  const config = readFileSync(new URL('../../supabase/config.toml', import.meta.url), 'utf8')
  assert.match(config, /\[functions\.print-payment-test\][^[]*verify_jwt\s*=\s*true/)
  for (const name of ['order-checkout', 'order-confirm-payment']) {
    const source = readFileSync(new URL(`../../supabase/functions/${name}/index.ts`, import.meta.url), 'utf8')
    assert.match(source, /physical_order_payments_disabled/); assert.match(source, /410/)
  }
})

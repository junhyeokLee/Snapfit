import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import vm from 'node:vm'
import { createHmac, randomUUID } from 'node:crypto'
import { createPrintOrderSchedulerHandler, createPrintSchedulerProviderFetch, createPrintSchedulerRequestFetch, printSchedulerSignedPayload } from '../../supabase/functions/_shared/print-order-scheduler.ts'

const secret = 'a'.repeat(64), owner = '11111111-1111-4111-8111-111111111111', jobId = '22222222-2222-4222-8222-222222222222'
const payment = { user_id: owner, payment_id: 'SFP_33333333-3333-4333-8333-333333333333' }
function fixture(options = {}) {
  let clock = Date.now()
  const calls = [], config = { enabled: true, paymentObservable: true, refundsEnabled: true, fulfillmentReady: true, ...options.config }
  const database = { async rpc(name, args) {
    calls.push({ name, args })
    if (options.databaseError) return { data: null, error: { message: 'private database error' } }
    if (name === 'consume_print_order_scheduler_nonce') return { data: options.nonceAccepted !== false, error: options.nonceError ?? null }
    if (name === 'record_print_order_scheduler_heartbeat') return { data: null, error: null }
    if (name === 'claim_production_print_payment_rechecks') return { data: options.payments ?? [payment], error: null }
    if (name === 'list_print_order_requests') return { data: options.requests ?? [], error: null }
    if (name === 'claim_print_app_pdf_fulfillment_job') return { data: options.claim === null ? null : { job: {
      id: jobId, event_type: 'SUBMIT', state: 'CLAIMED', lease_owner: owner, lease_until: new Date(clock + 120000).toISOString(), ...options.job,
    } }, error: null }
    if (name === 'claim_abandoned_print_prepayment_packages') return { data: options.cleanup ?? [], error: null }
    if (name === 'finish_abandoned_print_prepayment_package') return { data: null, error: null }
    throw new Error('unexpected RPC')
  } }
  const handler = createPrintOrderSchedulerHandler({
    secret() { calls.push('secret'); return options.secret ?? secret },
    configuration() { calls.push('config'); return config }, createAdminDatabase() { calls.push('database'); return database },
    async reconcile(db, refs) { calls.push({ payment: refs }); clock += options.reconcileMs ?? 0
      if (options.reconcileError) throw new Error('private provider URL/key')
      return options.observation ?? { verifiedPaid: true } },
    async resolve(db, id, worker) { calls.push({ resolve: id, worker }); if (options.resolveError) throw new Error('private cancellation data')
      return { processed: true, request: { status: 'COMPLETED' } } },
    async advance(db, id, worker) { calls.push({ advance: id, worker }); if (options.advanceError) throw new Error('private supplier data') },
    ...(options.development ? { async development(db) { calls.push('development');
      if (options.developmentError) throw new Error('private TEST provider key')
      return options.development } } : {}),
    ...(options.cleanup ? { async removeFiles(db, paths) { calls.push({ remove: paths });
      if (options.removeError) throw new Error('private storage failure')
      return options.removed !== false } } : {}),
    now: () => clock, randomUUID: () => owner,
  })
  return { handler, calls }
}
const signedHeaders = (key = secret, signedAt = Math.floor(Date.now() / 1000), nonce = randomUUID()) => ({
  'X-Snapfit-Scheduler-Timestamp': String(signedAt), 'X-Snapfit-Scheduler-Nonce': nonce,
  'X-Snapfit-Scheduler-Signature': createHmac('sha256', key).update(printSchedulerSignedPayload(signedAt, nonce)).digest('hex'),
})
const request = (body = {}, supplied = secret, method = 'POST', raw = false) => new Request('https://fixture.invalid/scheduler', {
  method, headers: supplied == null ? { Authorization: 'Bearer customer-user-jwt' } : signedHeaders(supplied),
  ...(method === 'POST' ? { body: raw ? body : JSON.stringify(body) } : {}),
})

test('anonymous, ordinary signed customer/admin sessions and malformed secrets cannot inspect configuration or queues', async () => {
  for (const supplied of [null, '', 'b'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'A'.repeat(64), 'Bearer ' + secret]) {
    const f = fixture()
    assert.equal((await f.handler(request({}, supplied))).status, 401)
    assert.deepEqual(f.calls, ['secret'])
  }
})
test('missing runtime secret closes the private endpoint and never emits credentials', async () => {
  for (const value of ['', 'invalid', 'a'.repeat(63)]) {
    const f = fixture({ secret: value }), response = await f.handler(request())
    assert.equal(response.status, 401)
    assert.deepEqual(await response.json(), { error: 'authentication_required' })
    assert.equal(response.headers.get('cache-control'), 'no-store')
  }
})
test('HMAC rejects stale/future/tampered headers and a raw secret; valid signatures consume private nonce before any business work',async()=>{
  const timestamp=Math.floor(Date.now()/1000),nonce=owner
  for(const headers of[
    signedHeaders(secret,timestamp-121,nonce),signedHeaders(secret,timestamp+121,nonce),
    {...signedHeaders(secret,timestamp,nonce),'X-Snapfit-Scheduler-Nonce':jobId},
    {...signedHeaders(secret,timestamp,nonce),'X-Snapfit-Scheduler-Timestamp':String(timestamp+1)},
    {...signedHeaders(secret,timestamp,nonce),'X-Snapfit-Scheduler-Signature':'b'.repeat(64)},
    {...signedHeaders(secret,timestamp,nonce),'X-Snapfit-Scheduler-Secret':secret},
    {'X-Snapfit-Scheduler-Secret':secret},
  ]){
    const f=fixture(),result=await f.handler(new Request('https://fixture.invalid',{method:'POST',headers,body:'{}'}))
    assert.equal(result.status,401);assert.deepEqual(f.calls,['secret'])
  }
  const rejected=fixture({nonceAccepted:false}),response=await rejected.handler(request())
  assert.equal(response.status,403)
  assert.equal(rejected.calls.some(call=>call==='config'||call?.name==='record_print_order_scheduler_heartbeat'||call?.payment||call?.advance),false)
  const unavailable=fixture({nonceError:{message:'private SQL detail'}})
  assert.equal((await unavailable.handler(request())).status,503)
  const valid=fixture({config:{enabled:false}})
  assert.equal((await valid.handler(request())).status,200)
  assert.equal(valid.calls[2].name,'consume_print_order_scheduler_nonce');assert.equal(valid.calls[3],'config')
})
test('unsupported methods do no authentication/configuration/queue work', async () => {
  for (const method of ['GET', 'OPTIONS', 'PUT']) {
    const f = fixture()
    assert.equal((await f.handler(request({}, null, method))).status, 405)
    assert.deepEqual(f.calls, [])
  }
})
test('authenticated callers cannot supply owner, paid status, amount, credential, environment, job or batch size', async () => {
  for (const body of [null, [], { limit: 3 }, { environment: 'live' }, { isTest: false }, { paymentId: payment.payment_id },
    { amount: 49900 }, { owner }, { jobId }, { apiKey: 'injected' }]) {
    const f = fixture()
    assert.equal((await f.handler(request(body))).status, 400)
    assert.deepEqual(f.calls, ['secret'])
  }
  for (const body of ['{broken', ' '.repeat(1025)]) {
    const f = fixture()
    assert.equal((await f.handler(request(body, secret, 'POST', true))).status, 400)
  }
})
test('closed development configuration records heartbeat but performs no payment/supplier/queue claim', async () => {
  const f = fixture({ config: { enabled: false, paymentObservable: false, refundsEnabled: false, fulfillmentReady: false } })
  const result = await (await f.handler(request())).json()
  assert.equal(result.enabled, false); assert.equal(result.runtimeReady, false)
  assert.deepEqual(f.calls.filter(value => value?.name !== 'consume_print_order_scheduler_nonce'),
    ['secret', 'database', 'config', { name: 'record_print_order_scheduler_heartbeat', args: { p_runtime_ready: false } }])
})
test('enabled TEST/disabled financial runtime is a heartbeat-only no-op', async () => {
  const f = fixture({ config: { paymentObservable: false, fulfillmentReady: false } })
  const result = await (await f.handler(request())).json()
  assert.equal(result.enabled, true); assert.equal(result.runtimeReady, false)
  assert.equal(f.calls.length, 5)
})
test('separate enabled TEST queue keeps running with LIVE sales closed and performs only one bounded development phase', async () => {
  const development = { enabled: true, checked: 1, advanced: 1, errors: 0, stage: 'SUBMIT' }
  const f = fixture({ config: { paymentObservable: false, fulfillmentReady: false }, development })
  const result = await (await f.handler(request())).json()
  assert.equal(result.runtimeReady, false); assert.deepEqual(result.development, development)
  assert.equal(f.calls.includes('development'), true)
  assert.equal(f.calls.some(call => call?.payment || call?.advance || call?.resolve || call?.name === 'claim_print_app_pdf_fulfillment_job'), false)
  const closed = fixture({ config: { enabled: false }, development })
  await closed.handler(request()); assert.equal(closed.calls.includes('development'), false)
  const rejected = fixture({ development })
  await rejected.handler(request({}, null)); assert.equal(rejected.calls.includes('development'), false)
})
test('development phase failures are counted without exposing private provider errors or attempting LIVE work', async () => {
  const f = fixture({ development: { enabled: true }, developmentError: true })
  const result = await (await f.handler(request())).json()
  assert.equal(result.development.errors, 1); assert.equal(f.calls.some(call => call?.payment || call?.advance), false)
  assert.doesNotMatch(JSON.stringify(result), /private|provider key/)
})
test('Cron uses only due database references then an attached-PDF claim, never a renderer or client receipt', async () => {
  const f = fixture(), response = await f.handler(request()), result = await response.json()
  assert.equal(response.status, 200)
  assert.equal(result.payments.verifiedPaid, 1); assert.equal(result.fulfillment.advanced, 1)
  assert.deepEqual(f.calls.find(v => v?.payment), { payment: { userId: owner, paymentId: payment.payment_id } })
  assert.deepEqual(f.calls.find(v => v?.name === 'claim_print_app_pdf_fulfillment_job'), { name: 'claim_print_app_pdf_fulfillment_job',
    args: { p_worker_id: owner, p_limit: 1, p_lease_seconds: 120, p_runtime_ready: true } })
  assert.doesNotMatch(JSON.stringify(result), /SFP_|11111111|22222222|a{64}|Bearer|private/)
  assert.equal(f.calls.some(v => v?.name === 'claim_print_fulfillment_job'), false)
})
test('pending customer cancellation/refund takes precedence and defers supplier mutation to another invocation', async () => {
  const f = fixture({ requests: [{ requestId: jobId }] }), result = await (await f.handler(request())).json()
  assert.equal(result.requests.completed, 1)
  assert.equal(result.fulfillment.checked, 0)
  assert.equal(f.calls.some(v => v?.name === 'claim_print_app_pdf_fulfillment_job'), false)
})
test('closing new financial runtime still observes issued LIVE invoices without submitting new supplier jobs', async () => {
  const f = fixture({ config: { fulfillmentReady: false, refundsEnabled: false } }), result = await (await f.handler(request())).json()
  assert.equal(result.payments.verifiedPaid, 1); assert.equal(result.runtimeReady, false)
  assert.equal(f.calls.some(v => v?.advance), false)
})
test('invalid claimed references fail closed before calling a provider or supplier', async () => {
  for (const payments of [[{ ...payment, user_id: 'other' }], [{ ...payment, payment_id: 'other' }], [payment, payment]]) {
    const f = fixture({ payments })
    assert.equal((await f.handler(request())).status, 503)
    assert.equal(f.calls.some(v => v?.payment || v?.advance), false)
  }
})
test('unexpected RENDER stage, wrong lease, expired or malformed jobs never call advance', async () => {
  for (const job of [{ event_type: 'RENDER' }, { id: 'invalid' }, { state: 'PENDING' }, { lease_owner: jobId },
    { lease_until: '2000-01-01T00:00:00Z' }, { lease_until: 'not-a-time' }]) {
    const f = fixture({ job })
    assert.equal((await f.handler(request())).status, 503)
    assert.equal(f.calls.some(v => v?.advance), false)
  }
})
test('slow payment lookup stops before any cancellation or supplier financial phase', async () => {
  const f = fixture({ reconcileMs: 35000 }), result = await (await f.handler(request())).json()
  assert.equal(result.budgetDeferred, true)
  assert.equal(result.payments.checked, 1)
  assert.equal(f.calls.some(v => v?.resolve || v?.advance || v?.name === 'list_print_order_requests'), false)
})
test('lookup failures and ambiguous results remain pending and do not invent paid/unpaid proof', async () => {
  const failed = fixture({ reconcileError: true, claim: null }), failure = await (await failed.handler(request())).json()
  assert.equal(failure.payments.errors, 1)
  for (const observation of [{}, { verifiedPaid: true, verifiedUnpaid: true }]) {
    const f = fixture({ observation, claim: null }), result = await (await f.handler(request())).json()
    assert.equal(result.payments.pending, 1); assert.equal(result.payments.verifiedPaid, 0); assert.equal(result.payments.verifiedUnpaid, 0)
  }
})
test('financial/provider failures are counted without returning private error details or automatic second POST', async () => {
  const f = fixture({ advanceError: true }), result = await (await f.handler(request())).json()
  assert.equal(result.fulfillment.errors, 1)
  assert.equal(f.calls.filter(v => v?.advance).length, 1)
  assert.doesNotMatch(JSON.stringify(result), /private supplier/)
  const resolver = fixture({ requests: [{ requestId: jobId }], resolveError: true }), result2 = await (await resolver.handler(request())).json()
  assert.equal(result2.requests.errors, 1); assert.equal(result2.fulfillment.checked, 0)
})
test('deployed wrapper defaults all production work off and exposes only the dedicated secret gate', async () => {
  let dependencies, served, databaseOptions
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/print-order-scheduler/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, { createPrintOrderSchedulerHandler(value) { dependencies = value; return async () => new Response() },
    adminClient(options) { databaseOptions = options; return {} }, fetch,
    createPrintSchedulerRequestFetch: () => async () => { throw new Error('Unexpected external request') },
    Deno: { env: { get() { return undefined } }, serve(value) { served = value } }, Response })
  assert.equal(typeof served, 'function')
  await served(request())
  assert.equal(dependencies.secret(), '')
  assert.deepEqual(JSON.parse(JSON.stringify(dependencies.configuration())), { enabled: false, paymentObservable: false, refundsEnabled: false, fulfillmentReady: false })
  dependencies.createAdminDatabase()
  const firstFetch = databaseOptions.fetch
  assert.equal(typeof firstFetch, 'function')
  await served(request())
  dependencies.createAdminDatabase()
  assert.notEqual(firstFetch, databaseOptions.fetch)
})
test('actual Cron wrapper ignores a leftover TEST feature flag after switching PG to LIVE and continues LIVE payment reconciliation', async () => {
  let served, developmentCalls = 0, reconciled = 0
  const environment = { PRINT_ORDER_SCHEDULER_SECRET: secret, PRINT_ORDER_SCHEDULER_ENABLED: 'true',
    PRINT_DEV_CHECKOUT_ENABLED: 'true', PRINT_PORTONE_ENVIRONMENT: 'live', PRINT_PORTONE_STORE_ID: 'store-fixture-live',
    PRINT_PORTONE_CHANNEL_KEY: 'channel-key-fixture-live', PRINT_PORTONE_V2_API_SECRET: 'fixture-private-live-provider-key' }
  const database = { async rpc(name) {
    if (name === 'consume_print_order_scheduler_nonce') return { data: true, error: null }
    if (name === 'record_print_order_scheduler_heartbeat') return { data: null, error: null }
    if (name === 'claim_production_print_payment_rechecks') return { data: [payment], error: null }
    if (name === 'claim_abandoned_print_prepayment_packages') return { data: [], error: null }
    throw new Error('Unexpected LIVE wrapper RPC')
  } }
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/print-order-scheduler/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, { createPrintOrderSchedulerHandler, createPrintSchedulerRequestFetch,
    adminClient() { return database }, fetch, Response, Request, crypto,
    runPrintDevFulfillmentTick() { developmentCalls++; throw new Error('TEST tick must not run under LIVE PG') },
    RedprintingClient: class { constructor() { throw new Error('DEV provider must not be constructed') } },
    async reconcileProductionPrintPayment() { reconciled++; return { status: 'PAID' } },
    Deno: { env: { get(name) { return environment[name] } }, serve(handler) { served = handler } } })
  const response = await served(request()), result = await response.json()
  assert.equal(response.status, 200)
  assert.equal(result.development.enabled, false); assert.equal(result.development.errors, 0)
  assert.equal(result.payments.verifiedPaid, 1); assert.equal(reconciled, 1)
  assert.equal(developmentCalls, 0)
})

test('provider deadline retains the original shorter/aborted signal in RequestInit and Request input', async () => {
  for (const inputRequest of [false, true]) {
    const original = new AbortController(); let observed
    const provider = createPrintSchedulerProviderFetch(async (input, init) => { observed = init.signal; return Response.json({ ok: true }) })
    await provider(inputRequest ? new Request('https://fixture.invalid/provider', { signal: original.signal }) : 'https://fixture.invalid/provider',
      inputRequest ? undefined : { signal: original.signal })
    assert.equal(observed.aborted, false)
    original.abort('earlier deadline')
    assert.equal(observed.aborted, true); assert.equal(observed.reason, 'earlier deadline')
  }
  const stopped = new AbortController(); stopped.abort('already stopped'); let signal
  await createPrintSchedulerProviderFetch(async (input, init) => { signal = init.signal; return new Response() })('https://fixture.invalid', { signal: stopped.signal })
  assert.equal(signal.aborted, true); assert.equal(signal.reason, 'already stopped')
})
test('provider deadline aborts a long call without leaving an unbounded background task', async () => {
  let signal
  await createPrintSchedulerProviderFetch(async (input, init) => { signal = init.signal; return new Response() }, 1)('https://fixture.invalid')
  await new Promise(resolve => setTimeout(resolve, 5))
  assert.equal(signal.aborted, true)
  for (const value of [0, -1, 12001, NaN, '12000']) assert.throws(() => createPrintSchedulerProviderFetch(fetch, value), /invalid_scheduler_timeout/)
})

test('request budget has a fresh deadline for each invocation and blocks all later database/provider/Storage calls', async () => {
  let firstCalls = 0, secondCalls = 0, firstSignal, secondSignal
  const first = createPrintSchedulerRequestFetch(async (input, init) => { firstCalls++; firstSignal = init.signal; return new Response() }, 1)
  const second = createPrintSchedulerRequestFetch(async (input, init) => { secondCalls++; secondSignal = init.signal; return new Response() })
  await first('https://fixture.invalid/database')
  await second('https://fixture.invalid/provider')
  await new Promise(resolve => setTimeout(resolve, 5))
  assert.equal(firstSignal.aborted, true)
  assert.equal(secondSignal.aborted, false)
  for (const path of ['database', 'provider', 'storage']) await assert.rejects(first(`https://fixture.invalid/${path}`), { name: 'TimeoutError' })
  assert.equal(firstCalls, 1)
  await second('https://fixture.invalid/database')
  assert.equal(secondCalls, 2)
  for (const value of [0, -1, 115001, NaN, '115000']) assert.throws(() => createPrintSchedulerRequestFetch(fetch, value), /invalid_scheduler_execution_budget/)
})
test('request budget forwards shorter caller cancellation and incoming request cancellation without starting new I/O', async () => {
  const requestStop = new AbortController(), operationStop = new AbortController(); let observed, calls = 0
  const contextual = createPrintSchedulerRequestFetch(async (input, init) => { calls++; observed = init.signal; return new Response() }, 115_000,
    requestStop.signal)
  await contextual('https://fixture.invalid/provider', { signal: operationStop.signal })
  operationStop.abort('shorter operation timeout')
  assert.equal(observed.aborted, true); assert.equal(observed.reason, 'shorter operation timeout')
  requestStop.abort('incoming request aborted')
  await assert.rejects(contextual('https://fixture.invalid/next-post'), value => value === 'incoming request aborted')
  assert.equal(calls, 1)
  const original = new AbortController(); original.abort('already canceled')
  const newContext = createPrintSchedulerRequestFetch(async () => { throw new Error('Must not invoke this provider') })
  await assert.rejects(newContext(new Request('https://fixture.invalid/storage', { signal: original.signal })), value => value === 'already canceled')
})

const packageId = '44444444-4444-4444-8444-444444444444'
const abandoned = { id: packageId, paths: ['cover.pdf', 'interior.pdf', 'manifest.json'].map(file => `ordp_${jobId}/${packageId}/${file}`) }
test('idle scheduler removes only one server-claimed abandoned package with exact paths and commits cleanup result', async () => {
  const f = fixture({ payments: [], claim: null, cleanup: [abandoned] }), result = await (await f.handler(request())).json()
  assert.deepEqual(result.cleanup, { checked: 1, removed: 1, errors: 0 })
  assert.deepEqual(f.calls.find(v => v?.remove), { remove: abandoned.paths })
  assert.deepEqual(f.calls.find(v => v?.name === 'finish_abandoned_print_prepayment_package'), { name: 'finish_abandoned_print_prepayment_package',
    args: { p_id: packageId, p_removed: true } })
})
test('abandoned large PDFs clean up only bounded server-generated chunk paths in the same package', async () => {
  const chunkPaths = [...Array.from({ length: 10 }, (_, index) => `ordp_${jobId}/${packageId}/cover/part-${String(index).padStart(3, '0')}.bin`),
    ...Array.from({ length: 32 }, (_, index) => `ordp_${jobId}/${packageId}/interior/part-${String(index).padStart(3, '0')}.bin`)]
  const cleanup = { ...abandoned, paths: [...abandoned.paths, ...chunkPaths] }
  const f = fixture({ payments: [], claim: null, cleanup: [cleanup] }), result = await (await f.handler(request())).json()
  assert.deepEqual(result.cleanup, { checked: 1, removed: 1, errors: 0 })
  assert.deepEqual(f.calls.find(call => call?.remove).remove, cleanup.paths)
})
test('disabled/TEST runtime and invocations doing financial work never claim cleanup or remove files', async () => {
  for (const options of [{ config: { enabled: false } }, { config: { paymentObservable: false, fulfillmentReady: false } }, {},
    { payments: [], requests: [{ requestId: jobId }] }, { payments: [] }]) {
    const f = fixture({ ...options, cleanup: [abandoned] }), result = await (await f.handler(request())).json()
    assert.equal(result.cleanup.checked, 0)
    assert.equal(f.calls.some(v => v?.remove || v?.name === 'claim_abandoned_print_prepayment_packages'), false)
  }
})
test('cleanup rejects unsafe paths, borrowed order/package folders, duplicate filenames and oversized batches before remove', async () => {
  for (const cleanup of [[{ ...abandoned, id: jobId }], [{ ...abandoned, paths: [abandoned.paths[0], abandoned.paths[0], abandoned.paths[2]] }],
    [{ ...abandoned, paths: [...abandoned.paths.slice(0, 2), 'other-order/secret.json'] }],
    [{ ...abandoned, paths: ['https://outside.invalid/file.pdf', ...abandoned.paths.slice(1)] }], [abandoned, abandoned],
    [{ ...abandoned, paths: abandoned.paths.map(path => path.replace('/cover.pdf', '/../cover.pdf')) }],
    ...['cover/part-010.bin', 'interior/part-032.bin', 'interior/part-000.bin/extra', 'interior/part-00.bin', 'interior/../part-000.bin',
      'unknown/part-000.bin', 'interior/part-000.pdf'].map(suffix => [{ ...abandoned, paths: [...abandoned.paths, `ordp_${jobId}/${packageId}/${suffix}`] }]),
    [{ ...abandoned, paths: [...abandoned.paths, `ordp_${jobId}/${packageId}/interior/part-000.bin`, `ordp_${jobId}/${packageId}/interior/part-000.bin`] }],
    [{ ...abandoned, paths: [...abandoned.paths, `ordp_${jobId}/${jobId}/interior/part-000.bin`] }]]) {
    const f = fixture({ payments: [], claim: null, cleanup })
    assert.equal((await f.handler(request())).status, 503)
    assert.equal(f.calls.some(v => v?.remove), false)
  }
})
test('storage failure resets safe abandoned cleanup for later retry without pretending files are removed', async () => {
  for (const options of [{ removed: false }, { removeError: true }]) {
    const f = fixture({ payments: [], claim: null, cleanup: [abandoned], ...options }), result = await (await f.handler(request())).json()
    assert.deepEqual(result.cleanup, { checked: 1, removed: 0, errors: 1 })
    assert.equal(f.calls.find(v => v?.name === 'finish_abandoned_print_prepayment_package').args.p_removed, false)
  }
})

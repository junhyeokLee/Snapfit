import assert from 'node:assert/strict'
import { test } from 'node:test'
import { EventEmitter } from 'node:events'
import { spawn } from 'node:child_process'
import { mkdtemp, readFile, stat, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { runRendererProcess, renderPaidAlbum, workerTick, WorkerTransport, checkedFixtureScenario, checkedFixtureArtwork, checkedWorkerOptions, rendererEnvironment } from '../../tool/print_fulfillment/run_worker.mjs'

const wait = ms => new Promise(resolve => setTimeout(resolve, ms))
const error = code => Object.assign(new Error(code), { code })
const workerId = '11111111-1111-4111-8111-111111111111'
const route = { url: 'https://fixture.supabase.co', publishableKey: 'public-fixture' }
const session = { access_token: 'rotated-fixture-access', refresh_token: 'rotated-fixture-refresh', expires_in: 3600 }

test('render cancellation waits for close and terminates the entire Unix group before reporting failure', async () => {
  const child = new EventEmitter(), sent = [], controller = new AbortController()
  child.pid = 424242; child.stdout = new EventEmitter(); child.stderr = new EventEmitter()
  let options, completed = false
  const result = runRendererProcess('/local/fixture', [], { env: {}, signal: controller.signal, timeoutMs: 1000,
    killGraceMs: 15, platform: 'linux', spawnProcess: (_, __, value) => { options = value; return child },
    signalGroup: (pid, signal) => sent.push({ pid, signal }) }).catch(failure => { completed = true; throw failure })
  controller.abort()
  await wait(25)
  assert.equal(completed, false)
  assert.equal(options.detached, true)
  assert.deepEqual(sent, [{ pid: -424242, signal: 'SIGTERM' }, { pid: -424242, signal: 'SIGKILL' }])
  const rejected = assert.rejects(result, /print_worker_interrupted/)
  child.emit('close', null)
  await rejected
  assert.equal(sent.at(-1).signal, 'SIGKILL')
})

test('renderer timeout escalates and a later clean exit cannot become successful artwork', async () => {
  const child = new EventEmitter(), signals = []
  child.pid = 424243; child.stdout = new EventEmitter(); child.stderr = new EventEmitter()
  const output = runRendererProcess('/local/fixture', [], { env: {}, timeoutMs: 10, killGraceMs: 10,
    platform: 'linux', spawnProcess: () => child, signalGroup: (_, signal) => signals.push(signal) })
  const rejected = assert.rejects(output, /print_renderer_failed/)
  await wait(30)
  assert.deepEqual(signals, ['SIGTERM', 'SIGKILL'])
  child.emit('close', 0)
  await rejected
})

test('real local stubborn renderer and descendant stop writing after cancellation and escalation', { skip: process.platform === 'win32' }, async () => {
  const directory = await mkdtemp(join(tmpdir(), 'snapfit-render-stop-')), file = join(directory, 'heartbeat.txt')
  const controller = new AbortController(), groups = []
  let ready, pid
  const prepared = new Promise(resolve => { ready = resolve })
  // Synthetic local process tree only: no Flutter, account, artwork URL or API.
  const descendant = `const fs=require('node:fs');process.on('SIGTERM',()=>{});setInterval(()=>fs.appendFileSync(process.argv[1],'x'),5);process.stdout.write('ready');`
  const parent = `const {spawn}=require('node:child_process');process.on('SIGTERM',()=>{});spawn(process.execPath,['-e',${JSON.stringify(descendant)},process.argv[1]],{stdio:['ignore','inherit','inherit']});setInterval(()=>{},1000);`
  const outcome = runRendererProcess(process.execPath, ['-e', parent, file], { env: { PATH: '/usr/bin:/bin' }, signal: controller.signal,
    timeoutMs: 5000, killGraceMs: 25, spawnProcess: (...args) => {
      const child = spawn(...args); pid = child.pid; child.stdout.on('data', data => { if (String(data).includes('ready')) ready() }); return child
    }, signalGroup: (group, signal) => { groups.push(signal); process.kill(group, signal) } })
  const rejected = assert.rejects(outcome, /print_worker_interrupted/)
  try {
    await Promise.race([prepared, wait(3000).then(() => { throw error('local_fixture_process_timeout') })])
    await wait(25); controller.abort(); await rejected
    const bytes = (await stat(file)).size
    await wait(60)
    assert.equal((await stat(file)).size, bytes)
    assert.ok(groups.includes('SIGTERM')); assert.ok(groups.includes('SIGKILL'))
  } finally {
    if (pid) { try { process.kill(-pid, 'SIGKILL') } catch {} }
    await rm(directory, { recursive: true, force: true })
  }
})

test('renderer temp artwork stays private until process termination completes and is then removed', async () => {
  let entered, release, directory
  const start = new Promise(resolve => { entered = resolve }), closed = new Promise(resolve => { release = resolve })
  const output = renderPaidAlbum({ fixtureOnly: true }, { processRunner: async (_, args, options) => {
    assert.equal(args[0], '--no-version-check')
    assert.ok(args.includes('--no-pub'))
    assert.equal(options.env.FLUTTER_SUPPRESS_ANALYTICS, 'true')
    directory = options.env.SNAPFIT_RENDER_OUTPUT; entered(); await closed; throw error('print_renderer_failed')
  } })
  const rejected = assert.rejects(output, /print_renderer_failed/)
  await start
  assert.equal((await stat(directory)).mode & 0o777, 0o700)
  assert.equal((await stat(join(directory, 'input.json'))).mode & 0o777, 0o600)
  assert.equal(JSON.parse(await readFile(join(directory, 'input.json'), 'utf8')).fixtureOnly, true)
  release(); await rejected
  await assert.rejects(stat(directory), { code: 'ENOENT' })
})

test('concurrent calls share one normal login and only rotated bearer reaches protected endpoints', async () => {
  let release, logins = 0
  const pending = new Promise(resolve => { release = resolve }), headers = []
  const transport = new WorkerTransport({ ...route, email: 'local-worker@example.invalid', password: 'fixture-only-password',
    fetcher: async (url, init) => {
      if (url.includes('/auth/')) { logins++; await pending; return Response.json(session) }
      headers.push(init.headers.Authorization); return Response.json({ enabled: false })
    } })
  const calls = [transport.call('print-payment-reconcile', { limit: 3 }), transport.call('print-fulfillment-worker', { action: 'claim', workerId })]
  await wait(0); assert.equal(logins, 1); release(); await Promise.all(calls)
  assert.deepEqual(headers, ['Bearer rotated-fixture-access', 'Bearer rotated-fixture-access'])
})

test('concurrent 401s refresh once and repeat the identical durable request only once', async () => {
  let renewals = 0
  const requests = []
  const transport = new WorkerTransport({ ...route, jwt: 'expired-fixture', refreshToken: 'old-fixture-refresh', fetcher: async (url, init) => {
    if (url.includes('/auth/')) { renewals++; await wait(10); return Response.json(session) }
    requests.push({ body: init.body, bearer: init.headers.Authorization })
    return init.headers.Authorization === 'Bearer expired-fixture' ? Response.json({ error: 'jwt_expired' }, { status: 401 }) : Response.json({ processed: 1 })
  } })
  const body = { action: 'advance', jobId: '22222222-2222-4222-8222-222222222222', workerId }
  await Promise.all([transport.call('print-fulfillment-worker', body), transport.call('print-fulfillment-worker', body)])
  assert.equal(renewals, 1); assert.equal(requests.length, 4)
  assert.ok(requests.every(request => request.body === JSON.stringify(body)))
  assert.equal(requests.filter(request => request.bearer === 'Bearer rotated-fixture-access').length, 2)
})

test('a second 401 is reported without an auth retry loop or another supplier action', async () => {
  let endpoints = 0, renewals = 0
  const transport = new WorkerTransport({ ...route, jwt: 'expired-fixture', refreshToken: 'old-refresh', fetcher: async url => {
    if (url.includes('/auth/')) { renewals++; return Response.json(session) }
    endpoints++; return Response.json({ error: 'worker_role_required' }, { status: 401 })
  } })
  await assert.rejects(transport.call('print-fulfillment-worker', { action: 'advance', workerId }), /worker_role_required/)
  assert.equal(endpoints, 2); assert.equal(renewals, 1)
})

test('failed refresh falls back to normal account login and respects shorter session expiry', async () => {
  const auth = []
  const transport = new WorkerTransport({ ...route, jwt: 'expired-fixture', refreshToken: 'expired-refresh', email: 'local-worker@example.invalid', password: 'fixture-only-password', fetcher: async url => {
    if (url.includes('/auth/')) {
      auth.push(url)
      return url.endsWith('refresh_token') ? Response.json({}, { status: 400 }) : Response.json({ ...session, expires_in: 120 })
    }
    return Response.json({ enabled: false })
  } })
  transport.nextRefresh = 0
  const before = Date.now(); await transport.call('print-fulfillment-worker', { action: 'claim', workerId })
  assert.equal(auth.length, 2); assert.match(auth[1], /grant_type=password$/)
  assert.ok(transport.nextRefresh >= before + 59_000 && transport.nextRefresh <= Date.now() + 60_000)
})

test('immutable upload 401 retries the same bytes and URL without overwrite', async () => {
  const uploads = []
  const bytes = Buffer.from('synthetic PDF fixture')
  const transport = new WorkerTransport({ ...route, jwt: 'expired-fixture', refreshToken: 'old-refresh', fetcher: async (url, init) => {
    if (String(url).includes('/auth/')) return Response.json(session)
    uploads.push({ url: String(url), bytes: init.body, headers: init.headers })
    return uploads.length === 1 ? new Response('', { status: 401 }) : new Response('', { status: 200 })
  } })
  const signedUrl = `${route.url}/storage/v1/object/upload/sign/print-packages/fixture.pdf?token=local-fixture`
  await transport.upload({ signedUrl }, bytes)
  assert.equal(uploads.length, 2)
  for (const upload of uploads) { assert.equal(upload.url, signedUrl); assert.equal(upload.bytes, bytes); assert.equal(upload.headers['x-upsert'], 'false') }
})

test('only explicit synthetic 20/80 scenarios reach the child and never authorize production', () => {
  for (const scenario of ['SOFT_20', 'HARD_80']) {
    assert.equal(checkedFixtureScenario(scenario), scenario)
    const env = rendererEnvironment({ PRINT_REDP_PRODUCTION_API_KEY: 'fixture-only-key' }, '/tmp/input', '/tmp/output', true, scenario)
    assert.equal(env.SNAPFIT_WORKER_FIXTURE_SCENARIO, scenario)
    assert.equal(env.SNAPFIT_WORKER_FIXTURE_ARTWORK, scenario === 'HARD_80' ? 'compact' : 'standard')
    assert.doesNotMatch(JSON.stringify(env), /PRODUCTION_API|fixture-only-key/)
  }
  for (const scenario of ['LIVE', 'HARD_82', '', '--live']) assert.throws(() => checkedFixtureScenario(scenario), /print_fixture_scenario_invalid/)
  for (const value of ['LIVE', 'customer-photo', '', '--production']) assert.throws(() => checkedFixtureArtwork(value), /print_fixture_artwork_invalid/)
  assert.equal(rendererEnvironment({}, '/tmp/input', '/tmp/output', true, 'HARD_80', 'standard').SNAPFIT_WORKER_FIXTURE_ARTWORK, 'standard')
})

test('request recovery tick runs between reconcile and guarded claim; errors remain fixed host-log codes', async () => {
  for (const failure of [error('order_request_resolution_unavailable'), new Error('private-fixture-contact-and-url')]) {
    const calls = []
    const transport = { async call(endpoint, body) {
      calls.push({ endpoint, body })
      if (endpoint === 'print-order-request-resolve') throw failure
      return endpoint === 'print-fulfillment-worker' ? { enabled: false, claim: null } : { enabled: false }
    } }
    const result = await workerTick({ transport, workerId, renderer: () => assert.fail('disabled renderer called') })
    assert.deepEqual(calls.map(call => call.endpoint), ['print-payment-reconcile', 'print-order-request-resolve', 'print-fulfillment-worker'])
    assert.deepEqual(calls[1].body, { action: 'tick', limit: 1 })
    assert.equal(result.requestResolution.errorCode, failure.code ?? 'print_worker_unavailable')
    assert.equal(result.requestResolution.completed, 0)
    assert.doesNotMatch(JSON.stringify(result), /private-fixture-contact-and-url/)
  }
})

test('setup option mistakes and conflicting modes never enter the daemon or a queue claim', () => {
  assert.equal(checkedWorkerOptions([]).mode, 'daemon')
  assert.equal(checkedWorkerOptions(['--once']).mode, 'once')
  assert.equal(checkedWorkerOptions(['--check-auth']).mode, 'check-auth')
  assert.deepEqual(checkedWorkerOptions(['--fixture-artwork', 'standard', '--fixture', '--fixture-scenario', 'HARD_80']),
    { mode: 'fixture', fixtureScenario: 'HARD_80', fixtureArtwork: 'standard' })
  for (const args of [['--chek-auth'], ['--check-auth', '--once'], ['--fixture', '--check-auth'], ['--once', '--once'],
    ['--fixture-scenario', 'HARD_80'], ['--fixture', '--fixture-artwork'], ['--fixture', '--fixture-scenario', '--once'],
    ['--fixture', '--fixture-scenario', 'SOFT_20', '--fixture-scenario', 'HARD_80'], ['--worker-env-path', '/private/secret']]) {
    assert.throws(() => checkedWorkerOptions(args), /print_worker_arguments_invalid/)
  }
})

test('auth setup check verifies the current server role and never contacts a queue, PG or supplier', async () => {
  const calls = []
  const transport = new WorkerTransport({ ...route, email: 'private-fixture@example.invalid', password: 'private-fixture-password', fetcher: async (url, init) => {
    calls.push({ url, method: init.method })
    if (url.endsWith('grant_type=password')) return Response.json(session)
    assert.ok(url.endsWith('/auth/v1/user')); assert.equal(init.headers.Authorization, `Bearer ${session.access_token}`)
    return Response.json({ id: workerId, email: 'private-fixture@example.invalid', app_metadata: { role: 'print_worker' }, user_metadata: { private: 'private-fixture-contact' } })
  } })
  const result = await transport.checkAuthentication()
  assert.deepEqual(result, { authenticated: true, currentAccountRole: 'print_worker', providerRequests: 0, orderClaims: 0, productionReadinessChecked: false })
  assert.equal(calls.length, 2); assert.equal(calls.at(-1).method, 'GET')
  assert.doesNotMatch(JSON.stringify(result), /private-fixture|rotated-fixture|11111111/)
})

test('an encoded admin JWT claim never substitutes for the current server worker role', async () => {
  const fakeJwt = `header.${Buffer.from(JSON.stringify({ app_metadata: { role: 'admin' } })).toString('base64url')}.signature`
  const transport = new WorkerTransport({ ...route, jwt: fakeJwt, fetcher: async () => Response.json({ id: workerId,
    app_metadata: { role: 'customer' }, user_metadata: { role: 'print_worker' } }) })
  await assert.rejects(transport.checkAuthentication(), /print_worker_role_required/)
})

test('auth setup check refreshes one expired session and observes the same authenticated account endpoint once more', async () => {
  const calls = []
  const transport = new WorkerTransport({ ...route, jwt: 'expired-fixture', refreshToken: 'old-fixture-refresh', fetcher: async (url, init) => {
    calls.push({ url, auth: init.headers.Authorization })
    if (url.endsWith('grant_type=refresh_token')) return Response.json(session)
    return init.headers.Authorization === 'Bearer expired-fixture' ? Response.json({}, { status: 401 }) :
      Response.json({ id: workerId, app_metadata: { role: 'print_worker' } })
  } })
  assert.equal((await transport.checkAuthentication()).authenticated, true)
  assert.equal(calls.length, 3)
  assert.deepEqual(calls.filter(value => value.url.endsWith('/auth/v1/user')).map(value => value.auth),
    ['Bearer expired-fixture', 'Bearer rotated-fixture-access'])
})

test('auth setup check reports malformed/unavailable Auth results without private response data', async () => {
  for (const response of [new Response('private-fixture-invalid-json'), Response.json({ id: 'private-fixture-id', app_metadata: { role: 'admin' } }),
    Response.json({ private: 'private-fixture-contact' }, { status: 503 })]) {
    const transport = new WorkerTransport({ ...route, jwt: 'valid-local-fixture', fetcher: async () => response })
    await assert.rejects(transport.checkAuthentication(), { code: 'print_worker_authentication_required' })
  }
})

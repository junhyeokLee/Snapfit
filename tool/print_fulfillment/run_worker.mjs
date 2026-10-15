import { mkdtemp, readFile, writeFile, rm, chmod } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'
import { randomUUID } from 'node:crypto'

const project = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const delay = ms => new Promise(resolveDelay => setTimeout(resolveDelay, ms))
const codeError = code => Object.assign(new Error(code), { code })
const safe = error => /^[a-z0-9_]{1,80}$/.test(error?.code ?? '') ? error.code : 'print_worker_unavailable'

export function checkedFixtureScenario(value = 'SOFT_20') {
  if (!['SOFT_20', 'HARD_80'].includes(value)) throw codeError('print_fixture_scenario_invalid')
  return value
}
export function checkedFixtureArtwork(value = 'standard') {
  if (!['standard', 'compact'].includes(value)) throw codeError('print_fixture_artwork_invalid')
  return value
}

/** A typo in a setup check must never fall through to the live worker loop. */
export function checkedWorkerOptions(args) {
  if (!Array.isArray(args)) throw codeError('print_worker_arguments_invalid')
  const result = { mode: 'daemon', fixtureScenario: 'SOFT_20', fixtureArtwork: null }
  const modes = { '--check-auth': 'check-auth', '--once': 'once', '--fixture': 'fixture' }
  const values = { '--fixture-scenario': 'fixtureScenario', '--fixture-artwork': 'fixtureArtwork' }
  const seen = new Set()
  let modeSelected = false
  for (let index = 0; index < args.length; index++) {
    const flag = args[index]
    if (typeof flag !== 'string' || seen.has(flag)) throw codeError('print_worker_arguments_invalid')
    seen.add(flag)
    if (Object.hasOwn(modes, flag)) {
      if (modeSelected) throw codeError('print_worker_arguments_invalid')
      modeSelected = true; result.mode = modes[flag]
    } else if (Object.hasOwn(values, flag)) {
      const value = args[++index]
      if (typeof value !== 'string' || !value || value.startsWith('--')) throw codeError('print_worker_arguments_invalid')
      result[values[flag]] = value
    } else throw codeError('print_worker_arguments_invalid')
  }
  if ((seen.has('--fixture-scenario') || seen.has('--fixture-artwork')) && result.mode !== 'fixture') throw codeError('print_worker_arguments_invalid')
  result.fixtureScenario = checkedFixtureScenario(result.fixtureScenario)
  result.fixtureArtwork = checkedFixtureArtwork(result.fixtureArtwork ?? (result.fixtureScenario === 'HARD_80' ? 'compact' : 'standard'))
  return result
}

export function rendererEnvironment(environment, input, output, fixture = false, fixtureScenario = 'SOFT_20', fixtureArtwork = null) {
  // Child artwork rendering cannot inspect account/payment/worker credentials.
  const allowed = ['PATH', 'HOME', 'USER', 'LANG', 'LC_ALL', 'TMPDIR', 'FLUTTER_ROOT', 'PUB_CACHE']
  const result = Object.fromEntries(allowed.filter(key => environment[key]).map(key => [key, environment[key]]))
  return { ...result, FLUTTER_SUPPRESS_ANALYTICS: 'true', SNAPFIT_RENDER_INPUT: input, SNAPFIT_RENDER_OUTPUT: output, ...(fixture ? {
    SNAPFIT_WORKER_FIXTURE: 'true', SNAPFIT_WORKER_FIXTURE_SCENARIO: checkedFixtureScenario(fixtureScenario),
    SNAPFIT_WORKER_FIXTURE_ARTWORK: checkedFixtureArtwork(fixtureArtwork ?? (fixtureScenario === 'HARD_80' ? 'compact' : 'standard')),
  } : {}) }
}

/** Finish termination before temporary artwork is removed or another render starts. */
export function runRendererProcess(command, args, { cwd = project, env, signal, timeoutMs = 15 * 60_000,
  killGraceMs = 5_000, spawnProcess = spawn, platform = process.platform, signalGroup = process.kill } = {}) {
  return new Promise((accept, reject) => {
    const grouped = platform !== 'win32'
    let child, timeout, force, stopping = null, spawnFailed = false
    const send = value => {
      if (!child?.pid) return
      try { grouped ? signalGroup(-child.pid, value) : child.kill(value) } catch { /* Already stopped. */ }
    }
    const stop = code => {
      if (stopping) return
      stopping = code; clearTimeout(timeout)
      send('SIGTERM')
      force = setTimeout(() => send('SIGKILL'), killGraceMs)
    }
    const cancel = () => stop('print_worker_interrupted')
    try {
      child = spawnProcess(command, args, { cwd, env, detached: grouped, stdio: ['ignore', 'pipe', 'pipe'] })
    } catch { reject(codeError('print_renderer_failed')); return }
    // Flutter errors may contain private paths/URLs. Never forward their output.
    child.stdout?.on('data', () => {})
    child.stderr?.on('data', () => {})
    child.on('error', () => { spawnFailed = true; stop('print_renderer_failed') })
    child.on('close', code => {
      // A parent can close while a detached descendant remains alive. Send the
      // final group kill before clearing escalation and releasing temp files.
      if (stopping || spawnFailed || code !== 0) send('SIGKILL')
      clearTimeout(timeout); clearTimeout(force); signal?.removeEventListener('abort', cancel)
      if (stopping || spawnFailed || code !== 0) reject(codeError(stopping ?? 'print_renderer_failed'))
      else accept()
    })
    timeout = setTimeout(() => stop('print_renderer_failed'), timeoutMs)
    signal?.addEventListener('abort', cancel, { once: true })
    if (signal?.aborted) cancel()
  })
}

export async function renderPaidAlbum(input, { flutterBin, fixture = false, fixtureScenario = 'SOFT_20', fixtureArtwork = null, signal, preserveDirectory = null,
  processRunner = runRendererProcess } = {}) {
  const directory = preserveDirectory ?? await mkdtemp(join(tmpdir(), 'snapfit-print-'))
  await chmod(directory, 0o700)
  const inputPath = join(directory, 'input.json')
  if (!fixture) await writeFile(inputPath, JSON.stringify(input), { mode: 0o600 })
  try {
    await processRunner(flutterBin ?? process.env.SNAPFIT_FLUTTER_BIN ?? 'flutter',
        ['--no-version-check', 'test', 'tool/print_fulfillment/render_paid_album_test.dart', '--no-pub', '--reporter', 'compact'], {
          cwd: project, env: rendererEnvironment(process.env, inputPath, directory, fixture, fixtureScenario, fixtureArtwork), signal,
        })
    const cover = await readFile(join(directory, 'cover.pdf')), interior = await readFile(join(directory, 'interior.pdf'))
    const manifest = JSON.parse(await readFile(join(directory, 'manifest.json'), 'utf8'))
    if (!cover.length || !interior.length || cover.length > 100 * 1024 * 1024 || interior.length > 100 * 1024 * 1024) throw codeError('print_upload_failed')
    return { cover, interior, manifest, directory }
  } catch (error) {
    if (!preserveDirectory) await rm(directory, { recursive: true, force: true })
    throw error
  }
}

export class WorkerTransport {
  constructor({ url, publishableKey, jwt = '', refreshToken = '', email = '', password = '', fetcher = fetch }) {
    const origin = new URL(url)
    if (origin.protocol !== 'https:' || !/^[a-z0-9]+\.supabase\.co$/.test(origin.hostname) || origin.port || origin.username || origin.password) throw codeError('print_worker_configuration_required')
    if (!publishableKey || !jwt && (!email || !password)) throw codeError('print_worker_configuration_required')
    this.url = origin.origin; this.key = publishableKey; this.jwt = jwt; this.refreshToken = refreshToken; this.fetcher = fetcher
    this.email = email; this.password = password
    this.nextRefresh = Date.now() + 25 * 60_000
    this.authFlight = null
  }
  async authRefresh({ force = false, observedJwt = null } = {}) {
    if (force && observedJwt !== null && this.jwt !== observedJwt) return
    if (this.authFlight) return this.authFlight
    if (this.jwt && !force && (!this.refreshToken || Date.now() < this.nextRefresh)) return
    this.authFlight = this.refreshSession(force).finally(() => { this.authFlight = null })
    return this.authFlight
  }
  saveSession(session) {
    if (typeof session?.access_token !== 'string' || !session.access_token || typeof session?.refresh_token !== 'string' || !session.refresh_token) throw codeError('print_worker_authentication_required')
    this.jwt = session.access_token; this.refreshToken = session.refresh_token
    const expiresIn = Number(session.expires_in)
    this.nextRefresh = Date.now() + (Number.isFinite(expiresIn) && expiresIn > 0 ? Math.min(25 * 60_000, Math.max(0, expiresIn * 1000 - 60_000)) : 25 * 60_000)
  }
  async refreshSession(force = false) {
    if (!this.jwt || !this.refreshToken) {
      if (force || !this.jwt) await this.passwordLogin()
      return
    }
    const result = await this.fetcher(`${this.url}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15_000),
      headers: { apikey: this.key, 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: this.refreshToken }),
    })
    if (!result.ok) {
      if (this.email && this.password) { await this.passwordLogin(); return }
      throw codeError('print_worker_authentication_required')
    }
    this.saveSession(await result.json())
  }
  async passwordLogin() {
    if (!this.email || !this.password) throw codeError('print_worker_authentication_required')
    const result = await this.fetcher(`${this.url}/auth/v1/token?grant_type=password`, {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15_000), headers: { apikey: this.key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: this.email, password: this.password }),
    })
    if (!result.ok) throw codeError('print_worker_authentication_required')
    this.saveSession(await result.json())
  }
  /** Current server Auth only; no queue claim, heartbeat mutation, PG or vendor. */
  async checkAuthentication() {
    await this.authRefresh()
    const request = () => this.fetcher(`${this.url}/auth/v1/user`, {
      method: 'GET', redirect: 'error', signal: AbortSignal.timeout(15_000),
      headers: { apikey: this.key, Authorization: `Bearer ${this.jwt}` },
    })
    const observedJwt = this.jwt
    let response = await request()
    if (response.status === 401) {
      await this.authRefresh({ force: true, observedJwt }); response = await request()
    }
    if (!response.ok) throw codeError('print_worker_authentication_required')
    let user
    try { user = await response.json() } catch { throw codeError('print_worker_authentication_required') }
    if (typeof user?.id !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(user.id)) throw codeError('print_worker_authentication_required')
    const role = user.app_metadata?.role
    if (!['admin', 'print_worker'].includes(role)) throw codeError('print_worker_role_required')
    // Deliberately omit user IDs, contacts, tokens, provider readiness and files.
    return { authenticated: true, currentAccountRole: role, providerRequests: 0,
      orderClaims: 0, productionReadinessChecked: false }
  }
  async call(endpoint, body) {
    if (!['print-payment-reconcile', 'print-order-request-resolve', 'print-fulfillment-worker'].includes(endpoint)) throw codeError('print_worker_endpoint_invalid')
    await this.authRefresh()
    const serialized = JSON.stringify(body)
    const request = () => this.fetcher(`${this.url}/functions/v1/${endpoint}`, { method: 'POST', redirect: 'error',
      signal: AbortSignal.timeout(body.action === 'finalized' ? 120_000 : 60_000),
      headers: { apikey: this.key, Authorization: `Bearer ${this.jwt}`, 'Content-Type': 'application/json' }, body: serialized })
    const observedJwt = this.jwt
    let response = await request()
    if (response.status === 401) {
      await this.authRefresh({ force: true, observedJwt }); response = await request()
    }
    let result
    try { result = await response.json() } catch { throw codeError('print_worker_response_invalid') }
    if (!response.ok) throw codeError(/^[a-z0-9_]{1,80}$/.test(result?.error ?? '') ? result.error : 'print_worker_unavailable')
    return result
  }
  async upload(target, bytes) {
    const url = new URL(target.signedUrl)
    if (url.origin !== this.url || !url.pathname.startsWith('/storage/v1/object/upload/sign/print-packages/') || !url.searchParams.get('token')) throw codeError('print_upload_failed')
    await this.authRefresh()
    const request = () => this.fetcher(url, { method: 'PUT', redirect: 'error', signal: AbortSignal.timeout(120_000),
      headers: { apikey: this.key, Authorization: `Bearer ${this.jwt}`, 'Content-Type': 'application/pdf', 'x-upsert': 'false' }, body: bytes })
    const observedJwt = this.jwt
    let response = await request()
    if (response.status === 401) {
      await this.authRefresh({ force: true, observedJwt }); response = await request()
    }
    if (!response.ok) throw codeError('print_upload_failed')
  }
}

/** One claimed order at a time. Network retries recover the same durable ID. */
export async function workerTick({ transport, workerId, renderer = renderPaidAlbum, onHeartbeat = null }) {
  await transport.call('print-payment-reconcile', { limit: 3 })
  let requestResolution
  try {
    const result = await transport.call('print-order-request-resolve', { action: 'tick', limit: 1 })
    const count = key => Number.isSafeInteger(result?.[key]) && result[key] >= 0 && result[key] <= 3 ? result[key] : 0
    requestResolution = { enabled: result?.enabled === true, processed: count('processed'), waiting: count('waiting'),
      completed: count('completed'), reviewRequired: count('reviewRequired') }
  } catch (error) {
    // Database cancellation holds guard claims independently. Continue that
    // guarded cycle, while retaining a fixed error code in the host log.
    requestResolution = { enabled: false, processed: 0, waiting: 0, completed: 0, reviewRequired: 0, errorCode: safe(error) }
  }
  const result = await transport.call('print-fulfillment-worker', { action: 'claim', workerId })
  if (!result.claim) return { enabled: result.enabled, processed: 0, requestResolution }
  const { job } = result.claim
  let rendered, renewal, periodicReconcile, heartbeatBusy = false, reconciliationBusy = false, lost = null
  const abort = new AbortController(), args = { jobId: job.id, workerId }
  try {
    if (job.event_type === 'RENDER') {
      renewal = setInterval(async () => {
        if (heartbeatBusy) return
        heartbeatBusy = true
        try { await transport.call('print-fulfillment-worker', { action: 'renew', ...args }); onHeartbeat?.() }
        catch (error) { lost = error; abort.abort() }
        finally { heartbeatBusy = false }
      }, 30_000)
      periodicReconcile = setInterval(async () => {
        if (reconciliationBusy) return
        reconciliationBusy = true
        try { await transport.call('print-payment-reconcile', { limit: 3 }) } catch { /* Subsequent tick recovers it. */ }
        finally { reconciliationBusy = false }
      }, 60_000)
      const snapshot = await transport.call('print-fulfillment-worker', { action: 'snapshot', ...args })
      rendered = await renderer({ ...snapshot, supabaseOrigin: transport.url }, { signal: abort.signal })
      if (lost) throw lost
      // Recheck the active lease immediately before issuing immutable upload URLs.
      await transport.call('print-fulfillment-worker', { action: 'renew', ...args })
      const uploads = await transport.call('print-fulfillment-worker', { action: 'uploads', ...args })
      if (uploads.sourceFingerprint !== snapshot.sourceFingerprint || uploads.spec.specVersion !== snapshot.spec.specVersion) throw codeError('print_upload_failed')
      await transport.upload(uploads.cover, rendered.cover)
      await transport.upload(uploads.interior, rendered.interior)
      if (lost) throw lost
      const saved = await transport.call('print-fulfillment-worker', { action: 'finalized', ...args,
        uploadId: uploads.uploadId, manifest: { ...rendered.manifest, sourceFingerprint: snapshot.sourceFingerprint } })
      return { enabled: true, processed: 1, stage: saved.stage, state: saved.state, requestResolution }
    }
    const saved = await transport.call('print-fulfillment-worker', { action: 'advance', ...args })
    return { enabled: true, processed: 1, stage: saved.stage, state: saved.state, requestResolution }
  } catch (error) {
    // advance() already stores supplier uncertainty. Never replace its stable
    // supplier number or transform an uncertain deposit into a fresh request.
    if (job.event_type === 'RENDER') {
      try { await transport.call('print-fulfillment-worker', { action: 'fail', ...args,
        errorCode: ['print_renderer_failed','print_upload_failed'].includes(safe(error)) ? safe(error) : 'print_worker_interrupted' }) } catch { /* Lease recovery owns the next attempt. */ }
    }
    throw error
  } finally {
    clearInterval(renewal); clearInterval(periodicReconcile)
    if (rendered?.directory) await rm(rendered.directory, { recursive: true, force: true })
  }
}

async function main() {
  const options = checkedWorkerOptions(process.argv.slice(2))
  if (options.mode === 'fixture') {
    const scenario = options.fixtureScenario, artwork = options.fixtureArtwork
    const directory = await mkdtemp(join(tmpdir(), 'snapfit-print-fixture-'))
    const started = Date.now()
    const rendered = await renderPaidAlbum(null, { fixture: true, fixtureScenario: scenario, fixtureArtwork: artwork, preserveDirectory: directory })
    // Contains synthetic artwork only; these PDFs are evidence for local tests.
    process.stdout.write(JSON.stringify({ fixtureOnly: true, scenario, artworkProfile: artwork, outputDirectory: directory,
      elapsedMs: Date.now() - started, coverBytes: rendered.cover.length, interiorBytes: rendered.interior.length,
      supplierCalls: 0, productionApproved: false }) + '\n')
    return
  }
  const transport = new WorkerTransport({ url: process.env.SNAPFIT_SUPABASE_URL ?? '',
    publishableKey: process.env.SNAPFIT_SUPABASE_PUBLISHABLE_KEY, jwt: process.env.SNAPFIT_PRINT_WORKER_JWT,
    refreshToken: process.env.SNAPFIT_PRINT_WORKER_REFRESH_TOKEN, email: process.env.SNAPFIT_PRINT_WORKER_EMAIL,
    password: process.env.SNAPFIT_PRINT_WORKER_PASSWORD })
  const workerId = randomUUID()
  if (options.mode === 'check-auth') {
    process.stdout.write(JSON.stringify(await transport.checkAuthentication()) + '\n')
    return
  }
  do {
    try { process.stdout.write(JSON.stringify(await workerTick({ transport, workerId })) + '\n') }
    catch (error) { process.stderr.write(JSON.stringify({ error: safe(error) }) + '\n') }
    if (options.mode === 'once') break
    await delay(60_000)
  } while (true)
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => { process.stderr.write(JSON.stringify({ error: safe(error) }) + '\n'); process.exitCode = 1 })
}

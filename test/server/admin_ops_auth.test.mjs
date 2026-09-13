import assert from 'node:assert/strict'
import { createHmac } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'
import { OrderPaymentError } from '../../supabase/functions/_shared/order-types.ts'

// Local JWT fixtures only. Signature verification belongs to Supabase Auth;
// these tests exercise the production endpoint's use of auth.getUser(), never
// grant authority to decoded client claims, and make no remote requests.
function jwt(claims, key = 'local-auth-fixture-only') {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url')
  const unsigned = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({
    aud: 'authenticated', role: 'authenticated', sub: 'admin-fixture-user',
    exp: Math.floor(Date.now() / 1000) + 600, ...claims,
  })}`
  return `${unsigned}.${createHmac('sha256', key).update(unsigned).digest('base64url')}`
}

function endpoint({ authResult, env = {}, legacyKey = '' } = {}) {
  let serve
  const record = { adminClientCalls: 0, authCalls: [], clientOptions: [] }
  const environment = {
    SUPABASE_URL: 'https://auth-fixture.supabase.co',
    SUPABASE_ANON_KEY: 'local-publishable-fixture',
    SNAPFIT_ADMIN_KEY: legacyKey,
    ...env,
  }
  const sourceFile = readFileSync(new URL('../../supabase/functions/admin-ops/index.ts', import.meta.url), 'utf8')
  const sdkImport = "await import('https://esm.sh/@supabase/supabase-js@2')"
  assert.ok(sourceFile.includes(sdkImport), 'update the test SDK import seam if the production dependency changes')
  // Inject only the external SDK module, not getOptionalJwtUser or assertAdmin.
  // All authorization branches and HTTP status handling remain production code.
  const source = stripTypeScriptTypes(sourceFile.replace(/^import .*$/gm, '')
    .replace(sdkImport, 'await Promise.resolve({ createClient: fixtureCreateClient })'))
  vm.runInNewContext(source, {
    Deno: { serve: handler => { serve = handler }, env: { get: key => environment[key] } },
    fixtureCreateClient(url, key, options) {
      assert.equal(url, environment.SUPABASE_URL)
      assert.equal(key, environment.SUPABASE_ANON_KEY)
      assert.equal(options.auth.persistSession, false)
      record.clientOptions.push(options)
      return { auth: { async getUser(...args) {
        assert.equal(args.length, 0)
        const authorization = options.global.headers.Authorization
        record.authCalls.push(authorization)
        return typeof authResult === 'function' ? authResult(authorization) : authResult
      } } }
    },
    adminClient() { record.adminClientCalls++; return {} },
    adminIdentifier: value => String(value),
    loadOrder: async (_client, id) => ({ order_id: id, status: 'PAYMENT_COMPLETED', amount: 49900 }),
    withPrintOperations: async (_client, row) => row,
    Response, OrderPaymentError,
    console: { error() {} }, corsHeaders: {},
    jsonResponse: (body, status = 200) => Response.json(body, { status }),
  })
  return {
    record,
    request: ({ token, body = { action: 'getOrder', orderId: 'SF-1' }, headers = {} } = {}) => serve(new Request('https://admin-fixture.test', {
      method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
      body: JSON.stringify(body),
    })),
  }
}

test('verified Auth user app_metadata admin is accepted via Bearer without an admin key', async () => {
  const token = jwt({ email: 'admin@snapfit.app', app_metadata: { role: 'admin' } })
  const run = endpoint({ authResult: authorization => {
    assert.equal(authorization, `Bearer ${token}`)
    return { data: { user: { id: 'admin-fixture-user', email: 'admin@snapfit.app', app_metadata: { role: 'admin' } } }, error: null }
  } })
  const response = await run.request({ token })
  assert.equal(response.status, 200)
  assert.equal((await response.json()).orderId, 'SF-1')
  assert.deepEqual(run.record.authCalls, [`Bearer ${token}`])
  assert.equal(run.record.adminClientCalls, 1)
})

test('ordinary users, matching email and user-editable metadata never authorize admin actions', async () => {
  const identities = [
    { id: 'ordinary', email: 'user@example.test', app_metadata: {} },
    { id: 'email-only', email: 'admin@snapfit.app', app_metadata: {} },
    { id: 'self-promoted', email: 'admin@snapfit.app', app_metadata: {}, user_metadata: { role: 'admin', is_admin: true } },
    { id: 'wrong-role', email: 'admin@snapfit.app', app_metadata: { role: 'Admin' }, user_metadata: { role: 'admin' } },
  ]
  const actions = ['dashboard', 'orders', 'getOrder', 'getPrintSnapshot', 'createPrintUploads', 'finalizePrintPackage',
    'getPrintDownloadLinks', 'evaluatePrintCosts', 'configurePrintSpec', 'markPrintReviewed', 'submitPrintVendor',
    'acceptPrintVendor', 'markShipping', 'markDelivered', 'pointProducts', 'updatePointProduct', 'upsertTemplate', 'csSignals']
  for (const user of identities) {
    const run = endpoint({ authResult: { data: { user }, error: null } })
    // Even an admin claim inside the presented token cannot override the
    // authenticated user's current metadata returned by the Auth service.
    const token = jwt({ sub: user.id, app_metadata: { role: 'admin' } })
    for (const action of actions) {
      const response = await run.request({ token, body: { action, email: 'admin@snapfit.app', role: 'admin', app_metadata: { role: 'admin' }, adminKey: 'wrong' } })
      assert.equal(response.status, 403, `${user.id}: ${action}`)
      assert.deepEqual(await response.json(), { error: 'forbidden' })
    }
    assert.equal(run.record.adminClientCalls, 0)
    assert.equal(run.record.authCalls.length, actions.length)
  }
})

test('removing the current admin role denies an already-issued token on the next request', async () => {
  const token = jwt({ app_metadata: { role: 'admin' } })
  let role = 'admin'
  const run = endpoint({ authResult: () => ({ data: { user: { id: 'admin-fixture-user', app_metadata: { role } } }, error: null }) })
  assert.equal((await run.request({ token })).status, 200)
  role = 'user'
  const rejected = await run.request({ token })
  assert.equal(rejected.status, 403)
  assert.deepEqual(await rejected.json(), { error: 'forbidden' })
  assert.equal(run.record.authCalls.length, 2, 'authorization must consult Auth for each request')
  assert.equal(run.record.adminClientCalls, 1, 'revoked role must not reach privileged database operations')
})

test('expired, invalid and Auth-rejected revoked tokens fail closed before privileged access', async () => {
  for (const code of ['bad_jwt', 'jwt_expired', 'session_not_found', 'user_not_found']) {
    const run = endpoint({ authResult: { data: { user: null }, error: { code, message: 'sensitive Auth details' } } })
    const response = await run.request({ token: code === 'jwt_expired' ? jwt({ exp: 1, app_metadata: { role: 'admin' } }) : `invalid.${code}.signature` })
    assert.equal(response.status, 403, code)
    assert.deepEqual(await response.json(), { error: 'forbidden' })
    assert.equal(run.record.adminClientCalls, 0)
    assert.equal(run.record.authCalls.length, 1)
  }
})

test('missing credentials and missing Auth configuration do not load privileged clients', async () => {
  const run = endpoint({ authResult: () => { throw new Error('must not run Auth without credentials') } })
  assert.equal((await run.request()).status, 403)
  assert.equal((await run.request({ headers: { Authorization: 'Basic ignored' } })).status, 403)
  assert.equal(run.record.authCalls.length, 0)
  assert.equal(run.record.adminClientCalls, 0)
  for (const key of ['SUPABASE_URL', 'SUPABASE_ANON_KEY']) {
    const missing = endpoint({ env: { [key]: undefined } })
    assert.equal((await missing.request({ token: jwt({ app_metadata: { role: 'admin' } }) })).status, 403)
    assert.equal(missing.record.clientOptions.length, 0)
    assert.equal(missing.record.adminClientCalls, 0)
  }
})

test('Auth service failure never falls back to admin claims or exposes its error', async () => {
  const run = endpoint({ authResult: () => { throw new Error('private-auth-transport-details') } })
  const response = await run.request({ token: jwt({ app_metadata: { role: 'admin' } }) })
  assert.equal(response.status, 500)
  assert.deepEqual(await response.json(), { error: 'admin_operation_failed' })
  assert.equal(run.record.adminClientCalls, 0)
})

test('existing configured admin-key path remains independent of JWT login', async () => {
  const run = endpoint({ legacyKey: 'local-legacy-key', authResult: () => { throw new Error('Auth should not run for a valid alternate credential') } })
  const response = await run.request({ body: { action: 'getOrder', orderId: 'SF-1', adminKey: 'local-legacy-key' } })
  assert.equal(response.status, 200)
  assert.equal(run.record.authCalls.length, 0)
  assert.equal(run.record.adminClientCalls, 1)
})

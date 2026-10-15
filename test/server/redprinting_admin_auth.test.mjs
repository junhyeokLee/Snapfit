import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'
import { assertRedprintingAdmin, RedprintingAdminAuthError } from '../../supabase/functions/_shared/redprinting-admin-auth.ts'

// Auth server fixtures, never production keys or signed tokens. The real helper
// must consult the server lookup; encoded claims alone cannot authorize a call.
const token = claims => [Buffer.from(JSON.stringify({ alg: 'ES256', typ: 'JWT' })).toString('base64url'),
  Buffer.from(JSON.stringify(claims)).toString('base64url'), 'local-fixture-signature'].join('.')
const validToken = token({ sub: 'admin-fixture', app_metadata: { role: 'admin' }, exp: 4102444800 })
const forgedToken = token({ sub: 'ordinary-fixture', app_metadata: { role: 'admin' }, exp: 4102444800 })
const expiredToken = token({ sub: 'admin-fixture', app_metadata: { role: 'admin' }, exp: 1 })

function endpoint({ user, legacyKey = '', lookup } = {}) {
  let handler
  const seen = { auth: 0, database: 0, bodyReads: 0, actions: [], sequence: [] }
  class RedprintingError extends Error { constructor(code, status = 409) { super(code); this.code = code; this.status = status; this.uncertain = false } }
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/redprinting-admin/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, {
    Deno: { env: { get: key => ['SNAPFIT_ADMIN_KEY','ORDER_ADMIN_KEY'].includes(key) ? legacyKey : undefined }, serve: fn => { handler = fn } },
    assertRedprintingAdmin, RedprintingAdminAuthError, RedprintingError, OrderPaymentError: class extends Error {}, Response,
    corsHeaders: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' },
    getUser: async req => { seen.auth++; seen.sequence.push('getUser'); return lookup ? lookup(req) : user },
    adminClient: () => { seen.database++; seen.sequence.push('adminClient'); return {} },
    RedprintingAdmin: class { constructor(_db, _env, actor) { this.actor = actor } async action(action, body) { seen.sequence.push('action'); seen.actions.push({ action, body, actor: this.actor }); return { ok: true } } },
  })
  return { seen, call: (body = { action: 'overview' }, headers = { Authorization: `Bearer ${validToken}` }, method = 'POST') => {
    const request = new Request('https://edge-fixture.test', {
      method, headers: { 'Content-Type': 'application/json', ...headers }, ...(method === 'POST' ? { body: JSON.stringify(body) } : {}),
    })
    const parseBody = request.json.bind(request)
    request.json = () => { seen.bodyReads++; seen.sequence.push('json'); return parseBody() }
    return handler(request)
  } }
}

async function denied(run, body, headers, status, code) {
  const response = await run.call(body, headers)
  assert.equal(response.status, status); assert.deepEqual(await response.json(), { error: code })
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), '*')
  assert.equal(run.seen.database, 0); assert.equal(run.seen.actions.length, 0)
  assert.equal(run.seen.bodyReads, 0)
}

test('current server-verified admin authorizes only after getUser, before privileged database access', async () => {
  const run = endpoint({ lookup: async req => {
    assert.equal(req.headers.get('Authorization'), `Bearer ${validToken}`)
    return { id: 'admin-fixture', app_metadata: { role: 'admin' } }
  } })
  assert.equal((await run.call()).status, 200)
  assert.deepEqual(run.seen.sequence, ['getUser','json','adminClient','action']); assert.equal(run.seen.actions[0].actor, 'admin-fixture')
})
test('missing and malformed bearer headers reject before Auth, database, and vendor work', async () => {
  for (const headers of [{}, { Authorization: '' }, { Authorization: 'Basic local-fixture' }, { Authorization: 'Bearer' },
    { Authorization: 'Bearer ' }, { Authorization: 'Bearer token extra' }]) {
    const run = endpoint({ user: { id: 'admin-fixture', app_metadata: { role: 'admin' } } })
    await denied(run, { action: 'submitTest', id: 'one' }, headers, 401, 'authentication_required')
    assert.equal(run.seen.auth, 0)
  }
})
test('invalid and expired sessions reject even when claimed or previously stored roles are admin', async () => {
  for (const rejected of ['not-a-valid-session', expiredToken]) {
    const run = endpoint({ lookup: async req => {
      assert.equal(req.headers.get('Authorization'), `Bearer ${rejected}`)
      throw new Error('Auth server rejected the fixture session')
    } })
    await denied(run, { action: 'overview', app_metadata: { role: 'admin' } }, { Authorization: `Bearer ${rejected}` }, 401, 'invalid_session')
    assert.equal(run.seen.auth, 1)
  }
})
test('null user and absent user identity cannot authorize privileged database work', async () => {
  for (const user of [null, undefined, { id: '', app_metadata: { role: 'admin' } }, { app_metadata: { role: 'admin' } }]) {
    const run = endpoint({ user })
    await denied(run, { action: 'overview' }, { Authorization: `Bearer ${validToken}` }, 401, 'invalid_session')
  }
})
test('ordinary role, edited user metadata, email impersonation, and stale JWT admin claims all reject', async () => {
  for (const user of [
    { id: 'ordinary', app_metadata: {} },
    { id: 'email-only', email: 'admin@snapfit.app', app_metadata: {} },
    { id: 'edited-profile', app_metadata: { role: 'user' }, user_metadata: { role: 'admin', is_admin: true } },
    { id: 'case', app_metadata: { role: 'Admin' } },
  ]) {
    const run = endpoint({ lookup: async req => {
      assert.equal(req.headers.get('Authorization'), `Bearer ${forgedToken}`)
      return user
    } })
    await denied(run, { action: 'submitTest', id: 'one', email: 'admin@snapfit.app', app_metadata: { role: 'admin' } },
      { Authorization: `Bearer ${forgedToken}` }, 403, 'forbidden')
    assert.equal(run.seen.auth, 1)
  }
})
test('matching environment admin key, header key, body key, and public app key never bypass bearer authentication', async () => {
  for (const headers of [{ 'X-Admin-Key': 'local-fixture-admin-key' }, { apikey: 'local-fixture-public-key' },
    { 'X-Admin-Key': 'local-fixture-admin-key', apikey: 'local-fixture-public-key' }]) {
    const run = endpoint({ legacyKey: 'local-fixture-admin-key', user: { id: 'admin-fixture', app_metadata: { role: 'admin' } } })
    await denied(run, { action: 'overview', adminKey: 'local-fixture-admin-key' }, headers, 401, 'authentication_required')
    assert.equal(run.seen.auth, 0)
  }
  const ordinary = endpoint({ legacyKey: 'local-fixture-admin-key', user: { id: 'ordinary', app_metadata: {} } })
  await denied(ordinary, { action: 'overview', adminKey: 'local-fixture-admin-key' },
    { Authorization: `Bearer ${forgedToken}`, 'X-Admin-Key': 'local-fixture-admin-key' }, 403, 'forbidden')
})
test('OPTIONS stays public with CORS and cannot run Auth, database, or vendor work', async () => {
  const run = endpoint()
  const response = await run.call({}, {}, 'OPTIONS')
  assert.equal(response.status, 200); assert.equal(response.headers.get('Access-Control-Allow-Origin'), '*')
  assert.deepEqual(run.seen.sequence, [])
})

test('malformed POST body cannot reach privileged database or vendor client', async () => {
  const run = endpoint({ user: { id: 'admin-fixture', app_metadata: { role: 'admin' } } })
  assert.equal((await run.call([])).status, 400)
  assert.equal(run.seen.database, 0); assert.equal(run.seen.auth, 1); assert.equal(run.seen.bodyReads, 1)
})

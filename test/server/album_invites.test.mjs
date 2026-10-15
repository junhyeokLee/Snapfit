import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import { test } from 'node:test'
import vm from 'node:vm'

function endpoint({ invite, album = { title: '앨범', owner_id: 'owner' }, rpcResult, rpcError, readError, authError } = {}) {
  let handler
  const calls = { auth: 0, rpc: [], writes: [], reads: [] }
  const query = table => {
    calls.reads.push(table)
    const chain = {
      select: () => chain, eq: () => chain,
      maybeSingle: async () => ({ data: table === 'album_invites' ? invite : table === 'albums' ? album : { name: '초대한 사람' }, error: readError }),
      insert: async value => { calls.writes.push(value); return { error: readError } },
    }
    return chain
  }
  const source = stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/album-invites/index.ts', import.meta.url), 'utf8').replace(/^import .*$/gm, ''))
  vm.runInNewContext(source, {
    Deno: { serve: fn => { handler = fn } }, Response, Error, corsHeaders: {}, Date, crypto: globalThis.crypto,
    jsonResponse: (data, status = 200) => new Response(JSON.stringify(data), { status }),
    adminClient: () => ({ from: query, rpc: async (name, args) => { calls.rpc.push({ name, args }); return { data: rpcResult, error: rpcError } } }),
    getUser: async () => { calls.auth++; if (authError) throw new Error('Unauthorized'); return { id: 'verified-user' } },
  })
  return { calls, call: (body, method = 'POST') => handler(new Request('https://edge-fixture.test', {
    method, ...(method === 'POST' ? { body: JSON.stringify(body), headers: { 'Content-Type': 'application/json' } } : {}),
  })) }
}

test('public preview validates token and rejects expired, consumed or deleted albums', async () => {
  const run = endpoint({ invite: { album_id: 7, role: 'VIEWER', created_by: 'owner' } })
  const response = await run.call({ action: 'info', token: 'valid-token' })
  assert.equal(response.status, 200); assert.equal((await response.json()).role, 'VIEWER'); assert.equal(run.calls.auth, 0)
  for (const [invite, status] of [[null, 404], [{ accepted_at: new Date().toISOString() }, 409], [{ expires_at: '2020-01-01' }, 410]]) {
    assert.equal((await endpoint({ invite }).call({ action: 'info', token: 'valid' })).status, status)
  }
  assert.equal((await endpoint({ invite: { album_id: 7 }, album: null }).call({ action: 'info', token: 'valid' })).status, 404)
  for (const token of ['', {}, 'a b', 'a'.repeat(257)]) {
    const bad = endpoint(); assert.equal((await bad.call({ action: 'info', token })).status, 400); assert.equal(bad.calls.reads.length, 0)
  }
})

test('accept uses validated Auth identity, not a body userId, and one transactional RPC', async () => {
  const run = endpoint({ rpcResult: { albumId: 7, role: 'EDITOR', success: true } })
  assert.equal((await run.call({ action: 'accept', token: 'valid', userId: 'forged-user' })).status, 200)
  assert.deepEqual(JSON.parse(JSON.stringify(run.calls.rpc)), [{ name: 'accept_album_invite', args: { p_token: 'valid', p_user_id: 'verified-user' } }])
  assert.equal(run.calls.auth, 1); assert.equal(run.calls.writes.length, 0)
  const denied = endpoint({ authError: true })
  assert.equal((await denied.call({ action: 'accept', token: 'valid' })).status, 401); assert.equal(denied.calls.rpc.length, 0)
})

test('RPC errors and malformed success never pretend participation succeeded or leak secrets', async () => {
  for (const input of [{ rpcError: { message: 'secret internal details' } }, { rpcResult: null }, { rpcResult: { success: false } }]) {
    const response = await endpoint(input).call({ action: 'accept', token: 'valid' })
    assert.equal(response.status, 500); assert.deepEqual(await response.json(), { error: 'invite_unavailable' })
  }
  const response = await endpoint({ rpcResult: { error: 'invite_used', status: 409 } }).call({ action: 'accept', token: 'valid' })
  assert.equal(response.status, 409); assert.deepEqual(await response.json(), { error: 'invite_used' })
})

test('create remains owner-only and bad request shapes never reach writes', async () => {
  const run = endpoint()
  assert.equal((await run.call({ action: 'create', albumId: 7, role: 'VIEWER' })).status, 403)
  assert.equal(run.calls.writes.length, 0)
  const owned = endpoint({ album: { owner_id: 'verified-user' } })
  const created = await owned.call({ action: 'create', albumId: 7, role: 'VIEWER' })
  assert.equal(created.status, 200)
  const issued = await created.json()
  assert.match(issued.token, /^[a-f0-9]{48}$/)
  assert.equal(issued.link, `snapfit://invite?token=${issued.token}`)
  assert.equal(owned.calls.writes[0].role, 'VIEWER')
  for (const body of [null, [], { action: 'create', albumId: 7.5 }, { action: 'create', albumId: 7, role: 'OWNER' }, { action: 'other' }]) {
    const bad = endpoint(); assert.equal((await bad.call(body)).status, 400); assert.equal(bad.calls.writes.length, 0)
  }
  assert.equal((await run.call({}, 'GET')).status, 405)
  assert.equal((await run.call({}, 'OPTIONS')).status, 200)
})

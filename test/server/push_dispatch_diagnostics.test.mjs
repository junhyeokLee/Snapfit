import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createPushDispatchHandler } from '../../supabase/functions/push-dispatch/handler.ts';
import { googleAccessToken, parseServiceAccount } from '../../supabase/functions/push-dispatch/google-auth.ts';

const secret = 'worker-secret-only-for-tests-1234567890';
const privateMarker = 'must-never-appear-in-diagnostics';
const account = { project_id: 'test-project', client_email: 'service@example.invalid', private_key: privateMarker };
const request = () => new Request('https://example.invalid/push-dispatch', {
  method: 'POST', headers: { 'X-Push-Secret': secret },
});
function fixture({ raw = JSON.stringify(account), rpcErrorAt, error, getAccessToken, adminError } = {}) {
  const calls = [], logs = [];
  const env = { PUSH_DISPATCH_SECRET: secret, PUSH_DELIVERY_ENABLED: 'true', FIREBASE_SERVICE_ACCOUNT_JSON: raw };
  const handler = createPushDispatchHandler({
    env: (name) => env[name],
    getAccessToken: getAccessToken ?? (async () => 'test-oauth-token'),
    adminClient: () => {
      if (adminError) throw adminError;
      return {
        rpc: async (name) => {
          calls.push(name);
          return name === rpcErrorAt ? { error } : { data: name === 'claim_push_deliveries' ? [] : 0, error: null };
        },
        from: () => { throw new Error('empty queue must not send or query any recipient'); },
      };
    },
    logError: (event) => logs.push(event),
  });
  return { handler, calls, logs };
}

test('empty outbox completes cleanup and claim successfully without recipient access', async () => {
  const { handler, calls, logs } = fixture();
  const response = await handler(request());
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, sent: 0, discarded: 0, retry: 0, failed: 0 });
  assert.deepEqual(calls, ['cleanup_notifications', 'claim_push_deliveries']);
  assert.deepEqual(logs, []);
});

test('startup failures expose only their stage and safe database codes, never raw messages', async () => {
  const cases = [
    [{ raw: `{${privateMarker}` }, { stage: 'credential_parse', code: 'invalid_json' }],
    [{ raw: JSON.stringify({ private_key: privateMarker }) }, { stage: 'credential_parse', code: 'credentials_incomplete' }],
    [{ getAccessToken: async () => { throw new Error(privateMarker); } }, { stage: 'oauth', code: 'operation_failed' }],
    [{ adminError: new Error(privateMarker) }, { stage: 'admin_client', code: 'operation_failed' }],
    [{ rpcErrorAt: 'cleanup_notifications', error: { code: '42501', message: privateMarker, details: privateMarker } },
      { stage: 'cleanup', code: 'operation_failed', database_code: '42501' }],
    [{ rpcErrorAt: 'claim_push_deliveries', error: { code: 'PGRST202', message: privateMarker } },
      { stage: 'claim', code: 'operation_failed', database_code: 'PGRST202' }],
    [{ rpcErrorAt: 'claim_push_deliveries', error: { code: privateMarker, message: privateMarker } },
      { stage: 'claim', code: 'operation_failed' }],
  ];
  for (const [options, expected] of cases) {
    const { handler, logs } = fixture(options);
    const response = await handler(request());
    assert.equal(response.status, 500);
    const body = await response.json();
    assert.deepEqual(body, { error: 'push_dispatch_failed', ...expected });
    assert.deepEqual(logs, [{ event: 'push_dispatch_failed', ...expected }]);
    assert.ok(!JSON.stringify([body, logs]).includes(privateMarker));
    assert.ok(!JSON.stringify([body, logs]).includes(secret));
  }
});

test('env JSON wrapping and literal PEM newline escapes are normalized once', () => {
  const key = '-----BEGIN PRIVATE KEY-----\nZmFrZQ==\n-----END PRIVATE KEY-----';
  const expected = { ...account, private_key: key };
  assert.deepEqual(parseServiceAccount(JSON.stringify(expected)), expected);
  assert.deepEqual(parseServiceAccount(JSON.stringify(JSON.stringify(expected))), expected);
  assert.deepEqual(parseServiceAccount(JSON.stringify({ ...account, private_key: key.replaceAll('\n', '\\n') })), expected);
  for (const raw of ['null', '[]', '3', JSON.stringify({ ...account, private_key: 42 })]) {
    assert.throws(() => parseServiceAccount(raw), { stage: 'credential_parse', code: 'credentials_incomplete' });
  }
});

test('invalid PEM and OAuth failures report specific safe stages without provider payloads', async () => {
  await assert.rejects(googleAccessToken(account), { stage: 'credential_import_key', code: 'invalid_private_key' });
  const keyPair = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const pem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(await crypto.subtle.exportKey('pkcs8', keyPair.privateKey)).toString('base64')}\n-----END PRIVATE KEY-----`;
  const valid = { ...account, private_key: pem };
  const originalFetch = globalThis.fetch;
  try {
    const cases = [
      [async () => Response.json({ error_description: privateMarker }, { status: 401 }),
        { stage: 'oauth', code: 'request_rejected', httpStatus: 401 }],
      [async () => new Response(privateMarker), { stage: 'oauth', code: 'invalid_response' }],
      [async () => Response.json({ error: privateMarker }), { stage: 'oauth', code: 'access_token_missing' }],
      [async () => { throw new Error(privateMarker); }, { stage: 'oauth', code: 'request_failed' }],
    ];
    for (const [fetchMock, expected] of cases) {
      globalThis.fetch = fetchMock;
      await assert.rejects(googleAccessToken(valid), (error) => {
        for (const [field, value] of Object.entries(expected)) assert.equal(error[field], value);
        assert.ok(!error.message.includes(privateMarker));
        return true;
      });
    }
  } finally { globalThis.fetch = originalFetch; }
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { deliveryPolicy, fcmMessage, retryDelaySeconds, isInvalidToken, authorizedSecret } from '../../supabase/functions/push-dispatch/policy.ts';
import { googleAccessToken } from '../../supabase/functions/push-dispatch/google-auth.ts';

test('server quiet hours use each device offset and expire delayed messages before 22:00', () => {
  const prefs = { night_mute: true };
  assert.equal(deliveryPolicy('order', prefs, 540, new Date('2026-09-08T13:00:00Z')).allowed, false);
  assert.equal(deliveryPolicy('order', prefs, 540, new Date('2026-09-08T23:00:00Z')).allowed, true);
  assert.equal(deliveryPolicy('order', prefs, -240, new Date('2026-09-08T13:00:00Z')).allowed, true);
  assert.equal(deliveryPolicy('order', prefs, 540, new Date('2026-09-08T12:59:30Z')).ttlSeconds, 30);
  assert.equal(deliveryPolicy('order', { all_enabled: false }, 0, new Date()).allowed, false);
  assert.equal(deliveryPolicy('order', { order_enabled: false }, 0, new Date()).allowed, false);
  assert.equal(deliveryPolicy('marketing', null, 0, new Date()).allowed, false);
  assert.equal(deliveryPolicy('new_template', null, 0, new Date()).allowed, true);
});
test('FCM sends only exact device token and cannot overwrite recipient with payload data', () => {
  const now = new Date('2026-09-08T12:59:30Z');
  const { message } = fcmMessage({ id: 10, user_id: 'owner', type: 'order_status', category: 'order',
    title: 'Order', body: 'Shipped', data: { userId: 'attacker', notificationId: '999', orderId: 'ord_1' },
    deeplink: 'snapfit://order/detail?orderId=ord_1' }, 'recipient-device', now, 30);
  assert.equal(message.token, 'recipient-device'); assert.equal(message.topic, undefined);
  assert.equal(message.data.userId, 'owner'); assert.equal(message.data.notificationId, '10');
  assert.equal(message.android.ttl, '30s');
  assert.equal(message.apns.headers['apns-expiration'], String(now.getTime() / 1000 + 30));
  assert.equal(message.android.notification.tag, 'notification-10');
});
test('only explicit UNREGISTERED disables a token; transient errors keep retrying with a cap', () => {
  assert.equal(isInvalidToken({ error: { details: [{ errorCode: 'UNREGISTERED' }] } }), true);
  assert.equal(isInvalidToken({ error: { details: [{ errorCode: 'UNAVAILABLE' }] } }), false);
  assert.equal(retryDelaySeconds(1), 30); assert.equal(retryDelaySeconds(10), 3600);
  assert.equal(authorizedSecret('a'.repeat(32), 'a'.repeat(32)), true);
  assert.equal(authorizedSecret('', ''), false); assert.equal(authorizedSecret('a'.repeat(32), 'b'.repeat(32)), false);
});
test('Google credentials use signed RS256 OAuth assertion with fixed trusted audience', async () => {
  const keyPair = await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
  const pem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(await crypto.subtle.exportKey('pkcs8', keyPair.privateKey)).toString('base64')}\n-----END PRIVATE KEY-----`;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    assert.equal(url, 'https://oauth2.googleapis.com/token');
    const assertion = options.body.get('assertion');
    const [header, claims, signature] = assertion.split('.');
    const payload = JSON.parse(Buffer.from(claims, 'base64url'));
    assert.equal(payload.aud, url); assert.equal(payload.scope, 'https://www.googleapis.com/auth/firebase.messaging');
    assert.equal(payload.exp - payload.iat, 3600);
    assert.equal(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', keyPair.publicKey,
      Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${header}.${claims}`)), true);
    return Response.json({ access_token: 'test-oauth', expires_in: 3600 });
  };
  try { assert.equal(await googleAccessToken({ project_id: 'test', client_email: 'test@example.invalid', private_key: pem }), 'test-oauth'); }
  finally { globalThis.fetch = originalFetch; }
});

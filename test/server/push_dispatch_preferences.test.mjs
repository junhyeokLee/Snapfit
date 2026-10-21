// Offline handler tests. Every Supabase query and FCM request is a fixture.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createPushDispatchHandler } from '../../supabase/functions/push-dispatch/handler.ts';

const secret = 'offline-dispatch-preferences-test-secret';
const morning = '2026-10-19T23:00:00Z'; // 08:00 KST.

function fixture(t, {
  preferences = null, category = 'order', createdAt = morning, now = morning,
  offset = 540, platform = 'android', enabled = true,
} = {}) {
  t.mock.timers.enable({ apis: ['Date'], now: Date.parse(now) });
  const requests = [], patches = [], queries = [];
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://fcm.googleapis.com/v1/projects/offline-project/messages:send');
    requests.push(JSON.parse(options.body));
    return Response.json({ name: 'offline-message' });
  });
  const notification = { id: 7, user_id: 'offline-owner', type: 'order_status', category,
    title: 'Offline fixture', body: 'Offline fixture', created_at: createdAt };
  const handler = createPushDispatchHandler({
    env: name => ({ PUSH_DISPATCH_SECRET: secret, PUSH_DELIVERY_ENABLED: 'true',
      FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: 'offline-project',
        client_email: 'offline@example.invalid', private_key: 'offline-only' }) })[name],
    getAccessToken: async () => 'offline-access-token',
    logError: () => assert.fail('a controlled preference decision must not fail the worker'),
    adminClient: () => ({
      rpc: async name => ({ data: name === 'claim_push_deliveries'
        ? [{ id: 11, notification_id: 7, user_id: 'offline-owner', token: 'offline-device', attempts: 1, lease_token: 'offline-lease' }]
        : 0, error: null }),
      from: table => {
        const filters = [];
        const query = {
          select() { return query; },
          eq(field, value) { filters.push([field, value]); return query; },
          update(patch) { patches.push(patch); return query; },
          async maybeSingle() {
            queries.push({ table, filters });
            return { data: table === 'notifications' ? notification
              : table === 'push_preferences' ? preferences
                : { enabled, timezone_offset_minutes: offset, platform }, error: null };
          },
          then(resolve, reject) { return Promise.resolve({ error: null }).then(resolve, reject); },
        };
        return query;
      },
    }),
  });
  return {
    requests, patches, queries,
    async run() {
      const response = await handler(new Request('https://offline.invalid/push-dispatch', {
        method: 'POST', headers: { 'X-Push-Secret': secret },
      }));
      assert.equal(response.status, 200);
      return response.json();
    },
  };
}

test('pending deliveries recheck every latest opt-out before contacting FCM', async t => {
  for (const [name, category, preferences] of [
    ['master', 'order', { all_enabled: false }],
    ['order', 'order', { order_enabled: false }],
    ['invite', 'invite', { invite_enabled: false }],
    ['comment', 'comment', { comment_enabled: false }],
    ['new template', 'new_template', { new_template_enabled: false }],
    ['marketing explicit', 'marketing', { marketing_enabled: false }],
    ['marketing default', 'marketing', null],
  ]) {
    await t.test(name, async t => {
      const delivery = fixture(t, { category, preferences });
      assert.deepEqual(await delivery.run(), { ok: true, sent: 0, discarded: 1, retry: 0, failed: 0 });
      assert.equal(delivery.requests.length, 0);
      assert.equal(delivery.patches[0].last_error, 'notification_preferences');
      for (const query of delivery.queries) {
        assert.ok(query.filters.some(([field, value]) => field === 'user_id' && value === 'offline-owner'));
      }
    });
  }
});

test('legacy quiet-hour queue entries stay discarded after a morning worker restart', async t => {
  for (const [name, createdAt] of [
    ['22:00 event', '2026-10-19T13:00:00Z'],
    ['23:00 event', '2026-10-19T14:00:00Z'],
    ['07:59:59 event at the 08:00 worker run', '2026-10-19T22:59:59Z'],
  ]) {
    await t.test(name, async t => {
      const delivery = fixture(t, { preferences: { night_mute: true }, createdAt });
      assert.deepEqual(await delivery.run(), { ok: true, sent: 0, discarded: 1, retry: 0, failed: 0 });
      assert.equal(delivery.requests.length, 0);
      assert.equal(delivery.patches[0].status, 'discarded');
    });
  }
});

test('08:00 events and a currently disabled quiet preference remain deliverable', async t => {
  for (const [name, options] of [
    ['exactly 08:00', { preferences: { night_mute: true } }],
    ['quiet preference turned off', { preferences: { night_mute: false }, createdAt: '2026-10-19T14:00:00Z' }],
    ['the event is daytime in this device timezone', {
      preferences: { night_mute: true }, offset: -240,
      now: '2026-10-20T13:00:00Z', createdAt: '2026-10-19T13:00:00Z',
    }],
  ]) {
    await t.test(name, async t => {
      const delivery = fixture(t, options);
      assert.equal((await delivery.run()).sent, 1);
      assert.equal(delivery.requests.length, 1);
    });
  }
});

test('current quiet hours still suppress a daytime event already in the queue', async t => {
  const delivery = fixture(t, { preferences: { night_mute: true },
    now: '2026-10-19T13:00:00Z', createdAt: '2026-10-19T12:00:00Z' });
  assert.equal((await delivery.run()).discarded, 1);
  assert.equal(delivery.requests.length, 0);
});

test('late-evening native and web messages expire at the quiet-hour boundary', async t => {
  for (const platform of ['android', 'web']) {
    await t.test(platform, async t => {
      const delivery = fixture(t, { preferences: { night_mute: true }, platform,
        now: '2026-10-19T12:59:30Z', createdAt: '2026-10-19T12:00:00Z' });
      assert.equal((await delivery.run()).sent, 1);
      const message = delivery.requests[0].message;
      if (platform === 'web') {
        assert.equal(message.webpush.headers.TTL, '30');
        assert.equal(message.data.pushExpiresAt, String(Date.parse('2026-10-19T13:00:00Z')));
      } else {
        assert.equal(message.android.ttl, '30s');
        assert.equal(message.apns.headers['apns-expiration'], String(Date.parse('2026-10-19T13:00:00Z') / 1000));
      }
    });
  }
});

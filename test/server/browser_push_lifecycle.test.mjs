// Runs the production worker without Firebase, browser permissions, or network.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../../web/firebase-messaging-sw.js', import.meta.url), 'utf8');
const alice = '11111111-1111-1111-1111-111111111111';
const bob = '22222222-2222-2222-2222-222222222222';

function fixture({ hour = 12, windows = [] } = {}) {
  let now = Date.UTC(2026, 9, 19, hour);
  let storedOwner;
  let background;
  const handlers = {}, shown = [], posted = [], focused = [], opened = [];
  let closed = 0;
  class Clock extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now; }
    getHours() { return this.getUTCHours(); }
  }
  const indexedDB = {
    open() {
      const request = {};
      const db = {
        close() {},
        transaction() {
          const tx = {};
          tx.objectStore = () => ({
            get() {
              const result = {};
              queueMicrotask(() => { result.result = storedOwner; result.onsuccess(); });
              return result;
            },
            put(owner) { storedOwner = owner; queueMicrotask(() => tx.oncomplete()); },
            delete() { storedOwner = undefined; queueMicrotask(() => tx.oncomplete()); },
          });
          return tx;
        },
      };
      queueMicrotask(() => { request.result = db; request.onsuccess(); });
      return request;
    },
  };
  const options = Buffer.from(JSON.stringify({ apiKey: 'fixture', appId: 'fixture',
    messagingSenderId: 'fixture', projectId: 'fixture' })).toString('base64url');
  const location = new URL(`https://snapfit.test/app/push/firebase-messaging-sw.js?firebase=${options}`);
  const self = {
    location,
    registration: {
      scope: 'https://snapfit.test/app/push/',
      async showNotification(title, options) { shown.push({ title, ...options }); },
      async getNotifications() { return [{ close() { closed++; } }]; },
    },
    clients: {
      async matchAll() { return windows.map(url => ({ url,
        postMessage(message) { posted.push(message); }, async focus() { focused.push(url); },
      })); },
      async openWindow(url) { opened.push(url); },
    },
    addEventListener(type, callback) { handlers[type] = callback; },
    async skipWaiting() {},
  };
  vm.runInNewContext(source, { self, indexedDB, URL, Date: Clock, atob,
    importScripts() {}, firebase: { initializeApp() {}, messaging: () => ({
      onBackgroundMessage(callback) { background = callback; },
    }) },
  });
  async function message(data) {
    let completion, response;
    handlers.message({ data, source: { url: 'https://snapfit.test/app/' },
      ports: [{ postMessage(value) { response = value; } }],
      waitUntil(value) { completion = value; },
    });
    await completion;
    assert.equal(response.ok, true);
  }
  const bind = (userId = alice, preferences = {}) => message({ type: 'SNAPFIT_PUSH_BIND',
    userId, preferences, expiresAt: Math.floor(now / 1000) + 3600 });
  const data = (extra = {}) => ({ userId: alice, category: 'order', orderId: 'order-one',
    notificationId: '1', title: '앨범 제작 소식', body: '제작이 시작되었어요.',
    pushExpiresAt: String(now + 300000), ...extra });
  async function click(payload) {
    let completion;
    handlers.notificationclick({ notification: { data: payload, close() { closed++; } },
      stopImmediatePropagation() {}, waitUntil(value) { completion = value; } });
    await completion;
  }
  return { bind, message, data, click, background: payload => background({ data: payload }),
    shown, posted, focused, opened, get closed() { return closed; },
    advance(seconds) { now += seconds * 1000; } };
}

test('foreground and background web messages both respect current master and category opt-outs', async () => {
  for (const preferences of [{ all: false }, { order: false }]) {
    const f = fixture();
    await f.bind(alice, preferences);
    await f.background(f.data());
    await f.message({ type: 'SNAPFIT_PUSH_FOREGROUND', data: f.data() });
    assert.equal(f.shown.length, 0);
  }
  const f = fixture();
  await f.bind(alice, { all: true, order: true });
  await f.background(f.data());
  assert.equal(f.shown.length, 1);
});

test('web quiet hours, expired messages, and expired account leases fail closed', async () => {
  const night = fixture({ hour: 23 });
  await night.bind(alice, { nightMute: true });
  await night.background(night.data());
  assert.equal(night.shown.length, 0);
  const expired = fixture();
  await expired.bind();
  const old = expired.data();
  expired.advance(301);
  await expired.background(old);
  assert.equal(expired.shown.length, 0);
  expired.advance(3600);
  await expired.background(expired.data());
  await expired.click(expired.data());
  assert.equal(expired.shown.length, 0);
  assert.equal(expired.opened.length, 0);
});

test('an open web app receives the original owner-bound click and is focused', async () => {
  const f = fixture({ windows: ['https://other.test/', 'https://snapfit.test/app/#/albums'] });
  await f.bind();
  await f.click(f.data());
  assert.equal(f.posted.length, 1);
  assert.equal(f.posted[0].type, 'SNAPFIT_PUSH_CLICK');
  assert.equal(f.posted[0].data.userId, alice);
  assert.equal(f.focused.length, 1);
  assert.equal(f.opened.length, 0);
});

test('a closed web app opens same-origin order, album, and template routes', async () => {
  for (const [payload, fragment] of [
    [{ orderId: 'order-one' }, '/orders/order-one'],
    [{ orderId: undefined, albumId: '42' }, '/albums/42'],
    [{ orderId: undefined, templateId: '9' }, '/designs/templates/9'],
    [{ orderId: undefined, albumId: '../escape', deeplink: 'https://other.test/private' }, '/notifications'],
  ]) {
    const f = fixture();
    await f.bind();
    await f.click(f.data(payload));
    assert.deepEqual(f.opened, [`https://snapfit.test/app/#${fragment}`]);
  }
});

test('account replacement and logout suppress old content and clicks, closing old notifications', async () => {
  const f = fixture();
  await f.bind();
  await f.background(f.data());
  assert.equal(f.shown.length, 1);
  const before = f.closed;
  await f.bind(bob);
  assert.ok(f.closed > before);
  await f.background(f.data());
  await f.click(f.data());
  assert.equal(f.shown.length, 1);
  assert.equal(f.opened.length, 0);
  await f.background(f.data({ userId: bob }));
  assert.equal(f.shown.length, 2);
  await f.message({ type: 'SNAPFIT_PUSH_CLEAR' });
  await f.background(f.data({ userId: bob }));
  await f.click(f.data({ userId: bob }));
  assert.equal(f.shown.length, 2);
  assert.equal(f.opened.length, 0);
});

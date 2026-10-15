/* SnapFit web push. No fetch handler, application cache, credentials, or tokens. */
'use strict';

const DB_NAME = 'snapfit-browser-push-v1';
const STORE = 'installation';
let operations = Promise.resolve();
function serialize(task) {
  const result = operations.catch(() => {}).then(task);
  operations = result.catch(() => {});
  return result;
}

function database() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(new Error('push_storage_unavailable'));
  });
}
async function readOwner() {
  const db = await database();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction(STORE, 'readonly');
      const request = transaction.objectStore(STORE).get('owner');
      request.onsuccess = () => resolve(request.result || null);
      request.onerror = () => reject(new Error('push_storage_unavailable'));
    });
  } finally { db.close(); }
}
async function writeOwner(value) {
  const db = await database();
  try {
    await new Promise((resolve, reject) => {
      const transaction = db.transaction(STORE, 'readwrite');
      const store = transaction.objectStore(STORE);
      if (value) store.put(value, 'owner'); else store.delete('owner');
      transaction.oncomplete = () => resolve();
      transaction.onerror = transaction.onabort = () => reject(new Error('push_storage_unavailable'));
    });
  } finally { db.close(); }
}
function activeOwner(owner) {
  return owner && typeof owner.userId === 'string' &&
    Number.isFinite(owner.expiresAt) && owner.expiresAt * 1000 > Date.now();
}
async function closeNotifications() {
  const notifications = await self.registration.getNotifications();
  for (const notification of notifications) notification.close();
}
function allowed(owner, data) {
  if (!activeOwner(owner) || data.userId !== owner.userId) return false;
  const expires = Number(data.pushExpiresAt);
  if (!Number.isFinite(expires) || expires <= Date.now()) return false;
  const preferences = owner.preferences || {};
  if (preferences.all === false) return false;
  const category = String(data.category || 'general');
  if (preferences[category] === false) return false;
  const hour = new Date().getHours();
  return !(preferences.nightMute && (hour >= 22 || hour < 8));
}
async function display(data) {
  if (!data || typeof data !== 'object') return;
  const owner = await readOwner();
  if (!allowed(owner, data)) return;
  // No notification payload is sent for web: we verify the current owner before
  // showing content, including background messages queued for an old account.
  await self.registration.showNotification(String(data.title || '스냅핏').slice(0, 200), {
    body: String(data.body || '').slice(0, 1000),
    icon: new URL('../icons/Icon-192.png', self.registration.scope).href,
    tag: `snapfit-${String(data.notificationId || '').slice(0, 80)}`,
    data,
  });
}
function destination(data) {
  // Construct only known same-origin routes; never navigate to a payload URL.
  const base = new URL('../', self.registration.scope);
  // Static hosting serves the app document at base; the application Router
  // reads the fragment. Path URLs would request a nonexistent server file.
  const route = (path) => {
    const url = new URL(base.href);
    url.hash = path;
    return url.href;
  };
  const positiveId = (value) => /^[1-9][0-9]{0,17}$/.test(String(value || ''));
  const uuid = (value) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || ''));
  if (/^[A-Za-z0-9_-]{1,200}$/.test(String(data.orderId || ''))) {
    return route(`/orders/${data.orderId}`);
  }
  if (uuid(data.runId)) return route(`/test-orders/${data.runId}`);
  if (positiveId(data.albumId)) return route(`/albums/${data.albumId}`);
  if (positiveId(data.templateId)) return route(`/designs/templates/${data.templateId}`);
  return route('/notifications');
}

// Register before Firebase imports: its default click handler must not override
// the account check or use untrusted external fcm_options links.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.stopImmediatePropagation();
  event.waitUntil(serialize(async () => {
    const data = event.notification.data;
    const owner = await readOwner();
    if (!data || !activeOwner(owner) || data.userId !== owner.userId) return;
    const base = new URL('../', self.registration.scope);
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const client = clients.find((candidate) => {
      const url = new URL(candidate.url);
      return url.origin === base.origin && url.pathname.startsWith(base.pathname);
    });
    if (client) {
      client.postMessage({ type: 'SNAPFIT_PUSH_CLICK', data });
      await client.focus();
    } else {
      await self.clients.openWindow(destination(data));
    }
  }).catch(() => {}));
});

let firebaseOptions;
try {
  const encoded = new URL(self.location.href).searchParams.get('firebase') || '';
  if (!encoded || encoded.length > 4096) throw new Error('missing_public_configuration');
  const normalized = encoded.replace(/-/g, '+').replace(/_/g, '/');
  const parsed = JSON.parse(atob(normalized));
  const required = ['apiKey', 'appId', 'messagingSenderId', 'projectId'];
  if (required.some((key) => typeof parsed[key] !== 'string' || !parsed[key])) {
    throw new Error('invalid_public_configuration');
  }
  firebaseOptions = Object.fromEntries(required.map((key) => [key, parsed[key]]));
} catch (_) {
  // Installation fails closed; the app reports setup unavailable, not success.
  throw new Error('snapfit_web_push_configuration_unavailable');
}

self.addEventListener('message', (event) => {
  const port = event.ports && event.ports[0];
  if (!port || !event.source || !event.source.url ||
      new URL(event.source.url).origin !== self.location.origin) return;
  const message = event.data || {};
  event.waitUntil(serialize(async () => {
    if (message.type === 'SNAPFIT_PUSH_METADATA') {
      return { version: 1, projectId: firebaseOptions.projectId, appId: firebaseOptions.appId };
    }
    if (message.type === 'SNAPFIT_PUSH_CLEAR') {
      await writeOwner(null);
      await closeNotifications();
      return {};
    }
    if (message.type === 'SNAPFIT_PUSH_BIND') {
      if (!/^[0-9a-f-]{36}$/i.test(String(message.userId || '')) ||
          !Number.isFinite(message.expiresAt) || message.expiresAt * 1000 <= Date.now()) {
        throw new Error('invalid_push_owner');
      }
      const previous = await readOwner();
      if (previous?.userId !== message.userId) await closeNotifications();
      const preferences = {};
      for (const key of ['all', 'order', 'invite', 'comment', 'marketing', 'new_template', 'nightMute']) {
        if (typeof message.preferences?.[key] === 'boolean') preferences[key] = message.preferences[key];
      }
      await writeOwner({ userId: message.userId, expiresAt: message.expiresAt, preferences });
      return {};
    }
    if (message.type === 'SNAPFIT_PUSH_FOREGROUND') {
      await display(message.data);
      return {};
    }
    throw new Error('unknown_push_operation');
  }).then((value) => port.postMessage({ ok: true, ...value }))
    .catch(() => port.postMessage({ ok: false })));
});

self.addEventListener('install', (event) => event.waitUntil(self.skipWaiting()));
// Pinned to firebase_core_web 3.11.0 in pubspec.lock. Update both together.
importScripts('https://www.gstatic.com/firebasejs/12.18.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.18.0/firebase-messaging-compat.js');
firebase.initializeApp(firebaseOptions);
firebase.messaging().onBackgroundMessage((payload) =>
  serialize(() => display(payload.data)).catch(() => {}));

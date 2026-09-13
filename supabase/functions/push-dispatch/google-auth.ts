import { DispatchError } from './diagnostics.ts';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };
let cached: { token: string; expiresAt: number } | null = null;
function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
export function parseServiceAccount(raw: string): ServiceAccount {
  let value;
  try {
    value = JSON.parse(raw);
    // Secret tooling can preserve the surrounding JSON string from an env file.
    if (typeof value === 'string') value = JSON.parse(value);
  } catch (_) {
    throw new DispatchError('credential_parse', 'invalid_json');
  }
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
    ['project_id', 'client_email', 'private_key'].some((field) =>
      typeof value[field] !== 'string' || value[field].trim().length === 0)) {
    throw new DispatchError('credential_parse', 'credentials_incomplete');
  }
  return { project_id: value.project_id.trim(), client_email: value.client_email.trim(),
    private_key: value.private_key.replace(/\\r\\n|\\n/g, '\n') };
}
export async function googleAccessToken(account: ServiceAccount): Promise<string> {
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;
  const encoder = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = base64url(encoder.encode(JSON.stringify({ iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600 })));
  const pem = account.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  let key;
  try {
    key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  } catch (_) { throw new DispatchError('credential_import_key', 'invalid_private_key'); }
  let signature;
  try {
    signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(`${header}.${claims}`));
  } catch (_) { throw new DispatchError('credential_sign', 'assertion_signing_failed'); }
  let response;
  try {
    response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, signal: AbortSignal.timeout(10_000),
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${header}.${claims}.${base64url(new Uint8Array(signature))}` }) });
  } catch (_) { throw new DispatchError('oauth', 'request_failed'); }
  if (!response.ok) throw new DispatchError('oauth', 'request_rejected', response.status);
  let result;
  try { result = await response.json(); }
  catch (_) { throw new DispatchError('oauth', 'invalid_response'); }
  if (!result || typeof result.access_token !== 'string' || !result.access_token) {
    throw new DispatchError('oauth', 'access_token_missing');
  }
  cached = { token: result.access_token, expiresAt: Date.now() + Number(result.expires_in ?? 3600) * 1000 };
  return cached.token;
}

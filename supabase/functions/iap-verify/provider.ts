import {
  PurchaseError,
  type PurchaseRequest,
  text,
  validateApplePurchase,
  validateGooglePurchase,
  type VerifiedPointPurchase,
} from "./point-purchase.ts";

function base64UrlEncode(input: Uint8Array | string) {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function base64UrlDecodeJson(segment: string): Record<string, unknown> {
  const normalized = segment.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return JSON.parse(new TextDecoder().decode(bytes));
}

async function importGooglePrivateKey(pem: string) {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function signGoogleJwt(serviceAccount: Record<string, string>) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${
    base64UrlEncode(JSON.stringify(payload))
  }`;
  const key = await importGooglePrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

let cachedGoogleToken: { value: string; expiresAt: number } | null = null;
let pendingGoogleToken: Promise<string> | null = null;

async function googleAccessToken(): Promise<string> {
  if (cachedGoogleToken && cachedGoogleToken.expiresAt > Date.now()) {
    return cachedGoogleToken.value;
  }
  if (pendingGoogleToken) return pendingGoogleToken;
  pendingGoogleToken = requestGoogleAccessToken();
  try {
    return await pendingGoogleToken;
  } finally {
    pendingGoogleToken = null;
  }
}

async function requestGoogleAccessToken() {
  const rawJson = text(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"));
  const clientEmail = text(Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL"));
  const privateKey = text(
    Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY"),
  ).replace(/\\n/g, "\n");
  const serviceAccount = rawJson
    ? JSON.parse(rawJson)
    : { client_email: clientEmail, private_key: privateKey };
  if (!serviceAccount.client_email || !serviceAccount.private_key) {
    throw new PurchaseError("google_play_credentials_not_configured", 503);
  }
  const assertion = await signGoogleJwt(serviceAccount);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    signal: AbortSignal.timeout(15_000),
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await response.json().catch(() => ({}));
  const value = text(data.access_token);
  if (!response.ok || !value) {
    throw new PurchaseError("google_play_credentials_unavailable", 503);
  }
  const lifetime = Math.min(
    3600,
    Math.max(60, Number(data.expires_in) || 3600),
  );
  cachedGoogleToken = { value, expiresAt: Date.now() + (lifetime - 60) * 1000 };
  return value;
}

async function importApplePrivateKey(pem: string) {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

async function appleServerJwt() {
  const issuerId = text(Deno.env.get("APP_STORE_ISSUER_ID"));
  const keyId = text(Deno.env.get("APP_STORE_KEY_ID"));
  const bundleId = text(Deno.env.get("APP_STORE_BUNDLE_ID"));
  const privateKey = text(Deno.env.get("APP_STORE_PRIVATE_KEY")).replace(
    /\\n/g,
    "\n",
  );
  if (!issuerId || !keyId || !bundleId || !privateKey) {
    throw new PurchaseError("app_store_credentials_not_configured", 503);
  }
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: keyId, typ: "JWT" };
  const payload = {
    iss: issuerId,
    iat: now,
    exp: now + 1200,
    aud: "appstoreconnect-v1",
    bid: bundleId,
  };
  const signingInput = `${base64UrlEncode(JSON.stringify(header))}.${
    base64UrlEncode(JSON.stringify(payload))
  }`;
  const key = await importApplePrivateKey(privateKey);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function providerResponse(url: string, bearer: string) {
  let response: Response;
  try {
    response = await fetch(url, {
      headers: { authorization: `Bearer ${bearer}` },
      signal: AbortSignal.timeout(15_000),
    });
  } catch {
    throw new PurchaseError("store_verification_unavailable", 503);
  }
  if (!response.ok) {
    if (
      response.status === 400 || response.status === 404 ||
      response.status === 410
    ) {
      throw new PurchaseError("store_purchase_not_found");
    }
    // Provider errors may contain credentials/tokens. Never return raw bodies.
    throw new PurchaseError("store_verification_unavailable", 503);
  }
  const data = await response.json().catch(() => null);
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new PurchaseError("invalid_store_response", 503);
  }
  return data as Record<string, unknown>;
}

export async function verifyPurchase(
  request: PurchaseRequest,
): Promise<VerifiedPointPurchase> {
  if (request.platform === "GOOGLE_PLAY") {
    const packageName = text(Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME"));
    if (!packageName) {
      throw new PurchaseError("google_play_package_name_not_configured", 503);
    }
    if (request.packageName && request.packageName !== packageName) {
      throw new PurchaseError("google_play_package_id_mismatch");
    }
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
        encodeURIComponent(packageName)
      }/purchases/productsv2/tokens/${
        encodeURIComponent(request.purchaseToken)
      }`;
    const data = await providerResponse(url, await googleAccessToken());
    return validateGooglePurchase(request, data, packageName);
  }

  const configuredEnvironment =
    text(Deno.env.get("APP_STORE_ENVIRONMENT")).toLowerCase() || "production";
  if (!["production", "sandbox"].includes(configuredEnvironment)) {
    throw new PurchaseError("app_store_environment_not_configured", 503);
  }
  const environment = configuredEnvironment === "sandbox"
    ? "Sandbox"
    : "Production";
  const host = environment === "Sandbox"
    ? "https://api.storekit-sandbox.itunes.apple.com"
    : "https://api.storekit.itunes.apple.com";
  const data = await providerResponse(
    `${host}/inApps/v1/transactions/${
      encodeURIComponent(request.transactionId)
    }`,
    await appleServerJwt(),
  );
  const signed = text(data.signedTransactionInfo);
  const segments = signed.split(".");
  if (segments.length !== 3 || segments.some((segment) => !segment)) {
    throw new PurchaseError("invalid_store_response", 503);
  }
  // This JWS comes exclusively from Apple's authenticated HTTPS Server API,
  // never from client receiptData. Validate the exact requested transaction and
  // fixed bundle/environment before trusting any entitlement fields.
  const header = base64UrlDecodeJson(segments[0]);
  if (header.alg !== "ES256") {
    throw new PurchaseError("invalid_store_response", 503);
  }
  const payload = base64UrlDecodeJson(segments[1]);
  return validateApplePurchase(
    request,
    payload,
    text(Deno.env.get("APP_STORE_BUNDLE_ID")),
    environment,
  );
}

// Provider payload validation and request orchestration. No network or database
// globals: tests use the same code with isolated provider/database adapters.
export type StorePlatform = "GOOGLE_PLAY" | "APP_STORE";
export type PurchaseRequest = {
  platform: StorePlatform;
  productId: string;
  transactionId: string;
  purchaseToken: string;
  packageName: string;
};
export type VerifiedPointPurchase = {
  platform: StorePlatform;
  productId: string;
  transactionId: string;
  originalTransactionId: string;
  purchaseToken: string | null;
  storeAccountId: string | null;
  purchasedAt: string;
  rawResponse: Record<string, unknown>;
};
export type PointGrant = {
  product_id: string;
  granted_points: number;
  remaining_balance: number;
  already_granted: boolean;
};

export class PurchaseError extends Error {
  status: number;
  evidence?: Record<string, unknown>;
  constructor(code: string, status = 400, evidence?: Record<string, unknown>) {
    super(code);
    this.name = "PurchaseError";
    this.status = status;
    this.evidence = evidence;
  }
}

export const text = (value: unknown) =>
  typeof value === "string" ? value.trim() : "";
const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};

function parsePlatform(value: unknown): StorePlatform {
  const platform = text(value).toUpperCase();
  if (platform !== "GOOGLE_PLAY" && platform !== "APP_STORE") {
    throw new PurchaseError("invalid_platform");
  }
  return platform;
}

// Pre-purchase configuration check only: do not contact a store or expose keys,
// missing setting names, provider responses, or account-specific purchase data.
export function isPointPurchaseAvailable(
  platform: StorePlatform,
  env: (name: string) => string | undefined,
): boolean {
  try {
    if (platform === "APP_STORE") {
      const environment = text(env("APP_STORE_ENVIRONMENT")).toLowerCase() ||
        "production";
      return ["production", "sandbox"].includes(environment) &&
        [
          "APP_STORE_BUNDLE_ID",
          "APP_STORE_ISSUER_ID",
          "APP_STORE_KEY_ID",
          "APP_STORE_PRIVATE_KEY",
        ]
          .every((name) => Boolean(text(env(name))));
    }
    if (!text(env("GOOGLE_PLAY_PACKAGE_NAME"))) return false;
    const rawJson = text(env("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"));
    if (rawJson) {
      // Match the provider's JSON precedence: malformed or incomplete JSON must
      // not report READY just because separate fallback fields also exist.
      const account = record(JSON.parse(rawJson));
      return Boolean(text(account.client_email) && text(account.private_key));
    }
    return Boolean(
      text(env("GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL")) &&
        text(env("GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY")),
    );
  } catch {
    return false;
  }
}

export function parsePurchaseRequest(value: unknown): PurchaseRequest {
  const body = record(value);
  const platform = parsePlatform(body.platform);
  if (
    (body.purchaseType && text(body.purchaseType).toUpperCase() !== "POINTS") ||
    (body.planCode && text(body.planCode) !== "FREE")
  ) {
    throw new PurchaseError("point_purchases_only");
  }
  const productId = text(body.productId);
  const transactionId = text(body.transactionId);
  const purchaseToken = text(body.purchaseToken);
  if (!productId || productId.length > 200) {
    throw new PurchaseError("product_id_required");
  }
  if (
    platform === "GOOGLE_PLAY" &&
    (!purchaseToken || purchaseToken.length > 4096)
  ) {
    throw new PurchaseError("purchase_token_required");
  }
  if (platform === "APP_STORE" && !/^\d{1,64}$/.test(transactionId)) {
    throw new PurchaseError("transaction_id_required");
  }
  return {
    platform,
    productId,
    transactionId,
    purchaseToken,
    packageName: text(body.packageName),
  };
}

function purchaseDate(value: unknown) {
  const date = new Date(typeof value === "number" ? value : text(value));
  if (!Number.isFinite(date.getTime()) || date.getTime() <= 0) {
    throw new PurchaseError("invalid_purchase_date");
  }
  return date.toISOString();
}

export function validateGooglePurchase(
  request: PurchaseRequest,
  data: Record<string, unknown>,
  packageName: string,
): VerifiedPointPurchase {
  if (!packageName) {
    throw new PurchaseError("google_play_package_name_not_configured", 503);
  }
  if (request.packageName && request.packageName !== packageName) {
    throw new PurchaseError("google_play_package_id_mismatch");
  }
  const items = Array.isArray(data.productLineItem) ? data.productLineItem : [];
  if (
    items.length !== 1 || text(record(items[0]).productId) !== request.productId
  ) {
    throw new PurchaseError("google_play_product_id_mismatch");
  }
  const state = text(record(data.purchaseStateContext).purchaseState);
  if (state === "PENDING") throw new PurchaseError("purchase_pending", 409);
  if (state === "CANCELLED") {
    throw new PurchaseError("purchase_revoked", 409, data);
  }
  if (state !== "PURCHASED") {
    throw new PurchaseError("purchase_not_completed", 409);
  }
  const offer = record(record(items[0]).productOfferDetails);
  if (Number(offer.quantity ?? 1) !== 1) {
    throw new PurchaseError("unsupported_purchase_quantity");
  }
  if (offer.rentOfferDetails || offer.preorderOfferDetails) {
    throw new PurchaseError("point_purchases_only");
  }
  if (offer.refundableQuantity !== undefined) {
    // This is the not-yet-refunded quantity, independent of consumptionState.
    // Malformed provider data must never be used as evidence for a clawback.
    if (offer.refundableQuantity === 0) {
      throw new PurchaseError("purchase_revoked", 409, data);
    }
    if (offer.refundableQuantity !== 1) {
      throw new PurchaseError("invalid_store_response", 503);
    }
  }
  return {
    platform: "GOOGLE_PLAY",
    productId: text(record(items[0]).productId),
    // Google purchase tokens, unlike client order IDs, are globally unique.
    transactionId: request.purchaseToken,
    originalTransactionId: text(data.orderId) || request.purchaseToken,
    purchaseToken: request.purchaseToken,
    storeAccountId: text(data.obfuscatedExternalAccountId).toLowerCase() ||
      null,
    purchasedAt: purchaseDate(data.purchaseCompletionTime),
    rawResponse: data,
  };
}

export function validateApplePurchase(
  request: PurchaseRequest,
  payload: Record<string, unknown>,
  bundleId: string,
  environment: "Production" | "Sandbox",
): VerifiedPointPurchase {
  if (!bundleId) {
    throw new PurchaseError("app_store_bundle_id_not_configured", 503);
  }
  if (text(payload.bundleId) !== bundleId) {
    throw new PurchaseError("app_store_bundle_id_mismatch");
  }
  if (text(payload.productId) !== request.productId) {
    throw new PurchaseError("app_store_product_id_mismatch");
  }
  if (text(payload.transactionId) !== request.transactionId) {
    throw new PurchaseError("app_store_transaction_id_mismatch");
  }
  if (text(payload.environment) !== environment) {
    throw new PurchaseError("app_store_environment_mismatch");
  }
  if (
    text(payload.type) !== "Consumable" || payload.expiresDate !== undefined
  ) {
    throw new PurchaseError("point_purchases_only");
  }
  if (Number(payload.quantity ?? 1) !== 1) {
    throw new PurchaseError("unsupported_purchase_quantity");
  }
  if (
    payload.revocationDate ||
    (payload.revocationReason !== undefined &&
      payload.revocationReason !== null)
  ) {
    throw new PurchaseError("purchase_revoked", 409, payload);
  }
  if (text(payload.inAppOwnershipType) !== "PURCHASED") {
    throw new PurchaseError("purchase_ownership_invalid");
  }
  return {
    platform: "APP_STORE",
    productId: text(payload.productId),
    transactionId: text(payload.transactionId),
    originalTransactionId: text(payload.originalTransactionId) ||
      text(payload.transactionId),
    purchaseToken: null,
    storeAccountId: text(payload.appAccountToken).toLowerCase() || null,
    purchasedAt: purchaseDate(payload.purchaseDate),
    rawResponse: payload,
  };
}

export type PurchaseDependencies = {
  authenticate: (request: Request) => Promise<{ id: string }>;
  availability: (platform: StorePlatform) => boolean | Promise<boolean>;
  isPointProduct: (productId: string) => Promise<boolean>;
  verify: (request: PurchaseRequest) => Promise<VerifiedPointPurchase>;
  grant: (
    userId: string,
    purchase: VerifiedPointPurchase,
  ) => Promise<PointGrant>;
  log?: (event: {
    userId: string;
    eventType: string;
    platform: string;
    productId: string;
    transactionId: string;
    pointDelta: number;
  }) => Promise<void>;
};

export function createPointPurchaseHandler(
  deps: PurchaseDependencies,
  headers: Record<string, string> = {},
) {
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...headers, "content-type": "application/json" },
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers });
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    try {
      const user = await deps.authenticate(req);
      const raw = await req.text();
      if (raw.length > 65536) throw new PurchaseError("request_too_large", 413);
      let body;
      try {
        body = JSON.parse(raw);
      } catch {
        throw new PurchaseError("invalid_json");
      }
      if (record(body).action === "availability") {
        const platform = parsePlatform(record(body).platform);
        const available = await deps.availability(platform);
        return json({
          status: available ? "READY" : "UNAVAILABLE",
          platform,
          pointsOnly: true,
        });
      }
      const request = parsePurchaseRequest(body);
      if (!await deps.isPointProduct(request.productId)) {
        throw new PurchaseError("unknown_point_product");
      }
      const purchase = await deps.verify(request);
      if (
        purchase.storeAccountId &&
        purchase.storeAccountId !== user.id.toLowerCase()
      ) {
        throw new PurchaseError("purchase_account_mismatch", 403);
      }
      // Missing account tokens are decided inside the atomic grant, where only
      // a previously verified, already credited purchase owned by this user may retry.
      const row = await deps.grant(user.id, purchase);
      try {
        await deps.log?.({
          userId: user.id,
          eventType: row.already_granted
            ? "POINT_PURCHASE_DUPLICATE"
            : "POINT_PURCHASE_VERIFIED",
          platform: purchase.platform,
          productId: purchase.productId,
          transactionId: purchase.transactionId,
          pointDelta: row.already_granted ? 0 : row.granted_points,
        });
      } catch {
        console.warn("point_purchase_event_log_failed");
      }
      return json({
        userId: user.id,
        status: "VERIFIED",
        productId: row.product_id,
        pointPurchase: {
          productId: row.product_id,
          grantedPoints: row.granted_points,
          remainingBalance: row.remaining_balance,
          alreadyGranted: row.already_granted,
        },
      });
    } catch (error) {
      if (error instanceof PurchaseError) {
        return json({
          error: error.message,
          code: error.message,
          retryable: error.status >= 500 ||
            error.message === "purchase_pending",
        }, error.status);
      }
      if (error instanceof Error && error.message === "Unauthorized") {
        return json({ error: "unauthorized" }, 401);
      }
      console.error("point_purchase_internal_error");
      return json({ error: "purchase_verification_unavailable" }, 503);
    }
  };
}

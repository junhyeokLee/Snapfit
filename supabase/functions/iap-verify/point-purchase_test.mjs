import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { stripTypeScriptTypes } from "node:module";
import {
  createPointPurchaseHandler,
  isPointPurchaseAvailable,
  parsePurchaseRequest,
  PurchaseError,
  text,
  validateApplePurchase,
  validateGooglePurchase,
} from "./point-purchase.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const otherId = "22222222-2222-4222-8222-222222222222";
const productId = "snapfit_points_2500";
const googleRequest = () =>
  parsePurchaseRequest({
    platform: "GOOGLE_PLAY",
    productId,
    purchaseToken: "canonical-token",
    transactionId: "untrusted-client-order",
  });
const googlePayload = () => ({
  productLineItem: [{
    productId,
    productOfferDetails: {
      quantity: 1,
      refundableQuantity: 1,
      consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
    },
  }],
  purchaseStateContext: { purchaseState: "PURCHASED" },
  purchaseCompletionTime: "2026-09-08T00:00:00Z",
  obfuscatedExternalAccountId: userId,
  orderId: "provider-order",
});
const appleRequest = () =>
  parsePurchaseRequest({
    platform: "APP_STORE",
    productId,
    transactionId: "2000000123456789",
  });
const applePayload = () => ({
  productId,
  transactionId: "2000000123456789",
  originalTransactionId: "2000000123456789",
  bundleId: "com.example.snapfit",
  environment: "Production",
  type: "Consumable",
  quantity: 1,
  appAccountToken: userId,
  inAppOwnershipType: "PURCHASED",
  purchaseDate: Date.parse("2026-09-08T00:00:00Z"),
});
const google = (data = googlePayload(), request = googleRequest()) =>
  validateGooglePurchase(request, data, "com.example.snapfit");
const apple = (data = applePayload(), request = appleRequest()) =>
  validateApplePurchase(request, data, "com.example.snapfit", "Production");
const rejected = (fn, code) =>
  assert.throws(
    fn,
    (error) => error instanceof PurchaseError && error.message === code,
  );

test("Google uses verified product and canonical purchase token, ignores caller order ID", () => {
  const verified = google();
  assert.equal(verified.transactionId, "canonical-token");
  assert.equal(verified.originalTransactionId, "provider-order");
  assert.equal(verified.storeAccountId, userId);
  assert.equal(
    google({ ...googlePayload(), orderId: undefined }).transactionId,
    "canonical-token",
  );
});

test("Google rejects pending, cancelled and unspecified purchases even if acknowledged", () => {
  for (
    const [state, code] of [["PENDING", "purchase_pending"], [
      "CANCELLED",
      "purchase_revoked",
    ], ["", "purchase_not_completed"]]
  ) {
    rejected(
      () =>
        google({
          ...googlePayload(),
          acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
          purchaseStateContext: { purchaseState: state },
        }),
      code,
    );
  }
});

test("Google rejects a substituted subscription SKU, wrong package, multiple items and quantities", () => {
  rejected(
    () =>
      google({
        ...googlePayload(),
        productLineItem: [{ productId: "snapfit_pro_monthly" }],
      }),
    "google_play_product_id_mismatch",
  );
  rejected(
    () =>
      google(googlePayload(), {
        ...googleRequest(),
        packageName: "another.app",
      }),
    "google_play_package_id_mismatch",
  );
  rejected(
    () =>
      google({
        ...googlePayload(),
        productLineItem: [
          ...googlePayload().productLineItem,
          ...googlePayload().productLineItem,
        ],
      }),
    "google_play_product_id_mismatch",
  );
  rejected(
    () =>
      google({
        ...googlePayload(),
        productLineItem: [{ productId, productOfferDetails: { quantity: 2 } }],
      }),
    "unsupported_purchase_quantity",
  );
});

test("Google rejects refunded quantities and missing purchase completion time", () => {
  rejected(
    () =>
      google({
        ...googlePayload(),
        productLineItem: [{
          productId,
          productOfferDetails: { quantity: 1, refundableQuantity: 0 },
        }],
      }),
    "purchase_revoked",
  );
  rejected(
    () => google({ ...googlePayload(), purchaseCompletionTime: undefined }),
    "invalid_purchase_date",
  );
  for (const refundableQuantity of [null, -1, "0", 2]) {
    rejected(
      () =>
        google({
          ...googlePayload(),
          productLineItem: [{
            productId,
            productOfferDetails: { quantity: 1, refundableQuantity },
          }],
        }),
      "invalid_store_response",
    );
  }
});

test("Google permits consumed PURCHASED tokens to retry the same database grant", () => {
  const payload = googlePayload();
  payload.productLineItem[0].productOfferDetails.consumptionState =
    "CONSUMPTION_STATE_CONSUMED";
  assert.equal(google(payload).transactionId, "canonical-token");
});

test("Apple requires a consumable and exact bundle, transaction, product and environment", () => {
  assert.equal(apple().transactionId, "2000000123456789");
  for (
    const [field, value, code] of [
      ["type", "Auto-Renewable Subscription", "point_purchases_only"],
      ["bundleId", "another.app", "app_store_bundle_id_mismatch"],
      ["productId", "snapfit_pro_monthly", "app_store_product_id_mismatch"],
      [
        "transactionId",
        "2000000123456790",
        "app_store_transaction_id_mismatch",
      ],
      ["environment", "Sandbox", "app_store_environment_mismatch"],
      ["inAppOwnershipType", "FAMILY_SHARED", "purchase_ownership_invalid"],
      ["quantity", 2, "unsupported_purchase_quantity"],
    ]
  ) rejected(() => apple({ ...applePayload(), [field]: value }), code);
});

test("Apple rejects revoked transactions and subscription expiry fields", () => {
  rejected(
    () => apple({ ...applePayload(), revocationDate: Date.now() }),
    "purchase_revoked",
  );
  rejected(
    () => apple({ ...applePayload(), revocationReason: 0 }),
    "purchase_revoked",
  );
  rejected(
    () => apple({ ...applePayload(), expiresDate: Date.now() + 100000 }),
    "point_purchases_only",
  );
});

function handler(overrides = {}) {
  return createPointPurchaseHandler({
    authenticate: async () => ({ id: userId }),
    availability: () => true,
    isPointProduct: async (id) => id === productId,
    verify: async () => google(),
    grant: async () => ({
      product_id: productId,
      granted_points: 2500,
      remaining_balance: 2500,
      already_granted: false,
    }),
    ...overrides,
  });
}
const post = (body = { ...googleRequest(), purchaseType: "POINTS" }) =>
  new Request("https://offline.test", {
    method: "POST",
    body: JSON.stringify(body),
  });

test("availability returns only public readiness fields and never queries products, providers or grants", async () => {
  for (const available of [false, true]) {
    let calls = 0;
    const run = handler({
      availability: (platform) => {
        assert.equal(platform, "APP_STORE");
        return available;
      },
      isPointProduct: async () => {
        calls++;
        return true;
      },
      verify: async () => {
        calls++;
        return google();
      },
      grant: async () => {
        calls++;
        throw new Error("must not grant");
      },
    });
    const response = await run(
      post({ action: "availability", platform: "APP_STORE" }),
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      status: available ? "READY" : "UNAVAILABLE",
      platform: "APP_STORE",
      pointsOnly: true,
    });
    assert.equal(calls, 0);
  }
});

test("availability requires authentication and rejects invalid platforms before environment checks", async () => {
  let checks = 0;
  const readiness = () => {
    checks++;
    return true;
  };
  const unauthenticated = handler({
    authenticate: async () => {
      throw new Error("Unauthorized");
    },
    availability: readiness,
  });
  assert.equal(
    (await unauthenticated(
      post({ action: "availability", platform: "APP_STORE" }),
    )).status,
    401,
  );
  const invalid = await handler({ availability: readiness })(
    post({ action: "availability", platform: "EXTERNAL_BILLING" }),
  );
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error, "invalid_platform");
  assert.equal(checks, 0);
});

test("Apple readiness fails for bundle/environment-only configuration and checks all credential fields", () => {
  const settings = {
    APP_STORE_BUNDLE_ID: "com.example.snapfit",
    APP_STORE_ENVIRONMENT: "production",
  };
  const ready = () =>
    isPointPurchaseAvailable("APP_STORE", (name) => settings[name]);
  assert.equal(ready(), false);
  Object.assign(settings, {
    APP_STORE_ISSUER_ID: "test-issuer",
    APP_STORE_KEY_ID: "test-key-id",
    APP_STORE_PRIVATE_KEY: "test-private-key",
  });
  assert.equal(ready(), true);
  settings.APP_STORE_ENVIRONMENT = "invalid-environment";
  assert.equal(ready(), false);
  settings.APP_STORE_ENVIRONMENT = "sandbox";
  assert.equal(ready(), true);
  settings.APP_STORE_PRIVATE_KEY = " ";
  assert.equal(ready(), false);
});

test("Google readiness validates credential JSON shape, precedence and alternative fields", () => {
  const settings = { GOOGLE_PLAY_PACKAGE_NAME: "com.example.snapfit" };
  const ready = () =>
    isPointPurchaseAvailable("GOOGLE_PLAY", (name) => settings[name]);
  assert.equal(ready(), false);
  Object.assign(settings, {
    GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL: "test@example.invalid",
    GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY: "test-private-key",
  });
  assert.equal(ready(), true);
  for (
    const value of [
      "{",
      "null",
      "[]",
      "{}",
      JSON.stringify({ client_email: "test@example.invalid" }),
    ]
  ) {
    settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = value;
    assert.equal(ready(), false);
  }
  settings.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = JSON.stringify({
    client_email: "test@example.invalid",
    private_key: "test-private-key",
  });
  assert.equal(ready(), true);
  settings.GOOGLE_PLAY_PACKAGE_NAME = "";
  assert.equal(ready(), false);
});

test("handler rejects subscriptions before contacting providers or granting points", async () => {
  let calls = 0;
  const run = handler({
    verify: async () => {
      calls++;
      return google();
    },
  });
  for (
    const body of [{ ...googleRequest(), productId: "snapfit_pro_monthly" }, {
      ...googleRequest(),
      purchaseType: "SUBSCRIPTION",
    }, { ...googleRequest(), planCode: "SNAPFIT_PRO_MONTHLY" }]
  ) {
    assert.equal((await run(post(body))).status, 400);
  }
  assert.equal(calls, 0);
});

test("handler rejects account mismatch before any database grant", async () => {
  let calls = 0;
  const response = await handler({
    verify: async () => ({ ...google(), storeAccountId: otherId }),
    grant: async () => {
      calls++;
    },
  })(post());
  assert.equal(response.status, 403);
  assert.equal((await response.json()).error, "purchase_account_mismatch");
  assert.equal(calls, 0);
});

test("pending and revoked purchases return errors and never success or grant", async () => {
  for (const code of ["purchase_pending", "purchase_revoked"]) {
    let called = false;
    const response = await handler({
      verify: async () => {
        throw new PurchaseError(code, 409);
      },
      grant: async () => {
        called = true;
      },
    })(post());
    assert.equal(response.status, 409);
    assert.equal(called, false);
    assert.equal((await response.json()).error, code);
  }
});

test("verified duplicate response preserves canonical point data and log failure cannot undo grant", async () => {
  const response = await handler({
    grant: async () => ({
      product_id: productId,
      granted_points: 2500,
      remaining_balance: 1700,
      already_granted: true,
    }),
    log: async () => {
      throw new Error("unavailable");
    },
  })(post());
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).pointPurchase, {
    productId,
    grantedPoints: 2500,
    remainingBalance: 1700,
    alreadyGranted: true,
  });
});

test("handler rejects invalid requests and does not disclose backend errors", async () => {
  assert.equal(
    (await handler()(new Request("https://offline.test", { method: "GET" })))
      .status,
    405,
  );
  assert.equal(
    (await handler()(
      new Request("https://offline.test", { method: "POST", body: "{" }),
    )).status,
    400,
  );
  const response = await handler({
    grant: async () => {
      throw new Error("private-token-and-provider-details");
    },
  })(post());
  assert.equal(response.status, 503);
  assert.equal(
    (await response.json()).error,
    "purchase_verification_unavailable",
  );
});

test("production adapter calls Google one-time endpoint and server-only atomic RPC", async () => {
  let url, grantArgs;
  const adapterSource = stripTypeScriptTypes(
    ["./provider.ts", "./index.ts"].map((file) =>
      readFileSync(new URL(file, import.meta.url), "utf8").replace(
        /^import[\s\S]*?from ["'][^"']+["'];\s*/gm,
        "",
      ).replace(
        "export async function verifyPurchase",
        "async function verifyPurchase",
      )
    ).join("\n"),
  );
  const db = {
    from: () => ({
      select() {
        return this;
      },
      eq() {
        return this;
      },
      maybeSingle: async () => ({ data: { product_id: productId } }),
      insert: async () => ({}),
    }),
    rpc: async (name, args) => {
      assert.equal(name, "grant_verified_point_purchase");
      grantArgs = args;
      return {
        data: [{
          product_id: productId,
          granted_points: 2500,
          remaining_balance: 2500,
          already_granted: false,
        }],
      };
    },
  };
  const sandbox = {
    createPointPurchaseHandler,
    isPointPurchaseAvailable,
    PurchaseError,
    text,
    validateGooglePurchase,
    validateApplePurchase,
    console,
    Request,
    Response,
    TextEncoder,
    TextDecoder,
    Uint8Array,
    atob,
    btoa,
    crypto,
    URLSearchParams,
    AbortSignal,
    corsHeaders: {},
    adminClient: () => db,
    getUser: async () => ({ id: userId }),
    fetch: async (value) => {
      url = value;
      return new Response(JSON.stringify(googlePayload()));
    },
    Deno: {
      env: {
        get: (
          key,
        ) => ({ GOOGLE_PLAY_PACKAGE_NAME: "com.example.snapfit" }[key]),
      },
      serve: (run) => {
        sandbox.handler = run;
      },
    },
  };
  vm.createContext(sandbox);
  vm.runInContext(
    adapterSource + '\ngoogleAccessToken=async()=>"offline-token";',
    sandbox,
  );
  const response = await sandbox.handler(post());
  assert.equal(response.status, 200);
  assert.match(url, /\/purchases\/productsv2\/tokens\/canonical-token$/);
  assert.equal(grantArgs.p_user_id, userId);
  assert.equal(grantArgs.p_purchase.transactionId, "canonical-token");
  assert.equal(grantArgs.p_purchase.storeAccountId, userId);
});

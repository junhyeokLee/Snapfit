import assert from "node:assert/strict";
import { test } from "node:test";
import { createReconciliationHandler } from "./reconcile.ts";
import { PurchaseError } from "../iap-verify/point-purchase.ts";

const secret = "offline-reconciliation-secret-at-least-32";
const userId = "11111111-1111-4111-8111-111111111111";
const claim = (id = 1) => ({
  purchase_id: id,
  user_id: userId,
  platform: "GOOGLE_PLAY",
  product_id: "snapfit_points_2500",
  transaction_id: `token-${id}`,
  purchase_token: `token-${id}`,
  lease_id: `lease-${id}`,
});
const post = (authorization = `Bearer ${secret}`) =>
  new Request("https://offline.test/reconcile", {
    method: "POST",
    headers: { authorization },
    body: JSON.stringify({ transactionId: "untrusted-body-id" }),
  });
const defaults = () => ({
  secret,
  claim: async () => [claim()],
  verify: async () => ({ storeAccountId: userId }),
  revoke: async () => ({ already_revoked: false }),
  finish: async () => {},
});

test("worker fails closed without secret or with user JWT, before reading any claims", async () => {
  let reads = 0;
  const deps = {
    ...defaults(),
    claim: async () => {
      reads++;
      return [];
    },
  };
  assert.equal(
    (await createReconciliationHandler({ ...deps, secret: "" })(post())).status,
    503,
  );
  assert.equal(
    (await createReconciliationHandler(deps)(post("Bearer ordinary-user-jwt")))
      .status,
    401,
  );
  assert.equal(reads, 0);
});

test("worker uses only claimed database identities and leaves valid purchases credited", async () => {
  const requests = [], finishes = [];
  let refunds = 0;
  const run = createReconciliationHandler({
    ...defaults(),
    verify: async (request) => {
      requests.push(request);
      return { storeAccountId: userId };
    },
    revoke: async () => {
      refunds++;
      return { already_revoked: false };
    },
    finish: async (item, error) => {
      finishes.push({ id: item.purchase_id, error });
    },
  });
  assert.deepEqual(await (await run(post())).json(), {
    checked: 1,
    revoked: 0,
    alreadyRevoked: 0,
    failed: 0,
  });
  assert.equal(requests[0].transactionId, "token-1");
  assert.equal(refunds, 0);
  assert.deepEqual(finishes, [{ id: 1, error: null }]);
});

test("worker revokes only verified provider revocations and records retries for provider failure", async () => {
  const evidence = { purchaseStateContext: { purchaseState: "CANCELLED" } };
  const refunds = [], finishes = [];
  const run = createReconciliationHandler({
    ...defaults(),
    claim: async () => [claim(1), claim(2), claim(3)],
    verify: async (request) => {
      if (request.transactionId === "token-1") {
        throw new PurchaseError("purchase_revoked", 409, evidence);
      }
      if (request.transactionId === "token-2") {
        throw new PurchaseError("store_verification_unavailable", 503);
      }
      throw new Error("private-provider-token");
    },
    revoke: async (item, data) => {
      refunds.push({ id: item.purchase_id, data });
      return { already_revoked: false };
    },
    finish: async (item, error) => {
      finishes.push({ id: item.purchase_id, error });
    },
  });
  assert.deepEqual(await (await run(post())).json(), {
    checked: 1,
    revoked: 1,
    alreadyRevoked: 0,
    failed: 2,
  });
  assert.deepEqual(refunds, [{ id: 1, data: evidence }]);
  assert.deepEqual(finishes.sort((a, b) => a.id - b.id), [
    { id: 1, error: null },
    { id: 2, error: "store_verification_unavailable" },
    { id: 3, error: "reconciliation_unavailable" },
  ]);
});

test("worker does not debit on untrusted revocation, mismatched account or provider 404", async () => {
  for (
    const error of [
      new PurchaseError("purchase_revoked", 409),
      new PurchaseError("store_purchase_not_found", 400),
      null,
    ]
  ) {
    let refunds = 0;
    const run = createReconciliationHandler({
      ...defaults(),
      verify: async () => {
        if (error) throw error;
        return { storeAccountId: "other-account" };
      },
      revoke: async () => {
        refunds++;
        return { already_revoked: false };
      },
    });
    assert.equal((await (await run(post())).json()).failed, 1);
    assert.equal(refunds, 0);
  }
});

test("already reversed receipts are not reported as newly debited; finish failures remain retryable", async () => {
  const run = createReconciliationHandler({
    ...defaults(),
    verify: async () => {
      throw new PurchaseError("purchase_revoked", 409, {});
    },
    revoke: async () => ({ already_revoked: true }),
    finish: async () => {
      throw new Error("database offline");
    },
  });
  assert.deepEqual(await (await run(post())).json(), {
    checked: 1,
    revoked: 0,
    alreadyRevoked: 1,
    failed: 1,
  });
});

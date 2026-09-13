import {
  parsePurchaseRequest,
  PurchaseError,
  type VerifiedPointPurchase,
} from "../iap-verify/point-purchase.ts";

export type ReconciliationClaim = {
  purchase_id: number;
  user_id: string;
  platform: string;
  product_id: string;
  transaction_id: string;
  purchase_token: string | null;
  lease_id: string;
};
type Dependencies = {
  secret: string;
  claim: () => Promise<ReconciliationClaim[]>;
  verify: (
    request: ReturnType<typeof parsePurchaseRequest>,
  ) => Promise<VerifiedPointPurchase>;
  revoke: (
    claim: ReconciliationClaim,
    evidence: Record<string, unknown>,
  ) => Promise<{ already_revoked: boolean }>;
  finish: (claim: ReconciliationClaim, error: string | null) => Promise<void>;
};

async function matchesSecret(actual: string, expected: string) {
  const encode = new TextEncoder();
  const [a, b] = await Promise.all(
    [actual, expected].map((value) =>
      crypto.subtle.digest("SHA-256", encode.encode(value))
    ),
  );
  const left = new Uint8Array(a), right = new Uint8Array(b);
  let difference = 0;
  for (let i = 0; i < left.length; i++) difference |= left[i] ^ right[i];
  return difference === 0;
}

export function createReconciliationHandler(deps: Dependencies) {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    });
  return async (req: Request) => {
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405);
    }
    if (deps.secret.length < 32) {
      return json({ error: "reconciliation_not_configured" }, 503);
    }
    const provided =
      req.headers.get("authorization")?.match(/^Bearer (.+)$/)?.[1] ?? "";
    if (!provided || !await matchesSecret(provided, deps.secret)) {
      return json({ error: "unauthorized" }, 401);
    }
    try {
      // No transaction IDs or account IDs are accepted from the request body.
      // Work comes only from leased, previously credited database purchases.
      const claims = await deps.claim();
      const counts = { checked: 0, revoked: 0, alreadyRevoked: 0, failed: 0 };
      let cursor = 0;
      await Promise.all(
        Array.from({ length: Math.min(4, claims.length) }, async () => {
          while (cursor < claims.length) {
            const claim = claims[cursor++];
            let failure: string | null = null;
            try {
              const request = parsePurchaseRequest({
                platform: claim.platform,
                productId: claim.product_id,
                transactionId: claim.transaction_id,
                purchaseToken: claim.purchase_token,
                purchaseType: "POINTS",
              });
              try {
                const verified = await deps.verify(request);
                if (
                  verified.storeAccountId &&
                  verified.storeAccountId !== claim.user_id.toLowerCase()
                ) {
                  throw new PurchaseError("purchase_account_mismatch", 403);
                }
              } catch (error) {
                if (
                  !(error instanceof PurchaseError) ||
                  error.message !== "purchase_revoked" || !error.evidence
                ) throw error;
                const result = await deps.revoke(claim, error.evidence);
                if (result.already_revoked) counts.alreadyRevoked++;
                else counts.revoked++;
              }
              counts.checked++;
            } catch (error) {
              // Never persist provider bodies, credentials or purchase tokens in
              // error messages. Evidence is saved only by the revocation RPC.
              failure = error instanceof PurchaseError
                ? error.message
                : "reconciliation_unavailable";
            }
            try {
              await deps.finish(claim, failure);
            } catch {
              failure = "reconciliation_finish_failed";
            }
            if (failure) counts.failed++;
          }
        }),
      );
      return json(counts);
    } catch {
      return json({ error: "reconciliation_unavailable" }, 503);
    }
  };
}

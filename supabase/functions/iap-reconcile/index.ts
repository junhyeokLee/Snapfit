import { adminClient } from "../_shared/supabase.ts";
import { verifyPurchase } from "../iap-verify/provider.ts";
import { createReconciliationHandler } from "./reconcile.ts";

Deno.serve(createReconciliationHandler({
  secret: Deno.env.get("SNAPFIT_IAP_RECONCILE_SECRET") ?? "",
  claim: async () => {
    const { data, error } = await adminClient().rpc(
      "claim_point_purchase_reconciliation",
      { p_limit: 20 },
    );
    if (error) throw new Error("reconciliation_claim_failed");
    return data ?? [];
  },
  verify: verifyPurchase,
  revoke: async (claim, evidence) => {
    const { data, error } = await adminClient().rpc(
      "revoke_verified_point_purchase",
      {
        p_platform: claim.platform,
        p_transaction_id: claim.transaction_id,
        p_evidence: evidence,
      },
    );
    if (error) throw new Error("point_refund_failed");
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) throw new Error("invalid_point_refund_response");
    return row;
  },
  finish: async (claim, errorCode) => {
    const { error } = await adminClient().rpc(
      "finish_point_purchase_reconciliation",
      {
        p_purchase_id: claim.purchase_id,
        p_lease_id: claim.lease_id,
        p_error: errorCode,
      },
    );
    if (error) throw new Error("reconciliation_finish_failed");
  },
}));

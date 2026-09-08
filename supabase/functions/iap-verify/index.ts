import { corsHeaders } from "../_shared/cors.ts";
import { adminClient, getUser } from "../_shared/supabase.ts";
import {
  createPointPurchaseHandler,
  isPointPurchaseAvailable,
  PurchaseError,
  text,
} from "./point-purchase.ts";
import { verifyPurchase } from "./provider.ts";

async function logOperationalEvent(event: {
  userId: string;
  eventType: string;
  platform: string;
  productId: string;
  transactionId: string;
  pointDelta: number;
}) {
  const { error } = await adminClient().from("ai_album_operational_events")
    .insert({
      user_id: event.userId,
      event_type: event.eventType,
      platform: event.platform,
      product_id: event.productId,
      transaction_id: event.transactionId,
      point_delta: event.pointDelta,
      metadata: { purchaseType: "POINTS" },
    });
  if (error) throw new Error("operational_event_log_failed");
}

Deno.serve(createPointPurchaseHandler({
  authenticate: getUser,
  availability: (platform) =>
    isPointPurchaseAvailable(platform, (name) => Deno.env.get(name)),
  isPointProduct: async (productId) => {
    // Fulfill verified purchases of historical point SKUs too: is_active controls
    // sale/display, not delivery of an already paid package. Subscription SKUs do
    // not exist in this catalog and never reach a provider or entitlement mutation.
    const { data, error } = await adminClient().from("point_products")
      .select("product_id").eq("product_id", productId).maybeSingle();
    if (error) throw new Error("point_product_lookup_failed");
    return Boolean(data);
  },
  verify: verifyPurchase,
  grant: async (userId, purchase) => {
    const { data, error } = await adminClient().rpc(
      "grant_verified_point_purchase",
      {
        p_user_id: userId,
        p_purchase: purchase,
      },
    );
    if (error) {
      const code = text(error.message);
      const forbidden = [
        "purchase_account_mismatch",
        "purchase_owner_mismatch",
        "purchase_account_required",
      ];
      const conflicts = [
        "purchase_legacy_conflict",
        "purchase_identity_conflict",
        "purchase_revoked",
      ];
      if (forbidden.includes(code)) throw new PurchaseError(code, 403);
      if (conflicts.includes(code)) throw new PurchaseError(code, 409);
      if (code === "unknown_point_product") throw new PurchaseError(code);
      throw new Error("point_purchase_grant_failed");
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (
      !row || !Number.isInteger(row.granted_points) ||
      !Number.isInteger(row.remaining_balance)
    ) {
      throw new Error("invalid_point_grant_response");
    }
    return row;
  },
  log: logOperationalEvent,
}, corsHeaders));

import { adminClient, getUser } from "../_shared/supabase.ts";
import type { AiAlbumDraftResponsePayload } from "./index.ts";

export type GenerationReservation = {
  id: string;
  draftId: string;
  cached?: AiAlbumDraftResponsePayload;
};
export interface GenerationGuard {
  authenticate(req: Request): Promise<string>;
  reserve(
    actor: string,
    requestId: string,
    hash: string,
    version: number,
    expectedPointCost: number | null,
    pageCount: number,
  ): Promise<GenerationReservation>;
  complete(
    actor: string,
    id: string,
    result: AiAlbumDraftResponsePayload,
  ): Promise<void>;
  fail(actor: string, id: string): Promise<void>;
}
const allowed = new Set([
  "ai_generation_invalid_request",
  "ai_generation_disabled",
  "ai_generation_request_conflict",
  "ai_generation_in_progress",
  "ai_generation_request_expired",
  "ai_generation_rate_limited",
  "ai_generation_capacity_limited",
  "ai_generation_price_unavailable",
  "ai_generation_insufficient_points",
  "ai_generation_not_pending",
  "ai_generation_invalid_result",
  "ai_generation_v3_not_validated",
  "ai_generation_price_confirmation_required", "ai_generation_price_changed",
]);
export function generationGuard(): GenerationGuard {
  async function rpc(
    name: string,
    params: Record<string, unknown>,
  ): Promise<unknown> {
    const { data, error } = await adminClient().rpc(name, params);
    if (error) {
      throw new Error(
        allowed.has(error.message)
          ? error.message
          : "ai_generation_guard_unavailable",
      );
    }
    return data;
  }
  return {
    async authenticate(req) {
      if (!/^Bearer\s+\S+$/i.test(req.headers.get("Authorization") ?? "")) {
        throw new Error("ai_generation_auth_required");
      }
      try {
        const user = await getUser(req);
        if (user.is_anonymous) throw new Error("anonymous");
        return user.id;
      } catch {
        throw new Error("ai_generation_auth_required");
      }
    },
    async reserve(actor, requestId, hash, version, expectedPointCost, pageCount) {
      const data = await rpc("prepare_ai_template_generation", {
        p_actor: actor,
        p_request_id: requestId,
        p_brief_hash: hash,
        p_design_version: version,
        p_expected_point_cost: expectedPointCost,
        p_page_count: pageCount,
      });
      if (
        !data || typeof data !== "object" || !("id" in data) ||
        !("draftId" in data)
      ) throw new Error("ai_generation_guard_unavailable");
      return data as GenerationReservation;
    },
    async complete(actor, id, result) {
      await rpc("complete_ai_template_generation", {
        p_actor: actor,
        p_id: id,
        p_result: result,
      });
    },
    async fail(actor, id) {
      await rpc("fail_ai_template_generation", { p_actor: actor, p_id: id });
    },
  };
}

export async function readGenerationBody(
  req: Request,
): Promise<Record<string, unknown>> {
  if (!req.body) throw new Error("invalid_request");
  const reader = req.body.getReader(), chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 65536) {
        await reader.cancel();
        throw new Error("ai_generation_request_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const body = JSON.parse(new TextDecoder().decode(bytes));
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error();
    }
    return body;
  } catch {
    throw new Error("invalid_request");
  }
}
export async function generationHash(value: unknown): Promise<string> {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(value)),
  );
  return [...new Uint8Array(bytes)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}
export function generationStatus(code: string): number | undefined {
  if (code === "ai_generation_private_input_forbidden") return 400;
  if (code === "template_provider_rate_limited" || code === "template_provider_capacity_unavailable") return 429;
  if (code === "template_generation_timeout") return 504;
  if (["template_generation_incomplete", "template_generation_invalid_json", "template_provider_request_rejected"].includes(code)) return 502;
  if (code.startsWith("template_provider_")) return 503;
  if(code==='ai_generation_preview_forbidden')return 403;
  if(code==='invalid_preview_storage_uri')return 400;
  if (code === "ai_generation_auth_required") return 401;
  if (code === "ai_generation_insufficient_points") return 402;
  if (code === "ai_generation_request_too_large") return 413;
  if (
    [
      "ai_generation_in_progress",
      "ai_generation_request_conflict",
      "ai_generation_request_expired",
    ].includes(code)
  ) return 409;
  if (
    ["ai_generation_rate_limited", "ai_generation_capacity_limited"].includes(
      code,
    )
  ) return 429;
  if (["ai_generation_invalid_request","ai_generation_price_confirmation_required","ai_generation_price_changed"].includes(code)) return 400;
  if (code.startsWith("ai_generation_")) return 503;
}

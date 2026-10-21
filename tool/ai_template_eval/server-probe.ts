import { originalBookCases } from "./cases.ts";
import { evaluateCase } from "./evaluate.ts";
import { freeGeminiTemplateModels } from "../../supabase/functions/ai-album-draft/template-model-provider.ts";
import type { TemplateModelCheckpoint } from "../../supabase/functions/ai-album-draft/template-model-checkpoint.ts";

type ProbeOptions = {
  tokenHash: string;
  expiresAt: number;
  model?: typeof freeGeminiTemplateModels[number];
  checkpoint?: TemplateModelCheckpoint;
};
type Dependencies = {
  now?: () => number;
  key?: () => string | undefined;
  evaluate?: typeof evaluateCase;
};
const allowedCases = new Set([
  "travel-square",
  "wedding-portrait",
  "growth-landscape",
]);

async function hasPayload(req: Request): Promise<boolean> {
  if (!req.body) return false;
  const reader = req.body.getReader();
  try {
    const first = await reader.read();
    if (first.done) return false;
    await reader.cancel();
    return true;
  } finally {
    reader.releaseLock();
  }
}

export async function probeTokenHash(token: string) {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return [...new Uint8Array(bytes)].map((v) => v.toString(16).padStart(2, "0"))
    .join("");
}

// Temporary synthetic-only deployment; never expose this as a customer endpoint.
// The deployment must retain Supabase JWT verification and be deleted after use.
export function createSyntheticProbe(
  options: ProbeOptions,
  dependencies: Dependencies = {},
) {
  const now = dependencies.now ?? Date.now;
  const model = options.model ?? "gemini-3.6-flash";
  if (
    !/^[a-f0-9]{64}$/.test(options.tokenHash) ||
    !Number.isSafeInteger(options.expiresAt) ||
    options.expiresAt <= now() || options.expiresAt > now() + 30 * 60_000 ||
    !(freeGeminiTemplateModels as readonly string[]).includes(model)
  ) throw new Error("invalid_probe_configuration");
  const used = new Set<string>();
  const response = (status: number, value: unknown) =>
    Response.json(value, {
      status,
      headers: { "Cache-Control": "no-store" },
    });
  return async (req: Request): Promise<Response> => {
    if (now() >= options.expiresAt) {
      return response(410, { error: "evaluation_expired" });
    }
    if (req.method !== "POST") return response(405, { error: "method" });
    const token = req.headers.get("x-evaluation-token") ?? "";
    if (
      !/^Bearer \S+$/.test(req.headers.get("Authorization") ?? "") ||
      token.length < 32 || token.length > 128 ||
      await probeTokenHash(token) !== options.tokenHash
    ) return response(401, { error: "evaluation_auth_required" });
    const url = new URL(req.url), id = url.searchParams.get("case");
    if (
      await hasPayload(req) ||
      [...url.searchParams.keys()].some((key) => key !== "case") ||
      url.searchParams.getAll("case").length !== 1 ||
      !id || !allowedCases.has(id)
    ) return response(400, { error: "synthetic_case_required" });
    if (used.has(id)) return response(409, { error: "evaluation_already_run" });
    const key = (dependencies.key ?? (() => Deno.env.get("GEMINI_API_KEY")))();
    if (!key) return response(503, { error: "provider_not_configured" });
    used.add(id);
    try {
      const result = await (dependencies.evaluate ?? evaluateCase)(
        originalBookCases.find((entry) => entry.id === id)!,
        {
          apiKey: key,
          provider: "gemini",
          model,
          freeOnly: true,
          checkpoint: options.checkpoint,
          env: (name) =>
            name === "AI_TEMPLATE_TIMEOUT_MS" ? "120000" : undefined,
          fetch,
        },
      );
      return response(200, result);
    } catch {
      return response(503, { error: "evaluation_unavailable" });
    }
  };
}

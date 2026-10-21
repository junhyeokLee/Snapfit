import { jsonResponse } from "../_shared/cors.ts";
import { generationHash } from "./generation-guard.ts";
import {
  assertSafeJobBody,
  parseSafeTemplateOptions,
  safeTemplateBrief,
} from "./template-safe-options.ts";
import {
  type FreeTemplateCheckpoint,
  runFreeTemplateStep,
} from "./template-free-step.ts";
import {
  type TemplateModelEnv,
  TemplateModelFailure,
  type TemplateModelFetcher,
} from "./template-model-provider.ts";
import type { AiAlbumDraftResponsePayload } from "./index.ts";
import type { OriginalBook } from "./template-composition.ts";

export type FreeJobDatabase = {
  rpc(
    name: string,
    params: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
};
const publicErrors = new Set([
  "ai_generation_invalid_request",
  "ai_generation_private_input_forbidden",
  "ai_generation_disabled",
  "ai_generation_request_conflict",
  "ai_generation_in_progress",
  "ai_generation_request_expired",
  "ai_generation_rate_limited",
  "ai_generation_capacity_limited",
  "ai_generation_price_unavailable",
  "ai_generation_insufficient_points",
  "ai_generation_price_confirmation_required",
  "ai_generation_price_changed",
  "ai_generation_lease_lost",
  "ai_generation_not_pending",
  "ai_generation_invalid_result",
]);
export async function freeJobRpc(
  database: FreeJobDatabase,
  name: string,
  params: Record<string, unknown>,
) {
  const result = await database.rpc(name, params);
  if (result.error) {
    const message = (result.error as { message?: unknown }).message;
    throw new Error(
      typeof message === "string" && publicErrors.has(message)
        ? message
        : "ai_generation_guard_unavailable",
    );
  }
  return result.data;
}

// Called only after the main endpoint has verified the current nonanonymous user.
// A status read never starts a model call; only the private scheduled worker can.
export async function handleFreeTemplateJob(
  actor: string,
  body: Record<string, unknown>,
  database: FreeJobDatabase,
): Promise<Response> {
  assertSafeJobBody(body);
  let result: unknown;
  if (body.action === "create") {
    const options = parseSafeTemplateOptions(body.safeDesign);
    const price = body.expectedPointCost;
    if (
      typeof price !== "number" || !Number.isInteger(price) || price < 0 ||
      price > 1000000
    ) {
      throw new Error("ai_generation_price_confirmation_required");
    }
    result = await freeJobRpc(database, "prepare_free_ai_template_job", {
      p_actor: actor,
      p_request_id: body.generationRequestId,
      p_hash: await generationHash({ options, expectedPointCost: price }),
      p_options: options,
      p_expected_point_cost: price,
      p_page_count: options.pageCount,
    });
  } else if (body.action === "cancel") {
    result = await freeJobRpc(database, "cancel_free_ai_template_job", {
      p_actor: actor,
      p_request_id: body.generationRequestId,
    });
  } else {
    result = await freeJobRpc(database, "read_free_ai_template_job", {
      p_actor: actor,
      p_request_id: body.action === "latest" ? null : body.generationRequestId,
    });
  }
  const envelope = result && typeof result === "object"
    ? result
    : { job: null };
  const state = (envelope as { job?: { state?: string } }).job?.state;
  const response = jsonResponse(
    envelope,
    ["queued", "running", "waiting"].includes(state ?? "") ? 202 : 200,
  );
  response.headers.set("Cache-Control", "no-store");
  if (["queued", "running", "waiting"].includes(state ?? "")) {
    response.headers.set("Retry-After", "30");
  }
  return response;
}

function draftForBook(
  design: OriginalBook,
  draftId: string,
  provider: string,
  model: string,
): AiAlbumDraftResponsePayload {
  return {
    draftId,
    modelProvider: provider as "gemini",
    modelName: model,
    title: design.concept,
    pageCount: design.generation.pageCount,
    templateTone: design.concept,
    summary: design.rationale,
    design,
    recommendedPhotos: [],
    excludedPhotos: [],
    storySections: [],
    curationNotes: [],
    templateSlots: design.pages.flatMap((page, pageIndex) =>
      page.elements.filter((e) => e.kind === "photo").map((e) => ({
        slotId: e.id,
        pageIndex,
        role: pageIndex === 0 ? "cover" : "photo",
        hint: page.purpose,
      }))
    ),
    requiresUserReview: true,
    alreadyCreatedAlbum: false,
    reviewCtaLabel: "이 디자인으로 편집하기",
    provider: "advanced",
    fallbackUsed: false,
  };
}

export function secondsToPacificMidnight(now: number): number {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Los_Angeles",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const day = formatter.format(now);
  // Search the next civil-day boundary so daylight-saving transitions are safe.
  let lo = now, hi = now + 27 * 3600000;
  while (hi - lo > 1000) {
    const middle = Math.floor((lo + hi) / 2);
    if (formatter.format(middle) === day) lo = middle;
    else hi = middle;
  }
  return Math.max(60, Math.ceil((hi - now) / 1000) + 60);
}

const retryable = new Set([
  "template_provider_rate_limited",
  "template_provider_capacity_unavailable",
  "template_provider_unavailable",
  "template_generation_timeout",
]);
export function freeTemplateRetry(
  error: unknown,
  failures: number,
  now: number,
) {
  const code = error instanceof Error ? error.message : "server_error";
  if (!retryable.has(code)) return null;
  const exponential = Math.min(
    3600,
    60 * 2 ** Math.min(6, Math.max(0, failures)),
  );
  const provider = error instanceof TemplateModelFailure ? error : undefined;
  return {
    code,
    seconds: Math.max(
      exponential,
      provider?.retryAfterSeconds ?? 0,
      provider?.quotaScope === "daily" ? secondsToPacificMidnight(now) : 0,
    ),
  };
}

type ClaimedJob = {
  id: string;
  actor: string;
  requestId: string;
  draftId: string;
  safeOptions: unknown;
  checkpoint?: FreeTemplateCheckpoint | null;
  leaseOwner: string;
  attempts: number;
  consecutiveFailures: number;
  stage?: string;
};
export type FreeWorkerOptions = {
  env?: TemplateModelEnv;
  fetch?: TemplateModelFetcher;
  now?: () => number;
  step?: typeof runFreeTemplateStep;
};

export async function advanceOneFreeTemplateJob(
  database: FreeJobDatabase,
  options: FreeWorkerOptions = {},
) {
  const claimed = await freeJobRpc(
    database,
    "claim_free_ai_template_job",
    {},
  ) as ClaimedJob | null;
  if (!claimed) return { advanced: false };
  const identity = { p_id: claimed.id, p_owner: claimed.leaseOwner };
  let stage = claimed.stage ?? "direction";
  try {
    const safe = parseSafeTemplateOptions(claimed.safeOptions);
    const result = await (options.step ?? runFreeTemplateStep)(
      safeTemplateBrief(safe),
      {
        env: options.env,
        fetch: options.fetch,
        checkpoint: claimed.checkpoint ?? undefined,
        onCheckpoint: async (checkpoint) => {
          await freeJobRpc(database, "save_free_ai_template_checkpoint", {
            ...identity,
            p_checkpoint: checkpoint,
            p_stage: stage,
          });
        },
      },
    );
    stage = result.stage;
    await freeJobRpc(database, "settle_free_ai_template_job", {
      ...identity,
      p_state: result.design ? "ready" : "queued",
      p_stage: stage,
      p_retry_seconds: 65,
      p_error: null,
      p_result: result.design
        ? draftForBook(
          result.design,
          claimed.draftId,
          result.modelProvider,
          result.modelName,
        )
        : null,
    });
    return { advanced: true, complete: Boolean(result.design) };
  } catch (error) {
    const retry = freeTemplateRetry(
      error,
      claimed.consecutiveFailures,
      (options.now ?? Date.now)(),
    );
    const code = error instanceof Error ? error.message : "server_error";
    // A lost lease must never release a newer worker's lease or overwrite it.
    if (
      code === "ai_generation_lease_lost" ||
      code === "ai_generation_not_pending"
    ) return { advanced: false };
    // Persistence errors leave the claim fenced until recovery. A new model
    // request must not follow an unconfirmed DB write within this invocation.
    if (
      code === "ai_generation_guard_unavailable" ||
      code === "template_checkpoint_persistence_failed"
    ) throw error;
    await freeJobRpc(database, "settle_free_ai_template_job", {
      ...identity,
      p_state: retry ? "waiting" : "failed",
      p_stage: stage,
      p_retry_seconds: retry?.seconds ?? 65,
      p_error: retry?.code ??
        (code.startsWith("template_provider_")
          ? code
          : code.startsWith("template_")
          ? "template_quality_failed"
          : "ai_generation_failed"),
      p_result: null,
    });
    return { advanced: false, waiting: Boolean(retry) };
  }
}

import { createOriginalTemplate } from "../../supabase/functions/ai-album-draft/index.ts";
import {
  decodeTemplateModelOutput,
  templateModelEndpoint,
  type TemplateModelEnv,
  type TemplateModelProviderName,
} from "../../supabase/functions/ai-album-draft/template-model-provider.ts";
import {
  validateArtDirection,
  validateDirectedTemplate,
} from "../../supabase/functions/ai-album-draft/template-art-direction.ts";
import type { EvaluationCase } from "./cases.ts";
import type { TemplateModelCheckpoint } from "../../supabase/functions/ai-album-draft/template-model-checkpoint.ts";
import {
  validateCompositionBatch,
  validateOriginalPlan,
} from "../../supabase/functions/ai-album-draft/template-composition.ts";

export type Trace = {
  stage: "plan" | "layout" | "direction" | "composition" | "review";
  attempt: number;
  durationMs: number;
  status: number | null;
  model: string;
  provider: TemplateModelProviderName;
  transportAttempt?: number;
  finishReason?: string;
  usage?: {
    inputTokens: number;
    outputTokens: number;
    thinkingTokens?: number;
  };
  output?: unknown;
  validationError?: string;
  errorCode?: string;
};
export type CaseResult = EvaluationCase & {
  status: "accepted" | "rejected" | "skipped";
  reason?: string;
  durationMs: number;
  attempts: Trace[];
  document?: unknown;
  checkpoint?: TemplateModelCheckpoint;
  continuation?: { resumed: boolean; cacheHits: number };
};
type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;
export type EvaluationModelOptions = {
  apiKey: string;
  model: string;
  provider?: TemplateModelProviderName;
  freeOnly?: boolean;
  env?: TemplateModelEnv;
  checkpoint?: TemplateModelCheckpoint;
};
const providerCodes = new Set([
  "insufficient_quota",
  "credit_balance_exhausted",
  "invalid_api_key",
  "model_not_found",
  "rate_limit_exceeded",
  "RESOURCE_EXHAUSTED",
  "UNAUTHENTICATED",
  "PERMISSION_DENIED",
  "NOT_FOUND",
  "INVALID_ARGUMENT",
  "UNAVAILABLE",
]);
function safeError(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  return /^template_[a-z_]+(?::\d+)*$/.test(message)
    ? message
    : "evaluation_request_failed";
}
export async function evaluateCase(
  entry: EvaluationCase,
  options: EvaluationModelOptions & { fetch: Fetcher },
): Promise<CaseResult> {
  const provider = options.provider ?? "gemini";
  const attempts: Trace[] = [];
  const requestAttempts = new Map<string, number>();
  const start = performance.now();
  let latestCheckpoint = options.checkpoint, cacheHits = 0;
  const tracked: Fetcher = async (input, init) => {
    if (
      String(input) !==
        templateModelEndpoint({ provider, model: options.model })
    ) {
      throw new Error("evaluation_endpoint_rejected");
    }
    const request = JSON.parse(String(init?.body));
    const fingerprint = String(init?.body);
    const transportAttempt = (requestAttempts.get(fingerprint) ?? 0) + 1;
    requestAttempts.set(fingerprint, transportAttempt);
    const rawPrompt = JSON.parse(
      provider === "gemini"
        ? request.contents[0].parts[0].text
        : request.messages[1].content,
    );
    const prompt = rawPrompt.originalRequest
      ? JSON.parse(rawPrompt.originalRequest)
      : rawPrompt;
    const stage = entry.brief.designVersion === 3
      ? (prompt.book
        ? "review"
        : Array.isArray(prompt.indexes)
        ? "composition"
        : "direction")
      : (prompt.artDirection ? "layout" : "plan");
    const historyLength = provider === "gemini"
      ? request.contents.length
      : request.messages.length - 1;
    const trace: Trace = {
      stage,
      attempt: historyLength > 1 || rawPrompt.originalRequest ||
          prompt.repairFeedback ||
          (stage === "review" && attempts.some((t) => t.stage === "review"))
        ? 2
        : 1,
      durationMs: 0,
      status: null,
      provider,
      model: options.model,
      transportAttempt,
    };
    attempts.push(trace);
    const started = performance.now();
    try {
      const response = await options.fetch(input, init);
      trace.status = response.status;
      const raw = await response.clone().json().catch(() => null);
      if (!response.ok) {
        const code = provider === "gemini"
          ? raw?.error?.status
          : raw?.error?.code;
        trace.errorCode = providerCodes.has(code)
          ? code
          : `http_${response.status}`;
      } else if (raw) {
        const decoded = decodeTemplateModelOutput(provider, raw);
        trace.finishReason = decoded.finishReason;
        if (decoded.usage) trace.usage = decoded.usage;
        const content = decoded.content;
        if (typeof content === "string") {
          // Only model content is recorded, never request headers or credentials.
          const redacted = options.apiKey
            ? content.split(options.apiKey).join("[REDACTED]")
            : content;
          try {
            trace.output = JSON.parse(redacted);
          } catch {
            trace.output = redacted;
            trace.validationError = "invalid_json";
          }
          if (!trace.validationError) {
            try {
              if (trace.stage === "direction") {
                validateOriginalPlan(trace.output, entry.brief);
              } else if (trace.stage === "composition") {
                validateCompositionBatch(
                  trace.output,
                  prompt.indexes,
                  entry.brief,
                  prompt.direction,
                );
              } else if (trace.stage === "review") {
                // The production engine checks evidence and consistency against the entire book.
              } else if (trace.stage === "plan") {
                validateArtDirection(trace.output, entry.brief);
              } else {validateDirectedTemplate(
                  trace.output,
                  entry.brief,
                  prompt.artDirection,
                );}
            } catch (error) {
              trace.validationError = safeError(error);
            }
          }
        }
      }
      return response;
    } catch {
      trace.errorCode = init?.signal?.aborted
        ? "template_generation_timeout"
        : "request_failed";
      throw new Error("evaluation_request_failed");
    } finally {
      trace.durationMs = Math.round(performance.now() - started);
    }
  };
  try {
    const draft = await createOriginalTemplate(entry.brief, {
      checkpoint: options.checkpoint,
      onCheckpoint: (checkpoint) => {
        latestCheckpoint = JSON.parse(
          JSON.stringify(checkpoint).split(options.apiKey).join("[REDACTED]"),
        );
      },
      onModelReplay: () => {
        cacheHits++;
      },
      fetch: tracked,
      env: (key) => {
        if (key === "AI_TEMPLATE_PROVIDER") return provider;
        if (key === "AI_TEMPLATE_MODEL") return options.model;
        if (key === "AI_TEMPLATE_FREE_ONLY") {
          return String(options.freeOnly ?? true);
        }
        if (
          key === (provider === "gemini" ? "GEMINI_API_KEY" : "OPENAI_API_KEY")
        ) return options.apiKey;
        return options.env?.(key);
      },
    });
    // The exact server document is retained; evaluations never enter billing or storage.
    const document = JSON.parse(
      JSON.stringify(draft.design).split(options.apiKey || "\u0000").join(
        "[REDACTED]",
      ),
    );
    return {
      ...entry,
      status: "accepted",
      durationMs: Math.round(performance.now() - start),
      attempts,
      document,
      continuation: { resumed: !!options.checkpoint, cacheHits },
    };
  } catch (error) {
    const code = safeError(error);
    const providerFailure = code.startsWith("template_provider_") ||
      code === "evaluation_request_failed";
    return {
      ...entry,
      status: "rejected",
      reason: providerFailure
        ? attempts.findLast((t) => t.errorCode)?.errorCode ?? code
        : code,
      durationMs: Math.round(performance.now() - start),
      attempts,
      continuation: { resumed: !!options.checkpoint, cacheHits },
      ...((code === "template_provider_unavailable" ||
          code === "template_generation_timeout") && latestCheckpoint
        ? { checkpoint: latestCheckpoint }
        : {}),
    };
  }
}
export function stopReason(result: CaseResult): string | undefined {
  if (result.status !== "rejected") return;
  return result.reason === "template_quality_failed"
    ? undefined
    : result.reason;
}
export async function evaluateSuite(
  cases: EvaluationCase[],
  options: EvaluationModelOptions & {
    fetchFor: (entry: EvaluationCase) => Fetcher;
    onResult?: (result: CaseResult) => Promise<void>;
  },
): Promise<CaseResult[]> {
  const results: CaseResult[] = [];
  let stopped: string | undefined;
  for (const entry of cases) {
    const result: CaseResult = stopped
      ? {
        ...entry,
        status: "skipped",
        reason: stopped,
        durationMs: 0,
        attempts: [],
      }
      : await evaluateCase(entry, {
        ...options,
        fetch: options.fetchFor(entry),
      });
    results.push(result);
    if (!stopped) stopped = stopReason(result);
    await options.onResult?.(result);
  }
  return results;
}
export function summarize(results: CaseResult[]) {
  const attempted = results.filter((r) => r.status !== "skipped");
  const calls = results.flatMap((r) => r.attempts);
  const known = calls.filter((t) => t.usage);
  return {
    attempted: attempted.length,
    accepted: results.filter((r) => r.status === "accepted").length,
    rejected: results.filter((r) => r.status === "rejected").length,
    skipped: results.filter((r) => r.status === "skipped").length,
    firstPassAccepted:
      results.filter((r) =>
        r.status === "accepted" && !r.attempts.some((t) => t.attempt === 2)
      ).length,
    correctedAccepted:
      results.filter((r) =>
        r.status === "accepted" && r.attempts.some((t) => t.attempt === 2)
      ).length,
    modelCalls: calls.length,
    usageComplete: calls.length > 0 && known.length === calls.length,
    inputTokens: known.reduce((n, t) => n + t.usage!.inputTokens, 0),
    outputTokens: known.reduce((n, t) => n + t.usage!.outputTokens, 0),
    thinkingTokens: known.reduce(
      (n, t) => n + (t.usage!.thinkingTokens ?? 0),
      0,
    ),
    aestheticVerdict: "not_reviewed",
    estimatedCostUsd: null,
  };
}

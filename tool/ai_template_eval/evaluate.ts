import { createOriginalTemplate } from "../../supabase/functions/ai-album-draft/index.ts";
import {
  validateArtDirection,
  validateDirectedTemplate,
} from "../../supabase/functions/ai-album-draft/template-art-direction.ts";
import type { EvaluationCase } from "./cases.ts";

export type Trace = {
  stage: "plan" | "layout";
  attempt: number;
  durationMs: number;
  status: number | null;
  model: string;
  finishReason?: string;
  usage?: { inputTokens: number; outputTokens: number };
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
};
type Fetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;
const providerCodes = new Set([
  "insufficient_quota",
  "credit_balance_exhausted",
  "invalid_api_key",
  "model_not_found",
  "rate_limit_exceeded",
]);
function safeError(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  return /^template_[a-z_]+$/.test(message)
    ? message
    : "evaluation_request_failed";
}
export async function evaluateCase(
  entry: EvaluationCase,
  options: { apiKey: string; model: string; fetch: Fetcher },
): Promise<CaseResult> {
  const attempts: Trace[] = [];
  const start = performance.now();
  const tracked: Fetcher = async (input, init) => {
    if (String(input) !== "https://api.openai.com/v1/chat/completions") {
      throw new Error("evaluation_endpoint_rejected");
    }
    const request = JSON.parse(String(init?.body));
    const prompt = JSON.parse(request.messages[1].content);
    const trace: Trace = {
      stage: prompt.artDirection ? "layout" : "plan",
      attempt: request.messages.length > 2 ? 2 : 1,
      durationMs: 0,
      status: null,
      model: request.model,
    };
    attempts.push(trace);
    const started = performance.now();
    try {
      const response = await options.fetch(input, init);
      trace.status = response.status;
      const raw = await response.clone().json().catch(() => null);
      if (!response.ok) {
        const code = raw?.error?.code;
        trace.errorCode = providerCodes.has(code)
          ? code
          : `http_${response.status}`;
      } else if (raw) {
        trace.finishReason = String(
          raw.choices?.[0]?.finish_reason ?? "missing",
        );
        if (
          Number.isFinite(raw.usage?.prompt_tokens) &&
          Number.isFinite(raw.usage?.completion_tokens)
        ) {
          trace.usage = {
            inputTokens: raw.usage.prompt_tokens,
            outputTokens: raw.usage.completion_tokens,
          };
        }
        const content = raw.choices?.[0]?.message?.content;
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
              if (trace.stage === "plan") {
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
      trace.errorCode = "request_failed";
      throw new Error("evaluation_request_failed");
    } finally {
      trace.durationMs = Math.round(performance.now() - started);
    }
  };
  try {
    const draft = await createOriginalTemplate(entry.brief, {
      fetch: tracked,
      env: (key) =>
        key === "OPENAI_API_KEY"
          ? options.apiKey
          : key === "AI_TEMPLATE_MODEL"
          ? options.model
          : undefined,
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
    };
  } catch (error) {
    return {
      ...entry,
      status: "rejected",
      reason: attempts.find((t) => t.errorCode)?.errorCode ?? safeError(error),
      durationMs: Math.round(performance.now() - start),
      attempts,
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
  options: {
    apiKey: string;
    model: string;
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
    aestheticVerdict: "not_reviewed",
    estimatedCostUsd: null,
  };
}

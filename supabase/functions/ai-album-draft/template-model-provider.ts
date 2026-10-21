export type TemplateModelProviderName = "gemini" | "openai";
export type TemplateModelEnv = (key: string) => string | undefined;
export type TemplateModelFetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;
export type TemplateModelMessage = {
  role: "user" | "assistant";
  content: string;
};
export type TemplateModelRequest = {
  name: string;
  system: string;
  messages: TemplateModelMessage[];
  schema?: Record<string, unknown>;
  maxTokens: number;
};
export type TemplateModelOutput = {
  content: string;
  finishReason: string;
  complete: boolean;
  usage?: { inputTokens: number; outputTokens: number; thinkingTokens: number };
};
export type TemplateModelConfig = {
  provider: TemplateModelProviderName;
  model: string;
  apiKey: string;
  freeOnly: boolean;
  minIntervalMs: number;
  timeoutMs: number;
  transientRetries: number;
  retryBaseMs: number;
};

// A free-capable model is not proof that the associated Google project is free.
// Deploy only a Free-tier project key; never fall back to a paid provider.
export const freeGeminiTemplateModels = [
  "gemini-3.8-flash",
  "gemini-3.6-flash",
  "gemini-2.5-flash",
] as const;
const defaults = {
  gemini: {
    model: "gemini-3.6-flash",
    key: "GEMINI_API_KEY",
    interval: 1200,
    timeout: 120000,
  },
  openai: {
    model: "gpt-4o",
    key: "OPENAI_API_KEY",
    interval: 0,
    timeout: 90000,
  },
} as const;

function integer(
  value: string | undefined,
  fallback: number,
  min: number,
  max: number,
) {
  if (value === undefined || value.trim() === "") return fallback;
  if (!/^\d+$/.test(value)) throw new Error("template_provider_invalid_config");
  const result = Number(value);
  if (!Number.isSafeInteger(result) || result < min || result > max) {
    throw new Error("template_provider_invalid_config");
  }
  return result;
}

export function resolveTemplateModelConfig(
  env: TemplateModelEnv,
): TemplateModelConfig {
  const provider = env("AI_TEMPLATE_PROVIDER")?.trim() || "gemini";
  if (provider !== "gemini" && provider !== "openai") {
    throw new Error("template_provider_unsupported");
  }
  const freeValue = env("AI_TEMPLATE_FREE_ONLY")?.trim() || "true";
  if (freeValue !== "true" && freeValue !== "false") {
    throw new Error("template_provider_invalid_config");
  }
  const freeOnly = freeValue === "true";
  const entry = defaults[provider];
  const model = env("AI_TEMPLATE_MODEL")?.trim() ||
    env(provider === "gemini" ? "GEMINI_MODEL" : "OPENAI_MODEL")?.trim() ||
    entry.model;
  if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,100}$/.test(model)) {
    throw new Error("template_provider_invalid_config");
  }
  if (
    freeOnly && (provider !== "gemini" ||
      !(freeGeminiTemplateModels as readonly string[]).includes(model))
  ) {
    throw new Error("template_provider_free_only");
  }
  if (provider === "gemini" && !model.startsWith("gemini-")) {
    throw new Error("template_provider_invalid_config");
  }
  if (provider === "openai" && model.startsWith("gemini-")) {
    throw new Error("template_provider_invalid_config");
  }
  if (/(?:^|[-_.])(image|audio|tts|live|embedding)(?:[-_.]|$)/i.test(model)) {
    throw new Error("template_provider_model_not_supported");
  }
  const apiKey = env(entry.key)?.trim() || "";
  if (!apiKey) throw new Error("template_provider_not_configured");
  return {
    provider,
    model,
    apiKey,
    freeOnly,
    minIntervalMs: integer(
      env("AI_TEMPLATE_MIN_CALL_INTERVAL_MS"),
      entry.interval,
      0,
      15000,
    ),
    timeoutMs: integer(
      env("AI_TEMPLATE_TIMEOUT_MS"),
      entry.timeout,
      1000,
      130000,
    ),
    transientRetries: integer(
      env("AI_TEMPLATE_MAX_TRANSIENT_RETRIES"),
      provider === "gemini" && freeOnly ? 2 : 0,
      0,
      2,
    ),
    retryBaseMs: integer(env("AI_TEMPLATE_RETRY_BASE_MS"), 1200, 0, 5000),
  };
}

export function assertTemplateCustomerDataAllowed(
  config: TemplateModelConfig,
  env: TemplateModelEnv,
) {
  if (
    config.provider === "gemini" &&
    env("AI_TEMPLATE_ALLOW_UNPAID_USER_DATA") !== "true"
  ) {
    throw new Error("ai_generation_privacy_review_required");
  }
}

export function templateModelEndpoint(
  config: Pick<TemplateModelConfig, "provider" | "model">,
) {
  return config.provider === "gemini"
    ? `https://generativelanguage.googleapis.com/v1beta/models/${config.model}:generateContent`
    : "https://api.openai.com/v1/chat/completions";
}

function tokenCount(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}

export function decodeTemplateModelOutput(
  provider: TemplateModelProviderName,
  payload: unknown,
): TemplateModelOutput {
  const data = payload as Record<string, any> | null;
  if (provider === "gemini") {
    const candidate = data?.candidates?.[0];
    const parts = candidate?.content?.parts;
    const content = Array.isArray(parts)
      ? parts.filter((part) =>
        part?.thought !== true && typeof part?.text === "string"
      )
        .map((part) => part.text).join("")
      : "";
    const raw = data?.usageMetadata;
    const thinking = tokenCount(raw?.thoughtsTokenCount)
      ? raw.thoughtsTokenCount
      : 0;
    return {
      content,
      finishReason: typeof candidate?.finishReason === "string"
        ? candidate.finishReason
        : "missing",
      complete: candidate?.finishReason === "STOP" &&
        !data?.promptFeedback?.blockReason &&
        Array.isArray(parts) && parts.every((part) =>
          typeof part?.text === "string"
        ) && content.trim().length > 0,
      ...(tokenCount(raw?.promptTokenCount) &&
          tokenCount(raw?.candidatesTokenCount)
        ? {
          usage: {
            inputTokens: raw.promptTokenCount,
            outputTokens: raw.candidatesTokenCount + thinking,
            thinkingTokens: thinking,
          },
        }
        : {}),
    };
  }
  const choice = data?.choices?.[0];
  const content = typeof choice?.message?.content === "string"
    ? choice.message.content
    : "";
  const raw = data?.usage;
  return {
    content,
    finishReason: typeof choice?.finish_reason === "string"
      ? choice.finish_reason
      : "missing",
    complete: choice?.finish_reason === "stop" && !choice?.message?.refusal &&
      content.trim().length > 0,
    ...(tokenCount(raw?.prompt_tokens) && tokenCount(raw?.completion_tokens)
      ? {
        usage: {
          inputTokens: raw.prompt_tokens,
          outputTokens: raw.completion_tokens,
          thinkingTokens: 0,
        },
      }
      : {}),
  };
}

export class TemplateModelFailure extends Error {
  constructor(
    code: string,
    readonly retryAfterSeconds?: number,
    readonly quotaScope: "daily" | "unknown" = "unknown",
  ) {
    super(code);
    this.name = "TemplateModelFailure";
  }
}

async function responseFailure(response: Response): Promise<never> {
  const rawRetry = response.headers.get("Retry-After")?.trim();
  const seconds = rawRetry && /^\d+(?:\.\d+)?$/.test(rawRetry)
    ? Number(rawRetry)
    : rawRetry
    ? (Date.parse(rawRetry) - Date.now()) / 1000
    : NaN;
  let retry = Number.isFinite(seconds) && seconds > 0
    ? Math.min(Math.ceil(seconds), 86400)
    : undefined;
  let quotaScope: "daily" | "unknown" = "unknown";
  if (response.status === 429) {
    // Retain only machine-readable retry/quota classification, never provider
    // messages, subjects, project IDs, quota dimensions or arbitrary error text.
    try {
      const reader = response.body?.getReader();
      if (reader) {
        const chunks: Uint8Array[] = [];
        let total = 0;
        try {
          while (true) {
            const part = await reader.read();
            if (part.done) break;
            total += part.value.byteLength;
            if (total > 32768) {
              await reader.cancel();
              break;
            }
            chunks.push(part.value);
          }
          if (total <= 32768) {
            const bytes = new Uint8Array(total);
            let offset = 0;
            for (const chunk of chunks) {
              bytes.set(chunk, offset);
              offset += chunk.byteLength;
            }
            const payload = JSON.parse(new TextDecoder().decode(bytes));
            const details = payload?.error?.details;
            if (Array.isArray(details)) {
              for (const detail of details.slice(0, 20)) {
                if (
                  detail?.["@type"] ===
                    "type.googleapis.com/google.rpc.RetryInfo" &&
                  typeof detail.retryDelay === "string" &&
                  /^\d+(?:\.\d{1,9})?s$/.test(detail.retryDelay)
                ) {
                  const delay = Math.min(
                    Math.ceil(Number(detail.retryDelay.slice(0, -1))),
                    86400,
                  );
                  if (delay > 0) retry = Math.max(retry ?? 0, delay);
                }
                if (
                  detail?.["@type"] ===
                    "type.googleapis.com/google.rpc.QuotaFailure" &&
                  Array.isArray(detail.violations)
                ) {
                  for (const violation of detail.violations.slice(0, 20)) {
                    if (
                      [violation?.quotaId, violation?.quotaMetric].some((
                        value,
                      ) =>
                        typeof value === "string" && value.length <= 300 &&
                        /(?:per[_-]?day|daily)/i.test(value)
                      )
                    ) quotaScope = "daily";
                  }
                }
              }
            }
          }
        } finally {
          reader.releaseLock();
        }
      }
    } catch { /* Malformed details never hide the original safe status. */ }
    throw new TemplateModelFailure(
      "template_provider_rate_limited",
      retry ?? 60,
      quotaScope,
    );
  }
  if (response.status === 401 || response.status === 403) {
    throw new TemplateModelFailure("template_provider_not_configured");
  }
  if (response.status === 404) {
    throw new TemplateModelFailure("template_provider_model_unavailable");
  }
  if (response.status === 400) {
    throw new TemplateModelFailure("template_provider_request_rejected");
  }
  throw new TemplateModelFailure("template_provider_unavailable", retry);
}

function wireRequest(
  config: TemplateModelConfig,
  request: TemplateModelRequest,
) {
  if (
    !Number.isInteger(request.maxTokens) || request.maxTokens < 1 ||
    request.maxTokens > 16000 ||
    !/^[a-z0-9_]{1,64}$/.test(request.name) || !request.messages.length
  ) {
    throw new Error("template_provider_invalid_request");
  }
  if (config.provider === "gemini") {
    return {
      systemInstruction: { parts: [{ text: request.system }] },
      contents: request.messages.map((message) => ({
        role: message.role === "assistant" ? "model" : "user",
        parts: [{ text: message.content }],
      })),
      generationConfig: {
        candidateCount: 1,
        maxOutputTokens: request.maxTokens,
        responseModalities: ["TEXT"],
        responseMimeType: "application/json",
        ...(request.schema ? { responseJsonSchema: request.schema } : {}),
        thinkingConfig: config.model.startsWith("gemini-2.")
          ? { thinkingBudget: 1024, includeThoughts: false }
          : {
            // Direction and review keep deeper reasoning; validated geometry is cheaper.
            thinkingLevel: request.name === "snapfit_composition_v3"
              ? "LOW"
              : "MEDIUM",
            includeThoughts: false,
          },
      },
    };
  }
  return {
    model: config.model,
    max_completion_tokens: request.maxTokens,
    messages: [
      { role: "system", content: request.system },
      ...request.messages,
    ],
    response_format: request.schema
      ? {
        type: "json_schema",
        json_schema: {
          name: request.name,
          strict: true,
          schema: request.schema,
        },
      }
      : { type: "json_object" },
  };
}

async function pause(ms: number, signal: AbortSignal) {
  signal.throwIfAborted();
  if (ms <= 0) return;
  await new Promise<void>((resolve, reject) => {
    const cancel = () => {
      clearTimeout(timer);
      reject(new Error("template_generation_timeout"));
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", cancel);
      resolve();
    }, ms);
    signal.addEventListener("abort", cancel, { once: true });
  });
}

export function createTemplateJsonModel(
  config: TemplateModelConfig,
  fetcher: TemplateModelFetcher,
  signal: AbortSignal,
) {
  let queue = Promise.resolve();
  let nextStart = 0;
  let stopped = false;
  let retriesUsed = 0;
  async function send(request: TemplateModelRequest): Promise<unknown> {
    if (stopped) throw new Error("template_generation_cancelled");
    if (signal.aborted) throw new Error("template_generation_timeout");
    const body = wireRequest(config, request);
    try {
      let response: Response;
      while (true) {
        await pause(Math.max(0, nextStart - Date.now()), signal);
        nextStart = Date.now() + config.minIntervalMs;
        response = await fetcher(templateModelEndpoint(config), {
          method: "POST",
          redirect: "error",
          signal,
          headers: config.provider === "gemini"
            ? {
              "x-goog-api-key": config.apiKey,
              "Content-Type": "application/json",
            }
            : {
              Authorization: `Bearer ${config.apiKey}`,
              "Content-Type": "application/json",
            },
          body: JSON.stringify(body),
        });
        if (
          config.provider !== "gemini" || !config.freeOnly ||
          ![502, 503, 504].includes(response.status) ||
          retriesUsed >= config.transientRetries
        ) break;
        retriesUsed++;
        await response.body?.cancel();
        const delay = config.retryBaseMs * 2 ** (retriesUsed - 1);
        await pause(delay + Math.random() * config.retryBaseMs * .25, signal);
      }
      if (!response.ok) await responseFailure(response);
      let payload: unknown;
      try {
        payload = await response.json();
      } catch {
        throw new TemplateModelFailure("template_generation_invalid_json");
      }
      const output = decodeTemplateModelOutput(config.provider, payload);
      if (!output.complete) {
        throw new TemplateModelFailure("template_generation_incomplete");
      }
      try {
        return JSON.parse(output.content);
      } catch {
        throw new TemplateModelFailure("template_generation_invalid_json");
      }
    } catch (error) {
      stopped = true;
      if (signal.aborted) throw new Error("template_generation_timeout");
      if (error instanceof TemplateModelFailure) throw error;
      throw new Error("template_provider_unavailable");
    }
  }
  return (request: TemplateModelRequest): Promise<unknown> => {
    if (config.provider !== "gemini" && config.minIntervalMs === 0) {
      return send(request);
    }
    // Serialize this book's calls; a failed quota request also stops queued work.
    const result = queue.then(() => send(request));
    queue = result.then(() => {}, () => {});
    return result;
  };
}

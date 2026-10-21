import typography from "./typography-contract.json" with { type: "json" };
import {
  bookBatches,
  compositionSchema,
  directionSchema,
  generateOriginalBook,
  originalDirectionPrompt,
  reviewSchema,
} from "./template-book-engine.ts";
import {
  compositionContract,
  type OriginalBook,
} from "./template-composition.ts";
import { parseTemplateBrief, type TemplateBrief } from "./template-design.ts";
import { editorialQuality } from "./template-editorial-quality.ts";
import {
  createTemplateJsonModel,
  resolveTemplateModelConfig,
  type TemplateModelEnv,
  type TemplateModelFetcher,
  type TemplateModelRequest,
} from "./template-model-provider.ts";

/** Server-owned state only. Never accept checkpoints from a public request. */
export type FreeTemplateCheckpoint = {
  version: 2;
  identity: string;
  responses: { fingerprint: string; output: unknown }[];
};
export type FreeTemplateStepResult = {
  checkpoint: FreeTemplateCheckpoint;
  design?: OriginalBook;
  modelProvider: "gemini";
  modelName: string;
  stage: "direction" | "composition" | "review" | "complete";
};
export type FreeTemplateStepOptions = {
  env?: TemplateModelEnv;
  fetch?: TemplateModelFetcher;
  checkpoint?: FreeTemplateCheckpoint;
  onCheckpoint?: (checkpoint: FreeTemplateCheckpoint) => void | Promise<void>;
};

// Increment for any execution/validation change that must invalidate durable
// jobs. Full schemas, material/type rubrics and stage requests are also hashed.
export const FREE_TEMPLATE_ENGINE_REVISION = "free-safe-original-book-v1";
const system =
  `You are Snapfit's photobook art director for public, non-personal design settings. Return original editable JSON only using supplied free materials and registered fonts. Never request or infer personal photos, names, dates, places, identities or private stories. Follow ${editorialQuality.version}: deliberate typography, facing-page rhythm, useful photo windows, coherent materials/palette and natural concise copy. Preserve every quality gate and exact safe requested phrase. Never substitute catalog layouts or rasterize text. Keep planning descriptions concise and each page's role distinct.`;
const MAX_CHECKPOINT_BYTES = 2_000_000;

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
        .map(([key, v]) => [key, canonical(v)]),
    );
  }
  return value;
}
async function digest(value: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(canonical(value)));
  const result = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(result)].map((n) => n.toString(16).padStart(2, "0"))
    .join("");
}
class StepBoundary extends Error {
  constructor(readonly stage: "direction" | "composition" | "review") {
    super("template_step_pending");
  }
}

/**
 * The caller must construct brief.prompt solely from a server allowlist of
 * public design settings. This lower-level runner never sanitizes private text.
 * It performs zero or one transport call; quota/backoff/leases belong to the
 * durable job coordinator, not to an in-memory automatic retry loop.
 */
export async function runFreeTemplateStep(
  input: TemplateBrief,
  options: FreeTemplateStepOptions = {},
): Promise<FreeTemplateStepResult> {
  const env = options.env ?? ((name) => Deno.env.get(name));
  if (
    (env("AI_TEMPLATE_PROVIDER")?.trim() || "gemini") !== "gemini" ||
    (env("AI_TEMPLATE_FREE_ONLY")?.trim() || "true") !== "true"
  ) throw new Error("template_provider_free_only");
  const resolved = resolveTemplateModelConfig(env);
  if (resolved.provider !== "gemini" || !resolved.freeOnly) {
    throw new Error("template_provider_free_only");
  }
  const brief = parseTemplateBrief(input);
  if (brief.designVersion !== 3) {
    throw new Error("template_step_version_required");
  }
  const maxResponses = bookBatches(brief.pageCount).length + 7;
  const identity = await digest({
    revision: FREE_TEMPLATE_ENGINE_REVISION,
    system,
    model: { provider: "gemini", name: resolved.model, freeOnly: true },
    safeInput: brief,
    directionPrompt: originalDirectionPrompt(brief),
    schemas: { directionSchema, compositionSchema, reviewSchema },
    typography,
    compositionContract,
    editorialQuality,
    execution: { concurrency: 1, transientRetries: 0, timeoutMs: 110000 },
  });
  const supplied = options.checkpoint;
  if (
    supplied && (
      supplied.version !== 2 || supplied.identity !== identity ||
      !Array.isArray(supplied.responses) ||
      supplied.responses.length > maxResponses ||
      JSON.stringify(supplied).length > MAX_CHECKPOINT_BYTES ||
      supplied.responses.some((entry) =>
        !entry || !/^[a-f0-9]{64}$/.test(entry.fingerprint) ||
        !Object.hasOwn(entry, "output")
      ) ||
      new Set(supplied.responses.map((entry) => entry.fingerprint)).size !==
        supplied.responses.length
    )
  ) throw new Error("template_checkpoint_invalid");
  const responses = new Map(
    (supplied?.responses ?? []).map((
      entry,
    ) => [entry.fingerprint, structuredClone(entry.output)]),
  );
  const snapshot = (): FreeTemplateCheckpoint => ({
    version: 2,
    identity,
    responses: [...responses].map(([fingerprint, output]) => ({
      fingerprint,
      output: structuredClone(output),
    })),
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 110000);
  const generate = createTemplateJsonModel(
    {
      ...resolved,
      timeoutMs: 110000,
      transientRetries: 0,
    },
    options.fetch ?? fetch,
    controller.signal,
  );
  let transportStarted = false, calls = 0;
  const result = (
    stage: FreeTemplateStepResult["stage"],
    design?: OriginalBook,
  ): FreeTemplateStepResult => ({
    checkpoint: snapshot(),
    ...(design ? { design } : {}),
    modelProvider: "gemini",
    modelName: resolved.model,
    stage,
  });
  try {
    const design = await generateOriginalBook(brief, async (job) => {
      if (++calls > maxResponses) {
        throw new Error("template_generation_budget_exceeded");
      }
      const request: TemplateModelRequest = {
        name: `snapfit_${job.stage}_v3`,
        system,
        messages: [{ role: "user", content: job.prompt }],
        schema: job.schema,
        maxTokens: job.maxTokens,
      };
      const fingerprint = await digest({ identity, request });
      if (responses.has(fingerprint)) {
        return structuredClone(responses.get(fingerprint));
      }
      if (transportStarted) throw new StepBoundary(job.stage);
      if (responses.size >= maxResponses) {
        throw new Error("template_checkpoint_limit");
      }
      transportStarted = true;
      const output = await generate(request);
      if (JSON.stringify(output).includes(resolved.apiKey)) {
        throw new Error("template_generation_sensitive_output");
      }
      responses.set(fingerprint, structuredClone(output));
      const checkpoint = snapshot();
      if (JSON.stringify(checkpoint).length > MAX_CHECKPOINT_BYTES) {
        throw new Error("template_checkpoint_limit");
      }
      try {
        await options.onCheckpoint?.(checkpoint);
      } catch {
        throw new Error("template_checkpoint_persistence_failed");
      }
      return output;
    }, { compositionConcurrency: 1 });
    return result("complete", design);
  } catch (error) {
    if (error instanceof StepBoundary) return result(error.stage);
    throw error;
  } finally {
    clearTimeout(timer);
    controller.abort();
  }
}

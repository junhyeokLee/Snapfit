import {
  assert,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import {
  assertTemplateCustomerDataAllowed,
  createTemplateJsonModel,
  decodeTemplateModelOutput,
  resolveTemplateModelConfig,
  TemplateModelFailure,
  type TemplateModelRequest,
} from "./template-model-provider.ts";
import { createOriginalTemplate } from "./index.ts";
import { parseTemplateBrief } from "./template-design.ts";
import {
  contractTestGuard,
  fixtureEditorialChecks,
  handleAiAlbumDraftRequest,
} from "./test-support.ts";

const environment = (extra: Record<string, string | undefined> = {}) => {
  const values: Record<string, string | undefined> = {
    GEMINI_API_KEY: "test-gemini-secret",
    AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
    AI_TEMPLATE_RETRY_BASE_MS: "0",
    ...extra,
  };
  return (key: string) => values[key];
};
const job: TemplateModelRequest = {
  name: "snapfit_composition_v3",
  system: "Use existing free material IDs. Output editable JSON only.",
  messages: [{ role: "user", content: '{"indexes":[1,2]}' }],
  schema: {
    type: "object",
    properties: { pages: { type: "array", items: { type: "object" } } },
    required: ["pages"],
  },
  maxTokens: 12000,
};

Deno.test("429 parses HTTP-date and RetryInfo delays and machine daily quota without retaining provider messages", async () => {
  const date = new Date(Date.now() + 120_000).toUTCString();
  const model = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            error: {
              message: "PRIVATE project daily-story",
              details: [
                {
                  "@type": "type.googleapis.com/google.rpc.RetryInfo",
                  retryDelay: "180.2s",
                },
                {
                  "@type": "type.googleapis.com/google.rpc.QuotaFailure",
                  violations: [{
                    quotaId:
                      "GenerateRequestsPerDayPerProjectPerModel-FreeTier",
                    quotaMetric:
                      "generativelanguage.googleapis.com/generate_content_free_tier_requests",
                    subject: "PRIVATE project",
                  }],
                },
              ],
            },
          }),
          { status: 429, headers: { "Retry-After": date } },
        ),
      ),
    new AbortController().signal,
  );
  const failure = await assertRejects(() => model(job), TemplateModelFailure);
  assertEquals(failure.retryAfterSeconds, 181);
  assertEquals(failure.quotaScope, "daily");
  assertEquals(failure.message, "template_provider_rate_limited");
  assert(!JSON.stringify(failure).includes("PRIVATE"));
});

Deno.test("quota messages alone do not infer daily scope and 503 preserves a bounded HTTP-date retry", async () => {
  const quota = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    () =>
      Promise.resolve(
        new Response(
          JSON.stringify({
            error: {
              message: "daily quota PRIVATE",
              details: [{ "@type": "unknown", retryDelay: "1s" }],
            },
          }),
          { status: 429 },
        ),
      ),
    new AbortController().signal,
  );
  const failure = await assertRejects(() => quota(job), TemplateModelFailure);
  assertEquals(failure.quotaScope, "unknown");
  assertEquals(failure.retryAfterSeconds, 60);
  const retryDate = new Date(Date.now() + 120_000).toUTCString();
  const config = {
    ...resolveTemplateModelConfig(environment()),
    transientRetries: 0,
  };
  const unavailable = createTemplateJsonModel(
    config,
    () =>
      Promise.resolve(
        new Response("PRIVATE", {
          status: 503,
          headers: { "Retry-After": retryDate },
        }),
      ),
    new AbortController().signal,
  );
  const server = await assertRejects(
    () => unavailable(job),
    TemplateModelFailure,
  );
  assert(
    (server.retryAfterSeconds ?? 0) >= 118 &&
      (server.retryAfterSeconds ?? 0) <= 120,
  );
  assertEquals(server.quotaScope, "unknown");
});
function output(
  value: unknown,
  finishReason = "STOP",
  extra: Record<string, unknown> = {},
) {
  return new Response(JSON.stringify({
    candidates: [{
      finishReason,
      content: { parts: [{ text: JSON.stringify(value) }] },
    }],
    usageMetadata: {
      promptTokenCount: 100,
      candidatesTokenCount: 200,
      thoughtsTokenCount: 50,
    },
    ...extra,
  }));
}

Deno.test("default uses free-capable Gemini, not a present OpenAI credential", () => {
  const config = resolveTemplateModelConfig(
    environment({ OPENAI_API_KEY: "must-not-use" }),
  );
  assertEquals(config.provider, "gemini");
  assertEquals(config.model, "gemini-3.6-flash");
  assertEquals(config.apiKey, "test-gemini-secret");
  assertEquals(config.freeOnly, true);
  assertEquals(config.timeoutMs, 120000);
  assertThrows(
    () =>
      resolveTemplateModelConfig((key) =>
        key === "OPENAI_API_KEY" ? "present-but-not-selected" : undefined
      ),
    Error,
    "not_configured",
  );
});

Deno.test("paid models and providers require explicit server opt-in", () => {
  for (
    const extra of [
      { AI_TEMPLATE_MODEL: "gemini-4-argon" },
      { AI_TEMPLATE_MODEL: "gemini-3.1-flash-image" },
      { AI_TEMPLATE_PROVIDER: "openai", OPENAI_API_KEY: "test-only" },
    ]
  ) {
    assertThrows(
      () => resolveTemplateModelConfig(environment(extra)),
      Error,
      "free_only",
    );
  }
  const openai = resolveTemplateModelConfig(
    environment({
      AI_TEMPLATE_PROVIDER: "openai",
      AI_TEMPLATE_FREE_ONLY: "false",
      OPENAI_API_KEY: "test-only",
      AI_TEMPLATE_MODEL: "gpt-4o",
    }),
  );
  assertEquals(openai.provider, "openai");
  assertEquals(openai.freeOnly, false);
  assertThrows(
    () =>
      resolveTemplateModelConfig(
        environment({
          AI_TEMPLATE_FREE_ONLY: "false",
          AI_TEMPLATE_MODEL: "gemini-3.1-flash-image",
        }),
      ),
    Error,
    "model_not_supported",
  );
});

Deno.test("configuration cannot inject endpoints or silently select unsupported providers", () => {
  for (
    const extra of [
      { AI_TEMPLATE_PROVIDER: "unknown" },
      {
        AI_TEMPLATE_MODEL: "../openai?key=private",
        AI_TEMPLATE_FREE_ONLY: "false",
      },
      {
        AI_TEMPLATE_MODEL: "https://example.test/secret",
        AI_TEMPLATE_FREE_ONLY: "false",
      },
      { AI_TEMPLATE_FREE_ONLY: "False" },
      {
        AI_TEMPLATE_PROVIDER: "openai",
        AI_TEMPLATE_FREE_ONLY: "false",
        AI_TEMPLATE_MODEL: "gemini-3.8-flash",
        OPENAI_API_KEY: "test-only",
      },
      { AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "-1" },
      { AI_TEMPLATE_TIMEOUT_MS: "150001" },
    ]
  ) assertThrows(() => resolveTemplateModelConfig(environment(extra)));
});

Deno.test("unpaid customer processing is closed until privacy is explicitly reviewed", () => {
  const env = environment(), config = resolveTemplateModelConfig(env);
  assertThrows(
    () => assertTemplateCustomerDataAllowed(config, env),
    Error,
    "privacy_review_required",
  );
  assertTemplateCustomerDataAllowed(
    config,
    environment({ AI_TEMPLATE_ALLOW_UNPAID_USER_DATA: "true" }),
  );
});

Deno.test("Gemini uses a text-only schema contract and never sends a credential in its URL or prompt", async () => {
  const controller = new AbortController();
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    async (url, init) => {
      assertEquals(
        String(url),
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
      );
      assertEquals(init?.redirect, "error");
      assertEquals(init?.signal, controller.signal);
      const headers = new Headers(init?.headers);
      assertEquals(headers.get("x-goog-api-key"), "test-gemini-secret");
      assertEquals(headers.get("Authorization"), null);
      const body = JSON.parse(String(init?.body));
      assertEquals(body.contents, [{
        role: "user",
        parts: [{ text: job.messages[0].content }],
      }]);
      assertEquals(body.generationConfig.responseJsonSchema, job.schema);
      assertEquals(body.generationConfig.responseModalities, ["TEXT"]);
      assertEquals(body.generationConfig.maxOutputTokens, 12000);
      assertEquals(body.generationConfig.candidateCount, 1);
      assertEquals(body.tools, undefined);
      assertEquals(body.generationConfig.imageConfig, undefined);
      assert(!JSON.stringify(body).includes("test-gemini-secret"));
      return output({ pages: [] });
    },
    controller.signal,
  );
  assertEquals(await generate(job), { pages: [] });
});

Deno.test("Gemini composition bounds thinking latency without reducing direction or review reasoning", async () => {
  for (
    const model of ["gemini-3.8-flash", "gemini-3.6-flash", "gemini-2.5-flash"]
  ) {
    const generate = createTemplateJsonModel(
      resolveTemplateModelConfig(environment({ AI_TEMPLATE_MODEL: model })),
      async (_url, init) => {
        const body = JSON.parse(String(init?.body));
        const name = body.contents[0].parts[0].text;
        const thinking = body.generationConfig.thinkingConfig;
        assertEquals(thinking.includeThoughts, false);
        if (model === "gemini-2.5-flash") {
          assertEquals(thinking.thinkingBudget, 1024);
          assertEquals(thinking.thinkingLevel, undefined);
        } else {
          assertEquals(
            thinking.thinkingLevel,
            name === "composition" ? "LOW" : "MEDIUM",
          );
        }
        assertEquals(body.generationConfig.maxOutputTokens, job.maxTokens);
        assertEquals(body.generationConfig.responseJsonSchema, job.schema);
        return output({ pages: [] });
      },
      new AbortController().signal,
    );
    for (const stage of ["direction", "composition", "review"]) {
      await generate({
        ...job,
        name: `snapfit_${stage}_v3`,
        messages: [{ role: "user", content: stage }],
      });
    }
  }
});

Deno.test("Gemini correction history maps assistant text to model, not a new photo upload", async () => {
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    async (_, init) => {
      const body = JSON.parse(String(init?.body));
      assertEquals(body.contents.map((part: { role: string }) => part.role), [
        "user",
        "model",
        "user",
      ]);
      assert(
        body.contents.every((part: { parts: Record<string, string>[] }) =>
          part.parts.every((p) => Object.keys(p).join() === "text")
        ),
      );
      return output({ ok: true });
    },
    new AbortController().signal,
  );
  await generate({
    ...job,
    messages: [...job.messages, { role: "assistant", content: "{}" }, {
      role: "user",
      content: "Repair geometry",
    }],
  });
});

Deno.test("decoder excludes thoughts and reports reasoning tokens without inventing free usage", () => {
  const result = decodeTemplateModelOutput("gemini", {
    candidates: [{
      finishReason: "STOP",
      content: {
        parts: [{ text: "private reasoning", thought: true }, {
          text: '{"ok":true}',
        }],
      },
    }],
    usageMetadata: {
      promptTokenCount: 50,
      candidatesTokenCount: 80,
      thoughtsTokenCount: 40,
    },
  });
  assertEquals(result.content, '{"ok":true}');
  assertEquals(result.usage, {
    inputTokens: 50,
    outputTokens: 120,
    thinkingTokens: 40,
  });
  assertEquals(decodeTemplateModelOutput("gemini", {}).usage, undefined);
});

for (const reason of ["MAX_TOKENS", "SAFETY", "RECITATION", "OTHER"]) {
  Deno.test(`never accepts partial or blocked JSON: ${reason}`, async () => {
    let calls = 0;
    const generate = createTemplateJsonModel(
      resolveTemplateModelConfig(environment()),
      () => {
        calls++;
        return Promise.resolve(output({ pages: [] }, reason));
      },
      new AbortController().signal,
    );
    await assertRejects(() => generate(job), Error, "incomplete");
    assertEquals(calls, 1);
  });
}

Deno.test("invalid JSON and unexpected image parts fail closed", async () => {
  for (
    const body of [
      {
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: "not JSON" }] },
        }],
      },
      {
        candidates: [{
          finishReason: "STOP",
          content: {
            parts: [{ text: "{}" }, { inlineData: { data: "not-permitted" } }],
          },
        }],
      },
    ]
  ) {
    const generate = createTemplateJsonModel(
      resolveTemplateModelConfig(environment()),
      () => Promise.resolve(new Response(JSON.stringify(body))),
      new AbortController().signal,
    );
    await assertRejects(() => generate(job));
  }
});

Deno.test("quota failure stops all queued calls and never falls back to another provider", async () => {
  let calls = 0;
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(
      environment({ OPENAI_API_KEY: "paid-key-must-not-be-used" }),
    ),
    () => {
      calls++;
      return Promise.resolve(
        new Response('{"error":{"message":"private-key"}}', {
          status: 429,
          headers: { "Retry-After": "120" },
        }),
      );
    },
    new AbortController().signal,
  );
  const results = await Promise.allSettled([
    generate(job),
    generate(job),
    generate(job),
  ]);
  assertEquals(calls, 1);
  assert(results.every((result) => result.status === "rejected"));
  const first = results[0] as PromiseRejectedResult;
  assert(first.reason instanceof TemplateModelFailure);
  assertEquals(first.reason.retryAfterSeconds, 120);
  assertEquals(first.reason.message, "template_provider_rate_limited");
  assert(!String(first.reason).includes("private-key"));
});

Deno.test("model calls are sequential and paced within each free book", async () => {
  let active = 0, peak = 0;
  const starts: number[] = [];
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(
      environment({ AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "12" }),
    ),
    async () => {
      active++;
      peak = Math.max(active, peak);
      starts.push(Date.now());
      await new Promise((resolve) => setTimeout(resolve, 8));
      active--;
      return output({ ok: true });
    },
    new AbortController().signal,
  );
  await Promise.all([generate(job), generate(job), generate(job)]);
  assertEquals(peak, 1);
  assert(starts[1] - starts[0] >= 10);
  assert(starts[2] - starts[1] >= 10);
});

Deno.test("abort cancels waiting work without sending another model request", async () => {
  const controller = new AbortController();
  let calls = 0;
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(
      environment({ AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "500" }),
    ),
    () => {
      calls++;
      return Promise.resolve(output({ ok: true }));
    },
    controller.signal,
  );
  await generate(job);
  const pending = generate(job);
  controller.abort();
  await assertRejects(() => pending, Error, "timeout");
  assertEquals(calls, 1);
});

Deno.test("free Gemini retries only a transient failed call with the identical request", async () => {
  const requests: string[] = [];
  const endpoints: string[] = [];
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    async (url, init) => {
      endpoints.push(String(url));
      requests.push(String(init?.body));
      return requests.length === 1
        ? new Response("overloaded", { status: 503 })
        : output({ ok: true });
    },
    new AbortController().signal,
  );
  assertEquals(await generate(job), { ok: true });
  assertEquals(requests.length, 2);
  assertEquals(requests[0], requests[1]);
  assertEquals(endpoints[0], endpoints[1]);
});

Deno.test("transient retry budget is shared by the whole book, not reset for each page batch", async () => {
  let calls = 0;
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(environment()),
    () => {
      calls++;
      return Promise.resolve(
        calls % 2
          ? new Response("overloaded", { status: 503 })
          : output({ ok: true }),
      );
    },
    new AbortController().signal,
  );
  await generate(job);
  await generate(job);
  await assertRejects(() => generate(job), Error, "unavailable");
  assertEquals(calls, 5);
  await assertRejects(() => generate(job), Error, "cancelled");
  assertEquals(calls, 5);
});

Deno.test("shared deadline aborts transient backoff and paid modes never gain automatic retries", async () => {
  const controller = new AbortController();
  let calls = 0;
  const generate = createTemplateJsonModel(
    resolveTemplateModelConfig(
      environment({ AI_TEMPLATE_RETRY_BASE_MS: "500" }),
    ),
    () => {
      calls++;
      controller.abort();
      return Promise.resolve(new Response("overloaded", { status: 503 }));
    },
    controller.signal,
  );
  await assertRejects(() => generate(job), Error, "timeout");
  assertEquals(calls, 1);
  const paid = createTemplateJsonModel(
    resolveTemplateModelConfig(
      environment({
        AI_TEMPLATE_FREE_ONLY: "false",
        AI_TEMPLATE_MAX_TRANSIENT_RETRIES: "2",
      }),
    ),
    () => {
      calls++;
      return Promise.resolve(new Response("overloaded", { status: 503 }));
    },
    new AbortController().signal,
  );
  await assertRejects(() => paid(job), Error, "unavailable");
  assertEquals(calls, 2);
});

Deno.test("complete v3 book uses Gemini for direction, compositions and semantic review", async () => {
  const stages: string[] = [];
  const result = await createOriginalTemplate(
    parseTemplateBrief(fixture.brief),
    {
      env: environment(),
      fetch: (_, init) => {
        const body = JSON.parse(String(init?.body));
        const prompt = JSON.parse(body.contents[0].parts[0].text);
        if (prompt.book) {
          stages.push("review");
          return Promise.resolve(
            output({
              approved: true,
              qualityChecks: fixtureEditorialChecks(),
              requirementChecks: fixture.plan.requirements.map((_, i) => ({
                requirementIndex: i,
                satisfied: true,
                evidencePageIndexes: [0],
              })),
              issues: [],
            }),
          );
        }
        if (prompt.indexes) {
          stages.push("composition");
          return Promise.resolve(output(fixture.output));
        }
        stages.push("direction");
        assertEquals(
          prompt.availableMaterials.frames.studioOval.length > 0,
          true,
        );
        return Promise.resolve(output(fixture.plan));
      },
    },
  );
  assertEquals(stages, ["direction", "composition", "review"]);
  assertEquals(result.modelProvider, "gemini");
  assertEquals(result.modelName, "gemini-3.6-flash");
  assertEquals(result.design?.version, 3);
  assertEquals(result.recommendedPhotos, []);
  assertEquals(result.fallbackUsed, false);
});

Deno.test("HTTP request cannot override model/free/privacy policy or make an unpaid personal-data call", async () => {
  let calls = 0, failed = 0;
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        designBrief: fixture.brief,
        modelProvider: "openai",
        model: "paid",
        allowUnpaidUserData: true,
      }),
    }),
    {
      env: environment(),
      guard: {
        ...contractTestGuard,
        fail: () => {
          failed++;
          return Promise.resolve();
        },
      },
      fetch: () => {
        calls++;
        throw new Error("must not call");
      },
    },
  );
  assertEquals(response.status, 400);
  assertEquals(
    (await response.json()).error,
    "ai_generation_private_input_forbidden",
  );
  assertEquals(calls, 0);
  assertEquals(failed, 0);
});

Deno.test("synthetic engine quota failure retains Retry-After and returns no draft", async () => {
  const failure = await assertRejects(
    () =>
      createOriginalTemplate(
        parseTemplateBrief(fixture.brief),
        {
          env: environment({ AI_TEMPLATE_ALLOW_UNPAID_USER_DATA: "true" }),
          fetch: () =>
            Promise.resolve(
              new Response("private provider error", {
                status: 429,
                headers: { "Retry-After": "120" },
              }),
            ),
        },
      ),
    TemplateModelFailure,
    "template_provider_rate_limited",
  );
  assertEquals(failure.retryAfterSeconds, 120);
});

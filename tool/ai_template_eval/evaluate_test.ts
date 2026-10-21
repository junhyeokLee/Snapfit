import { assert, assertEquals, assertThrows } from "jsr:@std/assert";
import { evaluationCases, originalBookCases } from "./cases.ts";
import { parseTemplateBrief } from "../../supabase/functions/ai-album-draft/template-design.ts";
import { evaluateCase, evaluateSuite, summarize } from "./evaluate.ts";
import { fixtureCases, fixtureFetcher } from "./fixtures.ts";
import { parseArgs } from "./run.ts";
import { fixtureEditorialChecks } from "../../supabase/functions/ai-album-draft/test-support.ts";
import originalFixture from "../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};

Deno.test("suite spans six distinct briefs, three aspects and short/long books", () => {
  assertEquals(evaluationCases.length, 18);
  assertEquals(new Set(evaluationCases.map((c) => c.id)).size, 18);
  assertEquals(new Set(evaluationCases.map((c) => c.brief.prompt)).size, 6);
  assertEquals(new Set(evaluationCases.map((c) => c.brief.aspect)).size, 3);
  assertEquals(
    new Set(evaluationCases.map((c) => c.brief.pageCount)),
    new Set([4, 8, 12, 16]),
  );
  for (const c of evaluationCases) {
    assertEquals(parseTemplateBrief(c.brief), c.brief);
    assert(c.expectations.length >= 3);
  }
});
Deno.test("CLI never calls a model by default and limits live runs explicitly", () => {
  assertEquals(parseArgs([]), {
    mode: "list",
    chosen: undefined,
    limit: 1,
    engine: 3,
    provider: "gemini",
    allowPaid: false,
  });
  assertEquals(parseArgs(["--engine", "2"]).engine, 2);
  assertEquals(parseArgs(["--live"]).limit, 1);
  assertEquals(parseArgs(["--live"]).provider, "gemini");
  assertEquals(
    parseArgs(["--live", "--provider", "openai", "--allow-paid"]).allowPaid,
    true,
  );
  assertThrows(() => parseArgs(["--live", "--provider", "openai"]));
  assertThrows(() => parseArgs(["--provider", "unknown"]));
  assertEquals(
    parseArgs(["--live", "--case", "wedding-square"]).chosen,
    "wedding-square",
  );
  assertEquals(parseArgs(["--live", "--max-cases", "18"]).limit, 18);
  for (
    const args of [
      ["--live", "--fixture"],
      ["--live", "--max-cases", "19"],
      ["--live", "--max-cases", "NaN"],
      ["--live", "--max-cases", "0"],
      ["--live", "--case", "unknown"],
      ["--fixture", "--max-cases", "2"],
      ["--engine", "4"],
    ]
  ) assertThrows(() => parseArgs(args));
});

Deno.test("v3 evaluation covers complete real-size books without conflicting page instructions", () => {
  assertEquals(originalBookCases.length, 18);
  assertEquals(
    new Set(originalBookCases.map((c) => c.brief.pageCount)),
    new Set([20, 24, 32, 36]),
  );
  for (const entry of originalBookCases) {
    assertEquals(entry.brief.designVersion, 3);
    assertEquals(parseTemplateBrief(entry.brief), entry.brief);
    assert(entry.expectations.length >= 4);
  }
});

Deno.test("v3 traces original-book stages and targeted correction without misreporting a first-pass success", async () => {
  const entry = {
    id: "original-contract",
    label: "Contract only",
    brief: parseTemplateBrief(originalFixture.brief),
    expectations: ["No live model output"],
  };
  let compositions = 0;
  const result = await evaluateCase(entry, {
    provider: "openai",
    freeOnly: false,
    apiKey: "test-secret",
    model: "fixture",
    fetch: async (_url, init) => {
      const request = JSON.parse(String(init?.body));
      const stage = request.response_format.json_schema.name;
      let output: unknown;
      if (stage.includes("direction")) output = originalFixture.plan;
      else if (stage.includes("composition")) {
        compositions++;
        const sample = structuredClone(originalFixture.output);
        if (compositions === 1) sample.pages[1].elements[0].width = 2;
        output = sample;
      } else {output = {
          approved: true,
          qualityChecks: fixtureEditorialChecks(),
          requirementChecks: originalFixture.plan.requirements.map((_, i) => ({
            requirementIndex: i,
            satisfied: true,
            evidencePageIndexes: [0],
          })),
          issues: [],
        };}
      return new Response(
        JSON.stringify({
          choices: [{
            finish_reason: "stop",
            message: { content: JSON.stringify(output) },
          }],
        }),
      );
    },
  });
  assertEquals(result.status, "accepted");
  assertEquals(result.attempts.map((t) => t.stage), [
    "direction",
    "composition",
    "composition",
    "review",
  ]);
  assertEquals(result.attempts.map((t) => t.attempt), [1, 1, 2, 1]);
  assert(result.attempts[1].validationError);
  assertEquals(result.attempts[2].validationError, undefined);
  assertEquals(summarize([result]).correctedAccepted, 1);
  assertEquals(summarize([result]).firstPassAccepted, 0);
  assertEquals(summarize([result]).aestheticVerdict, "not_reviewed");
});
Deno.test("the production generator is traced without collecting headers or billing", async () => {
  const entry = fixtureCases[0], responses = fixtureFetcher(entry);
  const result = await evaluateCase(entry, {
    provider: "openai",
    freeOnly: false,
    apiKey: "secret-test-key",
    model: "test-model",
    fetch: async (url, init) => {
      assertEquals(String(url), "https://api.openai.com/v1/chat/completions");
      assertEquals(
        new Headers(init?.headers).get("Authorization"),
        "Bearer secret-test-key",
      );
      return responses(url, init);
    },
  });
  assertEquals(result.status, "accepted");
  assertEquals(result.attempts.map((t) => t.stage), ["plan", "layout"]);
  assertEquals(result.attempts.map((t) => t.attempt), [1, 1]);
  assert(
    result.attempts.every((t) =>
      t.output && t.status === 200 && !t.validationError
    ),
  );
  assert(!JSON.stringify(result).includes("secret-test-key"));
  assert(!JSON.stringify(result).includes("Authorization"));
  const summary = summarize([result]);
  assertEquals(summary.firstPassAccepted, 1);
  assertEquals(summary.inputTokens, 200);
  assertEquals(summary.outputTokens, 400);
  assertEquals(summary.usageComplete, true);
  assertEquals(summary.estimatedCostUsd, null);
  assertEquals(summary.aestheticVerdict, "not_reviewed");
});
for (const kind of ["repair", "reject"]) {
  Deno.test(`retains ${kind} errors and every returned model document`, async () => {
    const entry = fixtureCases.find((c) => c.id === `fixture-${kind}`)!;
    const result = await evaluateCase(entry, {
      provider: "openai",
      freeOnly: false,
      apiKey: "fixture-key",
      model: "test",
      fetch: fixtureFetcher(entry),
    });
    assertEquals(result.status, kind === "repair" ? "accepted" : "rejected");
    assertEquals(result.attempts.length, 3);
    assertEquals(
      result.attempts[1].validationError,
      "template_design_out_of_bounds",
    );
    assert(result.attempts.every((t) => t.output));
    assertEquals(
      summarize([result]).correctedAccepted,
      kind === "repair" ? 1 : 0,
    );
    if (kind === "reject") assertEquals(result.document, undefined);
  });
}
Deno.test("quota failure stops the remaining suite immediately and persists partial state", async () => {
  let calls = 0, stored = 0;
  const result = await evaluateSuite(evaluationCases, {
    provider: "openai",
    freeOnly: false,
    apiKey: "key",
    model: "test",
    fetchFor: () => async () => {
      calls++;
      return new Response(
        JSON.stringify({
          error: {
            code: "credit_balance_exhausted",
            message: "secret-test-key",
          },
        }),
        { status: 429 },
      );
    },
    onResult: async () => {
      stored++;
    },
  });
  assertEquals(calls, 1);
  assertEquals(stored, 18);
  assertEquals(result[0].reason, "credit_balance_exhausted");
  assert(
    result.slice(1).every((r) =>
      r.status === "skipped" && r.attempts.length === 0
    ),
  );
  assert(!JSON.stringify(result).includes("secret-test-key"));
  assertEquals(summarize(result).usageComplete, false);
  assertEquals(summarize(result).attempted, 1);
});
Deno.test("missing key never sends a request", async () => {
  const result = await evaluateCase(fixtureCases[0], {
    provider: "openai",
    freeOnly: false,
    apiKey: "",
    model: "test",
    fetch: async () => {
      throw new Error("Should not fetch");
    },
  });
  assertEquals(result.reason, "template_provider_not_configured");
  assertEquals(result.attempts, []);
});
Deno.test("network failure cannot leak its error contents", async () => {
  const result = await evaluateCase(fixtureCases[0], {
    provider: "openai",
    freeOnly: false,
    apiKey: "key",
    model: "test",
    fetch: async () => {
      throw new Error("Authorization Bearer key");
    },
  });
  assertEquals(result.reason, "request_failed");
  assert(!JSON.stringify(result).includes("Bearer"));
});

Deno.test("deadline aborts are not mislabeled as generic network failures", async () => {
  const result = await evaluateCase(fixtureCases[0], {
    provider: "openai",
    freeOnly: false,
    apiKey: "secret-never-record",
    model: "test",
    env: (key) => key === "AI_TEMPLATE_TIMEOUT_MS" ? "1000" : undefined,
    fetch: async (_url, init) =>
      await new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener(
          "abort",
          () => reject(new Error("secret-never-record")),
          { once: true },
        );
      }),
  });
  assertEquals(result.reason, "template_generation_timeout");
  assertEquals(result.attempts[0].errorCode, "template_generation_timeout");
  assert(!JSON.stringify(result).includes("secret-never-record"));
});
Deno.test("unknown provider errors keep status but omit raw error bodies", async () => {
  const result = await evaluateCase(fixtureCases[0], {
    provider: "openai",
    freeOnly: false,
    apiKey: "secret",
    model: "test",
    fetch: async () =>
      new Response(
        JSON.stringify({ error: { code: "secret", message: "secret" } }),
        { status: 403 },
      ),
  });
  assertEquals(result.reason, "http_403");
  assert(!JSON.stringify(result).includes("secret"));
});

Deno.test("Gemini evaluation traces the real text adapter with targeted repairs and thinking usage", async () => {
  const entry = {
    id: "gemini-contract",
    label: "Contract fixture, not AI output",
    brief: parseTemplateBrief(originalFixture.brief),
    expectations: ["No live output"],
  };
  let compositions = 0;
  const result = await evaluateCase(entry, {
    apiKey: "test-gemini-secret",
    model: "gemini-3.8-flash",
    env: (key) => key === "AI_TEMPLATE_MIN_CALL_INTERVAL_MS" ? "0" : undefined,
    fetch: async (url, init) => {
      assertEquals(
        String(url),
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent",
      );
      const request = JSON.parse(String(init?.body));
      const prompt = JSON.parse(request.contents[0].parts[0].text);
      let content: unknown;
      if (prompt.book) {
        content = {
          approved: true,
          qualityChecks: fixtureEditorialChecks(),
          requirementChecks: originalFixture.plan.requirements.map((_, i) => ({
            requirementIndex: i,
            satisfied: true,
            evidencePageIndexes: [0],
          })),
          issues: [],
        };
      } else if (prompt.indexes || prompt.originalRequest) {
        content = structuredClone(originalFixture.output);
        if (++compositions === 1) {
          (content as typeof originalFixture.output).pages[1].elements[0]
            .width = 2;
        }
      } else content = originalFixture.plan;
      return new Response(JSON.stringify({
        candidates: [{
          finishReason: "STOP",
          content: { parts: [{ text: JSON.stringify(content) }] },
        }],
        usageMetadata: {
          promptTokenCount: 100,
          candidatesTokenCount: 200,
          thoughtsTokenCount: 50,
        },
      }));
    },
  });
  assertEquals(result.status, "accepted");
  assertEquals(result.attempts.map((trace) => trace.stage), [
    "direction",
    "composition",
    "composition",
    "review",
  ]);
  assert(result.attempts.every((trace) => trace.provider === "gemini"));
  assertEquals(summarize([result]).outputTokens, 1000);
  assertEquals(summarize([result]).thinkingTokens, 200);
  assertEquals(summarize([result]).aestheticVerdict, "not_reviewed");
  assert(!JSON.stringify(result).includes("test-gemini-secret"));
});

Deno.test("Gemini daily/minute exhaustion is recorded and never retried as OpenAI", async () => {
  let calls = 0;
  const results = await evaluateSuite(originalBookCases, {
    apiKey: "test-gemini-secret",
    model: "gemini-3.8-flash",
    fetchFor: () => async () => {
      calls++;
      return new Response(
        '{"error":{"status":"RESOURCE_EXHAUSTED","message":"private details"}}',
        { status: 429 },
      );
    },
  });
  assertEquals(calls, 1);
  assertEquals(results[0].reason, "RESOURCE_EXHAUSTED");
  assert(results.slice(1).every((result) => result.status === "skipped"));
  assert(!JSON.stringify(results).includes("private details"));
});

Deno.test("a recovered transient error never hides a subsequent real geometry failure", async () => {
  let requests = 0;
  const entry = {
    id: "quality-after-retry",
    label: "Contract test",
    brief: parseTemplateBrief(originalFixture.brief),
    expectations: [],
  };
  const result = await evaluateCase(entry, {
    provider: "gemini",
    model: "gemini-3.6-flash",
    apiKey: "test-only",
    freeOnly: true,
    env: (key) =>
      key === "AI_TEMPLATE_MIN_CALL_INTERVAL_MS" ||
        key === "AI_TEMPLATE_RETRY_BASE_MS"
        ? "0"
        : undefined,
    fetch: async (_url, init) => {
      if (++requests === 1) {
        return new Response(
          JSON.stringify({ error: { status: "UNAVAILABLE" } }),
          { status: 503 },
        );
      }
      const prompt = JSON.parse(
        JSON.parse(String(init?.body)).contents[0].parts[0].text,
      );
      const output = prompt.indexes || prompt.originalRequest
        ? structuredClone(originalFixture.output)
        : structuredClone(originalFixture.plan);
      if ("pages" in output && "background" in output.pages[0]) {
        output.pages[0].elements[0].width = 250;
      }
      return new Response(
        JSON.stringify({
          candidates: [{
            finishReason: "STOP",
            content: { parts: [{ text: JSON.stringify(output) }] },
          }],
        }),
      );
    },
  });
  assertEquals(result.status, "rejected");
  assertEquals(result.reason, "template_quality_failed");
  assertEquals(result.checkpoint, undefined);
  assertEquals(result.attempts[1].transportAttempt, 2);
});

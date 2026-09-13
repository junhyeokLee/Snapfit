import { assert, assertEquals, assertThrows } from "jsr:@std/assert";
import { evaluationCases } from "./cases.ts";
import { parseTemplateBrief } from "../../supabase/functions/ai-album-draft/template-design.ts";
import { evaluateCase, evaluateSuite, summarize } from "./evaluate.ts";
import { fixtureCases, fixtureFetcher } from "./fixtures.ts";
import { parseArgs } from "./run.ts";

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
  assertEquals(parseArgs([]), { mode: "list", chosen: undefined, limit: 1 });
  assertEquals(parseArgs(["--live"]).limit, 1);
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
    ]
  ) assertThrows(() => parseArgs(args));
});
Deno.test("the production generator is traced without collecting headers or billing", async () => {
  const entry = fixtureCases[0], responses = fixtureFetcher(entry);
  const result = await evaluateCase(entry, {
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
    apiKey: "key",
    model: "test",
    fetch: async () => {
      throw new Error("Authorization Bearer key");
    },
  });
  assertEquals(result.reason, "request_failed");
  assert(!JSON.stringify(result).includes("Bearer"));
});
Deno.test("unknown provider errors keep status but omit raw error bodies", async () => {
  const result = await evaluateCase(fixtureCases[0], {
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

import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import { parseTemplateBrief } from "./template-design.ts";
import {
  type FreeTemplateCheckpoint,
  runFreeTemplateStep,
} from "./template-free-step.ts";
import { TemplateModelFailure } from "./template-model-provider.ts";
import { fixtureEditorialChecks } from "./test-support.ts";

const brief = parseTemplateBrief(fixture.brief);
const env =
  (extra: Record<string, string | undefined> = {}) => (name: string) => ({
    GEMINI_API_KEY: "synthetic-only-key-never-transmitted-in-body",
    AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
    ...extra,
  }[name]);
const output = (value: unknown) =>
  new Response(
    JSON.stringify({
      candidates: [{
        finishReason: "STOP",
        content: { parts: [{ text: JSON.stringify(value) }] },
      }],
    }),
  );
const approve = () => ({
  approved: true,
  qualityChecks: fixtureEditorialChecks(),
  requirementChecks: fixture.plan.requirements.map((_, requirementIndex) => ({
    requirementIndex,
    satisfied: true,
    evidencePageIndexes: [0],
  })),
  issues: [] as { pageIndexes: number[]; reason: string }[],
});
function body(init?: RequestInit) {
  const wire = JSON.parse(String(init?.body));
  const raw = JSON.parse(wire.contents[0].parts[0].text);
  return {
    wire,
    raw,
    prompt: raw.originalRequest ? JSON.parse(raw.originalRequest) : raw,
  };
}

Deno.test("durable free steps perform one transport each, persist before yielding, and complete after more than three resumptions", async () => {
  let checkpoint: FreeTemplateCheckpoint | undefined;
  let reviews = 0, total = 0;
  const phases: string[] = [];
  let design;
  for (let iteration = 0; iteration < 5; iteration++) {
    let transports = 0, writes = 0;
    const result = await runFreeTemplateStep(brief, {
      env: env(),
      checkpoint,
      onCheckpoint: async (value) => {
        writes++;
        checkpoint = structuredClone(value);
        await Promise.resolve();
      },
      fetch: (_url, init) => {
        transports++;
        total++;
        assertEquals(writes, 0);
        const { wire, prompt } = body(init);
        assert(!JSON.stringify(wire).includes(env()("GEMINI_API_KEY")!));
        assertEquals(wire.generationConfig.responseModalities, ["TEXT"]);
        if (prompt.book) {
          reviews++;
          const review = approve();
          if (reviews === 1) {
            review.approved = false;
            review.issues = [{
              pageIndexes: [2],
              reason: "Synthetic page-specific correction.",
            }];
          }
          return Promise.resolve(output(review));
        }
        if (prompt.indexes) {
          const pages = prompt.indexes.map((i: number) =>
            structuredClone(fixture.output.pages[i])
          );
          if (prompt.repairFeedback) {
            pages[0].elements.find((e: { kind: string }) => e.kind === "text")
              .text = "길가에 남은 장면";
          }
          return Promise.resolve(output({ pages }));
        }
        return Promise.resolve(output(structuredClone(fixture.plan)));
      },
    });
    assertEquals(transports, 1);
    assertEquals(writes, 1);
    assertEquals(result.checkpoint, checkpoint);
    phases.push(result.stage);
    design = result.design;
  }
  assertEquals(phases, [
    "composition",
    "review",
    "composition",
    "review",
    "complete",
  ]);
  assertEquals(total, 5);
  assertEquals(design?.pages.length, 5);
  const replayed = await runFreeTemplateStep(brief, {
    env: env(),
    checkpoint,
    fetch: () => {
      throw new Error("completed checkpoint must never call provider");
    },
  });
  assertEquals(replayed.stage, "complete");
  assertEquals(replayed.design, design);
});

Deno.test("replaying failed model JSON preserves both consumed quality repairs across HTTP steps", async () => {
  let checkpoint: FreeTemplateCheckpoint | undefined;
  let transports = 0;
  const options = {
    env: env(),
    onCheckpoint: (value: FreeTemplateCheckpoint) => {
      checkpoint = structuredClone(value);
    },
    fetch: (_url: string | URL | Request, init?: RequestInit) => {
      transports++;
      const { raw, prompt } = body(init);
      if (prompt.book) {
        const review = approve();
        review.approved = false;
        review.issues = [{
          pageIndexes: [2],
          reason: "Would require a third quality repair.",
        }];
        return Promise.resolve(output(review));
      }
      if (prompt.indexes) {
        const pages = structuredClone(fixture.output);
        if (!raw.originalRequest) pages.pages[1].elements[0].width = 2;
        return Promise.resolve(output(pages));
      }
      const plan = structuredClone(fixture.plan);
      if (!raw.originalRequest) plan.typography.body.lineHeight = 1.7;
      return Promise.resolve(output(plan));
    },
  };
  for (let step = 0; step < 4; step++) {
    await runFreeTemplateStep(brief, { ...options, checkpoint });
  }
  await assertRejects(
    () => runFreeTemplateStep(brief, { ...options, checkpoint }),
    Error,
    "template_quality_failed",
  );
  assertEquals(transports, 5);
  assertEquals(checkpoint?.responses.length, 5);
  await assertRejects(
    () => runFreeTemplateStep(brief, { ...options, checkpoint }),
    Error,
    "template_quality_failed",
  );
  assertEquals(transports, 5);
});

Deno.test("checkpoint identity binds safe brief and model while rejecting legacy, duplicate and oversized state", async () => {
  const first = await runFreeTemplateStep(brief, {
    env: env(),
    fetch: () => Promise.resolve(output(structuredClone(fixture.plan))),
  });
  const forbidden = () => {
    throw new Error("invalid context must not contact provider");
  };
  for (
    const altered of [
      { ...first.checkpoint, version: 1 },
      { ...first.checkpoint, identity: "0".repeat(64) },
      {
        ...first.checkpoint,
        responses: [
          ...first.checkpoint.responses,
          ...first.checkpoint.responses,
        ],
      },
      {
        ...first.checkpoint,
        responses: [{
          ...first.checkpoint.responses[0],
          output: "x".repeat(2_000_001),
        }],
      },
    ]
  ) {
    await assertRejects(
      () =>
        runFreeTemplateStep(brief, {
          env: env(),
          checkpoint: altered as FreeTemplateCheckpoint,
          fetch: forbidden,
        }),
      Error,
      "template_checkpoint_invalid",
    );
  }
  await assertRejects(
    () =>
      runFreeTemplateStep({
        ...brief,
        prompt: brief.prompt + " Public safe style change.",
      }, { env: env(), checkpoint: first.checkpoint, fetch: forbidden }),
    Error,
    "template_checkpoint_invalid",
  );
  await assertRejects(
    () =>
      runFreeTemplateStep(brief, {
        env: env({ AI_TEMPLATE_MODEL: "gemini-3.8-flash" }),
        checkpoint: first.checkpoint,
        fetch: forbidden,
      }),
    Error,
    "template_checkpoint_invalid",
  );
});

Deno.test("free runner forbids paid policy and preserves a checkpoint on quota/503 without transport retries", async () => {
  for (
    const extra of [{ AI_TEMPLATE_PROVIDER: "openai" }, {
      AI_TEMPLATE_FREE_ONLY: "false",
    }]
  ) {
    await assertRejects(
      () =>
        runFreeTemplateStep(brief, {
          env: env(extra),
          fetch: () => {
            throw new Error("paid request forbidden");
          },
        }),
      Error,
      "template_provider_free_only",
    );
  }
  const first = await runFreeTemplateStep(brief, {
    env: env(),
    fetch: () => Promise.resolve(output(structuredClone(fixture.plan))),
  });
  for (const status of [429, 503]) {
    let calls = 0, writes = 0;
    const before = structuredClone(first.checkpoint);
    const error = await assertRejects(() =>
      runFreeTemplateStep(brief, {
        env: env({ AI_TEMPLATE_MAX_TRANSIENT_RETRIES: "2" }),
        checkpoint: first.checkpoint,
        onCheckpoint: () => {
          writes++;
        },
        fetch: () => {
          calls++;
          return Promise.resolve(
            new Response("provider private error", {
              status,
              headers: { "Retry-After": "123" },
            }),
          );
        },
      }), TemplateModelFailure);
    assertEquals(error.retryAfterSeconds, 123);
    assertEquals(calls, 1);
    assertEquals(writes, 0);
    assertEquals(first.checkpoint, before);
    assert(!error.message.includes("private"));
  }
});

Deno.test("persistence failure stops the step and never leaks DB error text or starts another model request", async () => {
  let calls = 0;
  const failure = await assertRejects(
    () =>
      runFreeTemplateStep(brief, {
        env: env(),
        fetch: () => {
          calls++;
          return Promise.resolve(output(structuredClone(fixture.plan)));
        },
        onCheckpoint: () => {
          throw new Error("private connection secret");
        },
      }),
    Error,
    "template_checkpoint_persistence_failed",
  );
  assertEquals(calls, 1);
  assert(!failure.message.includes("secret"));
});

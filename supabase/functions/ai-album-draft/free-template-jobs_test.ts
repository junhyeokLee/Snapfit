import { assertEquals, assertRejects } from "jsr:@std/assert";
import {
  advanceOneFreeTemplateJob,
  type FreeJobDatabase,
  freeTemplateRetry,
  handleFreeTemplateJob,
  secondsToPacificMidnight,
} from "./free-template-jobs.ts";
import { TemplateModelFailure } from "./template-model-provider.ts";
const safeOptionsFixture = {
  version: 1,
  topic: "travel",
  mood: "editorial",
  palette: "neutral",
  density: "balanced",
  pageCount: 20,
  aspect: "square",
};
const actor = "11111111-1111-4111-8111-111111111111",
  requestId = "22222222-2222-4222-8222-222222222222";
const claim = {
  id: "intent-id",
  actor,
  requestId,
  draftId: "draft-id",
  safeOptions: safeOptionsFixture,
  checkpoint: null,
  leaseOwner: "lease-id",
  attempts: 1,
  consecutiveFailures: 0,
};
function db(
  values: Record<string, unknown>,
  events: Array<{ name: string; params: Record<string, unknown> }>,
): FreeJobDatabase {
  return {
    rpc: (name, params) => {
      events.push({ name, params });
      return Promise.resolve({ data: values[name] ?? null, error: null });
    },
  };
}
Deno.test("create submits only canonical public options; polling uses owner-bound reads with no model side effects", async () => {
  const events: Array<{ name: string; params: Record<string, unknown> }> = [];
  const database = db({
    prepare_free_ai_template_job: { job: { id: requestId, state: "queued" } },
  }, events);
  const response = await handleFreeTemplateJob(actor, {
    action: "create",
    generationRequestId: requestId,
    expectedPointCost: 0,
    safeDesign: safeOptionsFixture,
  }, database);
  assertEquals(response.status, 202);
  assertEquals(response.headers.get("Cache-Control"), "no-store");
  assertEquals(events[0].params.p_actor, actor);
  assertEquals(events[0].params.p_options, safeOptionsFixture);
  for (const action of ["status", "latest"]) {
    await handleFreeTemplateJob(actor, {
      action,
      ...(action === "latest" ? {} : { generationRequestId: requestId }),
    }, database);
  }
  assertEquals(events.slice(1).map((e) => e.name), [
    "read_free_ai_template_job",
    "read_free_ai_template_job",
  ]);
  assertEquals(events[2].params.p_request_id, null);
});
Deno.test("an extra personal payload is rejected before DB admission", async () => {
  const events: Array<{ name: string; params: Record<string, unknown> }> = [];
  await assertRejects(
    () =>
      handleFreeTemplateJob(actor, {
        action: "create",
        generationRequestId: requestId,
        expectedPointCost: 0,
        safeDesign: safeOptionsFixture,
        prompt: "개인",
      }, db({}, events)),
    Error,
    "private_input_forbidden",
  );
  assertEquals(events.length, 0);
});
Deno.test("worker persists checkpoint before settling the job and returns only minimal progress", async () => {
  const events: Array<{ name: string; params: Record<string, unknown> }> = [];
  const checkpoint = {
    version: 2 as const,
    identity: "a".repeat(64),
    responses: [],
  };
  const result = await advanceOneFreeTemplateJob(
    db({ claim_free_ai_template_job: claim }, events),
    {
      step: async (brief, options) => {
        assertEquals(brief.prompt.includes(actor), false);
        assertEquals(brief.prompt.includes(requestId), false);
        await options?.onCheckpoint?.(checkpoint);
        return {
          checkpoint,
          modelProvider: "gemini",
          modelName: "gemini-3.6-flash",
          stage: "composition",
        };
      },
    },
  );
  assertEquals(result, { advanced: true, complete: false });
  assertEquals(events.map((e) => e.name), [
    "claim_free_ai_template_job",
    "save_free_ai_template_checkpoint",
    "settle_free_ai_template_job",
  ]);
  assertEquals(events[2].params.p_state, "queued");
  assertEquals(events[2].params.p_owner, claim.leaseOwner);
});
Deno.test("quota schedules persisted waiting rather than retrying or failing the intent", async () => {
  const events: Array<{ name: string; params: Record<string, unknown> }> = [];
  const result = await advanceOneFreeTemplateJob(
    db({ claim_free_ai_template_job: claim }, events),
    {
      step: () =>
        Promise.reject(
          new TemplateModelFailure("template_provider_rate_limited", 7200),
        ),
    },
  );
  assertEquals(result, { advanced: false, waiting: true });
  assertEquals(events.length, 2);
  assertEquals(events[1].params.p_state, "waiting");
  assertEquals(events[1].params.p_retry_seconds, 7200);
  assertEquals(events[1].params.p_result, null);
});
Deno.test("daily quota waits until Pacific reset including daylight-saving transition; unknown quota backs off", () => {
  for (
    const iso of [
      "2026-11-01T07:00:00Z",
      "2026-03-08T08:00:00Z",
      "2026-10-20T14:00:00Z",
    ]
  ) {
    const now = Date.parse(iso), seconds = secondsToPacificMidnight(now);
    const before = new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Los_Angeles",
    }).format(now);
    const after = new Intl.DateTimeFormat("en-CA", {
      timeZone: "America/Los_Angeles",
    }).format(now + seconds * 1000);
    assertEquals(before === after, false);
    assertEquals(seconds <= 25 * 3600 + 61, true);
  }
  assertEquals(
    freeTemplateRetry(
      new TemplateModelFailure("template_provider_rate_limited", 60),
      6,
      Date.now(),
    )?.seconds,
    3600,
  );
  assertEquals(
    freeTemplateRetry(new Error("template_quality_failed"), 0, Date.now()),
    null,
  );
  for (
    const code of [
      "template_generation_incomplete",
      "template_generation_invalid_json",
    ]
  ) {
    assertEquals(
      freeTemplateRetry(new TemplateModelFailure(code), 0, Date.now()),
      null,
    );
  }
});
Deno.test("lease loss never settles another worker; DB failure never schedules another model request", async () => {
  for (
    const code of [
      "ai_generation_lease_lost",
      "ai_generation_guard_unavailable",
      "template_checkpoint_persistence_failed",
    ]
  ) {
    const events: Array<{ name: string; params: Record<string, unknown> }> = [];
    const run = () =>
      advanceOneFreeTemplateJob(
        db({ claim_free_ai_template_job: claim }, events),
        { step: () => Promise.reject(new Error(code)) },
      );
    if (code.includes("guard") || code.includes("persistence")) {
      await assertRejects(run, Error, code);
    } else assertEquals(await run(), { advanced: false });
    assertEquals(events.map((e) => e.name), ["claim_free_ai_template_job"]);
  }
});

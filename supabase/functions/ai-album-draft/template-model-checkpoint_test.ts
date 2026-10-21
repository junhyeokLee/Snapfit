import { assert, assertEquals, assertRejects } from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import { generateOriginalBook } from "./template-book-engine.ts";
import {
  createTemplateModelCheckpoint,
  type TemplateModelCheckpoint,
} from "./template-model-checkpoint.ts";
import { parseTemplateBrief } from "./template-design.ts";
import { fixtureEditorialChecks } from "./test-support.ts";

const brief = parseTemplateBrief(fixture.brief);
const approve = {
  approved: true,
  qualityChecks: fixtureEditorialChecks(),
  issues: [],
  requirementChecks: fixture.plan.requirements.map((_, requirementIndex) => ({
    requirementIndex,
    satisfied: true,
    evidencePageIndexes: [0],
  })),
};

Deno.test("checkpoint resumes only missing model calls, then still validates the complete book", async () => {
  let saved: TemplateModelCheckpoint | undefined;
  const first = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    undefined,
    (value) => {
      saved = value;
    },
  );
  await assertRejects(
    () =>
      generateOriginalBook(brief, (job) =>
        first(job, async () => {
          if (job.stage === "review") throw Error("temporary provider failure");
          return structuredClone(
            job.stage === "direction" ? fixture.plan : fixture.output,
          );
        })),
    Error,
    "temporary provider failure",
  );
  assert(saved);
  assertEquals(saved.responses.length, 2);
  let calls = 0, hits = 0;
  const resume = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    saved,
    undefined,
    () => {
      hits++;
    },
  );
  const book = await generateOriginalBook(
    brief,
    (job) =>
      resume(job, async () => {
        calls++;
        assertEquals(job.stage, "review");
        return approve;
      }),
  );
  assertEquals(hits, 2);
  assertEquals(calls, 1);
  assertEquals(book.pages.length, brief.pageCount + 1);
});

Deno.test("replayed invalid outputs cannot bypass quality repairs or reset the budget", async () => {
  let saved: TemplateModelCheckpoint | undefined;
  const first = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    undefined,
    (value) => {
      saved = value;
    },
  );
  const invalid = structuredClone(fixture.output);
  invalid.pages[1].elements[0].width = 250;
  await assertRejects(
    () =>
      generateOriginalBook(brief, (job) =>
        first(job, async () => {
          if (job.stage === "direction") return structuredClone(fixture.plan);
          if (JSON.parse(job.prompt).originalRequest) {
            throw Error("temporary repair failure");
          }
          return invalid;
        })),
    Error,
    "temporary repair failure",
  );
  assert(saved);
  const resume = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    saved,
  );
  let requestedCorrection = false;
  const book = await generateOriginalBook(
    brief,
    (job) =>
      resume(job, async () => {
        if (job.stage === "review") return approve;
        const prompt = JSON.parse(job.prompt);
        assert(prompt.originalRequest);
        assertEquals(prompt.validationError.pageIndex, 1);
        assertEquals(prompt.validationError.elementIndex, 0);
        requestedCorrection = true;
        return structuredClone(fixture.output);
      }),
  );
  assert(requestedCorrection);
  assertEquals(book.pages.length, 5);
});

Deno.test("checkpoint binds the original brief and model, rejects tampering and caps resumptions", async () => {
  let saved: TemplateModelCheckpoint | undefined;
  const first = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    undefined,
    (value) => {
      saved = value;
    },
  );
  await generateOriginalBook(
    brief,
    (job) =>
      first(job, async () =>
        structuredClone(
          job.stage === "direction"
            ? fixture.plan
            : job.stage === "composition"
            ? fixture.output
            : approve,
        )),
  );
  assert(saved);
  for (
    const [changedBrief, context, checkpoint] of [
      [{ ...brief, prompt: brief.prompt + "changed" }, "gemini:test", saved],
      [brief, "other:model", saved],
      [brief, "gemini:test", { ...saved, resumeCount: 3 }],
      [brief, "gemini:test", {
        ...saved,
        responses: [...saved.responses, saved.responses[0]],
      }],
    ] as [typeof brief, string, TemplateModelCheckpoint][]
  ) {
    await assertRejects(
      () => createTemplateModelCheckpoint(changedBrief, context, checkpoint),
      Error,
      "checkpoint_invalid",
    );
  }
});

Deno.test("a resumed provider failure consumes its resume allowance even without a new response", async () => {
  let saved: TemplateModelCheckpoint | undefined;
  const first = await createTemplateModelCheckpoint(
    brief,
    "gemini:test",
    undefined,
    (value) => {
      saved = value;
    },
  );
  await assertRejects(() =>
    generateOriginalBook(brief, (job) =>
      first(job, async () => {
        if (job.stage !== "direction") throw Error("provider failure");
        return structuredClone(fixture.plan);
      }))
  );
  assert(saved);
  for (let count = 1; count <= 3; count++) {
    const resumed = await createTemplateModelCheckpoint(
      brief,
      "gemini:test",
      saved,
      (value) => {
        saved = value;
      },
    );
    await assertRejects(() =>
      generateOriginalBook(brief, (job) =>
        resumed(job, async () => {
          throw Error("provider failure");
        }))
    );
    assertEquals(saved.resumeCount, count);
  }
  await assertRejects(
    () => createTemplateModelCheckpoint(brief, "gemini:test", saved),
    Error,
    "checkpoint_invalid",
  );
});

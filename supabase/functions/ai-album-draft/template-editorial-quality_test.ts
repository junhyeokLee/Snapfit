import {
  assert,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import { createOriginalTemplate } from "./index.ts";
import {
  validateCompositionBatch,
  validateOriginalPlan,
} from "./template-composition.ts";
import { parseTemplateBrief } from "./template-design.ts";
import {
  editorialCriteria,
  editorialQuality,
  validateEditorialBook,
  validateEditorialPage,
} from "./template-editorial-quality.ts";
import { fixtureEditorialChecks } from "./test-support.ts";

const fresh = () => structuredClone(fixture);
const brief = parseTemplateBrief(fixture.brief);
const plan = () => validateOriginalPlan(fresh().plan, brief);
const pages = () =>
  validateCompositionBatch(fresh().output, [0, 1, 2, 3, 4], brief, plan());
const env = (key: string) => ({
  GEMINI_API_KEY: "synthetic-only-not-a-real-key",
  AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
  AI_TEMPLATE_RETRY_BASE_MS: "0",
  AI_TEMPLATE_ALLOW_UNPAID_USER_DATA: "true",
}[key]);
const approval = () => ({
  approved: true,
  requirementChecks: fixture.plan.requirements.map((_, requirementIndex) => ({
    requirementIndex,
    satisfied: true,
    evidencePageIndexes: [0],
  })),
  qualityChecks: fixtureEditorialChecks(),
  issues: [] as { pageIndexes: number[]; reason: string }[],
});
const response = (value: unknown) =>
  new Response(JSON.stringify({
    candidates: [{
      finishReason: "STOP",
      content: { parts: [{ text: JSON.stringify(value) }] },
    }],
  }));

Deno.test("real Gemini wire carries the editorial rubric in every stage without changing model or token budgets", async () => {
  const stages: string[] = [];
  const result = await createOriginalTemplate(brief, {
    env,
    fetch: (url, init) => {
      assertEquals(
        String(url),
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent",
      );
      const body = JSON.parse(String(init?.body));
      assert(
        body.systemInstruction.parts[0].text.includes(editorialQuality.version),
      );
      assertEquals(body.generationConfig.responseModalities, ["TEXT"]);
      assertEquals(body.generationConfig.candidateCount, 1);
      assert(!("temperature" in body.generationConfig));
      const prompt = JSON.parse(body.contents[0].parts[0].text);
      assertEquals(prompt.editorialQuality, editorialQuality);
      assert(!("inlineData" in body.contents[0].parts[0]));
      if (prompt.book) {
        stages.push("review");
        assertEquals(body.generationConfig.maxOutputTokens, 2400);
        assertEquals(
          body.generationConfig.responseJsonSchema.properties.qualityChecks
            .items.properties.criterion.enum,
          editorialCriteria,
        );
        assert(
          prompt.rules.some((rule: string) => rule.includes("heavy display")),
        );
        return Promise.resolve(response(approval()));
      }
      if (prompt.indexes) {
        stages.push("composition");
        assertEquals(body.generationConfig.maxOutputTokens, 12000);
        assertEquals(prompt.direction.typography.display.weight, 400);
        return Promise.resolve(response(fresh().output));
      }
      stages.push("direction");
      assertEquals(body.generationConfig.maxOutputTokens, 2720);
      assert(
        prompt.rules.some((rule: string) => rule.includes("regular-weight")),
      );
      return Promise.resolve(response(fresh().plan));
    },
  });
  assertEquals(stages, ["direction", "composition", "review"]);
  assertEquals(result.fallbackUsed, false);
  assertEquals(result.design?.version, 3);
});

Deno.test("weak hierarchy and incompatible fixed postcard inks are rejected before composing", () => {
  const weak = fresh();
  Object.assign(weak.plan.typography, {
    display: { ...weak.plan.typography.display, fontSize: 32 },
    heading: { ...weak.plan.typography.heading, fontSize: 24 },
    body: { ...weak.plan.typography.body, fontSize: 24 },
  });
  assertThrows(
    () => validateOriginalPlan(weak.plan, brief),
    Error,
    "editorial_type_hierarchy",
  );
  const leading = fresh();
  leading.plan.typography.body.lineHeight = 1;
  assertThrows(
    () => validateOriginalPlan(leading.plan, brief),
    Error,
    "editorial_body_leading",
  );
  const fixed = fresh();
  fixed.plan.materials.frames[1] = "studioPostcard";
  assertThrows(
    () => validateOriginalPlan(fixed.plan, brief),
    Error,
    "fixed_material_palette",
  );
  fixed.plan.palette.push("#BD524E", "#3D727A");
  assertEquals(
    validateOriginalPlan(fixed.plan, brief).materials.frames[1],
    "studioPostcard",
  );
});

Deno.test("bold layered and deliberately colorful postcard concepts remain supported", () => {
  const layered = fresh();
  layered.plan.intent.density = "layered";
  layered.plan.typography.display.weight = 800;
  layered.plan.materials.frames[1] = "studioPostcard";
  assertEquals(
    validateOriginalPlan(layered.plan, brief).typography.display.weight,
    800,
  );
  const page = pages()[1];
  const base = page.elements.find((e) => e.kind === "paper")!;
  page.elements.push(...Array.from({ length: 3 }, (_, i) => ({
    ...base,
    id: `p1_extra${i}`,
    style: "atelierGridLeaf",
  })));
  assertThrows(
    () => validateEditorialPage(page, plan()),
    Error,
    "material_density",
  );
  validateEditorialPage(page, validateOriginalPlan(layered.plan, brief));
});

Deno.test("long numbered filler copy fails while requested repeated wording and running labels survive", () => {
  const sample = pages();
  const copy = "같은 말로 모든 사진의 소중한 순간을 반복해서 채웁니다";
  for (const page of sample.slice(1, 4)) {
    page.elements.find((e) => e.kind === "text")!.text =
      `${copy} ${page.pageIndex}`;
  }
  assertThrows(
    () => validateEditorialBook(sample, plan()),
    Error,
    "repeated_copy",
  );
  const requested = plan();
  requested.intent.verbatim.push(copy);
  validateEditorialBook(sample, requested);
  for (const page of sample.slice(1, 4)) {
    page.elements.find((e) => e.kind === "text")!.text = "산책의 기록";
  }
  validateEditorialBook(sample, plan());
  for (const page of sample.slice(1, 4)) {
    Object.assign(page.elements.find((e) => e.kind === "text")!, {
      text: "바람을 따라 천천히 걷던 제주의 긴 산책 기록",
      typography: "caption",
      y: .92,
      height: .04,
    });
  }
  validateEditorialBook(sample, plan());
  for (const page of sample.slice(1, 4)) {
    Object.assign(page.elements.find((e) => e.kind === "text")!, {
      y: .4,
      height: .12,
    });
  }
  assertThrows(
    () => validateEditorialBook(sample, plan()),
    Error,
    "repeated_copy",
  );
});

for (const missing of ["qualityChecks", "evidence", "reason", "duplicate"]) {
  Deno.test(`Gemini review cannot approve a book with missing ${missing}`, async () => {
    const review = approval();
    if (missing === "qualityChecks") {
      delete (review as Partial<typeof review>).qualityChecks;
    } else if (missing === "evidence") {
      review.qualityChecks[1].evidencePageIndexes = [];
    } else if (missing === "reason") {
      review.qualityChecks[1].reason = "";
    } else {
      review.qualityChecks[1].criterion = review.qualityChecks[0].criterion;
    }
    await assertRejects(() =>
      createOriginalTemplate(brief, {
        env,
        fetch: (_url, init) => {
          const prompt = JSON.parse(
            JSON.parse(String(init?.body)).contents[0].parts[0].text,
          );
          return Promise.resolve(response(
            prompt.book
              ? review
              : prompt.indexes
              ? fresh().output
              : fresh().plan,
          ));
        },
      })
    );
  });
}

Deno.test("editorial rejection repairs only the affected page, keeps accepted pages and rechecks every criterion", async () => {
  const requests: number[][] = [];
  let reviews = 0;
  const result = await createOriginalTemplate(brief, {
    env,
    fetch: (_url, init) => {
      const prompt = JSON.parse(
        JSON.parse(String(init?.body)).contents[0].parts[0].text,
      );
      if (prompt.book) {
        reviews++;
        const review = approval();
        if (reviews === 1) {
          review.approved = false;
          review.qualityChecks[2] = {
            criterion: "photo_text_balance",
            satisfied: false,
            evidencePageIndexes: [2],
            reason:
              "Synthetic page 2 caption needs a clearer relationship to its image.",
          };
          review.issues = [{
            pageIndexes: [2],
            reason:
              "Recompose page 2 caption and keep the other pages unchanged.",
          }];
        }
        return Promise.resolve(response(review));
      }
      if (!prompt.indexes) return Promise.resolve(response(fresh().plan));
      requests.push(prompt.indexes);
      const output = fresh().output;
      if (prompt.repairFeedback) {
        assertEquals(
          prompt.repairFeedback.existingPageGeometry.map((
            p: { pageIndex: number },
          ) => p.pageIndex),
          [0, 1, 3, 4],
        );
        output.pages[2].elements[2].text = "길에서 눈에 머문 장면";
      }
      return Promise.resolve(
        response({ pages: prompt.indexes.map((i: number) => output.pages[i]) }),
      );
    },
  });
  assertEquals(requests, [[0, 1, 2, 3, 4], [2]]);
  assertEquals(reviews, 2);
  assertEquals(result.design?.pages[0].elements, pages()[0].elements);
  assertEquals(
    result.design?.pages[2].elements.find((e) => e.kind === "text")?.text,
    "길에서 눈에 머문 장면",
  );
});

for (
  const failure of [
    "unfixable hierarchy",
    "unfixable heavy title",
    "missing review evidence",
  ]
) {
  Deno.test(`synthetic engine never returns a draft for ${failure}`, async () => {
    let calls = 0;
    await assertRejects(() =>
      createOriginalTemplate(
        brief,
        {
          env,
          fetch: (_url, init) => {
            calls++;
            const raw = JSON.parse(
              JSON.parse(String(init?.body)).contents[0].parts[0].text,
            );
            const prompt = raw.originalRequest
              ? JSON.parse(raw.originalRequest)
              : raw;
            if (prompt.book) {
              const review = approval();
              if (failure === "missing review evidence") {
                review.qualityChecks[0].evidencePageIndexes = [];
              } else {
                review.approved = false;
                review.qualityChecks[0].satisfied = false;
                review.qualityChecks[0].reason =
                  "The quiet book retains a heavy display weight that overwhelms its cover.";
                review.issues = [{
                  pageIndexes: [0],
                  reason: "The quiet cover still overwhelms its photograph.",
                }];
              }
              return Promise.resolve(response(review));
            }
            if (prompt.indexes) {
              return Promise.resolve(
                response({
                  pages: prompt.indexes.map((i: number) =>
                    fresh().output.pages[i]
                  ),
                }),
              );
            }
            const direction = fresh().plan;
            if (failure === "unfixable hierarchy") {
              direction.typography.display.fontSize = 32;
              direction.typography.heading.fontSize = 24;
              direction.typography.body.fontSize = 24;
            }
            if (failure === "unfixable heavy title") {
              direction.typography.display
                .weight = 800;
            }
            return Promise.resolve(response(direction));
          },
        },
      ), Error);
    assert(calls <= 5);
  });
}

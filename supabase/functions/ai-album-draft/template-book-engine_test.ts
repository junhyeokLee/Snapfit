import {
  assert,
  assertAlmostEquals,
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import typography from "./typography-contract.json" with { type: "json" };
import { luminance, parseTemplateBrief } from "./template-design.ts";
import {
  compositionCharacterWidthUnits,
  compositionSignature,
  compositionTextMetrics,
  CompositionValidationError,
  validateCompositionBatch,
  validateOriginalBook,
  validateOriginalPlan,
} from "./template-composition.ts";
import {
  bookBatches,
  type BookModelRequest,
  compositionSchema,
  directionSchema,
  generateOriginalBook,
} from "./template-book-engine.ts";
import { createOriginalTemplate } from "./index.ts";
import { fixtureEditorialChecks, openAiContractEnv } from "./test-support.ts";

const fresh = () => structuredClone(fixture);
const brief = parseTemplateBrief(fixture.brief);
const plan = () => validateOriginalPlan(fresh().plan, brief);
function payload(job: BookModelRequest): Record<string, any> {
  const raw = JSON.parse(job.prompt);
  return raw.originalRequest ? JSON.parse(raw.originalRequest) : raw;
}
const approve = (count: number) => ({
  approved: true,
  qualityChecks: fixtureEditorialChecks(),
  requirementChecks: Array.from(
    { length: count },
    (_, i) => ({
      requirementIndex: i,
      satisfied: true,
      evidencePageIndexes: [0],
    }),
  ),
  issues: [],
});

Deno.test("actual Gemini direction request exposes existing type limits and concise complete-book planning", async () => {
  let directionRequests = 0;
  const result = await createOriginalTemplate(brief, {
    env: (name) => ({
      GEMINI_API_KEY: "synthetic-contract-only",
      AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
    }[name]),
    fetch: (_url, init) => {
      const request = JSON.parse(String(init?.body));
      const prompt = JSON.parse(request.contents[0].parts[0].text);
      let output: unknown;
      if (prompt.book) output = approve(fixture.plan.requirements.length);
      else if (prompt.indexes) output = fresh().output;
      else {
        directionRequests++;
        const schema = request.generationConfig.responseJsonSchema;
        assertEquals(schema, directionSchema);
        const fontWeights = Object.fromEntries(
          Object.entries(typography.fonts).map((
            [font, value],
          ) => [font, value.weights]),
        );
        for (const [role, bounds] of Object.entries(typography.roles)) {
          const type = schema.properties.typography.properties[role].properties;
          assertEquals(type.fontSize.minimum, bounds.min);
          assertEquals(type.fontSize.maximum, bounds.max);
          assertEquals(type.lineHeight.minimum, role === "body" ? 1.2 : 1);
          assertEquals(type.lineHeight.maximum, 1.6);
          assert(!type.weight.enum.includes(500));
          assert(type.weight.description.includes(JSON.stringify(fontWeights)));
        }
        assertEquals(prompt.typographyLimits.fontWeights, fontWeights);
        assertEquals(prompt.typographyLimits.lineHeight, {
          minimum: 1,
          maximum: 1.6,
          bodyMinimum: 1.2,
        });
        assertEquals(
          schema.properties.pages.items.properties.intent.maxLength,
          60,
        );
        assertEquals(schema.properties.compositions.items.maxLength, 100);
        assertEquals(schema.properties.rationale.maxLength, 180);
        assertEquals(
          schema.properties.intent.properties.understanding.maxLength,
          180,
        );
        assert(prompt.planningCopy.includes("facing-pair relationships"));
        assert(
          prompt.rules.some((rule: string) =>
            rule.includes("ONLY front cover") &&
            rule.includes("closing INTERIOR, never a back cover")
          ),
        );
        output = fresh().plan;
      }
      return Promise.resolve(
        new Response(JSON.stringify({
          candidates: [{
            finishReason: "STOP",
            content: { parts: [{ text: JSON.stringify(output) }] },
          }],
        })),
      );
    },
  });
  assertEquals(directionRequests, 1);
  assertEquals(result.design?.pages.length, 5);
  assertEquals(
    result.design?.version === 3 &&
      result.design.artDirection.pages.map((page) => page.intent),
    fixture.plan.pages.map((page) => page.intent),
  );
});

Deno.test("the observed 1.7 line height remains invalid and consumes only the bounded direction repair", async () => {
  const invalid = fresh().plan;
  invalid.typography.body.lineHeight = 1.7;
  assertThrows(
    () => validateOriginalPlan(invalid, brief),
    Error,
    "invalid_geometry",
  );
  let directions = 0;
  const result = await generateOriginalBook(brief, async (job) => {
    if (job.stage === "direction") {
      directions++;
      if (directions === 1) return invalid;
      const feedback = JSON.parse(job.prompt);
      assertEquals(
        feedback.validationError,
        "template_design_invalid_geometry",
      );
      const fixed = fresh().plan;
      fixed.typography.body.lineHeight = 1.6;
      return fixed;
    }
    if (job.stage === "composition") return fresh().output;
    return approve(fixture.plan.requirements.length);
  });
  assertEquals(directions, 2);
  assertEquals(result.artDirection.typography.body.lineHeight, 1.6);
  assertEquals(
    result.pages.map((page) => page.purpose),
    fixture.plan.pages.map((page) => page.intent),
  );
});

Deno.test("actual Gemini composition receives valid flat text pairs and excludes the observed muted caption on white", async () => {
  const direction = fresh().plan;
  direction.palette.push("#7D9B8A", "#193627");
  let composed = false;
  const result = await createOriginalTemplate(brief, {
    env: (name) => ({
      GEMINI_API_KEY: "synthetic-contract-only",
      AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
    }[name]),
    fetch: (_url, init) => {
      const request = JSON.parse(String(init?.body));
      const prompt = JSON.parse(request.contents[0].parts[0].text);
      let output: unknown;
      if (prompt.book) output = approve(direction.requirements.length);
      else if (prompt.indexes) {
        composed = true;
        assertEquals(prompt.direction.palette, direction.palette);
        assertEquals(prompt.flatTextContrast.minimum, 4.5);
        const pairs = prompt.flatTextContrast.allowedPairs as {
          foreground: string;
          background: string;
        }[];
        const has = (foreground: string, background: string) =>
          pairs.some((pair) =>
            pair.foreground === foreground && pair.background === background
          );
        assert(!has("#7D9B8A", "#FFFFFF"));
        assert(has("#193627", "#FFFFFF"));
        assert(has("#FFFFFF", "#193627"));
        for (const pair of pairs) {
          const a = luminance(pair.foreground), b = luminance(pair.background);
          assert((Math.max(a, b) + .05) / (Math.min(a, b) + .05) >= 4.5);
        }
        assert(
          prompt.rules.some((rule: string) =>
            rule.includes("muted decorative accent") &&
            rule.includes("White text on dark paper")
          ),
        );
        assert(
          prompt.rules.some((rule: string) =>
            rule.includes("Large outline titles") &&
            rule.includes("may sit on photos")
          ),
        );
        output = fresh().output;
      } else output = direction;
      return Promise.resolve(
        new Response(JSON.stringify({
          candidates: [{
            finishReason: "STOP",
            content: { parts: [{ text: JSON.stringify(output) }] },
          }],
        })),
      );
    },
  });
  assert(composed);
  assertEquals(
    result.design?.version === 3 && result.design.artDirection.palette,
    direction.palette,
  );
});

Deno.test("the contrast gate still rejects muted captions and preserves white on dark paper and photo outline titles", () => {
  const direction = fresh().plan;
  direction.palette.push("#7D9B8A");
  const validated = validateOriginalPlan(direction, brief);
  const invalid = fresh().output;
  invalid.pages[1].background = "#FFFFFF";
  invalid.pages[1].elements[2].color = "#7D9B8A";
  assertThrows(
    () => validateCompositionBatch(invalid, [0, 1, 2, 3, 4], brief, validated),
    Error,
    "low_contrast",
  );
  const dark = fresh().output;
  dark.pages[2].background = "#16392D";
  dark.pages[2].elements[1].color = "#16392D";
  dark.pages[2].elements[2].color = "#FFFFFF";
  const accepted = validateCompositionBatch(
    dark,
    [0, 1, 2, 3, 4],
    brief,
    validated,
  );
  assertEquals(accepted[2].elements[2].color, "#FFFFFF");
  assertEquals(accepted[0].elements[1].style, "outline");
  assertEquals(accepted[0].elements[1].color, "#FFFFFF");
});

Deno.test("the observed explicit two-line heading needs three lines after wrapping and remains a rejected short box", () => {
  const text = "아무런 말 없이\n바다 앞에 섰을 때 비로소 들리는 것들";
  const direction = fresh().plan;
  direction.typography.heading.fontSize = 22;
  direction.typography.heading.lineHeight = 1.4;
  const validated = validateOriginalPlan(direction, brief);
  const metrics = compositionTextMetrics(
    text,
    .68,
    validated.typography.heading,
    brief,
  );
  assertEquals(text.split("\n").length, 2);
  assertEquals(metrics.lineCount, 3);
  assertEquals(metrics.requiredHeightPixels, 3 * 22 * 1.4);
  assertEquals(metrics.requiredHeightNormalized, 3 * 22 * 1.4 / 500);
  assert(metrics.requiredHeightNormalized > .12);
  const output = fresh().output;
  Object.assign(output.pages[1].elements[2], {
    text,
    typography: "heading",
    width: .68,
    height: .12,
  });
  assertThrows(
    () => validateCompositionBatch(output, [0, 1, 2, 3, 4], brief, validated),
    Error,
    "text_overflow",
  );
  assertEquals(output.pages[1].elements[2].height, .12);
  assertEquals(validated.typography.heading.fontSize, 22);
  output.pages[1].elements[2].height = metrics.requiredHeightNormalized;
  const accepted = validateCompositionBatch(
    output,
    [0, 1, 2, 3, 4],
    brief,
    validated,
  );
  assertEquals(accepted[1].elements[2].text, text);
  assertEquals(
    accepted[1].elements[2].height,
    metrics.requiredHeightNormalized,
  );
});

Deno.test("shared text metrics preserve weighted ASCII/space/Hangul and every explicit empty line in all aspects", () => {
  const style = { fontSize: 50, lineHeight: 1.4 };
  assertEquals(compositionCharacterWidthUnits, {
    space: .32,
    ascii: .62,
    otherIncludingHangul: 1,
  });
  for (const aspect of ["portrait", "square", "landscape"] as const) {
    const request = { ...brief, aspect };
    assertEquals(
      compositionTextMetrics("가A ", .2, style, request).lineCount,
      1,
    );
    assertEquals(
      compositionTextMetrics("가AA", .2, style, request).lineCount,
      2,
    );
    const emptyLine = compositionTextMetrics("가A \n\n나", .2, style, request);
    assertEquals(emptyLine.lineCount, 3);
    assertEquals(emptyLine.requiredHeightPixels, 3 * 50 * 1.4);
    assertAlmostEquals(
      emptyLine.requiredHeightNormalized,
      emptyLine.lineCount * emptyLine.lineHeightNormalized,
      1e-12,
    );
  }
});

Deno.test("Gemini composition receives planned role line heights and conservative width capacities from the validation helper", async () => {
  let inspected = false;
  let reviewedCopy = false;
  await createOriginalTemplate(brief, {
    env: (
      name,
    ) => ({
      GEMINI_API_KEY: "synthetic-contract-only",
      AI_TEMPLATE_MIN_CALL_INTERVAL_MS: "0",
    }[name]),
    fetch: (_url, init) => {
      const prompt = JSON.parse(
        JSON.parse(String(init?.body)).contents[0].parts[0].text,
      );
      let output: unknown;
      if (prompt.book) {
        reviewedCopy = true;
        assert(
          prompt.rules.some((rule: string) =>
            rule.includes("Proofread short Korean copy") &&
            rule.includes("issue on the affected page") &&
            rule.includes("exact requested phrases")
          ),
        );
        output = approve(fixture.plan.requirements.length);
      } else if (prompt.indexes) {
        inspected = true;
        assert(
          prompt.rules.some((rule: string) =>
            rule.includes("Proofread short Korean copy") &&
            rule.includes("only newly authored copy")
          ),
        );
        assertEquals(
          prompt.textFit.characterWidthUnits,
          compositionCharacterWidthUnits,
        );
        for (const [role, style] of Object.entries(plan().typography)) {
          const sent = prompt.textFit.plannedRoles[role];
          assertEquals(sent.fontSize, style.fontSize);
          assertEquals(sent.lineHeight, style.lineHeight);
          assertEquals(
            sent.lineHeightNormalized,
            compositionTextMetrics("", 1, style, brief).lineHeightNormalized,
          );
          for (const width of [.3, .5, .68, .84]) {
            assertEquals(
              sent.conservativeHangulCharsPerLineAtWidth[String(width)],
              Math.floor(
                compositionTextMetrics("", width, style, brief)
                  .capacityUnitsPerLine,
              ),
            );
          }
        }
        assert(
          prompt.textFit.lineCountRule.includes(
            "explicit two-line string may wrap into three",
          ),
        );
        assert(
          prompt.textFit.boxHeightRule.includes(
            "Never shrink the planned font/lineHeight",
          ),
        );
        output = fresh().output;
      } else output = fresh().plan;
      return Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [{
              finishReason: "STOP",
              content: { parts: [{ text: JSON.stringify(output) }] },
            }],
          }),
        ),
      );
    },
  });
  assert(inspected);
  assert(reviewedCopy);
});

Deno.test("composition schema prevents pixel coordinates and reports the exact invalid element", () => {
  const schema = compositionSchema as any;
  const element =
    schema.properties.pages.items.properties.elements.items.properties;
  for (const field of ["x", "y", "width", "height"]) {
    assertEquals(element[field].maximum, 1);
    assert(element[field].minimum >= 0);
  }
  const sample = fresh();
  sample.output.pages[2].elements[0].width = 250;
  try {
    validateCompositionBatch(sample.output, [0, 1, 2, 3, 4], brief, plan());
    throw new Error("should reject pixels");
  } catch (error) {
    assert(error instanceof CompositionValidationError);
    assertEquals(error.message, "template_design_invalid_geometry");
    assertEquals(error.pageIndex, 2);
    assertEquals(error.elementIndex, 0);
  }
});

Deno.test("v3 allows editable framed photos, papers, slight overlap and outlined photo titles", () => {
  const pages = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  const book = validateOriginalBook(pages, brief, plan());
  assertEquals(book.version, 3);
  assertEquals(book.generation, {
    strategy: "original_spread_batches_v1",
    pageCount: 4,
  });
  assert(!("layoutExpansion" in book));
  assertEquals(book.pages[1].elements[1].rotation, -.035);
  assertEquals(book.pages[3].elements[2].style, "studioFilm");
});

for (const aspect of ["portrait", "square", "landscape"] as const) {
  Deno.test(`v3 validates actual rotated bounds for ${aspect}`, () => {
    const sample = fresh();
    assertEquals(
      validateCompositionBatch(sample.output, [0, 1, 2, 3, 4], {
        ...brief,
        aspect,
      }, plan()).length,
      5,
    );
    Object.assign(sample.output.pages[1].elements[1], {
      x: 0,
      y: 0,
      width: 1,
      height: 1,
      rotation: .12,
    });
    assertThrows(
      () =>
        validateCompositionBatch(sample.output, [0, 1, 2, 3, 4], {
          ...brief,
          aspect,
        }, plan()),
      Error,
      "out_of_bounds",
    );
  });
}

Deno.test("v3 rejects unknown/paid materials and injected geometry fields", () => {
  const sample = fresh();
  sample.plan.materials.frames[0] = "signatureVowPocket";
  assertThrows(
    () => validateOriginalPlan(sample.plan, brief),
    Error,
    "not_licensed",
  );
  const other = fresh();
  other.output.pages[0].elements[0].style = "atelierDeepMat";
  assertThrows(
    () =>
      validateCompositionBatch(other.output, [0, 1, 2, 3, 4], brief, plan()),
    Error,
    "photo_frame",
  );
  Object.assign(other.output.pages[0].elements[0], {
    style: "none",
    url: "https://example.test/paid.png",
  });
  assertThrows(
    () =>
      validateCompositionBatch(other.output, [0, 1, 2, 3, 4], brief, plan()),
    Error,
    "element_identity",
  );
});

Deno.test("v3 rejects hidden text, excessive photo cover and unsafe photo captions", () => {
  const hidden = fresh();
  hidden.output.pages[0].elements.push({
    ...hidden.output.pages[0].elements[0],
    id: "p0_overlay",
    kind: "paper",
    style: "rect",
    color: "#FFFFFF",
    zIndex: 99,
  });
  assertThrows(
    () =>
      validateCompositionBatch(hidden.output, [0, 1, 2, 3, 4], brief, plan()),
    Error,
    "text_occluded",
  );
  const covered = fresh();
  covered.output.pages[1].elements.push({
    ...covered.output.pages[1].elements[0],
    id: "p1_overlay",
    style: "rect",
    rotation: 0,
    zIndex: 99,
  });
  assertThrows(
    () =>
      validateCompositionBatch(covered.output, [0, 1, 2, 3, 4], brief, plan()),
    Error,
    "photo_occluded",
  );
  const caption = fresh();
  caption.output.pages[0].elements[1].style = "plain";
  assertThrows(
    () =>
      validateCompositionBatch(caption.output, [0, 1, 2, 3, 4], brief, plan()),
    Error,
    "needs_backing",
  );
});

Deno.test("v3 preserves exact user copy and rejects invented dates", () => {
  const wrong = fresh();
  wrong.plan.intent.verbatim = ["새로운 제목"];
  assertThrows(
    () => validateOriginalPlan(wrong.plan, brief),
    Error,
    "verbatim_drift",
  );
  const missing = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  missing[0].elements[1].text = "다른 말";
  assertThrows(
    () => validateOriginalBook(missing, brief, plan()),
    Error,
    "missing_verbatim",
  );
  const date = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  date[4].elements[2].text = "2026-10-19";
  assertThrows(
    () => validateOriginalBook(date, brief, plan()),
    Error,
    "invented_date",
  );
});

Deno.test("v3 repetition gate ignores color/frame changes and tiny coordinate jitter", () => {
  const pages = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  pages[2].elements = pages[1].elements.map((e) => ({
    ...e,
    id: e.id.replace("p1_", "p2_"),
    x: e.x + .001,
    style: e.kind === "photo" ? "studioOval" : e.style,
  }));
  assertEquals(compositionSignature(pages[1]), compositionSignature(pages[2]));
  assertThrows(
    () => validateOriginalBook(pages, brief, plan()),
    Error,
    "repeated_page",
  );
});

Deno.test("v3 rejects mirrored filler pages and sparse book arrays", () => {
  const pages = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  const sparse = [...pages];
  delete sparse[2];
  assertThrows(
    () => validateOriginalBook(sparse, brief, plan()),
    Error,
    "book_incomplete",
  );
  pages[2].elements = pages[1].elements.map((e) => ({
    ...e,
    id: e.id.replace("p1_", "p2_"),
    x: 1 - e.x - e.width,
    rotation: -e.rotation,
  }));
  assertEquals(compositionSignature(pages[1]), compositionSignature(pages[2]));
  assertThrows(
    () => validateOriginalBook(pages, brief, plan()),
    Error,
    "repeated_page",
  );
});

Deno.test("v3 preserves Korean quotation marks and does not silently discard long requested copy", () => {
  const request = {
    ...brief,
    prompt: "산책 앨범, 제목은 「바람을 따라」. 날짜는 쓰지 마세요.",
  };
  assertEquals(validateOriginalPlan(fresh().plan, request).intent.verbatim, [
    "바람을 따라",
  ]);
  assertThrows(
    () =>
      validateOriginalPlan(fresh().plan, {
        ...brief,
        prompt: `제목은 「${"가".repeat(161)}」`,
      }),
    Error,
    "verbatim_limit",
  );
  const pages = validateCompositionBatch(
    fresh().output,
    [0, 1, 2, 3, 4],
    brief,
    plan(),
  );
  pages[4].elements.find((e) => e.kind === "text")!.text = "2026년 10월 19일";
  assertThrows(
    () => validateOriginalBook(pages, brief, plan()),
    Error,
    "invented_date",
  );
});

function longFixture(count: number) {
  const sample = fresh();
  const request = { ...brief, pageCount: count };
  const direction = {
    ...sample.plan,
    pages: Array.from(
      { length: count + 1 },
      (_, i) => ({
        role: i === 0 ? "cover" : i === count ? "closing" : "story",
        intent: `Synthetic contract page ${i}`,
        photoCount: 1,
      }),
    ),
    compositions: Array.from(
      { length: count + 1 },
      (_, i) => `Synthetic geometry case ${i}`,
    ),
  };
  const pages = Array.from(
    { length: count + 1 },
    (_, i) =>
      i === 0 ? sample.output.pages[0] : {
        pageIndex: i,
        background: "#FFFFFF",
        elements: [{
          id: `p${i}_photo`,
          kind: "photo",
          x: .05 + (i % 6) * .05,
          y: .05 + Math.floor(i / 6) * .025,
          width: .3 + (i % 5) * .07,
          height: .22 + (Math.floor(i / 5) % 4) * .06,
          color: "#DDECE4",
          style: "none",
          rotation: 0,
          zIndex: 10,
          text: null,
          typography: null,
          align: null,
        }],
      },
  );
  return { request, direction, pages };
}

for (const count of [20, 24, 36, 80]) {
  Deno.test(`v3 generates all ${count} unique interiors instead of expanding 16`, async () => {
    const sample = longFixture(count),
      stages: string[] = [],
      requested: number[] = [];
    let active = 0, peak = 0;
    const result = await generateOriginalBook(sample.request, async (job) => {
      stages.push(job.stage);
      const data = payload(job);
      if (job.stage === "direction") return sample.direction;
      if (job.stage === "review") {
        return approve(sample.direction.requirements.length);
      }
      active++;
      peak = Math.max(peak, active);
      await Promise.resolve();
      active--;
      requested.push(...data.indexes);
      return { pages: data.indexes.map((i: number) => sample.pages[i]) };
    });
    assertEquals(result.pages.length, count + 1);
    assertEquals(
      [...requested].sort((a, b) => a - b),
      Array.from({ length: count + 1 }, (_, i) => i),
    );
    assertEquals(
      new Set(result.pages.slice(1).map(compositionSignature)).size,
      count,
    );
    assert(peak <= 2);
    assertEquals(
      stages.filter((s) => s === "composition").length,
      bookBatches(count).length,
    );
    for (const indexes of bookBatches(count)) {
      for (const index of indexes.filter((i) => i > 0 && i % 2 === 1)) {
        assert(indexes.includes(index + 1));
      }
    }
  });
}

Deno.test("v3 corrects a bad batch without replacing the plan or unbounded retries", async () => {
  let compositions = 0, directions = 0;
  const result = await generateOriginalBook(brief, async (job) => {
    if (job.stage === "direction") {
      directions++;
      return fresh().plan;
    }
    if (job.stage === "review") {
      return approve(fixture.plan.requirements.length);
    }
    compositions++;
    const sample = fresh();
    if (compositions === 1) sample.output.pages[2].elements[0].width = 2;
    return sample.output;
  });
  assertEquals(result.pages.length, 5);
  assertEquals(directions, 1);
  assertEquals(compositions, 2);
  let attempts = 0;
  await assertRejects(
    () =>
      generateOriginalBook(brief, async (job) => {
        attempts++;
        if (job.stage === "direction") return fresh().plan;
        return { pages: [] };
      }),
    Error,
    "quality_failed",
  );
  assertEquals(attempts, 3);
});

Deno.test("v3 stops scheduling and repairing batches after either worker fails", async () => {
  const sample = longFixture(36);
  let pending!: (value: unknown) => void;
  const waiting = new Promise<unknown>((resolve) => {
    pending = resolve;
  });
  const requests: number[][] = [];
  const result = generateOriginalBook(sample.request, async (job) => {
    if (job.stage === "direction") return sample.direction;
    const indexes = payload(job).indexes as number[];
    requests.push(indexes);
    if (indexes[0] === 0) return waiting;
    throw new Error("quota_unavailable");
  });
  await assertRejects(() => result, Error, "quota_unavailable");
  pending({ pages: [] });
  await waiting;
  await new Promise((resolve) => setTimeout(resolve, 0));
  assertEquals(requests.length, 2);
});

Deno.test("v3 semantic repair touches only the identified page and rechecks it", async () => {
  const requests: number[][] = [];
  let reviews = 0;
  await generateOriginalBook(brief, async (job) => {
    if (job.stage === "direction") return fresh().plan;
    if (job.stage === "review") {
      reviews++;
      if (reviews === 1) {
        return {
          approved: false,
          qualityChecks: fixtureEditorialChecks(),
          requirementChecks: fixture.plan.requirements.map((_, i) => ({
            requirementIndex: i,
            satisfied: true,
            evidencePageIndexes: [0],
          })),
          issues: [{
            pageIndexes: [3],
            reason: "Synthetic correction to this page's concept.",
          }],
        };
      }
      return approve(fixture.plan.requirements.length);
    }
    const indexes = payload(job).indexes as number[];
    requests.push(indexes);
    return { pages: indexes.map((i) => fresh().output.pages[i]) };
  });
  assertEquals(requests, [[0, 1, 2, 3, 4], [3]]);
  assertEquals(reviews, 2);
});

Deno.test("v3 rejects fabricated semantic approval and propagates provider failure", async () => {
  await assertRejects(
    () =>
      generateOriginalBook(
        brief,
        async (job) =>
          job.stage === "direction"
            ? fresh().plan
            : job.stage === "composition"
            ? fresh().output
            : { approved: true, requirementChecks: [], issues: [] },
      ),
    Error,
    "review_invalid",
  );
  let calls = 0;
  await assertRejects(
    () =>
      generateOriginalBook(brief, () => {
        calls++;
        throw new Error("quota_unavailable");
      }),
    Error,
    "quota_unavailable",
  );
  assertEquals(calls, 1);
});

Deno.test("v3 transport negotiates strict structured output with no catalog fallback", async () => {
  const stages: string[] = [];
  const result = await createOriginalTemplate(brief, {
    env: openAiContractEnv("test-only"),
    fetch: ((_url, init) => {
      const request = JSON.parse(String(init?.body));
      assertEquals(request.response_format.type, "json_schema");
      assertEquals(request.response_format.json_schema.strict, true);
      const stage = request.response_format.json_schema.name;
      stages.push(stage);
      const content = stage.includes("direction")
        ? fresh().plan
        : stage.includes("composition")
        ? fresh().output
        : approve(fixture.plan.requirements.length);
      return Promise.resolve(
        new Response(
          JSON.stringify({
            choices: [{
              finish_reason: "stop",
              message: { content: JSON.stringify(content) },
            }],
          }),
        ),
      );
    }) as typeof fetch,
  });
  assertEquals(result.design?.version, 3);
  assertEquals(result.fallbackUsed, false);
  assertEquals(result.recommendedPhotos, []);
  assertEquals(result.curationNotes, []);
  assertEquals(stages, [
    "snapfit_direction_v3",
    "snapfit_composition_v3",
    "snapfit_review_v3",
  ]);
});

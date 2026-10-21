import { assertEquals, assertThrows } from "jsr:@std/assert";
import fixture from "../../test/fixtures/ai_template_v3.json" with {
  type: "json",
};
import {
  validateCompositionBatch,
  validateOriginalBook,
  validateOriginalPlan,
} from "../../supabase/functions/ai-album-draft/template-composition.ts";
import { parseTemplateBrief } from "../../supabase/functions/ai-album-draft/template-design.ts";
import { polishEditorialBook } from "./editorial-polish.ts";

const brief = parseTemplateBrief(fixture.brief);
const plan = validateOriginalPlan(fixture.plan, brief);
function book() {
  return validateOriginalBook(
    validateCompositionBatch(
      structuredClone(fixture.output),
      [0, 1, 2, 3, 4],
      brief,
      plan,
    ),
    brief,
    plan,
  );
}

Deno.test("editorial polishing preserves the AI's geometry, photo counts and original source", () => {
  const source = book(), before = JSON.stringify(source);
  const polished = polishEditorialBook(source, brief, {
    reason: "Visual review of actual renders",
    displayWeight: 400,
    frames: { none: "studioRounded" },
  });
  assertEquals(JSON.stringify(source), before);
  const geometry = (value: ReturnType<typeof book>) =>
    value.pages.map((page) =>
      page.elements.map(
        (element) => [
          element.id,
          element.kind,
          element.x,
          element.y,
          element.width,
          element.height,
          element.rotation,
          element.zIndex,
        ],
      )
    );
  assertEquals(geometry(polished), geometry(source));
  assertEquals(polished.artDirection.typography.display.weight, 400);
});

Deno.test("editorial polishing cannot inject paid materials, unsupported weights or lose requested exact text", () => {
  const source = book(), quote = source.artDirection.intent.verbatim[0];
  const text = source.pages.flatMap((p) => p.elements).find((e) =>
    e.text === quote
  )!;
  for (
    const edits of [
      { reason: "review", frames: { none: "atelierDeepMat" } },
      { reason: "review", displayWeight: 700 },
      { reason: "review", texts: { [text.id]: "requested copy removed" } },
      { reason: "review", texts: { unknown: "unknown target" } },
    ]
  ) assertThrows(() => polishEditorialBook(source, brief, edits));
});

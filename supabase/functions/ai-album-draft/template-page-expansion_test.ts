import { assertEquals, assertThrows } from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v2.json" with {
  type: "json",
};
import { parseTemplateBrief } from "./template-design.ts";
import {
  validateArtDirection,
  validateDirectedTemplate,
} from "./template-art-direction.ts";
import { expandTemplatePages } from "./template-page-expansion.ts";
import { handleAiAlbumDraftRequest } from "./index.ts";

Deno.test("page contract accepts physical even20..80 and legacy4..16 only", () => {
  for (const pageCount of [4, 8, 16, 20, 22, 50, 52, 80]) {
    assertEquals(
      parseTemplateBrief({ ...fixture.brief, pageCount }).pageCount,
      pageCount,
    );
  }
  for (
    const pageCount of [0, 2, 17, 18, 19, 21, 79, 81, 82, 20.1, "20", null]
  ) {
    assertThrows(() => parseTemplateBrief({ ...fixture.brief, pageCount }));
  }
});

function validatedLegacyDesign() {
  const brief = parseTemplateBrief(fixture.brief);
  return validateDirectedTemplate(
    fixture.output,
    brief,
    validateArtDirection(fixture.plan, brief),
  );
}

Deno.test("expansion retains cover/opener/closing, metadata and independently editable IDs", () => {
  const source = validatedLegacyDesign();
  assertEquals(expandTemplatePages(source, 4), source);
  const result = expandTemplatePages(source, 80);
  assertEquals(source.pages.length, 5); // source is not mutated
  assertEquals(result.pages.length, 81);
  assertEquals(result.pages[0].purpose, source.pages[0].purpose);
  assertEquals(result.pages[1].purpose, source.pages[1].purpose);
  assertEquals(result.pages[80].purpose, source.pages[4].purpose);
  assertEquals(result.layoutExpansion, {
    strategy: "repeat_inner_layouts_v1",
    sourcePageCount: 4,
    finalPageCount: 80,
  });
  const elements = result.pages.flatMap((p) => p.elements);
  assertEquals(new Set(elements.map((e) => e.id)).size, elements.length);
  if (result.version !== 2) throw new Error("Expected directed design");
  assertEquals(result.artDirection.pages.length, 81);
  assertEquals(result.artDirection.pages[80].role, "closing");
  for (const [index, page] of result.pages.entries()) {
    assertEquals(page.role, result.artDirection.pages[index].role);
    assertEquals(page.purpose, result.artDirection.pages[index].intent);
    assertEquals(
      page.elements.filter((e) => e.kind === "photo").length,
      result.artDirection.pages[index].photoCount,
    );
  }
  for (const count of [16, 18, 21, 82]) {
    assertThrows(() => expandTemplatePages(source, count));
  }
});

function sixteenPageSample() {
  const original = structuredClone(fixture);
  const indexes = [0, 1, ...Array.from({ length: 14 }, (_, i) => 2 + i % 2), 4];
  const plan = {
    ...original.plan,
    pages: indexes.map((i) => original.plan.pages[i]),
  };
  const output = {
    ...original.output,
    pages: indexes.map((source, index) => ({
      ...original.output.pages[source],
      elements: original.output.pages[source].elements.map((e, j) => ({
        ...e,
        id: `source_${index}_${j}`,
      })),
    })),
  };
  // The model's bounded design still needs three distinct photo compositions.
  output.pages[4].elements[0].width = .36;
  output.pages[4].elements[1].x = .56;
  output.pages[4].elements[1].width = .36;
  return { plan, output };
}

for (const pageCount of [20, 80]) {
  Deno.test(`v2 final${pageCount} uses only16 model interiors and unchanged token/deadline budget`, async () => {
    const sample = sixteenPageSample();
    const brief = { ...fixture.brief, pageCount };
    let calls = 0;
    let firstSignal: AbortSignal | null | undefined;
    const response = await handleAiAlbumDraftRequest(
      new Request("https://example.test/ai-album-draft", {
        method: "POST",
        body: JSON.stringify({ designBrief: brief, candidates: [] }),
      }),
      {
        env: (key) => key === "OPENAI_API_KEY" ? "test-key" : undefined,
        fetch: async (_, init) => {
          const body = JSON.parse(String(init?.body));
          const prompt = JSON.parse(body.messages[1].content);
          assertEquals(prompt.brief.pageCount, 16);
          calls++;
          assertEquals(body.max_completion_tokens, calls === 1 ? 2400 : 10000);
          if (calls === 1) firstSignal = init?.signal;
          else assertEquals(init?.signal, firstSignal);
          return new Response(
            JSON.stringify({
              choices: [{
                finish_reason: "stop",
                message: {
                  content: JSON.stringify(
                    calls === 1 ? sample.plan : sample.output,
                  ),
                },
              }],
            }),
          );
        },
      },
    );
    const result = await response.json();
    assertEquals(response.status, 200, JSON.stringify(result));
    assertEquals(calls, 2);
    assertEquals(result.pageCount, pageCount);
    assertEquals(result.design.pages.length, pageCount + 1);
    assertEquals(result.design.layoutExpansion.sourcePageCount, 16);
    assertEquals(result.design.artDirection.pages[pageCount].role, "closing");
    assertEquals(result.curationNotes.length, 1);
    const slots = result.templateSlots;
    assertEquals(
      new Set(slots.map((s: { slotId: string }) => s.slotId)).size,
      slots.length,
    );
    assertEquals(
      slots.every((s: { pageIndex: number }) => s.pageIndex <= pageCount),
      true,
    );
    assertEquals(result.fallbackUsed, false);
    // Expanded pages still satisfy the exact geometry, type and plan checks.
    validateDirectedTemplate(
      result.design,
      parseTemplateBrief(brief),
      result.design.artDirection,
    );
  });
}

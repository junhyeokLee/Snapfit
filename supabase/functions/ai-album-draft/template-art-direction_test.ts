import { assert, assertEquals, assertThrows } from "jsr:@std/assert";
import fixture from "../../../test/fixtures/ai_template_v2.json" with {
  type: "json",
};
import { parseTemplateBrief } from "./template-design.ts";
import {
  validateArtDirection,
  validateDirectedTemplate,
} from "./template-art-direction.ts";
import { handleAiAlbumDraftRequest } from "./index.ts";

const brief = parseTemplateBrief(fixture.brief);
const fresh = () => structuredClone(fixture);
const plan = () => validateArtDirection(fresh().plan, brief);

for (const aspect of ["portrait", "square", "landscape"] as const) {
  Deno.test(`v2 ${aspect}: preserves direction, editable type and text-only pages`, () => {
    const sample = fresh();
    const design = validateDirectedTemplate({ ...sample.output, aspect }, {
      ...brief,
      aspect,
    }, plan());
    assertEquals(design.artDirection, plan());
    assertEquals(
      design.pages[1].elements.filter((e) => e.kind === "photo"),
      [],
    );
    assertEquals(design.pages[4].background, "#123C32");
    assertEquals(design.pages[4].elements[1].color, "#123C32");
    assertEquals(design.pages[0].elements[0].typography, "display");
  });
}

Deno.test("version negotiation preserves old clients and rejects unsupported versions", () => {
  const { designVersion: _, ...legacy } = fixture.brief;
  assertEquals(parseTemplateBrief(legacy), legacy);
  assertEquals(parseTemplateBrief(fixture.brief).designVersion, 2);
  assertThrows(() => parseTemplateBrief({ ...legacy, designVersion: 3 }));
});

Deno.test("a typography-only cover is valid without inventing an extra photo slot", () => {
  const sample = fresh();
  sample.plan.pages[0].photoCount = 0;
  sample.output.pages[0].elements.splice(1, 1);
  sample.plan.pages[0].intent = "a".repeat(120);
  const result = validateDirectedTemplate(
    sample.output,
    brief,
    validateArtDirection(sample.plan, brief),
  );
  assertEquals(result.pages[0].purpose.length, 120);
  assertEquals(result.pages[0].elements.filter((e) => e.kind === "photo"), []);
});

Deno.test("plan rejects unsupported fonts, synthetic weights, hierarchy and empty books", () => {
  const badFont = fresh().plan;
  badFont.typography.heading.fontFamily = "Unknown Font";
  assertThrows(() => validateArtDirection(badFont, brief), Error, "plan_font");
  const weight = fresh().plan;
  weight.typography.heading.weight = 600;
  assertThrows(() => validateArtDirection(weight, brief), Error, "font_weight");
  const hierarchy = fresh().plan;
  hierarchy.typography.heading.fontSize = 60;
  assertThrows(
    () => validateArtDirection(hierarchy, brief),
    Error,
    "type_hierarchy",
  );
  const empty = fresh().plan;
  empty.pages[2] = { ...empty.pages[2], role: "story", photoCount: 0 };
  assertThrows(
    () => validateArtDirection(empty, brief),
    Error,
    "missing_photos",
  );
});

Deno.test("geometry cannot change the validated palette, type, photo count or scripts", () => {
  const colors = fresh().output;
  colors.pages[0].background = "#EEEEEE";
  assertThrows(
    () => validateDirectedTemplate(colors, brief, plan()),
    Error,
    "palette_drift",
  );
  const types = fresh().output;
  Object.assign(types.pages[0].elements[0], { fontSize: 12 });
  assertThrows(
    () => validateDirectedTemplate(types, brief, plan()),
    Error,
    "unsupported_field",
  );
  const photos = fresh().output;
  photos.pages[2].elements.splice(0, 1);
  assertThrows(
    () => validateDirectedTemplate(photos, brief, plan()),
    Error,
    "photo_plan_drift",
  );
  const script = fresh().output;
  script.pages[0].elements[0].text = "한글";
  assertThrows(
    () => validateDirectedTemplate(script, brief, plan()),
    Error,
    "font_script",
  );
  const ids = fresh().output;
  ids.pages[0].elements[0].id = "ai_paper_0";
  assertThrows(
    () => validateDirectedTemplate(ids, brief, plan()),
    Error,
    "duplicate_id",
  );
  const urls = fresh().output;
  Object.assign(urls.pages[0].elements[1], {
    url: "https://example.test/photo.jpg",
  });
  assertThrows(
    () => validateDirectedTemplate(urls, brief, plan()),
    Error,
    "unsupported_field",
  );
});

Deno.test("visible backdrop contrast accounts for panel coverage and stacking", () => {
  const partial = fresh().output;
  partial.pages[4].elements[0].width = .4;
  assertThrows(
    () => validateDirectedTemplate(partial, brief, plan()),
    Error,
    "low_contrast",
  );
  const overpaint = fresh().output;
  overpaint.pages[4].elements.push({
    ...overpaint.pages[4].elements[0],
    id: "top-panel",
    color: "#123C32",
  });
  assertThrows(
    () => validateDirectedTemplate(overpaint, brief, plan()),
    Error,
    "low_contrast",
  );
  const overlap = fresh().output;
  overlap.pages[2].elements[1].x = .3;
  assertThrows(
    () => validateDirectedTemplate(overlap, brief, plan()),
    Error,
    "content_overlap",
  );
  const overflow = fresh().output;
  overflow.pages[0].elements[0].text = "W".repeat(100);
  assertThrows(
    () => validateDirectedTemplate(overflow, brief, plan()),
    Error,
    "text_overflow",
  );
});

Deno.test("returned direction is server-owned, not replaceable by geometry output", () => {
  const result = validateDirectedTemplate(
    { ...fresh().output, concept: "Changed", artDirection: {} },
    brief,
    plan(),
  );
  assertEquals(result.concept, fixture.plan.concept);
  assertEquals(result.pages[1].purpose, fixture.plan.pages[1].intent);
  assertThrows(() =>
    validateDirectedTemplate({ ...fresh().output, version: 1 }, brief, plan())
  );
});

function request() {
  return new Request("https://example.test/ai-album-draft", {
    method: "POST",
    body: JSON.stringify({ designBrief: brief, candidates: [] }),
  });
}
function response(output: unknown, finish = "stop") {
  return new Response(
    JSON.stringify({
      choices: [{
        finish_reason: finish,
        message: { content: JSON.stringify(output) },
      }],
    }),
  );
}
const env = (key: string) => key === "OPENAI_API_KEY" ? "test-key" : undefined;

Deno.test("v2 plans then composes without photos, catalog layouts or fallback", async () => {
  let calls = 0;
  let signal: AbortSignal | null | undefined;
  const result = await handleAiAlbumDraftRequest(request(), {
    env,
    fetch: async (_, init) => {
      const body = JSON.parse(String(init?.body));
      const prompt = JSON.parse(body.messages[1].content);
      assertEquals(prompt.brief, brief);
      assertEquals(body.messages.length, 2);
      assert(!JSON.stringify(prompt).includes("reference_designs"));
      if (++calls === 1) {
        signal = init?.signal;
        assertEquals(body.max_completion_tokens, 2400);
        return response(fresh().plan);
      }
      assertEquals(init?.signal, signal);
      assertEquals(prompt.artDirection, plan());
      return response(fresh().output);
    },
  });
  assertEquals(result.status, 200);
  const body = await result.json();
  assertEquals(calls, 2);
  assertEquals(body.design.version, 2);
  assertEquals(body.design.artDirection, plan());
  assertEquals(body.templateSlots.length, 4);
  assertEquals(body.recommendedPhotos, []);
  assertEquals(body.fallbackUsed, false);
});

Deno.test("layout repair retains the validated plan and never repeats planning", async () => {
  let calls = 0;
  const result = await handleAiAlbumDraftRequest(request(), {
    env,
    fetch: async (_, init) => {
      if (++calls === 1) return response(fresh().plan);
      if (calls === 2) return response({ version: 2, pages: [] });
      const body = JSON.parse(String(init?.body));
      assertEquals(body.messages.length, 4);
      assertEquals(JSON.parse(body.messages[1].content).artDirection, plan());
      return response(fresh().output);
    },
  });
  assertEquals(calls, 3);
  assertEquals(result.status, 200);
});

Deno.test("one shared repair budget prevents runaway plan plus layout retries", async () => {
  let calls = 0;
  const result = await handleAiAlbumDraftRequest(request(), {
    env,
    fetch: async () => {
      calls++;
      return response(calls === 2 ? fresh().plan : {});
    },
  });
  assertEquals(calls, 3);
  assertEquals(result.status, 500);
  const body = await result.json();
  assertEquals(body.error, "template_quality_failed");
  assertEquals(body.design, undefined);
});

for (const mode of ["http", "incomplete", "credentials"] as const) {
  Deno.test(`v2 ${mode} failure does not return a substitute`, async () => {
    let calls = 0;
    const result = await handleAiAlbumDraftRequest(request(), {
      env: mode === "credentials" ? () => undefined : env,
      fetch: async () => {
        calls++;
        return mode === "http"
          ? new Response("error", { status: 429 })
          : response(fresh().plan, "length");
      },
    });
    assertEquals(calls, mode === "credentials" ? 0 : 1);
    assertEquals(result.status, 500);
    assertEquals((await result.json()).design, undefined);
  });
}

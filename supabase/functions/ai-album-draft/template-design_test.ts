import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  parseTemplateBrief,
  templateCanvasHeight,
  type TemplateBrief,
  validateTemplateDesign,
} from "./template-design.ts";
import { handleAiAlbumDraftRequest } from "./index.ts";

const brief: TemplateBrief = {
  prompt: "푸른 여백의 여행 사진집",
  pageCount: 4,
  aspect: "square",
};
function designFixture() {
  return {
    version: 1,
    aspect: brief.aspect,
    concept: "푸른 여백",
    rationale: "장면의 크기와 여백을 번갈아 배치한 사진집",
    pages: Array.from({ length: 5 }, (_, i) => ({
      background: "#FFFFFF",
      purpose: i === 0 ? "표지" : "여행 장면",
      elements: [
        {
          id: `photo-${i}`,
          kind: "photo",
          x: .06 + i * .03,
          y: .06,
          width: .88 - i * .1,
          height: .6,
          color: "#C9DCDD",
        },
        {
          id: `text-${i}`,
          kind: "text",
          x: .06,
          y: .76,
          width: .88,
          height: .18,
          color: "#172522",
          text: "머무른 장면",
          fontSize: 20,
          weight: 500,
          align: "left",
        },
      ],
    })),
  };
}

Deno.test("design validates every page, preserves free geometry and rejects defects", () => {
  const valid = designFixture();
  assertEquals(
    validateTemplateDesign(valid, brief).pages[3].elements[0].x,
    .15,
  );
  const outside = designFixture();
  outside.pages[0].elements[0].width = 1;
  assertThrows(
    () => validateTemplateDesign(outside, brief),
    Error,
    "out_of_bounds",
  );
  const overlap = designFixture();
  overlap.pages[0].elements[1].y = .5;
  assertThrows(() => validateTemplateDesign(overlap, brief), Error, "overlap");
  const contrast = designFixture();
  contrast.pages[0].elements[1].color = "#EEEEEE";
  assertThrows(
    () => validateTemplateDesign(contrast, brief),
    Error,
    "low_contrast",
  );
  const repeated = designFixture();
  repeated.pages.forEach((p) => {
    p.elements[0].x = .06;
    p.elements[0].width = .88;
  });
  assertThrows(
    () => validateTemplateDesign(repeated, brief),
    Error,
    "repetitive",
  );
  const tooMuchText = designFixture();
  tooMuchText.pages[0].elements[1].text = "가".repeat(100);
  assertThrows(
    () => validateTemplateDesign(tooMuchText, brief),
    Error,
    "text_overflow",
  );
  assertThrows(() => parseTemplateBrief({ ...brief, pageCount: 5 }));
  assertThrows(() => parseTemplateBrief({ ...brief, prompt: "" }));
});

function request() {
  return new Request("https://example.test/ai-album-draft", {
    method: "POST",
    body: JSON.stringify({ designBrief: brief, candidates: [] }),
  });
}
function modelResponse(design: unknown) {
  return new Response(
    JSON.stringify({
      choices: [{
        finish_reason: "stop",
        message: { content: JSON.stringify(design) },
      }],
    }),
  );
}

Deno.test("brief-only generation never reads photos or falls back to metadata", async () => {
  let calls = 0;
  const response = await handleAiAlbumDraftRequest(request(), {
    env: (key) => key === "OPENAI_API_KEY" ? "test-key" : undefined,
    fetch: async (url, init) => {
      calls++;
      assertEquals(String(url), "https://api.openai.com/v1/chat/completions");
      const body = JSON.parse(String(init?.body));
      assertEquals(
        JSON.parse(body.messages[1].content).brief.prompt,
        brief.prompt,
      );
      return modelResponse(designFixture());
    },
  });
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.design.pages.length, 5);
  assertEquals(body.recommendedPhotos, []);
  assertEquals(body.fallbackUsed, false);
  assertEquals(calls, 1);
});

Deno.test("quality failure repairs once, then fails without returning a fixed layout", async () => {
  let calls = 0;
  const response = await handleAiAlbumDraftRequest(request(), {
    env: (key) => key === "OPENAI_API_KEY" ? "test-key" : undefined,
    fetch: async (_, init) => {
      calls++;
      if (calls === 2) {
        assertEquals(JSON.parse(String(init?.body)).messages.length, 4);
      }
      return modelResponse({ pages: [] });
    },
  });
  assertEquals(calls, 2);
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error, "template_quality_failed");
});

Deno.test("corrected output is delivered and missing credentials never use metadata", async () => {
  let calls = 0;
  const response = await handleAiAlbumDraftRequest(request(), {
    env: (key) => key === "OPENAI_API_KEY" ? "test-key" : undefined,
    fetch: async () => modelResponse(++calls === 1 ? {} : designFixture()),
  });
  assertEquals(response.status, 200);
  assertEquals(calls, 2);
  const missing = await handleAiAlbumDraftRequest(request(), {
    env: () => undefined,
  });
  assertEquals(
    (await missing.json()).error,
    "template_provider_not_configured",
  );
});

Deno.test("ten size and cover products use exact canvas height and round trip in generated design", () => {
  for (const id of ["toString", "__proto__", "REDP_200_FABRIC", 123]) {
    assertThrows(() => parseTemplateBrief({ ...brief, aspect: "square", printProduct: { id } }));
  }
  for (const [id, width, height] of [
    ["REDP_200X150_SOFT", 200, 150], ["REDP_200_SOFT", 200, 200],
    ["REDP_250X200_SOFT", 250, 200], ["REDP_250_SOFT", 250, 250],
    ["REDP_300_SOFT", 300, 300],
    ["REDP_200X150_HARD", 200, 150], ["REDP_200_HARD", 200, 200],
    ["REDP_250X200_HARD", 250, 200], ["REDP_250_HARD", 250, 250],
    ["REDP_300_HARD", 300, 300],
  ] as const) {
    const printProduct = { id, trimWidthMm: width, trimHeightMm: height };
    const request = parseTemplateBrief({ ...brief, aspect: width > height ? "landscape" : "square", printProduct });
    assertEquals(templateCanvasHeight(request), 500 * height / width);
    const design = { ...designFixture(), aspect: request.aspect };
    assertEquals(validateTemplateDesign(design, request).printProduct, printProduct);
    assertThrows(() => parseTemplateBrief({ ...request, printProduct: { ...printProduct, trimWidthMm: width + 10 } }));
    assertThrows(() => parseTemplateBrief({ ...request, aspect: "portrait" }));
  }
});

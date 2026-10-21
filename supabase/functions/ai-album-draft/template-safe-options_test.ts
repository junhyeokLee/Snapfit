import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  assertSafeJobBody,
  parseSafeTemplateOptions,
  safeDesignChoices,
  safeTemplateBrief,
} from "./template-safe-options.ts";
export const safeOptionsFixture = {
  version: 1,
  topic: "travel",
  mood: "editorial",
  palette: "neutral",
  density: "balanced",
  pageCount: 20,
  aspect: "square",
};
Deno.test("finite public design preferences reconstruct a useful Korean brief without user identifiers", () => {
  for (const topic of safeDesignChoices.topic) {
    const options = parseSafeTemplateOptions({ ...safeOptionsFixture, topic });
    const brief = safeTemplateBrief(options);
    assertEquals(brief.designVersion, 3);
    assertEquals(brief.pageCount, 20);
    assertEquals(brief.prompt.includes("자연스러운 한국어"), true);
    assertEquals(brief.prompt.includes("빈 편집 슬롯"), true);
    assertEquals(brief.prompt.length < 1000, true);
  }
});
Deno.test("raw input, extra nested data and unknown enum values are rejected rather than redacted", () => {
  for (
    const extra of [
      "prompt",
      "title",
      "name",
      "photo",
      "createdAt",
      "url",
      "userId",
      "metadata",
    ]
  ) {
    assertThrows(
      () =>
        parseSafeTemplateOptions({ ...safeOptionsFixture, [extra]: "private" }),
      Error,
      "private_input_forbidden",
    );
  }
  for (const field of ["topic", "mood", "palette", "density"]) {
    assertThrows(() =>
      parseSafeTemplateOptions({ ...safeOptionsFixture, [field]: "김개인" })
    );
  }
  assertThrows(
    () =>
      parseSafeTemplateOptions({
        ...safeOptionsFixture,
        printProduct: {
          id: "REDP_200_SOFT",
          trimWidthMm: 200,
          trimHeightMm: 200,
          name: "개인",
        },
      }),
    Error,
    "private_input_forbidden",
  );
});
Deno.test("public print product dimensions and page bounds remain authoritative", () => {
  assertThrows(() =>
    parseSafeTemplateOptions({ ...safeOptionsFixture, pageCount: 18 })
  );
  assertThrows(() =>
    parseSafeTemplateOptions({ ...safeOptionsFixture, pageCount: 21 })
  );
  assertThrows(() =>
    parseSafeTemplateOptions({
      ...safeOptionsFixture,
      printProduct: {
        id: "REDP_200_SOFT",
        trimWidthMm: 201,
        trimHeightMm: 200,
      },
    })
  );
  assertEquals(
    parseSafeTemplateOptions({
      ...safeOptionsFixture,
      pageCount: 80,
      printProduct: {
        id: "REDP_200_SOFT",
        trimWidthMm: 200,
        trimHeightMm: 200,
      },
    }).pageCount,
    80,
  );
});
Deno.test("status/cancel/create have separate closed payload contracts", () => {
  const id = "11111111-1111-4111-8111-111111111111";
  for (const action of ["status", "cancel"]) {
    assertSafeJobBody({ action, generationRequestId: id });
    assertThrows(
      () =>
        assertSafeJobBody({
          action,
          generationRequestId: id,
          safeDesign: safeOptionsFixture,
        }),
      Error,
      "private_input_forbidden",
    );
  }
  assertSafeJobBody({ action: "latest" });
  assertThrows(() =>
    assertSafeJobBody({ action: "status", generationRequestId: "name" })
  );
  assertThrows(
    () =>
      assertSafeJobBody({
        action: "create",
        generationRequestId: id,
        designBrief: { prompt: "private" },
      }),
    Error,
    "private_input_forbidden",
  );
});

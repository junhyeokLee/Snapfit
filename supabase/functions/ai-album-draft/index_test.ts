import { assertEquals, assertExists } from "jsr:@std/assert";
import { buildDraftResponse, type PhotoCandidatePayload } from "./index.ts";
import { handleAiAlbumDraftRequest } from "./test-support.ts";

const candidates: PhotoCandidatePayload[] = [1, 2, 3].map((i) => ({
  assetId: `photo-${i}`,
  createdAt: "2026-08-20T09:00:00.000",
  width: 4000,
  height: 3000,
  orientation: "landscape",
  albumName: "개인 앨범명",
  isScreenshot: false,
}));
const request = (body: unknown) =>
  new Request("https://example.test/ai-album-draft", {
    method: "POST",
    body: JSON.stringify(body),
  });

Deno.test("metadata curation remains reviewable and never auto-selects customer photos", () => {
  const draft = buildDraftResponse({
    theme: "travel",
    range: "limitedLibrary",
    candidates,
  });
  assertExists(draft.draftId);
  assertEquals(draft.title, "여행의 장면들");
  assertEquals(draft.requiresUserReview, true);
  assertEquals(draft.alreadyCreatedAlbum, false);
  assertEquals(draft.recommendedPhotos, []);
  assertEquals(draft.excludedPhotos, []);
  assertEquals(draft.templateSlots[0].slotId, "cover-main");
});
Deno.test("CORS and method handling never need a provider", async () => {
  assertEquals(
    (await handleAiAlbumDraftRequest(
      new Request("https://example.test", { method: "OPTIONS" }),
    )).status,
    200,
  );
  assertEquals(
    (await handleAiAlbumDraftRequest(new Request("https://example.test")))
      .status,
    405,
  );
});
Deno.test("insufficient candidates are rejected", async () => {
  const response = await handleAiAlbumDraftRequest(
    request({ theme: "daily", candidates: [] }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "insufficient_candidates");
});
for (const provider of [undefined, "metadata", "advanced", "hybrid"]) {
  Deno.test(`customer photo curation is local metadata only even with legacy ${provider} provider configuration`, async () => {
    let externalCalls = 0, suppliedProviderCalls = 0;
    const response = await handleAiAlbumDraftRequest(
      request({ theme: "travel", range: "manualSelection", candidates }),
      {
        env: (key) =>
          key === "AI_ALBUM_DRAFT_PROVIDER" ? provider : "must-not-be-read",
        fetch: () => {
          externalCalls++;
          throw new Error("customer data must not leave server");
        },
        providers: {
          advanced: () => {
            suppliedProviderCalls++;
            throw new Error("not allowed");
          },
          hybrid: () => {
            suppliedProviderCalls++;
            throw new Error("not allowed");
          },
        },
      },
    );
    assertEquals(response.status, 200);
    assertEquals((await response.json()).provider, "metadata");
    assertEquals(externalCalls, 0);
    assertEquals(suppliedProviderCalls, 0);
  });
}
for (const rawDataFlag of ["false", "true"]) {
  Deno.test(`free-form HTTP briefs are blocked before model or reservation even with obsolete flag ${rawDataFlag}`, async () => {
    let calls = 0;
    const response = await handleAiAlbumDraftRequest(
      request({
        designBrief: {
          prompt: "김개인 010-0000-0000 주소",
          pageCount: 20,
          aspect: "square",
          designVersion: 3,
        },
      }),
      {
        env: () => rawDataFlag,
        fetch: () => {
          calls++;
          throw new Error("never transmit raw input");
        },
      },
    );
    assertEquals(response.status, 400);
    assertEquals(
      (await response.json()).error,
      "ai_generation_private_input_forbidden",
    );
    assertEquals(calls, 0);
  });
}
Deno.test("old preview references never trigger Storage or external downloads", async () => {
  let calls = 0;
  const response = await handleAiAlbumDraftRequest(
    request({
      theme: "travel",
      candidates: candidates.map((c) => ({
        ...c,
        previewStorageUri:
          `supabase://ai-album-previews/user/public/${c.assetId}.jpg`,
      })),
    }),
    {
      env: (key) => key === "AI_ALBUM_DRAFT_PROVIDER" ? "advanced" : "unused",
      fetch: () => {
        calls++;
        throw new Error("no preview download");
      },
    },
  );
  assertEquals(response.status, 200);
  assertEquals(calls, 0);
});

Deno.test("invalid safe design dimensions are client errors before queue admission", async () => {
  for (const safeDesign of [null, {version: 1, topic: "travel", mood: "editorial", palette: "neutral", density: "balanced", pageCount: 21, aspect: "square"}]) {
    let rpcCalls = 0;
    const result = await handleAiAlbumDraftRequest(request({action: "create", generationRequestId: "11111111-1111-4111-8111-111111111111", expectedPointCost: 0, safeDesign}), {
      freeJobDatabase: {rpc: () => {rpcCalls++; throw new Error("No queue admission");}},
    });
    assertEquals(result.status, 400);
    assertEquals((await result.json()).error, "ai_generation_invalid_request");
    assertEquals(rpcCalls, 0);
  }
});

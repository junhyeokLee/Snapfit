import { assertEquals, assertExists } from "jsr:@std/assert";
import {
  buildDraftResponse,
  handleAiAlbumDraftRequest,
  type PhotoCandidatePayload,
} from "./index.ts";

const candidates: PhotoCandidatePayload[] = [
  {
    assetId: "photo-1",
    createdAt: "2026-08-20T09:00:00.000",
    width: 4000,
    height: 3000,
    orientation: "landscape",
    albumName: "제주",
    isScreenshot: false,
  },
  {
    assetId: "photo-2",
    createdAt: "2026-08-20T13:00:00.000",
    width: 3000,
    height: 4000,
    orientation: "portrait",
    albumName: "제주",
    isScreenshot: false,
  },
  {
    assetId: "photo-3",
    createdAt: "2026-08-21T10:00:00.000",
    width: 4000,
    height: 4000,
    orientation: "square",
    albumName: "제주",
    isScreenshot: true,
  },
];

Deno.test("buildDraftResponse returns reviewable album-first JSON contract", () => {
  const draft = buildDraftResponse({
    theme: "travel",
    range: "limitedLibrary",
    candidates,
  });

  assertExists(draft.draftId);
  assertEquals(draft.title, "여행의 장면들");
  assertEquals(draft.pageCount, 8);
  assertEquals(draft.requiresUserReview, true);
  assertEquals(draft.alreadyCreatedAlbum, false);
  assertEquals(draft.recommendedPhotos.map((photo) => photo.assetId), [
    "photo-1",
    "photo-2",
  ]);
  assertEquals(draft.excludedPhotos.map((photo) => photo.assetId), ["photo-3"]);
  assertEquals(draft.storySections[0].photoAssetIds, ["photo-1", "photo-2"]);
  assertEquals(draft.summary.includes("앨범"), true);
});

Deno.test("handleAiAlbumDraftRequest rejects malformed candidate payload", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "daily",
        range: "recent30Days",
        candidates: [],
      }),
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error, "insufficient_candidates");
});

Deno.test("handleAiAlbumDraftRequest handles CORS preflight", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", { method: "OPTIONS" }),
  );

  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

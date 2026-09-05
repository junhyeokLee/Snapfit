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

Deno.test("handleAiAlbumDraftRequest uses metadata provider by default", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "travel",
        range: "limitedLibrary",
        candidates,
      }),
    }),
    {
      env: () => undefined,
    },
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.provider, "metadata");
  assertEquals(body.fallbackUsed, false);
  assertEquals(body.requiresUserReview, true);
  assertEquals(body.alreadyCreatedAlbum, false);
});

Deno.test("handleAiAlbumDraftRequest falls back to metadata provider when advanced provider times out", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "travel",
        range: "limitedLibrary",
        candidates,
      }),
    }),
    {
      env: (key) => {
        if (key === "AI_ALBUM_DRAFT_PROVIDER") return "advanced";
        if (key === "AI_ALBUM_DRAFT_TIMEOUT_MS") return "1";
        return undefined;
      },
      providers: {
        advanced: () =>
          new Promise((resolve) => {
            setTimeout(() =>
              resolve(buildDraftResponse({
                theme: "travel",
                range: "limitedLibrary",
                candidates,
              })), 20);
          }),
      },
    },
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.provider, "metadata");
  assertEquals(body.fallbackUsed, true);
  assertEquals(body.fallbackReason, "advanced_provider_timeout");
  assertEquals(body.requiresUserReview, true);
  assertEquals(body.alreadyCreatedAlbum, false);
});

Deno.test("handleAiAlbumDraftRequest returns advanced provider draft when it succeeds", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "family",
        range: "manualSelection",
        candidates,
      }),
    }),
    {
      env: (key) => key === "AI_ALBUM_DRAFT_PROVIDER" ? "advanced" : undefined,
      providers: {
        advanced: (request) =>
          Promise.resolve({
            ...buildDraftResponse(request),
            draftId: "advanced-draft-1",
            title: "가족의 따뜻한 오후",
            curationNotes: ["작은 미리보기로 분위기를 살펴봤어요."],
          }),
      },
    },
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.provider, "advanced");
  assertEquals(body.fallbackUsed, false);
  assertEquals(body.draftId, "advanced-draft-1");
  assertEquals(body.title, "가족의 따뜻한 오후");
  assertEquals(body.requiresUserReview, true);
  assertEquals(body.alreadyCreatedAlbum, false);
});

Deno.test("handleAiAlbumDraftRequest passes preview storage references to advanced provider", async () => {
  let receivedPreview: string | undefined;
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "family",
        range: "limitedLibrary",
        candidates: [
          {
            ...candidates[0],
            previewStorageUri:
              "supabase://ai-album-previews/user/draft/photo-1.jpg",
          },
          candidates[1],
          candidates[2],
        ],
      }),
    }),
    {
      env: (key) => key === "AI_ALBUM_DRAFT_PROVIDER" ? "advanced" : undefined,
      providers: {
        advanced: (request) => {
          receivedPreview = request.candidates[0].previewStorageUri;
          return buildDraftResponse(request);
        },
      },
    },
  );

  assertEquals(response.status, 200);
  assertEquals(
    receivedPreview,
    "supabase://ai-album-previews/user/draft/photo-1.jpg",
  );
});

Deno.test("default advanced provider downloads previews and maps model JSON", async () => {
  const calls: string[] = [];
  const methods: string[] = [];
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "travel",
        range: "limitedLibrary",
        candidates: [
          {
            ...candidates[0],
            previewStorageUri:
              "supabase://ai-album-previews/user/draft/photo-1.jpg",
          },
          {
            ...candidates[1],
            previewStorageUri:
              "supabase://ai-album-previews/user/draft/photo-2.jpg",
          },
          candidates[2],
        ],
      }),
    }),
    {
      env: (key) => {
        const values: Record<string, string> = {
          AI_ALBUM_DRAFT_PROVIDER: "advanced",
          OPENAI_API_KEY: "test-openai-key",
          OPENAI_MODEL: "gpt-test-vision",
          SUPABASE_URL: "https://project.supabase.co",
          SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
        };
        return values[key];
      },
      fetch: async (input, init) => {
        const url = input.toString();
        calls.push(url);
        methods.push(`${init?.method ?? "GET"} ${url}`);
        if (
          url.includes("/storage/v1/object/authenticated/ai-album-previews/") &&
          init?.method === "DELETE"
        ) {
          return new Response(null, { status: 200 });
        }
        if (
          url.includes("/storage/v1/object/authenticated/ai-album-previews/")
        ) {
          assertEquals(
            init?.headers instanceof Headers
              ? init.headers.get("Authorization")
              : undefined,
            "Bearer test-service-role",
          );
          return new Response(new Uint8Array([1, 2, 3]), {
            status: 200,
            headers: { "content-type": "image/jpeg" },
          });
        }
        if (url === "https://api.openai.com/v1/chat/completions") {
          const body = JSON.parse(init?.body?.toString() ?? "{}");
          assertEquals(body.model, "gpt-test-vision");
          assertEquals(body.response_format.type, "json_object");
          return Response.json({
            choices: [
              {
                message: {
                  content: JSON.stringify({
                    title: "제주의 푸른 장면",
                    pageCount: 8,
                    templateTone: "fresh-travel",
                    summary: "미리보기로 여행의 흐름을 정리했어요.",
                    recommendedPhotos: [
                      {
                        assetId: "photo-2",
                        score: 0.96,
                        reasons: [
                          {
                            type: "coverCandidate",
                            message: "대표 장면이에요",
                          },
                        ],
                      },
                      {
                        assetId: "photo-1",
                        score: 0.91,
                        reasons: [
                          { type: "dateFlow", message: "여행 흐름을 이어줘요" },
                        ],
                      },
                    ],
                    excludedPhotos: [
                      {
                        assetId: "photo-3",
                        reasons: [
                          {
                            type: "screenshotExcluded",
                            message: "스크린샷은 제외했어요",
                          },
                        ],
                      },
                    ],
                    storySections: [
                      {
                        title: "제주 첫날",
                        description: "바다에서 시작하는 흐름",
                        photoAssetIds: ["photo-2", "photo-1"],
                      },
                    ],
                    curationNotes: ["작은 미리보기로 분위기를 살펴봤어요."],
                  }),
                },
              },
            ],
          });
        }
        return new Response("unexpected", { status: 500 });
      },
    },
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.provider, "advanced");
  assertEquals(body.fallbackUsed, false);
  assertEquals(body.title, "제주의 푸른 장면");
  assertEquals(
    body.recommendedPhotos.map((photo: { assetId: string }) => photo.assetId),
    ["photo-2", "photo-1"],
  );
  assertEquals(calls.some((url) => url.includes("photo-1.jpg")), true);
  assertEquals(calls.some((url) => url.includes("photo-2.jpg")), true);
  assertEquals(
    methods.some((call) =>
      call.startsWith("DELETE ") && call.includes("photo-1.jpg")
    ),
    true,
  );
  assertEquals(
    methods.some((call) =>
      call.startsWith("DELETE ") && call.includes("photo-2.jpg")
    ),
    true,
  );
});

Deno.test("default advanced provider falls back when preview references are missing", async () => {
  const response = await handleAiAlbumDraftRequest(
    new Request("https://example.test/ai-album-draft", {
      method: "POST",
      body: JSON.stringify({
        theme: "travel",
        range: "limitedLibrary",
        candidates,
      }),
    }),
    {
      env: (key) => {
        const values: Record<string, string> = {
          AI_ALBUM_DRAFT_PROVIDER: "advanced",
          OPENAI_API_KEY: "test-openai-key",
          SUPABASE_URL: "https://project.supabase.co",
          SUPABASE_SERVICE_ROLE_KEY: "test-service-role",
        };
        return values[key];
      },
      fetch: () =>
        Promise.resolve(new Response("should not fetch", { status: 500 })),
    },
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.provider, "metadata");
  assertEquals(body.fallbackUsed, true);
  assertEquals(body.fallbackReason, "advanced_provider_failed");
});

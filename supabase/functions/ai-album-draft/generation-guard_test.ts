import { assertEquals, assertRejects } from "jsr:@std/assert";
import { buildDraftResponse, handleAiAlbumDraftRequest } from "./index.ts";
import {
  type GenerationGuard,
  generationGuard,
  generationHash,
  readGenerationBody,
} from "./generation-guard.ts";
const actor = "11111111-1111-4111-8111-111111111111",
  id = "22222222-2222-4222-8222-222222222222";
const body = {
  theme: "daily",
  range: "manualSelection",
  generationRequestId: id,
  candidates: [1, 2, 3].map((i) => ({
    assetId: String(i),
    createdAt: "2026-10-01",
    width: 2000,
    height: 2000,
    orientation: "square",
  })),
};
const request = (value: unknown = body) =>
  new Request("https://example.test/ai-album-draft", {
    method: "POST",
    body: JSON.stringify(value),
  });
const rejection = (message: string) => Promise.reject(new Error(message));
function guard(
  events: string[],
  overrides: Partial<GenerationGuard> = {},
): GenerationGuard {
  return {
    authenticate: async () => {
      events.push("auth");
      return actor;
    },
    reserve: async (who, key, hash, version) => {
      events.push("reserve");
      assertEquals(who, actor);
      assertEquals(key, id);
      assertEquals(hash.length, 64);
      assertEquals(version, 1);
      return { id, draftId: "server-draft" };
    },
    complete: async (_actor, _id, result) => {
      events.push("complete");
      assertEquals(result.draftId, "server-draft");
    },
    fail: async () => {
      events.push("fail");
    },
    ...overrides,
  };
}
Deno.test("real guard rejects absent/invalid bearer credentials before provider calls", async () => {
  const response = await handleAiAlbumDraftRequest(request(), {
    env: () => undefined,
  });
  assertEquals(response.status, 401);
  assertEquals((await response.json()).error, "ai_generation_auth_required");
  await assertRejects(
    () =>
      generationGuard().authenticate(
        new Request("https://example.test", {
          headers: { Authorization: "Basic forged" },
        }),
      ),
    Error,
    "auth_required",
  );
});
Deno.test("reservation failure never invokes the paid provider or charges a draft", async () => {
  const events: string[] = [];
  const response = await handleAiAlbumDraftRequest(request(), {
    guard: guard(events, {
      reserve: () => rejection("ai_generation_rate_limited"),
    }),
    env: () => undefined,
    fetch: () => {
      throw new Error("Must not call model");
    },
  });
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("Retry-After"), "60");
  assertEquals(events, ["auth"]);
});

Deno.test("another user preview cannot be read or deleted with service credentials", async () => {
  const events: string[] = [];
  const candidates = [1, 2, 3].map((i) => ({
    assetId: String(i),
    createdAt: "2026-10-01",
    width: 2000,
    height: 2000,
    orientation: "square",
    previewStorageUri: `supabase://ai-album-previews/other/request/${i}.jpg`,
  }));
  const response = await handleAiAlbumDraftRequest(
    request({ theme: "daily", range: "manualSelection", candidates }),
    {
      guard: guard(events),
      fetch: () => {
        throw new Error("No storage or provider call");
      },
    },
  );
  assertEquals(response.status, 403);
  assertEquals(events, ["auth"]);
});
Deno.test("invalid local curation marks the reserved generation failed without making a result billable", async () => {
  const events: string[] = [];
  const response = await handleAiAlbumDraftRequest(
    request({ ...body, candidates: [] }),
    {
      guard: guard(events),
      env: () => undefined,
    },
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error, "insufficient_candidates");
  assertEquals(events, ["auth", "reserve", "fail"]);
});
Deno.test("replay returns server cached document without requesting or completing it again", async () => {
  const events: string[] = [];
  const cached = buildDraftResponse({
    theme: "daily",
    range: "manualSelection",
    candidates: [1, 2, 3].map((i) => ({
      assetId: String(i),
      createdAt: "2026-10-01",
      width: 2000,
      height: 2000,
      orientation: "square" as const,
    })),
  });
  const response = await handleAiAlbumDraftRequest(request(), {
    guard: guard(events, {
      reserve: async () => ({ id, draftId: cached.draftId, cached }),
    }),
    fetch: () => {
      throw new Error("No API call");
    },
  });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), cached);
  assertEquals(events, ["auth"]);
});
Deno.test("malformed/oversized bodies and malformed request IDs fail before admission", async () => {
  for (
    const value of [
      { ...body, generationRequestId: "forged" },
      Array(40000).fill("x"),
    ]
  ) {
    const events: string[] = [];
    const response = await handleAiAlbumDraftRequest(request(value), {
      guard: guard(events),
    });
    assertEquals(response.status, Array.isArray(value) ? 413 : 400);
    assertEquals(events, ["auth"]);
  }
  await assertRejects(
    () =>
      readGenerationBody(
        new Request("https://example.test", {
          method: "POST",
          body: "{not json",
        }),
      ),
    Error,
    "invalid_request",
  );
  assertEquals((await generationHash(body)).length, 64);
});
Deno.test("database completion must succeed before a successful response is exposed", async () => {
  const events: string[] = [];
  const response = await handleAiAlbumDraftRequest(
    request({
      theme: "daily",
      range: "manualSelection",
      generationRequestId: id,
      candidates: [1, 2, 3].map((i) => ({
        assetId: String(i),
        createdAt: "2026-10-01",
        width: 2000,
        height: 2000,
        orientation: "square",
      })),
    }),
    {
      guard: guard(events, {
        reserve: async () => {
          events.push("reserve");
          return { id, draftId: "server-draft" };
        },
        complete: () => rejection("ai_generation_guard_unavailable"),
      }),
      env: () => undefined,
    },
  );
  assertEquals(response.status, 503);
  assertEquals(events, ["auth", "reserve", "fail"]);
});

import { createSyntheticProbe, probeTokenHash } from "./server-probe.ts";

function assert(value: unknown, label: string): asserts value {
  if (!value) throw new Error(label);
}
const token = "synthetic-only-random-token-at-least-32-characters";
const now = 100_000;
const request = (query = "case=travel-square", options: RequestInit = {}) =>
  new Request(`https://example.test/evaluate?${query}`, {
    method: "POST",
    headers: { Authorization: "Bearer test-jwt", "x-evaluation-token": token },
    ...options,
  });

Deno.test("probe requires JWT header and separate expiring credential", async () => {
  let clock = now;
  const handler = createSyntheticProbe({
    tokenHash: await probeTokenHash(token),
    expiresAt: now + 1000,
  }, {
    now: () => clock,
    key: () => {
      throw new Error("must not read key");
    },
  });
  assert(
    (await handler(request("case=travel-square", { headers: {} }))).status ===
      401,
    "missing auth",
  );
  assert(
    (await handler(request("case=travel-square", { method: "GET" }))).status ===
      405,
    "method",
  );
  clock += 1001;
  assert((await handler(request())).status === 410, "expired");
});

Deno.test("probe never accepts customer prompts, photos, arbitrary cases or model overrides", async () => {
  const handler = createSyntheticProbe({
    tokenHash: await probeTokenHash(token),
    expiresAt: now + 1000,
  }, {
    now: () => now,
    key: () => {
      throw new Error("must not read key");
    },
  });
  for (
    const req of [
      request("case=custom"),
      request("case=travel-square&model=paid"),
      request("case=travel-square&case=travel-square"),
      request("case=travel-square", {
        body: JSON.stringify({ prompt: "private" }),
      }),
    ]
  ) {
    assert((await handler(req)).status === 400, "synthetic allowlist");
  }
});

Deno.test("probe evaluates the actual full-book engine without paid fallback or billing", async () => {
  let calls = 0;
  const handler = createSyntheticProbe({
    tokenHash: await probeTokenHash(token),
    expiresAt: now + 1000,
  }, {
    now: () => now,
    key: () => "not-a-real-key",
    evaluate: async (entry, options) => {
      calls++;
      assert(
        entry.id === "travel-square" && entry.brief.pageCount === 20,
        "full book",
      );
      assert(entry.brief.designVersion === 3, "original engine");
      assert(
        options.provider === "gemini" && options.freeOnly,
        "free-only provider",
      );
      return { ...entry, status: "accepted", durationMs: 1, attempts: [] };
    },
  });
  const result = await handler(request("case=travel-square", {
    body: new ReadableStream({
      start(controller) {
        controller.close();
      },
    }),
  }));
  assert(
    result.status === 200 && result.headers.get("Cache-Control") === "no-store",
    "response",
  );
  assert((await handler(request())).status === 409, "bounded duplicate");
  assert(calls === 1, "one model attempt");
});

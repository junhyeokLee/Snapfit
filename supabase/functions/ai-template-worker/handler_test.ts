import { assertEquals } from "jsr:@std/assert";
import {
  createFreeTemplateWorker,
  freeWorkerSignedPayload,
} from "./handler.ts";
const secret = "a".repeat(64),
  nonce = "11111111-1111-4111-8111-111111111111",
  now = Date.parse("2026-10-20T14:00:00Z"),
  signedAt = now / 1000;
async function signed(body = "{}", purpose = "snapfit-ai-template-worker:v1") {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const payload = freeWorkerSignedPayload(signedAt, nonce).replace(
    "snapfit-ai-template-worker:v1",
    purpose,
  );
  const bytes = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)),
  );
  const signature = [...bytes].map((n) => n.toString(16).padStart(2, "0")).join(
    "",
  );
  return new Request("https://example.test/ai-template-worker", {
    method: "POST",
    body,
    headers: {
      "X-Snapfit-AI-Timestamp": String(signedAt),
      "X-Snapfit-AI-Nonce": nonce,
      "X-Snapfit-AI-Signature": signature,
    },
  });
}
Deno.test("public JWT and missing/foreign capabilities cannot touch database or model", async () => {
  let reads = 0;
  const handler = createFreeTemplateWorker({
    secret: () => secret,
    now: () => now,
    database: () => {
      reads++;
      throw new Error("forbidden");
    },
  });
  assertEquals(
    (await handler(
      new Request("https://example.test", {
        method: "POST",
        body: "{}",
        headers: { Authorization: "Bearer public-key" },
      }),
    )).status,
    401,
  );
  assertEquals(
    (await handler(await signed("{}", "snapfit-print-order-scheduler:v1")))
      .status,
    401,
  );
  assertEquals(reads, 0);
});
Deno.test("signed nonce is consumed once before claim; replay and payload overrides are blocked", async () => {
  const events: string[] = [];
  let consumed = false;
  const handler = createFreeTemplateWorker({
    secret: () => secret,
    now: () => now,
    database: () => ({
      rpc: (name) => {
        events.push(name);
        const data = name === "consume_free_ai_template_worker_nonce"
          ? !consumed
          : null;
        if (name === "consume_free_ai_template_worker_nonce") consumed = true;
        return Promise.resolve({ data, error: null });
      },
    }),
  });
  assertEquals((await handler(await signed('{"jobId":"other"}'))).status, 400);
  assertEquals(events, []);
  assertEquals((await handler(await signed())).status, 200);
  assertEquals(events, [
    "consume_free_ai_template_worker_nonce",
    "claim_free_ai_template_job",
  ]);
  assertEquals((await handler(await signed())).status, 401);
  assertEquals(events.length, 3);
});

import {
  advanceOneFreeTemplateJob,
  type FreeJobDatabase,
  freeJobRpc,
  type FreeWorkerOptions,
} from "../ai-album-draft/free-template-jobs.ts";

const uuid =
  /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
const reply = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
export function freeWorkerSignedPayload(signedAt: number, nonce: string) {
  return `snapfit-ai-template-worker:v1\n${signedAt}\n${nonce}\n{}`;
}
type WorkerDependencies = {
  secret(): string;
  database(): FreeJobDatabase;
  options?: FreeWorkerOptions;
  now?: () => number;
};

async function signedRequest(request: Request, secret: string, now: number) {
  const signature = request.headers.get("X-Snapfit-AI-Signature") ?? "";
  const timestamp = request.headers.get("X-Snapfit-AI-Timestamp") ?? "";
  const nonce = request.headers.get("X-Snapfit-AI-Nonce") ?? "";
  if (
    !/^[a-f0-9]{64}$/.test(secret) || !/^[a-f0-9]{64}$/.test(signature) ||
    !/^\d{10}$/.test(timestamp) || !uuid.test(nonce)
  ) return null;
  const signedAt = Number(timestamp);
  if (Math.abs(Math.floor(now / 1000) - signedAt) > 120) return null;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(freeWorkerSignedPayload(signedAt, nonce)),
    ),
  );
  const actual = new Uint8Array(
    signature.match(/../g)!.map((n) => parseInt(n, 16)),
  );
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected[i] ^ actual[i];
  }
  return difference === 0 ? { nonce, signedAt } : null;
}

export function createFreeTemplateWorker(dependencies: WorkerDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return reply({ error: "method_not_allowed" }, 405);
    }
    const auth = await signedRequest(
      request,
      dependencies.secret(),
      (dependencies.now ?? Date.now)(),
    );
    if (!auth) return reply({ error: "unauthorized" }, 401);
    if (!request.body) return reply({ error: "invalid_request" }, 400);
    const reader = request.body.getReader();
    let bytes = new Uint8Array();
    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        if (bytes.length + value.length > 2) {
          await reader.cancel();
          return reply({ error: "invalid_request" }, 400);
        }
        const next = new Uint8Array(bytes.length + value.length);
        next.set(bytes);
        next.set(value, bytes.length);
        bytes = next;
      }
    } finally {
      reader.releaseLock();
    }
    if (new TextDecoder().decode(bytes) !== "{}") {
      return reply({ error: "invalid_request" }, 400);
    }
    try {
      const database = dependencies.database();
      const consumed = await freeJobRpc(
        database,
        "consume_free_ai_template_worker_nonce",
        { p_nonce: auth.nonce, p_signed_at: auth.signedAt },
      );
      if (consumed !== true) return reply({ error: "unauthorized" }, 401);
      return reply(
        await advanceOneFreeTemplateJob(database, dependencies.options),
      );
    } catch {
      // No prompt, provider response, credentials or customer identity in logs.
      return reply({ error: "worker_unavailable" }, 503);
    }
  };
}

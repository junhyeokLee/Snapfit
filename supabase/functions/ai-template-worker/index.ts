import { adminClient } from "../_shared/supabase.ts";
import { createFreeTemplateWorker } from "./handler.ts";

// Dedicated Cron capability. Gateway JWTs alone cannot authorize this endpoint.
Deno.serve((request) => {
  const deadline = AbortSignal.timeout(125000);
  const boundedFetch: typeof fetch = (input, init) =>
    fetch(input, {
      ...init,
      signal: AbortSignal.any([
        deadline,
        ...(init?.signal ? [init.signal] : []),
      ]),
    });
  return createFreeTemplateWorker({
    secret: () => Deno.env.get("AI_TEMPLATE_WORKER_SECRET") ?? "",
    database: () => adminClient({ fetch: boundedFetch }),
    options: { fetch: boundedFetch },
  })(request);
});

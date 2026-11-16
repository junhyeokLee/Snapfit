import { adminClient } from '../_shared/supabase.ts';
import { createPushDispatchHandler } from './handler.ts';
import { createPrintSchedulerRequestFetch } from '../_shared/print-order-scheduler.ts';

Deno.serve(request => createPushDispatchHandler({
  env: name => Deno.env.get(name),
  adminClient: () => adminClient({
    fetch: createPrintSchedulerRequestFetch(fetch, 55_000, request.signal),
  }),
})(request));

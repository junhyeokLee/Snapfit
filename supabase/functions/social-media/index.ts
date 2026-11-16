import { adminClient } from '../_shared/supabase.ts'
import { createSocialMediaHandler } from '../_shared/social-media.ts'
import { createPrintSchedulerRequestFetch } from '../_shared/print-order-scheduler.ts'

// Capabilities are verified by service-only SQL. No service credentials or
// storage paths are returned to callers, and Storage reads have an outer limit.
Deno.serve(request => createSocialMediaHandler({
  createAdminDatabase: () => adminClient({
    fetch: createPrintSchedulerRequestFetch(fetch, 40_000, request.signal),
  }),
  storage: database => (database as ReturnType<typeof adminClient>).storage.from('social-snapshots'),
})(request))

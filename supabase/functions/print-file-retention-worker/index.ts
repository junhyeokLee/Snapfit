import { adminClient } from '../_shared/supabase.ts'
import { createPrintFileRetentionWorkerHandler } from '../_shared/print-file-retention.ts'
import { createPrintSchedulerRequestFetch } from '../_shared/print-order-scheduler.ts'
// Cron and SQL are both disabled by default. A separate runtime gate remains
// closed unless explicitly enabled after retention policy acceptance.
Deno.serve(request => {
  const boundedFetch = createPrintSchedulerRequestFetch(fetch, 40000, request.signal)
  return createPrintFileRetentionWorkerHandler({
    secret: () => Deno.env.get('PRINT_ORDER_SCHEDULER_SECRET') ?? '',
    enabled: () => Deno.env.get('PRINT_FILE_RETENTION_ENABLED') === 'true',
    createAdminDatabase: () => adminClient({ fetch: boundedFetch }),
    removeFiles: async (database, paths) => {
      const result = await (database as ReturnType<typeof adminClient>).storage.from('print-packages').remove(paths)
      return !result.error
    },
  })(request)
})

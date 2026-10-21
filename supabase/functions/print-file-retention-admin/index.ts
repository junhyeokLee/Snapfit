import { adminClient, getUser } from '../_shared/supabase.ts'
import { createPrintFileRetentionAdminHandler } from '../_shared/print-file-retention.ts'
Deno.serve(createPrintFileRetentionAdminHandler({ getUser, createAdminDatabase: adminClient }))

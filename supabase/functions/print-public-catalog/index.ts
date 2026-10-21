import { adminClient } from '../_shared/supabase.ts'
import { createPrintPublicCatalogHandler } from '../_shared/print-public-catalog.ts'
// Public retail information only. The gateway accepts the public anon client key.
Deno.serve(createPrintPublicCatalogHandler({ createAdminDatabase: adminClient }))

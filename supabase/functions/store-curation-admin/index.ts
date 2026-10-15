import { adminClient, getUser } from '../_shared/supabase.ts'
import { createStoreCurationHandler } from '../_shared/store-curation.ts'

Deno.serve(createStoreCurationHandler({ getUser, createAdminDatabase: adminClient }))

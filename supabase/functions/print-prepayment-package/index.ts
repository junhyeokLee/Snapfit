import { adminClient, getUser } from '../_shared/supabase.ts'
import { createPrepaymentPackageHandler } from '../_shared/print-prepayment-package.ts'

// Current owner Auth is required in addition to the signed JWT gateway. The
// client receives expiring source/upload URLs, never storage/vendor/PG secrets.
Deno.serve(createPrepaymentPackageHandler({
  getUser, createAdminDatabase: adminClient,
  configuration: () => ({ supabaseUrl: Deno.env.get('SUPABASE_URL') ?? '' }),
}))

import { getUser, adminClient } from '../_shared/supabase.ts'
import { createPrintPricingAdminHandler } from '../_shared/print-pricing-admin.ts'
// Planned price administration only. No vendor/payment request or sales activation.
Deno.serve(createPrintPricingAdminHandler({ getUser, createAdminDatabase: adminClient }))

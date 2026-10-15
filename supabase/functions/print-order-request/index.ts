import { getUser, adminClient } from '../_shared/supabase.ts'
import { createPrintOrderRequestHandler } from '../_shared/print-order-request.ts'
Deno.serve(createPrintOrderRequestHandler({getUser,createAdminDatabase:adminClient}))

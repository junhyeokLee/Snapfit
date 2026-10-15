import {getUser,adminClient} from '../_shared/supabase.ts'
import {createPrintSalesDraftHandler} from '../_shared/print-sales-draft.ts'
// Only private DRAFT bookkeeping. No payment/vendor call or credential setting.
Deno.serve(createPrintSalesDraftHandler({getUser,createAdminDatabase:adminClient}))

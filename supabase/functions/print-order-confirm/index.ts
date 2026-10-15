import { getUser, adminClient } from '../_shared/supabase.ts'
import { createProductionPrintCheckoutHandler } from '../_shared/production-print-checkout.ts'
Deno.serve(createProductionPrintCheckoutHandler({getUser,createAdminDatabase:adminClient,configuration:()=>({
  enabled:Deno.env.get('PRINT_PORTONE_PRODUCTION_ENABLED')==='true'&&Deno.env.get('PRINT_ORDER_REFUNDS_ENABLED')==='true'&&Deno.env.get('PRINT_ORDER_SCHEDULER_ENABLED')==='true',environment:Deno.env.get('PRINT_PORTONE_ENVIRONMENT')??'disabled',
  storeId:Deno.env.get('PRINT_PORTONE_STORE_ID')??'',channelKey:Deno.env.get('PRINT_PORTONE_CHANNEL_KEY')??'',
  apiSecret:Deno.env.get('PRINT_PORTONE_V2_API_SECRET')??'',supabaseUrl:Deno.env.get('SUPABASE_URL')??'',
})},true))

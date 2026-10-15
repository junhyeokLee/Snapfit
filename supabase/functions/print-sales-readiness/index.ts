import { getUser, adminClient } from '../_shared/supabase.ts'
import { createPrintSalesReadinessHandler } from '../_shared/print-sales-readiness.ts'
import { RedprintingFulfillmentClient } from '../_shared/print-fulfillment-vendor.ts'
import { RedprintingError } from '../_shared/redprinting.ts'
const bool=(name:string)=>Deno.env.get(name)==='true'
const testChannel='channel-key-34782ac7-e644-4234-ad27-2767b6904f88'
async function acquireRate(database:any) {
  const owner=crypto.randomUUID(),started=Date.now()
  for(;;) {
    const result=await database.rpc('redprinting_dev_acquire_slot',{p_owner:owner})
    const delay=Number(result.data)
    if(result.error||!Number.isFinite(delay)||delay<0||Date.now()-started>10000)throw new RedprintingError('vendor_api_busy',429)
    if(delay===0)break
    await new Promise(resolve=>setTimeout(resolve,Math.min(delay,1200)))
  }
  return async()=>{const result=await database.rpc('redprinting_dev_release_slot',{p_owner:owner});if(result.error)throw new RedprintingError('vendor_api_busy',429)}
}
Deno.serve(createPrintSalesReadinessHandler({getUser,createAdminDatabase:adminClient,
  runtime:()=>({portoneEnabled:bool('PRINT_PORTONE_PRODUCTION_ENABLED'),portoneLive:Deno.env.get('PRINT_PORTONE_ENVIRONMENT')==='live',
    portoneCredentialsConfigured:/^store-[A-Za-z0-9-]+$/.test(Deno.env.get('PRINT_PORTONE_STORE_ID')??'')&&
      /^channel-key-[A-Za-z0-9-]+$/.test(Deno.env.get('PRINT_PORTONE_CHANNEL_KEY')??'')&&Deno.env.get('PRINT_PORTONE_CHANNEL_KEY')!==testChannel&&
      /^[\x21-\x7e]{8,2048}$/.test(Deno.env.get('PRINT_PORTONE_V2_API_SECRET')??''),
    redprintingEnabled:bool('PRINT_REDP_PRODUCTION_ENABLED'),redprintingApproved:bool('PRINT_REDP_PRODUCTION_APPROVED'),
    redprintingCredentialsConfigured:Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID'))&&Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY')),
    fulfillmentEnabled:bool('PRINT_FULFILLMENT_ENABLED'),depositEnabled:bool('PRINT_REDP_DEPOSIT_ENABLED'),refundsEnabled:bool('PRINT_ORDER_REFUNDS_ENABLED'),
    schedulerEnabled:bool('PRINT_ORDER_SCHEDULER_ENABLED'),schedulerSecretConfigured:/^[a-f0-9]{64}$/.test(Deno.env.get('PRINT_ORDER_SCHEDULER_SECRET')??'')}),
  readSnapshot:async(database:unknown)=>{
    const {data,error}=await (database as ReturnType<typeof adminClient>).rpc('read_print_sales_readiness',{
      p_runtime_store_id:Deno.env.get('PRINT_PORTONE_STORE_ID')??'',p_runtime_channel_key:Deno.env.get('PRINT_PORTONE_CHANNEL_KEY')??''})
    if(error)throw new Error('print_sales_readiness_unavailable')
    return data
  },
  readDepositBalance:async(database:unknown)=>new RedprintingFulfillmentClient({enabled:bool('PRINT_REDP_PRODUCTION_ENABLED'),
    environment:bool('PRINT_REDP_PRODUCTION_ENABLED')?'production':'disabled',productionApproved:bool('PRINT_REDP_PRODUCTION_APPROVED'),
    depositEnabled:bool('PRINT_REDP_DEPOSIT_ENABLED'),userId:Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID')??'',
    apiKey:Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY')??''},()=>acquireRate(database)).depositBalance(),
}))

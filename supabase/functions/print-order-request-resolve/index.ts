import { getUser, adminClient } from '../_shared/supabase.ts'
import { createPrintOrderResolverHandler } from '../_shared/print-order-request.ts'
import { RedprintingCancellationClient } from '../_shared/print-order-cancel-vendor.ts'
import { RedprintingError } from '../_shared/redprinting.ts'
const bool=(key:string)=>Deno.env.get(key)==='true'
const pause=(ms:number)=>new Promise(resolve=>setTimeout(resolve,ms))
async function acquire(db:any){
  const owner=crypto.randomUUID(),started=Date.now()
  for(;;){const r=await db.rpc('redprinting_dev_acquire_slot',{p_owner:owner});if(r.error)throw new RedprintingError('vendor_api_busy',503,true)
    const wait=Number(r.data);if(wait===0)break;if(!Number.isFinite(wait)||wait<0||Date.now()-started>10000)throw new RedprintingError('vendor_api_busy',429,true)
    await pause(Math.min(wait,1200))}
  return async()=>{const r=await db.rpc('redprinting_dev_release_slot',{p_owner:owner});if(r.error)throw new RedprintingError('vendor_api_busy',503,true)}
}
// Signed JWT plus current admin/print_worker role; no browser or customer can
// provide keys, override an amount, or execute a supplier/PG financial request.
Deno.serve(createPrintOrderResolverHandler({getUser,createAdminDatabase:adminClient,
  configuration:()=>({enabled:bool('PRINT_ORDER_REFUNDS_ENABLED'),environment:Deno.env.get('PRINT_PORTONE_ENVIRONMENT')??'disabled',
    apiSecret:Deno.env.get('PRINT_PORTONE_V2_API_SECRET')??'',vendorReady:bool('PRINT_REDP_PRODUCTION_ENABLED')&&bool('PRINT_REDP_PRODUCTION_APPROVED')&&
      Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID'))&&Boolean(Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY'))}),
  vendor:db=>new RedprintingCancellationClient({enabled:bool('PRINT_REDP_PRODUCTION_ENABLED'),environment:bool('PRINT_REDP_PRODUCTION_ENABLED')?'production':'disabled',
    productionApproved:bool('PRINT_REDP_PRODUCTION_APPROVED'),userId:Deno.env.get('PRINT_REDP_PRODUCTION_USER_ID')??'',apiKey:Deno.env.get('PRINT_REDP_PRODUCTION_API_KEY')??''},()=>acquire(db)),
}))

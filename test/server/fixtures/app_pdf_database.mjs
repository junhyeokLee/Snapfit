import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=n=>readFileSync(new URL(`../../../supabase/migrations/${n}`,import.meta.url),'utf8')
const initial=migration('20260820140500_initial_snapfit_schema.sql')
const ordersDdl=initial.slice(initial.indexOf('create table if not exists public.orders ('),initial.indexOf('create trigger orders_set_updated_at')).replace("('ord_' || encode(extensions.gen_random_bytes(12), 'hex'))","('ord_' || gen_random_uuid()::text)")
const owner='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',worker='44444444-4444-4444-8444-444444444444'
const product={id:'REDP_200X150_SOFT',trimWidthMm:200,trimHeightMm:150}
const recipient={name:'테스트',phone:'01000000000',zipCode:'12345',addressLine1:'테스트 주소',addressLine2:'',deliveryMemo:''}
const confirmation={senderName:'스냅핏',senderLabelConfirmed:true,priceSlipOmittedConfirmed:true,promotionalMaterialsOmittedConfirmed:true,evidence:'synthetic approved shipping evidence'}
const costs={estimatedPrintCost:21230,estimatedShippingCost:3500,estimatedPackagingCost:500,paymentFeeRate:.04,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000,
  deliveryPolicy:{coverage:'POSTCODE_RANGES',verified:true,evidence:'synthetic fixed postcode policy',approvedPostcodeRanges:[{start:'12000',end:'12999'}]},fulfillmentConfirmation:confirmation}
const document=JSON.stringify({printProduct:product,pages:Array.from({length:20},(_,index)=>({index,isCover:index===0,layers:[]}))})
const functions=['20260908094302_secure_print_order_payments.sql','20260908104605_redprinting_fulfillment_contract.sql','20260908105146_remove_external_print_payment_integration.sql',
  '20260908114757_redprinting_five_size_contract.sql','20260908120849_redprinting_cover_types_contract.sql','20261013132908_redprinting_verified_combo_retail_policy.sql',
  '20261013170241_portone_production_print_checkout_foundation.sql','20261014142140_print_order_customer_requests_refunds.sql','20261014134738_admin_print_sales_readiness_readonly.sql','20261014161833_app_pdf_prepayment_and_supabase_fulfillment.sql']
async function fixture(approved=true){
  const db=new PGlite()
  await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth,public to authenticated,service_role;
    create table albums(id bigint primary key,owner_id uuid,title text,ratio text,cover_theme text,cover_layers_json text);
    create table album_pages(id bigint primary key,album_id bigint,page_index integer,layers_json jsonb);
    create table album_members(album_id bigint,user_id uuid,role text);
    create function can_access_album(aid bigint) returns boolean language sql security definer stable as $$select exists(select 1 from public.albums where id=aid and owner_id=auth.uid())$$;
    create table redprinting_dev_settings(id integer,sender_name text,sender_tel text,sender_zipcode text,sender_address text,sender_address_detail text);
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    insert into auth.users values('${owner}'),('${other}');${ordersDdl}
    alter table orders enable row level security;create policy own_order_read on orders for select to authenticated using(user_id=auth.uid());`)
  for(const m of functions)await db.exec(migration(m))
  await db.query('insert into albums values(1,$1,$2,$3,null,$4)',[owner,'synthetic album','4:3',document])
  await db.exec(`grant select,update on albums to service_role;grant select on album_pages,album_members to service_role;select set_config('request.jwt.claim.sub','${owner}',false);`)
  if(approved){
    const quote=(await db.query('select get_print_order_quote(1,null) q')).rows[0].q
    const spec={...quote.spec,verified:true,specVersion:'SYNTHETIC_APPROVED_V1'}
    await db.query(`insert into private.print_sales_combinations(product_id,page_count,final_price,price_version,retail_final,supplier_cost_confirmed,shipping_confirmed,packaging_confirmed,
      spec_approved,file_approved,sample_approved,order_code,approved_spec,cost_snapshot,approval_evidence)
      values($1,20,49900,'SYNTHETIC_FINAL_V1',true,true,true,true,true,true,true,'SYNTHETIC_CODE',$2,$3,'synthetic sample and PDF approval')`,[product.id,spec,costs])
    await db.exec(`update private.print_sales_configuration set enabled=true,business_ready=true,portone_live_ready=true,redprinting_live_ready=true,renderer_ready=true,fulfillment_ready=true,
      environment='live',store_id='store-synthetic-live',channel_key='channel-key-synthetic-live',worker_last_seen_at=now(),scheduler_last_seen_at=now();`)
  }
  return db
}
const ctx=async(db)=>(await db.query('select load_owned_print_checkout_context($1,1) x',[owner])).rows[0].x
async function prepare(db,changes={}){
  const c=await ctx(db)
  const v={request:'33333333-3333-4333-8333-333333333333',source:c.sourceDigest,revision:'a'.repeat(64),specRevision:'c'.repeat(64),amount:49900,pages:20,recipient,...changes}
  return (await db.query('select prepare_production_print_checkout($1,$2,1,$3,$4,$5,$6,$7,$8) x',[owner,v.request,v.source,v.revision,v.specRevision,v.amount,v.pages,v.recipient])).rows[0].x
}
const receipt=(i,extra={})=>({provider:'PORTONE',version:'V2',status:'PAID',paymentId:i.payment_id,transactionId:`tx_${i.payment_id}`,storeId:i.store_id,channelKey:i.channel_key,
  amount:i.amount,paidAmount:i.amount,discountAmount:0,currency:'KRW',paidAt:'2026-10-14T00:00:00Z',environment:'live',isTest:false,...extra})
const commit=async(db,i,r=receipt(i),unpaid=false)=>(await db.query('select commit_production_print_payment($1,$2,$3,$4) x',[owner,i.payment_id,r,unpaid])).rows[0].x


export { fixture, ctx, prepare, receipt, commit, owner, other, worker, product, recipient, costs, confirmation };

import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
import {ceilMoneyRate} from '../../supabase/functions/_shared/print-contract.ts'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const migration=n=>readFileSync(new URL(`../../supabase/migrations/${n}`,import.meta.url),'utf8')
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
  '20261013170241_portone_production_print_checkout_foundation.sql','20261014142140_print_order_customer_requests_refunds.sql']
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
      environment='live',store_id='store-synthetic-live',channel_key='channel-key-synthetic-live',worker_last_seen_at=now();`)
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

const cancelId='66666666-6666-4666-8666-666666666666'
const request=async(db,i,type='CANCEL',rid=cancelId,reason='synthetic request')=>(await db.query('select create_owned_print_order_request($1,$2,$3,$4,$5,null,null) x',[owner,rid,type,reason,i.order_id])).rows[0].x
const claimRequest=async(db)=>(await db.query('select claim_print_order_request($1,$2) x',[cancelId,worker])).rows[0].x
const advance=async(db,r,step,e={})=>(await db.query('select advance_print_order_request($1,$2,$3,$4) x',[r.id,worker,step,e])).rows[0].x
const refundReceipt=(i,r=receipt(i))=>({provider:'PORTONE',version:'V2',status:'CANCELLED',paymentId:i.payment_id,transactionId:r.transactionId,storeId:i.store_id,channelKey:i.channel_key,
 amount:i.amount,paidAmount:r.paidAmount,discountAmount:r.discountAmount,cancelledAmount:i.amount,currency:'KRW',environment:'live',isTest:false,
 cancelledAt:'2026-10-14T00:01:00Z',cancellationIds:['cancel-synthetic'],verifiedFullRefund:true})
test('owned cancellation request is idempotent, immutable, private and rejects forged unpaid cancellation',async()=>{
 const db=await fixture();try{const i=await prepare(db),r=await request(db,i),again=await request(db,i)
  assert.deepEqual(r,again);assert.equal(r.status,'REQUESTED');assert.equal(r.replacementAllowed,false);assert.equal(r.checkoutRequestId,i.request_id)
  assert.equal(r.reason,undefined);assert.equal(r.fingerprint,undefined)
  await assert.rejects(request(db,i,'CANCEL',cancelId,'changed'),/print_order_request_conflict/)
  await assert.rejects(db.query('select create_owned_print_order_request($1,$2,\'CANCEL\',\'x\',$3,null,null)',[other,worker,i.order_id]),/print_checkout_not_found/)
  await assert.rejects(db.query('select get_owned_print_order_request($1,$2)',[other,cancelId]),/print_order_request_not_found/)
  await assert.rejects(db.query("update private.print_order_requests set reason='changed'"),/print_order_request_immutable/)
  await assert.rejects(db.query("update orders set status='CANCELED' where order_id=$1",[i.order_id]),/print_order_request_proof_required/)
  for(const role of ['authenticated','anon']){await db.exec(`set role ${role};`)
   for(const sql of ['select * from private.print_order_requests','select * from private.print_payment_reversals',
     `select create_owned_print_order_request('${owner}','${worker}','CANCEL','x','${i.order_id}',null,null)`,
     `select advance_print_order_request('${cancelId}','${worker}','REFUND','{}')`])await assert.rejects(db.query(sql),/permission denied/)
   await db.exec('reset role;')}
 }finally{await db.close()}
})
test('general inquiry never holds manufacturing; cancellation hold prevents SDK replay and late-paid manufacturing',async()=>{
 const db=await fixture();try{const i=await prepare(db)
  await request(db,i,'GENERAL',worker);assert.equal((await db.query('select print_customer_request_hold h from orders')).rows[0].h,false)
  await request(db,i)
  assert.equal((await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x.launch_ready,false)
  await commit(db,i)
  assert.equal((await db.query('select status from orders')).rows[0].status,'PAYMENT_COMPLETED')
  assert.equal((await db.query('select state from private.print_fulfillment_outbox')).rows[0].state,'PENDING')
  assert.equal((await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,null)
  await assert.rejects(db.exec("update orders set status='IN_PRODUCTION'"),/print_customer_request_hold|vendor_acceptance_required/)
  await assert.rejects(db.exec('update orders set print_customer_request_hold=false'),/print_customer_request_hold/)
 }finally{await db.close()}
})
test('hold revokes a previously claimed worker before its supplier attempt and cannot infer an earlier attempt absent',async()=>{
 const db=await fixture();try{const i=await prepare(db);await commit(db,i)
  const job=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  await db.query("update private.print_fulfillment_outbox set event_type='SUBMIT' where id=$1",[job.job.id])
  await request(db,i)
  await assert.rejects(db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[job.job.id,worker,job.job.payload.vendorOrderNum]),/print_worker_lease_lost|print_customer_request_hold/)
  const c=await claimRequest(db);assert.equal(c.supplierNeverAttempted,true)
  await advance(db,c,'PG_ATTEMPT')
  await assert.rejects(advance(db,c,'PG_ATTEMPT'),/print_order_request_attempt_already_recorded/)
 }finally{await db.close()}
})
test('uncertain supplier submission requires matching cancellation status before any refund attempt',async()=>{
 const db=await fixture();try{const i=await prepare(db);await commit(db,i)
  const job=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  await db.query("update private.print_fulfillment_outbox set event_type='SUBMIT' where id=$1",[job.job.id])
  await db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[job.job.id,worker,job.job.payload.vendorOrderNum])
  await request(db,i);const c=await claimRequest(db);assert.equal(c.supplierNeverAttempted,false)
  await assert.rejects(advance(db,c,'PG_ATTEMPT'),/print_supplier_cancel_proof_required/)
  await assert.rejects(advance(db,c,'SUPPLIER_CANCELED',{orderNum:'forged',orderSeq:1,statusCode:'PGS_01',statusCodeOrg:'PGS_02'}),/print_order_request_proof_required/)
  await advance(db,c,'SUPPLIER_CANCELED',{orderNum:c.supplierOrderNum,orderSeq:1,statusCode:'PGS_01',statusCodeOrg:'PGS_02'})
  await advance(db,c,'PG_ATTEMPT')
 }finally{await db.close()}
})
test('exact LIVE full refund adds immutable reversal evidence, preserves original payment receipt, and atomically cancels',async()=>{
 const db=await fixture();try{const i=await prepare(db),paid=receipt(i,{paidAmount:44910,discountAmount:4990});await commit(db,i,paid)
  await request(db,i);const c=await claimRequest(db),full=refundReceipt(i,paid)
  for(const bad of [{...full,isTest:true,environment:'test'},{...full,transactionId:'forged'},{...full,cancelledAmount:1},{...full,cancellationIds:[]}])
   await assert.rejects(advance(db,c,'REFUND',bad),/print_order_request_proof_required/)
  await assert.rejects(db.query("update orders set status='CANCELED',payment_reversed_at=now(),payment_reversal_status='FULL_REFUND' where order_id=$1",[i.order_id]),/physical_order_payments_disabled/)
  const r=await advance(db,c,'REFUND',full);assert.equal(r.resolution,'REFUNDED_FULL');assert.equal(r.replacementAllowed,true)
  const o=(await db.query('select status,verified_payment_id,payment_reversal_status from orders')).rows[0]
  assert.equal(o.status,'CANCELED');assert.equal(o.verified_payment_id,i.payment_id);assert.equal(o.payment_reversal_status,'FULL_REFUND')
  const original=(await db.query('select status,payment_receipt from private.print_checkout_intents')).rows[0]
  assert.equal(original.status,'PAID');assert.deepEqual(original.payment_receipt,paid)
  assert.equal((await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x.refunded_full,true)
  assert.equal((await claimRequest(db)).completed,true);assert.equal((await db.query('select count(*) n from private.print_payment_reversals')).rows[0].n,1)
  await db.exec('set role service_role;');await assert.rejects(db.exec("update private.print_payment_reversals set receipt='{}'"),/permission denied/);await db.exec('reset role;')
 }finally{await db.close()}
})
test('unpaid request completes only after authoritative terminal receipt, never before',async()=>{
 const db=await fixture();try{const i=await prepare(db);await request(db,i);const c=await claimRequest(db)
  await assert.rejects(advance(db,c,'UNPAID'),/print_order_request_proof_required/)
  const failed={provider:'PORTONE',version:'V2',status:'FAILED',paymentId:i.payment_id,transactionId:'tx-synthetic-failed',storeId:i.store_id,channelKey:i.channel_key,
   amount:i.amount,paidAmount:0,cancelledAmount:0,currency:'KRW',environment:'live',isTest:false,verifiedUnpaid:true}
  await commit(db,i,failed,true)
  const done=await advance(db,c,'UNPAID');assert.equal(done.resolution,'CANCELLED_UNPAID');assert.equal(done.replacementAllowed,true)
 }finally{await db.close()}
})
test('deposit shortage is a visible retryable hold before any durable deposit attempt',async()=>{
 const db=await fixture();try{const i=await prepare(db);await commit(db,i)
  const job=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  await db.query("update private.print_fulfillment_outbox set event_type='CONFIRM' where id=$1",[job.job.id])
  const failed=(await db.query('select fail_print_fulfillment_job($1,$2,$3,now(),false) x',[job.job.id,worker,'supplier_deposit_insufficient'])).rows[0].x
  assert.equal(failed.state,'PENDING');assert.equal(failed.payload.depositAttempted,undefined)
  assert.equal((await db.query('select print_requires_action x from orders')).rows[0].x,true)
  const next=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x;assert.equal(next.job.id,job.job.id)
  await db.query("select finish_print_fulfillment_job($1,$2,'CONFIRM',$3)",[job.job.id,worker,{nextStage:'POLL',availableAt:'2099-01-01T00:00:00Z'}])
  assert.equal((await db.query('select print_requires_action x from orders')).rows[0].x,false)
 }finally{await db.close()}
})
test('pending request queue is bounded and owned public request readback remains read-only',async()=>{
 const db=await fixture();try{const i=await prepare(db);await request(db,i)
  await db.exec("update private.print_order_requests set updated_at=now()-interval '2 minutes'")
  const tick=(await db.query('select list_print_order_requests(1,null,true) x')).rows[0].x
  assert.equal(tick.length,1);assert.equal(tick[0].requestId,cancelId);assert.equal(tick[0].reason,undefined)
  const admin=(await db.query('select list_print_order_requests(50,$1,false) x',[i.order_id])).rows[0].x
  assert.equal(admin[0].reason,'synthetic request');assert.equal(admin[0].intent_id,undefined)
  assert.equal((await db.query('select list_print_order_requests(50,$1,false) x',['ordp_99999999-9999-4999-8999-999999999999'])).rows[0].x.length,0)
  await claimRequest(db);assert.equal((await db.query('select list_print_order_requests(1,null,true) x')).rows[0].x.length,0)
 }finally{await db.close()}
})
test('already-started production can continue status-only POLL after a review-required cancellation request',async()=>{
 const db=await fixture();try{const i=await prepare(db);await commit(db,i)
  // Synthetic prior verified production evidence, installed before the hold.
  // Bypass only this fixture transition to isolate the new hold's POLL contract.
  await db.exec('alter table orders disable trigger user;')
  await db.query("update print_order_operations set print_cost_snapshot=$1,actual_print_cost=21230,actual_shipping_cost=3500,actual_packaging_cost=500,payment_fee_reserve=1996,reprint_reserve=2495,operations_reserve=3000,contribution_margin=17179,fulfillment_confirmation=$2",[costs,confirmation])
  await db.query("update orders set status='IN_PRODUCTION',print_fulfillment_status='ACCEPTED',print_accepted_at=now(),print_submitted_at=now(),print_spec_confirmed_at=now(),print_cover_pdf_path='synthetic/cover.pdf',print_interior_pdf_path='synthetic/interior.pdf',print_manifest='{}',print_vendor='REDPRINTING',print_vendor_order_id=$1,fulfillment_method='DIRECT',sender_label_confirmed=true,price_slip_omitted_confirmed=true,promotional_materials_omitted_confirmed=true",[`SFO_${i.id.replaceAll('-','')}`])
  await db.exec("update private.print_fulfillment_outbox set event_type='POLL'")
  await db.exec('alter table orders enable trigger user;')
  const r=await request(db,i);assert.equal(r.status,'REVIEW_REQUIRED')
  const job=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  assert.equal(job.job.event_type,'POLL');assert.equal(job.order.print_customer_request_hold,true)
  await db.query('select renew_print_fulfillment_job($1,$2,120,true)',[job.job.id,worker])
  const c=await claimRequest(db);assert.equal(c.productionStarted,true)
  await assert.rejects(advance(db,c,'PG_ATTEMPT'),/print_order_request_review_required/)
 }finally{await db.close()}
})
test('CONFIRM started production but customer hold revoked worker lease: exact GET evidence recovers POLL without financial writes',async()=>{
 const db=await fixture();try{const i=await prepare(db),paid=receipt(i);await commit(db,i,paid)
  const supplier=`SFO_${i.id.replaceAll('-','')}`
  // Install only preexisting, synthetic supplier-submission evidence. This
  // fixture never calls a PG/vendor or operates on a remote database.
  await db.exec('alter table orders disable trigger user;')
  await db.query("update print_order_operations set print_cost_snapshot=$1,actual_print_cost=21230,actual_shipping_cost=3500,actual_packaging_cost=500,payment_fee_reserve=1996,reprint_reserve=2495,operations_reserve=3000,contribution_margin=17179,fulfillment_confirmation=$2",[costs,confirmation])
  await db.query("update orders set print_fulfillment_status='SUBMITTED',print_submitted_at=now(),print_spec_confirmed_at=now(),print_cover_pdf_path='synthetic/cover.pdf',print_interior_pdf_path='synthetic/interior.pdf',print_manifest='{}',print_vendor='REDPRINTING',print_vendor_order_id=$1,fulfillment_method='DIRECT',sender_label_confirmed=true,price_slip_omitted_confirmed=true,promotional_materials_omitted_confirmed=true",[supplier])
  await db.exec('alter table orders enable trigger user;')
  await db.exec("update private.print_fulfillment_outbox set event_type='CONFIRM',payload=payload||jsonb_build_object('queryOnly',true,'supplierAttemptedAt',now(),'depositAttempted',true)")
  const prior=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  await request(db,i)
  await assert.rejects(db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[prior.job.id,worker,supplier]),/print_worker_lease_lost|print_customer_request_hold/)
  const r=await claimRequest(db),e={orderNum:supplier,orderSeq:1,statusCode:'PGS_20',statusCodeOrg:'PGS_40',courier:'',trackingNumber:''}
  await assert.rejects(advance(db,r,'PRODUCTION_REVIEW',{...e,orderNum:'forged'}),/print_order_request_proof_required/)
  const outcome=await advance(db,r,'PRODUCTION_REVIEW',e);assert.equal(outcome.status,'REVIEW_REQUIRED');assert.equal(outcome.replacementAllowed,false)
  const o=(await db.query('select status,print_fulfillment_status,print_customer_request_hold,payment_reversed_at from orders')).rows[0]
  assert.equal(o.status,'IN_PRODUCTION');assert.equal(o.print_fulfillment_status,'ACCEPTED');assert.equal(o.print_customer_request_hold,true);assert.equal(o.payment_reversed_at,null)
  const next=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
  assert.equal(next.job.event_type,'POLL');assert.equal(next.job.payload.depositAttempted,true)
  assert.deepEqual((await db.query('select payment_receipt from private.print_checkout_intents')).rows[0].payment_receipt,paid)
  assert.equal((await db.query('select count(*) n from private.print_payment_reversals')).rows[0].n,0)
 }finally{await db.close()}
})


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
  '20261013170241_portone_production_print_checkout_foundation.sql']
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

test('all software sales gates start closed, even with a planned supplier price',async()=>{
  const db=await fixture(false);try{const c=await ctx(db);assert.equal(c.canPay,false);assert.equal(c.quote.retailPriceStatus,'PLANNED');assert.equal(c.configuration.worker_last_seen_at,null)
    await assert.rejects(prepare(db),/print_sales_not_ready/);assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
  }finally{await db.close()}
})
test('secure prepare freezes the authoritative spec/album/recipient and retries the exact same IDs',async()=>{
  const db=await fixture();try{const i=await prepare(db),again=await prepare(db);assert.equal(i.payment_id,again.payment_id);assert.match(i.payment_id,/^SFP_/);assert.equal(i.status,'PREPARED')
    const o=(await db.query('select * from orders')).rows[0];assert.equal(o.status,'PAYMENT_PENDING');assert.equal(o.checkout_flow,'PORTONE_V2_V1');assert.deepEqual(o.print_spec_snapshot,i.approved_spec)
    assert.deepEqual(i.delivery_snapshot,recipient);assert.equal(i.page_count,20);assert.equal(i.snapshot.pages.length,0);assert.deepEqual(i.source_asset_owners,[owner])
    for(const change of [{amount:1},{pages:22},{revision:'b'.repeat(64)},{recipient:{...recipient,addressLine1:'changed'}}])await assert.rejects(prepare(db,change),/print_checkout_request_conflict/)
    await db.exec(`update albums set title='later edit';update private.print_sales_configuration set enabled=false;`)
    const replay=await prepare(db);assert.equal(replay.payment_id,i.payment_id);assert.equal(replay.snapshot.album.title,'synthetic album')
    await assert.rejects(db.query('select get_owned_print_checkout($1,$2,null)',[other,i.payment_id]),/print_checkout_not_found/)
  }finally{await db.close()}
})
test('page CAS, current quote, shipping region and renderer heartbeat reject before creating invoices',async()=>{
  const db=await fixture();try{
    await assert.rejects(prepare(db,{source:'b'.repeat(64)}),/print_album_changed/)
    await assert.rejects(prepare(db,{pages:22}),/print_quote_changed/)
    await assert.rejects(prepare(db,{recipient:{...recipient,zipCode:'99999'}}),/print_delivery_quote_required/)
    await db.exec(`update private.print_sales_configuration set worker_last_seen_at=now()-interval '6 minutes';`)
    assert.equal((await ctx(db)).canPay,false);await assert.rejects(prepare(db),/print_sales_not_ready/)
    assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
  }finally{await db.close()}
})
test('approval/spec changes between review and freeze invalidate CAS and never silently replace a pending book',async()=>{
  const db=await fixture();try{
    const beforeMembership=await ctx(db)
    await db.query("insert into album_members values(1,$1,'EDITOR'),(1,$2,'OWNER')",[other,owner])
    const afterMembership=await ctx(db)
    assert.deepEqual(afterMembership.allowedAssetOwners,[owner,other]);assert.notEqual(beforeMembership.sourceDigest,afterMembership.sourceDigest)
    await assert.rejects(prepare(db,{source:beforeMembership.sourceDigest}),/print_album_changed/)
    const original=await ctx(db)
    await db.exec("update private.print_sales_combinations set approved_spec=jsonb_set(approved_spec,'{specVersion}','\"SYNTHETIC_APPROVED_V2\"');")
    await assert.rejects(prepare(db,{source:original.sourceDigest}),/print_album_changed/)
    const i=await prepare(db)
    assert.equal((await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x.launch_ready,true)
    await db.exec("update private.print_sales_combinations set approved_spec=jsonb_set(approved_spec,'{specVersion}','\"SYNTHETIC_APPROVED_V3\"');")
    const unchanged=(await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x
    assert.equal(unchanged.launch_ready,false);assert.equal(unchanged.approved_spec.specVersion,'SYNTHETIC_APPROVED_V2')
    await commit(db,i)
    const claim=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
    assert.equal(claim.approvalCurrent,false);assert.equal(claim.approvedSpec.specVersion,'SYNTHETIC_APPROVED_V2')
  }finally{await db.close()}
})
test('customers/anonymous cannot create/forge/read private checkout or worker rows',async()=>{
  const db=await fixture();try{const i=await prepare(db)
    for(const role of ['authenticated','anon']){await db.exec(`set role ${role};`)
      for(const sql of ['select * from private.print_sales_configuration','select * from private.print_checkout_intents',"select claim_print_fulfillment_job('44444444-4444-4444-8444-444444444444')",
        `select prepare_production_print_checkout('${owner}','33333333-3333-4333-8333-333333333333',1,'${'a'.repeat(64)}','${'a'.repeat(64)}','${'c'.repeat(64)}',49900,20,'{}')`,
        `update orders set status='PAYMENT_COMPLETED' where order_id='${i.order_id}'`])await assert.rejects(db.query(sql),/permission denied/)
      await db.exec('reset role;')
    }
    await assert.rejects(db.query("update orders set status='PAYMENT_COMPLETED',verified_payment_id=$1,verified_payment_provider='PORTONE',payment_confirmed_at=now() where order_id=$2",[i.payment_id,i.order_id]),/physical_order_payments_disabled/)
  }finally{await db.close()}
})
test('only exact LIVE PAID observation commits one immutable receipt and one durable job',async()=>{
  const db=await fixture();try{const i=await prepare(db)
    for(const extra of [{isTest:true,environment:'test'},{amount:1},{storeId:'other'},{channelKey:'other'},{status:'PENDING'},{paidAmount:0},{paidAmount:49899},{paidAt:null}])await assert.rejects(commit(db,i,receipt(i,extra)),/print_payment_receipt_invalid/)
    const paid=await commit(db,i);assert.equal(paid.status,'PAID');assert.equal((await commit(db,i)).verified_at,paid.verified_at)
    assert.equal((await db.query('select status from orders')).rows[0].status,'PAYMENT_COMPLETED');assert.equal((await db.query('select count(*) n from private.print_fulfillment_outbox')).rows[0].n,1)
    await assert.rejects(commit(db,i,receipt(i,{transactionId:'other_transaction'})),/print_payment_receipt_conflict/)
    await assert.rejects(db.query("update private.print_checkout_intents set amount=1 where payment_id=$1",[i.payment_id]),/print_checkout_immutable/)
    await assert.rejects(db.query("update orders set address_line1='different' where order_id=$1",[i.order_id]),/order_purchase_details_immutable/)
  }finally{await db.close()}
})
test('only authoritative zero-charge FAILED or full CANCELLED releases the pending invoice',async()=>{
  const db=await fixture();try{const i=await prepare(db)
    const unpaid=receipt(i,{status:'FAILED',paidAmount:0,cancelledAmount:0,verifiedUnpaid:true})
    for(const extra of [{status:null},{status:'CANCELLED',paidAmount:100,cancelledAmount:99},{status:'READY'}])await assert.rejects(commit(db,i,{...unpaid,...extra},true),/print_payment_receipt_invalid/)
    const r=await commit(db,i,unpaid,true);assert.equal(r.status,'FAILED');assert.equal((await db.query('select status from orders')).rows[0].status,'CANCELED')
    assert.equal((await db.query('select count(*) n from private.print_fulfillment_outbox')).rows[0].n,0)
    await assert.rejects(commit(db,i),/print_payment_receipt_conflict/)
  }finally{await db.close()}
})
test('worker lease owns PDF publication; timeout after attempted submit becomes query-only',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    const claim=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,j=claim.job
    assert.deepEqual(claim.costSnapshot,costs);assert.equal(claim.paymentEnvironment,'live');assert.equal(claim.paymentExpectation.paymentId,i.payment_id)
    assert.equal(claim.order.print_package_lock_token,worker)
    assert.equal((await db.query('select get_print_fulfillment_job($1,$2) x',[j.id,worker])).rows[0].x.order.order_id,i.order_id)
    await assert.rejects(db.query('select renew_print_fulfillment_job($1,$2,120,true)',[j.id,other]),/print_worker_lease_lost/)
    await db.query('select renew_print_fulfillment_job($1,$2,120,true)',[j.id,worker])
    await assert.rejects(db.query("select finish_print_fulfillment_job($1,$2,'RENDER','{\"nextStage\":\"SUBMIT\"}')",[j.id,worker]),/print_files_not_ready/)
    await db.query("update private.print_fulfillment_outbox set event_type='SUBMIT' where id=$1",[j.id])
    await db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[j.id,worker,j.payload.vendorOrderNum])
    const failed=(await db.query("select fail_print_fulfillment_job($1,$2,'provider_timeout',now(),false) x",[j.id,worker])).rows[0].x
    assert.equal(failed.state,'UNKNOWN');assert.equal(failed.payload.queryOnly,true);assert.ok(failed.payload.supplierAttemptedAt)
    assert.equal((await db.query('select print_package_lock_token from orders')).rows[0].print_package_lock_token,null)
    const second=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[other])).rows[0].x
    assert.equal(second.job.payload.vendorOrderNum,j.payload.vendorOrderNum)
    await assert.rejects(db.query('select get_print_fulfillment_job($1,$2)',[j.id,worker]),/print_worker_lease_lost/)
  }finally{await db.close()}
})
test('owned public progress is sanitized, RLS enforced and does not need private schema access',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${owner}',false);`)
    const p=(await db.query('select fetch_my_print_order_progress($1) x',[i.order_id])).rows[0].x
    assert.equal(p.customerStage,'PAID');assert.equal(p.requiresAction,false);assert.equal(p.fileCheckedAt,null)
    assert.doesNotMatch(JSON.stringify(p),/cost|snapshot|secret|recipient|source|vendorOrderNum/i)
    await db.exec(`select set_config('request.jwt.claim.sub','${other}',false);`);await assert.rejects(db.query('select fetch_my_print_order_progress($1)',[i.order_id]),/order_access_denied/)
  }finally{await db.close()}
})
test('server invoker RPCs work as service_role and cannot borrow a provider transaction for another checkout',async()=>{
  const db=await fixture();try{await db.exec('set role service_role;')
    const i=await prepare(db);await commit(db,i)
    const j=await prepare(db,{request:'66666666-6666-4666-8666-666666666666'})
    await assert.rejects(commit(db,j,receipt(j,{transactionId:receipt(i).transactionId})),/duplicate key/)
    assert.equal((await db.query('select status from private.print_checkout_intents where id=$1',[j.id])).rows[0].status,'PREPARED')
    assert.equal((await db.query('select status from orders where order_id=$1',[j.order_id])).rows[0].status,'PAYMENT_PENDING')
    assert.equal((await db.query('select count(*) n from private.print_fulfillment_outbox')).rows[0].n,1)
  }finally{await db.close()}
})
test('failed runtime cannot refresh renderer readiness, and durable deposit attempts cannot be rewound',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    const first=(await db.query('select claim_print_fulfillment_job($1,1,120,false) x',[worker])).rows[0].x
    assert.equal(first,null);assert.equal((await ctx(db)).canPay,false)
    const claim=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,j=claim.job
    assert.equal((await ctx(db)).canPay,true)
    await db.query("update private.print_fulfillment_outbox set event_type='CONFIRM' where id=$1",[j.id])
    const attempt=(await db.query('select record_print_fulfillment_attempt($1,$2,$3,1) x',[j.id,worker,j.payload.vendorOrderNum])).rows[0].x
    assert.equal(attempt.payload.depositAttempted,true)
    await assert.rejects(db.query("select finish_print_fulfillment_job($1,$2,'CONFIRM','{\"nextStage\":\"POLL\",\"depositAttempted\":false}')",[j.id,worker]),/print_deposit_attempt_immutable/)
    const stopped=(await db.query('select renew_print_fulfillment_job($1,$2,120,false) x',[j.id,worker])).rows[0].x
    assert.equal(stopped,null);assert.equal((await ctx(db)).canPay,false)
    await db.query('select renew_print_fulfillment_job($1,$2,120,true)',[j.id,worker])
    const failed=(await db.query("select fail_print_fulfillment_job($1,$2,'provider_timeout',now(),false) x",[j.id,worker])).rows[0].x
    assert.equal(failed.state,'UNKNOWN');assert.equal(failed.payload.depositAttempted,true)
  }finally{await db.close()}
})
test('pre-submit lookup timeout retries normally; only a recorded supplier attempt requires query-only recovery',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    let claim=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
    await db.query("update private.print_fulfillment_outbox set event_type='SUBMIT' where id=$1",[claim.job.id])
    const before=(await db.query("select fail_print_fulfillment_job($1,$2,'payment_lookup_timeout',now(),false) x",[claim.job.id,worker])).rows[0].x
    assert.equal(before.state,'PENDING');assert.equal(before.payload.queryOnly,false)
    claim=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
    await db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[claim.job.id,worker,claim.job.payload.vendorOrderNum])
    const after=(await db.query("select fail_print_fulfillment_job($1,$2,'provider_timeout',now(),false) x",[claim.job.id,worker])).rows[0].x
    assert.equal(after.state,'UNKNOWN');assert.equal(after.payload.queryOnly,true)
  }finally{await db.close()}
})
test('expired pending invoices are rechecked once per minute and can commit late payment while new sales are stopped',async()=>{
  const db=await fixture();try{const i=await prepare(db)
    // Expiry is immutable; move test time by creating a legitimate old expectation, not by changing a frozen row.
    await db.exec("alter table private.print_checkout_intents alter column expires_at set default now()-interval '1 hour';")
    const late=await prepare(db,{request:'66666666-6666-4666-8666-666666666666'})
    assert.ok(Date.parse(late.expires_at)<Date.now())
    await db.exec('update private.print_sales_configuration set enabled=false;')
    const check=(await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x
    assert.equal(check.length,2);assert.ok(check.some(v=>v.payment_id===late.payment_id))
    assert.deepEqual((await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x,[])
    await commit(db,late);assert.equal((await db.query('select status from orders where order_id=$1',[late.order_id])).rows[0].status,'PAYMENT_COMPLETED')
    assert.equal((await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,null)
    assert.equal((await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x.launch_ready,false)
  }finally{await db.close()}
})
test('confirmed supplier submission atomically stores exact frozen costs and direct shipping evidence under the active lease',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    const rendered=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x,j=rendered.job
    const manifest={spec:i.approved_spec,sourceFingerprint:'a'.repeat(64),cover:{sha256:'b'.repeat(64),pageCount:1},interior:{sha256:'c'.repeat(64),pageCount:20}}
    await db.query("update orders set print_fulfillment_status='RENDERING',print_upload_fingerprint=$2 where order_id=$1",[i.order_id,'a'.repeat(64)])
    await db.query("update orders set print_fulfillment_status='REVIEW_REQUIRED',print_cover_pdf_path='fixture/cover.pdf',print_interior_pdf_path='fixture/interior.pdf',print_manifest=$2,print_package_generated_at=now() where order_id=$1",[i.order_id,manifest])
    await db.query("update orders set print_fulfillment_status='READY',print_spec_confirmed_at=now() where order_id=$1",[i.order_id])
    await db.query("select finish_print_fulfillment_job($1,$2,'RENDER','{\"nextStage\":\"SUBMIT\"}')",[j.id,worker])
    const submit=(await db.query('select claim_print_fulfillment_job($1,1,120,true) x',[worker])).rows[0].x
    const operations={actual_print_cost:21230,actual_shipping_cost:3500,actual_packaging_cost:500,payment_fee_reserve:1996,reprint_reserve:2495,operations_reserve:3000,contribution_margin:17179,fulfillment_confirmation:confirmation}
    await assert.rejects(db.query('select commit_print_fulfillment_submission($1,$2,$3,$4)',[j.id,worker,submit.job.payload.vendorOrderNum,operations]),/print_worker_submission_invalid/)
    await db.query('select record_print_fulfillment_attempt($1,$2,$3,1)',[j.id,worker,submit.job.payload.vendorOrderNum])
    await assert.rejects(db.query('select commit_print_fulfillment_submission($1,$2,$3,$4)',[j.id,other,submit.job.payload.vendorOrderNum,operations]),/print_worker_lease_lost/)
    await assert.rejects(db.query('select commit_print_fulfillment_submission($1,$2,$3,$4)',[j.id,worker,submit.job.payload.vendorOrderNum,{...operations,actual_print_cost:21231}]),/print_worker_supply_quote_changed/)
    const order=(await db.query('select commit_print_fulfillment_submission($1,$2,$3,$4) x',[j.id,worker,submit.job.payload.vendorOrderNum,operations])).rows[0].x
    assert.equal(order.print_fulfillment_status,'SUBMITTED');assert.equal(order.status,'PAYMENT_COMPLETED')
    assert.equal((await db.query('select commit_print_fulfillment_submission($1,$2,$3,$4) x',[j.id,worker,submit.job.payload.vendorOrderNum,operations])).rows[0].x.print_submitted_at,order.print_submitted_at)
    assert.equal((await db.query('select contribution_margin from print_order_operations where order_id=$1',[i.order_id])).rows[0].contribution_margin,17179)
    // Supplier file acceptance is a separate fact from beginning production.
    await db.query('update orders set print_file_checked_at=now(),print_accepted_at=now() where order_id=$1',[i.order_id])
    await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${owner}',false);`)
    const progress=(await db.query('select fetch_my_print_order_progress($1) x',[i.order_id])).rows[0].x
    assert.equal(progress.customerStage,'PRODUCTION_PENDING');assert.equal(progress.preflightPassed,true);assert.ok(progress.vendorAcceptedAt);assert.ok(progress.fileCheckedAt)
    assert.equal(progress.productionStartedAt,null)
  }finally{await db.close()}
})
test('payment and reprint reserves agree with PostgreSQL decimal ceil, including exact integer boundary and exponent rates',async()=>{
  const db=new PGlite();try{
    assert.equal(Math.ceil(69900*.07),4894);assert.equal(ceilMoneyRate(69900,.07),4893)
    for(const amount of [49900,69900,100000])for(const rate of [.04,.05,.07,.035,.3333,1e-7]){
      const pg=(await db.query('select ceil($1::numeric * $2::numeric)::integer n',[String(amount),String(rate)])).rows[0].n
      assert.equal(ceilMoneyRate(amount,rate),pg,`${amount}/${rate}`)
    }
  }finally{await db.close()}
})
test('exact-order job lookup finds an old failure outside the recent fifty without exposing private data or granting customer access',async()=>{
  const db=await fixture();try{const i=await prepare(db);await commit(db,i)
    await db.query("update private.print_fulfillment_outbox set state='FAILED',last_error_code='supplier_file_error',updated_at=now()-interval '2 days' where order_id=$1",[i.order_id])
    await db.query("insert into orders(order_id,user_id,status) select 'synthetic-recent-'||n,$1,'PAYMENT_PENDING' from generate_series(1,51) n",[owner])
    await db.exec("insert into private.print_fulfillment_outbox(order_id) select 'synthetic-recent-'||n from generate_series(1,51) n;")
    await db.exec('set role service_role;')
    const recent=(await db.query('select list_print_fulfillment_jobs() x')).rows[0].x
    assert.equal(recent.length,50);assert.equal(recent.some(v=>v.order_id===i.order_id),false)
    const exact=(await db.query('select list_print_fulfillment_jobs(50,$1) x',[i.order_id])).rows[0].x
    assert.equal(exact.length,1);assert.equal(exact[0].order_id,i.order_id);assert.equal(exact[0].last_error_code,'supplier_file_error')
    assert.doesNotMatch(JSON.stringify(exact),/snapshot|cost|recipient|asset|payment_receipt|vendorOrderNum|payload|secret/i)
    assert.deepEqual((await db.query("select list_print_fulfillment_jobs(50,'unknown') x")).rows[0].x,[])
    await db.exec('reset role;set role authenticated;')
    await assert.rejects(db.query('select list_print_fulfillment_jobs(50,$1)',[i.order_id]),/permission denied/)
    await db.exec('reset role;set role anon;')
    await assert.rejects(db.query('select list_print_fulfillment_jobs(50,$1)',[i.order_id]),/permission denied/)
  }finally{await db.close()}
})

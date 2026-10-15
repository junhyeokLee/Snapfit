import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFile} from 'node:fs/promises'
import {fixture,prepare,commit,owner,worker} from './fixtures/app_pdf_database.mjs'
import {resolvePrintOrderRequest} from '../../supabase/functions/_shared/print-order-request.ts'
import {PortOnePrintPaymentError} from '../../supabase/functions/_shared/portone-print-payment.ts'
const migration=await readFile(new URL('../../supabase/migrations/20261014170828_app_pdf_pre_sdk_cancel_recovery.sql',import.meta.url),'utf8')
const requestId='77777777-7777-4777-8777-777777777777'
async function setup(t){const db=await fixture();t.after(()=>db.close());await db.exec(migration);const i=await prepare(db);return{db,i}}
const create=async(db,i)=>(await db.query("select create_owned_print_order_request($1,$2,'CANCEL','prepare PDF too large',$3,null,null) x",[owner,requestId,i.order_id])).rows[0].x
const claim=async db=>(await db.query('select claim_print_order_request($1,$2) x',[requestId,worker])).rows[0].x
const observation=i=>({provider:'PORTONE',version:'V2',status:'NOT_FOUND',paymentId:i.payment_id,storeId:i.store_id,channelKey:i.channel_key,amount:i.amount,currency:'KRW',environment:'live',httpStatus:404,observedAt:new Date().toISOString()})
const abort=async(db,i,proof=observation(i))=>(await db.query('select abort_print_pre_sdk_request($1,$2,$3) x',[requestId,worker,proof])).rows[0].x
const request=async db=>(await db.query('select get_owned_print_order_request($1,$2,null,null,null) x',[owner,requestId])).rows[0].x
async function readyPackage(db,i){
  const manifest={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:'f'.repeat(64),specVersion:i.approved_spec.specVersion,productId:i.product.id,coverType:'SOFT',pageCount:20,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,missingAssets:[],warnings:[],declaredFiles:{cover:{bytes:100,sha256:'a'.repeat(64)},interior:{bytes:100,sha256:'b'.repeat(64)}}}
  const base=[owner,i.request_id,i.order_id,i.payment_id]
  const p=(await db.query("select print_prepayment_package($1,'uploads',$2,$3,$4,null,null,$5,$6) x",[...base,{sourceFingerprint:'f'.repeat(64),specVersion:i.approved_spec.specVersion},manifest])).rows[0].x.package
  for(const kind of['cover','interior'])await db.query("select print_prepayment_package($1,'finalize',$2,$3,$4,$5,$6,$7,$8)",[...base,p.id,kind,{pageCount:kind==='cover'?1:20,widthMm:kind==='cover'?417.22:210,heightMm:160,byteLength:100,sha256:manifest.declaredFiles[kind].sha256},manifest])
  await db.query("select print_prepayment_package($1,'seal',$2,$3,$4,$5)",[...base,p.id])
}
function adapter(db){return{async rpc(name,p){
  const allowed={claim_print_order_request:['p_request_id','p_owner'],advance_print_order_request:['p_id','p_owner','p_step','p_evidence'],abort_print_pre_sdk_request:['p_request_id','p_owner','p_pg_observation'],commit_production_print_payment:['p_actor','p_payment_id','p_receipt','p_unpaid']}
  assert.ok(allowed[name],name)
  try{return{data:(await db.query(`select ${name}(${allowed[name].map((_,i)=>`$${i+1}`).join(',')}) x`,allowed[name].map(key=>p[key]??null))).rows[0].x,error:null}}
  catch(error){return{data:null,error:{code:error.code,message:error.message}}}
}}}
const config={enabled:true,environment:'live',apiSecret:'synthetic-server-only-secret',vendorReady:false}

test('owner cancellation + fresh server 404 atomically records PRE_SDK_ABORTED, no PG receipt, and permits a distinct new request',async t=>{
  const {db,i}=await setup(t);await create(db,i)
  const resolved=await resolvePrintOrderRequest(adapter(db),config,requestId,worker,{}, {queryPayment:async()=>{throw new PortOnePrintPaymentError('payment_not_found',404,true)}})
  assert.equal(resolved.request.status,'COMPLETED');assert.equal(resolved.request.resolution,'PRE_SDK_ABORTED');assert.equal(resolved.request.preSdkAbortVerified,true);assert.equal(resolved.request.replacementAllowed,true)
  const preserved=(await db.query('select * from private.print_checkout_intents where id=$1',[i.id])).rows[0]
  assert.equal(preserved.status,'PREPARED');assert.equal(preserved.payment_receipt,null);assert.equal(preserved.verified_at,null);assert.equal(preserved.sdk_issued_at,null)
  const order=(await db.query('select * from orders where order_id=$1',[i.order_id])).rows[0]
  assert.equal(order.status,'PAYMENT_PENDING');assert.equal(order.print_customer_request_hold,true);assert.ok(order.print_preparation_aborted_at);assert.equal(order.verified_payment_id,null)
  assert.equal((await db.query('select count(*)::integer n from private.print_pre_sdk_aborts')).rows[0].n,1)
  assert.equal((await db.query('select count(*)::integer n from private.print_fulfillment_outbox')).rows[0].n,0)
  assert.equal((await db.query('select count(*)::integer n from private.print_payment_reversals')).rows[0].n,0)
  await assert.rejects(db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id]),/print_files_not_ready/)
  await db.query("update albums set title='smaller revised album' where id=1")
  const replacement=await prepare(db,{request:'88888888-8888-4888-8888-888888888888'});assert.notEqual(replacement.payment_id,i.payment_id);assert.notEqual(replacement.order_id,i.order_id)
  assert.equal((await request(db)).replacementAllowed,true)
})

test('fresh provider absence is mandatory; timeout, unknown, foreign/stale/missing proof never releases pending refs',async t=>{
  const {db,i}=await setup(t);await create(db,i);await claim(db)
  for(const proof of[null,{...observation(i),paymentId:'SFP_other'},{...observation(i),observedAt:'2000-01-01T00:00:00Z'},{...observation(i),httpStatus:200},{...observation(i),status:'UNKNOWN'}])
    await assert.rejects(abort(db,i,proof),/print_order_request_proof_required/)
  assert.equal((await db.query('select count(*)::integer n from private.print_pre_sdk_aborts')).rows[0].n,0)
  await db.exec("update private.print_order_requests set lease_owner=null,lease_until=null")
  const unknown=await resolvePrintOrderRequest(adapter(db),config,requestId,worker,{}, {queryPayment:async()=>({kind:'unknown'})})
  assert.equal(unknown.request.status,'WAITING_PROVIDER');assert.equal(unknown.request.replacementAllowed,false)
  const timeout=await resolvePrintOrderRequest(adapter(db),config,requestId,worker,{}, {queryPayment:async()=>{throw new PortOnePrintPaymentError('payment_lookup_timeout',503,true)}})
  assert.equal(timeout.request.status,'WAITING_PROVIDER');assert.equal(timeout.request.replacementAllowed,false)
})

test('SDK-first ordering wins: fresh 404 cannot withdraw an issued invoice',async t=>{
  const {db,i}=await setup(t);await readyPackage(db,i)
  await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id])
  await create(db,i);await claim(db)
  assert.equal((await abort(db,i)).aborted,false)
  await db.exec("update private.print_order_requests set lease_owner=null,lease_until=null")
  const r=await resolvePrintOrderRequest(adapter(db),config,requestId,worker,{}, {queryPayment:async()=>{throw new PortOnePrintPaymentError('payment_not_found',404,true)}})
  assert.equal(r.request.status,'WAITING_PROVIDER');assert.equal(r.request.replacementAllowed,false)
  assert.equal((await db.query('select count(*)::integer n from private.print_pre_sdk_aborts')).rows[0].n,0)
  const stored=(await db.query('select sdk_issued_at,payment_receipt,status from private.print_checkout_intents where id=$1',[i.id])).rows[0]
  assert.ok(stored.sdk_issued_at);assert.equal(stored.status,'PREPARED');assert.equal(stored.payment_receipt,null)
})

test('cancellation-first ordering wins atomically: simultaneous SDK authorization sees hold, and aborted ledger/label are immutable',async t=>{
  const {db,i}=await setup(t);await readyPackage(db,i)
  const [cancel,sdk]=await Promise.allSettled([create(db,i),db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id])])
  assert.equal(cancel.status,'fulfilled');assert.equal(sdk.status,'rejected');assert.match(sdk.reason.message,/print_files_not_ready/)
  await claim(db);assert.equal((await abort(db,i)).aborted,true)
  const retry=await abort(db,i);assert.equal(retry.aborted,true);assert.equal(retry.request.replacementAllowed,true)
  await assert.rejects(db.query('update orders set print_preparation_aborted_at=null where order_id=$1',[i.order_id]),/print_pre_sdk_abort_immutable/)
  const privileges=(await db.query("select has_table_privilege('service_role','private.print_pre_sdk_aborts','UPDATE') update_allowed,has_table_privilege('service_role','private.print_pre_sdk_aborts','DELETE') delete_allowed")).rows[0]
  assert.equal(privileges.update_allowed,false);assert.equal(privileges.delete_allowed,false)
  await db.exec('set role service_role')
  await assert.rejects(db.query("update private.print_pre_sdk_aborts set pg_absence_observation='{}' where intent_id=$1",[i.id]),/permission denied/)
})

test('unexpected later LIVE money remains original PAID evidence and operator review, revokes replacement proof, and never submits',async t=>{
  const {db,i}=await setup(t);await create(db,i);await claim(db);assert.equal((await abort(db,i)).aborted,true)
  const checks=(await db.query('select claim_production_print_payment_rechecks(3) x')).rows[0].x
  assert.equal(checks.some(x=>x.payment_id===i.payment_id),true)
  const paid=await commit(db,i);assert.equal(paid.status,'PAID');assert.equal(paid.payment_receipt.paymentId,i.payment_id)
  const latest=await request(db);assert.equal(latest.resolution,'PRE_SDK_ABORTED');assert.equal(latest.preSdkAbortVerified,false);assert.equal(latest.replacementAllowed,false)
  const order=(await db.query('select * from orders where order_id=$1',[i.order_id])).rows[0]
  assert.equal(order.status,'PAYMENT_COMPLETED');assert.equal(order.print_requires_action,true);assert.equal(order.print_customer_request_hold,true);assert.ok(order.print_preparation_aborted_at)
  assert.equal(order.verified_payment_id,i.payment_id);assert.equal(order.payment_reversed_at,null)
  assert.equal((await db.query('select count(*)::integer n from private.print_fulfillment_outbox')).rows[0].n,0)
})

test('an outbox row or unproven public cancellation label cannot bypass the abort gate',async t=>{
  const {db,i}=await setup(t)
  await assert.rejects(db.query('update orders set print_preparation_aborted_at=now() where order_id=$1',[i.order_id]),/print_pre_sdk_abort_proof_required/)
  await create(db,i);await claim(db)
  await db.query("insert into private.print_fulfillment_outbox(order_id,event_type,state,payload) values($1,'SUBMIT','PENDING','{}')",[i.order_id])
  assert.equal((await abort(db,i)).aborted,false)
  assert.equal((await db.query('select count(*)::integer n from private.print_pre_sdk_aborts')).rows[0].n,0)
  for(const role of['anon','authenticated'])assert.equal((await db.query("select has_function_privilege($1,'public.abort_print_pre_sdk_request(uuid,uuid,jsonb)','EXECUTE') x",[role])).rows[0].x,false)
})

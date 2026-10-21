// Isolated PostgreSQL + fake Storage only. Never deletes a real file.
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { createPrintFileRetentionAdminHandler, createPrintFileRetentionWorkerHandler, printFileRetentionSignedPayload, validatedPrintRetentionPaths } from '../../supabase/functions/_shared/print-file-retention.ts'
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite')
const sql=readFileSync(new URL('../../supabase/migrations/20261018183844_print_file_retention_preparation.sql',import.meta.url),'utf8')
const admin='11111111-1111-4111-8111-111111111111',customer='22222222-2222-4222-8222-222222222222',owner='33333333-3333-4333-8333-333333333333'
const intent='44444444-4444-4444-8444-444444444444',packageId='55555555-5555-4555-8555-555555555555',orderId='ordp_66666666-6666-4666-8666-666666666666',nonce='77777777-7777-4777-8777-777777777777'
const paths=['cover.pdf','interior.pdf','manifest.json'].map(n=>`${orderId}/${packageId}/${n}`)
async function fixture(){
 const db=new PGlite();await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema private;create schema auth;
 create table auth.users(id uuid primary key,raw_app_meta_data jsonb);
 insert into auth.users values('${admin}','{"role":"admin"}'),('${customer}','{"role":"customer"}');
 create table public.orders(order_id text primary key,checkout_flow text,payment_environment text,status text,shipped_at timestamptz,payment_reversed_at timestamptz,
 print_customer_request_hold boolean default false,print_requires_action boolean default false,print_vendor text,print_vendor_order_id text,print_upload_id uuid,print_cover_pdf_path text,print_interior_pdf_path text);
 create table private.print_checkout_intents(id uuid primary key,order_id text,prepayment_package_id uuid,status text,verified_at timestamptz,payment_receipt jsonb,print_file_source text);
 create table private.print_prepayment_packages(id uuid primary key,intent_id uuid,state text,verified_at timestamptz,cover_path text,interior_path text,manifest_path text,file_parts jsonb);
 create table private.print_order_requests(order_id text,status text);
 create table private.print_fulfillment_outbox(order_id text,state text,event_type text);
 grant usage on schema public,private,auth to service_role;grant select on auth.users,public.orders,private.print_checkout_intents,private.print_prepayment_packages,private.print_order_requests,private.print_fulfillment_outbox to service_role;grant update on public.orders to service_role;
 insert into orders(order_id,checkout_flow,payment_environment,status,shipped_at,print_vendor,print_vendor_order_id,print_upload_id,print_cover_pdf_path,print_interior_pdf_path)
 values('${orderId}','PORTONE_V2_V1','live','SHIPPING',now()-interval '130 days','REDPRINTING','SFO_${intent.replaceAll('-','')}','${packageId}','${paths[0]}','${paths[1]}');
 insert into private.print_checkout_intents values('${intent}','${orderId}','${packageId}','PAID',now()-interval '140 days','{"status":"PAID","isTest":false}','APP_UPLOADED');
 insert into private.print_prepayment_packages values('${packageId}','${intent}','READY',now()-interval '140 days','${paths[0]}','${paths[1]}','${paths[2]}','{}');`)
 await db.exec(sql);return db
}
const query=async(db,name,args=[]) => (await db.query(`select ${name}(${args.map((_,i)=>`$${i+1}`).join(',')}) q`,args)).rows[0].q
const eligible=db=>query(db,'private.print_file_retention_eligible',[orderId])
const manage=(db,action,note='Synthetic file retention decision',actor=admin)=>query(db,'manage_print_file_retention',[actor,action,action==='overview'?null:orderId,action==='overview'?null:note])
const claim=db=>query(db,'claim_print_file_retention',[owner])

test('default preparation has zero claims and overview/hold do not mutate orders or enable sales',async t=>{
 const db=await fixture();t.after(()=>db.close());assert.equal(await eligible(db),true)
 const before=(await db.query('select * from orders')).rows
 assert.equal((await manage(db,'overview')).enabled,false);assert.equal((await manage(db,'overview')).eligibleCount,1)
 await db.exec('set role service_role');assert.deepEqual(await claim(db),{})
 await manage(db,'hold');assert.equal(await eligible(db),false);await manage(db,'release');assert.equal(await eligible(db),true)
 assert.deepEqual((await db.query('select * from orders')).rows,before)
 await assert.rejects(manage(db,'hold','Test customer spoof',customer),/forbidden/)
 await db.exec('reset role;set role authenticated');await assert.rejects(claim(db),/permission denied/)
})
test('120-day confirmed shipment requires paid production and coherent scoped package',async t=>{
 const db=await fixture();t.after(()=>db.close())
 for(const mutation of ["shipped_at=now()-interval '119 days'","shipped_at=null","status='IN_PRODUCTION'","payment_environment='test'","print_customer_request_hold=true","print_requires_action=true","print_vendor_order_id='wrong'","print_interior_pdf_path='album-assets/original.jpg'","payment_reversed_at=now()"]){
  await db.exec('begin');await db.exec(`update orders set ${mutation}`);assert.equal(await eligible(db),false,mutation);await db.exec('rollback')
 }
 await db.exec(`update private.print_checkout_intents set payment_receipt='{"status":"PAID","isTest":true}'`);assert.equal(await eligible(db),false)
})
test('unresolved customer requests and uncertain/active supplier work stop retention',async t=>{
 const db=await fixture();t.after(()=>db.close())
 await db.exec(`insert into private.print_order_requests values('${orderId}','REVIEW_REQUIRED')`);assert.equal(await eligible(db),false)
 await db.exec(`update private.print_order_requests set status='COMPLETED'`);assert.equal(await eligible(db),true)
 for(const [state,event]of [['UNKNOWN','POLL'],['CLAIMED','POLL'],['PENDING','CONFIRM'],['PENDING','SUBMIT']]){
  await db.exec('begin');await db.query('insert into private.print_fulfillment_outbox values($1,$2,$3)',[orderId,state,event]);assert.equal(await eligible(db),false);await db.exec('rollback')
 }
})
test('enabled claims lease one package, recheck holds, retry idempotently and audit removal without deleting trade or source records',async t=>{
 const db=await fixture();t.after(()=>db.close());await db.exec('update private.print_file_retention_settings set enabled=true;set role service_role')
 const first=await claim(db);assert.equal(first.orderId,orderId);assert.deepEqual(first.paths,paths);assert.deepEqual(await claim(db),{})
 await assert.rejects(manage(db,'hold'),/retention_removal_in_progress/)
 assert.equal(await query(db,'authorize_print_file_retention_removal',[orderId,owner]),true)
 await db.exec('reset role');await db.query('insert into private.print_order_requests values($1,$2)',[orderId,'REQUESTED']);await db.exec('set role service_role')
 assert.equal(await query(db,'authorize_print_file_retention_removal',[orderId,owner]),false)
 await query(db,'finish_print_file_retention',[orderId,owner,false]);await db.exec("reset role;update private.print_order_requests set status='COMPLETED';set role service_role")
 await claim(db);await query(db,'finish_print_file_retention',[orderId,owner,true]);assert.equal(await eligible(db),false);assert.deepEqual(await claim(db),{})
 assert.equal((await db.query('select count(*) n from orders')).rows[0].n,1)
 assert.equal((await db.query('select count(*) n from private.print_prepayment_packages')).rows[0].n,1)
 assert.deepEqual((await db.query('select action from private.print_file_retention_audit order by id')).rows.map(r=>r.action),['CLAIM','RETRY','CLAIM','REMOVED'])
})

test('path validation rejects original assets, cross-order packages, traversal and unbounded parts',()=>{
 const valid={orderId,packageId,owner,paths};assert.deepEqual(validatedPrintRetentionPaths(valid,owner),paths)
 for(const bad of [['album-assets/original.jpg',...paths], [...paths,`${orderId}/${packageId}/../secret`], [...paths,`${orderId}/${packageId}/interior/part-032.bin`], [...paths,paths[0]],paths.slice(1)])
  assert.equal(validatedPrintRetentionPaths({...valid,paths:bad},owner),null)
 assert.equal(validatedPrintRetentionPaths({...valid,owner:customer},owner),null)
 assert.ok(validatedPrintRetentionPaths({...valid,paths:[...paths,`${orderId}/${packageId}/interior/part-031.bin`]},owner))
})
const secret='a'.repeat(64),now=Date.now()
async function signed({prefix='snapfit-print-file-retention:v1',body='{}',signedAt=Math.floor(now/1000)}={}){
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign'])
 const message=prefix==='snapfit-print-file-retention:v1'?printFileRetentionSignedPayload(signedAt,nonce):`${prefix}\n${signedAt}\n${nonce}\n{}`
 const signature=Buffer.from(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(message))).toString('hex')
 return new Request('https://example.invalid/retention',{method:'POST',headers:{'X-Snapfit-Retention-Timestamp':String(signedAt),'X-Snapfit-Retention-Nonce':nonce,'X-Snapfit-Retention-Signature':signature},body})
}
function worker({enabled=true,allowed=true,consumed=true,badClaim=false,remove=true,batchSize=1,clock=()=>now}={}){
 const calls=[];let claims=0;const db={async rpc(name,p){calls.push({name,p});let claim={};
  if(name==='claim_print_file_retention'&&claims++<batchSize){const id=claims===1?orderId:`ordp_00000000-0000-4000-8000-${String(claims).padStart(12,'0')}`;claim={orderId:id,packageId,owner,paths:badClaim?['album-assets/original.jpg']:paths.map(path=>path.replace(orderId,id))}}
  return{data:name==='consume_print_order_scheduler_nonce'?consumed:name==='claim_print_file_retention'?claim:name==='authorize_print_file_retention_removal'?allowed:true,error:null}}}
 const handler=createPrintFileRetentionWorkerHandler({secret:()=>secret,enabled:()=>enabled,now:clock,randomUUID:()=>owner,createAdminDatabase:()=>db,removeFiles:async(_,p)=>{calls.push({remove:p});return remove}})
 return{handler,calls}
}
test('worker rejects scheduler-domain signatures, stale signatures and altered request bodies before database access',async()=>{
 for(const input of [{prefix:'snapfit-print-order-scheduler:v1'},{signedAt:Math.floor(now/1000)-121},{body:'{"action":"delete"}'}]){
  const w=worker();assert.equal((await w.handler(await signed(input))).status,401);assert.equal(w.calls.length,0)
 }
})
test('runtime default off and replayed nonces cannot claim or remove any package',async()=>{
 const off=worker({enabled:false});assert.equal((await off.handler(await signed())).status,200);assert.equal(off.calls.length,1)
 const replay=worker({consumed:false});assert.equal((await replay.handler(await signed())).status,401);assert.equal(replay.calls.length,1)
})
test('worker uses recheck and narrowly scoped fake Storage removal then records success',async()=>{
 const w=worker();const response=await w.handler(await signed());assert.equal(response.status,200);assert.equal((await response.json()).removed,1)
 assert.deepEqual(w.calls.find(x=>x.remove).remove,paths);assert.equal(w.calls.findLast(c=>c.name==='finish_print_file_retention').p.p_removed,true)
 for(const options of [{allowed:false},{remove:false}]){const retry=worker(options);await retry.handler(await signed());assert.equal(retry.calls.findLast(c=>c.name==='finish_print_file_retention').p.p_removed,false);assert.equal(retry.calls.filter(c=>c.name==='claim_print_file_retention').length,1);if(options.allowed===false)assert.equal(retry.calls.some(c=>c.remove),false)}
 const bad=worker({badClaim:true});assert.equal((await bad.handler(await signed())).status,503);assert.equal(bad.calls.some(c=>c.remove),false)
})
test('retention admin requires verified app role and never accepts enabling or deletion actions',async()=>{
 for(const [metadata,status]of [[{role:'customer'},403],[{},403]]){
  let db=false;const handler=createPrintFileRetentionAdminHandler({getUser:async()=>({id:admin,app_metadata:metadata,user_metadata:{role:'admin'}}),createAdminDatabase:()=>{db=true;throw Error()}})
  assert.equal((await handler(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer test'},body:'{"action":"overview"}'}))).status,status);assert.equal(db,false)
 }
 const handler=createPrintFileRetentionAdminHandler({getUser:async()=>({id:admin,app_metadata:{role:'admin'}}),createAdminDatabase:()=>{throw Error('No mutation permitted')}})
 for(const action of ['delete','enable','run'])assert.equal((await handler(new Request('https://example.invalid',{method:'POST',headers:{authorization:'Bearer test'},body:JSON.stringify({action})}))).status,400)
})

test('retention migration composes with the existing full production checkout and chunked PDF schema',async t=>{
 const {fixture:existingFixture}=await import('./fixtures/app_pdf_database.mjs')
 const db=await existingFixture(false);t.after(()=>db.close())
 await db.exec('alter table auth.users add column raw_app_meta_data jsonb')
 await db.query('update auth.users set raw_app_meta_data=$1 where id=$2',[{role:'admin'},admin])
 await db.exec(readFileSync(new URL('../../supabase/migrations/20261015021421_chunked_original_print_pdfs.sql',import.meta.url),'utf8'))
 await db.exec(sql)
 const result=await manage(db,'overview');assert.equal(result.enabled,false);assert.equal(result.eligibleCount,0)
 assert.deepEqual(await claim(db),{})
 const sales=(await db.query('select * from private.print_sales_configuration')).rows[0]
 assert.equal(sales.enabled,false);assert.equal(sales.environment,'disabled')
 assert.equal((await db.query('select count(*) n from orders')).rows[0].n,0)
})


test('worker bounds batches at five and stops before the shared request deadline',async()=>{
 const batch=worker({batchSize:10});const result=await (await batch.handler(await signed())).json();assert.equal(result.removed,5)
 assert.equal(batch.calls.filter(c=>c.remove).length,5);assert.equal(batch.calls.filter(c=>c.name==='claim_print_file_retention').length,5)
 let ticks=0;const deadline=worker({batchSize:10,clock:()=>now+(ticks++===0?0:30000)})
 assert.equal((await (await deadline.handler(await signed())).json()).removed,0);assert.equal(deadline.calls.some(c=>c.remove),false)
})

test('cadence roll-forward changes only the prepared job and forces it inactive',async t=>{
 const db=await fixture();t.after(()=>db.close());await db.exec(`create schema cron;
  create table cron.job(jobid bigint,jobname text,username text,schedule text,active boolean);
  insert into cron.job values(1,'snapfit-print-file-retention',current_user,'17 19 * * *',true),(2,'another-job',current_user,'* * * * *',true);
  create function cron.alter_job(job_id bigint,schedule text default null,command text default null,database text default null,username text default null,active boolean default null)
   returns void language sql as $$update cron.job j set schedule=coalesce($2,j.schedule),active=coalesce($6,j.active) where jobid=$1$$;`)
 const cadence=readFileSync(new URL('../../supabase/migrations/20261018184546_print_retention_bounded_hourly_batch.sql',import.meta.url),'utf8')
 await db.exec(cadence);const rows=(await db.query('select * from cron.job order by jobid')).rows
 assert.equal(rows[0].schedule,'17 * * * *');assert.equal(rows[0].active,false);assert.equal(rows[1].schedule,'* * * * *');assert.equal(rows[1].active,true)
 assert.equal((await manage(db,'overview')).enabled,false)
 await db.exec("begin;delete from cron.job where jobid=1");await assert.rejects(db.exec(cadence),/retention_job_missing/);await db.exec('rollback')
})

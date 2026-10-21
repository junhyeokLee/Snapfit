import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createHmac} from 'node:crypto';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const read=n=>readFileSync(new URL('../../supabase/migrations/'+n,import.meta.url),'utf8');
const jobs=read('20261020144824_ai_template_free_resumable_jobs.sql');
const cron=read('20261020144841_ai_template_free_worker_cron.sql');
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',free='33333333-3333-4333-8333-333333333333';
let serial=0;const request=()=>`00000000-0000-4000-8000-${String(++serial).padStart(12,'0')}`;
const safe={version:1,topic:'travel',mood:'editorial',palette:'neutral',density:'balanced',pageCount:20,aspect:'square',printProduct:{id:'REDP_200_SOFT',trimWidthMm:200,trimHeightMm:200}};
async function fixture(enabled=true){
 const db=new PGlite();await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create schema private;create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function public.is_admin() returns boolean language sql stable as $$select false$$;
 create function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
 grant usage on schema auth to authenticated,service_role;
 insert into auth.users values('${user}'),('${other}'),('${free}');`);
 await db.exec(read('20260905113000_ai_album_points.sql'));
 await db.exec(`create function public.ai_album_draft_point_cost() returns integer language sql stable as $$select 700$$;
 insert into public.point_wallets(user_id,balance) values('${user}',10000),('${other}',10000),('${free}',0);
 insert into public.ai_album_free_draft_claims(user_id,draft_id) values('${user}','prior-free'),('${other}','prior-free');
 grant select,insert,update,delete on all tables in schema public to service_role;
 grant usage,select on all sequences in schema public to service_role;`);
 await db.exec(read('20261018192705_ai_template_generation_billing_guard.sql'));
 await db.exec(read('20261019130000_ai_template_page_cost.sql'));
 await db.exec(jobs);
 if(enabled)await db.exec('update private.ai_template_generation_policy set free_jobs_enabled=true');
 return db;
}
async function role(db,name,work){await db.exec('set role '+name);try{return await work();}finally{await db.exec('reset role');}}
async function rpc(db,name,params=[]){return role(db,'service_role',async()=>(await db.query(`select public.${name}(${params.map((_,i)=>'$'+(i+1)).join(',')}) x`,params)).rows[0].x);}
const prepare=(db,actor=user,id=request(),options=safe,cost=500,hash='a'.repeat(64))=>rpc(db,'prepare_free_ai_template_job',[actor,id,hash,options,cost,options.pageCount]);
const claim=db=>rpc(db,'claim_free_ai_template_job');
const save=(db,j,checkpoint={version:2,identity:'a'.repeat(64),responses:[{fingerprint:'b'.repeat(64),output:{synthetic:true}}]})=>rpc(db,'save_free_ai_template_checkpoint',[j.id,j.leaseOwner,checkpoint,'composition']);
const result=j=>({draftId:j.draftId,requiresUserReview:true,alreadyCreatedAlbum:false,title:'Synthetic contract output'});
const settle=(db,j,state='ready',stage='complete',delay=65,error=null,output=state==='ready'?result(j):null)=>rpc(db,'settle_free_ai_template_job',[j.id,j.leaseOwner,state,stage,delay,error,output]);
const unlock=db=>db.exec("update private.ai_template_free_runtime set next_start_at=now()-interval '1 second',cooldown_until=now()-interval '1 second',lease_owner=null,lease_until=null");
async function consume(db,j,actor=user){await db.query("select set_config('request.jwt.claim.sub',$1,false)",[actor]);return role(db,'authenticated',async()=>(await db.query('select * from record_ai_album_draft_success($1)',[j.draftId])).rows[0]);}

test('activation is closed by default, structured options and exact physical product are mandatory',async t=>{
 const db=await fixture(false);t.after(()=>db.close());
 assert.equal((await db.query('select v3_enabled from private.ai_template_generation_policy')).rows[0].v3_enabled,false);
 await assert.rejects(prepare(db),/ai_generation_disabled/);await db.exec('update private.ai_template_generation_policy set free_jobs_enabled=true');
 for(const options of [{...safe,prompt:'private story'},{...safe,topic:'private'}, {...safe,topic:null}, {...safe,pageCount:21},
   {...safe,printProduct:{...safe.printProduct,private:'hidden'}},{...safe,printProduct:{...safe.printProduct,trimWidthMm:201}},{...safe,aspect:'portrait'}])
   await assert.rejects(prepare(db,user,request(),options),/ai_generation_invalid_request/);
 for(const key of Object.keys(safe))await assert.rejects(prepare(db,user,request(),{...safe,[key]:null}),/ai_generation_invalid_request/);
 for(const key of Object.keys(safe.printProduct))await assert.rejects(prepare(db,user,request(),{...safe,printProduct:{...safe.printProduct,[key]:null}}),/ai_generation_invalid_request/);
 for(const options of [null,[],false,'arbitrary'])await assert.rejects(rpc(db,'prepare_free_ai_template_job',[user,request(),'a'.repeat(64),options===null?null:JSON.stringify(options),500,20]),/ai_generation_invalid_request/);
 await assert.rejects(rpc(db,'prepare_free_ai_template_job',[user,request(),'a'.repeat(64),'null',500,20]),/ai_generation_invalid_request/);
 await assert.rejects(prepare(db,user,request(),safe,null),/price_confirmation_required/);
 await assert.rejects(prepare(db,user,request(),safe,0),/price_changed/);
 assert.equal((await db.query('select count(*)::int n from private.ai_template_generation_intents')).rows[0].n,0);
});
test('same pending request polls without new admission, owner isolation and seven-day expiry are fixed',async t=>{
 const db=await fixture();t.after(()=>db.close());const id=request(),first=await prepare(db,user,id);
 assert.equal(first.job.id,id);assert.equal(first.job.state,'queued');assert.deepEqual(first.job.safeDesign,safe);
 assert.deepEqual(await prepare(db,user,id),first);
 await assert.rejects(prepare(db,user,id,safe,500,'b'.repeat(64)),/request_conflict/);
 await assert.rejects(prepare(db),/in_progress/);
 assert.equal(await rpc(db,'read_free_ai_template_job',[other,id]),null);
 assert.equal(await rpc(db,'cancel_free_ai_template_job',[other,id]),null);
 const row=(await db.query('select lease_expires_at=expires_at same,expires_at-created_at duration from private.ai_template_generation_intents')).rows[0];
 assert.equal(row.same,true);assert.match(String(row.duration),/7/);
 assert.equal((await db.query('select count(*)::int n from private.ai_template_generation_intents')).rows[0].n,1);
 assert.equal((await db.query('select balance from point_wallets where user_id=$1',[user])).rows[0].balance,10000);
});
test('waiting does not consume capacity: more than four users can queue, one runs and global cooldown is exposed',async t=>{
 const db=await fixture();t.after(()=>db.close());
 for(let i=10;i<16;i++){const actor=`99999999-9999-4999-8999-${String(i).padStart(12,'0')}`;await db.query('insert into auth.users values($1)',[actor]);await prepare(db,actor,request(),safe,0);}
 assert.equal((await db.query('select count(*)::int n from private.ai_template_free_jobs')).rows[0].n,6);
 const first=await claim(db);assert.ok(first);assert.equal(await claim(db),null);
 await save(db,first);await settle(db,first,'waiting','composition',7200,'template_provider_rate_limited');
 assert.equal(await claim(db),null);
 const status=await rpc(db,'read_free_ai_template_job',[first.actor,first.requestId]);
 assert.equal(status.job.state,'waiting');assert.equal(status.job.completedStages,1);
 assert.ok(Date.parse(status.job.nextAttemptAt)>Date.now()+7100_000);
 assert.equal((await db.query('select status from private.ai_template_generation_intents where id=$1',[first.id])).rows[0].status,'GENERATING');
});
test('a DST-safe daily cooldown over 24 hours is retained and stage survives a crash',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db);const j=await claim(db);await save(db,j);
 await settle(db,j,'waiting','composition',90120,'template_provider_rate_limited');
 const status=await rpc(db,'read_free_ai_template_job',[user,j.requestId]);assert.ok(Date.parse(status.job.nextAttemptAt)>Date.now()+90000_000);
 await unlock(db);await db.exec("update private.ai_template_free_jobs set next_attempt_at=now()-interval '1 second'");
 const next=await claim(db);assert.equal(next.stage,'composition');
});
test('crash recovery fences old saves/completion and preserves accepted checkpoint',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db);const old=await claim(db);await save(db,old);
 await unlock(db);assert.equal(await claim(db),null);
 await db.exec("update private.ai_template_free_jobs set lease_until=now()-interval '1 second'");
 const current=await claim(db);assert.equal(current.id,old.id);assert.notEqual(current.leaseOwner,old.leaseOwner);assert.equal(current.attempts,2);assert.equal(current.checkpoint.responses.length,1);
 await assert.rejects(save(db,old),/lease_lost/);await assert.rejects(settle(db,old),/lease_lost/);
 await settle(db,current,'queued','review',65);assert.equal(await claim(db),null);
});
test('65-second pacing survives fast success and the bounded claim budget ends without charging',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db);const j=await claim(db);
 const runtime=(await db.query('select extract(epoch from(next_start_at-now()))::integer seconds from private.ai_template_free_runtime')).rows[0];assert.ok(runtime.seconds>=64);
 await save(db,j);await settle(db,j,'queued','composition',0);assert.equal(await claim(db),null);
 await unlock(db);await db.exec("update private.ai_template_free_jobs set attempts=100,next_attempt_at=now()-interval '1 second'");
 assert.equal(await claim(db),null);const ended=await rpc(db,'read_free_ai_template_job',[user,j.requestId]);assert.equal(ended.job.state,'failed');assert.equal(ended.job.error,'ai_generation_attempts_exhausted');
 assert.equal((await db.query('select checkpoint from private.ai_template_free_jobs')).rows[0].checkpoint,null);
 assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n,0);
});
test('only validated completion becomes READY; consumed recovery reuses the same draft and charges exactly once',async t=>{
 const db=await fixture();t.after(()=>db.close());const id=request();await prepare(db,user,id);const j=await claim(db);
 await assert.rejects(settle(db,j,'ready','review'),/invalid_result/);
 await assert.rejects(settle(db,j,'ready','complete',65,null,{...result(j),draftId:'forged'}),/invalid_result/);
 await settle(db,j);const ready=await rpc(db,'read_free_ai_template_job',[user,id]);assert.equal(ready.job.state,'ready');assert.equal(ready.draft.draftId,j.draftId);
 await assert.rejects(consume(db,j,other),/not_reviewable/);
 assert.equal((await consume(db,j)).charged_points,500);assert.equal((await consume(db,j)).charged_points,500);
 assert.equal((await db.query('select balance from point_wallets where user_id=$1',[user])).rows[0].balance,9500);
 const used=await rpc(db,'read_free_ai_template_job',[user,id]);assert.equal(used.job.state,'consumed');assert.equal(used.job.alreadyAccepted,true);assert.equal(used.draft.draftId,j.draftId);
 assert.equal((await rpc(db,'cancel_free_ai_template_job',[user,id])).job.state,'consumed');
 assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n,1);
});
test('accept/cancel/new-admission orderings preserve one charge, and settlement locks the actor before either row',async t=>{
 const source=jobs.slice(jobs.indexOf('create function public.settle_free_ai_template_job'),jobs.indexOf('create function public.consume_free_ai_template_worker_nonce'));
 assert.ok(source.indexOf("hashtextextended('snapfit:ai-user:'||actor::text,0)")<source.indexOf('for update'));
 for(const acceptFirst of [true,false]){
   const db=await fixture();try{
     const id=request();await prepare(db,user,id);const j=await claim(db);
     await assert.rejects(consume(db,j),/not_reviewable/);await settle(db,j);
     if(acceptFirst){await consume(db,j);assert.equal((await rpc(db,'cancel_free_ai_template_job',[user,id])).job.state,'consumed');assert.equal((await consume(db,j)).charged_points,500);}
     else{await rpc(db,'cancel_free_ai_template_job',[user,id]);await assert.rejects(consume(db,j),/not_reviewable/);}
     await prepare(db);
     assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n,acceptFirst?1:0);
     assert.equal((await db.query('select balance from point_wallets where user_id=$1',[user])).rows[0].balance,acceptFirst?9500:10000);
   }finally{await db.close();}
 }
});
test('cancellation, failures and waiting never consume first-free; claiming after free status changed never silently charges',async t=>{
 const db=await fixture();t.after(()=>db.close());const id=request();await prepare(db,free,id,safe,0);const j=await claim(db);await save(db,j);
 const canceled=await rpc(db,'cancel_free_ai_template_job',[free,id]);assert.equal(canceled.job.state,'canceled');
 assert.equal(await claim(db),null);assert.equal((await db.query('select lease_owner from private.ai_template_free_runtime')).rows[0].lease_owner,j.leaseOwner);
 await assert.rejects(settle(db,j),/lease_lost/);assert.equal((await db.query('select count(*)::int n from ai_album_free_draft_claims where user_id=$1',[free])).rows[0].n,0);
 const next=request();await prepare(db,free,next,safe,0);await unlock(db);const second=await claim(db);await settle(db,second);
 await db.query('insert into ai_album_free_draft_claims values($1,$2,now())',[free,'synthetic-other-flow']);
 await assert.rejects(consume(db,second,free),/free_credit_changed/);
 assert.equal((await db.query('select balance from point_wallets where user_id=$1',[free])).rows[0].balance,0);
});
test('terminal generation failure preserves first-free and a later accepted free job consumes it once',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db,free,request(),safe,0);const bad=await claim(db);await save(db,bad);await settle(db,bad,'failed','composition',65,'template_quality_failed');
 assert.equal((await db.query('select count(*)::int n from ai_album_free_draft_claims where user_id=$1',[free])).rows[0].n,0);
 await prepare(db,free,request(),safe,0);await unlock(db);const good=await claim(db);await settle(db,good);
 const accepted=await consume(db,good,free);assert.equal(accepted.used_free_credit,true);assert.equal(accepted.charged_points,0);assert.deepEqual(await consume(db,good,free),accepted);
 assert.equal((await db.query('select count(*)::int n from ai_album_free_draft_claims where user_id=$1',[free])).rows[0].n,1);
 assert.equal((await db.query('select count(*)::int n from point_ledger')).rows[0].n,1);
});
test('new admission invalidates old READY; expiry and attempt budget cannot resurrect it',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db);const first=await claim(db);await settle(db,first);const next=await prepare(db);
 await assert.rejects(consume(db,first),/not_reviewable/);const prior=await rpc(db,'read_free_ai_template_job',[user,first.requestId]);assert.equal(prior.job.state,'failed');assert.equal(Object.hasOwn(prior,'draft'),false);
 await db.exec("update private.ai_template_free_jobs set expires_at=now()-interval '1 second' where state='queued'");
 const expired=await rpc(db,'read_free_ai_template_job',[user,next.job.id]);assert.equal(expired.job.state,'failed');
 assert.equal((await db.query('select status from private.ai_template_generation_intents where request_id=$1',[next.job.id])).rows[0].status,'EXPIRED');
 await unlock(db);assert.equal(await claim(db),null);
});
test('checkpoint bound and service-only permissions protect every read/write/nonce boundary',async t=>{
 const db=await fixture();t.after(()=>db.close());await prepare(db);const j=await claim(db);
 await assert.rejects(save(db,j,{responses:[] ,large:'x'.repeat(2100000)}),/invalid_checkpoint/);
 for(const name of ['anon','authenticated']){
   await assert.rejects(role(db,name,()=>db.query('select public.read_free_ai_template_job($1)',[user])),/permission denied/);
   for(const table of ['ai_template_free_jobs','ai_template_free_runtime','ai_template_free_worker_nonces'])
     await assert.rejects(role(db,name,()=>db.exec('select * from private.'+table)),/permission denied/);
   for(const fn of ['prepare_free_ai_template_job(uuid,uuid,text,jsonb,integer,integer)','read_free_ai_template_job(uuid,uuid)','cancel_free_ai_template_job(uuid,uuid)',
     'claim_free_ai_template_job()','save_free_ai_template_checkpoint(uuid,uuid,jsonb,text)','settle_free_ai_template_job(uuid,uuid,text,text,integer,text,jsonb)','consume_free_ai_template_worker_nonce(uuid,bigint)'])
     assert.equal((await db.query('select has_function_privilege($1,$2,\'EXECUTE\') ok',[name,'public.'+fn])).rows[0].ok,false);
 }
 const nonce=request(),timestamp=Math.floor(Date.now()/1000);await db.query("insert into private.ai_template_free_worker_nonces values($1,$2,now()+interval '5 minutes',null)",[nonce,timestamp]);
 assert.equal(await rpc(db,'consume_free_ai_template_worker_nonce',[nonce,timestamp+1]),false);
 assert.equal(await rpc(db,'consume_free_ai_template_worker_nonce',[nonce,timestamp]),true);
 assert.equal(await rpc(db,'consume_free_ai_template_worker_nonce',[nonce,timestamp]),false);
});

async function cronFixture(){const db=await fixture();await db.exec(`
 create schema cron;create schema net;create schema vault;create schema extensions;
 create function extensions.hmac(data text,key text,kind text) returns bytea language plpgsql as $$
 declare material bytea:=convert_to(key,'UTF8');inner_pad bytea:=decode(repeat('00',64),'hex');outer_pad bytea:=inner_pad;idx integer;
 begin for idx in 0..63 loop inner_pad:=set_byte(inner_pad,idx,get_byte(material,idx)#54);outer_pad:=set_byte(outer_pad,idx,get_byte(material,idx)#92);end loop;
 return sha256(outer_pad||sha256(inner_pad||convert_to(data,'UTF8')));end;$$;
 create table cron.job(jobid bigserial primary key,jobname text,schedule text,command text,username text,active boolean,unique(jobname,username));
 create table cron.job_run_details(jobid bigint,end_time timestamptz);
 create function cron.schedule(job_name text,job_schedule text,job_command text) returns bigint language plpgsql as $$declare result bigint;begin
 insert into cron.job(jobname,schedule,command,username,active) values(job_name,job_schedule,job_command,current_user,true)
 on conflict(jobname,username) do update set schedule=excluded.schedule,command=excluded.command,active=true returning jobid into result;return result;end;$$;
 create function cron.alter_job(job_id bigint,active boolean default null) returns void language plpgsql as $$begin update cron.job set active=alter_job.active where jobid=job_id;end;$$;
 create table vault.secrets(name text primary key,value text);create view vault.decrypted_secrets as select name,value as decrypted_secret from vault.secrets;
 create table net.http_request_queue(id bigserial primary key,url text,headers jsonb,body jsonb,timeout_milliseconds integer);
 create function net.http_post(url text,body jsonb default '{}'::jsonb,params jsonb default '{}'::jsonb,headers jsonb default '{}'::jsonb,timeout_milliseconds integer default 2000)
 returns bigint language plpgsql as $$declare result bigint;begin insert into net.http_request_queue(url,body,headers,timeout_milliseconds) values(url,body,headers,timeout_milliseconds) returning id into result;return result;end;$$;
 grant usage on schema net to public;grant select on net.http_request_queue to public;
 select cron.schedule('snapfit-print-order-scheduler','*/2 * * * *','select 42');
 insert into pg_catalog.pg_extension(oid,extname,extowner,extnamespace,extrelocatable,extversion)
 select 200000+ordinality::integer,name,(select oid from pg_roles where rolname=current_user),'public'::regnamespace,true,'local-adapter'
 from unnest(array['pg_cron','pg_net','supabase_vault']) with ordinality as e(name,ordinality);`);
 await db.query('insert into vault.secrets values($1,$2),($3,$4)',['snapfit_ai_template_worker_secret','a'.repeat(64),'snapfit_ai_template_worker_project_url','https://rrbhxdtriummqpztpjrk.supabase.co']);return db;}
test('AI Cron is inactive on install, preserves print jobs, sends no empty/cooldown work and uses only one-use AI signatures',async t=>{
 const db=await cronFixture();t.after(()=>db.close());const prior=(await db.query('select * from cron.job')).rows[0];await db.exec(cron);await db.exec(cron);
 assert.deepEqual((await db.query('select * from cron.job where jobname=$1',[prior.jobname])).rows[0],prior);
 const own=(await db.query("select * from cron.job where jobname='snapfit-ai-template-worker'")).rows[0];assert.equal(own.active,false);assert.equal(own.schedule,'* * * * *');
 await db.exec(own.command);assert.equal((await db.query('select count(*)::int n from net.http_request_queue')).rows[0].n,0);
 await prepare(db);await db.exec(own.command);const sent=(await db.query('select * from net.http_request_queue')).rows[0];assert.deepEqual(sent.body,{});
 assert.equal(sent.url,'https://rrbhxdtriummqpztpjrk.supabase.co/functions/v1/ai-template-worker');assert.equal(sent.timeout_milliseconds,125000);
 const stamp=sent.headers['X-Snapfit-AI-Timestamp'],nonce=sent.headers['X-Snapfit-AI-Nonce'];assert.equal(sent.headers['X-Snapfit-AI-Signature'],createHmac('sha256','a'.repeat(64)).update(`snapfit-ai-template-worker:v1\n${stamp}\n${nonce}\n{}`).digest('hex'));
 assert.doesNotMatch(JSON.stringify(sent.headers),/a{64}|Secret|Bearer|eyJ/);assert.doesNotMatch(own.command,/PRINT_ORDER|snapfit_print_order|service_role|a{64}/);
 await db.exec("update private.ai_template_free_runtime set cooldown_until=now()+interval '1 hour'");await db.exec(own.command);
 assert.equal((await db.query('select count(*)::int n from net.http_request_queue')).rows[0].n,1);
 await db.exec('update private.ai_template_generation_policy set free_jobs_enabled=false');await unlock(db);await db.exec(own.command);
 assert.equal((await db.query('select count(*)::int n from net.http_request_queue')).rows[0].n,1);
 await db.exec("update private.ai_template_free_jobs set expires_at=now()-interval '1 second',checkpoint='{\"responses\":[]}'");await db.exec(own.command);
 assert.equal((await db.query('select checkpoint from private.ai_template_free_jobs')).rows[0].checkpoint,null);
 assert.equal((await db.query('select status from private.ai_template_generation_intents')).rows[0].status,'EXPIRED');
 assert.equal((await db.query('select count(*)::int n from net.http_request_queue')).rows[0].n,1);
});
test('AI Cron refuses wrong Vault values or another owner without changing existing jobs',async t=>{
 for(const sql of ["update vault.secrets set value='bad' where name='snapfit_ai_template_worker_secret'","update vault.secrets set value='https://other.invalid' where name='snapfit_ai_template_worker_project_url'"]){const db=await cronFixture();try{await db.exec(sql);await assert.rejects(db.exec(cron),/vault_configuration_required/);assert.equal((await db.query('select count(*)::int n from cron.job')).rows[0].n,1);}finally{await db.close();}}
 const db=await cronFixture();t.after(()=>db.close());await db.exec("insert into cron.job(jobname,username) values('snapfit-ai-template-worker','another-owner')");await assert.rejects(db.exec(cron),/owner_conflict/);
});

import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const read=name=>readFileSync(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',free='33333333-3333-4333-8333-333333333333';
const hash='a'.repeat(64),hash2='b'.repeat(64);
let serial=0;
const request=()=>`00000000-0000-4000-8000-${String(++serial).padStart(12,'0')}`;
async function fixture(){
 const db=new PGlite();await db.exec(`
 create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create schema private;
 create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function public.is_admin() returns boolean language sql stable as $$select false$$;
 create function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
 grant usage on schema auth to authenticated,service_role;
 insert into auth.users values('${user}'),('${other}'),('${free}');
 `);
 await db.exec(read('20260905113000_ai_album_points.sql'));
 await db.exec(`create function public.ai_album_draft_point_cost() returns integer language sql stable as $$select 700$$;
 insert into public.point_wallets(user_id,balance) values('${user}',10000),('${other}',10000),('${free}',0);
 insert into public.ai_album_free_draft_claims(user_id,draft_id) values('${user}','prior-free'),('${other}','other-free');
 insert into public.ai_album_draft_usages(user_id,draft_id,point_cost,used_free_credit) values('${user}','historical',300,false);
 grant select,insert,update,delete on all tables in schema public to service_role;
 grant usage,select on all sequences in schema public to service_role;
 `);
 await db.exec(read('20261018192705_ai_template_generation_billing_guard.sql'));return db;
}
async function asRole(db,role,callback){await db.exec('set role '+role);try{return await callback();}finally{await db.exec('reset role');}}
const prepare=(db,actor=user,key=request(),digest=hash)=>asRole(db,'service_role',async()=>(await db.query('select public.prepare_ai_template_generation($1,$2,$3) v',[actor,key,digest])).rows[0].v);
const result=r=>({draftId:r.draftId,requiresUserReview:true,alreadyCreatedAlbum:false,title:'contract only'});
const complete=(db,r,actor=user,output=result(r))=>asRole(db,'service_role',()=>db.query('select public.complete_ai_template_generation($1,$2,$3)',[actor,r.id,JSON.stringify(output)]));
const fail=(db,r,actor=user)=>asRole(db,'service_role',()=>db.query('select public.fail_ai_template_generation($1,$2)',[actor,r.id]));
async function consume(db,id,actor=user,cost=null){await db.query("select set_config('request.jwt.claim.sub',$1,false)",[actor]);return asRole(db,'authenticated',async()=>(await db.query('select * from public.record_ai_album_draft_success($1,$2)',[id,cost])).rows[0]);}
const balance=async(db,actor=user)=>(await db.query('select balance from public.point_wallets where user_id=$1',[actor])).rows[0].balance;

test('generated ownership and READY status are required; unknown, incomplete and cross-user drafts never charge',async()=>{
 const db=await fixture();try{
  await assert.rejects(consume(db,'forged'),/not_reviewable/);const r=await prepare(db);
  await assert.rejects(consume(db,r.draftId),/not_reviewable/);
  await assert.rejects(complete(db,r,other),/not_pending/);await complete(db,r);
  await assert.rejects(consume(db,r.draftId,other),/not_reviewable/);assert.equal(await balance(db),10000);
 }finally{await db.close();}
});
test('server price is authoritative, acceptance is idempotent and historical usage remains replayable',async()=>{
 const db=await fixture();try{
  const r=await prepare(db);await complete(db,r);
  await assert.rejects(consume(db,r.draftId,user,0),/price_mismatch/);assert.equal(await balance(db),10000);
  const accepted=await consume(db,r.draftId);assert.equal(accepted.charged_points,700);assert.equal(await balance(db),9300);
  assert.deepEqual(await consume(db,r.draftId),accepted);
  assert.equal((await db.query("select count(*)::int n from public.point_ledger where related_entity_id=$1",[r.draftId])).rows[0].n,1);
  const old=await consume(db,'historical',user,0);assert.equal(old.charged_points,300);assert.equal(await balance(db),9300);
 }finally{await db.close();}
});
test('failures do not consume free eligibility; only one accepted first-free credit is possible',async()=>{
 const db=await fixture();try{
  const bad=await prepare(db,free);await fail(db,bad,free);
  assert.equal((await db.query('select count(*)::int n from public.ai_album_free_draft_claims where user_id=$1',[free])).rows[0].n,0);
  const good=await prepare(db,free);await complete(db,good,free);
  const accepted=await consume(db,good.draftId,free);assert.equal(accepted.used_free_credit,true);assert.equal(accepted.charged_points,0);
  await db.exec("update private.ai_template_generation_intents set created_at=created_at-interval '2 minutes' where user_id='"+free+"'");
  await assert.rejects(prepare(db,free),/insufficient_points/);
  assert.equal(await balance(db,free),0);
 }finally{await db.close();}
});
test('admission is idempotent, cached results replay without a model call, and changed-body key reuse fails',async()=>{
 const db=await fixture();try{
  const key=request(),r=await prepare(db,user,key);
  await assert.rejects(prepare(db,user,key),/in_progress/);
  await assert.rejects(prepare(db,user,key,hash2),/request_conflict/);
  await complete(db,r);const cached=await prepare(db,user,key);assert.deepEqual(cached.cached,result(r));
  assert.equal((await db.query('select count(*)::int n from private.ai_template_generation_intents')).rows[0].n,1);
  const next=await prepare(db);await assert.rejects(consume(db,r.draftId),/not_reviewable/);await fail(db,next);
 }finally{await db.close();}
});
test('free/point eligibility is rechecked atomically; late wallet spending cannot overdraw',async()=>{
 const db=await fixture();try{
  const r=await prepare(db);await complete(db,r);await db.exec(`update public.point_wallets set balance=10 where user_id='${user}'`);
  await assert.rejects(consume(db,r.draftId),/insufficient points/);assert.equal(await balance(db),10);
  const f=await prepare(db,free);await complete(db,f,free);await db.exec(`insert into public.ai_album_free_draft_claims(user_id,draft_id) values('${free}','external')`);
  await assert.rejects(consume(db,f.draftId,free),/free_credit_changed/);assert.equal(await balance(db,free),0);
 }finally{await db.close();}
});
test('rate, project budget, in-flight and kill-switch policies apply before model work',async()=>{
 const db=await fixture();try{
  const r=await prepare(db);await assert.rejects(prepare(db),/in_progress/);
  await db.exec('update private.ai_template_generation_policy set concurrent_limit=1');await assert.rejects(prepare(db,other),/capacity_limited/);
  await fail(db,r);const second=await prepare(db);await fail(db,second);await assert.rejects(prepare(db),/rate_limited/);
  await db.exec('update private.ai_template_generation_policy set project_daily_limit=2');await assert.rejects(prepare(db,other),/capacity_limited/);
  await db.exec('update private.ai_template_generation_policy set enabled=false');await assert.rejects(prepare(db,other),/disabled/);
  assert.equal(await balance(db),10000);
 }finally{await db.close();}
});
test('unreviewed v3 engine is not enabled by deploying billing protection',async()=>{
 const db=await fixture();try{
  await assert.rejects(asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3)',[user,request(),hash])),/v3_not_validated/);
  assert.equal((await db.query('select count(*)::int n from private.ai_template_generation_intents')).rows[0].n,0);
  await db.exec('update private.ai_template_generation_policy set v3_enabled=true');
  await assert.rejects(asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3)',[user,request(),hash])),/price_confirmation_required/);
  await assert.rejects(asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3,0)',[user,request(),hash])),/price_changed/);
  await asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3,700)',[user,request(),hash]));
  await assert.rejects(asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3,700)',[free,request(),hash])),/price_changed/);
  await asRole(db,'service_role',()=>db.query('select public.prepare_ai_template_generation($1,$2,$3,3,0)',[free,request(),hash]));
 }finally{await db.close();}
});
test('expired or malformed results cannot become billable; generation SQL is service-role only',async()=>{
 const db=await fixture();try{
  const r=await prepare(db);
  await assert.rejects(complete(db,r,user,{...result(r),draftId:'forged'}),/invalid_result/);
  await db.exec(`update private.ai_template_generation_intents set lease_expires_at=now()-interval '1 second' where id='${r.id}'`);
  await assert.rejects(complete(db,r),/not_pending/);
  for(const role of ['anon','authenticated'])for(const sql of [
   `select public.prepare_ai_template_generation('${user}','${request()}','${hash}')`,
   `select public.complete_ai_template_generation('${user}','${r.id}','{}')`,
   `select public.fail_ai_template_generation('${user}','${r.id}')`,
   'select * from private.ai_template_generation_intents','update private.ai_template_generation_policy set enabled=true',
   `update public.point_wallets set balance=99999 where user_id='${user}'`,
  ])await assert.rejects(asRole(db,role,()=>db.exec(sql)),/permission denied|row.level security/);
  await db.exec("select set_config('request.jwt.claim.sub','',false)");
  await assert.rejects(asRole(db,'authenticated',()=>db.query('select * from public.record_ai_album_draft_success($1)',[r.draftId])),/auth_required/);
 }finally{await db.close();}
});

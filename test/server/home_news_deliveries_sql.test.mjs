// Actual migrations in disposable PostgreSQL. PGlite serializes one connection;
// queued retries do not claim to be a multiple-session locking load test.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {pathToFileURL} from 'node:url';
const {PGlite} = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite');
const sql = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8');
const a='11111111-1111-4111-8111-111111111111', b='22222222-2222-4222-8222-222222222222', admin='99999999-9999-4999-8999-999999999999';
const ids=['monthly-design:2026-10','attendance-benefit:v1','referral-benefit:v1','month-review:2026-10'];
async function fixture() {
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
  create schema auth;create schema attendance_private;create schema referral_private;create schema moments_private;
  create table auth.users(id uuid primary key,is_anonymous boolean not null default false,banned_until timestamptz,deleted_at timestamptz,raw_app_meta_data jsonb not null default '{}');
  create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function auth.jwt()returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
  create function public.is_admin()returns boolean language sql stable security definer set search_path=public as $$select coalesce((auth.jwt()->'app_metadata'->>'role')='admin',false)$$;
  grant usage on schema public,auth to anon,authenticated,service_role;
  create table attendance_private.daily_attendance(user_id uuid,attendance_date date);
  create table referral_private.redemptions(invitee_id uuid,inviter_id uuid);
  create table public.point_ledger(user_id uuid,reason text);
  create table public.albums(id bigint primary key,owner_id uuid);
  create table moments_private.weekly_moments(owner_id uuid,record_date date,photos jsonb,deleted_at timestamptz);
  create table moments_private.month_albums(owner_id uuid,month date,album_id bigint);
  insert into auth.users(id)values('${a}'),('${b}');
  insert into auth.users(id,raw_app_meta_data)values('${admin}','{"role":"admin"}');`);
 await db.exec(sql('20261027014355_home_news_exposure_policy.sql'));
 await db.exec(sql('20261027022615_home_news_remote_campaigns_and_deliveries.sql'));
 await db.exec(sql('20261027022937_preserve_month_review_trigger_after_generic_swipe.sql'));
 await db.exec(`create schema test_clock;create table test_clock.current(instant timestamptz);insert into test_clock.current values('2026-10-12T03:00:00Z');
  create or replace function home_news_private.server_now()returns timestamptz language sql volatile security invoker set search_path=''as $$select instant from test_clock.current$$;`);
 return db;
}
async function login(db,user=a,{role='authenticated',adminJwt=user===admin,userMetadataAdmin=false}={}) {
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[user??'',JSON.stringify({app_metadata:{role:adminJwt?'admin':'user'},user_metadata:{role:userMetadataAdmin?'admin':'user'}})]);
 await db.exec(`set role ${role}`);
}
async function clock(db,at,user=a){await db.exec('reset role');await db.query('update test_clock.current set instant=$1',[at]);await login(db,user);}
const state=async db=>(await db.query('select public.get_home_news_state()result')).rows[0].result;
const claim=async(db,list=ids)=>(await db.query('select public.claim_home_news_delivery($1)result',[list])).rows[0].result;
const single=async(db,id)=>(await db.query('select public.claim_home_news_exposure($1)result',[id])).rows[0].result;
const view=async(db,delivery,id)=>(await db.query('select public.record_home_news_delivery_view($1,$2)result',[delivery,id])).rows[0].result;
const adminState=async db=>(await db.query('select public.get_admin_home_news_campaigns()result')).rows[0].result;
const update=async(db,{kind='referral',enabled=true,start=null,end=null,order=3}={})=>(await db.query(
 'select public.update_admin_home_news_campaign($1,$2,$3,$4,$5)result',[kind,enabled,start,end,order])).rows[0].result;

test('four eligible month-end cards share one delivery; only actual first/swiped cards become seen',async()=>{
 const db=await fixture();try{
  await db.query("insert into moments_private.weekly_moments values($1,'2026-10-27','[{\"path\":\"private/not-exposed.jpg\"}]',null)",[a]);
  await clock(db,'2026-10-27T03:00:00Z');const before=await state(db);
  assert.deepEqual(before.campaigns.map(x=>[x.kind,x.sortOrder]),[['monthReview',0],['monthlyDesign',1],['attendance',2],['referral',3]]);
  const result=await claim(db);assert.equal(result.claimed,true);assert.deepEqual(result.allowedCampaignIds,ids);
  assert.equal(result.dailyCount,1);assert.equal(result.weeklyCount,1);assert.equal(result.deliveries.length,1);
  assert.deepEqual(result.history.map(x=>x.id),[ids[0]]);assert.equal(result.history[0].deliveryId,result.deliveryId);
  for(const id of ids.slice(1)){const shown=await view(db,result.deliveryId,id);assert.equal(shown.viewed,true);assert.equal(shown.dailyCount,1);assert.equal(shown.weeklyCount,1);}
  const final=await state(db);assert.equal(final.history.length,4);assert.equal(final.deliveries.length,1);
  const same=await view(db,result.deliveryId,ids[3]);assert.equal(same.history.length,4);assert.equal(same.dailyCount,1);
  await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from public.point_ledger')).rows[0].n,0);
 }finally{await db.close();}
});

test('first trigger must be unseen and eligible; other active benefit/recap cards remain visible after completed benefits',async()=>{
 const db=await fixture();try{
  await db.query("insert into attendance_private.daily_attendance values($1,'2025-01-01')",[a]);
  await db.query("insert into public.point_ledger values($1,'REFERRAL_INVITER')",[a]);
  await login(db);
  assert.equal((await claim(db,[ids[1],ids[0]])).claimed,false);
  assert.equal((await claim(db,[ids[2],ids[0]])).claimed,false);
  assert.equal((await claim(db,[ids[3],ids[0]])).claimed,false);
  const allowed=await claim(db);assert.equal(allowed.claimed,true);assert.deepEqual(allowed.allowedCampaignIds,ids);
  for(const id of ids.slice(1,3))assert.equal((await view(db,allowed.deliveryId,id)).viewed,true);
  assert.equal((await view(db,allowed.deliveryId,ids[3])).viewed,false);
  assert.equal((await state(db)).history.length,3);
  await clock(db,'2026-10-13T03:00:00Z');assert.equal((await claim(db)).claimed,false);
  assert.equal((await claim(db,[ids[1],ids[0]])).claimed,false);
 }finally{await db.close();}
});

test('viewing the generic month-review card never consumes the later actual month-end photo reminder',async()=>{
 const db=await fixture();try{
  await login(db);const introduction=await claim(db);assert.equal(introduction.claimed,true);
  assert.equal(introduction.allowedCampaignIds.includes(ids[3]),true);
  const generic=await view(db,introduction.deliveryId,ids[3]);
  assert.equal(generic.viewed,false);assert.equal(generic.dailyCount,1);assert.equal(generic.weeklyCount,1);
  assert.equal(generic.history.some(x=>x.id===ids[3]),false);
  await db.exec('reset role');
  await db.query("insert into moments_private.weekly_moments values($1,'2026-10-26','[{\"path\":\"private/future-recap.jpg\"}]',null)",[a]);
  await clock(db,'2026-10-27T03:00:00Z');
  const actual=await claim(db,[ids[3],ids[0],ids[1],ids[2]]);
  assert.equal(actual.claimed,true);assert.equal(actual.dailyCount,1);assert.equal(actual.weeklyCount,1);
  assert.equal(actual.history.some(x=>x.id===ids[3]),true);
  assert.equal(actual.history.find(x=>x.id===ids[3]).deliveryId,actual.deliveryId);
 }finally{await db.close();}
});

test('queued app/web retries reserve one delivery, legacy single claims keep counting and Monday resets the combined cap',async()=>{
 const db=await fixture();try{
  await login(db);const results=await Promise.all(Array.from({length:10},()=>claim(db)));
  assert.equal(results.filter(x=>x.claimed).length,1);
  await clock(db,'2026-10-13T03:00:00Z');
  const next=await single(db,ids[1]);assert.equal(next.claimed,true);assert.equal(next.dailyCount,1);assert.equal(next.weeklyCount,2);
  assert.equal(next.history.filter(x=>x.deliveryId===null).length,1);
  await clock(db,'2026-10-14T03:00:00Z');assert.equal((await claim(db,[ids[2],ids[3]])).claimed,false);
  await clock(db,'2026-10-19T03:00:00Z');const monday=await claim(db,[ids[2],ids[3]]);
  assert.equal(monday.claimed,true);assert.equal(monday.weeklyCount,1);assert.equal(monday.dailyCount,1);
  assert.equal(monday.history.length,3);assert.equal(monday.deliveries.length,2);
 }finally{await db.close();}
});

test('administrator access requires real current server app metadata plus admin JWT; mutable user metadata cannot authorize',async()=>{
 const db=await fixture();try{
  await login(db,null,{role:'anon'});await assert.rejects(()=>adminState(db),/permission denied/);
  await login(db,a,{userMetadataAdmin:true});await assert.rejects(()=>adminState(db),/HOME_NEWS_ADMIN_REQUIRED/);
  await login(db,a,{adminJwt:true});await assert.rejects(()=>update(db),/HOME_NEWS_ADMIN_REQUIRED/);
  await login(db,admin,{adminJwt:false});await assert.rejects(()=>adminState(db),/HOME_NEWS_ADMIN_REQUIRED/);
  await login(db,admin);const initial=await adminState(db);assert.equal(initial.userId,admin);assert.equal(initial.campaigns.length,4);
  const changed=await update(db,{kind:'referral',enabled:false,order:-3});assert.equal(changed.campaigns[0].kind,'referral');assert.equal(changed.campaigns[0].enabled,false);
  await db.exec('reset role');await db.query("update auth.users set raw_app_meta_data='{}'where id=$1",[admin]);
  await login(db,admin);await assert.rejects(()=>update(db),/HOME_NEWS_ADMIN_REQUIRED/);
  await login(db,a);await assert.rejects(()=>db.query('select * from home_news_private.campaigns'),/permission denied/);
  await assert.rejects(()=>db.query('select * from home_news_private.deliveries'),/permission denied/);
  await assert.rejects(()=>db.query('select home_news_private.campaigns_json()'),/permission denied/);
 }finally{await db.close();}
});

test('remote enable/start-inclusive/end-exclusive schedules are enforced by single/batch claim and each subsequent swipe',async()=>{
 const db=await fixture();try{
  await login(db,admin);await update(db,{kind:'monthlyDesign',start:'2026-10-12T03:01:00Z',end:'2026-10-12T03:03:00Z',order:1});
  await login(db);assert.equal((await claim(db)).claimed,false);assert.equal((await single(db,ids[0])).claimed,false);
  await clock(db,'2026-10-12T03:01:00Z');const accepted=await claim(db);assert.equal(accepted.claimed,true);
  await login(db,admin);await update(db,{kind:'referral',enabled:false});
  await login(db);assert.equal((await view(db,accepted.deliveryId,ids[2])).viewed,false);
  await clock(db,'2026-10-12T03:03:00Z',b);assert.equal((await claim(db)).claimed,false);
  await login(db,admin);await update(db,{kind:'monthlyDesign',enabled:false,order:1});
  await login(db);assert.equal((await view(db,accepted.deliveryId,ids[0])).viewed,false);
 }finally{await db.close();}
});

test('delivery views reject other owners, absent snapshot cards, unknown IDs, expired TTL and old monthly editions without spending quota',async()=>{
 const db=await fixture();try{
  await login(db,admin);await update(db,{kind:'referral',enabled:false});
  await login(db);const result=await claim(db);assert.equal(result.allowedCampaignIds.length,3);
  await login(db,b);assert.equal((await view(db,result.deliveryId,ids[1])).viewed,false);assert.equal((await state(db)).dailyCount,0);
  await login(db,admin);await update(db,{kind:'referral',enabled:true});
  await login(db);assert.equal((await view(db,result.deliveryId,ids[2])).viewed,false);
  assert.equal((await view(db,result.deliveryId,'month-review:2026-09')).viewed,false);
  await clock(db,'2026-10-12T03:30:00Z');assert.equal((await view(db,result.deliveryId,ids[1])).viewed,false);
  assert.equal((await state(db)).history.length,1);
  await login(db,b);assert.equal((await claim(db,['monthly-design:2026-11'])).claimed,false);
  for(const invalid of [[],[ids[0],ids[0]],[ids[0],null],Array(5).fill(ids[0])])await assert.rejects(()=>claim(db,invalid),/HOME_NEWS_INVALID_CAMPAIGNS/);
 }finally{await db.close();}
});

test('invalid admin updates and failed first exposure roll back without a ghost delivery or changed configuration',async()=>{
 const db=await fixture();try{
  await login(db,admin);const original=await adminState(db);
  for(const patch of [{kind:'unknown'},{enabled:null},{order:1001},{order:null},{start:'2026-10-13T00:00:00Z',end:'2026-10-12T00:00:00Z'},{start:'infinity'}])
   await assert.rejects(()=>update(db,patch),/HOME_NEWS_INVALID_SCHEDULE/);
  assert.deepEqual((await adminState(db)).campaigns,original.campaigns);
  await db.exec(`reset role;create function home_news_private.fail_exposure()returns trigger language plpgsql as $$begin raise exception 'synthetic exposure failure';end$$;
   create trigger synthetic_exposure_failure before insert on home_news_private.exposures for each row execute function home_news_private.fail_exposure();`);
  await login(db);await assert.rejects(()=>claim(db),/synthetic exposure failure/);
  const after=await state(db);assert.equal(after.dailyCount,0);assert.equal(after.weeklyCount,0);assert.deepEqual(after.deliveries,[]);assert.deepEqual(after.history,[]);
 }finally{await db.close();}
});

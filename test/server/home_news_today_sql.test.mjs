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
 await db.exec(sql('20261028082350_home_news_every_entry_and_today_hide.sql'));
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

const hide=async db=>(await db.query('select public.hide_home_news_for_today()result')).rows[0].result;
const interaction=async(db,id,action)=>(await db.query('select public.record_home_news_interaction($1,$2)result',[id,action])).rows[0].result;

test('every home entry can show the active four cards regardless of first-use, seen history, daily count or month-end targets',async()=>{
 const db=await fixture();try{
  await db.query("insert into attendance_private.daily_attendance values($1,'2025-01-01')",[a]);
  await db.query("insert into public.point_ledger values($1,'REFERRAL_INVITER')",[a]);
  await login(db);
  const reordered=[ids[3],ids[1],ids[2],ids[0]];
  const first=await claim(db,reordered);assert.equal(first.claimed,true);assert.deepEqual(first.allowedCampaignIds,reordered);
  for(const id of reordered)assert.equal((await view(db,first.deliveryId,id)).viewed,true);
  assert.equal((await state(db)).history.length,4);
  for(let n=2;n<=5;n++){
   const next=await claim(db,reordered);assert.equal(next.claimed,true);assert.equal(next.dailyCount,n);assert.equal(next.weeklyCount,n);
   assert.notEqual(next.deliveryId,first.deliveryId);assert.equal(next.history.length,4);
  }
  assert.equal((await single(db,ids[1])).claimed,true);
  assert.equal((await single(db,ids[1])).dailyCount,7);
 }finally{await db.close();}
});

test('normal close and click do not hide later entries; only the explicit today-hide action persists it',async()=>{
 const db=await fixture();try{
  await login(db);await claim(db);
  assert.equal((await interaction(db,ids[0],'dismiss')).hiddenForToday,false);
  assert.equal((await claim(db)).claimed,true);
  assert.equal((await interaction(db,ids[0],'click')).hiddenForToday,false);
  assert.equal((await claim(db)).claimed,true);
  const hidden=await hide(db);assert.equal(hidden.hiddenForToday,true);
  assert.equal(Date.parse(hidden.hiddenUntil),Date.parse('2026-10-12T15:00:00Z'));
  assert.equal((await hide(db)).hiddenUntil,hidden.hiddenUntil);
  const denied=await claim(db);assert.equal(denied.claimed,false);assert.equal(denied.deliveryId,null);assert.deepEqual(denied.allowedCampaignIds,[]);
  assert.equal((await single(db,ids[0])).claimed,false);
  assert.equal((await state(db)).dailyCount,3);
 }finally{await db.close();}
});

test('today hide is account-owned and shared by every client until exactly Korean midnight, independent of device clock',async()=>{
 const db=await fixture();try{
  await clock(db,'2026-10-12T14:59:59Z');await db.exec("set timezone='Pacific/Kiritimati'");
  await db.query("select set_config('request.headers',$1,false)",[JSON.stringify({'x-client-date':'2099-01-01'})]);
  const hidden=await hide(db);assert.equal(hidden.serverDate,'2026-10-12');assert.equal(hidden.hiddenForToday,true);
  await login(db,a);assert.equal((await state(db)).hiddenForToday,true);assert.equal((await claim(db)).claimed,false);
  await login(db,b);assert.equal((await state(db)).hiddenForToday,false);assert.equal((await claim(db)).claimed,true);
  await clock(db,'2026-10-12T15:00:00Z');const reset=await state(db);
  assert.equal(reset.serverDate,'2026-10-13');assert.equal(reset.hiddenForToday,false);assert.equal(reset.hiddenUntil,null);
  assert.equal((await claim(db)).claimed,true);
  await assert.rejects(()=>db.query("select hide_home_news_for_today('2099-01-01')"),/does not exist/);
  await assert.rejects(()=>db.query('select hide_home_news_for_today($1)',[b]),/does not exist/);
 }finally{await db.close();}
});

test('anonymous, missing, banned, deleted and another account cannot forge or read hidden preferences',async()=>{
 const db=await fixture();try{
  await login(db,null,{role:'anon'});await assert.rejects(()=>hide(db),/permission denied/);
  await login(db,null);await assert.rejects(()=>hide(db),/HOME_NEWS_LOGIN_REQUIRED/);
  for(const patch of ['is_anonymous=true',"banned_until='2099-01-01'","deleted_at='2026-10-01'"]){
   await db.exec('reset role');await db.exec(`update auth.users set is_anonymous=false,banned_until=null,deleted_at=null where id='${a}';update auth.users set ${patch} where id='${a}'`);
   await login(db);await assert.rejects(()=>hide(db),/HOME_NEWS_ACCOUNT_REQUIRED/);
  }
  await login(db,b);await hide(db);
  await assert.rejects(()=>db.query('select * from home_news_private.preferences'),/permission denied/);
  await assert.rejects(()=>db.query('update home_news_private.preferences set hidden_date=current_date+7'),/permission denied/);
  await assert.rejects(()=>db.query('select home_news_private.state_json($1,now(),false)',[b]),/permission denied/);
  await db.exec('reset role');await db.query('delete from auth.users where id=$1',[b]);
  assert.equal((await db.query('select count(*)::int n from home_news_private.preferences')).rows[0].n,0);
 }finally{await db.close();}
});

test('remote disabled and schedule boundaries still filter cards, including an originally requested first card',async()=>{
 const db=await fixture();try{
  await login(db,admin);await update(db,{kind:'monthlyDesign',enabled:false,order:1});
  await update(db,{kind:'attendance',start:'2026-10-12T03:01:00Z',end:'2026-10-12T03:02:00Z',order:2});
  await login(db);const filtered=await claim(db);assert.equal(filtered.claimed,true);assert.deepEqual(filtered.allowedCampaignIds,[ids[2],ids[3]]);
  assert.equal((await single(db,ids[0])).claimed,false);
  await clock(db,'2026-10-12T03:01:00Z');assert.equal((await claim(db)).allowedCampaignIds.includes(ids[1]),true);
  await clock(db,'2026-10-12T03:02:00Z');assert.equal((await claim(db)).allowedCampaignIds.includes(ids[1]),false);
  await login(db,admin);for(const kind of ['monthReview','referral'])await update(db,{kind,enabled:false});
  await login(db);assert.equal((await claim(db)).claimed,false);
 }finally{await db.close();}
});

test('repeated deliveries return bounded JSON with exact omitted aggregates instead of restoring exposure caps',async()=>{
 const db=await fixture();try{
  await login(db);let last;
  for(let n=0;n<75;n++)last=await claim(db);
  assert.equal(last.claimed,true);assert.equal(last.dailyCount,75);assert.equal(last.weeklyCount,75);
  assert.ok(last.deliveries.length<=51);assert.equal(last.history.length,1);
  const included=new Set(last.deliveries.map(x=>x.id)).size;
  assert.equal(last.omittedDailyCount+included,75);assert.equal(last.omittedWeeklyCount+included,75);
  assert.equal(last.deliveries.some(x=>x.id===last.deliveryId),true);
  assert.equal(last.hiddenForToday,false);
 }finally{await db.close();}
});

test('old unreferenced repeat deliveries are pruned after 35 days while first-seen history and referenced deliveries survive',async()=>{
 const db=await fixture();try{
  await login(db);const first=await claim(db);await claim(db);await claim(db);
  await clock(db,'2026-11-20T03:00:00Z');const next=await claim(db,['monthly-design:2026-11','attendance-benefit:v1']);
  assert.equal(next.claimed,true);assert.equal(next.dailyCount,1);assert.equal(next.weeklyCount,1);
  await db.exec('reset role');const remaining=(await db.query('select id from home_news_private.deliveries where user_id=$1',[a])).rows.map(x=>x.id);
  assert.equal(remaining.length,2);assert.equal(remaining.includes(first.deliveryId),true);
  assert.equal((await db.query('select count(*)::int n from home_news_private.exposures')).rows[0].n,2);
 }finally{await db.close();}
});

test('many queued entries all succeed before hide, a failed exposure rolls back its delivery, and no points are changed',async()=>{
 const db=await fixture();try{
  await login(db);const replies=await Promise.all(Array.from({length:8},()=>claim(db)));
  assert.equal(replies.every(x=>x.claimed),true);assert.equal(new Set(replies.map(x=>x.deliveryId)).size,8);
  await hide(db);const denied=await Promise.all(Array.from({length:5},()=>claim(db)));
  assert.equal(denied.every(x=>!x.claimed),true);
  await db.exec(`reset role;create function home_news_private.fail_today_exposure()returns trigger language plpgsql as $$begin raise exception'synthetic failure';end$$;
   create trigger synthetic_failure before insert on home_news_private.exposures for each row execute function home_news_private.fail_today_exposure();`);
  await login(db,b);await assert.rejects(()=>claim(db),/synthetic failure/);
  assert.equal((await state(db)).dailyCount,0);assert.deepEqual((await state(db)).deliveries,[]);
  await db.exec('reset role');assert.equal((await db.query('select count(*)::int n from public.point_ledger')).rows[0].n,0);
 }finally{await db.close();}
});


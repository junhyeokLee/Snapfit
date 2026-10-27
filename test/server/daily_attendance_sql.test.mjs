// Actual migrations and PostgreSQL roles in disposable PGlite only. PGlite queues
// calls on one connection; the queued test is not a multi-session lock/load test.
import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const {PGlite}=await import(process.env.PGLITE_MODULE??'@electric-sql/pglite');
const sql=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8');
const attendance=sql('20261026075526_daily_attendance_rewards.sql');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',c='33333333-3333-4333-8333-333333333333';
async function fixture({beforeAttendance}={}){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
  create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean not null default false,banned_until timestamptz,deleted_at timestamptz);
  create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function auth.jwt()returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
  create function public.is_admin()returns boolean language sql stable as $$select false$$;
  create function public.set_updated_at()returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
  grant usage on schema public,auth to anon,authenticated,service_role;
  alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
  alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
  alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
  insert into auth.users(id)values('${a}'),('${b}');`);
 await db.exec(sql('20260905113000_ai_album_points.sql'));
 await db.exec('alter table public.point_wallets drop constraint point_wallets_balance_check');
 await db.exec(sql('20260908111001_digital_point_shop.sql'));
 await db.exec(sql('20261019121000_signup_bonus_points.sql'));
 if(beforeAttendance)await beforeAttendance(db);
 await db.exec(attendance);
 await db.exec(`create schema test_clock;revoke all on schema test_clock from public,anon,authenticated,service_role;
  create table test_clock.current(instant timestamptz);insert into test_clock.current values('2026-10-26T03:00:00Z');
  create or replace function attendance_private.server_now()returns timestamptz language sql volatile security invoker set search_path=''as $$select instant from test_clock.current$$;`);
 return db;
}
async function login(db,user=a,role='authenticated'){
 await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user??'']);await db.exec(`set role ${role}`);
}
async function clock(db,at){await db.exec('reset role');await db.query('update test_clock.current set instant=$1',[at]);await login(db);}
async function status(db){return(await db.query('select public.get_attendance_status()result')).rows[0].result;}
async function claim(db){return(await db.query('select public.claim_daily_attendance()result')).rows[0].result;}
async function rawCounts(db){await db.exec('reset role');return(await db.query(`select(select count(*)::int from point_wallets)wallets,(select count(*)::int from point_ledger)ledger,(select count(*)::int from attendance_private.daily_attendance)attendance`)).rows[0];}
async function fund(db,value,user=a){await db.exec('reset role');await db.query('insert into point_wallets(user_id,balance)values($1,$2)on conflict(user_id)do update set balance=excluded.balance',[user,value]);await login(db,user);}

test('read-only status and first/repeated claim return the complete camelCase contract with one atomic credit',async()=>{
 const db=await fixture();try{
  await login(db);const first=await status(db);
  assert.deepEqual(Object.keys(first).sort(),['serverTime','serverDate','timezone','nextResetAt','checkedInToday','currentStreak','cycleDay','todayReward','weeklyRewards','month','monthPoints','monthAttendanceCount','history','claimed','awardedPoints','balance'].sort());
  assert.equal(first.serverDate,'2026-10-26');assert.equal(first.timezone,'Asia/Seoul');assert.equal(Date.parse(first.nextResetAt),Date.parse('2026-10-26T15:00:00Z'));
  assert.deepEqual(first.weeklyRewards,[10,10,20,10,10,10,30]);assert.equal(first.currentStreak,0);assert.equal(first.cycleDay,1);assert.equal(first.todayReward,10);assert.equal(first.claimed,false);assert.equal(first.awardedPoints,0);assert.equal(first.balance,0);assert.deepEqual(first.history,[]);
  assert.deepEqual(await rawCounts(db),{wallets:0,ledger:0,attendance:0});
  await login(db);const earned=await claim(db);assert.equal(earned.claimed,true);assert.equal(earned.awardedPoints,10);assert.equal(earned.balance,10);assert.equal(earned.checkedInToday,true);assert.equal(earned.currentStreak,1);assert.equal(earned.cycleDay,1);assert.equal(earned.monthPoints,10);assert.equal(earned.monthAttendanceCount,1);
  assert.deepEqual(earned.history,[{date:'2026-10-26',points:10,cycleDay:1,streak:1}]);
  const again=await claim(db);assert.equal(again.claimed,false);assert.equal(again.awardedPoints,0);assert.equal(again.balance,10);assert.equal(again.todayReward,10);
  assert.equal((await status(db)).claimed,false);assert.deepEqual(await rawCounts(db),{wallets:1,ledger:1,attendance:1});
 }finally{await db.close();}
});

test('queued simultaneous same-user retries award once; a failed response retry is safe',async()=>{
 const db=await fixture();try{
  await login(db);const results=await Promise.all(Array.from({length:20},()=>claim(db)));
  assert.equal(results.filter(x=>x.claimed).length,1);assert.equal(results.reduce((n,x)=>n+x.awardedPoints,0),10);assert.ok(results.every(x=>x.balance===10));
  assert.deepEqual(await rawCounts(db),{wallets:1,ledger:1,attendance:1});await login(db);assert.equal((await claim(db)).awardedPoints,0);
 }finally{await db.close();}
});

test('KST midnight uses the server clock despite client timezone, forged headers/metadata and unsupported date arguments',async()=>{
 const db=await fixture();try{
  await clock(db,'2026-10-26T14:59:59.999Z');await db.exec("set timezone='Pacific/Kiritimati'");
  await db.query("select set_config('request.jwt.claims',$1,false),set_config('request.headers',$2,false)",[JSON.stringify({user_metadata:{date:'2099-01-01',reward:999999,streak:99}}),JSON.stringify({'x-client-date':'2099-01-01','date':'2099-01-01'})]);
  const before=await claim(db);assert.equal(before.serverDate,'2026-10-26');assert.equal(before.awardedPoints,10);
  await assert.rejects(()=>db.query("select claim_daily_attendance('2099-01-01')"),/does not exist/);
  await assert.rejects(()=>db.query('select get_attendance_status($1)',[b]),/does not exist/);
  await assert.rejects(()=>db.query("create or replace function attendance_private.server_now()returns timestamptz language sql as $$select '2099-01-01'::timestamptz$$"),/permission denied|must be owner/);
  await clock(db,'2026-10-26T15:00:00Z');const next=await status(db);assert.equal(next.serverDate,'2026-10-27');assert.equal(next.checkedInToday,false);assert.equal(next.currentStreak,1);assert.equal(next.cycleDay,2);assert.equal(Date.parse(next.nextResetAt),Date.parse('2026-10-27T15:00:00Z'));
  assert.equal((await claim(db)).currentStreak,2);
 }finally{await db.close();}
});

test('claim re-evaluates server day after acquiring the wallet lock when a request spans midnight',async()=>{
 const db=await fixture();try{
  await db.exec(`create table test_clock.calls(n int);insert into test_clock.calls values(0);
   create or replace function attendance_private.server_now()returns timestamptz language plpgsql volatile security invoker set search_path=''as $$declare n int;begin update test_clock.calls set n=test_clock.calls.n+1 returning test_clock.calls.n into n;return case when n=1 then '2026-10-26T14:59:59Z'::timestamptz else '2026-10-26T15:00:00Z'::timestamptz end;end$$;`);
  await login(db);const result=await claim(db);assert.equal(result.serverDate,'2026-10-27');assert.equal(result.history[0].date,'2026-10-27');
 }finally{await db.close();}
});

test('seven-day rewards repeat on day eight, missing a day resets, and status retains only yesterday continuity',async()=>{
 const db=await fixture();try{
  const rewards=[];
  for(let day=1;day<=8;day++){
   await clock(db,`2026-10-${String(day).padStart(2,'0')}T03:00:00Z`);
   const before=await status(db);assert.equal(before.currentStreak,day-1);assert.equal(before.cycleDay,1+((day-1)%7));
   const result=await claim(db);rewards.push(result.awardedPoints);assert.equal(result.currentStreak,day);assert.equal(result.cycleDay,1+((day-1)%7));
  }
  assert.deepEqual(rewards,[10,10,20,10,10,10,30,10]);
  await clock(db,'2026-10-10T03:00:00Z');const missed=await status(db);assert.equal(missed.currentStreak,0);assert.equal(missed.cycleDay,1);assert.equal(missed.todayReward,10);assert.equal((await claim(db)).currentStreak,1);
 }finally{await db.close();}
});

test('month history and totals roll at KST month/leap boundaries while the streak continues',async()=>{
 const db=await fixture();try{
  for(let day=1;day<=31;day++){await clock(db,`2026-10-${String(day).padStart(2,'0')}T03:00:00Z`);await claim(db);}
  const oct=await status(db);assert.equal(oct.monthAttendanceCount,31);assert.equal(oct.monthPoints,440);assert.equal(oct.history.length,31);assert.equal(oct.history[0].date,'2026-10-01');
  await clock(db,'2026-10-31T15:00:00Z');let before=await status(db);assert.equal(before.month,'2026-11');assert.equal(before.monthAttendanceCount,0);assert.equal(before.currentStreak,31);assert.equal(before.cycleDay,4);
  const nov=await claim(db);assert.equal(nov.currentStreak,32);assert.equal(nov.monthPoints,10);assert.deepEqual(nov.history,[{date:'2026-11-01',points:10,cycleDay:4,streak:32}]);
  await clock(db,'2028-02-28T15:00:00Z');assert.equal((await claim(db)).serverDate,'2028-02-29');
  await clock(db,'2028-02-29T15:00:00Z');const leap=await claim(db);assert.equal(leap.serverDate,'2028-03-01');assert.equal(leap.currentStreak,2);assert.equal(leap.monthAttendanceCount,1);
 }finally{await db.close();}
});

test('permanent logged-in existing accounts only; anonymous, missing, banned and soft-deleted users cannot claim',async()=>{
 const db=await fixture();try{
  await login(db,null,'anon');for(const fn of[status,claim])await assert.rejects(()=>fn(db),/permission denied/);
  await login(db,null);for(const fn of[status,claim])await assert.rejects(()=>fn(db),e=>e.code==='42501'&&/login_required/.test(e.message));
  await login(db,c);await assert.rejects(()=>claim(db),/personal_account_required/);
  for(const patch of['is_anonymous=true',"banned_until='2099-01-01'","deleted_at='2026-10-01'"]){
   await db.exec('reset role');await db.exec(`update auth.users set is_anonymous=false,banned_until=null,deleted_at=null where id='${a}';update auth.users set ${patch} where id='${a}'`);await login(db);
   await assert.rejects(()=>status(db),/personal_account_required/);await assert.rejects(()=>claim(db),/personal_account_required/);
  }
  assert.deepEqual(await rawCounts(db),{wallets:0,ledger:0,attendance:0});
 }finally{await db.close();}
});

test('account isolation and private helper/table ACLs prevent another actor from seeing or claiming attendance',async()=>{
 const db=await fixture();try{
  await login(db);await claim(db);await login(db,b);const own=await status(db);assert.equal(own.balance,0);assert.deepEqual(own.history,[]);assert.equal(own.checkedInToday,false);
  await assert.rejects(()=>db.query('select * from attendance_private.daily_attendance'),/permission denied/);
  await assert.rejects(()=>db.query("select attendance_private.status_json($1,now(),false,0)",[a]),/permission denied/);
  await assert.rejects(()=>db.query('select attendance_private.server_now()'),/permission denied/);
  const second=await claim(db);assert.equal(second.balance,10);assert.equal(second.currentStreak,1);assert.equal((await db.query('select user_id,amount_delta from point_ledger')).rows.length,1);
  await db.exec('reset role');const rows=(await db.query('select user_id,points from attendance_private.daily_attendance order by user_id')).rows;assert.deepEqual(rows,[{user_id:a,points:10},{user_id:b,points:10}]);
 }finally{await db.close();}
});

test('direct attendance reason/prefix insertion and record/ledger changes are denied even with permissive legacy policies',async()=>{
 const db=await fixture();try{
  await login(db);
  const forged={attendanceDate:'2026-10-26',timezone:'Asia/Seoul',source:'free_attendance',cycleDay:1,streak:1};
  await assert.rejects(()=>db.query(`insert into point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)values($1,10,'DAILY_ATTENDANCE',$2,'daily_attendance','2026-10-26',$3)`,[a,`daily_attendance:${a}:2026-10-26`,JSON.stringify(forged)]),/row-level security/);
  await assert.rejects(()=>db.query(`insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,10,'ADMIN_ADJUSTMENT',$2)`,[a,`daily_attendance:${a}:2026-10-26`]),/attendance_ledger_invalid/);
  await claim(db);await db.exec('reset role');
  for(const stmt of["update point_ledger set amount_delta=30 where reason='DAILY_ATTENDANCE'","delete from point_ledger where reason='DAILY_ATTENDANCE'","update attendance_private.daily_attendance set points=20","delete from attendance_private.daily_attendance"]){await assert.rejects(()=>db.exec(stmt),/attendance_ledger_immutable|attendance_record_immutable/);}
  await login(db);assert.equal((await claim(db)).awardedPoints,0);
 }finally{await db.close();}
});

test('wallet overflow rolls back attendance and ledger together; negative refund debt is not forgiven',async()=>{
 const db=await fixture();try{
  await fund(db,2147483640);await assert.rejects(()=>claim(db),e=>e.code==='22003');assert.deepEqual(await rawCounts(db),{wallets:1,ledger:0,attendance:0});
  await fund(db,-20);const result=await claim(db);assert.equal(result.balance,-10);assert.equal(result.awardedPoints,10);assert.deepEqual(await rawCounts(db),{wallets:1,ledger:1,attendance:1});
 }finally{await db.close();}
});

test('signup bonus remains valid, refund reason is restored, and unknown allowed legacy reasons are preserved',async()=>{
 const db=await fixture({beforeAttendance:async db=>{
  await db.exec("alter table point_ledger drop constraint point_ledger_reason_check;alter table point_ledger add constraint point_ledger_reason_check check(reason in('AI_ALBUM_DRAFT_FREE','AI_ALBUM_DRAFT_CHARGE','ADMIN_ADJUSTMENT','POINT_PURCHASE','DIGITAL_ITEM_PURCHASE','SIGNUP_BONUS','EXISTING_CUSTOM_REASON'))");
 }});try{
  await db.query('insert into auth.users(id)values($1)',[c]);await login(db,c);assert.equal((await status(db)).balance,500);assert.equal((await claim(db)).balance,510);
  await db.exec('reset role');for(const reason of['POINT_PURCHASE_REFUND','EXISTING_CUSTOM_REASON'])await db.query('insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,-10,$2,$2)',[c,reason]);
  await assert.rejects(()=>db.query("insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,1,'NOT_ALLOWED','forged')",[c]),/point_ledger_reason_check/);
 }finally{await db.close();}
});

test('existing wallet/catalog/ownership/ledger rows survive migration and unrelated purchase rows remain unchanged by attendance',async()=>{
 let baseline;
 const snapshot=async db=>(await db.query(`select jsonb_build_object('wallets',(select jsonb_agg(to_jsonb(t)order by user_id)from point_wallets t),'ledger',(select jsonb_agg(to_jsonb(t)order by id)from point_ledger t),'products',(select jsonb_agg(to_jsonb(t)order by product_key)from point_shop_products t),'ownership',(select jsonb_agg(to_jsonb(t)order by user_id,product_key)from point_shop_ownership t))state`)).rows[0].state;
 const db=await fixture({beforeAttendance:async db=>{
  await db.exec("insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)values('frame:existing','existing','frame','Existing',100,true)");await fund(db,500,b);await db.query("select purchase_point_shop_product('frame:existing',100)");await db.exec('reset role');baseline=await snapshot(db);
 }});try{
  assert.deepEqual(await snapshot(db),baseline);await login(db);await claim(db);await db.exec('reset role');
  const after=await snapshot(db);assert.deepEqual(after.products,baseline.products);assert.deepEqual(after.ownership,baseline.ownership);assert.deepEqual(after.wallets.find(x=>x.user_id===b),baseline.wallets[0]);assert.deepEqual(after.ledger.filter(x=>x.user_id===b),baseline.ledger);
 }finally{await db.close();}
});

test('account deletion safely cascades protected attendance and a deleted-account JWT cannot claim again',async()=>{
 const db=await fixture();try{
  await login(db);await claim(db);await login(db,b);await claim(db);await db.exec('reset role');await db.query('delete from auth.users where id=$1',[a]);
  assert.deepEqual(await rawCounts(db),{wallets:1,ledger:1,attendance:1});await login(db);await assert.rejects(()=>claim(db),/personal_account_required/);await login(db,b);assert.equal((await status(db)).balance,10);
 }finally{await db.close();}
});

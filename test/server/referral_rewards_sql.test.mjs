// Actual migrations in disposable PostgreSQL. PGlite queues one connection;
// queued retries do not replace an ordinary-JWT multi-session production test.
import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const {PGlite}=await import(process.env.PGLITE_MODULE??'@electric-sql/pglite');
const sql=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8');
const referral=sql('20261026084050_simple_referral_rewards.sql');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',c='33333333-3333-4333-8333-333333333333';
const user=n=>`99999999-9999-4999-8999-${String(n).padStart(12,'0')}`;
async function fixture({beforeReferral}={}){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean not null default false,banned_until timestamptz,deleted_at timestamptz,created_at timestamptz not null default '2026-10-25T03:00:00Z',email text,email_confirmed_at timestamptz default '2026-10-25T03:00:00Z');
 create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function auth.jwt()returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
 create function public.is_admin()returns boolean language sql stable as $$select false$$;
 create function public.set_updated_at()returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
 grant usage on schema public,auth to anon,authenticated,service_role;
 alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
 alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
 alter default privileges in schema public grant all on functions to anon,authenticated,service_role;
 insert into auth.users(id,email)values('${a}','a@qa.snapfit.invalid'),('${b}','b@qa.snapfit.invalid');`);
 await db.exec(sql('20260905113000_ai_album_points.sql'));
 await db.exec('alter table public.point_wallets drop constraint point_wallets_balance_check');
 await db.exec(sql('20260908111001_digital_point_shop.sql'));
 await db.exec(sql('20261019121000_signup_bonus_points.sql'));
 await db.exec(sql('20261026075526_daily_attendance_rewards.sql'));
 if(beforeReferral)await beforeReferral(db);
 await db.exec(referral);
 await db.exec(`create schema test_clock;revoke all on schema test_clock from public,anon,authenticated,service_role;
 create table test_clock.current(instant timestamptz);insert into test_clock.current values('2026-10-26T03:00:00Z');
 create or replace function referral_private.server_now()returns timestamptz language sql volatile security invoker set search_path=''as $$select instant from test_clock.current$$;
 create or replace function attendance_private.server_now()returns timestamptz language sql volatile security invoker set search_path=''as $$select instant from test_clock.current$$;`);
 return db;
}
async function login(db,uid=a,role='authenticated'){
 await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[uid??'']);await db.exec(`set role ${role}`);
}
async function clock(db,at,uid=a){await db.exec('reset role');await db.query('update test_clock.current set instant=$1',[at]);await login(db,uid);}
async function status(db){return(await db.query('select get_referral_status()result')).rows[0].result;}
async function redeem(db,code){return(await db.query('select redeem_referral_code($1)result',[code])).rows[0].result;}
async function ownCode(db,uid){await login(db,uid);return(await status(db)).ownCode;}
async function counts(db){await db.exec('reset role');return(await db.query(`select(select count(*)::int from point_wallets)wallets,(select count(*)::int from point_ledger)ledger,(select count(*)::int from referral_private.redemptions)referrals`)).rows[0];}
async function add(db,uid,created='2026-10-25T03:00:00Z'){
 await db.exec('reset role');await db.query("insert into auth.users(id,email,created_at)values($1::uuid,$1::uuid::text||'@qa.snapfit.invalid',$2)",[uid,created]);
}
async function wallets(db){await db.exec('reset role');return(await db.query('select user_id,balance from point_wallets order by user_id')).rows;}

test('status exposes only the complete self contract, creates a stable random code, and grants no points',async()=>{
 const db=await fixture();try{
  await login(db);const first=await status(db);
  assert.deepEqual(Object.keys(first).sort(),['ownCode','inviterPoints','inviteePoints','registrationWindowDays','rewardLimit','monthlyRewardedCount','remaining','invitedCount','totalEarned','balance','canRedeem','redeemed','eligibleUntil','serverTime','claimed','awardedPoints','rewardMonth','timezone','ineligibleReason'].sort());
  assert.match(first.ownCode,/^[A-HJKMNP-Z2-9]{10}$/);assert.ok(!a.replaceAll('-','').includes(first.ownCode));assert.equal((await status(db)).ownCode,first.ownCode);
  assert.equal(first.inviterPoints,100);assert.equal(first.inviteePoints,100);assert.equal(first.registrationWindowDays,7);assert.equal(first.rewardLimit,20);assert.equal(first.remaining,20);assert.equal(first.monthlyRewardedCount,0);assert.equal(first.totalEarned,0);assert.equal(first.invitedCount,0);
  assert.equal(first.balance,0);assert.equal(first.canRedeem,true);assert.equal(first.redeemed,false);assert.equal(first.claimed,false);assert.equal(first.awardedPoints,0);assert.equal(first.ineligibleReason,null);assert.equal(first.rewardMonth,'2026-10');assert.equal(first.timezone,'Asia/Seoul');assert.equal(Date.parse(first.eligibleUntil),Date.parse('2026-11-01T03:00:00Z'));
  const other=await ownCode(db,b);assert.notEqual(other,first.ownCode);assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
 }finally{await db.close();}
});

test('one code registration credits both wallets immediately with linked 100P entries and idempotent retries',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);const result=await redeem(db,`  ${code.toLowerCase()}  `);
  assert.equal(result.claimed,true);assert.equal(result.awardedPoints,100);assert.equal(result.balance,100);assert.equal(result.redeemed,true);assert.equal(result.canRedeem,false);assert.equal(result.ineligibleReason,'already_redeemed');assert.equal(result.totalEarned,100);
  const duplicate=await redeem(db,code);assert.equal(duplicate.claimed,false);assert.equal(duplicate.awardedPoints,0);assert.equal(duplicate.balance,100);
  // Changing the retry's code cannot change the inviter or create another credit.
  assert.equal((await redeem(db,'INVALID')).awardedPoints,0);
  await login(db,a);const inviter=await status(db);assert.equal(inviter.balance,100);assert.equal(inviter.invitedCount,1);assert.equal(inviter.monthlyRewardedCount,1);assert.equal(inviter.remaining,19);assert.equal(inviter.totalEarned,100);
  assert.deepEqual(await counts(db),{wallets:2,ledger:2,referrals:1});await db.exec('reset role');
  const record=(await db.query('select * from referral_private.redemptions')).rows[0];assert.equal(record.invitee_id,b);assert.equal(record.inviter_id,a);assert.equal(record.points,100);
  const entries=(await db.query('select id,user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata from point_ledger order by id')).rows;
  assert.deepEqual(entries.map(x=>[x.user_id,x.amount_delta,x.reason]),[[a,100,'REFERRAL_INVITER'],[b,100,'REFERRAL_INVITEE']]);
  assert.deepEqual(entries.map(x=>x.id),[record.inviter_ledger_id,record.invitee_ledger_id]);assert.ok(entries.every(x=>x.related_entity_type==='friend_referral'&&x.related_entity_id===b&&x.metadata.source==='friend_referral'));
 }finally{await db.close();}
});

test('twenty queued duplicate requests award exactly once and preserve the once-per-invitee rule',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);const results=await Promise.all(Array.from({length:20},()=>redeem(db,code)));
  assert.equal(results.filter(x=>x.claimed).length,1);assert.equal(results.reduce((sum,x)=>sum+x.awardedPoints,0),100);assert.ok(results.every(x=>x.balance===100));
  assert.deepEqual(await counts(db),{wallets:2,ledger:2,referrals:1});
 }finally{await db.close();}
});

test('invalid, self and reciprocal codes do not create a reward or consume eligibility',async()=>{
 const db=await fixture();try{
  const ca=await ownCode(db,a),cb=await ownCode(db,b);await login(db,a);
  for(const code of[null,'',' ',"x' or true--",'ABCDEFGHIJ','AAAAAAAAAA','A'.repeat(100000)])await assert.rejects(()=>redeem(db,code),/REFERRAL_INVALID_CODE/);
  await assert.rejects(()=>redeem(db,ca),/REFERRAL_SELF_NOT_ALLOWED/);assert.equal((await status(db)).canRedeem,true);assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
  await login(db,a);await redeem(db,cb);await login(db,b);await assert.rejects(()=>redeem(db,ca),/REFERRAL_RECIPROCAL_NOT_ALLOWED/);
  assert.equal((await status(db)).canRedeem,true);assert.deepEqual(await counts(db),{wallets:2,ledger:2,referrals:1});
 }finally{await db.close();}
});

test('permanent active accounts only: anonymous, missing, banned, soft-deleted and no-login requests are denied',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,b);
  await login(db,null,'anon');await assert.rejects(()=>status(db),/permission denied/);await assert.rejects(()=>redeem(db,code),/permission denied/);
  await login(db,null);await assert.rejects(()=>status(db),/REFERRAL_LOGIN_REQUIRED/);
  await login(db,c);await assert.rejects(()=>redeem(db,code),/REFERRAL_ACCOUNT_REQUIRED/);
  for(const patch of['is_anonymous=true',"banned_until='2099-01-01'","deleted_at='2026-10-01'"]){
   await db.exec('reset role');await db.exec(`update auth.users set is_anonymous=false,banned_until=null,deleted_at=null where id='${a}';update auth.users set ${patch} where id='${a}'`);await login(db,a);
   await assert.rejects(()=>status(db),/REFERRAL_ACCOUNT_REQUIRED/);await assert.rejects(()=>redeem(db,code),/REFERRAL_ACCOUNT_REQUIRED/);
  }
  assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
 }finally{await db.close();}
});

test('unverified and expired invitees see clear eligibility, while established verified members can still invite',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await db.exec('reset role');await db.exec(`update auth.users set email_confirmed_at=null where id='${b}'`);await login(db,b);
  let current=await status(db);assert.equal(current.canRedeem,false);assert.equal(current.ineligibleReason,'unverified');await assert.rejects(()=>redeem(db,code),/REFERRAL_UNVERIFIED_ACCOUNT/);
  await db.exec('reset role');await db.exec(`update auth.users set email_confirmed_at='2026-10-25',created_at='2026-10-01'where id='${b}'`);await login(db,b);current=await status(db);assert.equal(current.ineligibleReason,'expired');assert.equal(current.canRedeem,false);await assert.rejects(()=>redeem(db,code),/REFERRAL_WINDOW_EXPIRED/);
  const oldCode=current.ownCode;await login(db,a);const earned=await redeem(db,oldCode);assert.equal(earned.claimed,true);await login(db,b);assert.equal((await status(db)).balance,100);
 }finally{await db.close();}
});

test('unverified, banned and deleted inviters cannot receive rewards via a previously issued code',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);
  for(const patch of['email_confirmed_at=null',"banned_until='2099-01-01'","deleted_at='2026-10-01'",'is_anonymous=true']){
   await db.exec('reset role');await db.exec(`update auth.users set is_anonymous=false,email_confirmed_at='2026-10-25',banned_until=null,deleted_at=null where id='${a}';update auth.users set ${patch} where id='${a}'`);await login(db,b);
   await assert.rejects(()=>redeem(db,code),/REFERRAL_INVALID_CODE/);assert.equal((await status(db)).redeemed,false);
  }
  assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
 }finally{await db.close();}
});

test('seven-day eligibility boundary uses server time, and rechecks after the wallet lock',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await clock(db,'2026-11-01T02:59:59.999Z',b);assert.equal((await status(db)).canRedeem,true);
  await clock(db,'2026-11-01T03:00:00Z',b);assert.equal((await status(db)).ineligibleReason,'expired');await assert.rejects(()=>redeem(db,code),/REFERRAL_WINDOW_EXPIRED/);
  await db.exec('reset role');await db.exec(`create table test_clock.calls(n int);insert into test_clock.calls values(0);
   create or replace function referral_private.server_now()returns timestamptz language plpgsql volatile security invoker set search_path=''as $$declare n int;begin update test_clock.calls set n=test_clock.calls.n+1 returning test_clock.calls.n into n;return case when n=1 then'2026-11-01T02:59:59Z'::timestamptz else'2026-11-01T03:00:00Z'::timestamptz end;end$$;`);
  await login(db,b);await assert.rejects(()=>redeem(db,code),/REFERRAL_WINDOW_EXPIRED/);assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
 }finally{await db.close();}
});

test('inviter monthly cap blocks both payouts at twenty, then resets exactly at KST month boundary',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await clock(db,'2026-10-31T14:59:59Z');
  for(let n=1;n<=20;n++){const uid=user(n);await add(db,uid,'2026-10-30T03:00:00Z');await login(db,uid);assert.equal((await redeem(db,code)).awardedPoints,100);}
  await login(db,a);let inviter=await status(db);assert.equal(inviter.monthlyRewardedCount,20);assert.equal(inviter.remaining,0);assert.equal(inviter.totalEarned,2000);
  const last=user(21);await add(db,last,'2026-10-30T03:00:00Z');await login(db,last);await assert.rejects(()=>redeem(db,code),/REFERRAL_LIMIT_REACHED/);assert.equal((await status(db)).redeemed,false);assert.equal((await status(db)).balance,500);
  await clock(db,'2026-10-31T15:00:00Z',last);assert.equal((await redeem(db,code)).awardedPoints,100);
  await login(db,a);inviter=await status(db);assert.equal(inviter.rewardMonth,'2026-11');assert.equal(inviter.monthlyRewardedCount,1);assert.equal(inviter.remaining,19);assert.equal(inviter.invitedCount,21);assert.equal(inviter.totalEarned,2100);assert.equal(inviter.balance,2100);
  assert.deepEqual(await counts(db),{wallets:22,ledger:63,referrals:21});
 }finally{await db.close();}
});

test('client timezone, dates, amounts and user metadata cannot alter the server policy or actor',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);await db.exec("set timezone='Pacific/Kiritimati'");
  await db.query("select set_config('request.jwt.claims',$1,false),set_config('request.headers',$2,false)",[JSON.stringify({user_metadata:{user_id:a,reward:999999,created_at:'2099-01-01',email_confirmed_at:'2099-01-01'}}),JSON.stringify({'x-client-date':'2099-01-01','x-reward':'999999'})]);
  const result=await redeem(db,code);assert.equal(result.balance,100);assert.equal(result.awardedPoints,100);assert.equal(result.rewardMonth,'2026-10');
  await assert.rejects(()=>db.query('select redeem_referral_code($1,$2,$3)',[code,a,99999]),/does not exist/);await assert.rejects(()=>db.query('select get_referral_status($1)',[a]),/does not exist/);
 }finally{await db.close();}
});

test('private records, helper functions and code lists are unavailable to authenticated and service roles',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);await redeem(db,code);
  for(const statement of['select * from referral_private.codes','select * from referral_private.redemptions',`select referral_private.ensure_code('${a}')`,`select referral_private.status_json('${a}',now(),false,0)`,'select referral_private.server_now()'])await assert.rejects(()=>db.exec(statement),/permission denied/);
  await login(db,b,'service_role');await assert.rejects(()=>db.exec('select * from referral_private.redemptions'),/permission denied/);await assert.rejects(()=>status(db),/permission denied/);
  await login(db,b);const own=await status(db);assert.equal(own.invitedCount,0);assert.equal(own.totalEarned,100);const ledger=(await db.query('select user_id,reason from point_ledger')).rows;assert.deepEqual(ledger,[{user_id:b,reason:'REFERRAL_INVITEE'}]);
 }finally{await db.close();}
});

test('legacy permissive writes cannot forge, edit or delete referral rewards and reserved idempotency keys',async()=>{
 const db=await fixture();try{
  await db.exec("create policy test_legacy_insert on point_ledger for insert to authenticated with check(true);create policy test_legacy_update on point_ledger for update to authenticated using(true)with check(true);create policy test_legacy_delete on point_ledger for delete to authenticated using(true)");
  const code=await ownCode(db,a);await login(db,b);
  const values=[b,`friend_referral:invitee:${b}`,b,JSON.stringify({source:'friend_referral',referralRole:'invitee',ruleVersion:1})];
  await assert.rejects(()=>db.query("insert into point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)values($1,100,'REFERRAL_INVITEE',$2,'friend_referral',$3,$4)",values),/row-level security/);
  await assert.rejects(()=>db.query("insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,100,'ADMIN_ADJUSTMENT',$2)",[b,`friend_referral:other:${b}`]),/referral_ledger_invalid/);
  await redeem(db,code);
  for(const statement of["update point_ledger set amount_delta=1000 where reason='REFERRAL_INVITEE'","delete from point_ledger where reason='REFERRAL_INVITEE'"])await assert.rejects(()=>db.exec(statement),/referral_ledger_immutable/);
  await db.exec('reset role');for(const statement of['update referral_private.redemptions set points=200','delete from referral_private.redemptions'])await assert.rejects(()=>db.exec(statement),/referral_record_immutable/);
  assert.deepEqual(await counts(db),{wallets:2,ledger:2,referrals:1});
 }finally{await db.close();}
});

test('integer overflow rolls back both credits and registration; existing refund debt is not forgiven',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await db.exec('reset role');await db.query('insert into point_wallets(user_id,balance)values($1,2147483600),($2,-200)',[a,b]);await login(db,b);
  await assert.rejects(()=>redeem(db,code),e=>e.code==='22003');assert.deepEqual(await counts(db),{wallets:2,ledger:0,referrals:0});assert.deepEqual(await wallets(db),[{user_id:a,balance:2147483600},{user_id:b,balance:-200}]);
  await db.query('update point_wallets set balance=0 where user_id=$1',[a]);await login(db,b);const result=await redeem(db,code);assert.equal(result.balance,-100);assert.equal(result.awardedPoints,100);
  assert.deepEqual(await wallets(db),[{user_id:a,balance:100},{user_id:b,balance:-100}]);
 }finally{await db.close();}
});

test('deleting an inviter keeps the invitee redeemed, and deleted-account JWTs cannot issue another reward',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);await redeem(db,code);await db.exec('reset role');await db.query('delete from auth.users where id=$1',[a]);
  await login(db,b);let own=await status(db);assert.equal(own.redeemed,true);assert.equal(own.totalEarned,100);assert.equal((await redeem(db,code)).awardedPoints,0);
  await db.exec('reset role');assert.equal((await db.query('select inviter_id from referral_private.redemptions')).rows[0].inviter_id,null);
  await login(db,a);await assert.rejects(()=>redeem(db,own.ownCode),/REFERRAL_ACCOUNT_REQUIRED/);
  await db.exec('reset role');await db.query('delete from auth.users where id=$1',[b]);assert.deepEqual(await counts(db),{wallets:0,ledger:0,referrals:0});
 }finally{await db.close();}
});

test('deleting an invitee does not erase the inviter earned totals or release a paid monthly slot',async()=>{
 const db=await fixture();try{
  const code=await ownCode(db,a);await login(db,b);await redeem(db,code);await db.exec('reset role');await db.query('delete from auth.users where id=$1',[b]);await login(db,a);
  const own=await status(db);assert.equal(own.invitedCount,1);assert.equal(own.monthlyRewardedCount,1);assert.equal(own.remaining,19);assert.equal(own.totalEarned,100);assert.equal(own.balance,100);
  assert.deepEqual(await counts(db),{wallets:1,ledger:1,referrals:0});
 }finally{await db.close();}
});

test('migration preserves every existing wallet, ledger, product and ownership plus existing callable function definitions',async()=>{
 let baseline;
 const snapshot=async db=>(await db.query(`select jsonb_build_object('wallets',(select jsonb_agg(to_jsonb(t)order by user_id)from point_wallets t),'ledger',(select jsonb_agg(to_jsonb(t)order by id)from point_ledger t),'products',(select jsonb_agg(to_jsonb(t)order by product_key)from point_shop_products t),'ownership',(select jsonb_agg(to_jsonb(t)order by user_id,product_key)from point_shop_ownership t),'functions',(select jsonb_agg(jsonb_build_object('name',p.oid::regprocedure::text,'md5',md5(pg_get_functiondef(p.oid)))order by p.oid::regprocedure::text)from pg_proc p where p.oid in('public.grant_signup_bonus()'::regprocedure,'public.purchase_point_shop_product(text,integer)'::regprocedure,'public.get_attendance_status()'::regprocedure,'public.claim_daily_attendance()'::regprocedure)))state`)).rows[0].state;
 const db=await fixture({beforeReferral:async db=>{
  await db.exec("insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)values('frame:existing','existing','frame','Existing',100,true)");await db.query('insert into point_wallets(user_id,balance)values($1,500)',[a]);await login(db,a);await db.query("select purchase_point_shop_product('frame:existing',100)");await db.exec('reset role');baseline=await snapshot(db);
 }});try{
  assert.deepEqual(await snapshot(db),baseline);const code=await ownCode(db,a);await login(db,b);await redeem(db,code);await db.exec('reset role');
  const after=await snapshot(db);assert.deepEqual(after.products,baseline.products);assert.deepEqual(after.ownership,baseline.ownership);assert.deepEqual(after.functions,baseline.functions);assert.deepEqual(after.ledger.filter(x=>x.reason==='DIGITAL_ITEM_PURCHASE'),baseline.ledger);
 }finally{await db.close();}
});

test('signup bonus, attendance, product purchase and refund/custom allowed reasons continue to coexist',async()=>{
 const db=await fixture({beforeReferral:async db=>{
  await db.exec("alter table point_ledger drop constraint point_ledger_reason_check;alter table point_ledger add constraint point_ledger_reason_check check(reason in('AI_ALBUM_DRAFT_FREE','AI_ALBUM_DRAFT_CHARGE','ADMIN_ADJUSTMENT','POINT_PURCHASE','DIGITAL_ITEM_PURCHASE','SIGNUP_BONUS','POINT_PURCHASE_REFUND','DAILY_ATTENDANCE','EXISTING_CUSTOM_REASON'))");
 }});try{
  await add(db,c);await login(db,c);assert.equal((await status(db)).balance,500);assert.equal((await db.query('select claim_daily_attendance()result')).rows[0].result.balance,510);
  const code=await ownCode(db,a);await login(db,c);assert.equal((await redeem(db,code)).balance,610);
  await db.exec('reset role');await db.exec("insert into point_shop_products(product_key,asset_id,kind,title,point_price,is_active)values('frame:existing','existing','frame','Existing',100,true)");await login(db,c);await db.query("select purchase_point_shop_product('frame:existing',100)");assert.equal((await status(db)).balance,510);
  await db.exec('reset role');for(const reason of['POINT_PURCHASE_REFUND','EXISTING_CUSTOM_REASON'])await db.query('insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,-10,$2,$2)',[c,reason]);
  await assert.rejects(()=>db.query("insert into point_ledger(user_id,amount_delta,reason,idempotency_key)values($1,1,'NOT_ALLOWED','forged')",[c]),/point_ledger_reason_check/);
 }finally{await db.close();}
});

import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {fixture as base,login,entry,api,save,publish,a,b,id,rid,pid,photo,second} from './helpers/social_safety_fixture.mjs';

const migration=readFileSync(new URL('../../supabase/migrations/20261030093518_private_moment_archive_and_weekly_choices.sql',import.meta.url),'utf8');
async function fixture(){
 const db=await base();
 await db.exec('reset role');
 await db.exec("create or replace function moments_private.server_now() returns timestamptz language sql volatile as $$select '2026-11-04T03:00:00Z'::timestamptz$$");
 await db.exec(migration);await login(db);return db;
}
const months=async(db,before=null,limit=6)=>(await db.query('select get_my_moment_months($1::date,$2::int)r',[before,limit])).rows[0].r;
const weekly=async(db,week='2026-10-26')=>(await db.query('select get_moment_week_photo_choices($1::date)r',[week])).rows[0].r;
const monthly=async(db,month='2026-10-01')=>(await db.query('select get_moment_month_photo_choices($1::date)r',[month])).rows[0].r;
const choose=async(db,ids=[pid],week='2026-10-26')=>(await db.query('select save_moment_week_photo_choices($1::date,$2::uuid[])r',[week,ids])).rows[0].r;

test('private month summaries include unpublished originals and seek older months without duplicates',async()=>{
 const db=await fixture();try{
  for(let n=1;n<=8;n++)await entry(db,300+n,`2026-${String(n).padStart(2,'0')}-15`,{status:'private'});
  const november=await entry(db,310,'2026-11-01',{status:'private'});
  const first=await months(db,null,3);assert.deepEqual(first.map(x=>x.month),['2026-11-01','2026-10-01','2026-08-01']);
  assert.equal(first[0].coverPhoto.id,november.photo.id);assert.equal(first[0].recordCount,1);assert.equal(first[1].photoCount,2);
  const next=await months(db,first.at(-1).month,3);assert.deepEqual(next.map(x=>x.month),['2026-07-01','2026-06-01','2026-05-01']);
  assert.equal(new Set([...first,...next].map(x=>x.month)).size,6);
  assert.equal((await api(db,'feed')).items.length,0);
 }finally{await db.close();}
});

test('another account cannot ask for an owner and sees only its own archive and choices',async()=>{
 const db=await fixture();try{
  await choose(db);const own=await months(db);assert.equal(own.length,1);
  await login(db,b);assert.deepEqual(await months(db),[]);assert.deepEqual(await weekly(db),[]);assert.deepEqual(await monthly(db),[]);
  await assert.rejects(()=>choose(db),/MOMENTS_SELECTION_CHANGED/);
  await assert.rejects(()=>db.query('select get_my_moment_months($1::uuid,$2::date,$3)',[a,null,6]),/does not exist/);
  await login(db);assert.deepEqual(await weekly(db),[pid]);assert.equal((await months(db))[0].coverPhoto.path,photo.path);
 }finally{await db.close();}
});

test('guests, anonymous, missing, banned and deleted actors cannot read or write private archive APIs',async()=>{
 const db=await fixture();try{
  await login(db,null,'anon');for(const call of[()=>months(db),()=>weekly(db),()=>monthly(db),()=>choose(db)])await assert.rejects(call,/permission denied/);
  await login(db,null);await assert.rejects(()=>months(db),/MOMENTS_LOGIN_REQUIRED/);
  for(const mutation of["is_anonymous=true","is_anonymous=false,banned_until='2099-01-01'","banned_until=null,deleted_at=now()"]){
   await db.exec('reset role');await db.query(`update auth.users set ${mutation} where id=$1`,[a]);await login(db);
   for(const call of[()=>months(db),()=>weekly(db),()=>monthly(db),()=>choose(db)])await assert.rejects(call,/MOMENTS_ACCOUNT_REQUIRED/);
  }
  await login(db,id(999999));await assert.rejects(()=>months(db),/MOMENTS_ACCOUNT_REQUIRED/);
 }finally{await db.close();}
});

test('weekly selections cross the month boundary and each month contains only its own actual record dates',async()=>{
 const db=await fixture();try{
  const november=await entry(db,320,'2026-11-01',{status:'private'});await choose(db,[november.photo.id,pid]);
  assert.deepEqual(await weekly(db),[november.photo.id,pid]);assert.deepEqual(await monthly(db),[pid]);
  assert.deepEqual(await monthly(db,'2026-11-01'),[november.photo.id]);
 }finally{await db.close();}
});

test('replacing one week preserves other weeks and repeated saves are idempotent without album or social mutations',async()=>{
 const db=await fixture();try{
  const prior=await entry(db,330,'2026-10-20',{status:'private'});await choose(db,[prior.photo.id],'2026-10-19');
  const snapshot=JSON.stringify((await months(db)));await choose(db,[pid,second.id]);await choose(db,[pid,second.id]);
  assert.deepEqual(await monthly(db),[prior.photo.id,pid,second.id]);assert.equal(JSON.stringify(await months(db)),snapshot);
  await choose(db,[]);assert.deepEqual(await weekly(db),[]);assert.deepEqual(await monthly(db),[prior.photo.id]);
  assert.equal((await api(db,'feed')).items.length,0);await db.exec('reset role');
  assert.equal((await db.query('select count(*)::int n from public.albums')).rows[0].n,1);
  const stamp=(await db.query('select updated_at from moments_private.week_photo_choices where owner_id=$1 and week_start=$2',[a,'2026-10-19'])).rows[0].updated_at;
  await login(db);await choose(db,[prior.photo.id],'2026-10-19');await db.exec('reset role');
  assert.equal(String((await db.query('select updated_at from moments_private.week_photo_choices where owner_id=$1 and week_start=$2',[a,'2026-10-19'])).rows[0].updated_at),String(stamp));
 }finally{await db.close();}
});

test('unknown, out-of-week, duplicate and excessive choices fail before mutation',async()=>{
 const db=await fixture();try{
  const prior=await entry(db,340,'2026-10-20',{status:'private'});
  for(const ids of[[id(9999)],[prior.photo.id],[pid,pid],[pid,second.id,id(9999),id(9998)],[null],null])await assert.rejects(()=>choose(db,ids),/MOMENTS_SELECTION_CHANGED|MOMENTS_INVALID_SELECTION/);
  for(const week of[null,'2026-10-27','1899-12-25','2026-11-09'])await assert.rejects(()=>choose(db,[],week),/MOMENTS_INVALID_WEEK/);
  assert.deepEqual(await weekly(db),[]);
 }finally{await db.close();}
});

test('deleted photos are pruned and moving a record never silently moves its weekly curation',async()=>{
 const db=await fixture();try{
  await choose(db,[pid,second.id]);await save(db,{photos:[second],revision:1});
  assert.deepEqual(await weekly(db),[second.id]);assert.deepEqual(await monthly(db),[second.id]);
  await save(db,{photos:[second],date:'2026-10-20',revision:2});
  assert.deepEqual(await weekly(db),[]);assert.deepEqual(await weekly(db,'2026-10-19'),[]);
  await choose(db,[second.id],'2026-10-19');await db.query('select delete_weekly_moment($1,3)',[rid]);
  assert.deepEqual(await monthly(db),[]);assert.deepEqual(await months(db),[]);
 }finally{await db.close();}
});

test('private raw photos and curation never appear in visitor profiles or public feed',async()=>{
 const db=await fixture();try{
  const work=await publish(db);await choose(db,[second.id]);
  await login(db,b);const feed=await api(db,'feed');assert.equal(feed.items[0].id,work.id);
  const collection=await api(db,'profileMomentMonthsPage',{userId:a});
  for(const value of[feed,collection])for(const secret of[photo.path,second.path,second.id,'week_photo_choices','photo_ids','album-assets'])assert.equal(JSON.stringify(value).includes(secret),false,secret);
  assert.equal((await db.query("select * from storage.objects where bucket_id='album-assets'")).rows.length,0);
 }finally{await db.close();}
});

test('new tables deny direct access and public wrappers remain security invokers with explicit grants',async()=>{
 const db=await fixture();try{
  for(const role of['authenticated','anon','service_role']){await login(db,role==='anon'?null:a,role);await assert.rejects(()=>db.query('select * from moments_private.week_photo_choices'),/permission denied/);}
  await db.exec('reset role');const rows=(await db.query("select p.proname,p.prosecdef,has_function_privilege('anon',p.oid,'execute') anon,has_function_privilege('authenticated',p.oid,'execute') authenticated from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in('get_my_moment_months','get_moment_week_photo_choices','get_moment_month_photo_choices','save_moment_week_photo_choices')")).rows;
  assert.equal(rows.length,4);assert.ok(rows.every(r=>!r.prosecdef&&!r.anon&&r.authenticated));
  assert.equal((await db.query("select relrowsecurity from pg_class where oid='moments_private.week_photo_choices'::regclass")).rows[0].relrowsecurity,true);
 }finally{await db.close();}
});

test('invalid archive cursors and limits cannot expand the private query',async()=>{
 const db=await fixture();try{
  for(const before of['2026-10-02','1899-01-01','2027-01-01'])await assert.rejects(()=>months(db,before),/MOMENTS_INVALID_MONTH/);
  for(const limit of[null,0,-1,13,1000000])await assert.rejects(()=>months(db,null,limit),/MOMENTS_INVALID_MONTH/);
  assert.deepEqual(await months(db,'1900-01-01'),[]);
 }finally{await db.close();}
});

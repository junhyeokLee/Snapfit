import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const migration = readFileSync(new URL('../../supabase/migrations/20261025062446_social_publication_and_profiles.sql', import.meta.url), 'utf8');
const legacyFallbackMigration = readFileSync(new URL('../../supabase/migrations/20261025062938_social_legacy_empty_pages_fallback.sql', import.meta.url), 'utf8');
const topicTaxonomyMigration = readFileSync(new URL('../../supabase/migrations/20261025073121_social_topic_taxonomy.sql', import.meta.url), 'utf8');
const followStateMigration = readFileSync(new URL('../../supabase/migrations/20261025073122_social_idempotent_follow_state.sql', import.meta.url), 'utf8');
const profilePhotoMigration = readFileSync(new URL('../../supabase/migrations/20261025074127_social_public_profile_photos.sql', import.meta.url), 'utf8');
const reactionStateMigration = readFileSync(new URL('../../supabase/migrations/20261025082024_social_idempotent_reaction_state.sql', import.meta.url), 'utf8');
const commentRetryMigration = readFileSync(new URL('../../supabase/migrations/20261025082810_social_idempotent_comments.sql', import.meta.url), 'utf8');
const publicationConflictMigration = readFileSync(new URL('../../supabase/migrations/20261025083353_social_publication_conflict_http_status.sql', import.meta.url), 'utf8');
const collaborationHistoryMigration = readFileSync(new URL('../../supabase/migrations/20261025092245_collaborative_album_publication_history.sql', import.meta.url), 'utf8');
const pagedMigration = readFileSync(new URL('../../supabase/migrations/20261026064733_social_paginated_collections.sql', import.meta.url), 'utf8');
const templateCategorySource = readFileSync(new URL('../../lib/core/templates/template_catalog_categories.dart', import.meta.url), 'utf8');
const canonicalTopics = [...templateCategorySource.match(/const templateTopicOrder = \[([\s\S]*?)\];/)[1].matchAll(/'([^']+)'/g)].map(match=>match[1]).concat('기타');
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
const c='33333333-3333-4333-8333-333333333333';

async function fixture({topics=true,paged=true}={}){
 const db=new PGlite();
 await db.exec(`create role anon; create role authenticated; create role service_role;
 create schema auth; create schema storage; create schema private; create schema album_private;
 revoke all on schema album_private from public,anon,authenticated;
 revoke all on schema private from public,anon,authenticated;
 create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth,storage to anon,authenticated;
 create table public.profiles(id uuid primary key,email text,name text,avatar_url text);
 insert into public.profiles values ('${a}','private@example.invalid','PRIVATE_ACCOUNT_NAME','https://private.invalid/avatar');
 create table public.albums(id bigint primary key,owner_id uuid references auth.users,cover_layers_json text,ratio text,updated_at timestamptz not null default now());
 create table public.album_members(album_id bigint references public.albums,user_id uuid references auth.users,status text default 'ACCEPTED');
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(bucket_id text,name text,metadata jsonb,primary key(bucket_id,name));
 alter table storage.objects enable row level security;
 grant select,insert,update,delete on storage.objects to anon,authenticated;
 insert into auth.users values('${a}'),('${b}'),('${c}');
 insert into public.albums(id,owner_id,cover_layers_json,ratio) values
 (10,'${a}','{"pages":[{"source":"PRIVATE_SOURCE_URL"},{},{}],"private":"PRIVATE_DOCUMENT"}','3:4'),
 (20,'${b}','{"pages":[{},{}]}','1:1');`);
 await db.exec(migration);
 await db.exec(legacyFallbackMigration);
 if(topics){await db.exec(topicTaxonomyMigration);await db.exec(followStateMigration);await db.exec(profilePhotoMigration);await db.exec(reactionStateMigration);await db.exec(commentRetryMigration);await db.exec(publicationConflictMigration);await db.exec(collaborationHistoryMigration);if(paged)await db.exec(pagedMigration);}
 return db;
}
async function as(db,user,role='authenticated'){
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user??'']);
 await db.exec(`set role ${role}`);
}
async function api(db,action,payload={}){
 return (await db.query('select public.social_api($1,$2::jsonb) result',[action,JSON.stringify(payload)])).rows[0].result;
}
async function draft(db,overrides={}){
 return api(db,'beginPublication',{albumId:10,pageIndexes:[0,2],title:'Selected pages',topic:'여행',...overrides});
}
async function upload(db,id,position){
 const slot=await api(db,'publicationUploadPath',{id,position});
 await db.query("insert into storage.objects values('social-snapshots',$1,$2::jsonb)",[slot.path,JSON.stringify({mimetype:'image/png',size:1024})]);
 return slot.path;
}
async function publish(db){
 await as(db,a); const d=await draft(db);
 await upload(db,d.id,0);await upload(db,d.id,1);
 return api(db,'finalizePublication',{id:d.id});
}

// These are SQL behavior tests running the actual migrations under anon and
// authenticated roles. Synthetic fixture insertion below is local PGlite only.
async function seedWorks(db,count=31){
 await as(db,a);await api(db,'ensureProfile');
 await as(db,b);await api(db,'ensureProfile');
 await db.exec('reset role');
 await db.query(`insert into public.social_works(id,author_id,title,topic,status,published_at,created_at)
  select ('00000000-0000-4000-8000-'||lpad(g::text,12,'0'))::uuid,$1,'Journal '||g,'여행','published','2026-10-26','2026-10-26'
  from generate_series(1,$2)g`,[a,count]);
 return (await db.query('select id from public.social_works order by id desc')).rows.map(r=>r.id);
}
async function collect(db,action,payload={}){
 const all=[];let offset=0;
 for(let i=0;i<100;i++){
  const page=await api(db,action,{...payload,offset,limit:12});
  assert.ok(page.items.length<=12);assert.equal(page.nextOffset,offset+page.items.length);
  all.push(...page.items);
  if(!page.hasMore)return all;
  assert.ok(page.nextOffset>offset);offset=page.nextOffset;
 }
 assert.fail('pagination did not terminate');
}

test('31st work is reachable in profile, own, saved and search pages with deterministic ties; legacy arrays stay compatible',async()=>{
 const db=await fixture();try{
  const ids=await seedWorks(db);
  await as(db,a);
  assert.equal((await api(db,'ownWorks')).length,30);
  assert.deepEqual((await collect(db,'ownWorksPage')).map(w=>w.id),ids);
  await as(db,b);
  for(const id of ids)await api(db,'setSaved',{id,saved:true});
  assert.equal((await api(db,'savedWorks')).length,30);
  assert.deepEqual((await collect(db,'savedWorksPage')).map(w=>w.id),ids);
  await as(db,null,'anon');
  assert.equal((await api(db,'profileWorks',{userId:a})).length,30);
  assert.equal((await api(db,'search',{query:'Journal'})).length,30);
  for(const [action,payload]of [['profileWorksPage',{userId:a}],['searchPage',{query:'Journal'}]]){
   assert.deepEqual((await collect(db,action,payload)).map(w=>w.id),ids);
   const empty=await api(db,action,{...payload,offset:31});
   assert.deepEqual(empty,{items:[],hasMore:false,nextOffset:31});
  }
 }finally{await db.close();}
});

test('new work pages preserve own-private, withdrawn/deleted/draft, block and anonymous boundaries',async()=>{
 const db=await fixture();try{
  const ids=await seedWorks(db,5);
  await db.query(`update public.social_works set status=case id when $1::uuid then 'private' when $2::uuid then 'deleted' when $3::uuid then 'draft' else status end`,[ids[0],ids[1],ids[2]]);
  await as(db,a);
  assert.deepEqual((await collect(db,'ownWorksPage')).map(w=>w.id),[ids[0],...ids.slice(3)]);
  await as(db,b);
  for(const id of ids.slice(3))await api(db,'setSaved',{id,saved:true});
  await api(db,'setBlocked',{userId:a,blocked:true});
  for(const [action,payload]of [['savedWorksPage',{}],['profileWorksPage',{userId:a}],['searchPage',{query:'Journal'}]]){
   assert.deepEqual((await api(db,action,payload)).items,[]);
  }
  await as(db,null,'anon');
  for(const action of ['ownWorksPage','savedWorksPage'])await assert.rejects(()=>api(db,action),/social_login_required/);
  assert.deepEqual((await collect(db,'profileWorksPage',{userId:a})).map(w=>w.id),ids.slice(3));
  assert.deepEqual((await collect(db,'searchPage',{query:'Journal'})).map(w=>w.id),ids.slice(3));
 }finally{await db.close();}
});

async function seedProfiles(db,count=31){
 await as(db,a);await api(db,'ensureProfile');
 await db.exec('reset role');
 const ids=[];
 for(let i=1;i<=count;i++){
  const id=`44444444-4444-4444-8444-${String(i).padStart(12,'0')}`;
  await db.query('insert into auth.users values($1)',[id]);
  await db.query("insert into public.social_profiles(user_id,display_name,handle)values($1,'Discovery creator',$2)",[id,`creator_${String(i).padStart(3,'0')}`]);
  await db.query("insert into public.social_follows(follower_id,following_id,created_at)values($1,$2,'2026-10-26'),($2,$1,'2026-10-26')",[a,id]);
  ids.push(id);
 }
 return ids;
}

test('31st creator and both relation directions remain reachable, with stable ordering and blocked-row filtering before pagination',async()=>{
 const db=await fixture();try{
  const ids=await seedProfiles(db);
  await as(db,null,'anon');
  assert.equal((await api(db,'searchProfiles',{query:'Discovery'})).length,30);
  assert.deepEqual((await collect(db,'searchProfilesPage',{query:'Discovery'})).map(p=>p.userId),ids);
  for(const followers of[true,false])assert.deepEqual((await collect(db,'relationsPage',{userId:a,followers})).map(p=>p.userId),ids);
  await as(db,a);await api(db,'setBlocked',{userId:ids[0],blocked:true});
  assert.deepEqual((await collect(db,'searchProfilesPage',{query:'Discovery'})).map(p=>p.userId),ids.slice(1));
  for(const followers of[true,false])assert.deepEqual((await collect(db,'relationsPage',{userId:a,followers})).map(p=>p.userId),ids.slice(1));
  assert.deepEqual((await api(db,'relationsPage',{userId:ids[0]})).items,[]);
 }finally{await db.close();}
});

test('new pages validate offset, clamp page size, handle empty queries, and never project private source fields',async()=>{
 const db=await fixture();try{
  await seedWorks(db,31);await as(db,null,'anon');
  for(const action of['profileWorksPage','searchPage','searchProfilesPage','relationsPage']){
   for(const offset of[-1,10001])await assert.rejects(()=>api(db,action,{offset,userId:a,query:'Journal'}),/social_invalid_page_offset/);
  }
  const maximum=await api(db,'profileWorksPage',{userId:a,limit:1000});assert.equal(maximum.items.length,30);assert.equal(maximum.hasMore,true);
  assert.equal((await api(db,'profileWorksPage',{userId:a,limit:0})).items.length,1);
  for(const query of['','   ','a'.repeat(81)])for(const action of['searchPage','searchProfilesPage'])assert.deepEqual((await api(db,action,{query})).items,[]);
  for(const forbidden of['source_album','cover_layers','email','PRIVATE_'])assert.equal(JSON.stringify(maximum).includes(forbidden),false);
  const security=(await db.query("select prosecdef,proconfig,has_function_privilege('anon',oid,'EXECUTE')anon_execute from pg_proc where oid='social_private.social_api(text,jsonb)'::regprocedure")).rows[0];
  assert.equal(security.prosecdef,true);assert.deepEqual(security.proconfig,['search_path=""']);assert.equal(security.anon_execute,true);
 }finally{await db.close();}
});

test('101st comment remains reachable newest first with stable ties, while legacy latest-100 order is preserved',async()=>{
 const db=await fixture();try{
  const [id]=await seedWorks(db,1);
  await db.query(`insert into public.social_comments(id,work_id,author_id,body,created_at)
   select ('55555555-5555-4555-8555-'||lpad(g::text,12,'0'))::uuid,$1,$2,'Comment '||g,'2026-10-26'
   from generate_series(1,101)g`,[id,b]);
  const expected=(await db.query('select id from public.social_comments order by created_at desc,id desc')).rows.map(r=>r.id);
  await as(db,null,'anon');
  const old=await api(db,'comments',{id});assert.equal(old.length,100);assert.deepEqual(old.map(c=>c.id),expected.slice(0,100).reverse());
  assert.deepEqual((await collect(db,'commentsPage',{id})).map(c=>c.id),expected);
  assert.deepEqual(await api(db,'commentsPage',{id,offset:101}),{items:[],hasMore:false,nextOffset:101});
  for(const offset of[-1,10001])await assert.rejects(()=>api(db,'commentsPage',{id,offset}),/social_invalid_page_offset/);
 }finally{await db.close();}
});

test('comment pages filter blocked authors before offset, obey work visibility and preserve deletion ownership',async()=>{
 const db=await fixture();try{
  const [id]=await seedWorks(db,1);
  await as(db,c);await api(db,'ensureProfile');
  await db.exec('reset role');
  await db.query(`insert into public.social_comments(id,work_id,author_id,body,created_at)
   select ('66666666-6666-4666-8666-'||lpad(g::text,12,'0'))::uuid,$1,case when g%2=0 then $2::uuid else $3::uuid end,'Comment '||g,'2026-10-26'
   from generate_series(1,31)g`,[id,b,c]);
  const byB=(await db.query('select id from public.social_comments where author_id=$1 order by created_at desc,id desc',[b])).rows.map(r=>r.id);
  const byC=(await db.query('select id from public.social_comments where author_id=$1 order by created_at desc,id desc',[c])).rows.map(r=>r.id);
  await as(db,b);
  await assert.rejects(()=>api(db,'deleteComment',{id:byC[0]}),/social_comment_owner_required/);
  await api(db,'deleteComment',{id:byB[0]});
  await as(db,a);await api(db,'setBlocked',{userId:c,blocked:true});
  assert.deepEqual((await collect(db,'commentsPage',{id})).map(c=>c.id),byB.slice(1));
  assert.equal((await api(db,'work',{id})).commentCount,byB.length-1);
  await api(db,'deleteComment',{id:byC[0]});
  await api(db,'visibility',{id,published:false});
  assert.deepEqual((await collect(db,'commentsPage',{id})).map(c=>c.id),byB.slice(1));
  for(const actor of[b,c,null]){
   await as(db,actor,actor?'authenticated':'anon');
   assert.deepEqual((await api(db,'commentsPage',{id})).items,[]);
  }
  await as(db,a);await api(db,'deleteWork',{id});assert.deepEqual((await api(db,'commentsPage',{id})).items,[]);
  await as(db,null,'anon');assert.deepEqual((await api(db,'commentsPage',{id:'99999999-9999-4999-8999-999999999999'})).items,[]);
 }finally{await db.close();}
});

test('paged dispatcher preserves accepted collaboration history after a member leaves and denies begin/finalize bypasses',async()=>{
 const db=await fixture();try{
  await as(db,a);const d=await draft(db);await upload(db,d.id,0);await upload(db,d.id,1);
  await db.exec('reset role');
  await db.query("insert into public.album_members(album_id,user_id,status)values(10,$1,'ACCEPTED')",[b]);
  await db.query('delete from public.album_members where album_id=10 and user_id=$1',[b]);
  assert.equal((await db.query('select source_was_collaborative from social_private.social_publication_sources where work_id=$1',[d.id])).rows[0].source_was_collaborative,true);
  await as(db,a);
  await assert.rejects(()=>draft(db),/social_collaborative_album_unsupported/);
  await assert.rejects(()=>api(db,'finalizePublication',{id:d.id}),/social_collaborative_album_unsupported/);
  await assert.rejects(()=>db.query('select album_private.was_collaborative(10)'),/permission denied/);
 }finally{await db.close();}
});

test('paged dispatcher preserves the republish barrier after collaboration/removal and original album deletion',async()=>{
 const db=await fixture();try{
  const w=await publish(db);
  await db.exec('reset role');
  await db.query("insert into public.album_members(album_id,user_id,status)values(10,$1,'ACCEPTED')",[b]);
  await db.query('delete from public.album_members where album_id=10 and user_id=$1',[b]);
  await as(db,a);
  assert.equal((await api(db,'work',{id:w.id})).status,'published');
  assert.deepEqual((await collect(db,'profileWorksPage',{userId:a})).map(w=>w.id),[w.id]);
  await api(db,'visibility',{id:w.id,published:false});
  await assert.rejects(()=>api(db,'visibility',{id:w.id,published:true}),/social_collaborative_album_unsupported/);
  await db.exec('reset role');await db.exec('delete from public.albums where id=10');
  await as(db,a);
  await assert.rejects(()=>api(db,'visibility',{id:w.id,published:true}),/social_collaborative_album_unsupported/);
  assert.equal((await collect(db,'ownWorksPage')).length,1);
  await as(db,null,'anon');assert.deepEqual((await api(db,'profileWorksPage',{userId:a})).items,[]);
 }finally{await db.close();}
});

test('pagination inherits the exact production collaboration dispatcher definition and only adds a read branch',async()=>{
 const db=await fixture({paged:false});try{
  const before=(await db.query("select pg_get_functiondef(oid) definition,prosrc,md5(pg_get_functiondef(oid)) definition_md5 from pg_proc where oid='social_private.social_api(text,jsonb)'::regprocedure")).rows[0];
  // Observed read-only on production 2026-10-26 before this additive migration.
  assert.equal(before.definition_md5,'e528d6c1aada12627f61a43e6e1b8c4c');
  await db.exec(pagedMigration);
  const after=(await db.query("select prosrc from pg_proc where oid='social_private.social_api(text,jsonb)'::regprocedure")).rows[0].prosrc;
  const start=after.indexOf(' -- Paged actions');
  const end=after.indexOf(" if p_action in ('feed','profileWorks','search','savedWorks','ownWorks')",start);
  assert.ok(start>0);assert.ok(end>start);
  assert.equal((after.slice(0,start)+after.slice(end)).trim(),before.prosrc.trim());
 }finally{await db.close();}
});

test('own work status filters run before offset across interleaved collections larger than 30 and reject invalid states',async()=>{
 const db=await fixture();try{
  const allIds=await seedWorks(db,68);
  await db.query("update public.social_works set status='private' where mod(right(id::text,12)::integer,2)=1");
  await db.query("insert into public.social_works(author_id,title,status,published_at)values($1,'Other public','published','2026-10-27'),($1,'Other private','private','2026-10-27')",[b]);
  const privateIds=allIds.filter(id=>Number(id.slice(-12))%2===1);
  const publicIds=allIds.filter(id=>Number(id.slice(-12))%2===0);
  await as(db,a);
  assert.deepEqual((await collect(db,'ownWorksPage')).map(w=>w.id),allIds);
  assert.deepEqual((await collect(db,'ownWorksPage',{status:'all'})).map(w=>w.id),allIds);
  assert.deepEqual((await collect(db,'ownWorksPage',{status:null})).map(w=>w.id),allIds);
  for(const [status,expected]of [['public',publicIds],['private',privateIds]]){
   assert.equal(expected.length,34);
   assert.deepEqual((await collect(db,'ownWorksPage',{status})).map(w=>w.id),expected);
   const tail=await api(db,'ownWorksPage',{status,offset:30,limit:12});
   assert.deepEqual(tail.items.map(w=>w.id),expected.slice(30));assert.equal(tail.hasMore,false);assert.equal(tail.nextOffset,34);
  }
  for(const status of['published','','draft','deleted','PUBLIC',true,1,[],{}]){
   await assert.rejects(()=>api(db,'ownWorksPage',{status}),e=>e.code==='22023'&&e.message==='social_invalid_work_status_filter');
  }
  await as(db,b);
  assert.equal((await collect(db,'ownWorksPage',{status:'private'})).length,1);
  await as(db,null,'anon');await assert.rejects(()=>api(db,'ownWorksPage',{status:'private'}),/social_login_required/);
 }finally{await db.close();}
});

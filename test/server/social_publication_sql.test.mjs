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

async function fixture({topics=true}={}){
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
 if(topics){await db.exec(topicTaxonomyMigration);await db.exec(followStateMigration);await db.exec(profilePhotoMigration);await db.exec(reactionStateMigration);await db.exec(commentRetryMigration);await db.exec(publicationConflictMigration);await db.exec(collaborationHistoryMigration);await db.exec(pagedMigration);}
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

test('public projection never copies private account/album fields; own safe profile is idempotent',async()=>{
 const db=await fixture();try{
  await as(db,a); const first=await api(db,'ensureProfile');
  assert.equal(first.displayName,'나의 기록');assert.equal(first.avatarUrl,null);
  assert.deepEqual(await api(db,'ensureProfile'),first);
  await api(db,'upsertProfile',{displayName:'Public name',handle:'public.name',bio:'Public introduction',userId:b});
  const work=await publish(db);
  assert.equal(work.aspectRatio,0.75);
  await as(db,null,'anon'); const feed=await api(db,'feed');
  assert.equal(feed.items.length,1);assert.equal(feed.items[0].author.userId,a);
  const serialized=JSON.stringify(feed);
  for(const forbidden of ['PRIVATE_','private@example','albumId','source_album','cover_layers','email','avatar.invalid'])assert.equal(serialized.includes(forbidden),false,forbidden);
  const columns=(await db.query("select column_name from information_schema.columns where table_schema='public' and table_name='social_works'")).rows.map(x=>x.column_name);
  assert.equal(columns.includes('source_album_id'),false);
  await assert.rejects(()=>db.query('select * from social_private.social_publication_sources'),/permission denied/);
 }finally{await db.close();}
});

test('owner-only, collaborative restriction, selected page bounds and duplicate guards are enforced by the server',async()=>{
 const db=await fixture();try{
  await as(db,b);await assert.rejects(()=>draft(db),/social_album_owner_required/);
  await as(db,a);
  for(const pageIndexes of [[],[3],[-1],[0,0],Array.from({length:21},(_,i)=>i)])await assert.rejects(()=>draft(db,{pageIndexes}),/social_invalid_pages/);
  await db.exec('reset role');await db.query('insert into public.album_members(album_id,user_id) values(10,$1)',[b]);
  await as(db,a);await assert.rejects(()=>draft(db),/social_collaborative_album_unsupported/);
 }finally{await db.close();}
});

test('draft snapshots are private; finalize requires every page and is atomic and idempotent',async()=>{
 const db=await fixture();try{
  await as(db,a);const d=await draft(db);const path=await upload(db,d.id,0);
  assert.equal((await api(db,'publicationUploadPath',{id:d.id,position:0})).uploaded,true);
  await assert.rejects(()=>api(db,'finalizePublication',{id:d.id}),/social_snapshot_uploads_incomplete/);
  await as(db,null,'anon');assert.deepEqual((await api(db,'feed')).items,[]);
  assert.equal((await db.query('select * from storage.objects')).rows.length,0);
  assert.equal(await api(db,'work',{id:d.id}),null);
  await as(db,b);await assert.rejects(()=>api(db,'publicationUploadPath',{id:d.id,position:1}),/social_work_owner_required/);
  await assert.rejects(()=>db.query("insert into storage.objects values('social-snapshots',$1,'{}')",[path.replace(a,b)]),/row-level security/);
  await as(db,a);await upload(db,d.id,1);
  const work=await api(db,'finalizePublication',{id:d.id});assert.equal(work.status,'published');
  assert.deepEqual(await api(db,'finalizePublication',{id:d.id}),work);
  await assert.rejects(()=>api(db,'publicationUploadPath',{id:d.id,position:0}),/social_snapshot_immutable/);
  const denied=await db.query("update storage.objects set metadata='{}' where name=$1 returning name",[path]);
  assert.equal(denied.rows.length,0);
  await db.exec('reset role');
  await assert.rejects(()=>db.query("update storage.objects set metadata='{}' where name=$1",[path]),/social_snapshot_immutable/);
  await as(db,null,'anon');assert.equal((await db.query('select * from storage.objects')).rows.length,2);
 }finally{await db.close();}
});

test('source changes or collaboration after begin prevent finalization',async()=>{
 const db=await fixture();try{
  await as(db,a);const d=await draft(db);await upload(db,d.id,0);await upload(db,d.id,1);
  await db.exec('reset role');await db.exec("update public.albums set updated_at=updated_at+interval '1 second' where id=10");
  await as(db,a);await assert.rejects(()=>api(db,'finalizePublication',{id:d.id}),/social_source_changed/);
  const next=await draft(db);await upload(db,next.id,0);await upload(db,next.id,1);
  await db.exec('reset role');await db.query('insert into public.album_members(album_id,user_id) values(10,$1)',[b]);
  await as(db,a);await assert.rejects(()=>api(db,'finalizePublication',{id:next.id}),/social_collaborative_album_unsupported/);
 }finally{await db.close();}
});

test('publication request keys survive lost responses without duplicating drafts or finalized works',async()=>{
 const db=await fixture();try{
  await as(db,a);const requestId='44444444-4444-4444-8444-444444444444';
  const first=await draft(db,{requestId});
  assert.deepEqual(await draft(db,{requestId}),first);
  await assert.rejects(()=>draft(db,{requestId,title:'Different content'}),/social_publication_request_mismatch/);
  await upload(db,first.id,0);await upload(db,first.id,1);
  await api(db,'finalizePublication',{id:first.id});
  const retry=await draft(db,{requestId});assert.equal(retry.id,first.id);assert.equal(retry.status,'published');
  assert.equal((await api(db,'ownWorks')).length,1);
 }finally{await db.close();}
});

test('legacy saved cover documents allow only position zero, without inventing inner pages',async()=>{
 const db=await fixture();try{
  await db.exec('update public.albums set cover_layers_json=\'{"layers":[]}\' where id=10');
  await as(db,a);const d=await draft(db,{pageIndexes:[0]});assert.deepEqual(d.pageIndexes,[0]);
  await assert.rejects(()=>draft(db,{pageIndexes:[1]}),/social_invalid_pages/);
  await upload(db,d.id,0);assert.equal((await api(db,'finalizePublication',{id:d.id})).imagePaths.length,1);
 }finally{await db.close();}
});

test('client loaded revision is checked at begin, closing the load-to-begin gap',async()=>{
 const db=await fixture();try{
  const revision=(await db.query('select updated_at from public.albums where id=10')).rows[0].updated_at;
  await db.exec("update public.albums set updated_at=updated_at+interval '1 second' where id=10");
  await as(db,a);await assert.rejects(()=>draft(db,{expectedUpdatedAt:revision}),/social_source_changed/);
 }finally{await db.close();}
});

test('empty pages plus legacy layers uses the same single-cover fallback as the app',async()=>{
 const db=await fixture();try{
  await db.exec('update public.albums set cover_layers_json=\'{"pages":[],"layers":[]}\' where id=10');
  await as(db,a);const d=await draft(db,{pageIndexes:[0]});assert.deepEqual(d.pageIndexes,[0]);
  await assert.rejects(()=>draft(db,{pageIndexes:[1]}),/social_invalid_pages/);
 }finally{await db.close();}
});

test('explicit recovery discards only own unfinished drafts and cannot delete a finalized work',async()=>{
 const db=await fixture();try{
  const work=await publish(db);await api(db,'visibility',{id:work.id,published:false});
  for(let i=0;i<5;i++)await draft(db);
  await assert.rejects(()=>draft(db),/social_draft_limit/);
  await as(db,b);assert.equal(await api(db,'discardDrafts'),0);
  assert.equal(await api(db,'discardDraft',{id:work.id}),false);
  await as(db,a);assert.equal(await api(db,'discardDrafts'),5);
  assert.equal((await api(db,'ownWorks'))[0].status,'private');
  assert.equal(await api(db,'discardDraft',{id:work.id}),false);
  const next=await draft(db);assert.equal(await api(db,'discardDraft',{id:next.id}),true);
  assert.equal(await api(db,'work',{id:next.id}),null);
 }finally{await db.close();}
});

test('withdrawal hides images/rows from strangers; only the owner can republish or delete',async()=>{
 const db=await fixture();try{
  const w=await publish(db);
  await as(db,b);await assert.rejects(()=>api(db,'visibility',{id:w.id,published:false}),/social_work_owner_required/);
  await as(db,a);await api(db,'visibility',{id:w.id,published:false});
  assert.equal((await api(db,'ownWorks')).length,1);
  await as(db,null,'anon');assert.equal(await api(db,'work',{id:w.id}),null);
  assert.equal((await db.query('select * from public.social_work_pages')).rows.length,0);
  assert.equal((await db.query('select * from storage.objects')).rows.length,0);
  await as(db,a);await api(db,'visibility',{id:w.id,published:true});
  await db.exec('reset role');await db.exec('delete from public.albums where id=10');
  await as(db,null,'anon');assert.equal((await api(db,'work',{id:w.id})).title,w.title);
  await as(db,a);await api(db,'deleteWork',{id:w.id});
  assert.equal((await api(db,'ownWorks')).length,0);
  await assert.rejects(()=>api(db,'visibility',{id:w.id,published:true}),/social_not_finalized/);
 }finally{await db.close();}
});

test('follow, save, reaction and comment ownership; blocking removes relations and hides interaction',async()=>{
 const db=await fixture();try{
  const w=await publish(db);
  await as(db,b);await api(db,'ensureProfile');assert.equal(await api(db,'toggleFollow',{userId:a}),true);
  assert.equal((await api(db,'feed',{following:true})).items.length,1);
  assert.equal(await api(db,'toggleLike',{id:w.id}),true);assert.equal(await api(db,'toggleSave',{id:w.id}),true);
  const comment=await api(db,'addComment',{id:w.id,body:'A public comment'});
  assert.equal((await api(db,'comments',{id:w.id})).length,1);
  await as(db,c);await assert.rejects(()=>api(db,'deleteComment',{id:comment.id}),/social_comment_owner_required/);
  assert.equal((await db.query('select * from public.social_saves')).rows.length,0);
  await as(db,a);await api(db,'deleteComment',{id:comment.id});
  await api(db,'setBlocked',{userId:b,blocked:true});
  assert.equal((await api(db,'relations',{userId:a})).length,0);
  await as(db,b);assert.equal(await api(db,'profile',{userId:a}),null);
  assert.equal((await api(db,'savedWorks')).length,0);
  await assert.rejects(()=>api(db,'addComment',{id:w.id,body:'blocked'}),/social_work_unavailable/);
  await assert.rejects(()=>api(db,'toggleFollow',{userId:a}),/social_blocked/);
  await as(db,a);assert.equal((await api(db,'blockedProfiles')).length,1);
  await api(db,'setBlocked',{userId:b,blocked:false});
  assert.equal((await api(db,'relations',{userId:a})).length,0);
 }finally{await db.close();}
});

test('direct table writes and anonymous mutations cannot bypass the dispatcher',async()=>{
 const db=await fixture();try{
  await as(db,null,'anon');await assert.rejects(()=>api(db,'ensureProfile'),/social_login_required/);
  assert.equal((await db.query("select has_schema_privilege('anon','private','usage') allowed")).rows[0].allowed,false);
  await as(db,a);await api(db,'ensureProfile');
  for(const sql of ["update public.social_profiles set display_name='forged'", "insert into public.social_works(author_id,title) values('"+a+"','forged')", 'delete from public.social_follows'])await assert.rejects(()=>db.exec(sql),/permission denied/);
  await assert.rejects(()=>db.query('select social_private.social_profile_json($1)',[a]),/permission denied/);
  await api(db,'upsertProfile',{displayName:'One',handle:'one.handle',bio:''});
  await as(db,b);await assert.rejects(()=>api(db,'upsertProfile',{displayName:'Two',handle:'ONE.HANDLE',bio:''}),/unique constraint/);
  await assert.rejects(()=>api(db,'upsertProfile',{displayName:'Two',handle:'bad handle',bio:''}),/check constraint/);
 }finally{await db.close();}
});

test('another user cannot squat a predictable handle and lock someone out of profile creation or repair',async()=>{
 const db=await fixture();try{
  await as(db,a);await api(db,'upsertProfile',{displayName:'First',handle:'sf_'+b.replaceAll('-','').slice(0,20),bio:''});
  await as(db,b);const ensured=await api(db,'ensureProfile');
  assert.equal(ensured.userId,b);assert.notEqual(ensured.handle,'sf_'+b.replaceAll('-','').slice(0,20));
  const repaired=await api(db,'upsertProfile',{displayName:'Second',handle:'victim.safe',bio:''});
  assert.equal(repaired.handle,'victim.safe');
 }finally{await db.close();}
});

test('snapshot isolation does not intercept updates to existing unrelated storage buckets',async()=>{
 const db=await fixture();try{
  await db.exec("insert into storage.objects values('album-assets','private/source.png','{\"size\":24}'); update storage.objects set metadata='{\"size\":48}' where bucket_id='album-assets'");
  assert.equal((await db.query("select metadata->>'size' size from storage.objects where bucket_id='album-assets'")).rows[0].size,'48');
 }finally{await db.close();}
});

test('topic/following/search filters and deterministic page bounds only expose published works',async()=>{
 const db=await fixture();try{
  await publish(db);await publish(db);
  await as(db,b);await api(db,'ensureProfile');
  assert.equal((await api(db,'feed',{following:true})).items.length,0);
  const page=await api(db,'feed',{limit:1});assert.equal(page.items.length,1);assert.equal(page.hasMore,true);assert.equal(page.nextOffset,1);
  const next=await api(db,'feed',{limit:1,offset:1});assert.equal(next.hasMore,false);assert.notEqual(page.items[0].id,next.items[0].id);
  assert.equal((await api(db,'feed',{topic:'가족'})).items.length,0);
  assert.equal((await api(db,'search',{query:'Selected'})).length,2);
  assert.equal((await api(db,'search',{query:''})).length,0);
 }finally{await db.close();}
});

test('server accepts every shared template topic and filters canonical publications',async()=>{
 const db=await fixture();try{
  assert.equal(canonicalTopics.length,11);
  for(const required of ['웨딩','성장·육아','스포츠·도전','동아리'])assert.ok(canonicalTopics.includes(required));
  const works=new Map();
  await as(db,a);
  for(const topic of canonicalTopics){
   const d=await draft(db,{topic,title:'Topic '+topic});
   await upload(db,d.id,0);await upload(db,d.id,1);
   const w=await api(db,'finalizePublication',{id:d.id});
   assert.equal(w.topic,topic);works.set(topic,w.id);
  }
  await assert.rejects(()=>draft(db,{topic:'unknown-topic'}),/social_works_topic_check/);
  await as(db,null,'anon');
  for(const topic of canonicalTopics){
   const page=await api(db,'feed',{topic});
   assert.deepEqual(page.items.map(w=>w.id),[works.get(topic)],topic);
  }
  await as(db,b);await api(db,'toggleFollow',{userId:a});
  assert.deepEqual((await api(db,'feed',{following:true,topic:'동아리'})).items.map(w=>w.id),[works.get('동아리')]);
  await db.exec('reset role');
  const helper=(await db.query("select provolatile,prosecdef,proparallel,proconfig,has_function_privilege('anon',oid,'execute') anon_execute,has_function_privilege('authenticated',oid,'execute') user_execute from pg_proc where oid='social_private.normalize_social_topic(text)'::regprocedure")).rows[0];
  assert.equal(helper.provolatile,'i');assert.equal(helper.prosecdef,false);assert.equal(helper.proparallel,'s');
  assert.ok(helper.proconfig.includes('search_path=""'));assert.equal(helper.anon_execute,false);assert.equal(helper.user_execute,false);
  await as(db,null,'anon');
  await assert.rejects(()=>db.query("select social_private.normalize_social_topic('커플')"),/permission denied/);
 }finally{await db.close();}
});

test('taxonomy upgrade preserves existing legacy rows and both old/new feed filter labels',async()=>{
 const db=await fixture({topics:false});try{
  const legacy=new Map();
  await as(db,a);
  for(const topic of ['커플','가족']){
   const d=await draft(db,{topic,title:'Legacy '+topic});
   await upload(db,d.id,0);await upload(db,d.id,1);
   legacy.set(topic,(await api(db,'finalizePublication',{id:d.id})).id);
  }
  await db.exec('reset role');await db.exec(topicTaxonomyMigration);
  const persisted=(await db.query('select id,topic from public.social_works order by topic')).rows;
  assert.deepEqual(persisted.map(w=>w.topic),['가족','커플']);
  await as(db,null,'anon');
  for(const [oldLabel,canonical] of [['커플','커플·기념일'],['가족','가족·친구']]){
   for(const topic of [oldLabel,canonical])assert.deepEqual((await api(db,'feed',{topic})).items.map(w=>w.id),[legacy.get(oldLabel)]);
   assert.equal((await api(db,'work',{id:legacy.get(oldLabel)})).topic,oldLabel);
  }
  await as(db,a);
  // Older installed clients can still publish their original labels.
  const oldClient=await draft(db,{topic:'커플'});await upload(db,oldClient.id,0);await upload(db,oldClient.id,1);
  assert.equal((await api(db,'finalizePublication',{id:oldClient.id})).topic,'커플');
 }finally{await db.close();}
});

test('canonical search topics also find existing legacy couple/family publications',async()=>{
 const db=await fixture();try{
  const legacy=new Map();await as(db,a);
  for(const topic of ['커플','가족']){
   const d=await draft(db,{topic,title:'Legacy record'});
   await upload(db,d.id,0);await upload(db,d.id,1);
   legacy.set(topic,(await api(db,'finalizePublication',{id:d.id})).id);
  }
  await as(db,null,'anon');
  for(const [oldLabel,canonical] of [['커플','커플·기념일'],['가족','가족·친구']]){
   for(const query of [oldLabel,canonical])assert.deepEqual((await api(db,'search',{query})).map(w=>w.id),[legacy.get(oldLabel)]);
  }
 }finally{await db.close();}
});

test('desired follow state is idempotent after lost responses and updates the exact outgoing edge',async()=>{
 const db=await fixture();try{
  const w=await publish(db);
  await as(db,b);await api(db,'ensureProfile');
  for(let retry=0;retry<3;retry++)assert.equal(await api(db,'setFollowing',{userId:a,following:true}),true);
  let own=await api(db,'profile',{userId:b});let author=await api(db,'profile',{userId:a});
  assert.equal(own.followingCount,1);assert.equal(author.followersCount,1);assert.equal(author.isFollowing,true);
  assert.deepEqual((await api(db,'relations',{userId:b,followers:false})).map(p=>p.userId),[a]);
  assert.deepEqual((await api(db,'feed',{following:true})).items.map(item=>item.id),[w.id]);
  await as(db,a);assert.equal(await api(db,'setFollowing',{userId:b,following:true}),true);
  await as(db,b);
  for(let retry=0;retry<3;retry++)assert.equal(await api(db,'setFollowing',{userId:a,following:false}),false);
  own=await api(db,'profile',{userId:b});author=await api(db,'profile',{userId:a});
  assert.equal(own.followingCount,0);assert.equal(own.followersCount,1);
  assert.equal(author.followersCount,0);assert.equal(author.followingCount,1);assert.equal(author.isFollowing,false);
  assert.deepEqual((await api(db,'relations',{userId:b,followers:false})),[]);
  assert.deepEqual((await api(db,'feed',{following:true})).items,[]);
  assert.equal(await api(db,'toggleFollow',{userId:a}),true);
  assert.equal(await api(db,'setFollowing',{userId:a,following:true}),true);
  assert.equal((await api(db,'profile',{userId:b})).followingCount,1);
 }finally{await db.close();}
});

test('desired follow state requires an actual JSON boolean and retains auth/self/block guards',async()=>{
 const db=await fixture();try{
  await as(db,b);await api(db,'ensureProfile');await as(db,a);await api(db,'ensureProfile');
  for(const following of [undefined,null,'true','false',0,1,{},[]]){
   await assert.rejects(()=>api(db,'setFollowing',{userId:b,following}),/social_invalid_follow_state/);
  }
  assert.equal((await api(db,'profile',{userId:a})).followingCount,0);
  await assert.rejects(()=>api(db,'setFollowing',{userId:a,following:true}),/social_invalid_user/);
  await assert.rejects(()=>api(db,'setFollowing',{userId:c,following:true}),/social_invalid_user/);
  await as(db,null,'anon');await assert.rejects(()=>api(db,'setFollowing',{userId:b,following:true}),/social_login_required/);
  await as(db,b);await api(db,'setBlocked',{userId:a,blocked:true});
  await as(db,a);
  for(const following of [true,false])await assert.rejects(()=>api(db,'setFollowing',{userId:b,following}),/social_blocked/);
  assert.equal((await api(db,'profile',{userId:a})).followingCount,0);
 }finally{await db.close();}
});

const photoPath=(owner,number)=>`${owner}/44444444-4444-4444-8444-${String(number).padStart(12,'0')}.png`;
async function uploadPhoto(db,path,metadata={mimetype:'image/png',size:1024}){
 await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-profile-photos',$1,$2::jsonb)",[path,JSON.stringify(metadata)]);
}

test('public photo is explicitly selected from a private owner upload and never copies private profile data',async()=>{
 const db=await fixture();try{
  await as(db,a);
  assert.equal((await api(db,'ensureProfile')).avatarPath,null);
  await api(db,'upsertProfile',{displayName:'Public author',handle:'public.author',bio:'Only this introduction'});
  const path=photoPath(a,1);await uploadPhoto(db,path);
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await as(db,null,'anon');
  assert.equal((await api(db,'profile',{userId:a})).avatarPath,null);
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,0);
  await assert.rejects(()=>api(db,'setProfilePhoto',{path}),/social_login_required/);
  await as(db,a);const profile=await api(db,'setProfilePhoto',{path});
  assert.equal(profile.avatarPath,path);assert.equal(profile.avatarUrl,null);
  assert.equal(profile.displayName,'Public author');assert.equal(profile.bio,'Only this introduction');
  await as(db,null,'anon');
  assert.equal((await api(db,'profile',{userId:a})).avatarPath,path);
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await db.exec('reset role');
  assert.equal((await db.query('select avatar_url from public.profiles where id=$1',[a])).rows[0].avatar_url,'https://private.invalid/avatar');
  const bucket=(await db.query("select public,file_size_limit,allowed_mime_types from storage.buckets where id='social-profile-photos'")).rows[0];
  assert.equal(bucket.public,false);assert.equal(Number(bucket.file_size_limit),3145728);assert.deepEqual(bucket.allowed_mime_types,['image/png']);
 }finally{await db.close();}
});

test('profile photo path, owner, PNG metadata and size are enforced before changing the pointer',async()=>{
 const db=await fixture();try{
  await as(db,a);await api(db,'ensureProfile');await uploadPhoto(db,photoPath(a,1));
  for(const payload of [{},{path:true},{path:1},{path:[]},{path:{}},{path:''},{path:'https://private.invalid/avatar.png'},{path:`${a}/not-a-uuid.png`},{path:`${a}/44444444-4444-4444-8444-000000000001.jpg`}]){
   await assert.rejects(()=>api(db,'setProfilePhoto',payload),/social_invalid_profile_photo_path/);
  }
  await assert.rejects(()=>api(db,'setProfilePhoto',{path:photoPath(a,9)}),/social_profile_photo_upload_required/);
  await uploadPhoto(db,photoPath(a,2),{mimetype:'image/jpeg',size:1024});
  await uploadPhoto(db,photoPath(a,3),{mimetype:'image/png',size:3145729});
  await uploadPhoto(db,photoPath(a,4),{mimetype:'image/png',size:23});
  for(const number of [2,3,4])await assert.rejects(()=>api(db,'setProfilePhoto',{path:photoPath(a,number)}),/social_profile_photo_upload_required/);
  assert.equal((await api(db,'profile',{userId:a})).avatarPath,null);
  await as(db,b);await api(db,'ensureProfile');
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,0);
  await assert.rejects(()=>api(db,'setProfilePhoto',{path:photoPath(a,1)}),/social_profile_photo_owner_required/);
  await assert.rejects(()=>uploadPhoto(db,photoPath(a,8)),/row-level security/);
  await as(db,a);await uploadPhoto(db,photoPath(a,5),{mimetype:'image/png',size:3145728});
  assert.equal((await api(db,'setProfilePhoto',{path:photoPath(a,5),userId:b})).userId,a);
  await assert.rejects(()=>db.query('update public.social_profiles set avatar_path=$1 where user_id=$2',[photoPath(a,1),a]),/permission denied/);
 }finally{await db.close();}
});

test('profile PNGs are immutable; referenced deletion is guarded until replacement or explicit clear',async()=>{
 const db=await fixture();try{
  await as(db,a);await api(db,'ensureProfile');
  const first=photoPath(a,1),second=photoPath(a,2);
  await uploadPhoto(db,first);await uploadPhoto(db,second);await api(db,'setProfilePhoto',{path:first});
  assert.equal((await db.query("delete from storage.objects where bucket_id='social-profile-photos' and name=$1 returning name",[first])).rows.length,0);
  assert.equal((await db.query("update storage.objects set metadata='{}' where bucket_id='social-profile-photos' and name=$1 returning name",[first])).rows.length,0);
  await db.exec('reset role');
  await assert.rejects(()=>db.query("delete from storage.objects where bucket_id='social-profile-photos' and name=$1",[first]),/social_profile_photo_referenced/);
  await assert.rejects(()=>db.query("update storage.objects set metadata='{}' where bucket_id='social-profile-photos' and name=$1",[first]),/social_profile_photo_immutable/);
  await db.exec('alter table storage.objects add column updated_at timestamptz; alter table storage.objects add column last_accessed_at timestamptz');
  await db.query("update storage.objects set updated_at=now(),last_accessed_at=now() where bucket_id='social-profile-photos' and name=$1",[first]);
  await as(db,a);await api(db,'setProfilePhoto',{path:second});
  assert.equal((await db.query("delete from storage.objects where bucket_id='social-profile-photos' and name=$1 returning name",[first])).rows.length,1);
  await as(db,b);await api(db,'ensureProfile');
  assert.equal((await db.query("delete from storage.objects where bucket_id='social-profile-photos' and name=$1 returning name",[second])).rows.length,0);
  await as(db,a);assert.equal((await api(db,'setProfilePhoto',{path:null})).avatarPath,null);
  assert.equal((await db.query("delete from storage.objects where bucket_id='social-profile-photos' and name=$1 returning name",[second])).rows.length,1);
 }finally{await db.close();}
});

test('public photo delivery follows bilateral blocking and only the owner can read cleared/pending files',async()=>{
 const db=await fixture();try{
  await as(db,a);await api(db,'ensureProfile');const path=photoPath(a,1);
  await uploadPhoto(db,path);await api(db,'setProfilePhoto',{path});
  await as(db,b);await api(db,'ensureProfile');
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await api(db,'setBlocked',{userId:a,blocked:true});
  assert.equal(await api(db,'profile',{userId:a}),null);
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,0);
  await as(db,a);assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await as(db,null,'anon');assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await as(db,b);await api(db,'setBlocked',{userId:a,blocked:false});
  assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
  await as(db,a);await api(db,'setProfilePhoto',{path:null});
  await as(db,b);assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,0);
  await as(db,a);assert.equal((await db.query("select * from storage.objects where bucket_id='social-profile-photos'")).rows.length,1);
 }finally{await db.close();}
});

test('desired like/save states survive repeated responses and only change the authenticated actor edge',async()=>{
 const db=await fixture();try{
  const w=await publish(db);await as(db,b);
  for(let retry=0;retry<3;retry++){
   assert.equal(await api(db,'setLiked',{id:w.id,liked:true,userId:c}),true);
   assert.equal(await api(db,'setSaved',{id:w.id,saved:true,userId:c}),true);
  }
  let work=await api(db,'work',{id:w.id});
  assert.equal(work.likeCount,1);assert.equal(work.isLiked,true);assert.equal(work.isSaved,true);
  assert.deepEqual((await api(db,'savedWorks')).map(x=>x.id),[w.id]);
  await as(db,c);
  assert.equal((await api(db,'work',{id:w.id})).isLiked,false);assert.equal((await api(db,'savedWorks')).length,0);
  await api(db,'setLiked',{id:w.id,liked:true});await api(db,'setSaved',{id:w.id,saved:true});
  await as(db,b);
  for(let retry=0;retry<3;retry++){
   assert.equal(await api(db,'setLiked',{id:w.id,liked:false}),false);
   assert.equal(await api(db,'setSaved',{id:w.id,saved:false}),false);
  }
  work=await api(db,'work',{id:w.id});
  assert.equal(work.likeCount,1);assert.equal(work.isLiked,false);assert.equal(work.isSaved,false);
  assert.equal((await api(db,'savedWorks')).length,0);
  await as(db,c);assert.equal((await api(db,'work',{id:w.id})).isLiked,true);assert.equal((await api(db,'savedWorks')).length,1);
  await as(db,b);
  assert.equal(await api(db,'toggleLike',{id:w.id}),true);assert.equal(await api(db,'setLiked',{id:w.id,liked:true}),true);
  assert.equal(await api(db,'toggleSave',{id:w.id}),true);assert.equal(await api(db,'setSaved',{id:w.id,saved:true}),true);
  assert.equal((await api(db,'work',{id:w.id})).likeCount,2);
  assert.equal(await api(db,'toggleLike',{id:w.id}),false);assert.equal(await api(db,'toggleSave',{id:w.id}),false);
 }finally{await db.close();}
});

test('desired reaction states accept only actual JSON booleans and never bypass direct-write or anonymous restrictions',async()=>{
 const db=await fixture();try{
  const w=await publish(db);await as(db,b);
  for(const [action,key,error] of [['setLiked','liked',/social_invalid_like_state/],['setSaved','saved',/social_invalid_save_state/]]){
   for(const value of [undefined,null,'true','false',0,1,[],{}]){
    await assert.rejects(()=>api(db,action,{id:w.id,[key]:value}),error);
   }
  }
  const untouched=await api(db,'work',{id:w.id});
  assert.equal(untouched.likeCount,0);assert.equal(untouched.isLiked,false);assert.equal(untouched.isSaved,false);
  for(const table of ['social_likes','social_saves'])await assert.rejects(()=>db.query(`insert into public.${table}(work_id,user_id) values($1,$2)`,[w.id,b]),/permission denied/);
  await as(db,null,'anon');
  await assert.rejects(()=>api(db,'setLiked',{id:w.id,liked:true}),/social_login_required/);
  await assert.rejects(()=>api(db,'setSaved',{id:w.id,saved:true}),/social_login_required/);
 }finally{await db.close();}
});

test('desired reactions retain published, missing, draft, private, deleted and bilateral block guards',async()=>{
 const db=await fixture();try{
  const w=await publish(db);await as(db,a);const d=await draft(db);
  async function denied(id){
   for(const [action,key] of [['setLiked','liked'],['setSaved','saved']])for(const value of [true,false]){
    await assert.rejects(()=>api(db,action,{id,[key]:value}),/social_work_unavailable/);
   }
  }
  await denied(d.id);await denied('99999999-9999-4999-8999-999999999999');
  await api(db,'visibility',{id:w.id,published:false});await denied(w.id);
  await as(db,b);await denied(w.id);
  await as(db,a);await api(db,'visibility',{id:w.id,published:true});
  await as(db,b);await api(db,'setBlocked',{userId:a,blocked:true});await denied(w.id);
  await as(db,a);await api(db,'setBlocked',{userId:b,blocked:true});
  await as(db,b);await api(db,'setBlocked',{userId:a,blocked:false});await denied(w.id);
  await as(db,a);await api(db,'setBlocked',{userId:b,blocked:false});
  await api(db,'setLiked',{id:w.id,liked:true});assert.equal((await api(db,'work',{id:w.id})).isLiked,true);
  await api(db,'deleteWork',{id:w.id});await denied(w.id);
 }finally{await db.close();}
});

test('comment request UUID returns the same comment for retries while omitted/null keys preserve legacy behavior',async()=>{
 const db=await fixture();try{
  const w=await publish(db);await as(db,b);
  const requestId='55555555-5555-4555-8555-555555555555';
  const first=await api(db,'addComment',{id:w.id,body:'  One public comment  ',requestId});
  assert.equal(first.id,requestId);assert.equal(first.body,'One public comment');assert.equal(first.author.userId,b);
  for(let retry=0;retry<3;retry++)assert.deepEqual(await api(db,'addComment',{id:w.id,body:'One public comment',requestId}),first);
  assert.equal((await api(db,'comments',{id:w.id})).length,1);assert.equal((await api(db,'work',{id:w.id})).commentCount,1);
  const legacy=await api(db,'addComment',{id:w.id,body:'Legacy client'});
  const nullable=await api(db,'addComment',{id:w.id,body:'Legacy client',requestId:null});
  assert.notEqual(legacy.id,nullable.id);assert.notEqual(legacy.id,first.id);
  for(const invalid of [true,1,[],{}])await assert.rejects(()=>api(db,'addComment',{id:w.id,body:'Invalid request',requestId:invalid}),/social_invalid_comment_request_id/);
  await assert.rejects(()=>api(db,'addComment',{id:w.id,body:'Invalid request',requestId:'not-a-uuid'}),/invalid input syntax for type uuid/);
 }finally{await db.close();}
});

test('a conflicting comment UUID cannot overwrite or replay another actor/work/body',async()=>{
 const db=await fixture();try{
  const firstWork=await publish(db);const otherWork=await publish(db);await as(db,b);
  const requestId='66666666-6666-4666-8666-666666666666';
  const original=await api(db,'addComment',{id:firstWork.id,body:'Original body',requestId});
  await assert.rejects(()=>api(db,'addComment',{id:firstWork.id,body:'Changed body',requestId}),/social_comment_request_mismatch/);
  await assert.rejects(()=>api(db,'addComment',{id:otherWork.id,body:'Original body',requestId}),/social_comment_request_mismatch/);
  await as(db,c);await assert.rejects(()=>api(db,'addComment',{id:firstWork.id,body:'Original body',requestId}),/social_comment_request_mismatch/);
  await as(db,b);
  assert.deepEqual((await api(db,'comments',{id:firstWork.id})),[original]);assert.deepEqual(await api(db,'comments',{id:otherWork.id}),[]);
 }finally{await db.close();}
});

test('comment retries still require a published visible work before resolving a request UUID',async()=>{
 const db=await fixture();try{
  const w=await publish(db);await as(db,b);
  const payload={id:w.id,body:'Retry permission',requestId:'77777777-7777-4777-8777-777777777777'};
  await api(db,'addComment',payload);
  await as(db,a);await api(db,'setBlocked',{userId:b,blocked:true});
  await as(db,b);await assert.rejects(()=>api(db,'addComment',payload),/social_work_unavailable/);
  await as(db,a);await api(db,'setBlocked',{userId:b,blocked:false});await api(db,'visibility',{id:w.id,published:false});
  await as(db,b);await assert.rejects(()=>api(db,'addComment',payload),/social_work_unavailable/);
  await as(db,a);await api(db,'visibility',{id:w.id,published:true});
  await as(db,null,'anon');await assert.rejects(()=>api(db,'addComment',payload),/social_login_required/);
  await as(db,b);assert.equal((await api(db,'comments',{id:w.id})).length,1);
 }finally{await db.close();}
});


test('changed source revisions return HTTP-domain conflicts instead of retryable serialization errors',async()=>{
 const db=await fixture();try{
  const revision=(await db.query('select updated_at from public.albums where id=10')).rows[0].updated_at;
  await as(db,a);const d=await draft(db,{expectedUpdatedAt:revision});await upload(db,d.id,0);await upload(db,d.id,1);
  await db.exec('reset role');await db.exec("update public.albums set updated_at=updated_at+interval '1 second' where id=10");
  await as(db,a);
  const domainConflict=error=>error.code==='PT409' && error.message==='social_source_changed';
  await assert.rejects(()=>api(db,'finalizePublication',{id:d.id}),domainConflict);
  await assert.rejects(()=>draft(db,{expectedUpdatedAt:revision}),domainConflict);
  assert.equal((await api(db,'work',{id:d.id})).status,'draft');
 }finally{await db.close();}
});

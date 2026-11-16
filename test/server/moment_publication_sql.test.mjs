import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const {PGlite}=await import(process.env.PGLITE_MODULE??'@electric-sql/pglite');
const sql=name=>readFileSync(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222';
const id=n=>`aaaaaaaa-aaaa-4aaa-8aaa-${String(n).padStart(12,'0')}`;
const rid=id(1),pid=id(2),otherPid=id(3),path=`${a}/moments/${rid}/${pid}.jpg`;
const photo={id:pid,path,width:1200,height:1600};
const second={id:otherPid,path:`${a}/moments/${rid}/${otherPid}.jpg`,width:1600,height:900};
async function fixture(){
 const db=new PGlite();
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create schema storage;create schema album_private;
 create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth,storage to anon,authenticated;
 create table auth.users(id uuid primary key,is_anonymous boolean not null default false,deleted_at timestamptz,banned_until timestamptz);
 insert into auth.users(id)values('${a}'),('${b}');
 create table public.albums(id bigint primary key,owner_id uuid references auth.users,cover_layers_json text,ratio text,updated_at timestamptz not null default now());
 insert into public.albums values(10,'${a}','{"pages":[{},{}]}','1:1',now());
 create table public.album_members(album_id bigint references public.albums,user_id uuid references auth.users,status text default 'ACCEPTED');
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(bucket_id text,name text,owner uuid,owner_id text,metadata jsonb,updated_at timestamptz default now(),last_accessed_at timestamptz,primary key(bucket_id,name));
 alter table storage.objects enable row level security;
 grant select,insert,update,delete on storage.objects to anon,authenticated;
 create policy original_owner on storage.objects for select to authenticated using(bucket_id='album-assets' and owner_id=auth.uid()::text);
 create table public.point_shop_products(product_key text primary key,kind text,title text,point_price integer,is_active boolean);
 create table public.point_shop_ownership(user_id uuid references auth.users,product_key text references public.point_shop_products,primary key(user_id,product_key));`);
 for(const name of [
  '20261025062446_social_publication_and_profiles.sql','20261025062938_social_legacy_empty_pages_fallback.sql',
  '20261025073121_social_topic_taxonomy.sql','20261025073122_social_idempotent_follow_state.sql',
  '20261025074127_social_public_profile_photos.sql','20261025082024_social_idempotent_reaction_state.sql',
  '20261025082810_social_idempotent_comments.sql','20261025083353_social_publication_conflict_http_status.sql',
  '20261025092245_collaborative_album_publication_history.sql','20261026064733_social_paginated_collections.sql',
  '20261026092426_weekly_photo_moments.sql','20261026142401_social_official_template_sources.sql',
  '20261028112445_private_moment_publication_feed.sql',
  '20261028120622_public_moment_month_collections.sql',
 ]){
  const source=sql(name);
  if(name==='20261028112445_private_moment_publication_feed.sql')await db.query("select public.social_api('feed','{}'::jsonb)");
  try{await db.exec(source);}catch(error){
   const position=Number(error.position??0);throw new Error(`${name}: ${error.message}; ${error.where??''}; line ${source.slice(0,position).split('\n').length}: ${source.slice(Math.max(0,position-90),position+120)}`);
  }
 }
 for(const p of[photo,second])await db.query("insert into storage.objects(bucket_id,name,owner,owner_id,metadata)values('album-assets',$1,$2::uuid,$2::uuid::text,'{\"mimetype\":\"image/jpeg\"}')",[p.path,a]);
 await login(db);await save(db);return db;
}
async function login(db,owner=a,role='authenticated'){
 await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[owner??'']);await db.exec(`set role ${role}`);
}
async function api(db,action,payload={}){return(await db.query('select public.social_api($1,$2::jsonb)r',[action,JSON.stringify(payload)])).rows[0].r;}
async function save(db,{record=rid,date='2026-10-26',caption='오늘의 한 문장',photos=[photo,second],revision=0}={}){
 return(await db.query('select public.save_weekly_moment($1,$2,$3,$4::jsonb,$5)r',[record,date,caption,JSON.stringify(photos),revision])).rows[0].r;
}
async function begin(db,patch={}){return api(db,'beginMomentPublication',{recordId:rid,photoId:pid,expectedRevision:1,requestId:id(10),...patch});}
async function state(db){return api(db,'momentPublication',{recordId:rid});}
async function upload(db,draft){
 const slot=await api(db,'publicationUploadPath',{id:draft.id,position:0});
 await db.query("insert into storage.objects(bucket_id,name,metadata)values('social-snapshots',$1,'{\"mimetype\":\"image/png\",\"size\":1024}')",[slot.path]);return slot.path;
}
async function publish(db,patch={}){const draft=await begin(db,patch);await upload(db,draft);return api(db,'finalizePublication',{id:draft.id});}
async function visibility(db,work,published,revision){return api(db,'visibility',{id:work.id,published,expectedPublicationRevision:revision});}

test('new private records have no public work, no album requirement and no direct ledger grants',async()=>{const db=await fixture();try{
 assert.deepEqual(await state(db),{recordId:rid,recordRevision:1,sourceRevision:1,photoId:null,workId:null,id:null,status:'private',publicationRevision:0,requestId:null});
 await assert.rejects(()=>db.query('select * from moments_private.publications'),/permission denied/);
 await assert.rejects(()=>db.query('select * from social_private.moment_publication_sources'),/permission denied/);
 await assert.rejects(()=>db.query("select social_private.social_api_albums_v1('feed','{}')"),/permission denied/);
 await login(db,b);assert.equal(await state(db),null);await assert.rejects(()=>begin(db),/MOMENTS_ACCESS_DENIED/);
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items.length,0);await assert.rejects(()=>begin(db),/MOMENTS_LOGIN_REQUIRED/);
 assert.equal((await db.query("select * from storage.objects where bucket_id='album-assets'")).rows.length,0);
}finally{await db.close();}});

test('one explicit photo and server caption become a safe public moment while private photos stay private',async()=>{const db=await fixture();try{
 const work=await publish(db);assert.equal(work.kind,'moment');assert.equal(work.recordDate,'2026-10-26');assert.equal(work.caption,'오늘의 한 문장');assert.equal(work.aspectRatio,.75);assert.equal(work.publicationRevision,1);
 const own=await state(db);assert.equal(own.photoId,pid);assert.equal(own.workId,work.id);assert.equal(own.requestId,id(10));
 assert.equal((await api(db,'ownWorksPage')).items.length,0);assert.deepEqual(await api(db,'ownWorks'),[]);
 await login(db,null,'anon');const feed=await api(db,'feed');assert.equal(feed.items.length,1);assert.equal(feed.items[0].publicationRevision,null);
 const serialized=JSON.stringify(feed);for(const secret of[path,second.path,rid,pid,'recordId','photoId','album-assets','source_revision'])assert.equal(serialized.includes(secret),false,secret);
 assert.equal(feed.items[0].imagePaths.length,1);assert.equal((await api(db,'profileWorksPage',{userId:a})).items.length,0);
 assert.equal((await api(db,'profileMomentsPage',{userId:a})).items.length,1);
 const profile=await api(db,'profile',{userId:a});assert.equal(profile.worksCount,0);assert.equal(profile.momentsCount,1);
 assert.equal((await db.query("select * from storage.objects where bucket_id='album-assets'")).rows.length,0);
 assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,1);
}finally{await db.close();}});

test('ordinary public albums stay in profiles and search while the feed and public records remain moment-only',async()=>{const db=await fixture();try{
 const draft=await api(db,'beginPublication',{albumId:10,pageIndexes:[0],title:'My album',topic:'일상'});await upload(db,draft);const album=await api(db,'finalizePublication',{id:draft.id});assert.equal(album.kind,'album');
 const moment=await publish(db);await login(db,b);await api(db,'setLiked',{id:moment.id,liked:true});await api(db,'setSaved',{id:moment.id,saved:true});await api(db,'setFollowing',{userId:a,following:true});await api(db,'addComment',{id:moment.id,body:'좋아요',requestId:id(30)});
 assert.equal((await api(db,'feed',{following:true})).items[0].likeCount,1);
 assert.equal((await api(db,'savedWorksPage')).items[0].kind,'moment');
 assert.equal((await api(db,'work',{id:album.id})).id,album.id);
 assert.equal((await api(db,'profileWorksPage',{userId:a})).items[0].id,album.id);
 assert.equal((await api(db,'profileMomentsPage',{userId:a})).items[0].id,moment.id);
 assert.equal((await api(db,'searchPage',{query:'My album'})).items[0].id,album.id);
 await login(db);assert.equal((await api(db,'ownWorksPage')).items[0].id,album.id);
}finally{await db.close();}});

test('legacy profile and own arrays preserve their thirty-work default while paged actions default to twelve',async()=>{const db=await fixture();try{
 await api(db,'ensureProfile');
 await db.exec('reset role');
 await db.query("insert into public.social_works(author_id,title,status,published_at)select $1::uuid,'Legacy album '||g,'published',clock_timestamp()+g*interval '1 second' from generate_series(1,31)g",[a]);
 await login(db);
 const own=await api(db,'ownWorks');assert.equal(own.length,30);assert.equal(new Set(own.map(w=>w.id)).size,30);
 assert.equal((await api(db,'ownWorksPage')).items.length,12);
 assert.equal((await api(db,'ownWorksPage')).hasMore,true);
 assert.equal((await api(db,'ownWorks',{limit:5})).length,5);
 await login(db,null,'anon');
 const profile=await api(db,'profileWorks',{userId:a});assert.equal(profile.length,30);assert.equal(new Set(profile.map(w=>w.id)).size,30);
 assert.equal((await api(db,'profileWorksPage',{userId:a})).items.length,12);
 assert.equal((await api(db,'profileWorksPage',{userId:a})).hasMore,true);
 assert.equal((await api(db,'profileWorks',{userId:a,limit:5})).length,5);
 assert.equal((await api(db,'feed')).items.length,0);
}finally{await db.close();}});

test('begin binds a revision and one photo, retries the same UUID and rejects mismatched requests',async()=>{const db=await fixture();try{
 const first=await begin(db);assert.deepEqual(await begin(db),first);
 await assert.rejects(()=>begin(db,{photoId:otherPid}),/social_publication_request_mismatch/);
 await assert.rejects(()=>begin(db,{photoId:id(99),requestId:id(11)}),/MOMENTS_PHOTO_UNAVAILABLE/);
 await assert.rejects(()=>begin(db,{expectedRevision:2}),/MOMENTS_REVISION_CONFLICT/);
 await assert.rejects(()=>api(db,'beginMomentPublication',{recordId:rid,photoId:pid,expectedRevision:1}),/social_invalid_publication_request_id/);
 assert.equal((await state(db)).status,'draft');
 await assert.rejects(()=>api(db,'publicationUploadPath',{id:first.id,position:1}),/social_invalid_position/);
 await assert.rejects(()=>api(db,'finalizePublication',{id:first.id}),/social_snapshot_uploads_incomplete/);
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items.length,0);
}finally{await db.close();}});

test('a real record edit withdraws every snapshot and invalidates delayed upload and finalize',async()=>{const db=await fixture();try{
 const old=await publish(db);const before=await state(db);await save(db,{caption:'수정된 문장',revision:1});
 const fresh=await state(db);assert.equal(fresh.status,'private');assert.equal(fresh.workId,null);assert.equal(fresh.publicationRevision,before.publicationRevision+1);
 await assert.rejects(()=>api(db,'finalizePublication',{id:old.id}),/MOMENTS_PUBLICATION_CHANGED/);
 await assert.rejects(()=>api(db,'publicationUploadPath',{id:old.id,position:0}),/MOMENTS_PUBLICATION_CHANGED/);
 await assert.rejects(()=>visibility(db,old,true,before.publicationRevision),/MOMENTS_PUBLICATION_CHANGED/);
 await assert.rejects(()=>begin(db),/MOMENTS_REVISION_CONFLICT/);
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items.length,0);assert.equal(await api(db,'work',{id:old.id}),null);assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);
 await login(db);const updated=await publish(db,{expectedRevision:2,requestId:id(11)});assert.equal(updated.caption,'수정된 문장');assert.notEqual(updated.id,old.id);
}finally{await db.close();}});

test('unchanged lost-save retry preserves a publication; deletion revokes and retains the private tombstone',async()=>{const db=await fixture();try{
 const work=await publish(db);assert.equal((await save(db,{revision:1})).revision,1);assert.equal((await state(db)).status,'published');
 await visibility(db,work,false,1);
 const replacement=await publish(db,{requestId:id(11),photoId:otherPid});
 assert.equal((await api(db,'work',{id:work.id})).status,'private');
 await db.query('select public.delete_weekly_moment($1,1)',[rid]);assert.equal(await state(db),null);
 assert.equal(await api(db,'work',{id:work.id}),null);
 assert.equal(await api(db,'work',{id:replacement.id}),null);
 assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);
 await assert.rejects(()=>api(db,'finalizePublication',{id:work.id}),/MOMENTS_PUBLICATION_CHANGED/);
 await login(db,null,'anon');assert.equal(await api(db,'work',{id:work.id}),null);assert.equal((await api(db,'profileMomentsPage',{userId:a})).items.length,0);
}finally{await db.close();}});

test('draft withdrawal is fenced and a delayed false request cannot withdraw a newer generation',async()=>{const db=await fixture();try{
 const draft=await begin(db);await upload(db,draft);await visibility(db,draft,false,draft.publicationRevision);await visibility(db,draft,false,draft.publicationRevision);
 assert.equal((await state(db)).status,'private');assert.equal((await state(db)).workId,null);
 await assert.rejects(()=>api(db,'finalizePublication',{id:draft.id}),/MOMENTS_PUBLICATION_CHANGED/);
 await assert.rejects(()=>begin(db),/MOMENTS_PUBLICATION_CHANGED/);
 const newer=await publish(db,{requestId:id(11),photoId:otherPid});
 await assert.rejects(()=>visibility(db,draft,false,draft.publicationRevision),/MOMENTS_PUBLICATION_CHANGED/);
 assert.equal((await state(db)).workId,newer.id);assert.equal((await state(db)).status,'published');
}finally{await db.close();}});

test('hard deletion also tombstones a previously private snapshot before private bindings cascade',async()=>{const db=await fixture();try{
 const work=await publish(db);await visibility(db,work,false,1);
 assert.equal((await api(db,'work',{id:work.id})).status,'private');
 await db.exec('reset role');await db.query('delete from moments_private.weekly_moments where id=$1',[rid]);await login(db);
 assert.equal(await state(db),null);assert.equal(await api(db,'work',{id:work.id}),null);
 assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);
}finally{await db.close();}});

test('finalized visibility requires CAS and repeating finalize never republishes a private work',async()=>{const db=await fixture();try{
 const work=await publish(db);await assert.rejects(()=>api(db,'visibility',{id:work.id,published:false}),/MOMENTS_PUBLICATION_CAS_REQUIRED/);
 await visibility(db,work,false,1);assert.equal((await state(db)).publicationRevision,2);assert.equal((await state(db)).workId,work.id);
 assert.equal((await api(db,'finalizePublication',{id:work.id})).status,'private');
 await assert.rejects(()=>visibility(db,work,true,1),/MOMENTS_PUBLICATION_CHANGED/);
 await visibility(db,work,true,2);assert.equal((await state(db)).publicationRevision,3);await visibility(db,work,true,2);assert.equal((await state(db)).publicationRevision,3);
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items.length,1);
}finally{await db.close();}});

test('abandoned draft cleanup and deleteWork clear the current generation without deleting the private record',async()=>{const db=await fixture();try{
 const draft=await begin(db);assert.equal(await api(db,'discardDrafts'),1);assert.equal((await state(db)).workId,null);await assert.rejects(()=>api(db,'finalizePublication',{id:draft.id}),/MOMENTS_PUBLICATION_CHANGED/);
 const work=await publish(db,{requestId:id(11)});await api(db,'deleteWork',{id:work.id});assert.equal((await state(db)).status,'private');assert.equal((await state(db)).workId,null);
 assert.equal((await db.query('select public.get_moment_journal($1)r',['2026-10-01'])).rows[0].r.records.length,1);
}finally{await db.close();}});

test('snapshot originals cannot be overwritten and public pagination accepts stable cursors',async()=>{const db=await fixture();try{
 const one=await publish(db);const secondRecord=id(50),thirdRecord=id(60);
 for(const record of[secondRecord,thirdRecord]){
  const p={id:id(record===secondRecord?51:61),path:`${a}/moments/${record}/${id(record===secondRecord?51:61)}.jpg`,width:900,height:1200};
  await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,owner,owner_id,metadata)values('album-assets',$1,$2::uuid,$2::uuid::text,'{\"mimetype\":\"image/jpeg\"}')",[p.path,a]);await login(db);await save(db,{record,photos:[p]});await publish(db,{recordId:record,photoId:p.id,requestId:id(record===secondRecord?52:62)});
 }
 const first=await api(db,'feed',{limit:1});assert.equal(first.hasMore,true);assert.ok(first.nextCursor);
 const next=await api(db,'feed',{limit:1,cursor:first.nextCursor});assert.notEqual(next.items[0].id,first.items[0].id);
 await assert.rejects(()=>api(db,'feed',{cursor:{id:one.id}}),/social_invalid_cursor/);
 await assert.rejects(()=>api(db,'feed',{cursor:first.nextCursor,offset:1}),/social_invalid_cursor/);
 assert.equal((await db.query("update storage.objects set metadata='{}' where bucket_id='social-snapshots' returning name")).rows.length,0);
 await db.exec('reset role');await assert.rejects(()=>db.query("update storage.objects set metadata='{}' where bucket_id='social-snapshots'"),/social_snapshot_immutable/);
 await login(db,b);assert.equal((await api(db,'feed',{following:true})).items.length,0);
}finally{await db.close();}});

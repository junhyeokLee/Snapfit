import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const modulePath=process.env.PGLITE_MODULE??'@electric-sql/pglite';
const {PGlite}=await import(modulePath);
const {pgcrypto}=await import(modulePath.replace(/index[.]js$/, 'contrib/pgcrypto.js'));
const sql=name=>readFileSync(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222';
const id=n=>`aaaaaaaa-aaaa-4aaa-8aaa-${String(n).padStart(12,'0')}`;
const rid=id(1),pid=id(2),otherPid=id(3),path=`${a}/moments/${rid}/${pid}.jpg`;
const photo={id:pid,path,width:1200,height:1600};
const second={id:otherPid,path:`${a}/moments/${rid}/${otherPid}.jpg`,width:1600,height:900};
async function fixture(){
 const db=new PGlite({extensions:{pgcrypto}});
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create schema storage;create schema album_private;
 create function auth.uid()returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth,storage to anon,authenticated;
 create table auth.users(id uuid primary key,is_anonymous boolean not null default false,deleted_at timestamptz,banned_until timestamptz,raw_app_meta_data jsonb not null default '{}',raw_user_meta_data jsonb not null default '{}');
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
  '20261028133130_social_moderation_safety_and_media.sql',
  '20261028133132_social_month_cursors_and_controls.sql',
  '20261028133232_social_revocable_media_gateway.sql',
  '20261028143428_social_restricted_owner_work_placeholders.sql',
 ]){
  const source=sql(name);
  if(name==='20261028112445_private_moment_publication_feed.sql'||name==='20261028120622_public_moment_month_collections.sql')await db.query("select public.social_api('feed','{}'::jsonb)");
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

async function entry(db,n,date,{owner=a,status='published'}={}){
 const recordId=id(100+n*10),photoId=id(101+n*10);
 const p={id:photoId,path:`${owner}/moments/${recordId}/${photoId}.jpg`,width:1200,height:1600};
 await db.exec('reset role');await db.query("insert into storage.objects(bucket_id,name,owner,owner_id,metadata)values('album-assets',$1,$2::uuid,$2::uuid::text,'{\"mimetype\":\"image/jpeg\"}')",[p.path,owner]);
 await login(db,owner);await save(db,{record:recordId,date,photos:[p],caption:`Saved caption ${n}`});
 if(status==='private')return{recordId,photo:p};
 const draft=await begin(db,{recordId,photoId,requestId:id(102+n*10)});
 if(status==='draft')return{recordId,photo:p,work:draft};
 await upload(db,draft);const work=await api(db,'finalizePublication',{id:draft.id});
 if(status==='withdrawn')await visibility(db,work,false,draft.publicationRevision);
 if(status==='edited')await save(db,{record:recordId,date,photos:[p],caption:'Edited private caption',revision:1});
 return{recordId,photo:p,work};
}
const months=(db,patch={})=>api(db,'profileMomentMonthsPage',{userId:a,...patch});
const month=(db,patch={})=>api(db,'profileMomentMonthPage',{userId:a,month:'2026-10-01',...patch});

const c='33333333-3333-4333-8333-333333333333',d='44444444-4444-4444-8444-444444444444';
async function operator(db){
 await db.exec('reset role');await db.query("insert into auth.users(id,raw_app_meta_data)values($1,'{\"role\":\"admin\"}'),($2,'{}')on conflict(id)do nothing",[c,d]);await login(db,c);
}
const report=(db,target,patch={})=>api(db,'reportContent',{targetKind:'work',targetId:target,reason:'privacy',details:'Please review this public post',requestId:id(900),...patch});
const resolve=(db,row,patch={})=>api(db,'resolveReport',{id:row.id,decision:'hide',expectedRevision:row.revision,note:'Operator review',...patch});
async function policy(db,assignments){await db.exec('reset role');await db.exec(`update social_private.safety_policy set ${assignments}`);await login(db);}


async function privileged(db){await db.exec('reset role');}
async function cap(db,work){const row=await api(db,'work',{id:work.id});return row.mediaTokens[0].token;}
async function descriptor(db,work,token,position=0){await privileged(db);return(await db.query('select public.social_media_descriptor($1,$2,$3)r',[work.id,position,token])).rows[0].r;}
async function signed(db,work,position,viewer,epoch,expiry){await privileged(db);const payload=`image|${work.id}|${position}|${viewer}|${epoch}|${expiry}`;const sig=(await db.query('select social_private.media_mac($1)r',[payload])).rows[0].r;return `v1.${expiry}.${epoch}.${viewer}.${sig}`;}
async function sqlScalar(db,sql,params=[]){return(await db.query(sql,params)).rows[0].r;}

test('gateway capability is bounded, bound to work/page/viewer, and signing primitives are inaccessible',async()=>{const db=await fixture();try{
 const work=await publish(db);const token=await cap(db,work);assert.equal((await descriptor(db,work,token)).mime,'image/png');
 assert.equal(await descriptor(db,work,token,1),null);assert.equal(await descriptor(db,{id:id(999)},token),null);assert.equal(await descriptor(db,work,token.slice(0,-1)+'z'),null);
 const [v,expiry,epoch,viewer]=token.split('.');assert.equal(v,'v1');assert.equal(viewer,a);
 const now=Number(await sqlScalar(db,'select floor(extract(epoch from statement_timestamp()))r'));
 assert.equal(await descriptor(db,work,await signed(db,work,0,a,epoch,now-1)),null);
 assert.equal(await descriptor(db,work,await signed(db,work,0,a,epoch,now+3600)),null);
 await login(db,b);await assert.rejects(()=>db.query('select public.social_media_descriptor($1,0,$2)',[work.id,token]),/permission denied/);
 for(const call of ['social_private.media_key','social_private.media_epochs','social_private.media_worker_caps'])await assert.rejects(()=>db.query('select * from '+call),/permission denied/);
 await assert.rejects(()=>db.query("select social_private.media_mac('image')"),/permission denied/);
}finally{await db.close();}});

test('privacy changes fence even an old owner capability; a new private-owner capability alone works',async()=>{const db=await fixture();try{
 const work=await publish(db);const ownerToken=await cap(db,work);await login(db,b);const otherToken=await cap(db,work);
 await login(db,null,'anon');const guestToken=await cap(db,work);assert.ok(await descriptor(db,work,guestToken));
 await login(db);await visibility(db,work,false,1);
 for(const token of[ownerToken,otherToken,guestToken])assert.equal(await descriptor(db,work,token),null);
 await login(db);const privateToken=await cap(db,work);assert.ok(await descriptor(db,work,privateToken));
 await login(db,b);assert.equal(await api(db,'work',{id:work.id}),null);
 await login(db);await visibility(db,work,true,2);assert.equal(await descriptor(db,work,ownerToken),null);assert.equal(await descriptor(db,work,privateToken),null);
}finally{await db.close();}});

test('source editing, blocking, inactive viewers and moderation revoke freshly issued capabilities',async()=>{const db=await fixture();try{
 let work=await publish(db);await login(db,b);await api(db,'ensureProfile');const token=await cap(db,work);await privileged(db);await db.query('insert into public.social_blocks(owner_id,target_id)values($1,$2)',[a,b]);assert.equal(await descriptor(db,work,token),null);
 await privileged(db);await db.query('delete from public.social_blocks');await db.query("update auth.users set banned_until=now()+interval '1 day'where id=$1",[b]);assert.equal(await descriptor(db,work,token),null);
 await privileged(db);await db.query('update auth.users set banned_until=null where id=$1',[b]);await login(db);await save(db,{revision:1,caption:'Edit private original'});assert.equal(await descriptor(db,work,token),null);
 work=(await entry(db,2,'2026-10-22')).work;const ownerToken=await cap(db,work);await privileged(db);await db.query('update public.social_works set moderation_hidden=true where id=$1',[work.id]);assert.equal(await descriptor(db,work,ownerToken),null);
}finally{await db.close();}});

test('moderated manual albums remain owner-only image-free rows beside healthy albums',async()=>{const db=await fixture();try{
 await privileged(db);await db.query("insert into public.albums(id,owner_id,cover_layers_json,ratio)values(11,$1,'{\"pages\":[{},{}]}','1:1')",[a]);await login(db);
 const manual=async(albumId,requestId)=>{const draft=await api(db,'beginPublication',{albumId,pageIndexes:[0],title:`Album ${albumId}`,requestId});await upload(db,draft);return api(db,'finalizePublication',{id:draft.id});};
 const hidden=await manual(10,id(401)),healthy=await manual(11,id(402));const oldToken=await cap(db,hidden);
 await login(db,b);const row=await report(db,hidden.id);await operator(db);await resolve(db,row);await login(db);
 const own=(await api(db,'ownWorksPage')).items;assert.equal(own.length,2);
 const restricted=own.find(work=>work.id===hidden.id),normal=own.find(work=>work.id===healthy.id);
 assert.equal(restricted.isRestricted,true);assert.equal(restricted.status,'private');assert.equal(restricted.mediaVersion,2);
 assert.deepEqual(restricted.imagePaths,[]);assert.deepEqual(restricted.mediaTokens,[]);assert.equal(restricted.sourceTemplate,null);
 assert.equal(normal.isRestricted,false);assert.equal(normal.imagePaths.length,1);assert.equal(normal.mediaTokens.length,1);
 assert.deepEqual((await api(db,'ownWorks')).map(work=>work.id).sort(),[hidden.id,healthy.id].sort());
 assert.equal((await api(db,'work',{id:hidden.id})).isRestricted,true);
 await assert.rejects(()=>api(db,'visibility',{id:hidden.id,published:true}),/social_publication_restricted/);
 await assert.rejects(()=>api(db,'beginPublication',{albumId:10,pageIndexes:[0],title:'Retry hidden source',requestId:id(403)}),/social_publication_restricted/);
 assert.equal(await descriptor(db,hidden,oldToken),null);
 for(const viewer of[b,null]){
  await login(db,viewer,viewer?'authenticated':'anon');
  assert.equal(await api(db,'work',{id:hidden.id}),null);
  assert.deepEqual((await api(db,'profileWorksPage',{userId:a})).items.map(work=>work.id),[healthy.id]);
  await assert.rejects(()=>db.query('select social_private.social_work_json($1)',[hidden.id]),/permission denied/);
  await privileged(db);assert.equal(await sqlScalar(db,'select social_private.social_work_json($1)r',[hidden.id]),null);
 }
 await login(db);assert.equal((await api(db,'ownWorksPage')).items.length,2);
 await privileged(db);assert.equal(await sqlScalar(db,'select count(*)::int r from public.albums'),2);
 assert.equal(await sqlScalar(db,"select count(*)::int r from storage.objects where bucket_id='album-assets'"),2);
}finally{await db.close();}});

test('direct snapshot SELECT and long URL minting are denied while original assets and draft uploads remain usable',async()=>{const db=await fixture();try{
 const work=await publish(db);await login(db);assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);assert.equal((await db.query("select * from storage.objects where bucket_id='album-assets'")).rows.length,2);
 await login(db,b);assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);
 await login(db,null,'anon');assert.equal((await db.query("select * from storage.objects where bucket_id='social-snapshots'")).rows.length,0);
 await login(db);const draft=await begin(db,{requestId:id(11),photoId:otherPid});assert.ok(await upload(db,draft));
}finally{await db.close();}});

async function queue(db,work){await privileged(db);const path=(await db.query('select storage_path r from public.social_work_pages where work_id=$1',[work.id])).rows[0].r;return(await db.query("insert into social_private.media_rotations(work_id,position,old_path,new_path,expected_size)values($1,0,$2,$3,1024)returning *",[work.id,path,`${a}/${id(888)}/0.png`])).rows[0];}
async function workerToken(db){await privileged(db);return sqlScalar(db,'select social_private.make_media_worker_token()r');}
async function claim(db,token){return sqlScalar(db,'select public.claim_social_media_rotations($1)r',[token]);}
const sha='a'.repeat(64);
test('rotation claims require one-use expiring HMAC and never expose queues to users',async()=>{const db=await fixture();try{
 const work=await publish(db);const job=await queue(db,work);await assert.rejects(()=>claim(db,'r1.forged.1.bad'),/media_worker_forbidden|invalid input/);
 const token=await workerToken(db);const jobs=await claim(db,token);assert.equal(jobs[0].oldPath,job.old_path);assert.equal(jobs[0].expectedSize,1024);await assert.rejects(()=>claim(db,token),/media_worker_forbidden/);
 assert.deepEqual(await claim(db,await workerToken(db)),[]);
 await login(db);await assert.rejects(()=>claim(db,token),/permission denied/);await assert.rejects(()=>db.query('select public.run_social_media_rotation_job()'),/permission denied/);
}finally{await db.close();}});

test('rotation verifies metadata and digest before mapping CAS and finishes only after exact copy survives and old key is removed',async()=>{const db=await fixture();try{
 const work=await publish(db),token=await cap(db,work),job=await queue(db,work);await claim(db,await workerToken(db));
 const mark=(hash,size)=>sqlScalar(db,'select public.mark_social_media_rotation_digest($1,$2,$3)r',[job.id,hash,size]);const commit=()=>sqlScalar(db,'select public.commit_social_media_rotation($1,$2)r',[job.id,sha]);const finish=()=>sqlScalar(db,'select public.finish_social_media_rotation($1,$2)r',[job.id,sha]);
 assert.equal(await mark(null,1024),false);assert.equal(await mark(sha,100),false);assert.equal(await mark(sha,1024),true);assert.equal(await commit(),false);
 await db.query("insert into storage.objects(bucket_id,name,metadata)values('social-snapshots',$1,'{\"mimetype\":\"image/png\",\"size\":999}')",[job.new_path]);assert.equal(await commit(),false);
 assert.equal(await sqlScalar(db,'select storage_path r from public.social_work_pages where work_id=$1',[work.id]),job.old_path);
 await db.query('delete from storage.objects where name=$1',[job.new_path]);await db.query("insert into storage.objects(bucket_id,name,metadata)values('social-snapshots',$1,'{\"mimetype\":\"image/png\",\"size\":1024}')",[job.new_path]);assert.equal(await commit(),true);assert.equal(await descriptor(db,work,token),null);assert.equal(await finish(),false);
 await db.query('delete from storage.objects where name=$1',[job.old_path]);assert.equal(await commit(),true);assert.equal(await finish(),true);assert.equal(await finish(),true);
 assert.equal(await sqlScalar(db,'select count(*)::int r from public.albums'),1);assert.equal(await sqlScalar(db,"select count(*)::int r from storage.objects where bucket_id='album-assets'"),2);
}finally{await db.close();}});

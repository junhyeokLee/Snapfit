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

test('month counts cover the whole published month before record pagination and exclude every private source',async()=>{const db=await fixture();try{
 const visible=[];
 for(let n=1;n<=15;n++)visible.push(await entry(db,n,`2026-10-${String(n).padStart(2,'0')}`));
 await entry(db,20,'2026-09-28');await entry(db,21,'2025-11-30');
 await entry(db,22,'2026-10-20',{status:'private'});await entry(db,23,'2026-10-21',{status:'draft'});
 await entry(db,24,'2026-10-22',{status:'withdrawn'});await entry(db,25,'2026-10-23',{status:'edited'});
 await entry(db,26,'2026-10-28',{owner:b});
 await login(db,null,'anon');const cards=await months(db);
 assert.deepEqual(cards.items.map(x=>[x.month,x.recordCount]),[['2026-10-01',15],['2026-09-01',1],['2025-11-01',1]]);
 assert.equal(cards.items[0].cover.id,visible.at(-1).work.id);assert.equal(cards.items[0].cover.recordDate,'2026-10-15');
 const first=await month(db);assert.equal(first.items.length,12);assert.equal(first.hasMore,true);assert.equal(first.nextOffset,12);
 const next=await month(db,{offset:12});assert.equal(next.items.length,3);assert.equal(next.hasMore,false);assert.equal(next.nextOffset,15);
 assert.equal(new Set([...first.items,...next.items].map(x=>x.id)).size,15);
 assert.deepEqual([...first.items,...next.items].map(x=>x.recordDate),visible.map(x=>x.work.recordDate).reverse());
 const encoded=JSON.stringify([cards,first,next]);
 for(const secret of['recordId','photoId','record_id','album-assets',...visible.flatMap(x=>[x.recordId,x.photo.id,x.photo.path])])assert.equal(encoded.includes(secret),false,secret);
 assert.equal((await db.query("select * from storage.objects where bucket_id='album-assets'")).rows.length,0);
}finally{await db.close();}});

test('months default to six complete books and paginate in calendar order across years',async()=>{const db=await fixture();try{
 for(let n=1;n<=8;n++)await entry(db,n,n===1?'2025-12-30':`2026-${String(n-1).padStart(2,'0')}-15`);
 await login(db,null,'anon');const first=await months(db),last=await months(db,{offset:6});
 assert.equal(first.items.length,6);assert.equal(first.hasMore,true);assert.equal(first.nextOffset,6);
 assert.equal(last.items.length,2);assert.equal(last.hasMore,false);assert.equal(last.nextOffset,8);
 assert.deepEqual([...first.items,...last.items].map(x=>x.month),['2026-07-01','2026-06-01','2026-05-01','2026-04-01','2026-03-01','2026-02-01','2026-01-01','2025-12-01']);
 assert.equal((await months(db,{limit:1})).items.length,1);
 assert.deepEqual(await month(db,{month:'2026-08-01'}),{items:[],hasMore:false,nextOffset:0});
}finally{await db.close();}});

test('the cover uses record date then public creation time then UUID; detail uses date and UUID',async()=>{const db=await fixture();try{
 const older=await entry(db,1,'2026-10-01');const latest=await entry(db,2,'2026-10-28');
 const tiedA=await entry(db,3,'2026-10-28'),tiedB=await entry(db,4,'2026-10-28');
 await db.exec('reset role');
 await db.query("update public.social_works set published_at='2026-10-28T22:00:00Z' where id=$1",[older.work.id]);
 await db.query("update public.social_works set published_at='2026-10-28T19:00:00Z' where id=$1",[latest.work.id]);
 await db.query("update public.social_works set published_at='2026-10-28T20:00:00Z' where id=any($1::uuid[])",[[tiedA.work.id,tiedB.work.id]]);
 await login(db,null,'anon');const cards=await months(db);const expectedCover=[tiedA.work.id,tiedB.work.id].sort().at(-1);
 assert.equal(cards.items[0].recordCount,4);assert.equal(cards.items[0].cover.id,expectedCover);
 const details=await month(db);assert.deepEqual(details.items.map(x=>x.id),[latest.work.id,tiedA.work.id,tiedB.work.id].sort().reverse().concat(older.work.id));
}finally{await db.close();}});

test('blocks and a source withdrawal remove cards and counts even for an already loaded public month',async()=>{const db=await fixture();try{
 const first=await entry(db,1,'2026-10-10'),second=await entry(db,2,'2026-10-11');
 await login(db,b);assert.equal((await months(db)).items[0].recordCount,2);
 await api(db,'setBlocked',{userId:a,blocked:true});assert.deepEqual((await months(db)).items,[]);assert.deepEqual((await month(db)).items,[]);
 await api(db,'setBlocked',{userId:a,blocked:false});assert.equal((await months(db)).items[0].recordCount,2);
 await login(db);await visibility(db,second.work,false,1);assert.equal((await months(db)).items[0].recordCount,1);assert.equal((await months(db)).items[0].cover.id,first.work.id);
 await db.query('select public.delete_weekly_moment($1,1)',[first.recordId]);assert.deepEqual((await months(db)).items,[]);assert.deepEqual((await month(db)).items,[]);
}finally{await db.close();}});

test('the new dispatcher keeps the publication, feed, album and reaction APIs intact and closes legacy bypasses',async()=>{const db=await fixture();try{
 const record=await entry(db,1,'2026-10-15');
 const draft=await api(db,'beginPublication',{albumId:10,pageIndexes:[0],title:'Public album',topic:'일상'});await upload(db,draft);const album=await api(db,'finalizePublication',{id:draft.id});
 assert.equal((await api(db,'profileWorksPage',{userId:a})).items[0].id,album.id);assert.equal((await api(db,'ownWorks')).length,1);
 assert.equal((await api(db,'feed')).items[0].id,record.work.id);assert.equal((await months(db)).items[0].recordCount,1);
 await login(db,b);await api(db,'setLiked',{id:record.work.id,liked:true});assert.equal((await month(db)).items[0].likeCount,1);
 await assert.rejects(()=>db.query("select social_private.social_api_moments_v1('feed','{}')"),/permission denied/);
 await assert.rejects(()=>db.query('select * from moments_private.weekly_moments'),/permission denied/);
 await assert.rejects(()=>db.query('select * from moments_private.publications'),/permission denied/);
}finally{await db.close();}});

test('month and paging inputs are bounded and private-only profiles return empty collections',async()=>{const db=await fixture();try{
 assert.deepEqual(await months(db),{items:[],hasMore:false,nextOffset:0});
 assert.deepEqual(await month(db),{items:[],hasMore:false,nextOffset:0});
 for(const value of[null,'2026-10-15','2026-13-01','2026-1-01','1899-01-01','not-a-date'])await assert.rejects(()=>month(db,{month:value}),/social_invalid_month/);
 for(const offset of[-1,10001])await assert.rejects(()=>months(db,{offset}),/social_invalid_page_offset/);
 await assert.rejects(()=>api(db,'profileMomentMonthsPage'),/social_profile_required/);
 await login(db,null,'anon');assert.deepEqual(await months(db,{userId:b}),{items:[],hasMore:false,nextOffset:0});
}finally{await db.close();}});


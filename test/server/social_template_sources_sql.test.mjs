import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const migration = name => readFileSync(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8');
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
const c='33333333-3333-4333-8333-333333333333';
const request='44444444-4444-4444-8444-444444444444';
const free={productKey:'template:official-free',title:'Official free title'};
const paid={productKey:'template:official-paid',title:'Official paid title'};
const document = (key=free.productKey) => JSON.stringify({
  pages:[{layers:[{text:'PRIVATE_CAPTION',url:'PRIVATE_PHOTO_URL'}]},{}],
  sourceTemplate:{productKey:key,title:'FORGED_TITLE',pointPrice:0},
  private:'PRIVATE_DOCUMENT',
});

async function fixture(){
 const db=new PGlite();
 await db.exec(`create role anon; create role authenticated; create role service_role;
 create schema auth; create schema storage; create schema private; create schema album_private;
 revoke all on schema album_private,private from public,anon,authenticated;
 create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
 grant usage on schema auth,storage to anon,authenticated;
 create table public.profiles(id uuid primary key,email text,name text,avatar_url text);
 create table public.albums(id bigint primary key,owner_id uuid references auth.users,cover_layers_json text,ratio text,updated_at timestamptz not null default now());
 create table public.album_members(album_id bigint references public.albums,user_id uuid references auth.users,status text default 'ACCEPTED');
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(bucket_id text,name text,metadata jsonb,primary key(bucket_id,name));
 alter table storage.objects enable row level security;
 grant select,insert,update,delete on storage.objects to anon,authenticated;
 create table public.point_shop_products(product_key text primary key,kind text,title text,point_price integer,is_active boolean);
 create table public.point_shop_ownership(user_id uuid references auth.users,product_key text references public.point_shop_products,primary key(user_id,product_key));
 insert into auth.users values('${a}'),('${b}'),('${c}');
 insert into public.point_shop_products values
 ('${free.productKey}','template','${free.title}',0,true),
 ('${paid.productKey}','template','${paid.title}',1800,true),
 ('template:inactive','template','Inactive',0,false),
 ('sticker:sample','sticker','Wrong kind',0,true),
 ('template:unpriced','template','Unpriced',null,true);`);
 await db.query('insert into public.albums(id,owner_id,cover_layers_json,ratio) values(10,$1,$2,\'3:4\'),(20,$3,\'{"pages":[{}]}\',\'1:1\')',[a,document(),b]);
 for(const name of [
  '20261025062446_social_publication_and_profiles.sql',
  '20261025062938_social_legacy_empty_pages_fallback.sql',
  '20261025073121_social_topic_taxonomy.sql',
  '20261025073122_social_idempotent_follow_state.sql',
  '20261025074127_social_public_profile_photos.sql',
  '20261025082024_social_idempotent_reaction_state.sql',
  '20261025082810_social_idempotent_comments.sql',
  '20261025083353_social_publication_conflict_http_status.sql',
  '20261025092245_collaborative_album_publication_history.sql',
  '20261026064733_social_paginated_collections.sql',
  '20261026142401_social_official_template_sources.sql',
 ]) await db.exec(migration(name));
 await as(db,a);
 return db;
}
async function as(db,user,role='authenticated'){
 await db.exec('reset role');
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user??'']);
 await db.exec(`set role ${role}`);
}
async function admin(db,sql,args=[]){await db.exec('reset role');return db.query(sql,args);}
async function api(db,action,payload={}){
 return (await db.query('select public.social_api($1,$2::jsonb) result',[action,JSON.stringify(payload)])).rows[0].result;
}
async function draft(db,extra={}){
 return api(db,'beginPublication',{albumId:10,pageIndexes:[0],title:'Public title',topic:'여행',...extra});
}
async function publish(db,extra={}){
 const d=await draft(db,extra);
 const slot=await api(db,'publicationUploadPath',{id:d.id,position:0});
 await db.query("insert into storage.objects values('social-snapshots',$1,$2::jsonb)",[slot.path,JSON.stringify({mimetype:'image/png',size:1024})]);
 return api(db,'finalizePublication',{id:d.id});
}
async function setDocument(db,value){
 await admin(db,'update public.albums set cover_layers_json=$1 where id=10',[value]);
 await as(db,a);
}

test('default opt-out and legacy documents never expose a source; payload keys cannot invent provenance',async()=>{
 const db=await fixture();try{
  const work=await publish(db,{sourceTemplate:{productKey:paid.productKey},productKey:paid.productKey});
  assert.equal(work.sourceTemplate,null);
  await setDocument(db,JSON.stringify({pages:[{}]}));
  assert.equal(await api(db,'albumTemplateSource',{albumId:10}),null);
  await assert.rejects(draft(db,{includeSourceTemplate:true,sourceTemplate:free}),/social_source_template_unavailable/);
  const legacy=await publish(db);assert.equal(legacy.sourceTemplate,null);
 }finally{await db.close();}
});

test('opted free source appears only after publication, with canonical metadata and isolated raster paths',async()=>{
 const db=await fixture();try{
  assert.deepEqual(await api(db,'albumTemplateSource',{albumId:10}),free);
  const d=await draft(db,{includeSourceTemplate:true});
  assert.equal((await api(db,'work',{id:d.id})).sourceTemplate,null);
  assert.equal(await api(db,'resolveWorkTemplate',{id:d.id}),null);
  const slot=await api(db,'publicationUploadPath',{id:d.id,position:0});
  await db.query("insert into storage.objects values('social-snapshots',$1,'{\"mimetype\":\"image/png\",\"size\":1024}')",[slot.path]);
  const work=await api(db,'finalizePublication',{id:d.id});
  assert.deepEqual(work.sourceTemplate,free);
  await as(db,null,'anon');
  assert.deepEqual(await api(db,'resolveWorkTemplate',{id:d.id}),free);
  const feed=await api(db,'feed');assert.deepEqual(feed.items[0].sourceTemplate,free);
  assert.doesNotMatch(JSON.stringify(feed),/PRIVATE_|FORGED_TITLE|pointPrice|source_album|albumId/);
  const saved=(await admin(db,'select cover_layers_json from public.albums where id=10')).rows[0].cover_layers_json;
  assert.equal(saved,document());
 }finally{await db.close();}
});

test('paid source requires author ownership, never charges or grants a viewer entitlement',async()=>{
 const db=await fixture();try{
  await setDocument(db,document(paid.productKey));
  assert.equal(await api(db,'albumTemplateSource',{albumId:10}),null);
  await assert.rejects(draft(db,{includeSourceTemplate:true}),/social_source_template_unavailable/);
  await admin(db,'insert into public.point_shop_ownership values($1,$2)',[a,paid.productKey]);
  await as(db,a);const work=await publish(db,{includeSourceTemplate:true});
  await as(db,b);assert.deepEqual(await api(db,'resolveWorkTemplate',{id:work.id}),paid);
  const ownership=await admin(db,'select user_id,product_key from public.point_shop_ownership');
  assert.deepEqual(ownership.rows,[{user_id:a,product_key:paid.productKey}]);
  assert.equal((await admin(db,'select point_price from public.point_shop_products where product_key=$1',[paid.productKey])).rows[0].point_price,1800);
 }finally{await db.close();}
});

test('unregistered, inactive, wrong kind, unpriced and malformed provenance cannot be attributed',async()=>{
 const db=await fixture();try{
  for(const key of ['template:missing','template:inactive','sticker:sample','template:unpriced','x'.repeat(191)]){
   await setDocument(db,document(key));
   assert.equal(await api(db,'albumTemplateSource',{albumId:10}),null);
   await assert.rejects(draft(db,{includeSourceTemplate:true}),/social_source_template_unavailable/);
  }
  for(const value of ['not-json','{}','[]',JSON.stringify({pages:[{}],sourceTemplate:{productKey:42}})]){
   await setDocument(db,value);
   assert.equal(await api(db,'albumTemplateSource',{albumId:10}),null);
  }
 }finally{await db.close();}
});

test('opt-in must be an actual boolean; retries cannot change the consent',async()=>{
 const db=await fixture();try{
  for(const includeSourceTemplate of [null,'true',1,[],{}]){
   await assert.rejects(draft(db,{includeSourceTemplate}),/social_invalid_template_source_opt_in/);
  }
  const first=await draft(db,{includeSourceTemplate:true,requestId:request});
  assert.deepEqual(await draft(db,{includeSourceTemplate:true,requestId:request}),first);
  await assert.rejects(draft(db,{includeSourceTemplate:false,requestId:request}),/social_publication_request_mismatch/);
  const id2='55555555-5555-4555-8555-555555555555';
  const optedOut=await draft(db,{requestId:id2});
  await admin(db,"update social_private.social_publication_sources set request_fingerprint=request_fingerprint-'includeSourceTemplate' where work_id=$1",[optedOut.id]);
  await as(db,a);
  assert.deepEqual(await draft(db,{includeSourceTemplate:false,requestId:id2}),optedOut);
  await assert.rejects(draft(db,{includeSourceTemplate:true,requestId:id2}),/social_publication_request_mismatch/);
 }finally{await db.close();}
});

test('album source lookup is owner-only and internal helpers/private bindings have no client access',async()=>{
 const db=await fixture();try{
  await as(db,null,'anon');await assert.rejects(api(db,'albumTemplateSource',{albumId:10}),/social_login_required/);
  await as(db,b);await assert.rejects(api(db,'albumTemplateSource',{albumId:10}),/social_album_owner_required/);
  await assert.rejects(db.query('select social_private.document_template_source($1,$2)',[document(),a]),/permission denied/);
  await assert.rejects(db.query("select social_private.work_template_source('00000000-0000-4000-8000-000000000000')"),/permission denied/);
  await assert.rejects(db.query('select source_template_product_key from social_private.social_publication_sources'),/permission denied/);
  const funcs=(await admin(db,"select n.nspname,p.proname,p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.oid in ('public.social_api(text,jsonb)'::regprocedure,'social_private.social_api(text,jsonb)'::regprocedure) order by n.nspname")).rows;
  assert.deepEqual(funcs,[{nspname:'public',proname:'social_api',prosecdef:false},{nspname:'social_private',proname:'social_api',prosecdef:true}]);
 }finally{await db.close();}
});

test('private/deleted/blocked works cannot resolve a source, even for the author',async()=>{
 const db=await fixture();try{
  const work=await publish(db,{includeSourceTemplate:true});
  await api(db,'visibility',{id:work.id,published:false});
  assert.equal(await api(db,'resolveWorkTemplate',{id:work.id}),null);
  assert.equal((await api(db,'work',{id:work.id})).sourceTemplate,null);
  await api(db,'visibility',{id:work.id,published:true});
  await as(db,b);await api(db,'setBlocked',{userId:a,blocked:true});
  assert.equal(await api(db,'resolveWorkTemplate',{id:work.id}),null);
  await api(db,'setBlocked',{userId:a,blocked:false});
  assert.deepEqual(await api(db,'resolveWorkTemplate',{id:work.id}),free);
  await as(db,a);await api(db,'deleteWork',{id:work.id});
  assert.equal(await api(db,'resolveWorkTemplate',{id:work.id}),null);
 }finally{await db.close();}
});

test('fresh source resolution follows availability, title and author entitlement changes',async()=>{
 const db=await fixture();try{
  await setDocument(db,document(paid.productKey));
  await admin(db,'insert into public.point_shop_ownership values($1,$2)',[a,paid.productKey]);
  await as(db,a);const work=await publish(db,{includeSourceTemplate:true});
  await admin(db,'update public.point_shop_products set is_active=false where product_key=$1',[paid.productKey]);
  await as(db,b);assert.equal(await api(db,'resolveWorkTemplate',{id:work.id}),null);
  await admin(db,"update public.point_shop_products set is_active=true,title='Updated official title' where product_key=$1",[paid.productKey]);
  await as(db,b);assert.deepEqual(await api(db,'resolveWorkTemplate',{id:work.id}),{...paid,title:'Updated official title'});
  await admin(db,'delete from public.point_shop_ownership where user_id=$1',[a]);
  await as(db,b);assert.equal(await api(db,'resolveWorkTemplate',{id:work.id}),null);
  assert.equal((await api(db,'work',{id:work.id})).sourceTemplate,null);
 }finally{await db.close();}
});

test('source opt-in retains source revision and collaboration checks, likes, saves and follow behavior',async()=>{
 const db=await fixture();try{
  await assert.rejects(draft(db,{includeSourceTemplate:true,expectedUpdatedAt:'2000-01-01T00:00:00Z'}),/social_source_changed/);
  const work=await publish(db,{includeSourceTemplate:true});
  await as(db,b);assert.equal(await api(db,'setLiked',{id:work.id,liked:true}),true);
  assert.equal(await api(db,'setSaved',{id:work.id,saved:true}),true);
  assert.equal(await api(db,'setFollowing',{userId:a,following:true}),true);
  assert.equal((await api(db,'savedWorksPage')).items[0].sourceTemplate.productKey,free.productKey);
  await admin(db,'insert into public.album_members values(10,$1,\'ACCEPTED\')',[c]);
  await as(db,a);await assert.rejects(draft(db,{includeSourceTemplate:true}),/social_collaborative_album_unsupported/);
 }finally{await db.close();}
});

test('the production rollback smoke script runs and leaves every fixture count unchanged',async()=>{
 const db=await fixture();try{
  await db.exec(`reset role;
   alter table auth.users add column email text,add column raw_app_meta_data jsonb;
   alter table public.albums add column title text default '';
   alter table public.albums alter column id add generated by default as identity(start with 100);
   alter table public.point_shop_products add column asset_id text;`);
  const counts=()=>db.query(`select (select count(*)::int from auth.users) users,
   (select count(*)::int from public.albums) albums,
   (select count(*)::int from public.point_shop_products) products,
   (select count(*)::int from public.social_works) works,
   (select count(*)::int from storage.objects) objects`);
  const before=(await counts()).rows;
  await db.exec(readFileSync(new URL('../../supabase/tests/social_template_sources_runtime.sql',import.meta.url),'utf8'));
  assert.deepEqual((await counts()).rows,before);
 }finally{await db.close();}
});

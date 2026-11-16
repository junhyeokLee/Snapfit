import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';

const modulePath=process.env.PGLITE_MODULE??'@electric-sql/pglite';
const {PGlite}=await import(modulePath);
const {pgcrypto}=await import(modulePath.endsWith('index.js')
  ? modulePath.replace(/index[.]js$/, 'contrib/pgcrypto.js')
  : '@electric-sql/pglite/contrib/pgcrypto');
const sql=name=>readFileSync(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8');
const migration='20261028165540_album_creation_idempotent_requests.sql';
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';
const absent='33333333-3333-4333-8333-333333333333';
const key=n=>`aaaaaaaa-aaaa-4aaa-8aaa-${String(n).padStart(12,'0')}`;
const seed=(overrides={})=>({
  title:'나의 첫 앨범',ratio:'1.0',cover_layers_json:'{"layers":[]}',
  cover_image_url:'',cover_thumbnail_url:'',cover_original_url:'',
  cover_preview_url:'',cover_theme:'기본',target_pages:20,...overrides,
});

// Only the Supabase platform's auth/storage shells are supplied. The albums
// table, policies, revision/asset guards and the save RPC are actual migrations.
async function fixture(){
  const db=new PGlite({extensions:{pgcrypto}});
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema extensions; create schema auth; create schema storage;
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.jwt() returns jsonb language sql stable as
      $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create table auth.users(id uuid primary key,deleted_at timestamptz,banned_until timestamptz);
    insert into auth.users(id) values('${a}'),('${b}');
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(bucket_id text,name text,owner uuid,owner_id text,
      metadata jsonb default '{}',updated_at timestamptz default now(),last_accessed_at timestamptz,
      primary key(bucket_id,name));
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql immutable as
      $$select string_to_array($1,'/')$$;
    grant usage on schema public,auth,storage to anon,authenticated,service_role;
  `);
  for(const name of [
    '20260820140500_initial_snapfit_schema.sql',
    '20260820152000_backend_gap_alignment.sql',
    '20260825000000_fix_albums_select_policy_returning.sql',
  ]) await db.exec(sql(name));
  await db.exec(`
    create table public.social_profiles(user_id uuid primary key,display_name text);
    grant select,insert,update,delete on all tables in schema public to authenticated;
    grant usage,select on all sequences in schema public to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;
  `);
  await db.exec(sql('20261025092237_album_collaboration_authorization_and_cas.sql'));
  await db.exec(sql('20261025092240_album_asset_membership_bindings.sql'));
  await db.exec(sql(migration));
  return db;
}

async function as(db,actor=a,role='authenticated'){
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[actor??'']);
  await db.exec('set role '+role);
}
async function create(db,{requestId=key(1),actor=a,payload=seed()}={}){
  return (await db.query('select public.create_album_document($1,$2,$3::jsonb) result',
    [requestId,actor,JSON.stringify(payload)])).rows[0].result;
}
async function album(db,id){
  return (await db.query('select to_jsonb(a) result from public.albums a where id=$1',[id])).rows[0]?.result;
}
async function count(db,table){
  return (await db.query('select count(*)::int value from '+table)).rows[0].value;
}

test('creation returns the ordinary complete owner row and preserves legacy INSERT',async()=>{
  const db=await fixture();try{
    await as(db);const result=await create(db);
    assert.equal(result.owner_id,a);assert.equal(result.title,'나의 첫 앨범');
    assert.equal(result.target_pages,20);assert.equal(result.total_pages,0);
    assert.deepEqual(result,await album(db,result.id));
    const legacy=(await db.query("insert into public.albums(owner_id,title,ratio,cover_layers_json) values($1,'구버전','1.0','{}') returning id",[a])).rows[0];
    assert.notEqual(legacy.id,result.id);assert.equal(await count(db,'public.albums'),2);
    await assert.rejects(()=>db.query('insert into public.albums(owner_id) values($1)',[b]),/row-level security/);
    assert.equal((await db.query("select amount from public.billing_plans where plan_code='SNAPFIT_PRO_MONTHLY'")).rows[0].amount,4900);
  }finally{await db.close();}
});

test('lost-response retry preserves one album and the exact initial row/revision',async()=>{
  const db=await fixture();try{
    await as(db);const first=await create(db);
    // Discarding the first result models a committed response lost in transit.
    for(let i=0;i<20;i++) assert.deepEqual(await create(db),first);
    assert.equal(await count(db,'public.albums'),1);
    await db.exec('reset role');assert.equal(await count(db,'album_private.creation_requests'),1);
    const saved=(await db.query('select request_fingerprint,initial_result from album_private.creation_requests')).rows[0];
    assert.equal(saved.request_fingerprint.length,64);assert.deepEqual(saved.initial_result,first);
  }finally{await db.close();}
});

test('the same request rejects changed seeds; JSON key order is canonical',async()=>{
  const db=await fixture();try{
    await as(db);const first=await create(db);
    const reordered=Object.fromEntries(Object.entries(seed()).reverse());
    assert.deepEqual(await create(db,{payload:reordered}),first);
    for(const changed of [seed({title:'다른 앨범'}),seed({target_pages:40}),seed({cover_layers_json:'{"layers":[{}]}'})]){
      await assert.rejects(()=>create(db,{payload:changed}),e=>e.code==='PT409'&&e.message==='album_creation_request_conflict');
    }
    assert.equal(await count(db,'public.albums'),1);
  }finally{await db.close();}
});

test('request identity is owner-scoped and actor replacement cannot replay another account',async()=>{
  const db=await fixture();try{
    await as(db);const first=await create(db);
    await as(db,b);await assert.rejects(()=>create(db),/album_editor_session_changed/);
    const second=await create(db,{actor:b});assert.notEqual(second.id,first.id);assert.equal(second.owner_id,b);
    assert.equal(await album(db,first.id),undefined);
    await as(db);await assert.rejects(()=>create(db,{actor:b}),/album_editor_session_changed/);
    assert.deepEqual(await create(db),first);
    await db.exec('reset role');assert.equal(await count(db,'public.albums'),2);
    await db.query("select set_config('request.jwt.claim.sub','',false)");
    await db.query('update public.albums set owner_id=$1 where id=$2',[b,first.id]);
    await as(db);await assert.rejects(()=>create(db),/album_creation_access_denied/);
  }finally{await db.close();}
});

test('login, current account and explicit expected actor are required before replay',async()=>{
  const db=await fixture();try{
    await as(db);await create(db);
    await assert.rejects(()=>create(db,{actor:null}),/album_editor_session_changed/);
    await as(db,null);await assert.rejects(()=>create(db),/album_login_required/);
    await as(db,null,'anon');await assert.rejects(()=>create(db),/permission denied/);
    await as(db,absent);await assert.rejects(()=>create(db,{actor:absent}),/album_login_required/);
    for(const state of ['deleted_at=now()','banned_until=now()+interval \'1 day\'']){
      await db.exec('reset role');await db.query('update auth.users set deleted_at=null,banned_until=null where id=$1',[a]);
      await db.query('update auth.users set '+state+' where id=$1',[a]);
      await as(db);await assert.rejects(()=>create(db),/album_login_required/);
    }
    await db.exec('reset role');assert.equal(await count(db,'public.albums'),1);
  }finally{await db.close();}
});

test('malformed, oversized and forged creation fields never claim a request',async()=>{
  const db=await fixture();try{
    await as(db);
    for(const payload of [null,[],false,7,'text']){
      await assert.rejects(()=>create(db,{payload}),e=>e.code==='22023'&&e.message==='album_invalid_creation');
    }
    for(const payload of [{},seed({owner_id:b}),seed({id:1}),seed({points:9000}),
      seed({title:null}),seed({title:'x'.repeat(81)}),seed({ratio:''}),seed({ratio:'x'.repeat(51)}),
      seed({cover_layers_json:{layers:[]}}),seed({cover_image_url:7}),seed({target_pages:null}),
      seed({target_pages:'20'}),seed({target_pages:1.5}),seed({target_pages:-1}),seed({target_pages:81})]){
      await assert.rejects(()=>create(db,{payload}),e=>e.code==='22023');
    }
    await assert.rejects(()=>create(db,{payload:seed({cover_layers_json:'x'.repeat(8388608)})}),/album_document_too_large/);
    for(const requestId of [null,'00000000-0000-0000-0000-000000000000']){
      await assert.rejects(()=>create(db,{requestId}),/album_creation_request_required/);
    }
    await db.exec('reset role');assert.equal(await count(db,'public.albums'),0);
    assert.equal(await count(db,'album_private.creation_requests'),0);
    await as(db);const empty=await create(db,{payload:seed({title:'',target_pages:0})});
    assert.equal(empty.title,'');assert.equal(empty.target_pages,0);
  }finally{await db.close();}
});

test('deleting an album tombstones its request and erases its initial private paths',async()=>{
  const db=await fixture();try{
    await as(db);const first=await create(db);
    await db.query('delete from public.albums where id=$1',[first.id]);
    await assert.rejects(()=>create(db),e=>e.code==='PT410'&&e.message==='album_creation_deleted');
    assert.equal(await count(db,'public.albums'),0);
    await db.exec('reset role');const request=(await db.query('select * from album_private.creation_requests')).rows[0];
    assert.equal(request.album_id,null);assert.equal(request.initial_result,null);assert.ok(request.deleted_at);
    // A legacy caller may explicitly reuse an identity value; the old key still
    // refers to the tombstone, never to the replacement album with the same ID.
    await as(db);await db.query("insert into public.albums(id,owner_id,title,ratio,cover_layers_json) values($1,$2,'다시 쓴 번호','1.0','{}')",[first.id,a]);
    await assert.rejects(()=>create(db),e=>e.code==='PT410');
    assert.equal((await album(db,first.id)).title,'다시 쓴 번호');
    const fresh=await create(db,{requestId:key(2)});assert.notEqual(fresh.id,first.id);
  }finally{await db.close();}
});

test('an edited album replay cannot supply a fresh revision to overwrite newer pages',async()=>{
  const db=await fixture();try{
    await as(db);const initial=await create(db);
    const changes={title:'다른 탭에서 완성',cover_layers_json:'{"pages":[{"layers":[{"text":"새 내용"}]}]}'};
    const updated=(await db.query('select public.save_album_document($1,$2,$3::jsonb,$4,$5) result',
      [initial.id,initial.updated_at,JSON.stringify(changes),key(10),a])).rows[0].result;
    assert.notEqual(updated.updated_at,initial.updated_at);
    const replay=await create(db);assert.deepEqual(replay,initial);
    await assert.rejects(()=>db.query('select public.save_album_document($1,$2,$3::jsonb,$4,$5)',
      [replay.id,replay.updated_at,JSON.stringify({title:'오래된 복구 초안'}),key(11),a]),
      e=>e.code==='PT409'&&e.message==='album_revision_conflict');
    assert.equal((await album(db,initial.id)).cover_layers_json,changes.cover_layers_json);
    assert.equal((await album(db,initial.id)).title,changes.title);
  }finally{await db.close();}
});

test('a failed asset-guard insert rolls back the key as well as the album',async()=>{
  const db=await fixture();try{
    const path=a+'/albums/images/seed.png';
    const payload=seed({cover_layers_json:JSON.stringify({layers:[{imageUrl:'supabase://album-assets/'+path}]})});
    await as(db);await assert.rejects(()=>create(db,{payload}),/album_asset_share_forbidden/);
    assert.equal(await count(db,'public.albums'),0);
    await db.exec('reset role');assert.equal(await count(db,'album_private.creation_requests'),0);
    await db.query("insert into storage.objects(bucket_id,name,owner,owner_id) values('album-assets',$1,$2::uuid,$2::uuid::text)",[path,a]);
    await as(db);const result=await create(db,{payload});assert.equal(result.cover_layers_json,payload.cover_layers_json);
    assert.deepEqual(await create(db,{payload}),result);assert.equal(await count(db,'public.albums'),1);
    await assert.rejects(()=>db.query('delete from storage.objects where name=$1',[path]),/album_asset_in_use/);
  }finally{await db.close();}
});

test('burst duplicate requests share one unique claim and independent keys stay distinct',async()=>{
  const db=await fixture();try{
    await as(db);
    // PGlite queues one backend; this covers burst API reentry and the actual
    // SQL unique/row-lock path. Multi-session contention also relies on native
    // PostgreSQL ON CONFLICT waiting semantics, not JS-side deduplication.
    const burst=await Promise.all(Array.from({length:24},()=>create(db)));
    assert.equal(new Set(burst.map(x=>x.id)).size,1);
    const distinct=await Promise.all([2,3,4].map(n=>create(db,{requestId:key(n)})));
    assert.equal(new Set(distinct.map(x=>x.id)).size,3);
    assert.equal(await count(db,'public.albums'),4);
    await db.exec('reset role');assert.equal(await count(db,'album_private.creation_requests'),4);
    const primary=(await db.query("select pg_get_constraintdef(oid) definition from pg_constraint where conrelid='album_private.creation_requests'::regclass and contype='p'")).rows[0].definition;
    assert.match(primary,/PRIMARY KEY \(actor_id, request_id\)/);
  }finally{await db.close();}
});

test('private creation bookkeeping is inaccessible; account removal cleans its private seed',async()=>{
  const db=await fixture();try{
    await as(db);await create(db);
    for(const statement of ['select * from album_private.creation_requests',
      'delete from album_private.creation_requests',
      "update album_private.creation_requests set deleted_at=null"]){
      await assert.rejects(()=>db.exec(statement),/permission denied/);
    }
    await db.exec('reset role');
    const grants=(await db.query("select has_table_privilege('authenticated','album_private.creation_requests','SELECT') s,has_table_privilege('anon','album_private.creation_requests','INSERT') i")).rows[0];
    assert.deepEqual(grants,{s:false,i:false});
    const policy=(await db.query("select relrowsecurity from pg_class where oid='album_private.creation_requests'::regclass")).rows[0];
    assert.equal(policy.relrowsecurity,true);
    await db.query("select set_config('request.jwt.claim.sub','',false)");
    await db.query('delete from auth.users where id=$1',[a]);
    assert.equal(await count(db,'public.albums'),0);assert.equal(await count(db,'album_private.creation_requests'),0);
  }finally{await db.close();}
});

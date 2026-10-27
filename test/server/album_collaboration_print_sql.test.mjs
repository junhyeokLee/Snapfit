import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {fixture as printFixture,owner,other,ctx,prepare} from './fixtures/app_pdf_database.mjs';
const migration=n=>readFileSync(new URL('../../supabase/migrations/'+n,import.meta.url),'utf8');
const update=migration('20261025093805_album_collaboration_print_asset_owners.sql');
const b=other,c='33333333-3333-4333-8333-333333333333';
const path=(actor=b,album=1)=>`${actor}/albums/${album}/images/original.jpg`;
const document=p=>JSON.stringify({printProduct:{id:'REDP_200X150_SOFT',trimWidthMm:200,trimHeightMm:150},pages:Array.from({length:20},(_,index)=>({index,isCover:index===0,layers:index===1&&p?[{id:'photo',type:'image',originalUrl:'supabase://album-assets/'+p}]:[]}))});
async function fixture(){
 const db=await printFixture();
 await db.exec(migration('20261015021421_chunked_original_print_pdfs.sql'));
 await db.exec(`alter table albums add cover_image_url text,add cover_thumbnail_url text,add cover_original_url text,add cover_preview_url text;
 alter table album_members add status text default 'ACCEPTED';
 create table storage.objects(bucket_id text,name text,owner uuid,owner_id text,metadata jsonb default '{}',updated_at timestamptz,last_accessed_at timestamptz,primary key(bucket_id,name));
 alter table storage.objects enable row level security;
 create schema album_private;revoke all on schema album_private from public,anon,authenticated;grant usage on schema album_private to authenticated,service_role;
 create function album_private.can_access_album(p_id bigint) returns boolean language sql stable security definer as $$select exists(select 1 from public.albums where id=p_id and owner_id=auth.uid())$$;
 create function album_private.can_edit_album(p_id bigint) returns boolean language sql stable security definer as $$select album_private.can_access_album(p_id)$$;
 create function album_private.collaboration_api(text,jsonb) returns jsonb language sql as $$select '{}'::jsonb$$;
 create function album_private.save_album(bigint,timestamptz,jsonb,uuid,uuid) returns jsonb language sql as $$select '{}'::jsonb$$;`);
 await db.exec(migration('20261025092240_album_asset_membership_bindings.sql'));
 await db.exec(update);
 return db;
}
async function object(db,p,actor=b){await db.query("insert into storage.objects(bucket_id,name,owner,owner_id) values('album-assets',$1,$2::uuid,$2::text)",[p,actor]);}
async function saved(db,p,{bind=true}={}){
 if(!bind)await db.exec('alter table albums disable trigger albums_sync_asset_bindings');
 await db.query('update albums set cover_layers_json=$1 where id=1',[document(p)]);
 if(!bind)await db.exec('alter table albums enable trigger albums_sync_asset_bindings');
}
const owners=async(db,actor=owner)=>(await db.query('select album_private.print_asset_owners(1,$1) r',[actor])).rows[0].r;

test('saved contributor photos remain printable after VIEWER downgrade and leaving',async()=>{const db=await fixture();try{
 await object(db,path());await db.query("insert into album_members values(1,$1,'EDITOR','ACCEPTED')",[b]);await saved(db,path());
 assert.deepEqual(await owners(db),[owner,b]);
 await db.query("update album_members set role='VIEWER' where user_id=$1",[b]);assert.deepEqual(await owners(db),[owner,b]);
 await db.query('delete from album_members where user_id=$1',[b]);assert.deepEqual(await owners(db),[owner,b]);
 const context=await ctx(db);assert.deepEqual(context.allowedAssetOwners,[owner,b]);assert.equal(context.snapshot.album.cover_layers_json,document(path()));
 const intent=await prepare(db);assert.deepEqual(intent.source_asset_owners,[owner,b]);
 await saved(db,null);assert.deepEqual((await db.query('select source_asset_owners,snapshot from private.print_checkout_intents where id=$1',[intent.id])).rows[0],{source_asset_owners:[owner,b],snapshot:intent.snapshot});
}finally{await db.close();}});
test('noncanonical contributor files need exact saved binding, never just membership',async()=>{const db=await fixture();try{
 const p=`${b}/albums/images/legacy.jpg`;await object(db,p);await saved(db,p,{bind:false});
 await db.query("insert into album_members values(1,$1,'EDITOR','ACCEPTED')",[b]);await assert.rejects(()=>owners(db),/print_asset_access_requires_review/);
 await db.query('insert into album_private.asset_bindings values(1,$1)',[p]);await db.query('delete from album_members where user_id=$1',[b]);assert.deepEqual(await owners(db),[owner,b]);
}finally{await db.close();}});
test('PENDING members without a saved file never expand frozen owner scope',async()=>{const db=await fixture();try{
 await db.query("insert into album_members values(1,$1,'EDITOR','PENDING'),(1,$2,'VIEWER','ACCEPTED')",[b,c]);
 assert.deepEqual(await owners(db),[owner]);assert.deepEqual((await ctx(db)).allowedAssetOwners,[owner]);
}finally{await db.close();}});
test('guessed other-private or other-album paths fail even when the uploader is a member',async()=>{const db=await fixture();try{
 await db.query("insert into album_members values(1,$1,'EDITOR','PENDING')",[b]);
 for(const p of [`${b}/private/secret.jpg`,path(b,99)]){await object(db,p);await saved(db,p,{bind:false});await assert.rejects(()=>owners(db),/print_asset_access_requires_review/);await assert.rejects(()=>ctx(db),/print_asset_access_requires_review/);}
}finally{await db.close();}});
test('stale bindings not in the current saved document never add an uploader',async()=>{const db=await fixture();try{
 await object(db,path());await db.query('insert into album_private.asset_bindings values(1,$1)',[path()]);
 assert.deepEqual(await owners(db),[owner]);
 const auth=(await db.query('select read_album_print_asset_authorization(1,$1) r',[owner])).rows[0].r;assert.deepEqual(auth.allowedAssetPaths,[]);
}finally{await db.close();}});
test('legacy owner references and real current files are supported; missing objects fail closed',async()=>{const db=await fixture();try{
 const p=`${owner}/albums/images/legacy.jpg`;await object(db,p,owner);await saved(db,p,{bind:false});assert.deepEqual(await owners(db),[owner]);
 await saved(db,path(),{bind:false});await assert.rejects(()=>owners(db),/print_asset_access_requires_review/);
}finally{await db.close();}});
test('private helper and public wrapper are service-only and require the actual album owner',async()=>{const db=await fixture();try{
 await assert.rejects(()=>owners(db,b),/album_owner_required/);
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);await assert.rejects(()=>db.query('select read_album_print_asset_authorization(1,$1)',[owner]),/permission denied/);await db.exec('reset role');}
 await db.exec('set role service_role');assert.deepEqual(await owners(db),[owner]);const r=(await db.query('select read_album_print_asset_authorization(1,$1) r',[owner])).rows[0].r;assert.deepEqual(r.allowedAssetOwners,[owner]);
}finally{await db.close();}});
test('alternate private URI spellings and nested legacy JSON cannot hide guessed references',async()=>{const db=await fixture();try{
 await object(db,path());await saved(db,path());
 const guessed=`${b}/private/guessed.jpg`;await object(db,guessed);
 for(const source of [`https://rrbhxdtriummqpztpjrk.supabase.co/storage/v1/render/image/sign/album-assets/${guessed}`,`SUPABASE://album-assets/${guessed}`,`https://u:p@rrbhxdtriummqpztpjrk.supabase.co/storage/v1/object/sign/album-assets/${guessed}`]){
  const doc=JSON.parse(document(path()));doc.pages[1].layers.push({previewUrl:source});
  await db.exec('alter table albums disable trigger albums_sync_asset_bindings');await db.query('update albums set cover_layers_json=$1 where id=1',[JSON.stringify(doc)]);await db.exec('alter table albums enable trigger albums_sync_asset_bindings');
  await assert.rejects(()=>owners(db),/print_asset_access_requires_review/);
 }
 const doc=JSON.parse(document(path()));doc.pages[1].layers.push({layers_json:JSON.stringify({layers:[{originalUrl:'supabase://album-assets/'+guessed}]})});
 await db.exec('alter table albums disable trigger albums_sync_asset_bindings');await db.query('update albums set cover_layers_json=$1 where id=1',[JSON.stringify(doc)]);await db.exec('alter table albums enable trigger albums_sync_asset_bindings');
 await assert.rejects(()=>owners(db),/print_asset_access_requires_review/);
}finally{await db.close();}});
test('checkout function differs from the previous definition only at source authorization',()=>{
 const old=migration('20261015021421_chunked_original_print_pdfs.sql');const a=old.indexOf('create or replace function public.load_owned_print_checkout_context('),b=old.indexOf('create or replace function public.read_print_sales_readiness',a);
 const expected=old.slice(a,b).replace("  select array_agg(distinct user_id order by user_id) into owners from (select p_actor user_id union all\n    select user_id from public.album_members where album_id=p_album_id and role in ('OWNER','EDITOR')) allowed;",'  owners:=album_private.print_asset_owners(p_album_id,p_actor);');
 assert.equal(update.slice(update.indexOf('create or replace function public.load_owned_print_checkout_context(')),expected);
});

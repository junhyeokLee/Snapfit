import assert from 'node:assert/strict';
import {test} from 'node:test';
import {getPrintSnapshot} from '../../supabase/functions/_shared/print-package.ts';
import {makeFixture,owner} from './fixtures/print_worker_fixture.mjs';
const other='22222222-2222-4222-8222-222222222222',origin='https://fixture.supabase.co';
const path=`${other}/albums/7/images/saved.jpg`;
function fixture(source=path,{paths=[path],readError=null}={}){
 const f=makeFixture();let reads=0;const signed=[];
 const order={...f.order,album_id:7,user_id:owner,print_content_snapshot:{...f.order.print_content_snapshot,album:{...f.order.print_content_snapshot.album,owner_id:owner,cover_original_url:'supabase://album-assets/'+source}}};
 const db={from(){throw Error('membership namespace queries are forbidden');},async rpc(name,args){reads++;assert.equal(name,'read_album_print_asset_authorization');assert.deepEqual(args,{p_album_id:7,p_actor:owner});return{data:{allowedAssetPaths:paths,allowedAssetOwners:[owner,other]},error:readError};},storage:{from(bucket){assert.equal(bucket,'album-assets');return{async createSignedUrl(p){signed.push(p);return{data:{signedUrl:'https://signed.invalid/'+p},error:null};}};}}};
 return{order,db,signed,get reads(){return reads;}};
}
test('historical fallback signs only the former collaborator exact server-saved file',async()=>{const f=fixture();const r=await getPrintSnapshot(f.db,f.order,origin);assert.equal(f.reads,1);assert.deepEqual(f.signed,[path]);assert.ok(r.sourceUrls['supabase://album-assets/'+path]);});
test('a guessed same-owner private file cannot piggyback on one allowed saved file',async()=>{const f=fixture(`${other}/private/guessed.jpg`);await assert.rejects(()=>getPrintSnapshot(f.db,f.order,origin),/print_asset_access_requires_review/);assert.deepEqual(f.signed,[]);});
test('existing frozen intent owner scope survives current album or membership changes without RPC',async()=>{const f=fixture(path,{paths:[]});await getPrintSnapshot(f.db,f.order,origin,{allowedAssetOwners:[owner,other]});assert.equal(f.reads,0);assert.deepEqual(f.signed,[path]);});
test('frozen owner denial never invokes historical fallback to expand the contract',async()=>{const f=fixture();await assert.rejects(()=>getPrintSnapshot(f.db,f.order,origin,{allowedAssetOwners:[owner]}),/print_asset_access_requires_review/);assert.equal(f.reads,0);assert.deepEqual(f.signed,[]);});
test('historical owner-owned files retain their old scope without current-document revalidation',async()=>{const p=`${owner}/old-paid-snapshot.jpg`,f=fixture(p,{readError:Error('unavailable')});await getPrintSnapshot(f.db,f.order,origin);assert.equal(f.reads,0);assert.deepEqual(f.signed,[p]);});
test('failed server authorization returns no contributor signed URL',async()=>{const f=fixture(path,{readError:Error('denied')});await assert.rejects(()=>getPrintSnapshot(f.db,f.order,origin),/print_asset_access_requires_review/);assert.deepEqual(f.signed,[]);});

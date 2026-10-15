import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {join} from 'node:path'
import {createHash} from 'node:crypto'
import {fixture,prepare,commit,owner,other,worker} from './fixtures/app_pdf_database.mjs'
import {createPrepaymentPackageHandler} from '../../supabase/functions/_shared/print-prepayment-package.ts'

const migration=readFileSync(new URL('../../supabase/migrations/20261015021421_chunked_original_print_pdfs.sql',import.meta.url),'utf8')
const h=c=>c.repeat(64)
async function setup(t){const db=await fixture();t.after(()=>db.close());await db.exec(migration);return{db,i:await prepare(db)}}
function report(i,changes={}){
 const bytes=60_200_362,parts=Array.from({length:Math.ceil(bytes/16_000_000)},(_,index)=>({bytes:Math.min(16_000_000,bytes-index*16_000_000),sha256:h(String(index+1))}))
 return {renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:h('f'),specVersion:i.approved_spec.specVersion,productId:i.product.id,coverType:'SOFT',pageCount:20,
  dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,missingAssets:[],warnings:[],declaredFiles:{cover:{bytes:100,sha256:h('a')},interior:{bytes,sha256:h('b'),parts}},...changes}
}
const rpc=async(db,i,action,pkg=null,kind=null,result=null,manifest=null)=>(await db.query('select print_prepayment_package($1,$2,$3,$4,$5,$6,$7,$8,$9) x',[owner,action,i.request_id,i.order_id,i.payment_id,pkg,kind,result,manifest])).rows[0].x
async function uploads(db,i,m=report(i)){return(await rpc(db,i,'uploads',null,null,{sourceFingerprint:h('f'),specVersion:i.approved_spec.specVersion},m)).package}
async function proofs(db,i,p,m,limit=4){for(const part of p.file_parts.interior.slice(0,limit))await rpc(db,i,'verify_part',p.id,'interior',{index:part.index,byteLength:part.byteLength,sha256:part.sha256},m)}
const result=(kind,m)=>({pageCount:kind==='cover'?1:20,widthMm:kind==='cover'?417.22:210,heightMm:160,byteLength:m.declaredFiles[kind].bytes,sha256:m.declaredFiles[kind].sha256})
async function finish(db,i,p,m){await proofs(db,i,p,m);for(const kind of['cover','interior'])await rpc(db,i,'finalize',p.id,kind,result(kind,m),m);return(await rpc(db,i,'seal',p.id)).package}

test('large original PDF metadata creates exact immutable 16MB private chunks, and incomplete proof cannot issue SDK',async t=>{
 const {db,i}=await setup(t),m=report(i),p=await uploads(db,i,m)
 assert.equal(p.transport_version,'CHUNKED_V1');assert.equal(p.max_file_bytes,500_000_000)
 assert.equal(p.file_parts.interior.length,4);assert.equal(p.file_parts.interior[3].byteLength,12_200_362)
 assert.equal(p.file_parts.interior[0].path,`${i.order_id}/${p.id}/interior/part-000.bin`)
 assert.equal(p.file_parts.cover,undefined)
 await proofs(db,i,p,m,3)
 await assert.rejects(rpc(db,i,'finalize',p.id,'interior',result('interior',m),m),/parts_incomplete/)
 await assert.rejects(db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id]),/print_files_not_ready/)
 await assert.rejects(db.query("update private.print_prepayment_packages set file_parts='{}' where id=$1",[p.id]),/immutable/)
 await assert.rejects(rpc(db,i,'verify_part',p.id,'interior',{index:0,byteLength:16_000_000,sha256:h('9')},m),/file_conflict/)
 await assert.rejects(db.query("update private.print_prepayment_packages set part_results='{}' where id=$1",[p.id]),/file_conflict/)
 const retry=await uploads(db,i,m);assert.equal(retry.id,p.id);assert.deepEqual(retry.file_parts,p.file_parts)
})

test('all per-part proofs plus whole PDF spec and SHA bind exactly one paid SUBMIT and one supplier PDF descriptor',async t=>{
 const {db,i}=await setup(t),m=report(i),p=await uploads(db,i,m)
 await assert.rejects(db.query('select read_print_file_delivery($1,$2,$3)',[i.order_id,p.id,'interior']),/not_found/)
 const sealed=await finish(db,i,p,m)
 assert.equal(sealed.state,'READY');assert.deepEqual(sealed.pdf_manifest.fileTransport,{version:'CHUNKED_V1',files:p.file_parts})
 assert.deepEqual(sealed.interior_result,result('interior',m))
 await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id])
 await commit(db,i)
 const delivery=(await db.query('select read_print_file_delivery($1,$2,$3) x',[i.order_id,p.id,'interior'])).rows[0].x
 assert.equal(delivery.result.byteLength,60_200_362);assert.equal(delivery.result.sha256,h('b'));assert.deepEqual(delivery.parts,p.file_parts.interior)
 assert.equal((await db.query('select count(*)::integer n from private.print_fulfillment_outbox')).rows[0].n,1)
 assert.equal((await db.query('select event_type from private.print_fulfillment_outbox')).rows[0].event_type,'SUBMIT')
 await assert.rejects(db.query('select read_print_file_delivery($1,$2,$3)',[i.order_id,p.id,'cover']),/not_found/)
 await assert.rejects(db.query('select read_print_file_delivery($1,$2,$3)',[i.order_id,'99999999-9999-4999-8999-999999999999','interior']),/not_found/)
 await db.query('update orders set print_customer_request_hold=true where order_id=$1',[i.order_id])
 await assert.rejects(db.query('select read_print_file_delivery($1,$2,$3)',[i.order_id,p.id,'interior']),/not_found/)
})

test('malformed size/order/hash/path metadata is rejected and neither app role can finalize or read delivery',async t=>{
 const {db,i}=await setup(t)
 for(const mutation of[
  m=>m.declaredFiles.interior.parts.reverse(),m=>m.declaredFiles.interior.parts.pop(),m=>m.declaredFiles.interior.parts[0].bytes++,
  m=>m.declaredFiles.interior.parts[0].path='foreign',m=>m.declaredFiles.interior.parts[0].sha256='bad',
  m=>m.declaredFiles.cover.bytes=150_000_001,m=>m.declaredFiles.interior.bytes=500_000_001,
 ]){const m=report(i);mutation(m);await assert.rejects(uploads(db,i,m),/invalid_print_prepayment_request/)}
 await assert.rejects(uploads(db,i,report(i,{fileTransport:{version:'CHUNKED_V1',files:{interior:[{path:'foreign'}]}}})),/print_prepayment_manifest_conflict/)
 const m=report(i),p=await uploads(db,i,m)
 for(const role of['anon','authenticated']){
  await db.exec('set role '+role)
  await assert.rejects(db.query('select read_print_file_delivery($1,$2,$3)',[i.order_id,p.id,'interior']),/permission denied/)
  await assert.rejects(rpc(db,i,'verify_part',p.id,'interior',{index:0,byteLength:16_000_000,sha256:h('1')},m),/permission denied/)
  await db.exec('reset role')
 }
 const permissions=(await db.query("select has_table_privilege('authenticated','private.print_prepayment_packages','SELECT') readable,has_function_privilege('anon','read_print_file_delivery(text,uuid,text)','EXECUTE') callable")).rows[0]
 assert.deepEqual(permissions,{readable:false,callable:false})
})

test('abandoned package cleanup includes only its own immutable chunks and never deletes a paid or SDK-issued packet',async t=>{
 const {db,i}=await setup(t),m=report(i),p=await uploads(db,i,m)
 const issued=await prepare(db,{request:'88888888-8888-4888-8888-888888888888'}),issuedManifest=report(issued),issuedPack=await uploads(db,issued,issuedManifest)
 await finish(db,issued,issuedPack,issuedManifest);await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,issued.payment_id])
 const paid=await prepare(db,{request:'99999999-9999-4999-8999-999999999999'}),paidManifest=report(paid),paidPack=await uploads(db,paid,paidManifest)
 await finish(db,paid,paidPack,paidManifest);await db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,paid.payment_id]);await commit(db,paid)
 // Clock advance in this isolated test only. Purchase/package expiry remains
 // immutable in the deployed schema; no production trigger is disabled.
 await db.exec("alter table private.print_checkout_intents disable trigger user;alter table private.print_prepayment_packages disable trigger user;")
 await db.exec("update private.print_checkout_intents set expires_at=now()-interval '2 hours';update private.print_prepayment_packages set expires_at=now()-interval '2 hours';")
 await db.exec('alter table private.print_checkout_intents enable trigger user;alter table private.print_prepayment_packages enable trigger user;')
 const claim=(await db.query('select claim_abandoned_print_prepayment_packages(1) x')).rows[0].x
 assert.equal(claim.length,1);assert.equal(claim[0].paths.length,7)
 assert.ok(claim[0].paths.every(path=>path.startsWith(`${i.order_id}/${p.id}/`)))
 assert.deepEqual(new Set(claim[0].paths),new Set([p.cover_path,p.interior_path,p.manifest_path,...p.file_parts.interior.map(part=>part.path)]))
 await db.query('select finish_abandoned_print_prepayment_package($1,true)',[p.id])
 assert.deepEqual((await db.query('select claim_abandoned_print_prepayment_packages(1) x')).rows[0].x,[])
 assert.deepEqual((await db.query('select id,state from private.print_prepayment_packages where id<>$1 order by id',[p.id])).rows.map(row=>row.state),['READY','READY'])
})

test('legacy direct files remain compatible under the new transport schema and current sales gates stay unchanged',async t=>{
 const {db,i}=await setup(t),m=report(i);m.declaredFiles.interior={bytes:100,sha256:h('b')}
 const p=await uploads(db,i,m);assert.equal(p.transport_version,'DIRECT_V1');assert.deepEqual(p.file_parts,{})
 const bucket=(await db.query("select public,file_size_limit,allowed_mime_types from storage.buckets where id='print-packages'")).rows[0]
 assert.equal(bucket.public,false);assert.equal(bucket.file_size_limit,104857600);assert.ok(bucket.allowed_mime_types.includes('application/pdf'));assert.ok(bucket.allowed_mime_types.includes('application/json'));assert.ok(bucket.allowed_mime_types.includes('application/octet-stream'))
 const limits=(await db.query('select load_owned_print_checkout_context($1,1) x',[owner])).rows[0].x
 assert.equal(limits.maxFileBytes,500_000_000);assert.equal(limits.maxCoverFileBytes,150_000_000)
 for(const kind of['cover','interior'])await rpc(db,i,'finalize',p.id,kind,result(kind,m),m)
 const ready=await rpc(db,i,'seal',p.id);assert.equal(ready.package.state,'READY');assert.equal(ready.package.pdf_manifest.fileTransport,undefined)
 const closed=await fixture(false);t.after(()=>closed.close());await closed.exec(migration)
 assert.equal((await closed.query('select enabled from private.print_sales_configuration')).rows[0].enabled,false)
 await assert.rejects(prepare(closed),/sales_not_ready/)
})

const actualDirectory=process.env.SNAPFIT_CHUNKED_FIXTURE_OUTPUT
test('actual 80-page original PDF → owner API → chunk proofs in real SQL → full validation/seal → SDK → one SUBMIT',{skip:!actualDirectory},async t=>{
 const db=await fixture();t.after(()=>db.close());await db.exec(migration)
 const artwork=JSON.parse(readFileSync(join(actualDirectory,'fixture.json'),'utf8')),cover=readFileSync(join(actualDirectory,'cover.pdf')),interior=readFileSync(join(actualDirectory,'interior.pdf'))
 assert.equal(artwork.fixtureOnly,true);assert.equal(artwork.spec.pageCount,80);assert.ok(interior.length>50_000_000)
 const digest=bytes=>createHash('sha256').update(bytes).digest('hex')
 await db.query('update albums set title=$1,ratio=$2,cover_layers_json=$3 where id=1',[artwork.snapshot.album.title,String(artwork.snapshot.album.ratio),typeof artwork.snapshot.album.cover_layers_json==='string'?artwork.snapshot.album.cover_layers_json:JSON.stringify(artwork.snapshot.album.cover_layers_json)])
 await db.query(`insert into private.print_sales_combinations select (jsonb_populate_record(null::private.print_sales_combinations,
  to_jsonb(c)||jsonb_build_object('product_id',$1::text,'page_count',80,'final_price',159900,'approved_spec',$2::jsonb,
   'cost_snapshot',c.cost_snapshot||jsonb_build_object('estimatedPrintCost',101860)))).*
  from private.print_sales_combinations c where product_id='REDP_200X150_SOFT' and page_count=20`,[artwork.spec.id,artwork.spec])
 await db.exec('set role service_role')
 const i=await prepare(db,{amount:159900,pages:80}),refs={requestId:i.request_id,orderId:i.order_id,paymentId:i.payment_id},files=new Map(),calls=[]
 const origin='https://synthetic-project.supabase.co',params=['p_actor','p_action','p_request_id','p_order_id','p_payment_id','p_package_id','p_file_kind','p_file_result','p_manifest']
 const adapter={async rpc(name,args){assert.equal(name,'print_prepayment_package');calls.push({rpc:name,action:args.p_action});try{return{data:(await db.query(`select print_prepayment_package(${params.map((_,index)=>`$${index+1}`).join(',')}) x`,params.map(key=>args[key]??null))).rows[0].x,error:null}}catch(error){return{data:null,error:{code:error.code,message:error.message}}}},
  storage:{async getBucket(){return{data:{public:false},error:null}},from(bucket){return{
   async createSignedUrl(path){return{data:{signedUrl:`${origin}/storage/v1/object/sign/${bucket}/${path}?token=local-stub`},error:null}},
   async createSignedUploadUrl(path,options){assert.equal(options.upsert,false);return{data:{token:'local-stub',signedUrl:`${origin}/storage/v1/object/upload/sign/${bucket}/${path}?token=local-stub`},error:null}},
   async upload(path,value,options){assert.equal(options.upsert,false);if(files.has(path))return{error:{statusCode:'409',message:'already exists'}};files.set(path,new TextEncoder().encode(value));return{error:null}},
   async download(path){return files.has(path)?{data:new Blob([files.get(path)]),error:null}:{data:null,error:{message:'missing'}}},
  }}}}
 const handler=createPrepaymentPackageHandler({getUser:async()=>({id:owner}),createAdminDatabase:()=>adapter,configuration:()=>({supabaseUrl:origin}),fetcher:async url=>{
  const path=new URL(url).pathname.split('/print-packages/')[1],bytes=files.get(path);return bytes?new Response(bytes,{headers:{'content-length':String(bytes.length)}}):new Response(null,{status:404})}})
 const call=async body=>{const response=await handler(new Request('https://example.invalid/prepayment',{method:'POST',headers:{authorization:'Bearer local-owned-auth'},body:JSON.stringify({...refs,...body})}));return{status:response.status,body:await response.json()}}
 const snapshot=await call({action:'snapshot'});assert.equal(snapshot.status,200,JSON.stringify(snapshot.body));assert.equal(snapshot.body.maxFileBytes,500_000_000)
 const manifest={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:snapshot.body.sourceFingerprint,specVersion:artwork.spec.specVersion,
  productId:artwork.spec.id,coverType:'HARD',pageCount:80,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,pdfStandard:'PDF-1.4',fit:'contain',missingAssets:[],warnings:[]}
 const declarations=[];for(let offset=0;offset<interior.length;offset+=16_000_000){const bytes=interior.subarray(offset,Math.min(interior.length,offset+16_000_000));declarations.push({bytes:bytes.length,sha256:digest(bytes)})}
 const uploaded=await call({action:'uploads',manifest,cover:{bytes:cover.length,sha256:digest(cover)},interior:{bytes:interior.length,sha256:digest(interior),parts:declarations}})
 assert.equal(uploaded.status,200,JSON.stringify(uploaded.body));const pkg=uploaded.body.packageId
 const incomplete=await call({action:'finalize',packageId:pkg,kind:'interior',manifest});assert.equal(incomplete.body.error,'print_prepayment_parts_incomplete')
 files.set(uploaded.body.cover.path,cover);assert.equal((await call({action:'finalize',packageId:pkg,kind:'cover',manifest})).status,200)
 for(const part of uploaded.body.interior.parts){files.set(part.path,interior.subarray(part.index*16_000_000,part.index*16_000_000+part.byteLength));
  const checked=await call({action:'finalize',packageId:pkg,kind:'interior',partIndex:part.index,manifest});assert.equal(checked.status,200,JSON.stringify(checked.body));assert.equal(checked.body.partVerified,true)
  await assert.rejects(db.query('select authorize_print_app_pdf_checkout($1,$2)',[owner,i.payment_id]),/print_files_not_ready/)}
 const checked=await call({action:'finalize',packageId:pkg,kind:'interior',manifest});assert.equal(checked.status,200,JSON.stringify(checked.body));assert.equal(checked.body.packageState,'READY');assert.equal(checked.body.interior.sha256,digest(interior));assert.equal(checked.body.interior.pageCount,80)
 const issued=(await db.query('select authorize_print_app_pdf_checkout($1,$2) x',[owner,i.payment_id])).rows[0].x;assert.ok(issued.sdk_issued_at)
 await commit(db,issued);await commit(db,issued)
 assert.deepEqual((await db.query('select event_type from private.print_fulfillment_outbox where order_id=$1',[i.order_id])).rows,[{event_type:'SUBMIT'}])
 const delivery=(await db.query('select read_print_file_delivery($1,$2,$3) x',[i.order_id,pkg,'interior'])).rows[0].x
 assert.equal(delivery.result.sha256,digest(interior));assert.equal(delivery.result.byteLength,interior.length);assert.equal(delivery.parts.length,declarations.length)
 assert.equal(calls.filter(row=>row.action==='verify_part').length,declarations.length)
})

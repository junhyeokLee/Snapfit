import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fixture, prepare, commit, owner, other } from './fixtures/app_pdf_database.mjs'
import { createPrepaymentPackageHandler } from '../../supabase/functions/_shared/print-prepayment-package.ts'
import { sourceFingerprint, sha256 } from '../../supabase/functions/_shared/print-contract.ts'

const origin='https://synthetic-project.supabase.co'
const outcome=async promise=>{const response=await promise;return{status:response.status,body:await response.json()}}
const request=body=>new Request('https://example.invalid/prepayment',{method:'POST',headers:{authorization:'Bearer local-owned-auth'},body:JSON.stringify(body)})
const rpcParams=['p_actor','p_action','p_request_id','p_order_id','p_payment_id','p_package_id','p_file_kind','p_file_result','p_manifest']
function sqlApi(db,files,{actor=owner,inspectPdf,publishHook}={}) {
  const calls=[]
  const adapter={async rpc(name,params){
    assert.equal(name,'print_prepayment_package');calls.push({rpc:name,params:structuredClone(params)})
    const values=rpcParams.map(key=>params[key]??null)
    try{return{data:(await db.query(`select public.print_prepayment_package(${rpcParams.map((_,i)=>`$${i+1}`).join(',')}) x`,values)).rows[0].x,error:null}}
    catch(error){return{data:null,error:{code:error.code,message:error.message}}}
  },storage:{async getBucket(){return{data:{public:false},error:null}},from(bucket){assert.ok(['print-packages','album-assets'].includes(bucket));return{
    async createSignedUrl(path){return{data:{signedUrl:`${origin}/storage/v1/object/sign/${bucket}/${path}?token=local-stub`},error:null}},
    async createSignedUploadUrl(path,options){assert.equal(options.upsert,false);calls.push({signUpload:path});return{data:{token:'local-stub',signedUrl:`${origin}/storage/v1/object/upload/sign/${bucket}/${path}?token=local-stub`},error:null}},
    async upload(path,bytes,options){assert.equal(options.upsert,false);calls.push({publish:path});if(publishHook)await publishHook(path,bytes)
      if(files.has(path))return{error:{statusCode:'409',message:'already exists'}};files.set(path,new TextEncoder().encode(bytes));return{error:null}},
    async download(path){return files.has(path)?{data:new Blob([files.get(path)]),error:null}:{data:null,error:{message:'missing'}}}
  }}}}
  const handler=createPrepaymentPackageHandler({getUser:async()=>({id:actor}),createAdminDatabase:()=>adapter,configuration:()=>({supabaseUrl:origin}),inspectPdf,
    fetcher:async url=>{const path=new URL(url).pathname.split('/print-packages/')[1];calls.push({download:path})
      return files.has(path)?new Response(files.get(path),{headers:{'content-length':String(files.get(path).byteLength)}}):new Response(null,{status:404})}})
  return{handler,calls,adapter}
}
async function setup(db,options={}) {
  const i=await prepare(db),refs={requestId:i.request_id,orderId:i.order_id,paymentId:i.payment_id},files=new Map()
  const api=sqlApi(db,files,options),snapshot=await outcome(api.handler(request({...refs,action:'snapshot'})))
  assert.equal(snapshot.status,200,JSON.stringify(snapshot.body))
  const manifest={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:snapshot.body.sourceFingerprint,specVersion:snapshot.body.spec.specVersion,
    productId:snapshot.body.spec.id,coverType:snapshot.body.spec.coverType,pageCount:20,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,pdfStandard:'PDF-1.4',fit:'contain',missingAssets:[],warnings:[]}
  return{i,refs,files,api,snapshot,manifest,
    async upload(cover,interior){return outcome(api.handler(request({...refs,action:'uploads',manifest,cover:{bytes:cover.length,sha256:await sha256(cover)},interior:{bytes:interior.length,sha256:await sha256(interior)}})))},
    async finalize(packageId,kind,extra={}){return outcome(api.handler(request({...refs,action:'finalize',packageId,kind,manifest,...extra})))}}
}
const fakePdf=kind=>new TextEncoder().encode(`%PDF-1.4\n${kind}${' '.repeat(140)}`)
function fakeInspector(bytes) {
  const cover=new TextDecoder().decode(bytes.subarray(9,14))==='cover',width=(cover?417.22:210)*72/25.4,height=160*72/25.4
  return Promise.resolve(Array.from({length:cover?1:20},()=>({width,height,trimBox:{x:5*72/25.4,y:5*72/25.4,width:width-10*72/25.4,height:height-10*72/25.4}})))
}
const owned=async(db,i)=>(await db.query('select get_owned_print_checkout($1,$2,null) x',[owner,i.payment_id])).rows[0].x
const authorize=async(db,i)=>(await db.query('select authorize_print_app_pdf_checkout($1,$2) x',[owner,i.payment_id])).rows[0].x

test('actual handler and SQL: partial PDF and unpublished manifest cannot issue SDK; sealed files bind paid order and SUBMIT outbox',async t=>{
  const db=await fixture();t.after(()=>db.close());const f=await setup(db,{inspectPdf:fakeInspector}),cover=fakePdf('cover'),interior=fakePdf('interior')
  assert.equal(f.snapshot.body.printPackageReady,false);assert.equal((await owned(db,f.i)).prepayment_package_ready,false)
  await assert.rejects(authorize(db,f.i),/print_files_not_ready/)
  const uploaded=await f.upload(cover,interior);assert.equal(uploaded.status,200)
  f.files.set(uploaded.body.cover.path,cover);f.files.set(uploaded.body.interior.path,interior)
  const first=await f.finalize(uploaded.body.packageId,'cover');assert.equal(first.status,200);assert.equal(first.body.printPackageReady,false)
  await assert.rejects(authorize(db,f.i),/print_files_not_ready/)
  const second=await f.finalize(uploaded.body.packageId,'interior');assert.equal(second.status,200);assert.equal(second.body.printPackageReady,true)
  const stored=(await db.query('select * from private.print_prepayment_packages where id=$1',[uploaded.body.packageId])).rows[0]
  assert.equal(stored.state,'READY');assert.ok(stored.verified_at)
  assert.deepEqual(JSON.parse(new TextDecoder().decode(f.files.get(stored.manifest_path))),stored.pdf_manifest)
  assert.equal((await owned(db,f.i)).prepayment_package_ready,true)
  const issued=await authorize(db,f.i);assert.ok(issued.sdk_issued_at);const paid=await commit(db,issued)
  assert.equal(paid.status,'PAID')
  const order=(await db.query('select * from orders where order_id=$1',[f.i.order_id])).rows[0]
  assert.equal(order.status,'PAYMENT_COMPLETED');assert.equal(order.print_fulfillment_status,'READY');assert.equal(order.print_upload_id,stored.id)
  assert.equal(order.print_cover_pdf_path,stored.cover_path);assert.equal(order.print_interior_pdf_path,stored.interior_path);assert.deepEqual(order.print_manifest,stored.pdf_manifest)
  const jobs=(await db.query('select * from private.print_fulfillment_outbox where order_id=$1',[f.i.order_id])).rows
  assert.equal(jobs.length,1);assert.equal(jobs[0].event_type,'SUBMIT');assert.equal(jobs[0].payload.prepaymentPackageId,stored.id)
  assert.equal(jobs.some(j=>j.event_type==='RENDER'),false)
  await assert.rejects(db.query("update orders set print_cover_pdf_path='foreign/cover.pdf' where order_id=$1",[f.i.order_id]),/print_paid_file_binding_immutable/)
  assert.equal((await f.finalize(stored.id,'interior')).status,409)
})

test('owner/foreign binding, wrong hash and forged finalization cannot advance real SQL package',async t=>{
  const db=await fixture();t.after(()=>db.close());const f=await setup(db,{inspectPdf:fakeInspector}),cover=fakePdf('cover'),interior=fakePdf('interior'),uploaded=await f.upload(cover,interior)
  f.files.set(uploaded.body.cover.path,cover)
  const foreign=sqlApi(db,f.files,{actor:other,inspectPdf:fakeInspector})
  assert.equal((await outcome(foreign.handler(request({...f.refs,action:'snapshot'})))).status,404)
  const p={p_actor:owner,p_action:'finalize',p_request_id:f.i.request_id,p_order_id:f.i.order_id,p_payment_id:f.i.payment_id,p_package_id:uploaded.body.packageId,p_file_kind:'cover'}
  const stored=(await db.query('select renderer_manifest from private.print_prepayment_packages where id=$1',[uploaded.body.packageId])).rows[0].renderer_manifest
  const result={pageCount:1,widthMm:417.22,heightMm:160,byteLength:cover.length,sha256:'f'.repeat(64)}
  const rejected=await f.api.adapter.rpc('print_prepayment_package',{...p,p_manifest:stored,p_file_result:result})
  assert.equal(rejected.error.message,'print_prepayment_file_conflict')
  for(const change of[{p_file_kind:null},{p_file_result:null},{p_file_result:{...result,sha256:await sha256(cover),pageCount:null}}]){
    const r=await f.api.adapter.rpc('print_prepayment_package',{...p,p_manifest:stored,p_file_result:result,...change});assert.ok(r.error)
  }
  const current=(await db.query('select cover_result,state from private.print_prepayment_packages where id=$1',[uploaded.body.packageId])).rows[0]
  assert.equal(current.cover_result,null);assert.equal(current.state,'UPLOADING')
  const seal=await f.api.adapter.rpc('print_prepayment_package',{...p,p_action:'seal'});assert.equal(seal.error.message,'print_prepayment_state_changed')
  await assert.rejects(db.query('update private.print_checkout_intents set prepayment_package_id=$1 where id=$2',[crypto.randomUUID(),f.i.id]),/print_prepayment_conflict|print_checkout_file_binding_immutable/)
})

test('RPC/table permissions are service-only; held pending orders remain uncharged and unsubmitted',async t=>{
  const db=await fixture();t.after(()=>db.close());const f=await setup(db,{inspectPdf:fakeInspector})
  const signature='public.print_prepayment_package(uuid,text,uuid,text,text,uuid,text,jsonb,jsonb)'
  for(const role of['anon','authenticated']){
    const r=(await db.query('select has_function_privilege($1,$2,$3) execute,has_table_privilege($1,$4,$5) read',[role,signature,'EXECUTE','private.print_prepayment_packages','SELECT'])).rows[0]
    assert.equal(r.execute,false);assert.equal(r.read,false)
  }
  assert.equal((await db.query("select relrowsecurity enabled from pg_class where oid='private.print_prepayment_packages'::regclass")).rows[0].enabled,true)
  await db.query('update orders set print_customer_request_hold=true where order_id=$1',[f.i.order_id])
  assert.equal((await f.upload(fakePdf('cover'),fakePdf('interior'))).status,409)
  assert.equal((await db.query('select count(*)::integer n from private.print_fulfillment_outbox')).rows[0].n,0)
  assert.equal((await db.query('select status from private.print_checkout_intents where id=$1',[f.i.id])).rows[0].status,'PREPARED')
})

const actualDirectory=process.env.SNAPFIT_PREPAYMENT_FIXTURE_OUTPUT
test('actual Flutter 20-page PDFs → owner handler → real SQL FILES_VERIFIED/seal → SDK authorization → exactly one SUBMIT',{skip:!actualDirectory},async t=>{
  const db=await fixture();t.after(()=>db.close())
  const artwork=JSON.parse(await readFile(join(actualDirectory,'fixture.json'),'utf8')),report=JSON.parse(await readFile(join(actualDirectory,'manifest.json'),'utf8'))
  const cover=await readFile(join(actualDirectory,'cover.pdf')),interior=await readFile(join(actualDirectory,'interior.pdf'))
  assert.equal(artwork.spec.pageCount,20);assert.equal(artwork.fixtureOnly,true)
  await db.query('update albums set title=$1,ratio=$2,cover_layers_json=$3 where id=1',[artwork.snapshot.album.title,artwork.snapshot.album.ratio,
    typeof artwork.snapshot.album.cover_layers_json==='string'?artwork.snapshot.album.cover_layers_json:JSON.stringify(artwork.snapshot.album.cover_layers_json)])
  await db.query('update private.print_sales_combinations set approved_spec=$1 where product_id=$2 and page_count=20',[artwork.spec,artwork.spec.id])
  await db.exec('set role service_role')
  const f=await setup(db)
  Object.assign(f.manifest,report,{sourceFingerprint:await sourceFingerprint({...f.snapshot.body.snapshot,
    order_id:f.i.order_id,print_content_snapshot:f.snapshot.body.snapshot,print_product_snapshot:f.i.product,page_count:20,pricing_version:'PRINT_REDP_COVERTYPE_V3'}),specVersion:f.snapshot.body.spec.specVersion})
  // The immutable snapshot is the actual renderer fixture's album document.
  const document=value=>typeof value==='string'?JSON.parse(value):value
  assert.deepEqual(document(f.snapshot.body.snapshot.album.cover_layers_json),document(artwork.snapshot.album.cover_layers_json))
  const uploaded=await f.upload(cover,interior);assert.equal(uploaded.status,200,JSON.stringify(uploaded.body))
  f.files.set(uploaded.body.cover.path,cover);f.files.set(uploaded.body.interior.path,interior)
  assert.equal((await f.finalize(uploaded.body.packageId,'cover')).body.printPackageReady,false)
  const final=await f.finalize(uploaded.body.packageId,'interior');assert.equal(final.status,200,JSON.stringify(final.body));assert.equal(final.body.printPackageReady,true)
  assert.equal(final.body.cover.byteLength,cover.length);assert.equal(final.body.interior.byteLength,interior.length);assert.equal(final.body.interior.pageCount,20)
  const i=await authorize(db,f.i);await commit(db,i);await commit(db,i)
  const jobs=(await db.query('select event_type from private.print_fulfillment_outbox where order_id=$1',[i.order_id])).rows
  assert.deepEqual(jobs,[{event_type:'SUBMIT'}]);assert.equal(f.api.calls.filter(c=>c.download).length,2)
  assert.equal(f.api.calls.filter(c=>c.publish).length,1)
})

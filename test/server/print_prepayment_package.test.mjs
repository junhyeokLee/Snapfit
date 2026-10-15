import assert from 'node:assert/strict'
import { test } from 'node:test'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { createPrepaymentPackageHandler, downloadPrepaymentPdf, PREPAYMENT_MAX_FILE_BYTES } from '../../supabase/functions/_shared/print-prepayment-package.ts'
import { inspectAppRasterPdf } from '../../supabase/functions/_shared/print-raster-pdf-inspector.ts'
import { PRINT_CHUNK_BYTES, PRINT_LARGE_FILE_BYTES } from '../../supabase/functions/_shared/print-chunked-pdf.ts'
import { sourceFingerprint, sha256 } from '../../supabase/functions/_shared/print-contract.ts'
import { makeFixture, owner } from './fixtures/print_worker_fixture.mjs'

const requestId='33333333-3333-4333-8333-333333333333',suffix='55555555-5555-4555-8555-555555555555',packageId='66666666-6666-4666-8666-666666666666'
const origin='https://fixture.supabase.co',references={requestId,orderId:`ordp_${suffix}`,paymentId:`SFP_${suffix}`}
const request=(body,auth='Bearer fixture-user')=>new Request('https://example.invalid/prepay',{method:'POST',headers:auth?{authorization:auth}:{},body:JSON.stringify({...references,...body})})
const result=async promise=>{const r=await promise;return{status:r.status,body:await r.json()}}
const fakePdf=kind=>new TextEncoder().encode(`%PDF-1.4\n${kind}${' '.repeat(140)}`)
async function fixture(overrides={},artwork={}) {
  const f=makeFixture(artwork),order={...f.order,order_id:references.orderId,status:'PAYMENT_PENDING',verified_payment_id:null,verified_payment_provider:null,payment_confirmed_at:null}
  const intent={user_id:owner,request_id:requestId,order_id:references.orderId,payment_id:references.paymentId,album_id:1,status:'PREPARED',environment:'live',currency:'KRW',
    reviewed_revision:'a'.repeat(64),reviewed_spec_revision:'b'.repeat(64),snapshot:order.print_content_snapshot,source_asset_owners:[owner],expires_at:new Date(Date.now()+86400_000).toISOString()}
  const fingerprint=await sourceFingerprint(order),spec=order.print_spec_snapshot
  const manifest={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:fingerprint,specVersion:spec.specVersion,productId:spec.id,coverType:spec.coverType,
    pageCount:spec.pageCount,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,pdfStandard:'PDF-1.4',fit:'contain',missingAssets:[],warnings:[]}
  const cover=fakePdf('cover'),interior=fakePdf('interior'),calls=[],files=new Map(),state={pack:null,parseCount:0}
  const envelope=()=>structuredClone({intent,order,package:state.pack})
  const db={async rpc(name,p){calls.push({name,p});assert.equal(name,'print_prepayment_package')
    if(p.p_actor!==owner||p.p_request_id!==requestId||p.p_order_id!==references.orderId||p.p_payment_id!==references.paymentId)return{error:{message:'print_checkout_not_found'},data:null}
    if(p.p_action==='uploads'){
      if(state.pack&&JSON.stringify(state.pack.renderer_manifest)!==JSON.stringify(p.p_manifest))return{error:{message:'print_prepayment_manifest_conflict'},data:null}
      state.pack??={id:packageId,state:'UPLOADING',source_fingerprint:fingerprint,spec_version:spec.specVersion,renderer_manifest:p.p_manifest,cover_result:null,interior_result:null,
        cover_path:`${references.orderId}/${packageId}/cover.pdf`,interior_path:`${references.orderId}/${packageId}/interior.pdf`,manifest_path:`${references.orderId}/${packageId}/manifest.json`,max_file_bytes:PRINT_LARGE_FILE_BYTES,expires_at:intent.expires_at,
        file_parts:Object.fromEntries(Object.entries(p.p_manifest.declaredFiles).filter(([,file])=>file.parts).map(([kind,file])=>[kind,file.parts.map((part,index)=>({index,path:`${references.orderId}/${packageId}/${kind}/part-${String(index).padStart(3,'0')}.bin`,byteLength:part.bytes,sha256:part.sha256}))])),part_results:{}}
      state.pack.transport_version=Object.keys(state.pack.file_parts).length?'CHUNKED_V1':'DIRECT_V1'
    }
    if(p.p_action==='verify_part'){
      assert.deepEqual(p.p_manifest,state.pack.renderer_manifest)
      const kind=p.p_file_kind,index=p.p_file_result.index
      state.pack.part_results[kind]??={};state.pack.part_results[kind][String(index)]=p.p_file_result
    }
    if(p.p_action==='finalize'){
      state.pack[`${p.p_file_kind}_result`]=p.p_file_result
      if(state.pack.cover_result&&state.pack.interior_result){state.pack.state='FILES_VERIFIED';state.pack.pdf_manifest={...manifest,spec,cover:state.pack.cover_result,interior:state.pack.interior_result,generatedAt:new Date().toISOString(),vendorReady:false,
        ...(state.pack.transport_version==='CHUNKED_V1'?{fileTransport:{version:'CHUNKED_V1',files:state.pack.file_parts}}:{})}}
    }
    if(p.p_action==='seal'){
      assert.ok(files.has(state.pack.manifest_path));state.pack.state='READY'
    }
    return{error:null,data:envelope()}
  },storage:{async getBucket(){return{data:{public:false},error:null}},from(bucket){assert.equal(bucket,'print-packages');return{
    async createSignedUploadUrl(path,options){calls.push({upload:path,options});return{data:{token:'signed-upload',signedUrl:`${origin}/storage/v1/object/upload/sign/${bucket}/${path}?token=fixture`},error:null}},
    async createSignedUrl(path){calls.push({sign:path});return{data:{signedUrl:`${origin}/storage/v1/object/sign/${bucket}/${path}?token=fixture`},error:null}},
    async upload(path,bytes,options){calls.push({publish:path,options});if(files.has(path))return{error:{statusCode:'409',message:'already exists'}};files.set(path,new TextEncoder().encode(bytes));return{error:null}},
    async download(path){return files.has(path)?{data:new Blob([files.get(path)]),error:null}:{data:null,error:{message:'missing'}}}
  }}}}
  const deps={getUser:async()=>({id:owner}),createAdminDatabase:()=>{calls.push('db');return db},configuration:()=>({supabaseUrl:origin}),
    fetcher:async url=>{const path=new URL(url).pathname.split('/print-packages/')[1];calls.push({fetch:path});return files.has(path)?new Response(files.get(path),{headers:{'content-length':String(files.get(path).length)}}):new Response(null,{status:404})},
    inspectPdf:async bytes=>{state.parseCount++;const isCover=new TextDecoder().decode(bytes.subarray(9,14))==='cover',w=(isCover?spec.cover.widthMm:210)*72/25.4,h=160*72/25.4;
      return Array.from({length:isCover?1:20},()=>({width:w,height:h,trimBox:{x:5*72/25.4,y:5*72/25.4,width:w-10*72/25.4,height:h-10*72/25.4}}))},...overrides}
  return{handler:createPrepaymentPackageHandler(deps),deps,db,calls,order,intent,manifest,cover,interior,state,files,
    async uploads(changes={}){return result(this.handler(request({action:'uploads',manifest,cover:{bytes:cover.length,sha256:await sha256(cover)},interior:{bytes:interior.length,sha256:await sha256(interior)},...changes})))},
    async finalize(kind,changes={}){return result(this.handler(request({action:'finalize',packageId,kind,manifest,...changes})))}}
}

test('anonymous/stale owner and malformed refs do not gain source/storage URLs or read secrets',async()=>{
  for(const [overrides,auth]of[[{},null],[{getUser:async()=>null},'Bearer stale']]){const f=await fixture(overrides);assert.equal((await result(f.handler(request({action:'snapshot'},auth)))).status,401);assert.equal(f.calls.includes('db'),false)}
  const f=await fixture();assert.equal((await result(f.handler(request({action:'snapshot',paymentId:'SFP_forged'})))).status,400)
  assert.equal((await result(f.handler(request({action:'snapshot',orderId:`ordp_${requestId}`})))).status,404)
  assert.equal((await result(f.handler(request({action:'snapshot',userId:owner})))).status,400)
  assert.equal((await result(f.handler(request({action:'snapshot',padding:'x'.repeat(140_000)})))).status,413)
})
test('frozen unpaid snapshot is signed without fabricated PAID fields, and disallows paid/held/expired mutation',async()=>{
  const f=await fixture(),r=await result(f.handler(request({action:'snapshot'})));assert.equal(r.status,200);assert.equal(r.body.sourceFingerprint,await sourceFingerprint(f.order));assert.equal(r.body.maxFileBytes,500_000_000);assert.equal(r.body.maxCoverFileBytes,150_000_000)
  assert.deepEqual(r.body.snapshot,f.order.print_content_snapshot);assert.equal(f.order.verified_payment_id,null);assert.equal(r.body.packageState,'NONE')
  for(const change of[x=>x.intent.request_hold=true,x=>x.intent.status='PAID',x=>x.intent.expires_at='2020-01-01T00:00:00Z']){const item=await fixture();change(item);assert.equal((await result(item.handler(request({action:'snapshot'})))).status,409)}
})
test('uploads are exact owner/server paths, no upsert, immutable manifest and Free per-file cap',async()=>{
  const f=await fixture();const r=await f.uploads();assert.equal(r.status,200);assert.equal(r.body.packageId,packageId);assert.equal(r.body.printPackageReady,false)
  assert.equal(r.body.cover.path,`${references.orderId}/${packageId}/cover.pdf`);assert.equal(r.body.reviewedRevision,'a'.repeat(64))
  assert.equal(f.calls.filter(x=>x.upload).length,2);assert.ok(f.calls.filter(x=>x.upload).every(x=>x.options.upsert===false))
  assert.equal((await f.uploads()).body.packageId,packageId)
  assert.equal((await f.uploads({cover:{bytes:150_000_001,sha256:'f'.repeat(64)}})).status,413)
  assert.equal((await f.uploads({cover:{bytes:50_000_001,sha256:'f'.repeat(64)}})).status,400)
  assert.equal((await f.uploads({manifest:{...f.manifest,sourceFingerprint:'c'.repeat(64)}})).status,409)
  assert.equal((await f.uploads({manifest:{...f.manifest,warnings:['changed']}})).status,409)
  assert.equal((await f.uploads({manifest:{...f.manifest,fileTransport:{version:'CHUNKED_V1',files:{}}}})).status,409)
})
test('large files use immutable 16MB parts; every true hash receipt is required and a caller cannot skip PDF inspection',async()=>{
  const f=await fixture(),bytes=new Uint8Array(50_000_001),declarations=[]
  for(let offset=0;offset<bytes.length;offset+=PRINT_CHUNK_BYTES){const part=bytes.subarray(offset,Math.min(bytes.length,offset+PRINT_CHUNK_BYTES));declarations.push({bytes:part.length,sha256:await sha256(part)})}
  const file={bytes:bytes.length,sha256:await sha256(bytes),parts:declarations}
  const uploaded=await f.uploads({interior:file});assert.equal(uploaded.status,200);assert.equal(uploaded.body.maxFileBytes,500_000_000)
  assert.equal((await result(f.handler(request({action:'snapshot'})))).body.fileRecovery,undefined)
  const parts=uploaded.body.interior.parts;assert.equal(parts.length,4);assert.ok(parts.every(part=>part.byteLength<=16_000_000));assert.equal(uploaded.body.interior.path,undefined)
  assert.equal((await f.finalize('interior')).body.error,'print_prepayment_parts_incomplete')
  assert.equal((await f.finalize('interior',{partIndex:1.5})).status,400)
  assert.equal((await f.finalize('cover',{partIndex:0})).status,409)
  assert.equal((await f.finalize('interior',{partIndex:0})).body.error,'print_upload_missing')
  for(const part of parts)f.files.set(part.path,bytes.subarray(part.index*PRINT_CHUNK_BYTES,part.index*PRINT_CHUNK_BYTES+part.byteLength))
  const corrupted=bytes.subarray(0,parts[0].byteLength).slice();corrupted[20]=1;f.files.set(parts[0].path,corrupted)
  assert.equal((await f.finalize('interior',{partIndex:0})).body.error,'print_upload_hash_mismatch');assert.deepEqual(f.state.pack.part_results,{})
  f.files.set(parts[0].path,bytes.subarray(0,parts[0].byteLength))
  for(const part of parts){const checked=await f.finalize('interior',{partIndex:part.index});assert.equal(checked.status,200);assert.equal(checked.body.partVerified,true);assert.equal(checked.body.partIndex,part.index);assert.equal(checked.body.kind,'interior');assert.equal(checked.body.printPackageReady,false)}
  // Complete parts alone cannot imply the other direct PDF was checked.
  assert.equal((await result(f.handler(request({action:'snapshot'})))).body.fileRecovery,undefined)
  f.files.set(f.state.pack.cover_path,f.cover);assert.equal((await f.finalize('cover')).status,200)
  const recovery=await result(f.handler(request({action:'snapshot'})))
  assert.equal(recovery.status,200);assert.deepEqual(recovery.body.fileRecovery,{packageId,manifest:f.manifest})
  assert.doesNotMatch(JSON.stringify(recovery.body.fileRecovery),/declaredFiles|file_parts|part_results|signed-upload|fixture\.supabase|cover\.pdf|interior\.pdf/)
  const received=f.state.pack.part_results.interior['0'];f.state.pack.part_results.interior['0']={...received,sha256:'f'.repeat(64)}
  assert.equal((await result(f.handler(request({action:'snapshot'})))).body.fileRecovery,undefined)
  f.state.pack.part_results.interior['0']=received
  const before=f.calls.filter(call=>call.fetch).length;assert.equal((await f.finalize('interior',{partIndex:0})).body.partVerified,true);assert.equal(f.calls.filter(call=>call.fetch).length,before)
  const inspected=await f.finalize('interior');assert.equal(inspected.body.error,'invalid_app_print_pdf');assert.equal(f.state.pack.interior_result,null);assert.equal(f.state.pack.state,'UPLOADING')
  assert.equal(f.calls.some(call=>call.name==='commit_production_print_payment'),false)
  assert.equal((await f.uploads({interior:{...file,sha256:'a'.repeat(64)}})).status,409)
  const path=f.state.pack.file_parts.interior[0].path;f.state.pack.file_parts.interior[0].path='another-owner/x.bin'
  assert.equal((await f.finalize('interior',{partIndex:0})).status,409);f.state.pack.file_parts.interior[0].path=path
})
test('existing direct packages retain their immutable 50MB cap and remain readable',async()=>{
  const f=await fixture();await f.uploads();f.state.pack.max_file_bytes=50_000_000
  const status=await result(f.handler(request({action:'status'})));assert.equal(status.status,200);assert.equal(status.body.maxFileBytes,50_000_000);assert.equal(status.body.maxCoverFileBytes,50_000_000)
})
test('one file at a time: hashes, geometry, and canonical manifest seal are all required before READY',async()=>{
  const f=await fixture();await f.uploads();f.files.set(f.state.pack.cover_path,f.cover);f.files.set(f.state.pack.interior_path,f.interior)
  const first=await f.finalize('cover');assert.equal(first.status,200);assert.equal(first.body.printPackageReady,false);assert.equal(first.body.cover.pageCount,1)
  assert.equal(f.calls.filter(x=>x.fetch).length,1);assert.equal(f.state.parseCount,1)
  const second=await f.finalize('interior');assert.equal(second.status,200);assert.equal(second.body.packageState,'READY');assert.equal(second.body.printPackageReady,true);assert.equal(f.state.parseCount,2)
  const saved=JSON.parse(new TextDecoder().decode(f.files.get(f.state.pack.manifest_path)));assert.equal(saved.cover.sha256,await sha256(f.cover));assert.equal(saved.interior.sha256,await sha256(f.interior));assert.equal(saved.vendorReady,false)
  assert.equal((await f.finalize('interior')).body.printPackageReady,true);assert.equal(f.state.parseCount,2);assert.equal(f.calls.filter(x=>x.publish).length,1)
  assert.equal(f.calls.some(x=>x.name==='commit_production_print_payment'),false)
})
test('malformed/stale package refs, altered file or manifest cannot finalize',async()=>{
  const f=await fixture();await f.uploads();f.files.set(f.state.pack.cover_path,f.cover)
  assert.equal((await f.finalize('cover',{packageId:requestId})).status,409)
  assert.equal((await f.finalize('cover',{manifest:{...f.manifest,warnings:['tamper']}})).status,409)
  const changed=f.cover.slice();changed[20]=88;f.files.set(f.state.pack.cover_path,changed)
  assert.equal((await f.finalize('cover')).body.error,'print_upload_hash_mismatch');assert.equal(f.state.pack.cover_result,null)
  f.files.set(f.state.pack.cover_path,f.cover);f.state.pack.cover_path='another-owner/cover.pdf'
  assert.equal((await f.finalize('cover')).status,503)
})
test('bounded download refuses redirect/origin, oversized content length/chunks, and truncation',async()=>{
  const f=await fixture();await f.uploads();const path=f.state.pack.cover_path
  for(const response of[new Response(new Uint8Array(200),{headers:{'content-length':'200'}}),new Response(new Uint8Array(200)),new Response(new Uint8Array(90))]){
    await assert.rejects(downloadPrepaymentPdf(f.db,path,100,origin,async()=>response),/print_upload_size_mismatch/)
  }
  await assert.rejects(downloadPrepaymentPdf(f.db,path,50_000_001,origin),/print_pdf_too_large/)
  const db={storage:{from:()=>({createSignedUrl:async()=>({data:{signedUrl:`https://attacker.invalid/${path}`}})})}}
  let fetches=0;await assert.rejects(downloadPrepaymentPdf(db,path,100,origin,async()=>{fetches++;throw Error('should not fetch')}),/print_upload_missing/);assert.equal(fetches,0)
})
test('storage manifest publication failure is retryable; both parsed immutable files are not re-downloaded',async()=>{
  const f=await fixture();await f.uploads();f.files.set(f.state.pack.cover_path,f.cover);f.files.set(f.state.pack.interior_path,f.interior)
  await f.finalize('cover');const storage=f.db.storage.from.bind(f.db.storage);let fail=true
  f.db.storage.from=bucket=>({...storage(bucket),upload:async(...args)=>fail?{error:{message:'offline'}}:storage(bucket).upload(...args)})
  assert.equal((await f.finalize('interior')).status,503);assert.equal(f.state.pack.state,'FILES_VERIFIED');assert.equal(f.state.parseCount,2)
  const recovered=await result(f.handler(request({action:'snapshot'})))
  assert.deepEqual(recovered.body.fileRecovery,{packageId,manifest:f.manifest});assert.equal(recovered.body.printPackageReady,false)
  fail=false;assert.equal((await f.finalize('interior')).body.printPackageReady,true);assert.equal(f.state.parseCount,2)
  assert.equal((await result(f.handler(request({action:'snapshot'})))).body.fileRecovery,undefined)
})

test('concurrent file finalization in one Edge isolate never holds two full PDF buffers',async()=>{
  const f=await fixture();await f.uploads();f.files.set(f.state.pack.cover_path,f.cover)
  const inspect=f.deps.inspectPdf;let resume,started
  const paused=new Promise(resolve=>{resume=resolve}),entered=new Promise(resolve=>{started=resolve})
  f.deps.inspectPdf=async bytes=>{started();await paused;return inspect(bytes)}
  const first=f.finalize('cover');await entered
  const second=await f.finalize('cover');assert.equal(second.status,429);assert.equal(second.body.error,'print_validation_busy');assert.equal(second.body.retryable,true)
  resume();assert.equal((await first).status,200);assert.equal(f.state.parseCount,1)
})

test('portable real JPEG/ICC PDF fixture forbids active dictionaries, foreign profile, fake image dimensions and malformed stream/xref',async()=>{
  const fixture=JSON.parse(await readFile(new URL('./fixtures/prepayment_raster_pdf.json',import.meta.url),'utf8'))
  const bytes=Buffer.from(fixture.base64,'base64'),pages=await inspectAppRasterPdf(bytes)
  assert.equal(pages.length,1);assert.equal(pages[0].width,2.83465)
  const alter=(from,to)=>{assert.equal(from.length,to.length);const modified=Buffer.from(bytes),at=modified.indexOf(Buffer.from(from));assert.ok(at>=0);modified.set(Buffer.from(to),at);return modified}
  await assert.rejects(inspectAppRasterPdf(alter('/Type /Catalog','/AA   /Catalog')),/invalid_app_print_pdf/)
  const cmyk=Buffer.from(bytes);cmyk.set(Buffer.from('CMYK'),cmyk.indexOf(Buffer.from('acsp'))-20)
  await assert.rejects(inspectAppRasterPdf(cmyk),/invalid_print_icc_profile/)
  await assert.rejects(inspectAppRasterPdf(alter('/Width 12','/Width 99')),/print_raster_resolution_too_low/)
  await assert.rejects(inspectAppRasterPdf(alter('0000000031','0000000032')),/invalid_app_print_pdf/)
  await assert.rejects(inspectAppRasterPdf(alter('endstream','endstreaX')),/invalid_app_print_pdf/)
  await assert.rejects(inspectAppRasterPdf(alter('/TrimBox','/CropBox')),/print_trim_box_mismatch/)
  const profile=Buffer.from(bytes);const signature=profile.indexOf(Buffer.from('acsp'));profile[signature+60]^=1
  await assert.rejects(inspectAppRasterPdf(profile),/print_srgb_profile_mismatch/)
})

const actualDirectory=process.env.SNAPFIT_PREPAYMENT_FIXTURE_OUTPUT
test('actual Flutter JPEG/ICC raster PDFs pass the bounded strict grammar; hidden action/xref/stream tampering fails',{skip:!actualDirectory},async()=>{
  for(const file of['cover.pdf','interior.pdf']){
    const bytes=await readFile(join(actualDirectory,file)),pages=await inspectAppRasterPdf(bytes);assert.ok(pages.length>0)
    const header=Buffer.from(bytes);header[0]=0;await assert.rejects(inspectAppRasterPdf(header),/invalid_app_print_pdf/)
    const xref=Buffer.from(bytes);const at=xref.lastIndexOf(Buffer.from('xref\n0 '));xref[at]=0;await assert.rejects(inspectAppRasterPdf(xref),/invalid_app_print_pdf/)
    const hidden=Buffer.concat([bytes,Buffer.from('/OpenAction')]);await assert.rejects(inspectAppRasterPdf(hidden),/invalid_app_print_pdf/)
    const renamed=Buffer.from(bytes);const dictAt=renamed.indexOf(Buffer.from('/Type /Catalog'));renamed.set(Buffer.from('/AA   /Catalog'),dictAt);await assert.rejects(inspectAppRasterPdf(renamed),/invalid_app_print_pdf/)
  }
})

const actualLargeDirectory=process.env.SNAPFIT_CHUNKED_FIXTURE_OUTPUT
test('actual 80-page owner package seals only after every part and the full original SHA pass; wrong aggregate SHA never becomes READY',{skip:!actualLargeDirectory},async()=>{
  const artwork=JSON.parse(await readFile(join(actualLargeDirectory,'fixture.json'),'utf8')),
    cover=await readFile(join(actualLargeDirectory,'cover.pdf')),interior=await readFile(join(actualLargeDirectory,'interior.pdf')),parts=[]
  for(let offset=0;offset<interior.length;offset+=PRINT_CHUNK_BYTES){const bytes=interior.subarray(offset,Math.min(interior.length,offset+PRINT_CHUNK_BYTES));parts.push({bytes:bytes.length,sha256:await sha256(bytes)})}
  for(const wrongWholeHash of[true,false]){
    const f=await fixture({inspectPdf:inspectAppRasterPdf},artwork),uploads=await f.uploads({cover:{bytes:cover.length,sha256:await sha256(cover)},
      interior:{bytes:interior.length,sha256:wrongWholeHash?'a'.repeat(64):await sha256(interior),parts}})
    assert.equal(uploads.status,200);f.files.set(uploads.body.cover.path,cover)
    assert.equal((await f.finalize('cover')).status,200)
    for(const part of uploads.body.interior.parts){f.files.set(part.path,interior.subarray(part.index*PRINT_CHUNK_BYTES,part.index*PRINT_CHUNK_BYTES+part.byteLength));assert.equal((await f.finalize('interior',{partIndex:part.index})).body.partVerified,true)}
    const finished=await f.finalize('interior')
    if(wrongWholeHash){assert.equal(finished.body.error,'print_upload_hash_mismatch');assert.equal(f.state.pack.state,'UPLOADING');assert.equal(f.state.pack.interior_result,null)}
    else{assert.equal(finished.status,200);assert.equal(finished.body.packageState,'READY');assert.equal(finished.body.printPackageReady,true);assert.equal(finished.body.interior.sha256,await sha256(interior));assert.equal(finished.body.interior.byteLength,interior.length);assert.equal(finished.body.interior.pageCount,80)
      assert.deepEqual(Object.keys(finished.body.interior).sort(),['byteLength','heightMm','pageCount','sha256','widthMm']);assert.deepEqual(f.state.pack.pdf_manifest.fileTransport,{version:'CHUNKED_V1',files:f.state.pack.file_parts})}
    assert.equal(f.calls.some(call=>call.name==='commit_production_print_payment'),false)
  }
})

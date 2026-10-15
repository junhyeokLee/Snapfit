import { corsHeaders } from './cors.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'
import { OrderPaymentError } from './order-types.ts'
import { PRINT_BUCKET, sourceFingerprint, sha256 } from './print-contract.ts'
import { canonicalPrintReview, printCheckoutRevision } from './production-print-checkout.ts'
import { assertFulfillmentAssetSources } from './print-fulfillment-assets.ts'
import { resolvePrintAssetPath, validatePrintPdf } from './print-package.ts'
import { inspectAppRasterPdf } from './print-raster-pdf-inspector.ts'
import { downloadPrepaymentPdf } from './print-prepayment-package.ts'
import { checkedChunkParts, createChunkedPdfReader, downloadChunkPdfPart, PRINT_CHUNK_BYTES, validateChunkedPrintPdf } from './print-chunked-pdf.ts'
import { assertDevelopment, vendorTestRecipient, testPrintSpec, type RedprintingEnvironment } from './redprinting.ts'

type Row = Record<string, any>
export type PrintDevCheckoutDependencies = { getUser: VerifiedUserLookup; createAdminDatabase(): any;
 configuration(): { enabled: boolean; paymentEnvironment: string; storeId: string; channelKey: string; supabaseUrl: string; vendor: RedprintingEnvironment };
 fetcher?: typeof fetch; now?: () => number }
const route = { storeId: 'store-33df409e-0ad9-4953-8194-70db7e32efae', channelKey: 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88' }
const object = (value: unknown): Row => value && typeof value === 'object' && !Array.isArray(value) ? value as Row : {}
const uuid = (v: unknown): v is string => typeof v === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v)
const hash = (v: unknown) => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v)
const canonical = (v: any): string => JSON.stringify(v, (_, value) => value && typeof value === 'object' && !Array.isArray(value) ? Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b))) : value)
const fail = (message: string, status = 409): never => { throw new OrderPaymentError(message, status) }
const json = (value: unknown, status = 200) => Response.json(value, { status, headers: { ...corsHeaders, 'Cache-Control': 'no-store' } })
async function rpc(db: any, name: string, params: Row): Promise<Row> {
 const {data,error} = await db.rpc(name,params)
 if(error){const message=String(error.message??'');if(error.code==='42501')return fail('album_access_denied',403);
 if(error.code==='P0002')return fail('print_dev_checkout_not_found',404);
 if(/^(?:print_dev_|print_prepayment_|invalid_print_|test_payment_|print_album_changed|album_access_denied)[a-z0-9_]*$/.test(message))return fail(message,message.startsWith('invalid_')?400:409);
 return fail('print_dev_database_unavailable',503)}
 return object(data)
}
async function body(request:Request){
 if(!request.body)return fail('invalid_print_dev_request',400)
 const reader=request.body.getReader(),bytes=new Uint8Array(140_000);let offset=0
 try{for(;;){const part=await reader.read();if(part.done)break;if(offset+part.value.length>bytes.length)return fail('invalid_print_dev_request',413);bytes.set(part.value,offset);offset+=part.value.length}
 try{return object(JSON.parse(new TextDecoder().decode(bytes.subarray(0,offset))))}catch{return fail('invalid_print_dev_request',400)}}finally{try{await reader.cancel()}catch{}reader.releaseLock()}
}
function context(value:Row,actor:string,input:Row,now:number,mutable=false){
 const c=object(value.checkout),s=object(value.session),p=value.package==null?null:object(value.package)
 if(c.owner_id!==actor||!uuid(c.id)||c.order_id!==`ordp_${c.id}`||!uuid(c.request_id)||!Number.isSafeInteger(c.album_id)||c.environment!=='test'||c.currency!=='KRW'||c.total_amount!==159900||c.product?.id!=='REDP_300_HARD'||c.spec?.pageCount!==80||c.spec?.verified!==false||!hash(c.reviewed_revision)||!hash(c.reviewed_spec_revision)||
 s.owner_id!==actor||s.payment_id!==c.payment_id||!/^SFPGT_[a-f0-9-]{36}$/.test(c.payment_id??'')||s.store_id!==route.storeId||s.channel_key!==route.channelKey||s.environment!=='test'||s.total_amount!==159900||!['PREPARED','VERIFIED_TEST'].includes(s.status))return fail('print_dev_record_invalid',503)
 if(input.runId!==undefined&&(c.id!==input.runId||c.request_id!==input.requestId||c.order_id!==input.orderId||c.payment_id!==input.paymentId||c.album_id!==input.albumId))return fail('print_dev_checkout_not_found',404)
 if(p){const base=`${c.order_id}/${p.id}`;if(!uuid(p.id)||p.checkout_id!==c.id||c.package_id!==p.id||p.cover_path!==`${base}/cover.pdf`||p.interior_path!==`${base}/interior.pdf`||p.manifest_path!==`${base}/manifest.json`||p.max_file_bytes!==500_000_000||!['UPLOADING','FILES_VERIFIED','READY'].includes(p.state))return fail('print_dev_record_invalid',503)}
 if(mutable&&(c.sdk_issued_at||Date.parse(c.expires_at)<=now||!['PREPARING','READY'].includes(c.status)))return fail('print_dev_state_changed')
 return{c,s,p}
}
function output(ctx:ReturnType<typeof context>,sourceFp?:string,includeRecipient=true){const{c,s,p}=ctx;return{albumTitle:c.album_title??c.snapshot?.album?.title??'앨범',createdAt:c.created_at,productId:'REDP_300_HARD',pageCount:80,coverType:'HARD',...(includeRecipient?{recipient:{name:c.recipient?.name??'',phone:c.recipient?.tel??'',zipCode:c.recipient?.zipcode??'',addressLine1:c.recipient?.address??'',addressLine2:c.recipient?.addressDetail??'',deliveryMemo:c.recipient?.message??''}}:{}),environment:'test',isTest:true,productionApproved:false,id:c.id,runId:c.id,orderId:c.order_id,paymentId:c.payment_id,requestId:c.request_id,albumId:c.album_id,totalAmount:159900,currency:'KRW',
 reviewedRevision:c.reviewed_revision,reviewedSpecRevision:c.reviewed_spec_revision,sourceFingerprint:sourceFp??p?.source_fingerprint??null,
 status:s.status,stage:c.status,packageId:p?.id??null,packageState:p?.state??'NONE',printPackageReady:p?.state==='READY',maxFileBytes:500_000_000,maxCoverFileBytes:150_000_000,
 cover:p?.cover_result??null,interior:p?.interior_result??null,expiresAt:c.expires_at,sdkIssuedAt:c.sdk_issued_at??null,
 receipt:s.status==='VERIFIED_TEST'?s.receipt:null,verifiedAt:s.verified_at??null,devOrderNum:c.submitted_at?`SFD${c.id.replaceAll('-','')}`:null,vendorStatus:c.vendor_status,errorCode:c.error_code,lastStatusAt:c.last_status_at}}
function order(c:Row){return{order_id:c.order_id,user_id:c.owner_id,album_id:c.album_id,page_count:80,pricing_version:'PRINT_REDP_COVERTYPE_V3',print_content_snapshot:c.snapshot,print_product_snapshot:c.product}}
async function snapshot(db:any,c:Row,origin:string){
 assertFulfillmentAssetSources(c.snapshot,origin,c.source_asset_owners)
 const sources=new Set<string>(),visit=(value:any,key='')=>{if(typeof value==='string'){if(/^(?:cover_layers_json|layers_json)$/.test(key)){try{visit(JSON.parse(value))}catch{return fail('invalid_print_snapshot')}}else if(/(?:originalUrl|previewUrl|imageUrl|textFillImageUrl|original_url|preview_url|image_url|thumbnail_url)$/.test(key))sources.add(value)}else if(Array.isArray(value))value.forEach(v=>visit(v));else if(value&&typeof value==='object')Object.entries(value).forEach(([k,v])=>visit(v,k))}
 visit(c.snapshot);const sourceUrls:Row={},owners=new Set<string>(c.source_asset_owners)
 for(const source of sources){const path=resolvePrintAssetPath(source,origin,owners);if(!path)continue;const signed=await db.storage.from('album-assets').createSignedUrl(path,3600);if(signed.error||!signed.data?.signedUrl)return fail('print_asset_signing_failed');sourceUrls[source]=signed.data.signedUrl}
 return{snapshot:c.snapshot,spec:c.spec,sourceUrls,sourceFingerprint:await sourceFingerprint(order(c) as any)}
}
function report(value:unknown,c:Row,fp:string){const r=object(value);if(r.renderer!=='flutter-layer-builder-raster-v1'||r.sourceFingerprint!==fp||r.specVersion!==c.spec.specVersion||r.productId!=='REDP_300_HARD'||r.coverType!=='HARD'||r.pageCount!==80||r.dpi!==300||r.colorSpace!=='sRGB'||r.iccProfileEmbedded!==true||r.pdfStandard!=='PDF-1.4'||r.fit!=='contain'||!Array.isArray(r.missingAssets)||r.missingAssets.length||!Array.isArray(r.warnings)||Object.hasOwn(r,'declaredFiles')||Object.hasOwn(r,'fileTransport')||JSON.stringify(r).length>120_000)return fail('print_dev_preflight_failed');return r}
function declared(value:unknown,kind:string){const f=object(value),maximum=kind==='cover'?150_000_000:500_000_000;if(Object.keys(f).some(k=>!['bytes','sha256','parts'].includes(k))||!Number.isSafeInteger(f.bytes)||f.bytes<100||f.bytes>maximum||!hash(f.sha256))return fail('invalid_print_dev_file',400)
 if(f.bytes<=50_000_000){if(Object.hasOwn(f,'parts'))return fail('invalid_print_dev_file',400);return{bytes:f.bytes,sha256:f.sha256}}
 if(!Array.isArray(f.parts)||f.parts.length!==Math.ceil(f.bytes/PRINT_CHUNK_BYTES)||f.parts.some((v:unknown,index:number)=>{const p=object(v);return Object.keys(p).some(k=>!['bytes','sha256'].includes(k))||p.bytes!==Math.min(PRINT_CHUNK_BYTES,f.bytes-index*PRINT_CHUNK_BYTES)||!hash(p.sha256)}))return fail('invalid_print_dev_file',400)
 return{bytes:f.bytes,sha256:f.sha256,parts:f.parts}
}
function fileRecovery(ctx:ReturnType<typeof context>,fp:string){
 const p=ctx.p;if(!p||p.state!=='UPLOADING')return{}
 const {declaredFiles,...manifest}=p.renderer_manifest
 report(manifest,ctx.c,fp)
 for(const kind of['cover','interior'] as const){
  const parts=checkedChunkParts(p,kind,declared(declaredFiles?.[kind],kind))
  if(parts){if(parts.some(part=>canonical(p.part_results?.[kind]?.[String(part.index)])!==canonical({index:part.index,byteLength:part.byteLength,sha256:part.sha256})))return{}}
  else if(!p[`${kind}_result`])return{}
 }
 return{fileRecovery:{packageId:p.id,manifest}}
}
export function createPrintDevCheckoutHandler(deps:PrintDevCheckoutDependencies){let validating=false;return async(request:Request)=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});if(request.method!=='POST')return json({error:'method_not_allowed'},405)
 try{
 const input=await body(request),action=input.action
 if(!['capability','history','detail','prepare','snapshot','uploads','finalize','authorize','status'].includes(action)||Object.keys(input).some(k=>!['action','runId','requestId','orderId','paymentId','albumId','reviewedRevision','recipient','expectedAmount','packageId','kind','partIndex','manifest','cover','interior'].includes(k)))return fail('invalid_print_dev_request',400)
 const disabled={available:false,canTest:false,environment:'disabled',isTest:false,productionApproved:false}
 let actor:string
 try{actor=await assertRedprintingAdmin(request,deps.getUser)}catch(error){
  // A normal account may render the same checkout form. Only a fresh,
  // server-verified admin receives the TEST capability; it never grants LIVE.
  if(action==='capability'&&error instanceof RedprintingAdminAuthError&&error.code==='forbidden')return json(disabled)
  throw error
 }
 const config=deps.configuration(),now=(deps.now??Date.now)()
 if(action==='capability'){
  if(!Number.isSafeInteger(input.albumId)||input.albumId<1||!hash(input.reviewedRevision))return fail('invalid_print_dev_request',400)
  if(!config.enabled||config.paymentEnvironment!=='test'||config.storeId!==route.storeId||config.channelKey!==route.channelKey)return json(disabled)
  try{assertDevelopment(config.vendor,now)}catch{return json(disabled)}
  const current=await rpc(deps.createAdminDatabase(),'load_owned_print_checkout_context',{p_actor:actor,p_album_id:input.albumId}),q=object(current.quote)
  if(q.productCode!=='REDP_300_HARD'||q.pageCount!==80||q.sourcePageCount!==80||await printCheckoutRevision(current.snapshot)!==input.reviewedRevision)return json(disabled)
  return json({available:true,canTest:true,environment:'test',isTest:true,productionApproved:false,albumId:input.albumId,reviewedRevision:input.reviewedRevision,productId:'REDP_300_HARD',pageCount:80,totalAmount:159900,currency:'KRW',...route})
 }
 const db=deps.createAdminDatabase()
 if(!['status','history','detail'].includes(action)){if(!config.enabled||config.paymentEnvironment!=='test'||config.storeId!==route.storeId||config.channelKey!==route.channelKey)return fail('print_dev_disabled',503);assertDevelopment(config.vendor,now)}
 let ctx:ReturnType<typeof context>
 if(action==='history'){
  const result=await rpc(db,'list_owned_print_dev_checkouts',{p_actor:actor})
  if(!Array.isArray(result.items)||result.items.length>50)return fail('print_dev_record_invalid',503)
  return json({environment:'test',isTest:true,productionApproved:false,orders:result.items.map((value:Row)=>output(context(value,actor,{},now),undefined,false))})
 }
 if(action==='detail'){
  if(!uuid(input.runId))return fail('invalid_print_dev_request',400)
  return json(output(context(await rpc(db,'get_print_dev_checkout',{p_actor:actor,p_run_id:input.runId}),actor,{},now)))
 }
 if(action==='prepare'){
 if(!uuid(input.requestId)||!Number.isSafeInteger(input.albumId)||input.albumId<1||!hash(input.reviewedRevision)||(input.expectedAmount!==undefined&&input.expectedAmount!==159900))return fail('invalid_print_dev_request',400)
 const current=await rpc(db,'load_owned_print_checkout_context',{p_actor:actor,p_album_id:input.albumId}),q=object(current.quote)
 if(q.productCode!=='REDP_300_HARD'||q.pageCount!==80||q.sourcePageCount!==80)return fail('print_dev_hard80_required')
 if(await printCheckoutRevision(current.snapshot)!==input.reviewedRevision)return fail('print_album_changed')
 const spec=testPrintSpec('REDP_300_HARD',80),specRevision=await sha256(new TextEncoder().encode(JSON.stringify(canonicalPrintReview(spec))))
 const r=object(input.recipient),receiver=vendorTestRecipient({name:r.name,tel:r.phone,zipcode:r.zipCode,address:r.addressLine1,addressDetail:r.addressLine2,message:r.deliveryMemo})
 assertFulfillmentAssetSources(current.snapshot,config.supabaseUrl,current.allowedAssetOwners)
 ctx=context(await rpc(db,'prepare_print_dev_checkout',{p_actor:actor,p_request_id:input.requestId,p_album_id:input.albumId,p_reviewed_revision:input.reviewedRevision,p_reviewed_spec_revision:specRevision,p_source_digest:current.sourceDigest,p_spec:spec,p_recipient:receiver}),actor,{},now)
 return json({...output(ctx),...await snapshot(db,ctx.c,config.supabaseUrl)})
 }
 if(!uuid(input.runId)||!uuid(input.requestId)||!Number.isSafeInteger(input.albumId)||typeof input.orderId!=='string'||typeof input.paymentId!=='string')return fail('invalid_print_dev_request',400)
 ctx=context(await rpc(db,'get_print_dev_checkout',{p_actor:actor,p_run_id:input.runId}),actor,input,now,['uploads','finalize'].includes(action))
 if(action==='status')return json(output(ctx))
 if(action==='authorize'){
 ctx=context(await rpc(db,'authorize_print_dev_checkout',{p_actor:actor,p_run_id:input.runId}),actor,input,now)
 return json({...output(ctx),sdkRequest:ctx.s.status==='PREPARED'?{paymentId:ctx.c.payment_id,storeId:route.storeId,channelKey:route.channelKey,orderName:ctx.s.order_name,totalAmount:159900,currency:'KRW',environment:'test',status:'PREPARED'}:null})
 }
 const fp=await sourceFingerprint(order(ctx.c) as any),params={p_actor:actor,p_run_id:ctx.c.id}
 if(ctx.p&&(ctx.p.source_fingerprint!==fp||ctx.p.spec_version!==ctx.c.spec.specVersion))return fail('print_dev_package_conflict')
 if(action==='snapshot')return json({...output(ctx,fp),...await snapshot(db,ctx.c,config.supabaseUrl),...fileRecovery(ctx,fp)})
 if(action==='uploads'){
 const manifest={...report(input.manifest,ctx.c,fp),declaredFiles:{cover:declared(input.cover,'cover'),interior:declared(input.interior,'interior')}}
 ctx=context(await rpc(db,'print_dev_package',{...params,p_action:'uploads',p_manifest:manifest,p_result:{sourceFingerprint:fp,specVersion:ctx.c.spec.specVersion}}),actor,input,now,true)
 const pack=ctx.p!;if(canonical(pack.renderer_manifest)!==canonical(manifest))return fail('print_dev_package_conflict')
 const bucket=await db.storage.getBucket(PRINT_BUCKET);if(bucket.error||bucket.data?.public!==false)return fail('print_bucket_must_be_private',503)
 const targets:Row={};for(const kind of['cover','interior'] as const){const parts=checkedChunkParts(pack,kind,manifest.declaredFiles[kind]);if(parts){const signed=[];for(const part of parts){const result=await db.storage.from(PRINT_BUCKET).createSignedUploadUrl(part.path,{upsert:false});if(result.error||!result.data?.token||!result.data?.signedUrl)return fail('print_upload_signing_unavailable',503);signed.push({...part,...result.data})}targets[kind]={parts:signed}}
 else{const path=pack[`${kind}_path`],result=await db.storage.from(PRINT_BUCKET).createSignedUploadUrl(path,{upsert:false});if(result.error||!result.data?.token||!result.data?.signedUrl)return fail('print_upload_signing_unavailable',503);targets[kind]={path,...result.data}}}
 return json({...output(ctx,fp),...targets,bucket:PRINT_BUCKET,uploadId:pack.id,spec:ctx.c.spec})
 }
 const pack=ctx.p,kind=input.kind;if(!pack||input.packageId!==pack.id||!['cover','interior'].includes(kind))return fail('print_dev_package_conflict')
 const {declaredFiles,...storedReport}=pack.renderer_manifest,r=report(input.manifest,ctx.c,fp);if(canonical(r)!==canonical(storedReport))return fail('print_prepayment_manifest_conflict')
 const f=declared(declaredFiles[kind],kind),parts=checkedChunkParts(pack,kind,f),partProof=(index:number)=>parts&&canonical(pack.part_results?.[kind]?.[String(index)])===canonical({index,byteLength:parts[index].byteLength,sha256:parts[index].sha256})
 if(Object.hasOwn(input,'partIndex')){const index=input.partIndex;if(!Number.isSafeInteger(index)||!parts?.[index])return fail('invalid_print_dev_file',400)
 if(!partProof(index)){if(validating)return fail('print_validation_busy',429);validating=true;try{await downloadChunkPdfPart(db,parts[index],config.supabaseUrl,deps.fetcher)}finally{validating=false}
 ctx=context(await rpc(db,'print_dev_package',{...params,p_action:'verify_part',p_package_id:pack.id,p_kind:kind,p_result:{index,byteLength:parts[index].byteLength,sha256:parts[index].sha256},p_manifest:pack.renderer_manifest}),actor,input,now,true)}
 return json({...output(ctx,fp),partVerified:true,partIndex:index,kind})}
 if(!pack[`${kind}_result`]){
 if(parts?.some(p=>!partProof(p.index)))return fail('print_prepayment_parts_incomplete')
 if(validating)return fail('print_validation_busy',429);validating=true
 let result;try{const spec=ctx.c.spec,width=kind==='cover'?spec.cover.widthMm:spec.interior.trimWidthMm+10,height=kind==='cover'?spec.cover.heightMm:spec.interior.trimHeightMm+10,pages=kind==='cover'?1:80,trim=kind==='cover'?spec.cover.trim:undefined
 if(parts){const reader=createChunkedPdfReader(db,parts,config.supabaseUrl,deps.fetcher);try{result=await validateChunkedPrintPdf(reader,pages,width,height,trim)}finally{reader.clear()}}
 else result=await validatePrintPdf(await downloadPrepaymentPdf(db,pack[`${kind}_path`],f.bytes,config.supabaseUrl,deps.fetcher),pages,width,height,inspectAppRasterPdf,trim)
 }finally{validating=false}
 if(result.sha256!==f.sha256||result.byteLength!==f.bytes)return fail('print_upload_hash_mismatch')
 ctx=context(await rpc(db,'print_dev_package',{...params,p_action:'finalize',p_package_id:pack.id,p_kind:kind,p_result:result,p_manifest:pack.renderer_manifest}),actor,input,now,true)
 }
 if(ctx.p?.state==='FILES_VERIFIED'){
 const manifest=ctx.p.pdf_manifest;if(canonical(manifest.spec)!==canonical(ctx.c.spec)||manifest.productionApproved!==false||manifest.vendorReady!==false)return fail('print_dev_package_conflict')
 const published=await db.storage.from(PRINT_BUCKET).upload(ctx.p.manifest_path,JSON.stringify(manifest),{upsert:false,contentType:'application/json'})
 if(published.error){if(String(published.error.statusCode)!=='409'&&!/already exists|duplicate/i.test(published.error.message??''))return fail('print_manifest_publish_unavailable',503)
 const old=await db.storage.from(PRINT_BUCKET).download(ctx.p.manifest_path);if(old.error||!old.data||old.data.size>140_000||canonical(JSON.parse(await old.data.text()))!==canonical(manifest))return fail('print_manifest_conflict')}
 ctx=context(await rpc(db,'print_dev_package',{...params,p_action:'seal',p_package_id:pack.id}),actor,input,now,true)
 }
 return json(output(ctx,fp))
 }catch(error){if(error instanceof RedprintingAdminAuthError)return json({error:error.code},error.status);if(error instanceof OrderPaymentError)return json({error:error.message,retryable:[429,503].includes(error.status)},error.status)
 const code=(error as any)?.code;if(typeof code==='string'&&/^[a-z0-9_]{1,80}$/.test(code))return json({error:code},Number((error as any).status)||409)
 return json({error:'print_dev_operation_unavailable',retryable:true},503)}
}}

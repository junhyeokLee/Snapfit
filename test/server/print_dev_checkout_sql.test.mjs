import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {join} from 'node:path'
import {createHash} from 'node:crypto'
import {fixture,owner,other} from './fixtures/app_pdf_database.mjs'
import {createPrintDevCheckoutHandler} from '../../supabase/functions/_shared/print-dev-checkout.ts'
import {printCheckoutRevision} from '../../supabase/functions/_shared/production-print-checkout.ts'
import {RedprintingError} from '../../supabase/functions/_shared/redprinting.ts'
import {runPrintDevFulfillmentTick} from '../../supabase/functions/_shared/print-dev-fulfillment.ts'

const migration=name=>readFileSync(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8')
const directory=process.env.SNAPFIT_CHUNKED_FIXTURE_OUTPUT
const hash=bytes=>createHash('sha256').update(bytes).digest('hex')
const route={storeId:'store-33df409e-0ad9-4953-8194-70db7e32efae',channelKey:'channel-key-34782ac7-e644-4234-ad27-2767b6904f88'}
const recipient={name:'테스트',phone:'01000000000',zipCode:'12345',addressLine1:'개발 검증 주소',addressLine2:'가상 검수',deliveryMemo:''}
const vendorConfiguration={environment:'development',enabled:true,userId:'localdev',apiKey:'local-test-key-only',expiresAt:'2099-01-01'}
const configuration={enabled:true,paymentEnvironment:'test',...route,supabaseUrl:'https://fixture.supabase.co',vendor:vendorConfiguration}
async function setup(){
 const db=await fixture(false)
 await db.exec(migration('20261015021421_chunked_original_print_pdfs.sql'))
 await db.exec('drop table public.redprinting_dev_settings cascade')
 await db.exec(migration('20261008064729_redprinting_development_tests.sql'))
 await db.exec(migration('20261013154850_admin_portone_test_payment_sessions.sql'))
 await db.exec(migration('20261015030803_admin_owned_test_checkout_pipeline.sql'))
 await db.exec(migration('20261015055100_owned_development_order_history.sql'))
 const artwork=JSON.parse(readFileSync(join(directory,'fixture.json'),'utf8'))
 await db.query('update albums set title=$1,ratio=$2,cover_layers_json=$3 where id=1',[artwork.snapshot.album.title,'1',JSON.stringify(artwork.snapshot.album.cover_layers_json)])
 await db.exec("insert into redprinting_dev_codes(order_code,use_yn) values('C8E9D98C73536387071','Y');update redprinting_dev_mappings set order_code='C8E9D98C73536387071',exact_match_confirmed=true,vendor_use_yn='Y',vendor_order_yn='Y',verified_at=now() where product_id='REDP_300_HARD' and page_count=80;")
 const ctx=(await db.query('select load_owned_print_checkout_context($1,1) x',[owner])).rows[0].x
 const revision=await printCheckoutRevision(ctx.snapshot),files=new Map(),calls=[]
 const params={load_owned_print_checkout_context:['p_actor','p_album_id'],prepare_print_dev_checkout:['p_actor','p_request_id','p_album_id','p_reviewed_revision','p_reviewed_spec_revision','p_source_digest','p_spec','p_recipient'],get_print_dev_checkout:['p_actor','p_run_id'],print_dev_package:['p_actor','p_run_id','p_action','p_package_id','p_kind','p_result','p_manifest'],authorize_print_dev_checkout:['p_actor','p_run_id'],list_owned_print_dev_checkouts:['p_actor']}
 const adapter={
  async rpc(name,args){
   calls.push({name,args:structuredClone(args)})
   try{const keys=params[name]??Object.keys(args);return{data:(await db.query(`select ${name}(${keys.map((_,i)=>`$${i+1}`).join(',')}) x`,keys.map(key=>args[key]??null))).rows[0].x,error:null}}
   catch(error){return{data:null,error:{message:error.message,code:error.code}}}
  },
  storage:{
   async getBucket(){return{data:{public:false},error:null}},
   from(bucket){return{
    async createSignedUrl(path){return{data:{signedUrl:`https://fixture.supabase.co/storage/v1/object/sign/${bucket}/${path}?token=local-stub`},error:null}},
    async createSignedUploadUrl(path,options){assert.equal(options.upsert,false);return{data:{signedUrl:'https://fixture.invalid/upload',token:'local-upload'},error:null}},
    async upload(path,value,options){assert.equal(options.upsert,false);if(files.has(path))return{error:{statusCode:'409',message:'already exists'}};files.set(path,new TextEncoder().encode(value));return{error:null}},
    async download(path){return files.has(path)?{data:new Blob([files.get(path)]),error:null}:{data:null,error:{message:'missing'}}}
   }}
  }
 }
 const dependencies={getUser:async()=>({id:owner,app_metadata:{role:'admin'}}),createAdminDatabase:()=>adapter,configuration:()=>configuration,fetcher:async url=>{const path=new URL(url).pathname.split('/print-packages/')[1],bytes=files.get(path);return bytes?new Response(bytes,{headers:{'content-length':String(bytes.length)}}):new Response(null,{status:404})}}
 let handler=createPrintDevCheckoutHandler(dependencies)
 const call=async(input,selected=handler)=>{const response=await selected(new Request('https://fixture.invalid/dev',{method:'POST',headers:{authorization:'Bearer local-auth'},body:JSON.stringify(input)}));return{status:response.status,body:await response.json()}}
 return{db,revision,files,calls,adapter,dependencies,call,handler}
}
function receipt(payment){return{provider:'PORTONE',version:'V2',status:'PAID',paymentId:payment.paymentId,transactionId:'tx_local_test_only',storeId:route.storeId,channelKey:route.channelKey,amount:159900,paidAmount:159900,discountAmount:0,currency:'KRW',paidAt:'2026-10-15T01:00:00Z',environment:'test',isTest:true}}
async function ready(f){
 const prepared=await f.call({action:'prepare',requestId:'33333333-3333-4333-8333-333333333333',albumId:1,reviewedRevision:f.revision,recipient,expectedAmount:159900})
 assert.equal(prepared.status,200,JSON.stringify(prepared.body));const v=prepared.body,refs={runId:v.runId,requestId:v.requestId,albumId:v.albumId,orderId:v.orderId,paymentId:v.paymentId}
 assert.equal(v.spec.verified,false);assert.equal(v.environment,'test');assert.equal(v.sourceFingerprint.length,64)
 const cover=readFileSync(join(directory,'cover.pdf')),interior=readFileSync(join(directory,'interior.pdf'))
 const declaration=bytes=>({bytes:bytes.length,sha256:hash(bytes),...(bytes.length>50_000_000?{parts:Array.from({length:Math.ceil(bytes.length/16_000_000)},(_,index)=>{const part=bytes.subarray(index*16_000_000,Math.min(bytes.length,(index+1)*16_000_000));return{bytes:part.length,sha256:hash(part)}})}:{})})
 const manifest={renderer:'flutter-layer-builder-raster-v1',sourceFingerprint:v.sourceFingerprint,specVersion:v.spec.specVersion,productId:'REDP_300_HARD',coverType:'HARD',pageCount:80,dpi:300,colorSpace:'sRGB',iccProfileEmbedded:true,pdfStandard:'PDF-1.4',fit:'contain',missingAssets:[],warnings:[]}
 assert.equal((await f.call({...refs,action:'authorize'})).status,409)
 const uploaded=await f.call({...refs,action:'uploads',manifest,cover:declaration(cover),interior:declaration(interior)});assert.equal(uploaded.status,200,JSON.stringify(uploaded.body));const p=uploaded.body
 assert.equal((await f.call({...refs,action:'snapshot'})).body.fileRecovery,undefined)
 assert.equal((await f.call({...refs,action:'finalize',packageId:p.packageId,kind:'interior',manifest})).body.error,'print_prepayment_parts_incomplete')
 for(const[kind,bytes]of[['cover',cover],['interior',interior]]){
  if(p[kind].parts){for(const part of p[kind].parts){if(part.index===0){const wrong=Uint8Array.from(bytes.subarray(0,part.byteLength));wrong[0]^=1;f.files.set(part.path,wrong);assert.equal((await f.call({...refs,action:'finalize',packageId:p.packageId,kind,partIndex:part.index,manifest})).body.error,'print_upload_hash_mismatch')}
   if(part.index===p[kind].parts.length-1)assert.equal((await f.call({...refs,action:'snapshot'})).body.fileRecovery,undefined)
   f.files.set(part.path,bytes.subarray(part.index*16_000_000,part.index*16_000_000+part.byteLength));const checked=await f.call({...refs,action:'finalize',packageId:p.packageId,kind,partIndex:part.index,manifest});assert.equal(checked.status,200,JSON.stringify(checked.body));assert.equal(checked.body.partVerified,true)}}
  else f.files.set(p[kind].path,bytes)
  if(kind==='interior'){
   const recovered=await f.call({...refs,action:'snapshot'});assert.equal(recovered.status,200,JSON.stringify(recovered.body));assert.equal(recovered.body.packageState,'UPLOADING')
   assert.deepEqual(recovered.body.fileRecovery,{packageId:p.packageId,manifest})
   assert.deepEqual(Object.keys(recovered.body.fileRecovery).sort(),['manifest','packageId'])
   assert.equal(Object.hasOwn(recovered.body.fileRecovery.manifest,'declaredFiles'),false)
   assert.equal(Object.hasOwn(recovered.body.fileRecovery.manifest,'fileTransport'),false)
   const foreign=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:other,app_metadata:{role:'admin'}})})
   assert.equal((await f.call({...refs,action:'snapshot'},foreign)).status,404)
  }
  const checked=await f.call({...refs,action:'finalize',packageId:p.packageId,kind,manifest});assert.equal(checked.status,200,JSON.stringify(checked.body))
 }
 assert.equal((await f.call({...refs,action:'status'})).body.packageState,'READY')
 assert.equal((await f.call({...refs,action:'snapshot'})).body.fileRecovery,undefined)
 return{refs,manifest,p,interior,cover}
}

test('actual dense80 TEST owner API and SQL keep production closed; only Cron verifies TEST and enqueues one DEV submission',{skip:!directory},async t=>{
 const f=await setup();t.after(()=>f.db.close());const{refs,p,interior}=await ready(f)
 const authorized=await f.call({...refs,action:'authorize'});assert.equal(authorized.status,200,JSON.stringify(authorized.body));assert.equal(authorized.body.sdkRequest.environment,'test');assert.equal(authorized.body.sdkRequest.status,'PREPARED');assert.ok(authorized.body.sdkIssuedAt)
 await f.call({...refs,action:'authorize'});assert.equal((await f.db.query('select count(*)::integer n from private.print_dev_fulfillment_outbox')).rows[0].n,1)
 let PGcalls=0,POSTcalls=0,closed=false,statusFails=true
 const workerConfig={...configuration,paymentApiSecret:'local-test-secret-only',deliverySecret:'a'.repeat(64)}
 const deps={paymentLookup:async expected=>{assert.equal(closed,true);PGcalls++;return receipt(expected)},vendor:{call:async(path)=>{if(path==='/v1/code/detail')return{success:true,data:{order_code:'C8E9D98C73536387071',use_yn:'Y'}};if(path==='/v1/code/price')return{success:true,orderYn:'Y',priceInfo:{supplyPrice:92600,vatPrice:9260,totalPrice:101860,qty:1}};if(path==='/v1/code/order'){POSTcalls++;return{success:true}};throw Error(path)},status:async()=>{if(statusFails)throw new RedprintingError('vendor_http_404',404);return{statusCode:'PGS_07',statusCodeOrg:'PGS_07',statusName:'분석',fileProcessYn:'Y',fileError:false,fileErrorDetailPresent:false}}},sender:async()=>({senderName:'스냅핏',senderTel:'01000000000',senderZipcode:'12345',senderAddress:'개발주소',senderAddressDetail:'검수',colorMode:'RGB',developmentRgbTestAcknowledged:true,developmentGeometryTestAcknowledged:true})}
 const before=f.calls.length;const status=await f.call({...refs,action:'status'});assert.equal(status.body.status,'PREPARED');assert.equal(f.calls.length,before+1);assert.equal(PGcalls,0)
 closed=true
 const payment=await runPrintDevFulfillmentTick(f.adapter,workerConfig,deps);assert.equal(payment.errors,0);assert.equal(payment.advanced,1);assert.equal(PGcalls,1);assert.equal(POSTcalls,0)
 const after=(await f.db.query('select get_print_dev_checkout($1,$2) x',[owner,refs.runId])).rows[0].x;assert.equal(after.session.status,'VERIFIED_TEST');assert.equal(after.checkout.status,'PAYMENT_VERIFIED')
 const file=(await f.db.query('select read_print_dev_file_delivery($1,$2,$3) x',[refs.orderId,p.packageId,'interior'])).rows[0].x;assert.equal(file.result.sha256,hash(interior));assert.equal(file.parts.length,7)
 const lease=(await f.db.query('select claim_print_dev_fulfillment_job($1,1,120) x',[owner])).rows[0].x
 await assert.rejects(f.db.query('select get_print_dev_fulfillment_job($1,$2)',[lease.job.id,other]),/lease_lost/)
 assert.equal((await runPrintDevFulfillmentTick(f.adapter,workerConfig,deps)).checked,0)
 await f.db.query('select fail_print_dev_fulfillment_job($1,$2,$3,now(),false)',[lease.job.id,owner,'test_transient'])
 const submit=await runPrintDevFulfillmentTick(f.adapter,workerConfig,deps);assert.equal(submit.errors,1);assert.equal(POSTcalls,1)
 const uncertain=(await f.db.query('select payload,state from private.print_dev_fulfillment_outbox')).rows[0];assert.equal(uncertain.state,'UNKNOWN');assert.equal(uncertain.payload.queryOnly,true)
 // Advance this isolated fixture's scheduled time; the real Cron waits until due.
 await f.db.exec('update private.print_dev_fulfillment_outbox set available_at=now()');statusFails=false
 const recovered=await runPrintDevFulfillmentTick(f.adapter,workerConfig,deps);assert.equal(recovered.errors,0);assert.equal(recovered.advanced,1);assert.equal(POSTcalls,1)
 const done=(await f.call({...refs,action:'status'})).body;assert.equal(done.stage,'FILE_CHECKED');assert.equal(done.receipt.isTest,true);assert.equal(done.receipt.environment,'test')
 const history=(await f.call({action:'history'})).body;assert.equal(history.orders.length,1);assert.equal(history.orders[0].runId,refs.runId);assert.equal(history.orders[0].stage,'FILE_CHECKED');assert.equal(history.orders[0].packageState,'READY');assert.equal(history.orders[0].receipt.isTest,true);assert.equal(history.orders[0].recipient,undefined)
 const detail=(await f.call({action:'detail',runId:refs.runId})).body;assert.deepEqual(detail.recipient,recipient);assert.equal(detail.orderId,done.orderId);assert.ok(detail.createdAt)
 assert.equal(POSTcalls,1);assert.equal(PGcalls,2) // status/history/detail never drive payment or fulfillment

 assert.equal((await f.db.query('select enabled from private.print_sales_configuration')).rows[0].enabled,false)
 assert.equal((await f.db.query('select count(*)::integer n from public.orders')).rows[0].n,0);assert.equal((await f.db.query('select count(*)::integer n from private.print_checkout_intents')).rows[0].n,0)
})

test('TEST endpoint refuses nonadmin/foreign refs/LIVE routes and real SQL rejects LIVE receipts, partial proofs and changed frozen data',{skip:!directory},async t=>{
 const f=await setup();t.after(()=>f.db.close())
 const basic={action:'prepare',requestId:'33333333-3333-4333-8333-333333333333',albumId:1,reviewedRevision:f.revision,recipient}
 const noAdmin=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:owner,app_metadata:{role:'member'}})})
 assert.equal((await f.call(basic,noAdmin)).status,403)
 const live=createPrintDevCheckoutHandler({...f.dependencies,configuration:()=>({...configuration,paymentEnvironment:'live'})});assert.equal((await f.call(basic,live)).status,503)
 const{refs}=await ready(f)
 const foreign=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:other,app_metadata:{role:'admin'}})});assert.equal((await f.call({...refs,action:'status'},foreign)).status,404)
 await assert.rejects(f.db.query("update private.print_dev_checkouts set snapshot='{}' where id=$1",[refs.runId]),/immutable/)
 await f.call({...refs,action:'authorize'});const claim=(await f.db.query('select claim_print_dev_fulfillment_job($1,1,120) x',[owner])).rows[0].x
 await assert.rejects(f.db.query('select commit_print_dev_payment($1,$2,$3)',[claim.job.id,owner,{...receipt(claim.paymentExpectation),environment:'live',isTest:false}]),/receipt_invalid/)
 await assert.rejects(f.db.query("update private.print_dev_fulfillment_outbox set payload=jsonb_set(payload,'{vendorOrderNum}','\"OTHER\"') where id=$1",[claim.job.id]),/outbox_immutable/)
 for(const role of['anon','authenticated']){await f.db.exec('set role '+role);await assert.rejects(f.db.query('select get_print_dev_checkout($1,$2)',[owner,refs.runId]),/permission denied/);await f.db.exec('reset role')}
})


test('normal checkout gets an owner/album-specific TEST capability only for fresh verified admins and exact TEST routes',{skip:!directory},async t=>{
 const f=await setup();t.after(()=>f.db.close())
 const input={action:'capability',albumId:1,reviewedRevision:f.revision}
 const good=await f.call(input);assert.equal(good.status,200)
 assert.deepEqual(good.body,{available:true,canTest:true,environment:'test',isTest:true,productionApproved:false,albumId:1,reviewedRevision:f.revision,productId:'REDP_300_HARD',pageCount:80,totalAmount:159900,currency:'KRW',...route})
 for(const user of[{id:owner,app_metadata:{role:'member'}},{id:owner,user_metadata:{role:'admin'}}]){
  const h=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>user})
  const count=f.calls.length;const result=await f.call(input,h);assert.equal(result.status,200);assert.equal(result.body.canTest,false);assert.equal(result.body.environment,'disabled');assert.equal(f.calls.length,count)
 }
 const invalid=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>null});assert.equal((await f.call(input,invalid)).status,401)
 for(const patch of[{enabled:false},{paymentEnvironment:'live'},{storeId:'other'},{channelKey:'other'},{vendor:{...vendorConfiguration,environment:'production'}},{vendor:{...vendorConfiguration,expiresAt:'2020-01-01'}}]){
  const h=createPrintDevCheckoutHandler({...f.dependencies,configuration:()=>({...configuration,...patch})}),count=f.calls.length
  const result=await f.call(input,h);assert.equal(result.status,200);assert.equal(result.body.canTest,false);assert.equal(f.calls.length,count)
 }
 assert.equal((await f.call({...input,reviewedRevision:'f'.repeat(64)})).body.canTest,false)
 const foreign=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:other,app_metadata:{role:'admin'}})})
 assert.equal((await f.call(input,foreign)).status,403)
 assert.equal((await f.db.query('select count(*)::integer n from private.print_dev_checkouts')).rows[0].n,0)
 assert.equal((await f.db.query('select count(*)::integer n from private.print_dev_fulfillment_outbox')).rows[0].n,0)
})

test('TEST history/detail are owner-scoped read-only, omit artwork and list recipients, and cannot open LIVE orders',{skip:!directory},async t=>{
 const f=await setup();t.after(()=>f.db.close())
 const first=await f.call({action:'prepare',requestId:'33333333-3333-4333-8333-333333333333',albumId:1,reviewedRevision:f.revision,recipient})
 assert.equal(first.status,200,JSON.stringify(first.body));assert.deepEqual(first.body.recipient,recipient)
 const second=await f.call({action:'prepare',requestId:'55555555-5555-4555-8555-555555555555',albumId:1,reviewedRevision:f.revision,recipient})
 assert.equal(second.status,200);assert.notEqual(first.body.runId,second.body.runId)
 const readonlyCalls=f.calls.length
 const history=await f.call({action:'history'});assert.equal(history.status,200,JSON.stringify(history.body));assert.equal(history.body.environment,'test');assert.equal(history.body.productionApproved,false);assert.equal(history.body.orders.length,2)
 for(const row of history.body.orders){assert.ok(row.createdAt);assert.equal(row.albumTitle,first.body.albumTitle);assert.equal(row.recipient,undefined);assert.equal(row.snapshot,undefined);assert.equal(row.sourceUrls,undefined);assert.equal(row.sdkRequest,undefined);assert.equal(row.environment,'test')}
 assert.ok(!JSON.stringify(history.body).includes(recipient.addressLine1));assert.ok(!JSON.stringify(history.body).includes('/storage/v1/'))
 const detail=await f.call({action:'detail',runId:first.body.runId});assert.equal(detail.status,200);assert.deepEqual(detail.body.recipient,recipient);assert.equal(detail.body.snapshot,undefined);assert.equal(detail.body.sdkRequest,undefined)
 assert.deepEqual(f.calls.slice(readonlyCalls).map(c=>c.name),['list_owned_print_dev_checkouts','get_print_dev_checkout'])
 const foreign=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:other,app_metadata:{role:'admin'}})})
 assert.equal((await f.call({action:'history'},foreign)).body.orders.length,0)
 assert.equal((await f.call({action:'detail',runId:first.body.runId},foreign)).status,404)
 const noAdmin=createPrintDevCheckoutHandler({...f.dependencies,getUser:async()=>({id:owner,app_metadata:{role:'member'}})})
 assert.equal((await f.call({action:'history'},noAdmin)).status,403);assert.equal((await f.call({action:'detail',runId:first.body.runId},noAdmin)).status,403)
 const disabled=createPrintDevCheckoutHandler({...f.dependencies,configuration:()=>({...configuration,enabled:false,paymentEnvironment:'live'})})
 assert.equal((await f.call({action:'history'},disabled)).body.orders.length,2);assert.equal((await f.call({action:'detail',runId:first.body.runId},disabled)).status,200)
 for(const role of['anon','authenticated']){await f.db.exec('set role '+role);await assert.rejects(f.db.query('select list_owned_print_dev_checkouts($1)',[owner]),/permission denied/);await f.db.exec('reset role')}
 assert.equal((await f.db.query('select count(*)::integer n from private.print_dev_fulfillment_outbox')).rows[0].n,0)
 assert.equal((await f.db.query('select count(*)::integer n from public.orders')).rows[0].n,0)
 assert.equal((await f.db.query('select count(*)::integer n from private.print_checkout_intents')).rows[0].n,0)
 assert.equal((await f.db.query('select enabled from private.print_sales_configuration')).rows[0].enabled,false)
})

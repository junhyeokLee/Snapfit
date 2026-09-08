import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync,existsSync} from 'node:fs'
import {pathToFileURL} from 'node:url'
import {getPrintSpec,sourceInteriorPageCount,sourceFingerprint,calculateContribution,assertPrintOrder,PRINT_PRODUCTS,resolveAlbumPrintProduct,orderPrintProduct,sha256,validateHardCoverGeometry} from '../../supabase/functions/_shared/print-contract.ts'
import {buildPrintPackage,validatePrintPdf,createPdfInspector,finalizePrintPackage,resolvePrintAssetPath,createPrintUploads} from '../../supabase/functions/_shared/print-package.ts'
import {advanceVerifiedOrder} from '../../supabase/functions/_shared/order-fulfillment.ts'
const pdfLib=(await import(process.env.PDF_LIB_MODULE ? pathToFileURL(process.env.PDF_LIB_MODULE).href : 'pdf-lib')).default
const inspect=createPdfInspector(pdfLib)
const order=()=>({order_id:'fixture-order',status:'PAYMENT_COMPLETED',verified_payment_id:'historical',verified_payment_provider:'HISTORICAL',payment_confirmed_at:'2026-09-08T00:00:00Z',
  pricing_version:'PRINT_REDP_200_SOFT_V1',amount:49900,page_count:20,print_fulfillment_status:'AWAITING_RENDER',
  print_content_snapshot:{album:{cover_layers_json:JSON.stringify({pages:[{index:0,isCover:true,layers:[]},{index:1,isCover:false,layers:[]}]})},pages:[]},
  print_cost_snapshot:{paymentFeeRate:.04,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000}})
const profileSource=readFileSync(new URL('../../lib/features/album/printing/srgb_profile.dart',import.meta.url),'utf8')
const profile=Buffer.from([...profileSource.matchAll(/'([A-Za-z0-9+/=]{30,})'/g)].map(m=>m[1]).join(''),'base64')
async function pdf(pages,widthMm,heightMm,{active=false,icc=true,wrongProfile=false,lowResolution=false,noTrim=false,rotation=0,trim={xMm:5,yMm:5,widthMm:widthMm-10,heightMm:heightMm-10}}={}) {
  const {PDFDocument,PDFName}=pdfLib,doc=await PDFDocument.create(),context=doc.context
  const bytes=Buffer.from(profile);if(wrongProfile)bytes[100]=1
  const profileRef=context.register(context.stream(bytes,{N:3,Alternate:'DeviceRGB'}))
  const image=context.register(context.flateStream(new Uint8Array([255,250,245]),{Type:'XObject',Subtype:'Image',Width:lowResolution?1:Math.ceil(widthMm*300/25.4),Height:lowResolution?1:Math.ceil(heightMm*300/25.4),BitsPerComponent:8,ColorSpace:icc?['ICCBased',profileRef]:'DeviceRGB'}))
  for(let i=0;i<pages;i++){
    const p=doc.addPage([widthMm*72/25.4,heightMm*72/25.4]);if(!noTrim)p.setTrimBox(trim.xMm*72/25.4,(heightMm-trim.yMm-trim.heightMm)*72/25.4,trim.widthMm*72/25.4,trim.heightMm*72/25.4);p.setRotation(pdfLib.degrees(rotation));p.node.set(PDFName.of('Resources'),context.obj({XObject:{Im:image}}))
    p.node.set(PDFName.of('Contents'),context.register(context.flateStream(new TextEncoder().encode('q 1 0 0 1 0 0 cm /Im Do Q'))))
  }
  if(active)doc.catalog.set(PDFName.of('OpenAction'),context.obj({S:'JavaScript',JS:'alert(1)'}))
  return doc.save({useObjectStreams:false})
}

test('canonical full document takes precedence over stale legacy pages; quote geometry matches official guide',()=>{
  assert.equal(sourceInteriorPageCount(order().print_content_snapshot),1)
  assert.equal(sourceInteriorPageCount({...order().print_content_snapshot,pages:Array(99).fill({})}),1)
  assert.equal(getPrintSpec(order()).cover.widthMm,417.22)
  assert.equal(getPrintSpec({...order(),page_count:80}).cover.front.xMm,232.32)
  assert.throws(()=>assertPrintOrder({...order(),page_count:21}),/invalid_print_page_count/)
  assert.throws(()=>assertPrintOrder({...order(),verified_payment_provider:null}),/verified_payment_required/)
})
test('retail covers conservative repacking costs with a real margin floor, including fee, reprint and operations reserves',()=>{
  const result=calculateContribution(order(),{actualPrintCost:22600,actualShippingCost:7000,actualPackagingCost:1500})
  assert.equal(result.contribution_margin,11309)
  assert.equal(result.payment_fee_reserve,1996);assert.equal(result.reprint_reserve,2495);assert.equal(result.operations_reserve,3000)
  assert.throws(()=>calculateContribution(order(),{actualPrintCost:40000,actualShippingCost:7000,actualPackagingCost:1500}),/print_margin_below_minimum/)
  assert.equal(calculateContribution(order(),{actualPrintCost:40000,actualShippingCost:7000,actualPackagingCost:1500},false).contribution_margin,-6091)
  assert.throws(()=>calculateContribution(order(),{actualPrintCost:'22600',actualShippingCost:7000,actualPackagingCost:1500}),/actual_vendor_costs_required/)
})
test('queueing never manufactures a fake PDF or printer order, nor changes the payment status',async()=>{
  assert.deepEqual(await buildPrintPackage({},order()),{patch:{print_fulfillment_status:'AWAITING_RENDER'}})
  await assert.rejects(advanceVerifiedOrder({},order(),'acceptPrintVendor',{}),/vendor_submission_required/)
  await assert.rejects(advanceVerifiedOrder({}, {...order(), print_fulfillment_status:'READY',print_spec_confirmed_at:'now'},'submitPrintVendor',{
    vendorOrderId:'RED-1234',fulfillmentMethod:'DIRECT',actualPrintCost:22600,actualShippingCost:3500,actualPackagingCost:0,
    senderLabelConfirmed:true,priceSlipOmittedConfirmed:true,promotionalMaterialsOmittedConfirmed:false}),/direct_shipping_confirmation_required/)
})
test('PDF parser checks page count, physical dimensions, sRGB profile, and active content',async()=>{
  const bytes=await pdf(20,210,210)
  assert.equal((await validatePrintPdf(bytes,20,210,210,inspect)).pageCount,20)
  await assert.rejects(validatePrintPdf(bytes,21,210,210,inspect),/page_count_mismatch/)
  await assert.rejects(validatePrintPdf(bytes,20,206,206,inspect),/dimensions_mismatch/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{active:true}),1,210,210,inspect),/active_print_pdf/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{icc:false}),1,210,210,inspect),/icc_profile_required/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{wrongProfile:true}),1,210,210,inspect),/srgb_profile_mismatch/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{lowResolution:true}),1,210,210,inspect),/raster_resolution_too_low/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{noTrim:true}),1,210,210,inspect),/trim_box_mismatch/)
  await assert.rejects(validatePrintPdf(await pdf(1,210,210,{rotation:90}),1,210,210,inspect),/rotation_not_allowed/)
  await assert.rejects(validatePrintPdf(new Uint8Array(100),1,210,210,inspect),/invalid_print_pdf/)
})

test('publishing validates immutable source and paths, preserves paid status, and retries after a manifest-only partial failure',async()=>{
  const row={...order(),print_fulfillment_status:'RENDERING',print_upload_id:'upload-1'}
  const fingerprint=await sourceFingerprint(row);row.print_upload_fingerprint=fingerprint
  const files=new Map([
    ['fixture-order/upload-1/cover.pdf',new Blob([await pdf(1,417.22,210)])],
    ['fixture-order/upload-1/interior.pdf',new Blob([await pdf(20,210,210)])],
  ])
  const body={uploadId:'upload-1',manifest:{sourceFingerprint:fingerprint,specVersion:getPrintSpec(row).specVersion,pageCount:20,missingAssets:[],warnings:[],iccProfileEmbedded:true,colorSpace:'sRGB',dpi:300}}
  let failPublish=true,uploads=0
  const db={storage:{from(bucket){assert.equal(bucket,'print-packages');return {
    download:async path=>({data:files.get(path),error:null}),
    upload:async(path,contents)=>{if(files.has(path))return{error:{message:'already exists',statusCode:'409'}};files.set(path,new Blob([contents]));uploads++;return{error:null}},
  }}},from(table){assert.equal(table,'orders');let patch;const q={update(p){patch=p;return q},eq(){return q},is(){return q},select(){return q},async maybeSingle(){if(failPublish){failPublish=false;return{error:new Error('temporary DB failure')}};Object.assign(row,patch);return{data:{...row},error:null}}};return q}}
  await assert.rejects(finalizePrintPackage(db,row,{...body,manifest:{...body.manifest,missingAssets:['missing.jpg']}},inspect),/preflight_failed/)
  await assert.rejects(finalizePrintPackage(db,row,{...body,manifest:{...body.manifest,sourceFingerprint:'other'}},inspect),/preflight_failed/)
  await assert.rejects(finalizePrintPackage(db,row,body,inspect),/temporary DB failure/)
  const result=await finalizePrintPackage(db,row,body,inspect)
  assert.equal(result.status,'PAYMENT_COMPLETED');assert.equal(result.print_fulfillment_status,'REVIEW_REQUIRED');assert.equal(uploads,1)
  assert.equal(result.print_vendor_order_id,undefined)
  assert.equal((await finalizePrintPackage(db,row,body,inspect)).print_fulfillment_status,'REVIEW_REQUIRED')
  await assert.rejects(finalizePrintPackage(db,{...row,payment_reversed_at:'now'},body,inspect),/payment_reversed/)
})

test('actual Flutter-produced proof PDFs pass the same server inspector when available',async t=>{
  const base=new URL('../../output/pdf/print-export-proof/',import.meta.url)
  if(!existsSync(new URL('cover.pdf',base))){t.skip('Run Flutter print_export_test to generate visual proof');return}
  await validatePrintPdf(readFileSync(new URL('cover.pdf',base)),1,417.22,210,inspect)
  await validatePrintPdf(readFileSync(new URL('interior.pdf',base)),20,210,210,inspect)
})


test('private asset signing is limited to snapshot album owners/contributors and the album-assets bucket',()=>{
  const owners=new Set(['owner','editor']),host='https://project.supabase.co'
  assert.equal(resolvePrintAssetPath('supabase://album-assets/owner/albums/images/a.jpg',host,owners),'owner/albums/images/a.jpg')
  assert.equal(resolvePrintAssetPath(host+'/storage/v1/object/sign/album-assets/editor/albums/images/a.jpg?token=expired',host,owners),'editor/albums/images/a.jpg')
  assert.equal(resolvePrintAssetPath('https://outside.example/storage/v1/object/public/album-assets/owner/a.jpg',host,owners),null)
  assert.throws(()=>resolvePrintAssetPath('supabase://print-packages/owner/private.pdf',host,owners),/asset_access_requires_review/)
  assert.throws(()=>resolvePrintAssetPath('supabase://album-assets/stranger/albums/images/private.jpg',host,owners),/asset_access_requires_review/)
  assert.throws(()=>resolvePrintAssetPath('supabase://album-assets/owner/albums/%252e%252e/secret.jpg',host,owners),/asset_access_requires_review/)
})


function multiOrder(product) {
  const canonical={id:product.id,trimWidthMm:product.trimWidthMm,trimHeightMm:product.trimHeightMm}
  return {...order(),pricing_version:'PRINT_REDP_MULTISIZE_V2',print_product_snapshot:canonical,
    print_content_snapshot:{album:{ratio:String(product.trimWidthMm/product.trimHeightMm),cover_layers_json:JSON.stringify({pages:[{index:0,isCover:true,layers:[]},{index:1,isCover:false,layers:[]}],printProduct:canonical})},pages:[],printProduct:canonical}}
}
test('all five V2 products drive true physical PDF dimensions, and every product is fingerprint-bound',async()=>{
  const fingerprints=new Set()
  for(const product of Object.values(PRINT_PRODUCTS).filter(p=>p.id.endsWith('_SOFT'))){
    const row=multiOrder(product),spec=getPrintSpec(row)
    assertPrintOrder(row)
    assert.equal(spec.id,product.id);assert.equal(spec.interior.trimWidthMm,product.trimWidthMm);assert.equal(spec.interior.trimHeightMm,product.trimHeightMm)
    assert.equal(spec.cover.widthMm,product.trimWidthMm*2+17.22)
    assert.equal(spec.cover.heightMm,product.trimHeightMm+10)
    assert.equal(spec.specVersion,`${product.id}_REVIEW_V2_7.22`)
    fingerprints.add(await sourceFingerprint(row))
    await validatePrintPdf(await pdf(1,spec.cover.widthMm,spec.cover.heightMm),1,spec.cover.widthMm,spec.cover.heightMm,inspect)
    await validatePrintPdf(await pdf(20,product.trimWidthMm+10,product.trimHeightMm+10),20,product.trimWidthMm+10,product.trimHeightMm+10,inspect)
  }
  assert.equal(fingerprints.size,5)
})
test('explicit metadata is validated and unsupported legacy portrait books are never silently resized',()=>{
  assert.equal(resolveAlbumPrintProduct({ratio:'1:1',cover_layers_json:'{}'}).id,'REDP_200_SOFT')
  assert.equal(resolveAlbumPrintProduct({ratio:'4:3',cover_layers_json:'{}'}).id,'REDP_200X150_SOFT')
  assert.throws(()=>resolveAlbumPrintProduct({ratio:'0.75',cover_layers_json:'{}'}),/unsupported_print_product/)
  assert.throws(()=>resolveAlbumPrintProduct({ratio:'',cover_layers_json:'{}'}),/unsupported_print_product/)
  const album=multiOrder(PRINT_PRODUCTS.REDP_250X200_SOFT).print_content_snapshot.album
  assert.throws(()=>resolveAlbumPrintProduct({...album,ratio:'1'}),/print_product_ratio_mismatch/)
  for(const product of [{id:'__proto__'},{id:'REDP_300_SOFT',trimWidthMm:200,trimHeightMm:200},{id:'REDP_200_SOFT',trimWidthMm:'200',trimHeightMm:200}]){
    assert.throws(()=>resolveAlbumPrintProduct({ratio:'1',cover_layers_json:JSON.stringify({printProduct:product})}),/invalid_print_product/)
  }
  const mismatch=multiOrder(PRINT_PRODUCTS.REDP_250_SOFT)
  mismatch.print_product_snapshot={id:'REDP_300_SOFT',trimWidthMm:300,trimHeightMm:300}
  assert.throws(()=>orderPrintProduct(mismatch),/print_product_snapshot_mismatch/)
})
test('existing V1 square profile and fingerprint remain byte-for-byte compatible despite new product metadata',async()=>{
  const old=order()
  const expected=await sha256(new TextEncoder().encode(JSON.stringify({orderId:old.order_id,snapshot:old.print_content_snapshot,pageCount:old.page_count,pricingVersion:old.pricing_version})))
  assert.equal(await sourceFingerprint(old),expected)
  const withNewColumn={...old,print_product_snapshot:{id:'REDP_300_SOFT',trimWidthMm:300,trimHeightMm:300}}
  assert.equal(await sourceFingerprint(withNewColumn),expected)
  assert.equal(getPrintSpec(withNewColumn).specVersion,'REDP_200_SOFT_REVIEW_V1_7.22')
  assert.equal(getPrintSpec(withNewColumn).interior.trimWidthMm,200)
  assert.equal(getPrintSpec({...old,print_content_snapshot:{album:{ratio:'0.75',cover_layers_json:'{}'},pages:[]}}).interior.trimHeightMm,200)
})

const exactHardGeometry={construction:'casewrap',bleedMm:20,widthMm:461.1,heightMm:196,
  back:{xMm:20,yMm:20,widthMm:206,heightMm:156},front:{xMm:235.1,yMm:20,widthMm:206,heightMm:156},
  trim:{xMm:20,yMm:20,widthMm:421.1,heightMm:156}}
const v3Order=product=>({...multiOrder(product),pricing_version:'PRINT_REDP_COVERTYPE_V3'})
test('ten V3 product identities are frozen separately, while V2 never accepts hardcover',async()=>{
  const hashes=new Set()
  for(const product of Object.values(PRINT_PRODUCTS)){
    const row=v3Order(product)
    assertPrintOrder(row);assert.equal(orderPrintProduct(row).id,product.id)
    hashes.add(await sourceFingerprint(row))
    if(product.id.endsWith('_HARD'))assert.throws(()=>orderPrintProduct(multiOrder(product)),/print_product_version_mismatch/)
    else {
      assert.equal(getPrintSpec(row).coverType,'SOFT');assert.equal(getPrintSpec(row).coverLabel,'소프트커버')
      assert.equal(getPrintSpec(row).specVersion,`${product.id}_REVIEW_V3_7.22`)
      const old=multiOrder(product),canonical=old.print_product_snapshot
      const expected=await sha256(new TextEncoder().encode(JSON.stringify({orderId:old.order_id,snapshot:old.print_content_snapshot,pageCount:old.page_count,pricingVersion:old.pricing_version,printProduct:canonical})))
      assert.equal(await sourceFingerprint(old),expected)
      assert.equal(getPrintSpec(old).coverType,undefined)
    }
  }
  assert.equal(hashes.size,10)
})
test('hardcover requires an explicit casewrap template before upload; exact geometry keeps the physical board and TrimBox',async()=>{
  const row=v3Order(PRINT_PRODUCTS.REDP_200X150_HARD)
  assert.equal(getPrintSpec(row).coverGeometrySource,'official_default')
  assert.deepEqual(getPrintSpec(row).cover,exactHardGeometry)
  const missing={...row,print_spec_override:{spineMm:9.1}}
  assert.throws(()=>getPrintSpec(missing),/hardcover_template_required/)
  await assert.rejects(createPrintUploads({},missing),/hardcover_template_required/)
  for(const bad of [{...exactHardGeometry,construction:'softcover'},{...exactHardGeometry,trim:undefined},{...exactHardGeometry,front:{...exactHardGeometry.front,xMm:999}},{...exactHardGeometry,bleedMm:undefined}]){
    assert.throws(()=>validateHardCoverGeometry(bad),/hardcover/)
  }
  const configured={...row,print_spec_override:{coverGeometry:exactHardGeometry,templateRevision:'official20p'}}
  const spec=getPrintSpec(configured)
  assert.equal(spec.coverType,'HARD');assert.equal(spec.coverLabel,'하드커버');assert.equal(spec.specVersion,'REDP_200X150_HARD_REVIEW_V3_official20p')
  assert.equal(spec.interior.trimWidthMm,200);assert.equal(spec.cover.front.widthMm,206);assert.equal(spec.cover.bleedMm,20)
  const bytes=await pdf(1,461.1,196,{trim:exactHardGeometry.trim})
  await validatePrintPdf(bytes,1,461.1,196,inspect,exactHardGeometry.trim)
  await assert.rejects(validatePrintPdf(bytes,1,461.1,196,inspect),/trim_box_mismatch/)
  await assert.rejects(validatePrintPdf(await pdf(1,461.1,196),1,461.1,196,inspect,exactHardGeometry.trim),/trim_box_mismatch/)
  const asymmetric={xMm:20,yMm:18,widthMm:421.1,heightMm:156}
  await validatePrintPdf(await pdf(1,461.1,196,{trim:asymmetric}),1,461.1,196,inspect,asymmetric)
})

test('hardcover review profile agrees with the seven measured official guides and distinguishes inferred combinations',()=>{
  for(const [id,pageCount,widthMm,heightMm,spine]of [
    ['REDP_200X150_HARD',20,461.1,196,9.1],
    ['REDP_200_HARD',20,461.1,246,9.1],
    ['REDP_250X200_HARD',20,561.1,246,9.1],
    ['REDP_250_HARD',20,561.1,296,9.1],
    ['REDP_300_HARD',20,661.1,346,9.1],
    ['REDP_200X150_HARD',22,461.77,196,9.77],
    ['REDP_300_HARD',80,681.2,346,29.2],
  ]){
    const spec=getPrintSpec({...v3Order(PRINT_PRODUCTS[id]),page_count:pageCount})
    assert.equal(spec.cover.widthMm,widthMm);assert.equal(spec.cover.heightMm,heightMm);assert.equal(spec.spineMm,spine)
    assert.equal(spec.geometryMeasured,true);assert.equal(spec.verified,false);assert.equal(spec.coverGeometrySource,'official_default')
  }
  const inferred=getPrintSpec({...v3Order(PRINT_PRODUCTS.REDP_250_HARD),page_count:24})
  assert.equal(inferred.geometryMeasured,false);assert.match(inferred.geometrySource,/추정/);assert.equal(inferred.verified,false)
})

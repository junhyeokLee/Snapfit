import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createPrintPublicCatalogHandler } from '../../supabase/functions/_shared/print-public-catalog.ts'
const item={productId:'REDP_200_SOFT',pageCount:20,retailPrice:49900,shippingFee:0,shippingIncluded:true,priceIsEstimate:true,
 priceSource:'SERVER_PLANNED',priceVersion:'PLANNED_V1',orderCodeApproved:false}
function fixture(data=[item],error=null){const calls=[];const handler=createPrintPublicCatalogHandler({now:()=>Date.parse('2026-10-19T00:00:00Z'),
 createAdminDatabase:()=>({rpc:async(name,params)=>{calls.push({name,params});return{data,error}}})});return{calls,handler}}
const request=(method='GET',query='')=>new Request('https://example.invalid/print-public-catalog'+query,{method})
test('anonymous retail catalogue uses current server pricing and an explicit public field allowlist',async()=>{
 const f=fixture([{...item,estimatedPrintCost:21230,margin:17180,apiSecret:'private',orderCode:'private',enabled:true}]);
 const r=await f.handler(request());assert.equal(r.status,200);assert.equal(r.headers.get('Cache-Control'),'no-store');
 const b=await r.json();assert.deepEqual(b.items,[item]);assert.equal(b.salesOpen,false);assert.equal(b.currency,'KRW');
 assert.equal(b.generatedAt,'2026-10-19T00:00:00.000Z');assert.deepEqual(f.calls,[{name:'read_print_public_catalog',params:{}}]);
 assert.match(b.shippingNotice,/予定|예정/)
})
test('read-only endpoint rejects all mutation methods and query injection without database work',async()=>{
 for(const method of ['POST','PUT','PATCH','DELETE']){const f=fixture();assert.equal((await f.handler(request(method))).status,405);assert.equal(f.calls.length,0)}
 const f=fixture();assert.equal((await f.handler(request('GET','?action=activate'))).status,400);assert.equal(f.calls.length,0);
 assert.equal((await f.handler(request('OPTIONS'))).status,200);assert.equal(f.calls.length,0)
})
test('invalid, unavailable or duplicate price rows fail closed; no zero or invented fallback prices',async()=>{
 for(const data of [null,[],{},[{...item,retailPrice:0}],[{...item,retailPrice:1.5}],[{...item,productId:'UNKNOWN'}],
  [{...item,pageCount:21}],[{...item,pageCount:82}],[{...item,shippingFee:3500}],[{...item,shippingIncluded:false}],
  [{...item,priceIsEstimate:false}],[{...item,priceSource:'PRIVATE_API'}],[{...item,orderCodeApproved:'Y'}],
  [{...item,priceVersion:'invalid version'}],[item,item],Array.from({length:311},()=>item)]){
  const response=await fixture(data).handler(request());assert.equal(response.status,503);assert.deepEqual(await response.json(),{error:'print_catalog_unavailable'})
 }
 const response=await fixture([item],{message:'private SQL details'}).handler(request());assert.equal(response.status,503);assert.deepEqual(await response.json(),{error:'print_catalog_unavailable'})
})

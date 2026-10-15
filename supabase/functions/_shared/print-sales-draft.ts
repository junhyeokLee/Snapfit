import { corsHeaders } from './cors.ts'
import { PRINT_PRODUCTS } from './print-contract.ts'
import { assertRedprintingAdmin,RedprintingAdminAuthError,type VerifiedUserLookup } from './redprinting-admin-auth.ts'
type Database={rpc(name:string,params:Record<string,unknown>):PromiseLike<{data:unknown;error:unknown}>}
type Dependencies={getUser:VerifiedUserLookup;createAdminDatabase():Database}
class PrintSalesDraftError extends Error{constructor(readonly code:string,readonly status=409){super(code)}}
const object=(v:unknown):Record<string,any>=>v&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,any>:{}
const uuid=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(v)
const revision=(v:unknown):v is string=>typeof v==='string'&&/^[a-f0-9]{64}$/.test(v)
const money=(v:unknown,min=0,max=100000000):v is number=>Number.isSafeInteger(v)&&Number(v)>=min&&Number(v)<=max
const timestamp=(v:unknown):v is string=>typeof v==='string'&&Number.isFinite(Date.parse(v))
const keys=(b:Record<string,unknown>,allowed:string[])=>Object.keys(b).every(k=>allowed.includes(k))
const reply=(v:unknown,status=200)=>Response.json(v,{status,headers:{...corsHeaders,'Cache-Control':'no-store'}})
const constants={productionEnabled:false,canOpenSales:false,paymentFeeRate:.05,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000}
const message='개발 견적을 바탕으로 만든 가격 초안이에요. 배송·포장 예산은 미확정이며, 저장해도 사양·샘플·운영 승인이나 실제 판매가 열리지 않아요.'
export function printDraftContribution(retail:number,print:number,shipping:number,packaging:number){
 if(!money(retail,1)||!money(print,1)||!money(shipping,0,10000000)||!money(packaging,0,10000000))throw new PrintSalesDraftError('invalid_print_sales_draft',400)
 // Integer rational ceiling: each 5% reserve equals ceil(retail/20).
 return retail-print-shipping-packaging-2*Math.floor((retail+19)/20)-3000
}
function candidate(raw:unknown){const c=object(raw)
 if(typeof c.productId!=='string'||!Object.hasOwn(PRINT_PRODUCTS,c.productId)||!Number.isSafeInteger(c.pageCount)||c.pageCount<20||c.pageCount>80||c.pageCount%2||
   !money(c.observedPrintCost,1)||!timestamp(c.observedAt)||!revision(c.sourceRevision)||typeof c.locked!=='boolean')throw new PrintSalesDraftError('print_sales_draft_record_invalid',503)
 let draft=null
 if(c.draft!=null){const d=object(c.draft)
   if(!uuid(d.version)||!money(d.retailPrice,1)||!money(d.shippingBudget,0,10000000)||!money(d.packagingBudget,0,10000000)||
     !Number.isSafeInteger(d.estimatedContribution)||typeof d.note!=='string'||d.note.length>1000||!revision(d.sourceRevision)||!timestamp(d.updatedAt))throw new PrintSalesDraftError('print_sales_draft_record_invalid',503)
   // A stale source revision remains visible; it is never silently refreshed.
   draft={version:d.version,retailPrice:d.retailPrice,shippingBudget:d.shippingBudget,packagingBudget:d.packagingBudget,estimatedContribution:d.estimatedContribution,
     note:d.note,sourceRevision:d.sourceRevision,updatedAt:d.updatedAt}
 }
 const defaultRetailPrice=c.productId==='REDP_200X150_SOFT'&&c.pageCount===20?49900:c.productId==='REDP_300_HARD'&&c.pageCount===80?159900:null
 return {productId:c.productId,productName:PRINT_PRODUCTS[c.productId as keyof typeof PRINT_PRODUCTS].productName,pageCount:c.pageCount,sourceRevision:c.sourceRevision,
   observedPrintCost:c.observedPrintCost,observedAt:c.observedAt,defaultRetailPrice,locked:c.locked,draft}
}
async function rpc(db:Database,name:string,params:Record<string,unknown>){const r=await db.rpc(name,params)
 if(r.error){const e=object(r.error),code=String(e.message??'')
   if(['print_sales_draft_locked','print_sales_draft_conflict','print_sales_draft_source_changed'].includes(code))throw new PrintSalesDraftError(code)
   if(e.code==='23505')throw new PrintSalesDraftError('print_sales_draft_conflict')
   if(e.code==='P0002')throw new PrintSalesDraftError('print_sales_draft_source_unavailable',404)
   if(e.code==='22023')throw new PrintSalesDraftError('invalid_print_sales_draft',400)
   throw new PrintSalesDraftError('print_sales_draft_storage_unavailable',503)
 }return r.data
}
export function createPrintSalesDraftHandler(deps:Dependencies){return async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
 if(req.method!=='POST')return reply({error:'method_not_allowed'},405)
 try{
   await assertRedprintingAdmin(req,deps.getUser)
   const text=await req.text();if(text.length>8192)throw new PrintSalesDraftError('invalid_print_sales_draft',400)
   let parsed:unknown;try{parsed=JSON.parse(text)}catch{throw new PrintSalesDraftError('invalid_print_sales_draft',400)}
   if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw new PrintSalesDraftError('invalid_print_sales_draft',400)
   const b=object(parsed)
   if(b.action==='overview'&&keys(b,['action'])){
     const rows=await rpc(deps.createAdminDatabase(),'read_print_sales_draft_candidates',{})
     if(!Array.isArray(rows)||rows.length>310)throw new PrintSalesDraftError('print_sales_draft_record_invalid',503)
     return reply({...constants,candidates:rows.map(candidate),message})
   }
   if(b.action!=='save'||!keys(b,['action','productId','pageCount','reviewedSourceRevision','expectedDraftVersion','retailPrice','shippingBudget','packagingBudget','note'])||
     typeof b.productId!=='string'||!Object.hasOwn(PRINT_PRODUCTS,b.productId)||!Number.isSafeInteger(b.pageCount)||b.pageCount<20||b.pageCount>80||b.pageCount%2||
     !revision(b.reviewedSourceRevision)||!Object.hasOwn(b,'expectedDraftVersion')||(b.expectedDraftVersion!==null&&!uuid(b.expectedDraftVersion))||
     !money(b.retailPrice,1)||!money(b.shippingBudget,0,10000000)||!money(b.packagingBudget,0,10000000)||typeof b.note!=='string'||b.note.length>1000)
     throw new PrintSalesDraftError('invalid_print_sales_draft',400)
   const value=await rpc(deps.createAdminDatabase(),'save_print_sales_draft',{p_product_id:b.productId,p_page_count:b.pageCount,p_source_revision:b.reviewedSourceRevision,
     p_expected_version:b.expectedDraftVersion,p_retail_price:b.retailPrice,p_shipping_budget:b.shippingBudget,p_packaging_budget:b.packagingBudget,p_note:b.note})
   return reply({productionEnabled:false,canOpenSales:false,candidate:candidate(value),message})
 }catch(e){if(e instanceof PrintSalesDraftError||e instanceof RedprintingAdminAuthError)return reply({error:e.code},e.status)
   return reply({error:'print_sales_draft_unavailable'},503)}
}}

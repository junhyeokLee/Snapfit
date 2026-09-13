import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {stripTypeScriptTypes} from 'node:module'
import vm from 'node:vm'
import {adminPagination,adminSearch,exactPage,adminIdentifier,adminPointCatalog} from '../../supabase/functions/_shared/admin-catalog.ts'
import {OrderPaymentError} from '../../supabase/functions/_shared/order-types.ts'

function handler(database) {
  let result
  const source=stripTypeScriptTypes(readFileSync(new URL('../../supabase/functions/admin-ops/index.ts',import.meta.url),'utf8').replace(/^import .*$/gm,''))
  vm.runInNewContext(source,{
    Deno:{serve:f=>result=f,env:{get:key=>key==='SNAPFIT_ADMIN_KEY'?'fixture-admin':undefined}},
    adminClient:()=>database,Response,console:{error(){}},corsHeaders:{},jsonResponse:(body,status=200)=>Response.json(body,{status}),
    adminPagination,adminSearch,exactPage,adminIdentifier,adminPointCatalog,OrderPaymentError,
    withPrintOperations:async(_db,row)=>row,loadOrder:async(_db,id)=>({order_id:id,title:'Album',amount:69900,status:'PAYMENT_COMPLETED',print_cost_snapshot:{minimumContribution:10000}}),
  })
  return body=>result(new Request('https://example.test',{method:'POST',body:JSON.stringify(body)}))
}
function query(result,record=[]) {
  const q={then(resolve,reject){return Promise.resolve(result).then(resolve,reject)}}
  for(const method of ['select','eq','neq','gte','in','or','order','range','update','insert'])q[method]=(...args)=>{record.push([method,...args]);return q}
  q.maybeSingle=async()=>result
  return q
}

test('every new admin action refuses missing/wrong keys before touching the database',async()=>{
  let touched=0;const run=handler({from(){touched++;throw new Error('must not access')}})
  for(const action of ['orders','getOrder','pointProducts','updatePointProduct','upsertPointProduct','csSignals']){
    const response=await run({action,adminKey:'wrong'});assert.equal(response.status,403);assert.deepEqual(await response.json(),{error:'forbidden'})
  }
  assert.equal(touched,0)
})
test('orders uses exact count, safe quoted search, bounded pagination, and direct getOrder shape',async()=>{
  const record=[],run=handler({from:()=>query({data:[{order_id:'ord_1',amount:100,status:'PAYMENT_COMPLETED'}],error:null,count:51},record)})
  const response=await run({action:'orders',adminKey:'fixture-admin',page:1,size:20,keyword:'가족,or(status.eq.PAID)"%'})
  const body=await response.json();assert.equal(response.status,200);assert.equal(body.totalElements,51);assert.equal(body.totalPages,3);assert.equal(body.hasNext,true)
  assert.equal(body.items[0].orderId,'ord_1');assert.equal(record.find(r=>r[0]==='select')[2].count,'exact')
  assert.equal(record.find(r=>r[0]==='range')[1],20)
  const search=record.find(r=>r[0]==='or')[1];assert.ok(search.startsWith('order_id.ilike."%가족,'));assert.ok(search.includes('\\"\\%'))
  const one=await(await run({action:'getOrder',adminKey:'fixture-admin',orderId:'ord_7'})).json()
  assert.equal(one.orderId,'ord_7');assert.deepEqual(one.printCostSnapshot,{minimumContribution:10000})
  for(const payload of [{page:-1},{size:101},{page:1.5},{size:'20'}])assert.equal((await run({action:'orders',adminKey:'fixture-admin',...payload})).status,400)
})
test('database errors in dashboard and support cannot masquerade as zero counts or empty inquiries',async()=>{
  const run=handler({from:()=>query({data:null,count:null,error:{message:'private database failure'}})})
  for(const action of ['dashboard','csSignals','orders','templates','pointProducts']){
    const response=await run({action,adminKey:'fixture-admin'});assert.equal(response.status,500);assert.deepEqual(await response.json(),{error:'admin_operation_failed'})
  }
  assert.throws(()=>exactPage({data:[],count:null,error:null},0,20),/admin_data_unavailable/)
})
test('point products preserve schema identifiers, allow explicit new catalog config and reject price/key bypasses',async()=>{
  let existing=null;let saved;const records=[]
  const db={from(table){assert.equal(table,'point_shop_products');const r=[];records.push(r);let mutation
    const q=query({},r)
    q.update=payload=>{mutation=payload;return q};q.insert=payload=>{mutation=payload;return q}
    q.maybeSingle=async()=>mutation?{data:saved={...existing,...mutation,updated_at:'new'},error:null}:{data:existing,error:null}
    return q
  }}
  const body={productKey:'template:-123',assetId:'-123',kind:'template',title:'Bundled template',pointPrice:100,isActive:false}
  const added=await adminPointCatalog(db,'upsertPointProduct',body);assert.equal(added.productKey,'template:-123');assert.equal(added.pointPrice,100)
  existing=saved
  await adminPointCatalog(db,'updatePointProduct',{productKey:body.productKey,pointPrice:0,isActive:true,expectedUpdatedAt:'new'})
  assert.equal(saved.point_price,0);assert.equal(saved.asset_id,'-123')
  for(const change of [{pointPrice:-1},{pointPrice:1.2},{pointPrice:null,isActive:true},{isActive:'true'},{productKey:'order:123'},{kind:'sticker'}])await assert.rejects(adminPointCatalog(db,'upsertPointProduct',{...body,...change}),/invalid_point_product/)
  await assert.rejects(adminPointCatalog(db,'updatePointProduct',{...body,expectedUpdatedAt:'stale'}),/point_product_changed/)
  assert.equal(records.some(r=>r.some(x=>x[0]==='delete')),false)
})

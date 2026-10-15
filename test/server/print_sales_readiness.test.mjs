import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {stripTypeScriptTypes} from 'node:module'
import vm from 'node:vm'
import {createPrintSalesReadinessHandler,printSalesReadiness} from '../../supabase/functions/_shared/print-sales-readiness.ts'
const time=Date.parse('2026-10-14T12:00:00Z')
const runtime={portoneEnabled:true,portoneLive:true,portoneCredentialsConfigured:true,redprintingEnabled:true,redprintingApproved:true,redprintingCredentialsConfigured:true,fulfillmentEnabled:true,depositEnabled:true,refundsEnabled:true}
const configuration={present:true,enabled:true,businessReady:true,portoneLiveReady:true,redprintingLiveReady:true,rendererReady:true,fulfillmentReady:true,environmentLive:true,routeConfigured:true,routeMatchesRuntime:true,
  workerLastSeenAt:'2026-10-14T11:59:00Z'}
const approvedSpec={id:'REDP_200X150_SOFT',verified:true,specVersion:'SYNTHETIC_APPROVED_V1',coverType:'SOFT',pageCount:20,dpi:300,colorSpace:'sRGB',layoutFit:'contain',minimumPhotoPpi:150,minInteriorPages:20,maxInteriorPages:80,pageMultiple:2,
  spineMm:7.22,interior:{trimWidthMm:200,trimHeightMm:150,bleedMm:5},cover:{widthMm:417.22,heightMm:160,back:{xMm:5,yMm:5,widthMm:200,heightMm:150},front:{xMm:212.22,yMm:5,widthMm:200,heightMm:150}}}
const costSnapshot={estimatedPrintCost:21230,estimatedShippingCost:3500,estimatedPackagingCost:500,paymentFeeRate:.04,reprintReserveRate:.05,operationsReserve:3000,minimumContribution:10000,
  deliveryPolicy:{coverage:'POSTCODE_RANGES',verified:true,evidence:'synthetic verified shipping policy',approvedPostcodeRanges:[{start:'12000',end:'12999'}]},
  fulfillmentConfirmation:{senderName:'스냅핏',senderLabelConfirmed:true,priceSlipOmittedConfirmed:true,promotionalMaterialsOmittedConfirmed:true,evidence:'synthetic brand confirmation'}}
const combination={productId:'REDP_200X150_SOFT',pageCount:20,amount:49900,priceVersion:'SYNTHETIC_FINAL_V1',retailFinal:true,supplierCostConfirmed:true,shippingConfirmed:true,packagingConfirmed:true,specApproved:true,fileApproved:true,
  sampleApproved:true,orderCodePresent:true,approvalEvidencePresent:true,approvedSpec,costSnapshot}
function fixture(overrides={}){
  const calls=[],snapshot={configuration:structuredClone(configuration),senderConfigured:true,combinations:[structuredClone(combination)]}
  const deps={getUser:async()=>{calls.push('auth');return{id:'11111111-1111-4111-8111-111111111111',app_metadata:{role:'admin'}}},runtime:()=>{calls.push('runtime');return{...runtime}},
    createAdminDatabase:()=>{calls.push('database');return{readonly:true}},readSnapshot:async()=>{calls.push('read');return snapshot},now:()=>time,...overrides}
  return{handler:createPrintSalesReadinessHandler(deps),snapshot,calls}
}
const request=(body={},auth='Bearer synthetic-admin',method='POST')=>new Request('https://example.invalid/print-sales-readiness',{method,headers:auth?{authorization:auth}:{},...(method==='POST'?{body:JSON.stringify(body)}:{})})
const result=async r=>({status:r.status,body:await r.json()})

test('only current Auth administrator role can read readiness; anonymous/customer/worker/user_metadata do not touch configuration',async()=>{
  for(const [overrides,auth,status]of [[{},null,401],[{getUser:async()=>null},'Bearer stale',401],[{getUser:async()=>{throw Error('private token')}},'Bearer stale',401],
    [{getUser:async()=>({id:'customer',app_metadata:{role:'customer'},user_metadata:{role:'admin'}})},'Bearer customer',403],
    [{getUser:async()=>({id:'worker',app_metadata:{role:'print_worker'}})},'Bearer worker',403]]){
    const f=fixture(overrides),r=await result(await f.handler(request({},auth)));assert.equal(r.status,status)
    assert.equal(f.calls.includes('database'),false);assert.equal(f.calls.includes('runtime'),false);assert.equal(f.calls.includes('read'),false)
  }
})
test('empty POST is the only operation; method/body and callback flags cannot modify or inspect orders',async()=>{
  const f=fixture()
  assert.equal((await f.handler(request({},null,'OPTIONS'))).status,200);assert.equal((await f.handler(request({},null,'GET'))).status,405)
  for(const body of [{enabled:true},{action:'approve'},{paymentId:'SFP_fake',paid:true},{orderId:'private'},[],null])assert.equal((await f.handler(request(body))).status,400)
  assert.equal(f.calls.includes('database'),false)
})
test('response redacts keys, route IDs, raw specification, commercial evidence, source URLs and personal data',async()=>{
  const f=fixture(),before=structuredClone(f.snapshot)
  f.snapshot.configuration.store_id='store-private-account';f.snapshot.configuration.api_secret='private-server-key';f.snapshot.recipient={name:'private-person'}
  f.snapshot.combinations[0].approvedSpec.privateExtra={photo:'https://private.example/photo',evidence:'private-correspondence'}
  f.snapshot.combinations[0].costSnapshot.privateExtra={supplierCost:9999,apiKey:'private-key'}
  const unchanged=structuredClone(f.snapshot),r=await result(await f.handler(request()))
  assert.equal(r.status,200);assert.equal(r.body.globalSetupReady,true);assert.equal(r.body.salesEnabled,true);assert.equal(r.body.perAlbumCheckRequired,true)
  assert.equal(r.body.approvedRecordCount,1);assert.equal(r.body.validatedSalesRecordCount,1);assert.equal(r.body.approvedPrices[0].amount,49900)
  assert.deepEqual(Object.keys(r.body.approvedPrices[0]).sort(),['productId','productName','pageCount','coverType','amount','currency','priceVersion'].sort())
  assert.doesNotMatch(JSON.stringify(r.body),/private-|store-private|supplierCost|estimatedPrintCost|costSnapshot|approvedSpec|https:\/\//)
  assert.deepEqual(f.snapshot,unchanged);assert.equal(before.configuration.enabled,true);assert.deepEqual(f.calls,['auth','runtime','database','read'])
  assert.deepEqual(r.body.deposit,{balanceChecked:false,balance:null,message:'레드프린팅 예치금 잔액은 아직 확인하지 않았어요.'})
})
test('empty/closed configuration reports preparation, never vendor rejection or a fabricated ready catalog',async()=>{
  const s={configuration:{},senderConfigured:false,combinations:[]},r=printSalesReadiness(s,Object.fromEntries(Object.keys(runtime).map(k=>[k,false])),time)
  assert.equal(r.status,'PREPARING');assert.equal(r.globalSetupReady,false);assert.equal(r.salesEnabled,false);assert.equal(r.workerHeartbeatRecent,false)
  assert.equal(r.approvedRecordCount,0);assert.equal(r.validatedSalesRecordCount,0);assert.deepEqual(r.approvedPrices,[])
  assert.doesNotMatch(JSON.stringify(r),/거절|승인 거부|REJECTED|PAID/);assert.ok(r.pendingActions.length>0)
})
test('approval flags alone never create a validated sale: geometry, margin, delivery/brand facts and final price are required',()=>{
  for(const mutate of [r=>r.approvedSpec.verified=false,r=>r.approvedSpec.interior.bleedMm=0,r=>r.costSnapshot.estimatedPrintCost=49900,
    r=>r.costSnapshot.deliveryPolicy.verified=false,r=>r.costSnapshot.deliveryPolicy.approvedPostcodeRanges[0].start='invalid',
    r=>r.costSnapshot.fulfillmentConfirmation.senderName='other',r=>r.costSnapshot.operationsReserve=0,r=>r.amount=0,r=>r.priceVersion='',r=>r.productId='UNKNOWN']){
    const r=structuredClone(combination);mutate(r)
    const report=printSalesReadiness({configuration,senderConfigured:true,combinations:[r]},runtime,time)
    assert.equal(report.approvedRecordCount,1);assert.equal(report.validatedSalesRecordCount,0);assert.equal(report.globalSetupReady,false);assert.deepEqual(report.approvedPrices,[])
  }
  const r=structuredClone(combination);r.sampleApproved=false
  assert.equal(printSalesReadiness({configuration,senderConfigured:true,combinations:[r]},runtime,time).approvedRecordCount,0)
})
test('database and live runtime each gate setup; one stale/false fact keeps sales closed',()=>{
  for(const key of ['businessReady','portoneLiveReady','redprintingLiveReady','rendererReady','fulfillmentReady','environmentLive','routeConfigured','routeMatchesRuntime']){
    const report=printSalesReadiness({configuration:{...configuration,[key]:false},senderConfigured:true,combinations:[combination]},runtime,time)
    assert.equal(report.globalSetupReady,false,key);assert.equal(report.salesEnabled,false,key)
  }
  for(const key of ['portoneLive','portoneCredentialsConfigured','redprintingEnabled','redprintingApproved','redprintingCredentialsConfigured','fulfillmentEnabled','depositEnabled','refundsEnabled']){
    const report=printSalesReadiness({configuration,senderConfigured:true,combinations:[combination]},{...runtime,[key]:false},time)
    assert.equal(report.globalSetupReady,false,key);assert.equal(report.salesEnabled,false,key)
  }
  for(const last of [null,'invalid','2026-10-14T11:54:59Z','2026-10-14T12:01:00Z']){
    const report=printSalesReadiness({configuration:{...configuration,workerLastSeenAt:last},senderConfigured:true,combinations:[combination]},runtime,time)
    assert.equal(report.workerHeartbeatRecent,false);assert.equal(report.globalSetupReady,false)
  }
})
test('setup readiness and customer activation are separate; enabled false is simply not yet open',()=>{
  for(const [c,rt]of [[{...configuration,enabled:false},runtime],[configuration,{...runtime,portoneEnabled:false}]]){
    const report=printSalesReadiness({configuration:c,senderConfigured:true,combinations:[combination]},rt,time)
    assert.equal(report.globalSetupReady,true);assert.equal(report.status,'SETUP_READY');assert.equal(report.salesEnabled,false);assert.equal(report.perAlbumCheckRequired,true)
    assert.equal(report.conditions.find(v=>v.code==='sales_activation').ready,false);assert.doesNotMatch(JSON.stringify(report),/거절|REJECTED/)
  }
})
test('storage failures are safe and do not fall back to a fabricated closed or ready configuration',async()=>{
  const f=fixture({readSnapshot:async()=>{throw new Error('private-key contact supplierCost data')}}),r=await result(await f.handler(request()))
  assert.deepEqual(r,{status:503,body:{error:'print_sales_readiness_unavailable'}})
})
test('only approved production configuration reads balance; failure remains unknown and no history or credentials escape',async()=>{
  for(const key of ['redprintingEnabled','redprintingApproved','redprintingCredentialsConfigured']) {
    const f=fixture({runtime:()=>({...runtime,[key]:false}),readDepositBalance:async()=>assert.fail('disabled supplier queried')})
    assert.equal((await result(await f.handler(request()))).body.deposit.balanceChecked,false)
  }
  for(const [balance,checked]of [[24730,true],[0,true],[NaN,false],[-1,false]]) {
    const f=fixture({readDepositBalance:async()=>balance}),r=await result(await f.handler(request()))
    assert.equal(r.status,200);assert.equal(r.body.deposit.balanceChecked,checked);assert.equal(r.body.deposit.balance,checked?balance:null)
  }
  const f=fixture({readDepositBalance:async()=>{throw Error('private key account history')}}),r=await result(await f.handler(request()))
  assert.equal(r.status,200);assert.equal(r.body.deposit.balance,null);assert.doesNotMatch(JSON.stringify(r),/private key|account history/)
})
test('Edge wrapper derives facts after Auth and performs one read-only RPC without disabled supplier/payment requests',async()=>{
  const source=readFileSync(new URL('../../supabase/functions/print-sales-readiness/index.ts',import.meta.url),'utf8'),calls=[]
  let handler
  const env={PRINT_PORTONE_PRODUCTION_ENABLED:'false',PRINT_PORTONE_ENVIRONMENT:'test',PRINT_PORTONE_STORE_ID:'store-synthetic',PRINT_PORTONE_CHANNEL_KEY:'channel-key-synthetic',PRINT_PORTONE_V2_API_SECRET:'synthetic-server-secret'}
  const script=stripTypeScriptTypes(source.replace(/^import .+\n/gm,''),{mode:'transform'})
  vm.runInNewContext(script,{Deno:{env:{get:name=>{calls.push(`env:${name}`);return env[name]}},serve:h=>handler=h},
    getUser:async()=>{calls.push('auth');return{id:'admin',app_metadata:{role:'admin'}}},
    adminClient:()=>{calls.push('db');return{rpc:async(name,params)=>{calls.push({name,params});return{data:{configuration:{},combinations:[],senderConfigured:false},error:null}}}},
    createPrintSalesReadinessHandler,Boolean})
  assert.equal(calls.length,0);assert.equal((await handler(request())).status,200);assert.equal(calls[0],'auth')
  assert.equal(calls.filter(v=>v?.name==='read_print_sales_readiness').length,1)
  assert.doesNotMatch(source,/queryPortOne|vendor\.submit|\.update\(|\.insert\(|fetch\(/)
})
test('customer entry requires enabled refund recovery before issuing a new SDK request; existing payment observation remains independent',()=>{
  for(const name of ['print-order-checkout','print-order-confirm']) {
    const source=readFileSync(new URL(`../../supabase/functions/${name}/index.ts`,import.meta.url),'utf8')
    let deps
    const script=stripTypeScriptTypes(source.replace(/^import .+\n/gm,''),{mode:'transform'})
    const env={PRINT_PORTONE_PRODUCTION_ENABLED:'true'}
    vm.runInNewContext(script,{Deno:{env:{get:k=>env[k]},serve:()=>{}},getUser:()=>{},adminClient:()=>{},createProductionPrintCheckoutHandler:d=>{deps=d;return()=>{}}})
    assert.equal(deps.configuration().enabled,false)
    env.PRINT_ORDER_REFUNDS_ENABLED='true';assert.equal(deps.configuration().enabled,false)
    env.PRINT_ORDER_SCHEDULER_ENABLED='true';assert.equal(deps.configuration().enabled,true)
    env.PRINT_ORDER_SCHEDULER_ENABLED='false';assert.equal(deps.configuration().enabled,false)
    env.PRINT_ORDER_SCHEDULER_ENABLED='true'
    env.PRINT_PORTONE_PRODUCTION_ENABLED='false';assert.equal(deps.configuration().enabled,false)
  }
})
test('app PDF mode describes Supabase scheduling and requires its private runtime and recent execution',()=>{
  const snapshot={configuration:{...configuration,fulfillmentMode:'APP_PDF_SUPABASE'},senderConfigured:true,combinations:[combination]}
  const active={...runtime,schedulerEnabled:true,schedulerSecretConfigured:true}
  const ready=printSalesReadiness(snapshot,active,time)
  assert.equal(ready.globalSetupReady,true);assert.equal(ready.fulfillmentMode,'APP_PDF_SUPABASE')
  assert.equal(ready.maxPrepaymentFileBytes,500000000)
  assert.equal(ready.maxPrepaymentCoverBytes,150000000)
  assert.equal(ready.maxStorageObjectBytes,50000000)
  assert.equal(ready.printPartBytes,16000000)
  assert.equal(ready.conditions.find(v=>v.code==='worker').title,'Supabase 자동 발주')
  for(const key of ['schedulerEnabled','schedulerSecretConfigured'])assert.equal(printSalesReadiness(snapshot,{...active,[key]:false},time).globalSetupReady,false)
  assert.equal(printSalesReadiness({...snapshot,configuration:{...snapshot.configuration,workerLastSeenAt:null}},active,time).globalSetupReady,false)
})

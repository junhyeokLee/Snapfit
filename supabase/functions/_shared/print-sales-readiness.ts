import { corsHeaders } from './cors.ts'
import { assertRedprintingAdmin, RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'
import { frozenPrintSpec, calculateContribution, PRINT_PRODUCTS } from './print-contract.ts'

// Runtime credentials are reduced to facts in the Edge wrapper. The handler
// neither receives keys nor contacts PortOne/Redprinting to move money.
export type PrintSalesRuntimeFacts = {
  portoneEnabled: boolean; portoneLive: boolean; portoneCredentialsConfigured: boolean;
  redprintingEnabled: boolean; redprintingApproved: boolean; redprintingCredentialsConfigured: boolean;
  fulfillmentEnabled: boolean; depositEnabled: boolean;
  refundsEnabled: boolean;
  schedulerEnabled?: boolean; schedulerSecretConfigured?: boolean;
}
export type PrintSalesReadinessDependencies = {
  getUser: VerifiedUserLookup
  createAdminDatabase(): unknown
  readSnapshot(database: unknown): Promise<unknown>
  runtime(): PrintSalesRuntimeFacts
  readDepositBalance?(database: unknown): Promise<number>
  now?: () => number
}
const object=(v:unknown):Record<string,any>=>v&&typeof v==='object'&&!Array.isArray(v)?v as Record<string,any>:{}
const positive=(v:unknown,min=1)=>Number.isSafeInteger(v)&&Number(v)>=min
const flagKeys=['retailFinal','supplierCostConfirmed','shippingConfirmed','packagingConfirmed','specApproved','fileApproved','sampleApproved','orderCodePresent','approvalEvidencePresent']
function recordApproved(row:Record<string,any>) { return flagKeys.every(k=>row[k]===true) }
function validatedPrice(row:Record<string,any>) {
  if (!recordApproved(row)||!Object.hasOwn(PRINT_PRODUCTS,String(row.productId))||!positive(row.amount)||!positive(row.pageCount,20)||row.pageCount>80||row.pageCount%2||
      typeof row.priceVersion!=='string'||!/^[A-Za-z0-9_.-]{1,120}$/.test(row.priceVersion)) return null
  const product=PRINT_PRODUCTS[row.productId as keyof typeof PRINT_PRODUCTS],cost=object(row.costSnapshot),delivery=object(cost.deliveryPolicy),brand=object(cost.fulfillmentConfirmation)
  try {
    frozenPrintSpec({checkout_flow:'PORTONE_V2_V1',page_count:row.pageCount,pricing_version:'PRINT_REDP_COVERTYPE_V3',
      print_product_snapshot:product,print_content_snapshot:{album:{ratio:String(product.trimWidthMm/product.trimHeightMm),
        cover_layers_json:JSON.stringify({printProduct:product})},pages:[],printProduct:product},print_spec_snapshot:row.approvedSpec})
    if(!positive(cost.estimatedPrintCost)||!positive(cost.estimatedShippingCost,0)||!positive(cost.estimatedPackagingCost,0)||
      !positive(cost.operationsReserve,3000)||!positive(cost.minimumContribution,10000)||
      !['paymentFeeRate','reprintReserveRate'].every(k=>typeof cost[k]==='number'&&Number.isFinite(cost[k])&&cost[k]>=0&&cost[k]<1)||
      delivery.verified!==true||typeof delivery.evidence!=='string'||delivery.evidence.length<10||
      (delivery.coverage!=='NATIONWIDE_FIXED' && !(delivery.coverage==='POSTCODE_RANGES'&&Array.isArray(delivery.approvedPostcodeRanges)&&delivery.approvedPostcodeRanges.length>0&&
        delivery.approvedPostcodeRanges.every((r:unknown)=>{const p=object(r);return typeof p.start==='string'&&typeof p.end==='string'&&/^\d{5}$/.test(p.start)&&/^\d{5}$/.test(p.end)&&p.start<=p.end})))||
      brand.senderName!=='스냅핏'||brand.senderLabelConfirmed!==true||brand.priceSlipOmittedConfirmed!==true||brand.promotionalMaterialsOmittedConfirmed!==true||
      typeof brand.evidence!=='string'||brand.evidence.length<10) return null
    calculateContribution({amount:row.amount,print_cost_snapshot:cost},{actualPrintCost:cost.estimatedPrintCost,
      actualShippingCost:cost.estimatedShippingCost,actualPackagingCost:cost.estimatedPackagingCost})
    return {productId:product.id,productName:product.productName,pageCount:row.pageCount,coverType:product.id.endsWith('_HARD')?'HARD':'SOFT',
      amount:row.amount,currency:'KRW',priceVersion:row.priceVersion}
  } catch { return null }
}
export function printSalesReadiness(snapshot:unknown,runtime:PrintSalesRuntimeFacts,now:number,depositBalance:number|null=null) {
  const s=object(snapshot),config=object(s.configuration)
  if(!Array.isArray(s.combinations)||s.combinations.length>310||!Number.isFinite(now)) throw new Error('invalid_readiness_snapshot')
  const records=s.combinations.map(object),approvedRecordCount=records.filter(recordApproved).length
  const approvedPrices=records.map(validatedPrice).filter(v=>v!==null)
  const last=typeof config.workerLastSeenAt==='string'?Date.parse(config.workerLastSeenAt):NaN
  const workerHeartbeatRecent=Number.isFinite(last)&&now-last>=-5000&&now-last<=5*60*1000
  const present=config.present===true
  const appPdfMode=config.fulfillmentMode==='APP_PDF_SUPABASE'
  const conditions:Array<{code:string;title:string;ready:boolean;owner:string;pendingAction:string|null}>=[]
  const add=(code:string,title:string,ready:boolean,owner:string,action:string)=>conditions.push({code,title,ready,owner,pendingAction:ready?null:action})
  add('business','사업자 확인 기록',present&&config.businessReady===true,'사용자','사업자 정보와 운영 계약의 확인 기록을 등록해 주세요.')
  add('payment','포트원 운영 결제 연결',present&&config.portoneLiveReady===true&&config.environmentLive===true&&config.routeConfigured===true&&config.routeMatchesRuntime===true&&
    runtime.portoneLive===true&&runtime.portoneCredentialsConfigured===true,'결제사·연동 담당','결제사 운영 승인을 받은 뒤 포트원의 운영 연결을 확인해 주세요.')
  add('supplier','레드프린팅 운영 연결',present&&config.redprintingLiveReady===true&&runtime.redprintingEnabled===true&&runtime.redprintingApproved===true&&runtime.redprintingCredentialsConfigured===true,
    '인쇄업체·연동 담당','레드프린팅 정식 계약과 운영 연결을 확인해 주세요.')
  add('refunds','취소·환불 자동 처리',runtime.refundsEnabled===true&&runtime.portoneLive===true&&runtime.portoneCredentialsConfigured===true,
    '운영 담당','운영 결제 연결과 취소·환불 자동 처리를 확인해 주세요.')
  add('catalog','규격·파일·실물·판매가 확인',approvedPrices.length>0,'인쇄업체·운영 담당','표지·내지 파일과 실물 샘플, 배송·포장 및 최종 판매가를 확인해 주세요.')
  add('sender','발송자 설정',s.senderConfigured===true,'운영 담당','발송자명 스냅핏과 발송자 연락처·주소 설정을 확인해 주세요.')
  add('worker',appPdfMode?'Supabase 자동 발주':'제작 처리 서버',present&&config.rendererReady===true&&config.fulfillmentReady===true&&runtime.fulfillmentEnabled===true&&runtime.depositEnabled===true&&
    runtime.redprintingEnabled===true&&runtime.redprintingApproved===true&&runtime.redprintingCredentialsConfigured===true&&runtime.portoneLive===true&&runtime.portoneCredentialsConfigured===true&&workerHeartbeatRecent,
    '운영 담당',appPdfMode?'결제 전 PDF 검수와 Supabase 자동 발주의 운영 설정·최근 실행 상태를 확인해 주세요.':'제작 처리 서버의 운영 설정과 최근 실행 상태를 확인해 주세요.')
  if(appPdfMode&&!(runtime.schedulerEnabled===true&&runtime.schedulerSecretConfigured===true)) {
    const condition=conditions.find(v=>v.code==='worker')!;condition.ready=false
    condition.pendingAction='Supabase 자동 발주 실행 설정과 비공개 인증을 확인해 주세요.'
  }
  const globalSetupReady=conditions.every(c=>c.ready)
  const activated=present&&config.enabled===true&&runtime.portoneEnabled===true
  add('sales_activation','고객 주문 개방 설정',activated,'운영 담당','운영 준비를 확인한 뒤 고객 주문을 열어 주세요.')
  const pendingActions=conditions.filter(c=>!c.ready).map(c=>c.pendingAction as string)
  const balanceChecked=Number.isSafeInteger(depositBalance)&&Number(depositBalance)>=0
  if(!balanceChecked)pendingActions.push('레드프린팅 예치금 잔액은 별도로 확인해 주세요.')
  else if(depositBalance===0)pendingActions.push('주문 제작비를 결제할 레드프린팅 예치금을 충전해 주세요.')
  return {checkedAt:new Date(now).toISOString(),status:globalSetupReady?'SETUP_READY':'PREPARING',globalSetupReady,
    salesEnabled:activated&&globalSetupReady,perAlbumCheckRequired:true,approvedRecordCount,validatedSalesRecordCount:approvedPrices.length,approvedPrices,
    fulfillmentMode:appPdfMode?'APP_PDF_SUPABASE':'LEGACY_WORKER',maxPrepaymentFileBytes:appPdfMode?500000000:null,
    maxPrepaymentCoverBytes:appPdfMode?150000000:null,maxStorageObjectBytes:appPdfMode?50000000:null,printPartBytes:appPdfMode?16000000:null,
    workerHeartbeatRecent,conditions,pendingActions,deposit:{balanceChecked,balance:balanceChecked?depositBalance:null,
      message:balanceChecked?'현재 예치금 잔액이에요. 주문마다 제작·배송·포장 비용과 다시 비교해요.':'레드프린팅 예치금 잔액은 아직 확인하지 않았어요.'},
    message:globalSetupReady?'전역 설정을 확인했어요. 앨범·배송 지역·원본 파일 검수와 예치금 잔액 확인은 별도로 필요해요.':'고객 주문을 열기 위한 확인이 남아 있어요.'}
}
const reply=(body:unknown,status=200)=>Response.json(body,{status,headers:{...corsHeaders,'Cache-Control':'no-store'}})
export function createPrintSalesReadinessHandler(deps:PrintSalesReadinessDependencies) {
  return async(req:Request)=>{
    if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
    if(req.method!=='POST')return reply({error:'method_not_allowed'},405)
    try {
      await assertRedprintingAdmin(req,deps.getUser)
      let body:unknown
      try {const text=await req.text();if(text.length>1024)throw new Error();body=JSON.parse(text)} catch {return reply({error:'invalid_readiness_request'},400)}
      if(!body||typeof body!=='object'||Array.isArray(body)||Object.keys(body).length)return reply({error:'invalid_readiness_request'},400)
      const runtime=deps.runtime(),db=deps.createAdminDatabase(),snapshot=await deps.readSnapshot(db)
      // Never query a development account or infer funding from a test key.
      let balance:number|null=null
      if(runtime.redprintingEnabled&&runtime.redprintingApproved&&runtime.redprintingCredentialsConfigured&&deps.readDepositBalance) {
        try { balance=await deps.readDepositBalance(db) } catch { /* Unknown is not zero or a funded account. */ }
      }
      return reply(printSalesReadiness(snapshot,runtime,deps.now?.()??Date.now(),balance))
    } catch(error) {
      if(error instanceof RedprintingAdminAuthError)return reply({error:error.code},error.status)
      return reply({error:'print_sales_readiness_unavailable'},503)
    }
  }
}

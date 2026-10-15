import { REDPRINTING_API_ORIGIN, RedprintingError, identifier, orderStatus } from './redprinting.ts'
import type { SupplierStatus } from './print-fulfillment-vendor.ts'

export interface PrintCancellationVendor {
  status(orderNum: string, orderSeq: number): Promise<SupplierStatus>
  cancel(orderNum: string, orderSeq: number): Promise<void>
}
export type PrintCancellationVendorConfiguration = {
  enabled: boolean; environment: string; productionApproved: boolean; userId: string; apiKey: string
}
/** Separate adapter: cannot submit files, charge deposits, or manufacture. */
export class RedprintingCancellationClient implements PrintCancellationVendor {
  private token = ''
  constructor(private readonly config: PrintCancellationVendorConfiguration,
    private readonly acquire: ()=>Promise<()=>Promise<void>>,private readonly fetcher: typeof fetch=fetch) {}
  private configured() {
    if(this.config.enabled!==true||this.config.environment!=='production'||this.config.productionApproved!==true||!this.config.userId||!this.config.apiKey)
      throw new RedprintingError('production_vendor_not_configured',503)
  }
  private async request(path: string,method: 'GET'|'POST',body?:unknown,authenticate=false):Promise<Record<string,any>> {
    this.configured();const release=await this.acquire()
    try {
      const response=await this.fetcher(`${REDPRINTING_API_ORIGIN}${path}`,{method,redirect:'error',signal:AbortSignal.timeout(25000),
        headers:{'Content-Type':'application/json',...(authenticate?{'x-api-key':`Bearer ${this.config.apiKey}`}:{Authorization:`Token ${this.token}`})},
        ...(body===undefined?{}:{body:JSON.stringify(body)})})
      if(!response.ok){await response.body?.cancel().catch(()=>{});throw new RedprintingError(response.status===404?'vendor_order_not_found':'vendor_cancel_uncertain',response.status===404?404:502,true)}
      const length=response.headers.get('Content-Length'),limit=1024*1024
      if(length!=null&&(!/^\d+$/.test(length)||Number(length)>limit)){await response.body?.cancel().catch(()=>{});throw new RedprintingError('vendor_response_invalid',502,true)}
      if(!response.body)throw new RedprintingError('vendor_response_invalid',502,true)
      const reader=response.body.getReader(),decoder=new TextDecoder('utf-8',{fatal:true});let text='',count=0
      try{for(;;){const c=await reader.read();if(c.done)break;count+=c.value.byteLength;if(count>limit){await reader.cancel().catch(()=>{});throw new RedprintingError('vendor_response_invalid',502,true)}text+=decoder.decode(c.value,{stream:true})}text+=decoder.decode()}
      finally{reader.releaseLock()}
      let value:any;try{value=JSON.parse(text)}catch{throw new RedprintingError('vendor_response_invalid',502,true)}
      if(!value||typeof value!=='object'||Array.isArray(value))throw new RedprintingError('vendor_response_invalid',502,true)
      return value
    }catch(e){if(e instanceof RedprintingError)throw e;throw new RedprintingError('vendor_cancel_uncertain',502,true)}
    finally{await release()}
  }
  private async authenticate(){
    this.configured();if(this.token)return
    const value=await this.request('/v1/auth/token','POST',{id:identifier(this.config.userId),expired:'1h'},true)
    if(value.success!==true||typeof value.token!=='string'||value.token.length<20)throw new RedprintingError('vendor_authentication_failed',502)
    this.token=value.token
  }
  async status(orderNum:string,orderSeq:number){
    if(orderSeq!==1)throw new RedprintingError('vendor_cancel_identity_invalid',400)
    await this.authenticate()
    return orderStatus(await this.request(`/v1/code/order-status?order_num=${encodeURIComponent(identifier(orderNum))}&order_seq=1`,'GET'),orderNum,1)
  }
  async cancel(orderNum:string,orderSeq:number){
    if(orderSeq!==1)throw new RedprintingError('vendor_cancel_identity_invalid',400)
    await this.authenticate()
    const result=await this.request('/v1/code/order-cancel','POST',{order_num:identifier(orderNum),order_seq:1})
    // Acknowledgement only. The resolver must obtain the matching cancelled
    // order through GET before asking PortOne to refund customer money.
    if(result.success!==true)throw new RedprintingError('vendor_cancel_not_confirmed',409)
  }
}

import assert from 'node:assert/strict';
import {test} from 'node:test';
import {observeWebPointPayment, readPointBody, WebPointError} from '../../supabase/functions/_shared/web-point-topup-provider.ts';
const expected={paymentId:'SFPTT_11111111-1111-4111-8111-111111111111',storeId:'store-example-12345',channelKey:'channel-key-example-12345',totalAmount:2200,currency:'KRW',environment:'test'};
const secret='offline-provider-secret';
const paid=()=>({id:expected.paymentId,storeId:expected.storeId,version:'V2',status:'PAID',transactionId:'transaction-1',currency:'KRW',channel:{key:expected.channelKey,type:'TEST'},amount:{total:2200,paid:2200,discount:0,cancelled:0},paidAt:'2026-10-29T00:00:00Z',cancellations:[]});
const response=payload=>async()=>Response.json(payload);
const observe=(payload,patch={})=>observeWebPointPayment({...expected,...patch},secret,response(payload));
const reject=promise=>assert.rejects(promise,error=>error instanceof WebPointError);

test('paid observation is an exact secure GET to the stored provider identity',async()=>{
 let called=false;
 const result=await observeWebPointPayment(expected,secret,async(url,options)=>{
  called=true;assert.equal(url.origin,'https://api.portone.io');assert.equal(url.pathname,'/payments/'+expected.paymentId);assert.equal(url.searchParams.get('storeId'),expected.storeId);assert.equal(options.method,'GET');assert.equal(options.redirect,'error');assert.ok(options.signal);assert.equal(options.headers.Authorization,'PortOne '+secret);assert.ok(!url.toString().includes(secret));return Response.json(paid());
 });
 assert.ok(called);assert.equal(result.state,'paid');assert.equal(result.paidAmount,2200);assert.equal(result.paymentId,expected.paymentId);
});

test('unsettled states and a missing payment are never evidence of no charge',async()=>{
 for(const status of ['READY','PENDING','VIRTUAL_ACCOUNT_ISSUED','PAY_PENDING','UNKNOWN'])assert.equal(await observe({...paid(),status,channel:null,amount:null}),null);
 await assert.rejects(observeWebPointPayment(expected,secret,async()=>new Response('{}',{status:404})),error=>error.code==='web_point_payment_not_found'&&error.status===503);
});

test('paid identity, route, environment, amount and currency mismatches cannot grant',async()=>{
 const patches=[{id:'another-payment'},{storeId:'another-store'},{version:'V1'},{channel:{key:'different-channel',type:'TEST'}},{channel:{key:expected.channelKey,type:'LIVE'}},{currency:'USD'},{amount:{total:2201,paid:2201,discount:0,cancelled:0}},{amount:{total:2200,paid:2000,discount:0,cancelled:0}},{transactionId:''},{transactionId:'invalid/token'}];
 for(const patch of patches)await reject(observe({...paid(),...patch}));
});

test('LIVE observation requires its actual stored LIVE channel and cannot accept TEST evidence',async()=>{
 const live={...expected,paymentId:expected.paymentId.replace('SFPTT_','SFPTL_'),environment:'live',channelKey:'channel-key-live-12345'};
 const payload={...paid(),id:live.paymentId,channel:{key:live.channelKey,type:'LIVE'}};
 const result=await observeWebPointPayment(live,secret,response(payload));assert.equal(result.isTest,false);assert.equal(result.state,'paid');
 await reject(observeWebPointPayment(live,secret,response({...payload,channel:{key:live.channelKey,type:'TEST'}})));
});

test('provider discounts must exactly account for the prepared total',async()=>{
 const result=await observe({...paid(),amount:{total:2200,paid:1800,discount:400,cancelled:0}});assert.equal(result.state,'paid');assert.equal(result.discountAmount,400);
 for(const amount of [{total:2200,paid:1800,discount:399,cancelled:0},{total:2200,paid:0,discount:2200,cancelled:0},{total:2200,paid:2200,discount:0,cancelled:-1},{total:2200,paid:'2200',discount:0,cancelled:0}])await reject(observe({...paid(),amount}));
});

test('paid cancellation hints and partial cancellations go to review rather than a second credit',async()=>{
 assert.equal((await observe({...paid(),cancellations:[{id:'pending'}]})).state,'review');
 assert.equal((await observe({...paid(),status:'PARTIAL_CANCELLED',amount:{total:2200,paid:2200,discount:0,cancelled:500}})).state,'review');
 assert.equal((await observe({...paid(),paidAt:'invalid'})).state,'review');
});

const cancelled=()=>({...paid(),status:'CANCELLED',cancelledAt:'2026-10-29T00:01:00Z',amount:{total:2200,paid:2200,discount:0,cancelled:2200},cancellations:[{id:'cancellation-1',status:'SUCCEEDED',totalAmount:2200}]});
test('a full refund requires exact completed cancellation evidence',async()=>{
 const result=await observe(cancelled());assert.equal(result.state,'cancelled');assert.equal(result.fullCancellationVerified,true);
 const patches=[{cancellations:[]},{cancelledAt:'unknown'},{cancellations:[{id:'x',status:'PENDING',totalAmount:2200}]},{cancellations:[{id:'x',status:'SUCCEEDED',totalAmount:1100}]},{cancellations:[{id:'x',status:'SUCCEEDED',totalAmount:1100},{id:'x',status:'SUCCEEDED',totalAmount:1100}]}];
 for(const patch of patches)assert.equal((await observe({...cancelled(),...patch})).state,'review');
});

test('failed charges cannot hide a paid or cancelled amount',async()=>{
 const failed={...paid(),status:'FAILED',amount:{total:2200,paid:0,discount:0,cancelled:0}};assert.equal((await observe(failed)).state,'failed');
 await reject(observe({...failed,amount:{total:2200,paid:1,discount:0,cancelled:0}}));
 await reject(observe({...failed,amount:{total:2200,paid:0,discount:0,cancelled:1}}));
});

test('unexpected provider bodies and transport failures produce safe retryable errors',async()=>{
 for(const fetcher of [async()=>new Response('secret-provider-body',{status:500}),async()=>{throw new Error(secret);},async()=>new Response('{', {headers:{'content-type':'application/json'}}),async()=>Response.json({padding:'x'.repeat(262145)})]){
  await assert.rejects(observeWebPointPayment(expected,secret,fetcher),error=>error instanceof WebPointError&&error.status>=500&&!error.message.includes(secret)&&!error.message.includes('secret-provider-body'));
 }
});

test('stream byte limits and malformed UTF-8 fail without retaining or logging the body',async()=>{
 await assert.rejects(readPointBody(new Request('https://offline.test',{method:'POST',body:'가'.repeat(4)}),10),error=>error.code==='web_point_payload_invalid');
 await assert.rejects(readPointBody(new Request('https://offline.test',{method:'POST',body:new Uint8Array([255])}),100),error=>error.code==='web_point_payload_invalid');
 assert.equal(await readPointBody(new Request('https://offline.test',{method:'POST',body:'가나'}),6),'가나');
});

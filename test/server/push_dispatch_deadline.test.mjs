import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import vm from 'node:vm';
import {createPrintSchedulerRequestFetch} from '../../supabase/functions/_shared/print-order-scheduler.ts';

test('push entrypoint gives each request a bounded, independently abortable database fetch',async()=>{
 const source=readFileSync(new URL('../../supabase/functions/push-dispatch/index.ts',import.meta.url),'utf8').replace(/^import .*$/gm,'');
 let handler;const calls=[],budgets=[];
 const fetch=async(input,init)=>{calls.push({input,signal:init.signal});return new Response('{}');};
 vm.runInNewContext(source,{
  fetch,
  Deno:{env:{get:()=>undefined},serve:value=>{handler=value;}},
  createPrintSchedulerRequestFetch:(fetcher,budget,signal)=>{
   budgets.push({budget,signal});return createPrintSchedulerRequestFetch(fetcher,budget,signal);
  },
  adminClient:options=>({probe:()=>options.fetch('https://offline.invalid/database')}),
  createPushDispatchHandler:dependencies=>async()=>dependencies.adminClient().probe(),
 });
 const first=new AbortController();first.abort('obsolete push request');
 await assert.rejects(()=>handler(new Request('https://offline.invalid/push',{signal:first.signal})),error=>error==='obsolete push request');
 assert.equal(calls.length,0);
 const second=new AbortController();await handler(new Request('https://offline.invalid/push',{signal:second.signal}));
 assert.equal(calls.length,1);assert.equal(calls[0].signal.aborted,false);
 assert.equal(budgets.length,2);assert.ok(budgets.every(value=>value.budget===55_000));
 second.abort('new request stopped');assert.equal(calls[0].signal.aborted,true);
 assert.equal(calls[0].signal.reason,'new request stopped');
});

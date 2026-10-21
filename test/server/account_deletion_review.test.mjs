import assert from 'node:assert/strict'
import {test} from 'node:test'
import {readFileSync} from 'node:fs'
import {createAccountDeletionReviewHandler} from '../../supabase/functions/_shared/account-deletion-review.ts'

const owner='11111111-1111-4111-8111-111111111111'
const request=(body={action:'REQUEST_REVIEW'},authorization='Bearer synthetic',method='POST')=>new Request('https://edge.invalid/account-delete',{
 method,headers:authorization?{Authorization:authorization}:{},...(method==='POST'?{body:JSON.stringify(body)}:{})})
function fixture({existing=null,lookupError=null,insertError=null,userError=null}={}){const calls=[]
 const handler=createAccountDeletionReviewHandler({
  getUser:async()=>{calls.push('user');if(userError)throw userError;return{id:owner,email:'owner@example.invalid'}},
  findOpenRequest:async actor=>{calls.push(['find',actor]);if(lookupError)throw lookupError;return existing},
  insertRequest:async(actor,email)=>{calls.push(['insert',actor,email]);if(insertError)throw insertError;return{id:12}},
 });return{handler,calls}
}
test('missing or invalid authentication never reaches privileged reads or writes',async()=>{
 const f=fixture();assert.equal((await f.handler(request(undefined,null))).status,401);assert.deepEqual(f.calls,[])
 const invalid=fixture({userError:Error('Unauthorized')});assert.equal((await invalid.handler(request())).status,401)
 assert.deepEqual(invalid.calls,['user'])
})
test('legacy deletion bodies explicitly fail and never report an account deletion',async()=>{
 for(const body of [{},null,{action:'DELETE'},{action:'REQUEST_REVIEW',user_id:'forged'},{action:'REQUEST_REVIEW',deleteFiles:true}]){
  const f=fixture(),r=await f.handler(request(body)),data=await r.json();assert.equal(r.status,409)
  assert.equal(data.requestAccepted,false);assert.equal(data.accountDeleted,false);assert.deepEqual(f.calls,['user'])
 }
})
test('review acceptance records only the authenticated owner and maintains clear non-deletion semantics',async()=>{
 const f=fixture(),r=await f.handler(request()),data=await r.json();assert.equal(r.status,202)
 assert.equal(r.headers.get('Cache-Control'),'no-store');assert.equal(data.requestAccepted,true);assert.equal(data.accountDeleted,false)
 assert.equal(data.alreadyRequested,false);assert.equal(data.reference,'DEL-12');assert.equal(data.success,undefined)
 assert.deepEqual(f.calls,['user',['find',owner],['insert',owner,'owner@example.invalid']])
})
test('repeated request returns the active reference without inserting another inquiry',async()=>{
 const f=fixture({existing:{id:5}}),r=await f.handler(request()),data=await r.json()
 assert.equal(data.alreadyRequested,true);assert.equal(data.reference,'DEL-5');assert.equal(f.calls.length,2)
})
test('a racing unique conflict returns the already accepted inquiry',async()=>{
 let searches=0,inserts=0
 const handler=createAccountDeletionReviewHandler({getUser:async()=>({id:owner}),
  findOpenRequest:async()=>++searches===1?null:{id:8},
  insertRequest:async()=>{inserts++;throw{code:'23505'}},
 })
 const data=await(await handler(request())).json();assert.equal(data.reference,'DEL-8');assert.equal(data.alreadyRequested,true)
 assert.equal(data.accountDeleted,false);assert.equal(inserts,1);assert.equal(searches,2)
})
test('database failures and invalid references never claim acceptance or expose internal details',async()=>{
 for(const options of [{lookupError:Error('private-storage-address')},{insertError:Error('private-storage-address')},{existing:{id:'invalid'}}]){
  const f=fixture(options),r=await f.handler(request()),data=await r.json();assert.equal(r.status,503)
  assert.equal(data.requestAccepted,false);assert.equal(data.accountDeleted,false)
  assert.equal(JSON.stringify(data).includes('private-storage-address'),false)
 }
})
test('preflight and read methods do not read users or generate inquiries',async()=>{
 const f=fixture();assert.equal((await f.handler(request(undefined,null,'OPTIONS'))).status,200)
 assert.equal((await f.handler(request(undefined,null,'GET'))).status,405);assert.deepEqual(f.calls,[])
})
test('deployed adapter has no auth deletion, profile deletion, signout, Storage removal or email transport',()=>{
 const code=readFileSync(new URL('../../supabase/functions/account-delete/index.ts',import.meta.url),'utf8')
 assert.doesNotMatch(code,/deleteUser|\.delete\(|signOut|\.storage|sendMail|sendEmail|fetch\(/)
 assert.match(code,/category: 'ACCOUNT_DELETION'/)
})

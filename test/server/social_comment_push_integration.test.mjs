import assert from 'node:assert/strict';
import {test} from 'node:test';
import {fixture,login,api,publish,save,operator,report,resolve,a,b,id}from './helpers/social_safety_fixture.mjs';

async function device(db){
 await login(db);await db.query("select public.register_push_device('integration-alice-device-token','android',540,true)");
}
async function rows(db,table){await db.exec('reset role');return(await db.query(`select *from public.${table}`)).rows;}
async function claim(db){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.role','service_role',false)");return(await db.query('select *from public.claim_push_deliveries(25)')).rows[0];}
async function prepare(db,row){await db.exec('reset role');return(await db.query('select public.prepare_push_delivery($1,$2)r',[row.id,row.lease_token])).rows[0].r.allowed;}

test('real social RPC creates one owner-targeted comment notification and withdraw cancels delivery',async()=>{const db=await fixture({withPush:true});try{
 await device(db);const work=await publish(db);await login(db,b);
 const payload={id:work.id,body:'Only the work UI may display this comment',requestId:id(801)};
 const comment=await api(db,'addComment',payload);assert.deepEqual(await api(db,'addComment',payload),comment);
 const notifications=await rows(db,'notifications'),outbox=await rows(db,'push_outbox');
 assert.equal(notifications.length,1);assert.equal(outbox.length,1);
 assert.equal(notifications[0].user_id,a);assert.equal(outbox[0].user_id,a);
 assert.equal(notifications[0].event_key,`social:comment:${comment.id}`);
 assert.deepEqual(notifications[0].data,{workId:work.id,commentId:comment.id,showComments:true});
 assert.ok(!JSON.stringify(notifications).includes(payload.body));
 const delivery=await claim(db);assert.equal(await prepare(db,delivery),true);
 await login(db);await save(db,{revision:1,caption:'Editing revokes the public snapshot'});
 assert.equal(await prepare(db,delivery),false);
 assert.equal((await rows(db,'push_outbox'))[0].status,'discarded');
 assert.equal((await rows(db,'notifications')).length,1);
 await login(db,b);assert.equal(await api(db,'work',{id:work.id}),null);
}finally{await db.close();}});

test('real owner/self comment never notifies and moderation cancels an already queued comment',async()=>{const db=await fixture({withPush:true});try{
 await device(db);const work=await publish(db);
 await api(db,'addComment',{id:work.id,body:'My own note',requestId:id(811)});
 assert.equal((await rows(db,'notifications')).length,0);
 await login(db,b);await api(db,'addComment',{id:work.id,body:'Public response',requestId:id(812)});
 const delivery=await claim(db);await login(db,b);const issue=await report(db,work.id);
 await operator(db);await resolve(db,issue);
 assert.equal(await prepare(db,delivery),false);
 const unavailable=(await rows(db,'push_outbox'))[0];assert.equal(unavailable.last_error,'social_comment_unavailable');
 await login(db,b);await assert.rejects(()=>api(db,'addComment',{id:work.id,body:'Cannot comment on the hidden work',requestId:id(813)}),/social_work_unavailable/);
 assert.equal((await rows(db,'notifications')).length,1);
}finally{await db.close();}});

test('real category opt-out keeps the inbox record and never creates a push backlog',async()=>{const db=await fixture({withPush:true});try{
 await device(db);await db.query('insert into public.push_preferences(user_id,comment_enabled)values($1,false)',[a]);
 const work=await publish(db);await login(db,b);await api(db,'addComment',{id:work.id,body:'An inbox-only comment',requestId:id(821)});
 assert.equal((await rows(db,'notifications')).length,1);assert.equal((await rows(db,'push_outbox')).length,0);
 await db.query('update public.push_preferences set comment_enabled=true where user_id=$1',[a]);
 assert.equal((await rows(db,'push_outbox')).length,0);
}finally{await db.close();}});

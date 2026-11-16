import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {fixture,login,api,publish,entry,a,b,c,d,id} from './helpers/social_safety_fixture.mjs';

const migration=readFileSync(new URL('../../supabase/migrations/20261103123536_social_threaded_comments_and_mentions.sql',import.meta.url),'utf8');
async function setup(){
 const db=await fixture({withPush:true});
 await db.exec('reset role');await db.exec(migration);
 for(const [user,handle]of[[a,'alice'],[b,'bob'],[c,'carol'],[d,'dana']]){
  await db.exec('reset role');
  await db.query('insert into auth.users(id)values($1)on conflict do nothing',[user]);
  await login(db,user);await api(db,'upsertProfile',{displayName:handle,handle,bio:''});
 }
 await login(db);return db;
}
const add=(db,work,n,body,patch={})=>api(db,'addComment',{id:work.id,requestId:id(n),body,...patch});
async function raw(db,query,params=[]){await db.exec('reset role');return(await db.query(query,params)).rows;}

test('replies retain root and parent context across flat pages, deletion and safe retries',async()=>{
 const db=await setup();try{
  const work=await publish(db);await login(db,b);const root=await add(db,work,1501,'Root');
  await login(db,c);const reply=await add(db,work,1502,'Reply',{parentCommentId:root.id});
  await login(db,d);const nested=await add(db,work,1503,'Nested',{parentCommentId:reply.id});
  assert.equal(root.rootCommentId,null);assert.deepEqual(root.mentions,[]);
  assert.equal(reply.rootCommentId,root.id);assert.equal(reply.parentAuthor.userId,b);
  assert.equal(nested.parentCommentId,reply.id);assert.equal(nested.rootCommentId,root.id);assert.equal(nested.parentAuthor.userId,c);
  assert.deepEqual(await add(db,work,1503,'Nested',{parentCommentId:reply.id}),nested);
  await assert.rejects(()=>add(db,work,1503,'Nested',{parentCommentId:root.id}),/social_comment_request_mismatch/);
  const page=await api(db,'commentsPage',{id:work.id,limit:1});
  assert.equal(page.items[0].id,nested.id);assert.equal(page.items[0].parentAuthor.userId,c);
  assert.equal(page.nextOffset,1);assert.equal(page.hasMore,true);
  const next=await api(db,'commentsPage',{id:work.id,limit:1,offset:page.nextOffset});assert.equal(next.items[0].id,reply.id);
  assert.deepEqual((await api(db,'comments',{id:work.id})).map(x=>x.id),[root.id,reply.id,nested.id]);
  await login(db,c);await api(db,'deleteComment',{id:reply.id});
  await login(db,d);const retry=await add(db,work,1503,'Nested',{parentCommentId:reply.id});
  assert.equal(retry.parentCommentId,reply.id);assert.equal(retry.parentAuthor,null);assert.equal(retry.rootCommentId,root.id);
  await assert.rejects(()=>add(db,work,1504,'Gone parent',{parentCommentId:reply.id}),/social_comment_parent_unavailable/);
  await login(db,b);await api(db,'deleteComment',{id:root.id});await login(db,d);
  assert.equal((await api(db,'commentsPage',{id:work.id})).items[0].rootCommentId,root.id);
 }finally{await db.close();}
});

test('cross-work, blocked, hidden and unavailable roots cannot become reply parents',async()=>{
 const db=await setup();try{
  const work=await publish(db);const other=(await entry(db,9,'2026-10-29')).work;
  await login(db,b);const root=await add(db,work,1511,'Root');
  await login(db,c);
  await assert.rejects(()=>add(db,other,1512,'Cross-work',{parentCommentId:root.id}),/social_comment_parent_unavailable/);
  await assert.rejects(()=>add(db,work,1512,'Malformed parent',{parentCommentId:'invalid'}),/social_comment_parent_unavailable/);
  await assert.rejects(()=>add(db,work,1512,'Malformed parent',{parentCommentId:[]}),/social_invalid_comment_request_id/);
  await api(db,'setBlocked',{userId:b,blocked:true});
  await assert.rejects(()=>add(db,work,1512,'Blocked parent',{parentCommentId:root.id}),/social_comment_parent_unavailable/);
  await api(db,'setBlocked',{userId:b,blocked:false});
  const child=await add(db,work,1513,'Child',{parentCommentId:root.id});
  await raw(db,'update public.social_comments set moderation_hidden=true where id=$1',[root.id]);
  await login(db,d);await assert.rejects(()=>add(db,work,1514,'Hidden root',{parentCommentId:child.id}),/social_comment_parent_unavailable/);
  const visible=await api(db,'commentsPage',{id:work.id});assert.equal(visible.items.length,1);assert.equal(visible.items[0].parentAuthor,null);
  await assert.rejects(()=>db.query('select *from social_private.comment_mentions'),/permission denied/);
  await assert.rejects(()=>db.query('select social_private.comment_json($1)',[child.id]),/permission denied/);
 }finally{await db.close();}
});

test('mentions are derived only from bounded body handles, skip inaccessible people and retain original handles',async()=>{
 const db=await setup();try{
  const work=await publish(db);await login(db,b);
  const first=await add(db,work,1521,'Hi @CAROL, @carol and @dana! mail@alice.test @unknown',{mentionUserIds:[a]});
  assert.deepEqual(first.mentions.map(x=>x.userId),[c,d]);assert.deepEqual(first.mentions.map(x=>x.handle),['carol','dana']);
  assert.equal((await raw(db,"select count(*)::int n from social_private.comment_mentions where comment_id=$1",[first.id]))[0].n,2);
  await login(db,c);await api(db,'upsertProfile',{displayName:'Carol',handle:'new.carol',bio:''});
  await login(db,b);const retry=await add(db,work,1521,first.body);assert.deepEqual(retry.mentions.map(x=>x.handle),['carol','dana']);
  await api(db,'setBlocked',{userId:d,blocked:true});
  const blocked=await add(db,work,1522,'@dana @new.carol');assert.deepEqual(blocked.mentions.map(x=>x.userId),[c]);
  await login(db);await api(db,'setBlocked',{userId:c,blocked:true});
  await login(db,b);const ownerBlocked=await add(db,work,1523,'@new.carol');assert.deepEqual(ownerBlocked.mentions,[]);
  await assert.rejects(()=>add(db,work,1524,'@aaa @bbb @ccc @ddd @eee @fff'),/social_comment_mentions_limit/);
  await assert.rejects(()=>add(db,work,1525,' '),/social_invalid_comment_body/);
  await assert.rejects(()=>add(db,work,1525,'x'.repeat(501)),/social_invalid_comment_body/);
  assert.equal((await api(db,'commentsPage',{id:work.id})).items.length,3);
 }finally{await db.close();}
});

test('reply and mention notifications target authoritative recipients once and recheck access before push',async()=>{
 const db=await setup();try{
  for(const user of[a,b,c]){await login(db,user);await db.query('select public.register_push_device($1,\'android\',540,true)',['thread-device-token-'+user]);}
  await login(db);const work=await publish(db);await login(db,b);const root=await add(db,work,1531,'Root');
  await login(db,d);const reply=await add(db,work,1532,'@bob @carol @dana',{parentCommentId:root.id,mentionUserIds:[id(999)]});
  const notifications=await raw(db,"select *from public.notifications where data->>'commentId'=$1 order by user_id",[reply.id]);
  assert.deepEqual(notifications.map(x=>x.user_id),[a,b,c]);
  assert.equal(notifications.find(x=>x.user_id===b).data.commentContext,'reply');
  assert.equal(notifications.find(x=>x.user_id===c).data.commentContext,'mention');
  assert.ok(!JSON.stringify(notifications).includes('@carol'));
  await login(db,d);await add(db,work,1532,reply.body,{parentCommentId:root.id});
  assert.equal((await raw(db,"select *from public.notifications where data->>'commentId'=$1",[reply.id])).length,3);
  const allowed=async user=>(await raw(db,'select private.social_comment_push_allowed($1)ok',[notifications.find(x=>x.user_id===user).id]))[0].ok;
  assert.equal(await allowed(b),true);assert.equal(await allowed(c),true);
  await login(db,d);const replyOnly=await add(db,work,1533,'Reply without a mention',{parentCommentId:root.id});
  const replyOnlyNotification=(await raw(db,"select *from public.notifications where user_id=$1 and data->>'commentId'=$2",[b,replyOnly.id]))[0];
  await login(db,c);await api(db,'setBlocked',{userId:d,blocked:true});assert.equal(await allowed(c),false);
  await login(db,b);await api(db,'deleteComment',{id:root.id});
  assert.equal((await raw(db,'select private.social_comment_push_allowed($1)ok',[replyOnlyNotification.id]))[0].ok,false);
  // Bob is still an explicit @mention after deleting the replied-to comment.
  assert.equal(await allowed(b),true);
  await raw(db,'update public.social_works set status=\'private\'where id=$1',[work.id]);
  assert.equal(await allowed(a),false);assert.equal(await allowed(b),false);
 }finally{await db.close();}
});

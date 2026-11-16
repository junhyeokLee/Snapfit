import assert from 'node:assert/strict';
import {test} from 'node:test';
import {fixture,login,api,save,begin,state,upload,publish,visibility,entry,months,month,operator,report,resolve,policy,a,b,c,d,id,rid,pid,otherPid,photo,second}from './helpers/social_safety_fixture.mjs';

test('reports are owner-only, request-idempotent and unique per actor and public target',async()=>{const db=await fixture();try{
 const work=await publish(db);await login(db,b);const first=await report(db,work.id);
 assert.equal(first.status,'open');assert.equal(first.resolutionNote,null);assert.equal(first.resolvedAt,null);assert.equal(first.targetWorkId,work.id);assert.equal(first.targetPreview,null);
 assert.deepEqual(await report(db,work.id),first);assert.equal((await report(db,work.id,{requestId:id(901),reason:'spam'})).id,first.id);
 await assert.rejects(()=>report(db,work.id,{details:'different'}),/social_report_request_mismatch/);
 assert.equal((await api(db,'ownReportsPage')).items.length,1);
 await assert.rejects(()=>api(db,'adminReportsPage'),/social_admin_required/);
 await assert.rejects(()=>db.query('select * from social_private.content_reports'),/permission denied/);
 await assert.rejects(()=>db.query('select * from social_private.rate_windows'),/permission denied/);
 await login(db);assert.equal((await api(db,'ownReportsPage')).items.length,0);assert.equal((await api(db,'feed')).items.length,1);
 await assert.rejects(()=>report(db,work.id,{details:'x'.repeat(501)}),/social_invalid_report/);
 await assert.rejects(()=>report(db,work.id,{targetId:id(999)}),/social_report_target_unavailable/);
}finally{await db.close();}});

test('only authoritative active app metadata grants moderation; dismissal is CAS checked and notes stay internal',async()=>{const db=await fixture();try{
 const work=await publish(db);await login(db,b);const row=await report(db,work.id);
 await db.exec('reset role');await db.query("update auth.users set raw_user_meta_data='{\"role\":\"admin\"}'where id=$1",[b]);await login(db,b);
 await db.query("select set_config('request.jwt.claims','{\"app_metadata\":{\"role\":\"admin\"}}',false)");
 await assert.rejects(()=>api(db,'adminReportsPage'),/social_admin_required/);
 await operator(db);assert.equal((await api(db,'adminReportsPage')).items.length,1);assert.equal((await api(db,'adminReportsPage')).items[0].targetPreview.caption,'오늘의 한 문장');
 const dismissed=await resolve(db,row,{decision:'dismiss'});assert.equal(dismissed.status,'dismissed');assert.equal(dismissed.resolutionNote,'Operator review');assert.ok(dismissed.resolvedAt);
 assert.deepEqual(await resolve(db,row,{decision:'dismiss'}),dismissed);
 await assert.rejects(()=>resolve(db,row),/social_report_changed/);
 await login(db,b);const own=(await api(db,'ownReportsPage')).items[0];assert.equal(own.resolutionNote,null);assert.equal(own.reporterId,undefined);assert.equal((await api(db,'feed')).items.length,1);
 await db.exec('reset role');await db.query('update auth.users set banned_until=now()+interval\'1 day\'where id=$1',[c]);await login(db,c);await assert.rejects(()=>api(db,'adminReportsPage'),/MOMENTS_ACCOUNT_REQUIRED/);
}finally{await db.close();}});

test('explicit work moderation fences publication and blocks a new UUID for the same private source',async()=>{const db=await fixture();try{
 const first=await publish(db);const second=await publish(db,{requestId:id(11),photoId:otherPid});
 await login(db,b);const row=await report(db,second.id);await operator(db);const hidden=await resolve(db,row);assert.equal(hidden.status,'hidden');
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items.length,0);assert.equal((await months(db)).items.length,0);assert.equal(await api(db,'work',{id:second.id}),null);
 await login(db);await assert.rejects(()=>begin(db,{requestId:id(12)}),/social_publication_restricted/);
 await assert.rejects(()=>visibility(db,second,true,2),/social_publication_restricted/);
 assert.equal((await api(db,'work',{id:first.id})).status,'private');
 assert.equal((await save(db,{caption:'Private edits still work',revision:1})).revision,2);
 const editable=await api(db,'ownMomentRecord',{workId:second.id});assert.equal(editable.id,rid);assert.equal(editable.caption,'Private edits still work');
 await db.exec('reset role');assert.equal((await db.query('select social_private.work_restricted($1)r',[first.id])).rows[0].r,true);
}finally{await db.close();}});

test('comment and user reports hide only after an operator decision and raw comment reads follow moderation',async()=>{const db=await fixture();try{
 const work=await publish(db);await login(db,b);const comment=await api(db,'addComment',{id:work.id,body:'Reported comment',requestId:id(901)});
 await login(db);const row=await report(db,comment.id,{targetKind:'comment',reason:'harassment'});assert.equal((await api(db,'commentsPage',{id:work.id})).items.length,1);
 await operator(db);await resolve(db,row);await login(db);assert.equal((await api(db,'commentsPage',{id:work.id})).items.length,0);
 assert.equal((await db.query('select * from public.social_comments where id=$1',[comment.id])).rows.length,0);
 await assert.rejects(()=>api(db,'commentsPage',{id:id(999),offset:-1}),/social_invalid_page_offset/);
 const userReport=await report(db,b,{targetKind:'user',requestId:id(902),reason:'spam'});await operator(db);await resolve(db,userReport);
 await login(db);assert.equal(await api(db,'profile',{userId:b}),null);
 await login(db,b);await assert.rejects(()=>api(db,'addComment',{id:work.id,body:'New public comment',requestId:id(903)}),/social_publication_restricted/);
}finally{await db.close();}});

test('comment rate limits charge new writes, never an idempotent retry, and roll back rejected attempts',async()=>{const db=await fixture();try{
 const work=await publish(db);await policy(db,'comment_per_minute=1');await login(db,b);
 const one=await api(db,'addComment',{id:work.id,body:'One',requestId:id(901)});assert.deepEqual(await api(db,'addComment',{id:work.id,body:'One',requestId:id(901)}),one);
 await assert.rejects(()=>api(db,'addComment',{id:work.id,body:'Two',requestId:id(902)}),/social_rate_limited/);
 assert.equal((await api(db,'commentsPage',{id:work.id})).items.length,1);
 await db.exec('reset role');assert.equal((await db.query("select request_count from social_private.rate_windows where actor_id=$1 and action='comment'and window_seconds=60",[b])).rows[0].request_count,1);
}finally{await db.close();}});

test('publication and follow limits preserve same-request and same-state retries',async()=>{const db=await fixture();try{
 await policy(db,'publication_per_hour=1,follow_per_minute=1');const draft=await begin(db);assert.deepEqual(await begin(db),draft);await upload(db,draft);const work=await api(db,'finalizePublication',{id:draft.id});
 await assert.rejects(()=>api(db,'beginPublication',{albumId:10,pageIndexes:[0],title:'Separate album request',requestId:id(10)}),/social_rate_limited/);
 await visibility(db,work,true,1);await visibility(db,work,false,1);await assert.rejects(()=>visibility(db,work,true,2),/social_rate_limited/);assert.equal((await state(db)).status,'private');
 await assert.rejects(()=>begin(db,{requestId:id(11)}),/social_rate_limited/);
 await login(db,b);await api(db,'ensureProfile');await login(db);assert.equal(await api(db,'setFollowing',{userId:b,following:true}),true);assert.equal(await api(db,'setFollowing',{userId:b,following:true}),true);
 await assert.rejects(()=>api(db,'setFollowing',{userId:b,following:false}),/social_rate_limited/);
 assert.equal((await api(db,'profile',{userId:b})).isFollowing,true);
}finally{await db.close();}});

test('active public page and byte budgets are checked before finalizing, preserving the private saved record',async()=>{const db=await fixture();try{
 const first=await publish(db);const pending=await entry(db,1,'2026-10-20',{status:'draft'});await upload(db,pending.work);await policy(db,'max_active_snapshot_pages=1,max_active_snapshot_bytes=2048');
 await assert.rejects(()=>api(db,'finalizePublication',{id:pending.work.id}),/social_public_snapshot_quota_exceeded/);
 assert.equal((await api(db,'momentPublication',{recordId:pending.recordId})).status,'draft');assert.equal((await api(db,'ownMomentRecord',{workId:pending.work.id})).id,pending.recordId);
 await visibility(db,first,false,1);await policy(db,'max_active_snapshot_bytes=1023');await assert.rejects(()=>api(db,'finalizePublication',{id:pending.work.id}),/social_public_snapshot_quota_exceeded/);
 await policy(db,'max_active_snapshot_bytes=1024');const completed=await api(db,'finalizePublication',{id:pending.work.id});assert.equal(completed.status,'published');assert.equal((await api(db,'finalizePublication',{id:completed.id})).id,completed.id);
}finally{await db.close();}});

test('month and record cursors do not skip after the previous anchor is withdrawn',async()=>{const db=await fixture();try{
 const low=await entry(db,1,'2026-10-01'),middle=await entry(db,2,'2026-10-02'),high=await entry(db,3,'2026-10-03');
 let page=await month(db,{limit:1});assert.equal(page.items[0].id,high.work.id);assert.deepEqual(page.nextCursor,{recordDate:'2026-10-03',id:high.work.id});
 await visibility(db,high.work,false,1);page=await month(db,{limit:1,cursor:page.nextCursor});assert.equal(page.items[0].id,middle.work.id);page=await month(db,{limit:1,cursor:page.nextCursor});assert.equal(page.items[0].id,low.work.id);assert.equal(page.nextCursor,null);
 const september=await entry(db,4,'2026-09-15');await entry(db,5,'2026-08-15');let books=await months(db,{limit:1});assert.deepEqual(books.nextCursor,{month:'2026-10-01'});
 await visibility(db,middle.work,false,1);await visibility(db,low.work,false,1);books=await months(db,{limit:1,cursor:books.nextCursor});assert.equal(books.items[0].cover.id,september.work.id);
 await assert.rejects(()=>months(db,{offset:1,cursor:books.nextCursor}),/social_invalid_cursor/);
}finally{await db.close();}});

test('owner cover choices require a current public record and automatically fall back on withdrawal',async()=>{const db=await fixture();try{
 const old=await entry(db,1,'2026-10-01'),latest=await entry(db,2,'2026-10-20');
 await api(db,'setMomentMonthCover',{month:'2026-10-01',workId:old.work.id});let books=await months(db);assert.equal(books.items[0].cover.id,old.work.id);assert.equal(books.items[0].selectedWorkId,old.work.id);
 await login(db,null,'anon');books=await months(db);assert.equal(books.items[0].cover.id,old.work.id);assert.equal(books.items[0].selectedWorkId,null);
 await login(db,b);await assert.rejects(()=>api(db,'setMomentMonthCover',{month:'2026-10-01',workId:old.work.id}),/social_invalid_month_cover/);
 await login(db);await assert.rejects(()=>api(db,'setMomentMonthCover',{month:'2026-09-01',workId:old.work.id}),/social_invalid_month_cover/);
 await visibility(db,old.work,false,1);books=await months(db);assert.equal(books.items[0].cover.id,latest.work.id);assert.equal(books.items[0].selectedWorkId,null);
 await api(db,'setMomentMonthCover',{month:'2026-10-01',workId:latest.work.id});await api(db,'setMomentMonthCover',{month:'2026-10-01',workId:null});assert.equal((await months(db)).items[0].selectedWorkId,null);
 await assert.rejects(()=>db.query('select * from moments_private.public_month_covers'),/permission denied/);
}finally{await db.close();}});

test('own work-to-record lookup stays private, current and unavailable after deletion',async()=>{const db=await fixture();try{
 const work=await publish(db);await save(db,{caption:'Current private revision',revision:1});let record=await api(db,'ownMomentRecord',{workId:work.id});assert.equal(record.id,rid);assert.equal(record.revision,2);
 await login(db,b);assert.equal(await api(db,'ownMomentRecord',{workId:work.id}),null);await login(db);await db.query('select public.delete_weekly_moment($1,2)',[rid]);assert.equal(await api(db,'ownMomentRecord',{workId:work.id}),null);
 await assert.rejects(()=>db.query("select social_private.social_api_safety_v1('feed','{}')"),/permission denied/);
}finally{await db.close();}});

test('several reports never automatically hide a public post',async()=>{const db=await fixture();try{
 const work=await publish(db);await operator(db);await login(db,b);await report(db,work.id);await login(db,c);await report(db,work.id);await login(db,d);await report(db,work.id);
 await login(db,null,'anon');assert.equal((await api(db,'feed')).items[0].id,work.id);
 await operator(db);assert.equal((await api(db,'adminReportsPage')).items.length,3);
}finally{await db.close();}});


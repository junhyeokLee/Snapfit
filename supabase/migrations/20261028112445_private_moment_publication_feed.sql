-- A public record is one explicitly selected raster and its saved caption.
-- Private journal rows, original photo paths and albums remain private.
alter table public.social_works add column kind text not null default 'album'
 check(kind in ('album','moment'));
alter table public.social_works add column record_date date;
alter table public.social_works add constraint social_work_record_date_kind
 check((kind='album' and record_date is null) or(kind='moment' and record_date is not null));
create index social_moment_feed_idx on public.social_works(published_at desc,id desc)
 where kind='moment' and status='published';
create index social_moment_author_idx on public.social_works(author_id,published_at desc,id desc)
 where kind='moment' and status='published';

create table moments_private.publications(
 record_id uuid primary key references moments_private.weekly_moments(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 revision integer not null default 0 check(revision>=0),
 current_work_id uuid unique references public.social_works(id) on delete set null
);
create table social_private.moment_publication_sources(
 work_id uuid primary key references public.social_works(id) on delete cascade,
 record_id uuid not null references moments_private.weekly_moments(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 photo_id uuid not null,
 source_revision integer not null check(source_revision>0),
 publication_revision integer not null check(publication_revision>0),
 request_id uuid not null,
 request_fingerprint jsonb not null,
 unique(owner_id,request_id)
);
create index moment_publication_record_idx on social_private.moment_publication_sources(record_id);
create index moment_publications_owner_idx on moments_private.publications(owner_id,record_id);
alter table moments_private.publications enable row level security;
alter table social_private.moment_publication_sources enable row level security;
-- RPC-only ledgers: intentionally no direct policies or table grants.
revoke all on moments_private.publications,social_private.moment_publication_sources from public,anon,authenticated,service_role;

create function social_private.moment_source_current(p_work uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from social_private.moment_publication_sources b
  join moments_private.publications s on s.record_id=b.record_id and s.owner_id=b.owner_id
  join moments_private.weekly_moments m on m.id=b.record_id and m.owner_id=b.owner_id
  join public.social_works w on w.id=b.work_id and w.author_id=b.owner_id and w.kind='moment'
  where b.work_id=p_work and s.current_work_id=b.work_id and s.revision=b.publication_revision
   and m.deleted_at is null and m.revision=b.source_revision
   and exists(select 1 from jsonb_array_elements(m.photos)p where (p->>'id')::uuid=b.photo_id))
$$;
revoke all on function social_private.moment_source_current(uuid) from public,anon,authenticated,service_role;

create or replace function social_private.social_visible(p_work uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_works w where w.id=p_work
  and ((w.author_id=auth.uid() and w.status<>'deleted') or
   (w.status='published' and(w.kind='album' or social_private.moment_source_current(w.id))))
  and not social_private.social_blocked(w.author_id))
$$;

create or replace function social_private.social_snapshot_access(p_path text,p_upload boolean) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_work_pages p join public.social_works w on w.id=p.work_id
  where p.storage_path=p_path and case when p_upload then w.author_id=auth.uid() and w.status='draft'
   and(w.kind='album' or social_private.moment_source_current(w.id))
   else social_private.social_visible(w.id) end)
$$;

create function moments_private.revoke_record_publications() returns trigger
language plpgsql security definer set search_path='' as $$
declare remove_all boolean:=tg_op='DELETE';
begin
 if tg_op='UPDATE' and new.revision=old.revision and new.record_date=old.record_date
  and new.caption=old.caption and new.photos=old.photos and new.deleted_at is not distinct from old.deleted_at then
  return new;
 end if;
 if not remove_all then remove_all:=new.deleted_at is not null; end if;
 update moments_private.publications set revision=revision+1,current_work_id=null where record_id=old.id;
 -- An edit preserves a private historical copy. A deletion also tombstones
 -- previously private versions, so even their owner cannot reopen old photos.
 update public.social_works w set status=case when remove_all or w.status='draft' then 'deleted' else 'private' end
  where w.id in(select b.work_id from social_private.moment_publication_sources b where b.record_id=old.id)
   and w.status<>'deleted' and(remove_all or w.status in('draft','published'));
 return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function moments_private.revoke_record_publications() from public,anon,authenticated,service_role;
create trigger moments_revoke_public_copy before update or delete on moments_private.weekly_moments
 for each row execute function moments_private.revoke_record_publications();

create or replace function social_private.social_profile_json(p_user uuid) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('userId',p.user_id,'displayName',p.display_name,'handle',p.handle,'bio',p.bio,
  'avatarUrl',null,'avatarPath',p.avatar_path,
  'followersCount',(select count(*) from public.social_follows f where f.following_id=p.user_id and not social_private.social_blocked(f.follower_id)),
  'followingCount',(select count(*) from public.social_follows f where f.follower_id=p.user_id and not social_private.social_blocked(f.following_id)),
  'worksCount',(select count(*) from public.social_works w where w.author_id=p.user_id and w.kind='album' and w.status='published'),
  'momentsCount',(select count(*) from public.social_works w where w.author_id=p.user_id and w.kind='moment' and w.status='published' and social_private.social_visible(w.id)),
  'isFollowing',exists(select 1 from public.social_follows f where f.follower_id=auth.uid() and f.following_id=p.user_id))
 from public.social_profiles p where p.user_id=p_user
$$;

create or replace function social_private.social_work_json(p_id uuid) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',w.id,'author',social_private.social_profile_json(w.author_id),
  'title',w.title,'caption',w.caption,'topic',w.topic,'status',w.status,'aspectRatio',w.aspect_ratio,
  'kind',w.kind,'recordDate',w.record_date,'createdAt',coalesce(w.published_at,w.created_at),
  'imagePaths',coalesce((select jsonb_agg(p.storage_path order by p.position) from public.social_work_pages p where p.work_id=w.id),'[]'::jsonb),
  'likeCount',(select count(*) from public.social_likes l where l.work_id=w.id),
  'commentCount',(select count(*) from public.social_comments c where c.work_id=w.id and not social_private.social_blocked(c.author_id)),
  'isLiked',exists(select 1 from public.social_likes l where l.work_id=w.id and l.user_id=auth.uid()),
  'isSaved',exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=auth.uid()),
  'sourceTemplate',case when w.kind='album' then social_private.work_template_source(w.id) else null end,
  'publicationRevision',case when w.kind='moment' and w.author_id=auth.uid() then
   (select s.revision from moments_private.publications s join social_private.moment_publication_sources b on b.record_id=s.record_id where b.work_id=w.id and s.current_work_id=w.id) else null end)
 from public.social_works w where w.id=p_id
$$;

-- Keep the proven album implementation behind the new dispatcher. Direct
-- callers cannot bypass the moment-only feed or publication fences.
alter function social_private.social_api(text,jsonb) rename to social_api_albums_v1;
revoke all on function social_private.social_api_albums_v1(text,jsonb) from public,anon,authenticated,service_role;

create function social_private.social_api(p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); target uuid; m moments_private.weekly_moments;
 s moments_private.publications; b social_private.moment_publication_sources; w public.social_works;
 photo jsonb; request uuid; fingerprint jsonb; v_work uuid; expected integer; want_public boolean;
 result jsonb; page_offset integer; page_limit integer; cursor_at timestamptz; cursor_id uuid;
begin
 if p_action in('feed','profileMomentsPage','profileWorks','profileWorksPage','ownWorks','ownWorksPage') then
  page_offset:=coalesce((p_payload->>'offset')::integer,0);
  page_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,
   case when p_action in('profileWorks','ownWorks') then 30 else 12 end),1),30);
  if page_offset<0 or page_offset>10000 then raise exception 'social_invalid_page_offset' using errcode='22023'; end if;
  if p_action in('profileMomentsPage','profileWorks','profileWorksPage') then target:=(p_payload->>'userId')::uuid; end if;
  if p_action in('ownWorks','ownWorksPage') and actor is null then raise exception 'social_login_required' using errcode='42501'; end if;
  if p_action in('ownWorks','ownWorksPage') and coalesce(p_payload->>'status','all') not in('all','public','private') then
   raise exception 'social_invalid_work_status_filter' using errcode='22023'; end if;
  if p_payload->'cursor' is not null and p_payload->'cursor'<>'null'::jsonb then
   if jsonb_typeof(p_payload->'cursor')<>'object' or page_offset<>0 then raise exception 'social_invalid_cursor' using errcode='22023'; end if;
   cursor_at:=(p_payload->'cursor'->>'publishedAt')::timestamptz; cursor_id:=(p_payload->'cursor'->>'id')::uuid;
   if cursor_at is null or cursor_id is null then raise exception 'social_invalid_cursor' using errcode='22023'; end if;
  end if;
  select coalesce(jsonb_agg(social_private.social_work_json(q.id) order by q.sort_at desc,q.id desc),'[]'::jsonb) into result
  from(select x.id,coalesce(x.published_at,x.created_at) sort_at from public.social_works x
   where social_private.social_visible(x.id)
    and case when p_action in('feed','profileMomentsPage') then x.kind='moment' and x.status='published'
     else x.kind='album' end
    and case when p_action='feed' then
     (nullif(p_payload->>'topic','') is null or p_payload->>'topic'='전체' or social_private.normalize_social_topic(x.topic)=social_private.normalize_social_topic(p_payload->>'topic'))
      and(not coalesce((p_payload->>'following')::boolean,false) or exists(select 1 from public.social_follows f where f.follower_id=actor and f.following_id=x.author_id))
     when p_action in('ownWorks','ownWorksPage') then x.author_id=actor and x.status in('published','private')
      and(coalesce(p_payload->>'status','all')='all' or x.status=case p_payload->>'status' when 'public' then 'published' else 'private' end)
     else x.author_id=target and x.status='published' end
    and(cursor_at is null or(coalesce(x.published_at,x.created_at),x.id)<(cursor_at,cursor_id))
   order by sort_at desc,x.id desc offset page_offset limit page_limit+1)q;
  if p_action in('profileWorks','ownWorks') then
   return(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) from jsonb_array_elements(result)with ordinality where ordinality<=page_limit);
  end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) from jsonb_array_elements(result)with ordinality where ordinality<=page_limit),
   'hasMore',jsonb_array_length(result)>page_limit,'nextOffset',page_offset+least(jsonb_array_length(result),page_limit),
   'nextCursor',case when jsonb_array_length(result)>page_limit then jsonb_build_object('publishedAt',result->(page_limit-1)->>'createdAt','id',result->(page_limit-1)->>'id') else null end);
 end if;

 if p_action='momentPublication' then
  actor:=moments_private.actor();
  select * into m from moments_private.weekly_moments where id=(p_payload->>'recordId')::uuid and owner_id=actor and deleted_at is null;
  if not found then return null; end if;
  select * into s from moments_private.publications where record_id=m.id and owner_id=actor;
  select * into w from public.social_works where id=s.current_work_id and author_id=actor and status in('draft','published','private') and social_private.moment_source_current(id);
  if found then select * into b from social_private.moment_publication_sources where work_id=w.id; end if;
  return jsonb_build_object('recordId',m.id,'recordRevision',m.revision,'sourceRevision',coalesce(b.source_revision,m.revision),
   'photoId',b.photo_id,'workId',w.id,'id',w.id,'status',coalesce(w.status,'private'),'publicationRevision',coalesce(s.revision,0),'requestId',b.request_id);
 end if;

 if p_action='beginMomentPublication' then
  actor:=moments_private.actor(true);
  select * into m from moments_private.weekly_moments where id=(p_payload->>'recordId')::uuid and owner_id=actor for update;
  if not found then raise exception 'MOMENTS_ACCESS_DENIED' using errcode='42501'; end if;
  if m.deleted_at is not null then raise exception 'MOMENTS_RECORD_DELETED' using errcode='PT409'; end if;
  expected:=(p_payload->>'expectedRevision')::integer;
  if expected is null or expected<>m.revision then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
  select p into photo from jsonb_array_elements(m.photos)p where (p->>'id')::uuid=(p_payload->>'photoId')::uuid;
  if not found then raise exception 'MOMENTS_PHOTO_UNAVAILABLE' using errcode='42501'; end if;
  request:=(p_payload->>'requestId')::uuid;
  if request is null then raise exception 'social_invalid_publication_request_id' using errcode='22023'; end if;
  fingerprint:=jsonb_build_object('recordId',m.id,'photoId',photo->>'id','expectedRevision',expected);
  insert into moments_private.publications(record_id,owner_id)values(m.id,actor)on conflict(record_id)do nothing;
  select * into s from moments_private.publications where record_id=m.id and owner_id=actor for update;
  select * into b from social_private.moment_publication_sources where owner_id=actor and request_id=request;
  if found then
   if b.request_fingerprint<>fingerprint then raise exception 'social_publication_request_mismatch' using errcode='22023'; end if;
   if not social_private.moment_source_current(b.work_id) then raise exception 'MOMENTS_PUBLICATION_CHANGED' using errcode='PT409'; end if;
   select * into w from public.social_works where id=b.work_id and status in('draft','published','private');
   if not found then raise exception 'MOMENTS_PUBLICATION_CHANGED' using errcode='PT409'; end if;
   return jsonb_build_object('id',w.id,'pageIndexes',jsonb_build_array(0),'status',w.status,'publicationRevision',s.revision);
  end if;
  perform social_private.social_api_albums_v1('ensureProfile','{}'::jsonb);
  if(select count(*) from public.social_works where author_id=actor and status='draft')>=5 then raise exception 'social_draft_limit' using errcode='22023'; end if;
  -- Replacing a representative photograph is an explicit new publication.
  -- Withdraw its predecessor before preparing files; a failure stays private.
  update public.social_works x set status=case when x.status='draft' then 'deleted' else 'private' end
   where x.id in(select q.work_id from social_private.moment_publication_sources q where q.record_id=m.id)and x.status in('draft','published');
  update moments_private.publications set revision=revision+1,current_work_id=null where record_id=m.id returning * into s;
  insert into public.social_works(author_id,title,caption,topic,aspect_ratio,kind,record_date)
   values(actor,to_char(m.record_date,'YYYY.MM.DD')||'의 기록',m.caption,'일상',
    least(greatest((photo->>'width')::numeric/nullif((photo->>'height')::numeric,0),.1),10),'moment',m.record_date) returning id into v_work;
  insert into social_private.moment_publication_sources values(v_work,m.id,actor,(photo->>'id')::uuid,m.revision,s.revision,request,fingerprint);
  insert into public.social_work_pages values(v_work,0,actor::text||'/'||v_work::text||'/0.png');
  update moments_private.publications set current_work_id=v_work where record_id=m.id;
  return jsonb_build_object('id',v_work,'pageIndexes',jsonb_build_array(0),'status','draft','publicationRevision',s.revision);
 end if;

 if p_action in('publicationUploadPath','finalizePublication','visibility','deleteWork','discardDraft') then
  select * into b from social_private.moment_publication_sources where work_id=(p_payload->>'id')::uuid;
  if found then
   actor:=moments_private.actor(true);
   if b.owner_id<>actor then raise exception 'social_work_owner_required' using errcode='42501'; end if;
   select * into m from moments_private.weekly_moments where id=b.record_id and owner_id=actor for update;
   select * into s from moments_private.publications where record_id=b.record_id and owner_id=actor for update;
   select * into w from public.social_works where id=b.work_id and author_id=actor for update;
   if p_action in('deleteWork','discardDraft') then
    if p_action='discardDraft' and w.status<>'draft' then return 'false'::jsonb; end if;
    update public.social_works set status='deleted' where id=w.id;
    update moments_private.publications set revision=revision+1,current_work_id=null where record_id=b.record_id and current_work_id=w.id;
    return 'true'::jsonb;
   end if;
   if p_action='visibility' then
    expected:=(p_payload->>'expectedPublicationRevision')::integer;
    if jsonb_typeof(p_payload->'published') is distinct from 'boolean' or expected is null then raise exception 'MOMENTS_PUBLICATION_CAS_REQUIRED' using errcode='22023'; end if;
    want_public:=(p_payload->>'published')::boolean;
    -- A lost draft-withdrawal response may be retried, but cannot hide a newer generation.
    if not want_public and s.current_work_id is null and s.revision=expected+1 and w.status in('deleted','private') then return 'true'::jsonb; end if;
    if not social_private.moment_source_current(w.id) then raise exception 'MOMENTS_PUBLICATION_CHANGED' using errcode='PT409'; end if;
    if w.status=(case when want_public then 'published' else 'private' end) and expected in(s.revision,s.revision-1) then return 'true'::jsonb; end if;
    if expected<>s.revision then raise exception 'MOMENTS_PUBLICATION_CHANGED' using errcode='PT409'; end if;
    if w.status='draft' and not want_public then
     update public.social_works set status='deleted' where id=w.id;
     update moments_private.publications set revision=revision+1,current_work_id=null where record_id=b.record_id;
     return 'true'::jsonb;
    end if;
    if w.published_at is null or w.status not in('published','private') then raise exception 'social_not_finalized' using errcode='22023'; end if;
    update moments_private.publications set revision=revision+1 where record_id=b.record_id returning * into s;
    update social_private.moment_publication_sources set publication_revision=s.revision where work_id=w.id;
    update public.social_works set status=case when want_public then 'published' else 'private' end where id=w.id;
    return 'true'::jsonb;
   end if;
   if not social_private.moment_source_current(w.id) then raise exception 'MOMENTS_PUBLICATION_CHANGED' using errcode='PT409'; end if;
   if p_action='publicationUploadPath' then return social_private.social_api_albums_v1(p_action,p_payload); end if;
   if w.published_at is not null and w.status in('published','private') then return social_private.social_work_json(w.id); end if;
   if w.status<>'draft' then raise exception 'social_not_draft' using errcode='22023'; end if;
   if not exists(select 1 from storage.objects o join public.social_work_pages p on p.storage_path=o.name
    where p.work_id=w.id and p.position=0 and o.bucket_id='social-snapshots' and o.metadata->>'mimetype'='image/png'
     and(o.metadata->>'size')::bigint between 24 and 8388608)then raise exception 'social_snapshot_uploads_incomplete' using errcode='22023'; end if;
   update public.social_works set status='published',published_at=clock_timestamp() where id=w.id;
   return social_private.social_work_json(w.id);
  end if;
 end if;

 if p_action='discardDrafts' then
  actor:=moments_private.actor(true);
  result:=social_private.social_api_albums_v1(p_action,p_payload);
  update moments_private.publications ledger set revision=ledger.revision+1,current_work_id=null
   where ledger.owner_id=actor and exists(select 1 from public.social_works deleted_work where deleted_work.id=ledger.current_work_id and deleted_work.status='deleted');
  return result;
 end if;
 return social_private.social_api_albums_v1(p_action,p_payload);
end;
$$;
revoke all on function social_private.social_api(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb) to anon,authenticated;
-- Recompile the exposed wrapper too: pre-existing pooled connections must not
-- keep a cached plan pointing at the renamed album-only implementation.
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select social_private.social_api(p_action,p_payload) $$;
revoke all on function public.social_api(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb) to anon,authenticated;

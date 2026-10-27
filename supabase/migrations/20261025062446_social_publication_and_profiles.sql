-- Opt-in public identities and immutable, isolated raster publications.
-- Existing private profiles, albums, source URLs and documents are untouched.
create schema if not exists social_private;

create table public.social_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 30),
  handle text not null unique check (handle ~ '^[a-z0-9._]{3,24}$' and handle = lower(handle)),
  bio text not null default '' check (char_length(bio) <= 160),
  created_at timestamptz not null default now()
);
create table public.social_follows (
  follower_id uuid not null references public.social_profiles(user_id) on delete cascade,
  following_id uuid not null references public.social_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id), check (follower_id <> following_id)
);
create index social_follows_following_idx on public.social_follows(following_id, follower_id);
create table public.social_blocks (
  owner_id uuid not null references public.social_profiles(user_id) on delete cascade,
  target_id uuid not null references public.social_profiles(user_id) on delete cascade,
  primary key (owner_id, target_id), check (owner_id <> target_id)
);
create index social_blocks_target_idx on public.social_blocks(target_id, owner_id);
create table public.social_works (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.social_profiles(user_id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  caption text not null default '' check (char_length(caption) <= 500),
  topic text not null default '일상' check (topic in ('여행','일상','커플','가족','반려동물','기타')),
  aspect_ratio numeric not null default 1 check (aspect_ratio between 0.1 and 10),
  status text not null default 'draft' check (status in ('draft','published','private','deleted')),
  created_at timestamptz not null default now(),
  published_at timestamptz
);
create index social_works_feed_idx on public.social_works(published_at desc, id desc) where status = 'published';
create index social_works_author_idx on public.social_works(author_id, created_at desc);
create index social_works_topic_idx on public.social_works(topic, published_at desc, id desc) where status = 'published';
create table social_private.social_publication_sources (
  work_id uuid primary key references public.social_works(id) on delete cascade,
  source_album_id bigint references public.albums(id) on delete set null,
  source_updated_at timestamptz not null,
  page_indexes integer[] not null check (cardinality(page_indexes) between 1 and 20)
  ,owner_id uuid not null references auth.users(id) on delete cascade
  ,request_id uuid not null
  ,request_fingerprint jsonb not null
  ,unique(owner_id, request_id)
);
alter table social_private.social_publication_sources enable row level security;
revoke all on social_private.social_publication_sources from public, anon, authenticated;
create table public.social_work_pages (
  work_id uuid not null references public.social_works(id) on delete cascade,
  position integer not null check (position between 0 and 19),
  storage_path text not null unique,
  primary key (work_id, position)
);
create table public.social_likes (
  work_id uuid not null references public.social_works(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (work_id, user_id)
);
create table public.social_saves (
  work_id uuid not null references public.social_works(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (work_id, user_id)
);
create index social_saves_owner_idx on public.social_saves(user_id, created_at desc);
create table public.social_comments (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.social_works(id) on delete cascade,
  author_id uuid not null references public.social_profiles(user_id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);
create index social_comments_work_idx on public.social_comments(work_id, created_at, id);

create function social_private.social_blocked(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.social_blocks b where
    (b.owner_id = auth.uid() and b.target_id = p_user) or
    (b.target_id = auth.uid() and b.owner_id = p_user))
$$;
create function social_private.social_visible(p_work uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.social_works w where w.id = p_work
    and (w.status = 'published' or (w.author_id = auth.uid() and w.status <> 'deleted'))
    and not social_private.social_blocked(w.author_id))
$$;
revoke all on function social_private.social_blocked(uuid), social_private.social_visible(uuid) from public;
grant usage on schema social_private to anon, authenticated;
grant execute on function social_private.social_blocked(uuid), social_private.social_visible(uuid) to anon, authenticated;

alter table public.social_profiles enable row level security;
alter table public.social_follows enable row level security;
alter table public.social_blocks enable row level security;
alter table public.social_works enable row level security;
alter table public.social_work_pages enable row level security;
alter table public.social_likes enable row level security;
alter table public.social_saves enable row level security;
alter table public.social_comments enable row level security;
create policy social_profiles_read on public.social_profiles for select to anon, authenticated
  using (not social_private.social_blocked(user_id));
create policy social_follows_read on public.social_follows for select to anon, authenticated
  using (not social_private.social_blocked(follower_id) and not social_private.social_blocked(following_id));
create policy social_blocks_own on public.social_blocks for select to authenticated using (owner_id = (select auth.uid()));
create policy social_works_read on public.social_works for select to anon, authenticated using (social_private.social_visible(id));
create policy social_pages_read on public.social_work_pages for select to anon, authenticated using (social_private.social_visible(work_id));
create policy social_likes_own on public.social_likes for select to authenticated using (user_id = (select auth.uid()) and social_private.social_visible(work_id));
create policy social_saves_own on public.social_saves for select to authenticated using (user_id = (select auth.uid()) and social_private.social_visible(work_id));
create policy social_comments_read on public.social_comments for select to anon, authenticated
  using (social_private.social_visible(work_id) and not social_private.social_blocked(author_id));
revoke all on public.social_profiles, public.social_follows, public.social_blocks,
  public.social_works, public.social_work_pages, public.social_likes, public.social_saves, public.social_comments from public, anon, authenticated;
grant select on public.social_profiles, public.social_follows, public.social_works, public.social_work_pages, public.social_comments to anon, authenticated;
grant select on public.social_blocks, public.social_likes, public.social_saves to authenticated;

create function social_private.social_profile_json(p_user uuid) returns jsonb
language sql stable set search_path = '' as $$
 select jsonb_build_object('userId', p.user_id, 'displayName', p.display_name,
  'handle', p.handle, 'bio', p.bio, 'avatarUrl', null,
  'followersCount', (select count(*) from public.social_follows f where f.following_id=p.user_id and not social_private.social_blocked(f.follower_id)),
  'followingCount', (select count(*) from public.social_follows f where f.follower_id=p.user_id and not social_private.social_blocked(f.following_id)),
  'worksCount', (select count(*) from public.social_works w where w.author_id=p.user_id and w.status='published'),
  'isFollowing', exists(select 1 from public.social_follows f where f.follower_id=auth.uid() and f.following_id=p.user_id))
 from public.social_profiles p where p.user_id=p_user
$$;
create function social_private.social_work_json(p_id uuid) returns jsonb
language sql stable set search_path = '' as $$
 select jsonb_build_object('id', w.id, 'author', social_private.social_profile_json(w.author_id),
  'title', w.title, 'caption', w.caption, 'topic', w.topic, 'status', w.status, 'aspectRatio', w.aspect_ratio,
  'createdAt', coalesce(w.published_at, w.created_at),
  'imagePaths', coalesce((select jsonb_agg(p.storage_path order by p.position) from public.social_work_pages p where p.work_id=w.id), '[]'::jsonb),
  'likeCount', (select count(*) from public.social_likes l where l.work_id=w.id),
  'commentCount', (select count(*) from public.social_comments c where c.work_id=w.id and not social_private.social_blocked(c.author_id)),
  'isLiked', exists(select 1 from public.social_likes l where l.work_id=w.id and l.user_id=auth.uid()),
  'isSaved', exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=auth.uid()))
 from public.social_works w where w.id=p_id
$$;
revoke all on function social_private.social_profile_json(uuid), social_private.social_work_json(uuid) from public, anon, authenticated;

-- The sole privileged dispatcher lives outside the exposed schema. Every
-- mutation derives its actor from auth.uid(); no client-supplied actor is used.
create function social_private.social_api(p_action text, p_payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 actor uuid := auth.uid(); target uuid; v_work_id uuid; item public.social_works;
 source public.albums; binding social_private.social_publication_sources;
 document jsonb; selected integer[]; page_count integer; pos integer; ratio numeric := 1;
 v_request_id uuid; fingerprint jsonb;
 page_offset integer; page_limit integer; result jsonb; removed_count integer; profile_attempt integer;
begin
 if p_action in ('feed','profileWorks','search','savedWorks','ownWorks') then
  page_offset := least(greatest(coalesce((p_payload->>'offset')::integer,0),0),10000);
  page_limit := least(greatest(coalesce((p_payload->>'limit')::integer,12),1),30);
  if p_action in ('savedWorks','ownWorks') and actor is null then raise exception 'social_login_required' using errcode='42501'; end if;
  if p_action='profileWorks' then target:=(p_payload->>'userId')::uuid; page_limit:=30; end if;
  if p_action in ('savedWorks','ownWorks','search') then page_limit:=30; end if;
  select coalesce(jsonb_agg(social_private.social_work_json(q.id) order by q.sort_at desc,q.id desc),'[]'::jsonb) into result from (
   select w.id, coalesce(w.published_at,w.created_at) sort_at from public.social_works w
   where social_private.social_visible(w.id)
    and case p_action
      when 'ownWorks' then w.author_id=actor and w.status in ('published','private')
      when 'savedWorks' then w.status='published' and exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=actor)
      when 'profileWorks' then w.status='published' and w.author_id=target
      when 'search' then w.status='published' and char_length(btrim(coalesce(p_payload->>'query',''))) between 1 and 80
        and (w.title||' '||w.caption||' '||w.topic) ilike '%'||(p_payload->>'query')||'%'
      else w.status='published' and (nullif(p_payload->>'topic','') is null or p_payload->>'topic'='전체' or w.topic=p_payload->>'topic')
        and (not coalesce((p_payload->>'following')::boolean,false) or exists(select 1 from public.social_follows f where f.follower_id=actor and f.following_id=w.author_id))
    end
   order by sort_at desc,w.id desc offset page_offset limit page_limit+1
  ) q;
  if p_action='feed' then
   return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) from jsonb_array_elements(result) with ordinality where ordinality<=page_limit),
    'hasMore',jsonb_array_length(result)>page_limit,'nextOffset',page_offset+least(jsonb_array_length(result),page_limit));
  end if;
  return (select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) from jsonb_array_elements(result) with ordinality where ordinality<=page_limit);
 elsif p_action='profile' then
  target:=(p_payload->>'userId')::uuid;
  if social_private.social_blocked(target) then return null; end if;
  return social_private.social_profile_json(target);
 elsif p_action='searchProfiles' then
  if char_length(btrim(coalesce(p_payload->>'query',''))) not between 1 and 80 then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(social_private.social_profile_json(p.user_id) order by p.handle),'[]'::jsonb) from
    (select user_id,handle from public.social_profiles where not social_private.social_blocked(user_id)
     and (display_name||' '||handle) ilike '%'||(p_payload->>'query')||'%' order by handle limit 30) p);
 elsif p_action='relations' then
  target:=(p_payload->>'userId')::uuid;
  if social_private.social_blocked(target) then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(social_private.social_profile_json(q.id) order by q.created_at desc,q.id),'[]'::jsonb) from
    (select case when coalesce((p_payload->>'followers')::boolean,true) then follower_id else following_id end id,created_at
     from public.social_follows where case when coalesce((p_payload->>'followers')::boolean,true) then following_id=target else follower_id=target end) q
    where not social_private.social_blocked(q.id));
 elsif p_action='work' then
  v_work_id:=(p_payload->>'id')::uuid;
  if not social_private.social_visible(v_work_id) then return null; end if;
  return social_private.social_work_json(v_work_id);
 elsif p_action='comments' then
  v_work_id:=(p_payload->>'id')::uuid;
  if not social_private.social_visible(v_work_id) then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'body',q.body,'createdAt',q.created_at,'author',social_private.social_profile_json(q.author_id)) order by q.created_at,q.id),'[]'::jsonb)
    from (select * from public.social_comments where work_id=(p_payload->>'id')::uuid and not social_private.social_blocked(author_id) order by created_at desc,id desc limit 100) q);
 end if;

 if actor is null then raise exception 'social_login_required' using errcode='42501'; end if;
 if p_action='blockedProfiles' then
  return (select coalesce(jsonb_agg(social_private.social_profile_json(b.target_id) order by b.target_id),'[]'::jsonb) from public.social_blocks b where b.owner_id=actor);
 end if;
 -- A guessed UUID-derived default handle must never let another user prevent
 -- the actor from creating or repairing their own public identity.
 for profile_attempt in 1..5 loop
  begin
   insert into public.social_profiles(user_id,display_name,handle)
    values(actor,'나의 기록','sf_'||left(replace(gen_random_uuid()::text,'-',''),20)) on conflict(user_id) do nothing;
   exit;
  exception when unique_violation then
   if profile_attempt=5 then raise; end if;
  end;
 end loop;
 if p_action='ensureProfile' then return social_private.social_profile_json(actor);
 elsif p_action in ('discardDraft','discardDrafts') then
  perform 1 from public.social_profiles where user_id=actor for update;
  update public.social_works set status='deleted' where author_id=actor and status='draft'
    and (p_action='discardDrafts' or id=(p_payload->>'id')::uuid);
  get diagnostics removed_count=row_count;
  if p_action='discardDraft' then return to_jsonb(removed_count=1); end if;
  return to_jsonb(removed_count);
 elsif p_action='deleteComment' then
  delete from public.social_comments c where c.id=(p_payload->>'id')::uuid and
    (c.author_id=actor or exists(select 1 from public.social_works w where w.id=c.work_id and w.author_id=actor));
  if not found then raise exception 'social_comment_owner_required' using errcode='42501'; end if;
  return 'true'::jsonb;
 elsif p_action='upsertProfile' then
  update public.social_profiles set display_name=btrim(p_payload->>'displayName'),handle=lower(btrim(p_payload->>'handle')),bio=btrim(coalesce(p_payload->>'bio','')) where user_id=actor;
  return social_private.social_profile_json(actor);
 elsif p_action in ('toggleFollow','removeFollower','setBlocked') then
  target:=(p_payload->>'userId')::uuid;
  if target=actor or not exists(select 1 from public.social_profiles where user_id=target) then raise exception 'social_invalid_user' using errcode='22023'; end if;
  -- Lock both identities in a stable order so a concurrent block/follow cannot
  -- leave a fresh follow relation behind the block transaction.
  perform 1 from public.social_profiles where user_id in (actor,target) order by user_id for update;
  if p_action='setBlocked' then
   if coalesce((p_payload->>'blocked')::boolean,false) then
    insert into public.social_blocks(owner_id,target_id) values(actor,target) on conflict do nothing;
    delete from public.social_follows where (follower_id=actor and following_id=target) or (follower_id=target and following_id=actor);
   else delete from public.social_blocks where owner_id=actor and target_id=target; end if;
   return 'true'::jsonb;
  elsif p_action='removeFollower' then delete from public.social_follows where follower_id=target and following_id=actor; return 'true'::jsonb;
  end if;
  if social_private.social_blocked(target) then raise exception 'social_blocked' using errcode='42501'; end if;
  delete from public.social_follows where follower_id=actor and following_id=target;
  if found then return 'false'::jsonb; end if;
  insert into public.social_follows(follower_id,following_id) values(actor,target);
  return 'true'::jsonb;
 elsif p_action='beginPublication' then
  perform 1 from public.social_profiles where user_id=actor for update;
  v_request_id:=coalesce(nullif(p_payload->>'requestId','')::uuid,gen_random_uuid());
  fingerprint:=jsonb_build_object('albumId',(p_payload->>'albumId')::bigint,'pageIndexes',p_payload->'pageIndexes',
    'title',btrim(p_payload->>'title'),'caption',coalesce(p_payload->>'caption',''),'topic',coalesce(p_payload->>'topic','일상'),'expectedUpdatedAt',p_payload->>'expectedUpdatedAt');
  select * into binding from social_private.social_publication_sources s where s.owner_id=actor and s.request_id=v_request_id;
  if found then
   if binding.request_fingerprint<>fingerprint then raise exception 'social_publication_request_mismatch' using errcode='22023'; end if;
   select * into item from public.social_works where id=binding.work_id;
   if item.status='deleted' then raise exception 'social_not_draft' using errcode='22023'; end if;
   return jsonb_build_object('id',item.id,'pageIndexes',binding.page_indexes,'status',item.status);
  end if;
  select * into source from public.albums where id=(p_payload->>'albumId')::bigint and owner_id=actor for update;
  if not found then raise exception 'social_album_owner_required' using errcode='42501'; end if;
  if nullif(p_payload->>'expectedUpdatedAt','') is not null and
    (p_payload->>'expectedUpdatedAt')::timestamptz is distinct from source.updated_at then
   raise exception 'social_source_changed' using errcode='40001';
  end if;
  if exists(select 1 from public.album_members m where m.album_id=source.id and m.user_id<>actor) then raise exception 'social_collaborative_album_unsupported' using errcode='42501'; end if;
  document:=nullif(btrim(source.cover_layers_json),'')::jsonb;
  if jsonb_typeof(document->'pages')='array' then page_count:=jsonb_array_length(document->'pages');
  elsif jsonb_typeof(document->'layers')='array' then page_count:=1;
  else raise exception 'social_saved_document_required' using errcode='22023'; end if;
  if jsonb_typeof(p_payload->'pageIndexes') is distinct from 'array' then raise exception 'social_pages_required' using errcode='22023'; end if;
  select array_agg(value::integer order by ordinality) into selected from jsonb_array_elements_text(p_payload->'pageIndexes') with ordinality;
  if coalesce(cardinality(selected),0) not between 1 and 20 or exists(select 1 from unnest(selected) v where v<0 or v>=page_count) or (select count(distinct v) from unnest(selected) v)<>cardinality(selected) then raise exception 'social_invalid_pages' using errcode='22023'; end if;
  if (select count(*) from public.social_works where author_id=actor and status='draft')>=5 then raise exception 'social_draft_limit' using errcode='22023'; end if;
  if source.ratio ~ '^[0-9]+([.][0-9]+)?[:/][0-9]+([.][0-9]+)?$' then
   ratio := (regexp_split_to_array(source.ratio,'[:/]'))[1]::numeric / nullif((regexp_split_to_array(source.ratio,'[:/]'))[2]::numeric,0);
  elsif source.ratio ~ '^[0-9]+([.][0-9]+)?$' then ratio:=source.ratio::numeric; end if;
  ratio:=least(greatest(coalesce(ratio,1),0.1),10);
  insert into public.social_works(author_id,title,caption,topic,aspect_ratio) values(actor,btrim(p_payload->>'title'),coalesce(p_payload->>'caption',''),coalesce(p_payload->>'topic','일상'),ratio) returning id into v_work_id;
  insert into social_private.social_publication_sources(work_id,source_album_id,source_updated_at,page_indexes,owner_id,request_id,request_fingerprint)
   values(v_work_id,source.id,source.updated_at,selected,actor,v_request_id,fingerprint);
  for pos in 0..cardinality(selected)-1 loop
   insert into public.social_work_pages values(v_work_id,pos,actor::text||'/'||v_work_id::text||'/'||pos::text||'.png');
  end loop;
  return jsonb_build_object('id',v_work_id,'pageIndexes',selected,'status','draft');
 elsif p_action in ('publicationUploadPath','finalizePublication','visibility','deleteWork') then
  v_work_id:=(p_payload->>'id')::uuid;
  select * into item from public.social_works where id=v_work_id and author_id=actor for update;
  if not found then raise exception 'social_work_owner_required' using errcode='42501'; end if;
  if p_action='deleteWork' then update public.social_works set status='deleted' where id=v_work_id; return 'true'::jsonb; end if;
  if p_action='visibility' then
   if item.published_at is null or item.status='deleted' then raise exception 'social_not_finalized' using errcode='22023'; end if;
   update public.social_works set status=case when coalesce((p_payload->>'published')::boolean,false) then 'published' else 'private' end where id=v_work_id;
   return 'true'::jsonb;
  end if;
  if p_action='publicationUploadPath' then
   if item.status<>'draft' then raise exception 'social_snapshot_immutable' using errcode='42501'; end if;
   select jsonb_build_object('path',p.storage_path,'uploaded',exists(select 1 from storage.objects o where o.bucket_id='social-snapshots' and o.name=p.storage_path and o.metadata->>'mimetype'='image/png' and (o.metadata->>'size')::bigint between 24 and 8388608)) into result
    from public.social_work_pages p where p.work_id=item.id and p.position=(p_payload->>'position')::integer;
   if not found then raise exception 'social_invalid_position' using errcode='22023'; end if;
   return result;
  end if;
  if item.published_at is not null and item.status in ('published','private') then return social_private.social_work_json(v_work_id); end if;
  if item.status<>'draft' then raise exception 'social_not_draft' using errcode='22023'; end if;
  select * into binding from social_private.social_publication_sources where work_id=item.id;
  select * into source from public.albums where id=binding.source_album_id and owner_id=actor for update;
  if not found then raise exception 'social_album_owner_required' using errcode='42501'; end if;
  if source.updated_at<>binding.source_updated_at then raise exception 'social_source_changed' using errcode='40001'; end if;
  if exists(select 1 from public.album_members m where m.album_id=source.id and m.user_id<>actor) then raise exception 'social_collaborative_album_unsupported' using errcode='42501'; end if;
  if exists(select 1 from public.social_work_pages p where p.work_id=item.id and not exists(
   select 1 from storage.objects o where o.bucket_id='social-snapshots' and o.name=p.storage_path
    and o.metadata->>'mimetype'='image/png' and (o.metadata->>'size')::bigint between 24 and 8388608)) then
   raise exception 'social_snapshot_uploads_incomplete' using errcode='22023';
  end if;
  update public.social_works set status='published',published_at=now() where id=v_work_id;
  return social_private.social_work_json(v_work_id);
 elsif p_action in ('toggleLike','toggleSave','addComment') then
  v_work_id:=(p_payload->>'id')::uuid;
  select * into item from public.social_works where id=v_work_id and status='published' and not social_private.social_blocked(author_id) for update;
  if not found then raise exception 'social_work_unavailable' using errcode='42501'; end if;
  if p_action='toggleLike' then
   delete from public.social_likes where work_id=item.id and user_id=actor;
   if found then return 'false'::jsonb; end if;
   insert into public.social_likes values(item.id,actor); return 'true'::jsonb;
  elsif p_action='toggleSave' then
   delete from public.social_saves where work_id=item.id and user_id=actor;
   if found then return 'false'::jsonb; end if;
   insert into public.social_saves(work_id,user_id) values(item.id,actor); return 'true'::jsonb;
  end if;
  insert into public.social_comments(work_id,author_id,body) values(item.id,actor,btrim(p_payload->>'body')) returning id into target;
  return (select jsonb_build_object('id',c.id,'body',c.body,'createdAt',c.created_at,'author',social_private.social_profile_json(actor)) from public.social_comments c where c.id=target);
 end if;
 raise exception 'social_unknown_action' using errcode='22023';
end;
$$;
revoke all on function social_private.social_api(text,jsonb) from public;
grant execute on function social_private.social_api(text,jsonb) to anon, authenticated;
create function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path = '' as $$ select social_private.social_api(p_action,p_payload) $$;
revoke all on function public.social_api(text,jsonb) from public;
grant execute on function public.social_api(text,jsonb) to anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('social-snapshots','social-snapshots',false,8388608,array['image/png'])
on conflict(id) do nothing;
-- Refuse a pre-existing bucket with weaker privacy rather than silently using
-- public delivery for publications expected to be revocable.
do $$ begin
 if exists(select 1 from storage.buckets where id='social-snapshots' and public) then
  raise exception 'social_snapshot_bucket_must_be_private';
 end if;
end $$;
create function social_private.social_snapshot_access(p_path text,p_upload boolean) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.social_work_pages p join public.social_works w on w.id=p.work_id
  where p.storage_path=p_path and case when p_upload then w.author_id=auth.uid() and w.status='draft'
   else social_private.social_visible(w.id) end)
$$;
revoke all on function social_private.social_snapshot_access(text,boolean) from public;
grant execute on function social_private.social_snapshot_access(text,boolean) to anon,authenticated;
create policy social_snapshot_read on storage.objects for select to anon,authenticated
 using (bucket_id='social-snapshots' and social_private.social_snapshot_access(name,false));
create policy social_snapshot_insert on storage.objects for insert to authenticated
 with check (bucket_id='social-snapshots' and social_private.social_snapshot_access(name,true));
-- No overwrite policy: the uploaded page and the finalized publication are
-- immutable. Different selections or edits require another publication.
create function social_private.social_snapshot_guard() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if old.bucket_id='social-snapshots' then
  if tg_op='UPDATE' then
   if (to_jsonb(new)-array['updated_at','last_accessed_at']) is distinct from (to_jsonb(old)-array['updated_at','last_accessed_at']) then
    raise exception 'social_snapshot_immutable' using errcode='42501';
   end if;
   return new;
  end if;
  if exists(select 1 from public.social_work_pages p join public.social_works w on w.id=p.work_id where p.storage_path=old.name and w.status in ('published','private')) then
   raise exception 'social_snapshot_immutable' using errcode='42501';
  end if;
 end if;
 if tg_op='UPDATE' then return new; end if;
 return old;
end;
$$;
revoke all on function social_private.social_snapshot_guard() from public;
create trigger social_snapshot_immutable before update or delete on storage.objects
 for each row execute function social_private.social_snapshot_guard();

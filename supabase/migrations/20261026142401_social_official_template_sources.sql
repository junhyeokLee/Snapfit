-- Official template discovery is opt-in. Only a product identity is projected;
-- private album documents, photos, text, edits and material entitlements stay private.
alter table social_private.social_publication_sources
 add column source_template_product_key text references public.point_shop_products(product_key) on delete set null;
create index social_publication_template_source_idx
 on social_private.social_publication_sources(source_template_product_key)
 where source_template_product_key is not null;

-- A source document is a client-authored attribution, never proof of entitlement.
-- Resolve both the canonical title and permission from the server catalog.
create function social_private.document_template_source(p_document text,p_owner uuid) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare document jsonb; v_product_key text; result jsonb;
begin
 if p_owner is null or nullif(btrim(p_document),'') is null then return null; end if;
 begin document:=p_document::jsonb;
 exception when invalid_text_representation then return null; end;
 if jsonb_typeof(document->'sourceTemplate') is distinct from 'object'
  or jsonb_typeof(document->'sourceTemplate'->'productKey') is distinct from 'string' then
  return null;
 end if;
 v_product_key:=document->'sourceTemplate'->>'productKey';
 if char_length(v_product_key)>190 then return null; end if;
 select jsonb_build_object('productKey',p.product_key,'title',p.title) into result
 from public.point_shop_products p
 where p.product_key=v_product_key and p.kind='template' and p.is_active
  and p.point_price is not null
  and (p.point_price=0 or exists(select 1 from public.point_shop_ownership o
   where o.user_id=p_owner and o.product_key=p.product_key));
 return result;
end;
$$;
revoke all on function social_private.document_template_source(text,uuid) from public,anon,authenticated;

create function social_private.work_template_source(p_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('productKey',p.product_key,'title',p.title)
 from public.social_works w
 join social_private.social_publication_sources s on s.work_id=w.id
 join public.point_shop_products p on p.product_key=s.source_template_product_key
 where w.id=p_id and w.status='published' and not social_private.social_blocked(w.author_id)
  and p.kind='template' and p.is_active and p.point_price is not null
  and (p.point_price=0 or exists(select 1 from public.point_shop_ownership o
   where o.user_id=w.author_id and o.product_key=p.product_key))
$$;
revoke all on function social_private.work_template_source(uuid) from public,anon,authenticated;

create or replace function social_private.social_work_json(p_id uuid) returns jsonb
language sql stable set search_path = '' as $$
 select jsonb_build_object('id', w.id, 'author', social_private.social_profile_json(w.author_id),
  'title', w.title, 'caption', w.caption, 'topic', w.topic, 'status', w.status, 'aspectRatio', w.aspect_ratio,
  'createdAt', coalesce(w.published_at, w.created_at),
  'imagePaths', coalesce((select jsonb_agg(p.storage_path order by p.position) from public.social_work_pages p where p.work_id=w.id), '[]'::jsonb),
  'likeCount', (select count(*) from public.social_likes l where l.work_id=w.id),
  'commentCount', (select count(*) from public.social_comments c where c.work_id=w.id and not social_private.social_blocked(c.author_id)),
  'isLiked', exists(select 1 from public.social_likes l where l.work_id=w.id and l.user_id=auth.uid()),
  'isSaved', exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=auth.uid()),
  'sourceTemplate',social_private.work_template_source(w.id))
 from public.social_works w where w.id=p_id
$$;
revoke all on function social_private.social_work_json(uuid) from public,anon,authenticated;

-- Keep the existing dispatcher and its authorization/idempotency semantics.
-- Only the two source reads and the publication's explicit opt-in are additive.
create or replace function social_private.social_api(p_action text, p_payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 actor uuid := auth.uid(); target uuid; v_work_id uuid; item public.social_works;
 source public.albums; binding social_private.social_publication_sources;
 document jsonb; selected integer[]; page_count integer; pos integer; ratio numeric := 1;
 v_request_id uuid; fingerprint jsonb; v_avatar_path text; comment_item public.social_comments;
 page_offset integer; page_limit integer; result jsonb; removed_count integer; profile_attempt integer;
 include_source_template boolean; source_template jsonb;
begin
 if p_action='resolveWorkTemplate' then
  return social_private.work_template_source((p_payload->>'id')::uuid);
 elsif p_action='albumTemplateSource' then
  if actor is null then raise exception 'social_login_required' using errcode='42501'; end if;
  select * into source from public.albums where id=(p_payload->>'albumId')::bigint and owner_id=actor;
  if not found then raise exception 'social_album_owner_required' using errcode='42501'; end if;
  return social_private.document_template_source(source.cover_layers_json,actor);
 end if;
 -- Paged actions are additive: old clients keep their original array response.
 -- Projection and visibility rules are identical to the legacy read actions.
 if p_action in ('profileWorksPage','ownWorksPage','savedWorksPage','searchPage','searchProfilesPage','relationsPage','commentsPage') then
  page_offset:=coalesce((p_payload->>'offset')::integer,0);
  page_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,12),1),30);
  if page_offset<0 or page_offset>10000 then
   raise exception 'social_invalid_page_offset' using errcode='22023';
  end if;
  if p_action in ('ownWorksPage','savedWorksPage') and actor is null then
   raise exception 'social_login_required' using errcode='42501';
  end if;
  if p_action='ownWorksPage' and coalesce(p_payload->>'status','all') not in ('all','public','private') then
   raise exception 'social_invalid_work_status_filter' using errcode='22023';
  end if;
  if p_action='commentsPage' then
   v_work_id:=(p_payload->>'id')::uuid;
   if not social_private.social_visible(v_work_id) then result:='[]'::jsonb;
   else
    select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'body',q.body,'createdAt',q.created_at,'author',social_private.social_profile_json(q.author_id)) order by q.created_at desc,q.id desc),'[]'::jsonb) into result
    from (select c.id,c.body,c.created_at,c.author_id from public.social_comments c
     where c.work_id=v_work_id and not social_private.social_blocked(c.author_id)
     order by c.created_at desc,c.id desc offset page_offset limit page_limit+1)q;
   end if;
  elsif p_action in ('profileWorksPage','ownWorksPage','savedWorksPage','searchPage') then
   if p_action='profileWorksPage' then target:=(p_payload->>'userId')::uuid; end if;
   select coalesce(jsonb_agg(social_private.social_work_json(q.id) order by q.sort_at desc,q.id desc),'[]'::jsonb) into result from (
    select w.id,coalesce(w.published_at,w.created_at) sort_at from public.social_works w
    where social_private.social_visible(w.id)
     and case p_action
      when 'ownWorksPage' then w.author_id=actor and w.status in ('published','private')
       and (coalesce(p_payload->>'status','all')='all' or w.status=case p_payload->>'status' when 'public' then 'published' else 'private' end)
      when 'savedWorksPage' then w.status='published' and exists(select 1 from public.social_saves s where s.work_id=w.id and s.user_id=actor)
      when 'profileWorksPage' then w.status='published' and w.author_id=target
      else w.status='published' and char_length(btrim(coalesce(p_payload->>'query',''))) between 1 and 80
       and (w.title||' '||w.caption||' '||w.topic||' '||social_private.normalize_social_topic(w.topic)) ilike '%'||(p_payload->>'query')||'%'
     end
    order by sort_at desc,w.id desc offset page_offset limit page_limit+1
   )q;
  elsif p_action='searchProfilesPage' then
   select coalesce(jsonb_agg(social_private.social_profile_json(q.user_id) order by q.handle,q.user_id),'[]'::jsonb) into result from (
    select user_id,handle from public.social_profiles
    where not social_private.social_blocked(user_id)
     and char_length(btrim(coalesce(p_payload->>'query',''))) between 1 and 80
     and (display_name||' '||handle) ilike '%'||(p_payload->>'query')||'%'
    order by handle,user_id offset page_offset limit page_limit+1
   )q;
  else
   target:=(p_payload->>'userId')::uuid;
   if social_private.social_blocked(target) then result:='[]'::jsonb;
   else
    select coalesce(jsonb_agg(social_private.social_profile_json(q.id) order by q.created_at desc,q.id),'[]'::jsonb) into result from (
     select case when coalesce((p_payload->>'followers')::boolean,true) then f.follower_id else f.following_id end id,f.created_at
     from public.social_follows f
     where case when coalesce((p_payload->>'followers')::boolean,true) then f.following_id=target else f.follower_id=target end
      and not social_private.social_blocked(case when coalesce((p_payload->>'followers')::boolean,true) then f.follower_id else f.following_id end)
     order by f.created_at desc,id offset page_offset limit page_limit+1
    )q;
   end if;
  end if;
  return jsonb_build_object(
   'items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) from jsonb_array_elements(result) with ordinality where ordinality<=page_limit),
   'hasMore',jsonb_array_length(result)>page_limit,
   'nextOffset',page_offset+least(jsonb_array_length(result),page_limit));
 end if;
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
        and (w.title||' '||w.caption||' '||w.topic||' '||social_private.normalize_social_topic(w.topic)) ilike '%'||(p_payload->>'query')||'%'
      else w.status='published' and (nullif(p_payload->>'topic','') is null or p_payload->>'topic'='전체' or social_private.normalize_social_topic(w.topic)=social_private.normalize_social_topic(p_payload->>'topic'))
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
 elsif p_action='setProfilePhoto' then
  perform 1 from public.social_profiles where user_id=actor for update;
  if not (p_payload ? 'path') or jsonb_typeof(p_payload->'path') not in ('string','null') then
   raise exception 'social_invalid_profile_photo_path' using errcode='22023';
  end if;
  if jsonb_typeof(p_payload->'path')='null' then
   update public.social_profiles set avatar_path=null where user_id=actor;
   return social_private.social_profile_json(actor);
  end if;
  v_avatar_path:=p_payload->>'path';
  if v_avatar_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]png$' then
   raise exception 'social_invalid_profile_photo_path' using errcode='22023';
  end if;
  if split_part(v_avatar_path,'/',1)<>actor::text then
   raise exception 'social_profile_photo_owner_required' using errcode='42501';
  end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='social-profile-photos' and o.name=v_avatar_path
   and o.metadata->>'mimetype'='image/png' and (o.metadata->>'size')::bigint between 24 and 3145728) then
   raise exception 'social_profile_photo_upload_required' using errcode='22023';
  end if;
  update public.social_profiles set avatar_path=v_avatar_path where user_id=actor;
  return social_private.social_profile_json(actor);
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
 elsif p_action in ('toggleFollow','setFollowing','removeFollower','setBlocked') then
  if p_action='setFollowing' and jsonb_typeof(p_payload->'following') is distinct from 'boolean' then
   raise exception 'social_invalid_follow_state' using errcode='22023';
  end if;
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
  if p_action='setFollowing' then
   if (p_payload->>'following')::boolean then
    insert into public.social_follows(follower_id,following_id) values(actor,target)
     on conflict(follower_id,following_id) do nothing;
   else
    delete from public.social_follows where follower_id=actor and following_id=target;
   end if;
   return p_payload->'following';
  end if;
  delete from public.social_follows where follower_id=actor and following_id=target;
  if found then return 'false'::jsonb; end if;
  insert into public.social_follows(follower_id,following_id) values(actor,target);
  return 'true'::jsonb;
 elsif p_action='beginPublication' then
  if p_payload ? 'includeSourceTemplate' and jsonb_typeof(p_payload->'includeSourceTemplate') is distinct from 'boolean' then
   raise exception 'social_invalid_template_source_opt_in' using errcode='22023';
  end if;
  include_source_template:=coalesce((p_payload->>'includeSourceTemplate')::boolean,false);
  perform 1 from public.social_profiles where user_id=actor for update;
  v_request_id:=coalesce(nullif(p_payload->>'requestId','')::uuid,gen_random_uuid());
  fingerprint:=jsonb_build_object('albumId',(p_payload->>'albumId')::bigint,'pageIndexes',p_payload->'pageIndexes',
    'title',btrim(p_payload->>'title'),'caption',coalesce(p_payload->>'caption',''),'topic',coalesce(p_payload->>'topic','일상'),'expectedUpdatedAt',p_payload->>'expectedUpdatedAt','includeSourceTemplate',include_source_template);
  select * into binding from social_private.social_publication_sources s where s.owner_id=actor and s.request_id=v_request_id;
  if found then
   -- Pre-feature requests omitted the option, which is equivalent to false.
   if (binding.request_fingerprint || jsonb_build_object('includeSourceTemplate',
     coalesce((binding.request_fingerprint->>'includeSourceTemplate')::boolean,false)))<>fingerprint then raise exception 'social_publication_request_mismatch' using errcode='22023'; end if;
   select * into item from public.social_works where id=binding.work_id;
   if item.status='deleted' then raise exception 'social_not_draft' using errcode='22023'; end if;
   return jsonb_build_object('id',item.id,'pageIndexes',binding.page_indexes,'status',item.status);
  end if;
  select * into source from public.albums where id=(p_payload->>'albumId')::bigint and owner_id=actor for update;
  if not found then raise exception 'social_album_owner_required' using errcode='42501'; end if;
  if nullif(p_payload->>'expectedUpdatedAt','') is not null and
    (p_payload->>'expectedUpdatedAt')::timestamptz is distinct from source.updated_at then
   raise exception 'social_source_changed' using errcode='PT409';
  end if;
  if album_private.was_collaborative(source.id) then raise exception 'social_collaborative_album_unsupported' using errcode='42501'; end if;
  document:=nullif(btrim(source.cover_layers_json),'')::jsonb;
  source_template:=null;
  if include_source_template then
   source_template:=social_private.document_template_source(source.cover_layers_json,actor);
   if source_template is null then
    raise exception 'social_source_template_unavailable' using errcode='22023';
   end if;
  end if;
  if jsonb_typeof(document->'pages')='array' and jsonb_array_length(document->'pages')>0 then page_count:=jsonb_array_length(document->'pages');
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
  insert into social_private.social_publication_sources(work_id,source_album_id,source_updated_at,page_indexes,owner_id,request_id,request_fingerprint,source_template_product_key)
   values(v_work_id,source.id,source.updated_at,selected,actor,v_request_id,fingerprint,source_template->>'productKey');
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
   if coalesce((p_payload->>'published')::boolean,false) then
    select * into binding from social_private.social_publication_sources where work_id=item.id;
    -- Serialize a new publication boundary against accepted member changes.
    perform 1 from public.albums where id=binding.source_album_id for update;
    select * into binding from social_private.social_publication_sources where work_id=item.id for update;
    if binding.source_was_collaborative or album_private.was_collaborative(binding.source_album_id) then
     raise exception 'social_collaborative_album_unsupported' using errcode='42501';
    end if;
   end if;
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
  if source.updated_at<>binding.source_updated_at then raise exception 'social_source_changed' using errcode='PT409'; end if;
  if album_private.was_collaborative(source.id) then raise exception 'social_collaborative_album_unsupported' using errcode='42501'; end if;
  if exists(select 1 from public.social_work_pages p where p.work_id=item.id and not exists(
   select 1 from storage.objects o where o.bucket_id='social-snapshots' and o.name=p.storage_path
    and o.metadata->>'mimetype'='image/png' and (o.metadata->>'size')::bigint between 24 and 8388608)) then
   raise exception 'social_snapshot_uploads_incomplete' using errcode='22023';
  end if;
  update public.social_works set status='published',published_at=now() where id=v_work_id;
  return social_private.social_work_json(v_work_id);
 elsif p_action in ('toggleLike','toggleSave','setLiked','setSaved','addComment') then
  v_work_id:=(p_payload->>'id')::uuid;
  select * into item from public.social_works where id=v_work_id and status='published' and not social_private.social_blocked(author_id) for update;
  if not found then raise exception 'social_work_unavailable' using errcode='42501'; end if;
  if p_action='setLiked' then
   if jsonb_typeof(p_payload->'liked') is distinct from 'boolean' then
    raise exception 'social_invalid_like_state' using errcode='22023';
   end if;
   if (p_payload->>'liked')::boolean then
    insert into public.social_likes(work_id,user_id) values(item.id,actor)
     on conflict(work_id,user_id) do nothing;
   else delete from public.social_likes where work_id=item.id and user_id=actor;
   end if;
   return p_payload->'liked';
  elsif p_action='setSaved' then
   if jsonb_typeof(p_payload->'saved') is distinct from 'boolean' then
    raise exception 'social_invalid_save_state' using errcode='22023';
   end if;
   if (p_payload->>'saved')::boolean then
    insert into public.social_saves(work_id,user_id) values(item.id,actor)
     on conflict(work_id,user_id) do nothing;
   else delete from public.social_saves where work_id=item.id and user_id=actor;
   end if;
   return p_payload->'saved';
  elsif p_action='toggleLike' then
   delete from public.social_likes where work_id=item.id and user_id=actor;
   if found then return 'false'::jsonb; end if;
   insert into public.social_likes values(item.id,actor); return 'true'::jsonb;
  elsif p_action='toggleSave' then
   delete from public.social_saves where work_id=item.id and user_id=actor;
   if found then return 'false'::jsonb; end if;
   insert into public.social_saves(work_id,user_id) values(item.id,actor); return 'true'::jsonb;
  end if;
  if p_payload ? 'requestId' and jsonb_typeof(p_payload->'requestId') not in ('string','null') then
   raise exception 'social_invalid_comment_request_id' using errcode='22023';
  end if;
  target:=coalesce((p_payload->>'requestId')::uuid,gen_random_uuid());
  insert into public.social_comments(id,work_id,author_id,body)
   values(target,item.id,actor,btrim(p_payload->>'body')) on conflict(id) do nothing;
  select * into comment_item from public.social_comments where id=target for update;
  if not found or comment_item.author_id<>actor or comment_item.work_id<>item.id
   or comment_item.body is distinct from btrim(p_payload->>'body') then
   raise exception 'social_comment_request_mismatch' using errcode='22023';
  end if;
  return jsonb_build_object('id',comment_item.id,'body',comment_item.body,'createdAt',comment_item.created_at,'author',social_private.social_profile_json(actor));
 end if;
 raise exception 'social_unknown_action' using errcode='22023';
end;
$$;

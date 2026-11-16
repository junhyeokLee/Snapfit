-- Links intentionally survive a deleted parent. The RPC validates the parent
-- and root in the same public work under row locks; clients cannot insert rows.
alter table public.social_comments add column parent_comment_id uuid;
alter table public.social_comments add column root_comment_id uuid;
alter table public.social_comments add constraint social_comment_thread_shape check (
 (parent_comment_id is null and root_comment_id is null) or
 (parent_comment_id is not null and root_comment_id is not null
  and parent_comment_id<>id and root_comment_id<>id)
);
create index social_comments_root_idx on public.social_comments(work_id,root_comment_id,created_at,id)
 where root_comment_id is not null;

-- Keep mention identity and the handle used in the original body together.
-- This ledger is RPC-only, so blocked targets are never exposed by raw reads.
create table social_private.comment_mentions (
 comment_id uuid not null references public.social_comments(id) on delete cascade,
 target_id uuid not null references public.social_profiles(user_id) on delete cascade,
 handle text not null check(handle ~ '^[a-z0-9._]{3,24}$'),
 position integer not null check(position between 0 and 4),
 primary key(comment_id,target_id),unique(comment_id,position)
);
create index social_comment_mentions_target_idx on social_private.comment_mentions(target_id,comment_id);
alter table social_private.comment_mentions enable row level security;
revoke all on social_private.comment_mentions from public,anon,authenticated,service_role;

create function social_private.comment_json(p_id uuid)returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.id,'body',c.body,'createdAt',c.created_at,
  'author',social_private.social_profile_json(c.author_id),
  'parentCommentId',c.parent_comment_id,'rootCommentId',c.root_comment_id,
  'parentAuthor',(select social_private.social_profile_json(p.author_id)
   from public.social_comments p where p.id=c.parent_comment_id and p.work_id=c.work_id
    and not p.moderation_hidden and not social_private.social_blocked(p.author_id)),
  'mentions',(select coalesce(jsonb_agg(social_private.social_profile_json(m.target_id)
     ||jsonb_build_object('handle',m.handle)order by m.position),'[]'::jsonb)
   from social_private.comment_mentions m where m.comment_id=c.id
    and not social_private.social_blocked(m.target_id)))
 from public.social_comments c where c.id=p_id and not c.moderation_hidden
  and social_private.social_visible(c.work_id)and not social_private.social_blocked(c.author_id)
$$;
revoke all on function social_private.comment_json(uuid)from public,anon,authenticated,service_role;

alter function social_private.social_api(text,jsonb)rename to social_api_before_threads_v1;
revoke all on function social_private.social_api_before_threads_v1(text,jsonb)from public,anon,authenticated,service_role;
create function social_private.social_api(p_action text,p_payload jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;work public.social_works;parent public.social_comments;root public.social_comments;
 item public.social_comments;request_id uuid;parent_id uuid;root_id uuid;v_body text;
 v_work_id uuid;page_offset integer;page_limit integer;items jsonb;handles text[];v_handle text;target uuid;v_position integer:=0;
begin
 if p_action in('comments','commentsPage')then
  v_work_id:=(p_payload->>'id')::uuid;
  page_offset:=case when p_action='commentsPage'then coalesce((p_payload->>'offset')::integer,0)else 0 end;
  page_limit:=case when p_action='commentsPage'then least(greatest(coalesce((p_payload->>'limit')::integer,12),1),30)else 100 end;
  if page_offset<0 or page_offset>10000 then raise exception 'social_invalid_page_offset'using errcode='22023';end if;
  if not social_private.social_visible(v_work_id)then items:='[]'::jsonb;else
   -- Preserve the existing flat page ordering and offsets. Parent context is
   -- embedded even when that parent is outside the currently loaded page.
   select coalesce(jsonb_agg(social_private.comment_json(q.id)
    order by case when p_action='comments'then q.created_at end asc,
     case when p_action='comments'then q.id end asc,q.created_at desc,q.id desc),'[]'::jsonb)into items
   from(select c.id,c.created_at from public.social_comments c where c.work_id=v_work_id
    and not c.moderation_hidden and not social_private.social_blocked(c.author_id)
    order by case when p_action='comments'then c.created_at end asc,
     case when p_action='comments'then c.id end asc,c.created_at desc,c.id desc
    offset page_offset limit page_limit+case when p_action='comments'then 0 else 1 end)q;
  end if;
  if p_action='comments'then return items;end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)
    from jsonb_array_elements(items)with ordinality where ordinality<=page_limit),
   'hasMore',jsonb_array_length(items)>page_limit,'nextOffset',page_offset+least(jsonb_array_length(items),page_limit));
 elsif p_action='addComment'then
  actor:=moments_private.actor(true);
  perform social_private.social_api_before_threads_v1('ensureProfile','{}'::jsonb);
  if not social_private.public_author_allowed(actor)then raise exception 'social_publication_restricted'using errcode='42501';end if;
  v_work_id:=(p_payload->>'id')::uuid;
  v_body:=btrim(p_payload->>'body');
  if v_body is null or char_length(v_body)not between 1 and 500 then raise exception 'social_invalid_comment_body'using errcode='22023';end if;
  if(p_payload?'requestId'and jsonb_typeof(p_payload->'requestId')not in('string','null'))
   or(p_payload?'parentCommentId'and jsonb_typeof(p_payload->'parentCommentId')not in('string','null'))then
   raise exception 'social_invalid_comment_request_id'using errcode='22023';end if;
  request_id:=coalesce(nullif(p_payload->>'requestId','')::uuid,gen_random_uuid());
  if nullif(p_payload->>'parentCommentId','')is not null
   and not pg_input_is_valid(p_payload->>'parentCommentId','uuid')then
   raise exception 'social_comment_parent_unavailable'using errcode='42501';end if;
  parent_id:=nullif(p_payload->>'parentCommentId','')::uuid;
  -- Parse handles in the body only: client-supplied recipient IDs are ignored.
  -- Lowercase lookup keeps @ALICE equivalent to @alice and excludes emails.
  select coalesce(array_agg(h order by first_at),'{}'::text[])into handles from(
   select match[2]h,min(ordinality)first_at from regexp_matches(lower(v_body),
    '(^|[^a-z0-9_.@])@([a-z0-9._]{3,24})(?=$|[^a-z0-9._])','g')with ordinality r(match,ordinality)
   group by match[2])q;
  if cardinality(handles)>5 then raise exception 'social_comment_mentions_limit'using errcode='22023';end if;
  -- Match block/follow's identity order before taking a work lock. These are
  -- the identities referenced by the comment and mention foreign keys.
  perform 1 from public.social_profiles p where p.user_id=actor or p.handle=any(handles)
   order by p.user_id for key share;
  select *into work from public.social_works w where w.id=v_work_id
   and social_private.public_work_visible(w.id)and not social_private.social_blocked(w.author_id)for update;
  if not found then raise exception 'social_work_unavailable'using errcode='42501';end if;
  -- A lock wait can outlive the visibility snapshot used by the SELECT. Check
  -- again after the lock, before creating a comment or any notification.
  if work.status<>'published'or not social_private.public_work_visible(work.id)
   or social_private.social_blocked(work.author_id)then
   raise exception 'social_work_unavailable'using errcode='42501';end if;
  if not social_private.public_author_allowed(actor)then raise exception 'social_publication_restricted'using errcode='42501';end if;
  select *into item from public.social_comments c where c.id=request_id for update;
  if found then
   if item.author_id<>actor or item.work_id<>v_work_id or item.body is distinct from v_body
    or item.parent_comment_id is distinct from parent_id then
    raise exception 'social_comment_request_mismatch'using errcode='22023';end if;
   return social_private.comment_json(item.id);
  end if;
  if parent_id is not null then
   select *into parent from public.social_comments c where c.id=parent_id and c.work_id=v_work_id
    and not c.moderation_hidden and not social_private.social_blocked(c.author_id)for share;
   if not found then raise exception 'social_comment_parent_unavailable'using errcode='42501';end if;
   root_id:=coalesce(parent.root_comment_id,parent.id);
   select *into root from public.social_comments c where c.id=root_id and c.work_id=v_work_id
    and c.parent_comment_id is null and not c.moderation_hidden and not social_private.social_blocked(c.author_id)for share;
   if not found then raise exception 'social_comment_parent_unavailable'using errcode='42501';end if;
  end if;
  perform social_private.charge_rate(actor,'comment');
  insert into public.social_comments(id,work_id,author_id,body,parent_comment_id,root_comment_id)
   values(request_id,v_work_id,actor,v_body,parent_id,root_id)on conflict(id)do nothing returning *into item;
  if not found then raise exception 'social_comment_request_mismatch'using errcode='22023';end if;
  foreach v_handle in array handles loop
   select p.user_id into target from public.social_profiles p join auth.users u on u.id=p.user_id
    where p.handle=v_handle and not social_private.social_blocked(p.user_id)
     and social_private.public_author_allowed(p.user_id)and not u.is_anonymous and u.deleted_at is null
     and(u.banned_until is null or u.banned_until<=statement_timestamp())
     and not exists(select 1 from public.social_blocks b where
      (b.owner_id=p.user_id and b.target_id=work.author_id)or(b.owner_id=work.author_id and b.target_id=p.user_id));
   if target is not null then
    insert into social_private.comment_mentions(comment_id,target_id,handle,position)values(request_id,target,v_handle,v_position);
    v_position:=v_position+1;
   end if;
  end loop;
  -- The insert trigger handles the owner/reply recipient. This pass also sees
  -- the validated mention ledger; recipient/event uniqueness prevents repeats.
  perform private.notify_social_comment(request_id);
  return social_private.comment_json(request_id);
 end if;
 return social_private.social_api_before_threads_v1(p_action,p_payload);
end;$$;
revoke all on function social_private.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb)to anon,authenticated;
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb)returns jsonb
language sql security invoker set search_path='' as $$select social_private.social_api(p_action,p_payload)$$;
revoke all on function public.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb)to anon,authenticated;

create function private.social_comment_recipient_allowed(p_comment uuid,p_recipient uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_comments c join public.social_works w on w.id=c.work_id
  join auth.users writer on writer.id=c.author_id join auth.users recipient on recipient.id=p_recipient
  where c.id=p_comment and not c.moderation_hidden and c.author_id<>p_recipient
   and social_private.public_work_visible(w.id)and social_private.public_author_allowed(c.author_id)
   and social_private.public_author_allowed(p_recipient)
   and writer.deleted_at is null and not writer.is_anonymous and(writer.banned_until is null or writer.banned_until<=statement_timestamp())
   and recipient.deleted_at is null and not recipient.is_anonymous and(recipient.banned_until is null or recipient.banned_until<=statement_timestamp())
   and not exists(select 1 from public.social_blocks b where
    (b.owner_id=c.author_id and b.target_id=p_recipient)or(b.owner_id=p_recipient and b.target_id=c.author_id)
    or(b.owner_id=w.author_id and b.target_id=p_recipient)or(b.owner_id=p_recipient and b.target_id=w.author_id))
   and(w.author_id=p_recipient or exists(select 1 from public.social_comments parent
     where parent.id=c.parent_comment_id and parent.work_id=c.work_id and parent.author_id=p_recipient and not parent.moderation_hidden)
    or exists(select 1 from social_private.comment_mentions m where m.comment_id=c.id and m.target_id=p_recipient)))
$$;
revoke all on function private.social_comment_recipient_allowed(uuid,uuid)from public,anon,authenticated,service_role;

create function private.notify_social_comment(p_comment uuid)returns void
language plpgsql security definer set search_path='' as $$
declare item public.social_comments;work public.social_works;target uuid;context text;
begin
 select *into item from public.social_comments where id=p_comment;
 if not found then return;end if;
 select *into work from public.social_works where id=item.work_id;
 for target in select work.author_id union select c.author_id from public.social_comments c
   where c.id=item.parent_comment_id and c.work_id=item.work_id and not c.moderation_hidden
  union select m.target_id from social_private.comment_mentions m where m.comment_id=item.id
 loop
  if not private.social_comment_recipient_allowed(item.id,target)then continue;end if;
  context:=case when target=work.author_id then 'work'
   when exists(select 1 from public.social_comments c where c.id=item.parent_comment_id and c.author_id=target)then'reply'else'mention'end;
  insert into public.notifications(user_id,type,category,title,body,deeplink,data,event_key)
  values(target,'social_comment','comment',case context when'work'then'내 공개 작품에 새 댓글이 달렸어요'
    when'reply'then'내 댓글에 답글이 달렸어요'else'댓글에서 나를 언급했어요'end,
   '스냅핏에서 댓글을 확인해 보세요.','snapfit://work?workId='||work.id::text||'&comments=1',
   jsonb_build_object('workId',work.id,'commentId',item.id,'showComments',true)
    ||case when context='work'then'{}'::jsonb else jsonb_build_object('commentContext',context)end,
   'social:comment:'||item.id::text)on conflict do nothing;
 end loop;
end;$$;
revoke all on function private.notify_social_comment(uuid)from public,anon,authenticated,service_role;

create or replace function private.social_comment_notification()returns trigger
language plpgsql security definer set search_path='' as $$
begin perform private.notify_social_comment(new.id);return new;end;$$;
revoke all on function private.social_comment_notification()from public,anon,authenticated,service_role;

-- Delivery rechecks every target from authoritative comment relationships;
-- deleting a parent, withdrawing the work or blocking either party cancels it.
create or replace function private.social_comment_push_allowed(p_notification_id bigint)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.notifications n join public.social_comments c
  on c.id=case when pg_input_is_valid(n.data->>'commentId','uuid')then(n.data->>'commentId')::uuid else null end
  where n.id=p_notification_id and n.type='social_comment'and n.category='comment'
   and c.work_id::text=n.data->>'workId'and private.social_comment_recipient_allowed(c.id,n.user_id))
$$;
revoke all on function private.social_comment_push_allowed(bigint)from public,anon,authenticated,service_role;

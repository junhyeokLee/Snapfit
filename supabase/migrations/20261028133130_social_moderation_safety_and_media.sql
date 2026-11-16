-- Moderation is explicit operator action. Report counts never hide content.
-- Original albums, private journal records, points and entitlements are intact.
alter table public.social_profiles add column moderation_hidden boolean not null default false;
alter table public.social_works add column moderation_hidden boolean not null default false;
alter table public.social_comments add column moderation_hidden boolean not null default false;

create table social_private.content_reports(
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references auth.users(id) on delete cascade,
 target_kind text not null check(target_kind in('work','comment','user')),
 target_id uuid not null,
 reason text not null check(reason in('spam','harassment','privacy','inappropriate','copyright','other')),
 details text not null default '' check(char_length(details)<=500),
 request_id uuid not null,
 status text not null default 'open' check(status in('open','hidden','dismissed')),
 revision integer not null default 1 check(revision>0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 resolved_by uuid references auth.users(id) on delete set null,
 resolved_at timestamptz,
 internal_note text not null default '' check(char_length(internal_note)<=1000),
 unique(reporter_id,request_id),unique(reporter_id,target_kind,target_id)
);
create index social_reports_queue_idx on social_private.content_reports(status,created_at desc,id desc);
create index social_reports_resolver_idx on social_private.content_reports(resolved_by) where resolved_by is not null;
create table social_private.content_source_blocks(
 owner_id uuid not null references auth.users(id) on delete cascade,
 source_kind text not null check(source_kind in('album','moment')),
 source_id text not null,
 report_id uuid references social_private.content_reports(id) on delete set null,
 created_at timestamptz not null default clock_timestamp(),
 primary key(owner_id,source_kind,source_id)
);
create index social_source_block_report_idx on social_private.content_source_blocks(report_id) where report_id is not null;
create table social_private.safety_policy(
 singleton boolean primary key default true check(singleton),
 comment_per_minute integer not null default 12 check(comment_per_minute>0),
 comment_per_day integer not null default 120 check(comment_per_day>0),
 publication_per_hour integer not null default 12 check(publication_per_hour>0),
 publication_per_day integer not null default 60 check(publication_per_day>0),
 follow_per_minute integer not null default 40 check(follow_per_minute>0),
 follow_per_day integer not null default 400 check(follow_per_day>0),
 report_per_day integer not null default 10 check(report_per_day>0),
 max_active_snapshot_bytes bigint not null default 1073741824 check(max_active_snapshot_bytes>0),
 max_active_snapshot_pages integer not null default 4000 check(max_active_snapshot_pages>0)
);
insert into social_private.safety_policy(singleton)values(true);
create table social_private.rate_windows(
 actor_id uuid not null references auth.users(id) on delete cascade,
 action text not null check(action in('comment','publication','follow','report')),
 window_seconds integer not null check(window_seconds in(60,3600,86400)),
 window_start timestamptz not null,
 request_count integer not null check(request_count>0),
 primary key(actor_id,action,window_seconds,window_start)
);
create index social_rate_expiry_idx on social_private.rate_windows(window_start);
alter table social_private.content_reports enable row level security;
alter table social_private.content_source_blocks enable row level security;
alter table social_private.safety_policy enable row level security;
alter table social_private.rate_windows enable row level security;
-- RPC-only safety ledgers intentionally have no direct read/write policies.
revoke all on social_private.content_reports,social_private.content_source_blocks,
 social_private.safety_policy,social_private.rate_windows from public,anon,authenticated,service_role;

create function social_private.public_author_allowed(p_user uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_profiles p where p.user_id=p_user and not p.moderation_hidden)
$$;
create function social_private.work_restricted(p_work uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_works w where w.id=p_work and(w.moderation_hidden
  or not social_private.public_author_allowed(w.author_id)
  or exists(select 1 from social_private.content_source_blocks sb where sb.owner_id=w.author_id and sb.source_kind=w.kind
   and sb.source_id=case when w.kind='moment'then(select b.record_id::text from social_private.moment_publication_sources b where b.work_id=w.id)
    else(select b.source_album_id::text from social_private.social_publication_sources b where b.work_id=w.id)end)))
$$;
create or replace function social_private.social_blocked(p_user uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select (p_user is distinct from auth.uid() and not social_private.public_author_allowed(p_user))
  or exists(select 1 from public.social_blocks b where
   (b.owner_id=auth.uid() and b.target_id=p_user)or(b.target_id=auth.uid() and b.owner_id=p_user))
$$;
create or replace function social_private.social_visible(p_work uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_works w where w.id=p_work
  and((w.author_id=auth.uid() and w.status<>'deleted')or(w.status='published' and not social_private.work_restricted(w.id)
   and(w.kind='album' or social_private.moment_source_current(w.id))))
  and not social_private.social_blocked(w.author_id))
$$;
create function social_private.public_work_visible(p_work uuid)returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.social_works w where w.id=p_work and w.status='published' and not social_private.work_restricted(w.id)
  and(w.kind='album' or social_private.moment_source_current(w.id)))
$$;
drop policy social_comments_read on public.social_comments;
create policy social_comments_read on public.social_comments for select to anon,authenticated
 using(not moderation_hidden and social_private.social_visible(work_id)and not social_private.social_blocked(author_id));

create function social_private.require_moderator()returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=moments_private.actor(true);
begin
 if not exists(select 1 from auth.users u where u.id=v_actor and u.raw_app_meta_data->>'role'='admin')then
  raise exception 'social_admin_required' using errcode='42501';
 end if;
 return v_actor;
end;
$$;
create function social_private.charge_rate(p_actor uuid,p_action text)returns void
language plpgsql volatile security definer set search_path='' as $$
declare policy social_private.safety_policy; seconds integer; maximum integer; start_at timestamptz; used integer;
 v_now timestamptz:=moments_private.server_now();
begin
 select * into policy from social_private.safety_policy where singleton;
 for seconds,maximum in select * from(values
  (60,case p_action when 'comment' then policy.comment_per_minute when 'follow' then policy.follow_per_minute else null end),
  (3600,case when p_action='publication' then policy.publication_per_hour else null end),
  (86400,case p_action when 'comment' then policy.comment_per_day when 'publication' then policy.publication_per_day when 'follow' then policy.follow_per_day when 'report' then policy.report_per_day else null end))windows(seconds,maximum)
 loop
  if maximum is null then continue;end if;
  start_at:=to_timestamp(floor(extract(epoch from v_now)/seconds)*seconds);
  insert into social_private.rate_windows(actor_id,action,window_seconds,window_start,request_count)
   values(p_actor,p_action,seconds,start_at,1)
   on conflict(actor_id,action,window_seconds,window_start)do update set request_count=social_private.rate_windows.request_count+1
   returning request_count into used;
  if used>maximum then raise exception 'social_rate_limited' using errcode='PT429';end if;
 end loop;
 -- Bounded per-actor maintenance, without a recurring privileged client job.
 delete from social_private.rate_windows where actor_id=p_actor and window_start<v_now-interval '2 days';
end;
$$;
create function social_private.check_snapshot_quota(p_actor uuid,p_work uuid)returns void
language plpgsql stable security definer set search_path='' as $$
declare policy social_private.safety_policy; active_pages bigint; active_bytes bigint; pending_pages bigint; pending_bytes bigint;
begin
 select * into policy from social_private.safety_policy where singleton;
 select count(*),coalesce(sum((o.metadata->>'size')::bigint),0)into active_pages,active_bytes
 from public.social_works w join public.social_work_pages p on p.work_id=w.id
 left join storage.objects o on o.bucket_id='social-snapshots' and o.name=p.storage_path
 where w.author_id=p_actor and w.id<>p_work and social_private.public_work_visible(w.id);
 select count(*),coalesce(sum((o.metadata->>'size')::bigint),0)into pending_pages,pending_bytes
 from public.social_work_pages p left join storage.objects o on o.bucket_id='social-snapshots' and o.name=p.storage_path where p.work_id=p_work;
 if active_pages+pending_pages>policy.max_active_snapshot_pages or active_bytes+pending_bytes>policy.max_active_snapshot_bytes then
  raise exception 'social_public_snapshot_quota_exceeded' using errcode='22023';
 end if;
end;
$$;
create function social_private.report_json(p_id uuid,p_admin boolean default false)returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'targetKind',r.target_kind,'targetId',r.target_id,'reason',r.reason,'details',r.details,
  'status',r.status,'revision',r.revision,'createdAt',r.created_at,'updatedAt',r.updated_at,'resolvedAt',r.resolved_at,
  'resolutionNote',case when p_admin and r.status<>'open'then nullif(r.internal_note,'')else null end,
  'targetWorkId',case when r.target_kind='work'then r.target_id when r.target_kind='comment'then(select c.work_id from public.social_comments c where c.id=r.target_id)else null end,
  'targetPreview',case when p_admin then case r.target_kind
   when 'work'then(select jsonb_build_object('title',w.title,'caption',w.caption,'kind',w.kind,'author',social_private.social_profile_json(w.author_id))from public.social_works w where w.id=r.target_id and social_private.public_work_visible(w.id))
   when 'comment'then(select jsonb_build_object('body',c.body,'author',social_private.social_profile_json(c.author_id))from public.social_comments c where c.id=r.target_id and not c.moderation_hidden and social_private.public_author_allowed(c.author_id)and social_private.public_work_visible(c.work_id))
   else case when social_private.public_author_allowed(r.target_id)then social_private.social_profile_json(r.target_id)else null end end else null end)
  ||case when p_admin then jsonb_build_object('reporterId',r.reporter_id,'resolvedBy',r.resolved_by)else '{}'::jsonb end
 from social_private.content_reports r where r.id=p_id
$$;

alter function social_private.social_api(text,jsonb)rename to social_api_collections_v1;
revoke all on function social_private.social_api_collections_v1(text,jsonb)from public,anon,authenticated,service_role;
create function social_private.social_api(p_action text,p_payload jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_target uuid; v_id uuid; v_request uuid; v_kind text; v_reason text; v_details text;
 v_report social_private.content_reports; v_work public.social_works; v_binding social_private.moment_publication_sources;
 v_owner uuid; v_source text; v_decision text; v_expected integer; v_now timestamptz:=moments_private.server_now();
 v_limit integer; v_offset integer; v_result jsonb; v_items jsonb; v_desired boolean; v_existing boolean;
begin
 if p_action='reportContent' then
  v_actor:=moments_private.actor(true);v_kind:=p_payload->>'targetKind';v_target:=(p_payload->>'targetId')::uuid;
  v_request:=(p_payload->>'requestId')::uuid;v_reason:=p_payload->>'reason';v_details:=btrim(coalesce(p_payload->>'details',''));
  if v_kind is null or v_kind not in('work','comment','user')or v_target is null or v_request is null
   or v_reason is null or v_reason not in('spam','harassment','privacy','inappropriate','copyright','other')or char_length(v_details)>500 then
   raise exception 'social_invalid_report' using errcode='22023';end if;
  select * into v_report from social_private.content_reports where reporter_id=v_actor and request_id=v_request;
  if found then
   if v_report.target_kind<>v_kind or v_report.target_id<>v_target or v_report.reason<>v_reason or v_report.details<>v_details then raise exception 'social_report_request_mismatch' using errcode='22023';end if;
   return social_private.report_json(v_report.id);
  end if;
  select * into v_report from social_private.content_reports where reporter_id=v_actor and target_kind=v_kind and target_id=v_target;
  if found then return social_private.report_json(v_report.id);end if;
  if v_kind='work' then
   v_existing:=social_private.public_work_visible(v_target);
  elsif v_kind='comment' then
   select exists(select 1 from public.social_comments c where c.id=v_target and not c.moderation_hidden and social_private.public_author_allowed(c.author_id)and social_private.public_work_visible(c.work_id))into v_existing;
  else v_existing:=social_private.public_author_allowed(v_target)and v_target<>v_actor;end if;
  if not v_existing then raise exception 'social_report_target_unavailable' using errcode='42501';end if;
  perform social_private.charge_rate(v_actor,'report');
  insert into social_private.content_reports(reporter_id,target_kind,target_id,reason,details,request_id)
   values(v_actor,v_kind,v_target,v_reason,v_details,v_request)returning id into v_id;
  return social_private.report_json(v_id);
 elsif p_action in('ownReportsPage','adminReportsPage')then
  v_actor:=case when p_action='adminReportsPage' then social_private.require_moderator()else moments_private.actor()end;
  v_offset:=coalesce((p_payload->>'offset')::integer,0);v_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,20),1),50);
  if v_offset<0 or v_offset>10000 then raise exception 'social_invalid_page_offset' using errcode='22023';end if;
  if coalesce(p_payload->>'status','all')not in('all','open','hidden','dismissed')then raise exception 'social_invalid_report_status' using errcode='22023';end if;
  select coalesce(jsonb_agg(social_private.report_json(q.id,p_action='adminReportsPage')order by q.created_at desc,q.id desc),'[]'::jsonb)into v_items
   from(select r.id,r.created_at from social_private.content_reports r where(p_action='adminReportsPage'or r.reporter_id=v_actor)
    and(coalesce(p_payload->>'status','all')='all'or r.status=p_payload->>'status')order by r.created_at desc,r.id desc offset v_offset limit v_limit+1)q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)from jsonb_array_elements(v_items)with ordinality where ordinality<=v_limit),
   'hasMore',jsonb_array_length(v_items)>v_limit,'nextOffset',v_offset+least(jsonb_array_length(v_items),v_limit));
 elsif p_action='resolveReport' then
  v_actor:=social_private.require_moderator();v_id:=(p_payload->>'id')::uuid;v_decision:=p_payload->>'decision';v_expected:=(p_payload->>'expectedRevision')::integer;
  v_details:=btrim(coalesce(p_payload->>'note',p_payload->>'resolutionNote',''));
  if v_decision is null or v_decision not in('hide','dismiss')or v_expected is null or char_length(v_details)>1000 then raise exception 'social_invalid_report_resolution' using errcode='22023';end if;
  select * into v_report from social_private.content_reports where id=v_id for update;
  if not found then raise exception 'social_report_unavailable' using errcode='42501';end if;
  if v_report.status=(case when v_decision='hide'then'hidden'else'dismissed'end)and v_report.internal_note=v_details and v_expected in(v_report.revision,v_report.revision-1)then return social_private.report_json(v_id,true);end if;
  if v_report.status<>'open'or v_report.revision<>v_expected then raise exception 'social_report_changed' using errcode='PT409';end if;
  if v_decision='hide' then
   if v_report.target_kind='work' then
    select * into v_work from public.social_works where id=v_report.target_id;
    if found then
     if v_work.kind='moment'then
      select record_id::text into v_source from social_private.moment_publication_sources where work_id=v_work.id;
     else select source_album_id::text into v_source from social_private.social_publication_sources where work_id=v_work.id;end if;
     -- Match record editing's state-before-work lock order. An operator never
     -- holds a work row while waiting for the publication fence it protects.
     if v_work.kind='moment'and v_source is not null then update moments_private.publications set revision=revision+1,current_work_id=null where record_id=v_source::uuid;
     else update moments_private.publications set revision=revision+1,current_work_id=null where current_work_id=v_work.id;end if;
     if v_source is not null then insert into social_private.content_source_blocks(owner_id,source_kind,source_id,report_id)values(v_work.author_id,v_work.kind,v_source,v_id)on conflict(owner_id,source_kind,source_id)do nothing;end if;
     update public.social_works affected set moderation_hidden=true,status=case when affected.status='draft'then'deleted'else'private'end
      where affected.status<>'deleted'and(affected.id=v_work.id or(v_source is not null and affected.author_id=v_work.author_id and affected.kind=v_work.kind
       and case when v_work.kind='moment'then exists(select 1 from social_private.moment_publication_sources binding where binding.work_id=affected.id and binding.record_id::text=v_source)
        else exists(select 1 from social_private.social_publication_sources binding where binding.work_id=affected.id and binding.source_album_id::text=v_source)end));
    end if;
   elsif v_report.target_kind='comment'then update public.social_comments set moderation_hidden=true where id=v_report.target_id;
   else
    update moments_private.publications set revision=revision+1,current_work_id=null where owner_id=v_report.target_id;
    update public.social_profiles set moderation_hidden=true where user_id=v_report.target_id;
    update public.social_works set moderation_hidden=true,status=case when status='draft'then'deleted'else'private'end where author_id=v_report.target_id and status<>'deleted';
   end if;
  end if;
  update social_private.content_reports set status=case when v_decision='hide'then'hidden'else'dismissed'end,revision=revision+1,updated_at=v_now,resolved_at=v_now,resolved_by=v_actor,internal_note=v_details where id=v_id;
  return social_private.report_json(v_id,true);
 elsif p_action in('comments','commentsPage')then
  v_id:=(p_payload->>'id')::uuid;
  v_offset:=case when p_action='commentsPage'then coalesce((p_payload->>'offset')::integer,0)else 0 end;
  v_limit:=case when p_action='commentsPage'then least(greatest(coalesce((p_payload->>'limit')::integer,12),1),30)else 100 end;
  if v_offset<0 or v_offset>10000 then raise exception 'social_invalid_page_offset' using errcode='22023';end if;
  if not social_private.social_visible(v_id)then v_items:='[]'::jsonb;else
   select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'body',q.body,'createdAt',q.created_at,'author',social_private.social_profile_json(q.author_id))
    order by case when p_action='comments'then q.created_at end asc,case when p_action='comments'then q.id end asc,q.created_at desc,q.id desc),'[]'::jsonb)into v_items
    from(select c.* from public.social_comments c where c.work_id=v_id and not c.moderation_hidden and not social_private.social_blocked(c.author_id)
     order by case when p_action='comments'then c.created_at end asc,case when p_action='comments'then c.id end asc,c.created_at desc,c.id desc offset v_offset limit v_limit+case when p_action='comments'then 0 else 1 end)q;
  end if;
  if p_action='comments'then return v_items;end if;
  v_offset:=coalesce(v_offset,coalesce((p_payload->>'offset')::integer,0));v_limit:=coalesce(v_limit,least(greatest(coalesce((p_payload->>'limit')::integer,12),1),30));
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)from jsonb_array_elements(v_items)with ordinality where ordinality<=v_limit),
   'hasMore',jsonb_array_length(v_items)>v_limit,'nextOffset',v_offset+least(jsonb_array_length(v_items),v_limit));
 end if;

 if p_action in('addComment','beginPublication','beginMomentPublication','setFollowing','toggleFollow','finalizePublication','visibility')then
  v_actor:=moments_private.actor(true);
  if exists(select 1 from public.social_profiles p where p.user_id=v_actor and p.moderation_hidden)
   and not(p_action='visibility'and not coalesce((p_payload->>'published')::boolean,false))then raise exception 'social_publication_restricted' using errcode='42501';end if;
  if p_action='addComment'then
   v_request:=nullif(p_payload->>'requestId','')::uuid;
   if v_request is null or not exists(select 1 from public.social_comments c where c.id=v_request)then perform social_private.charge_rate(v_actor,'comment');end if;
  elsif p_action in('beginPublication','beginMomentPublication')then
   v_request:=nullif(p_payload->>'requestId','')::uuid;
   v_kind:=case when p_action='beginPublication'then'album'else'moment'end;
   v_source:=case when v_kind='album'then((p_payload->>'albumId')::bigint)::text else((p_payload->>'recordId')::uuid)::text end;
   if exists(select 1 from social_private.content_source_blocks sb where sb.owner_id=v_actor and sb.source_kind=v_kind and sb.source_id=v_source)then raise exception 'social_publication_restricted' using errcode='42501';end if;
   select case when v_kind='album'then exists(select 1 from social_private.social_publication_sources q where q.owner_id=v_actor and q.request_id=v_request)
    else exists(select 1 from social_private.moment_publication_sources q where q.owner_id=v_actor and q.request_id=v_request)end into v_existing;
   if not v_existing then perform social_private.charge_rate(v_actor,'publication');end if;
  elsif p_action in('setFollowing','toggleFollow')then
   v_target:=(p_payload->>'userId')::uuid;
   select exists(select 1 from public.social_follows f where f.follower_id=v_actor and f.following_id=v_target)into v_existing;
   if p_action='toggleFollow'or v_existing is distinct from(p_payload->>'following')::boolean then perform social_private.charge_rate(v_actor,'follow');end if;
  else
   select * into v_work from public.social_works where id=(p_payload->>'id')::uuid and author_id=v_actor;
   v_desired:=p_action='finalizePublication'or coalesce((p_payload->>'published')::boolean,false);
   if v_desired and v_work.id is not null then
    if social_private.work_restricted(v_work.id)then raise exception 'social_publication_restricted' using errcode='42501';end if;
    if(p_action='finalizePublication'and v_work.status='draft')or(p_action='visibility'and v_work.status='private')then
     perform social_private.check_snapshot_quota(v_actor,v_work.id);
     if p_action='visibility'then perform social_private.charge_rate(v_actor,'publication');end if;
    end if;
   end if;
  end if;
 end if;
 return social_private.social_api_collections_v1(p_action,p_payload);
end;
$$;
revoke all on function social_private.public_author_allowed(uuid),social_private.work_restricted(uuid),social_private.public_work_visible(uuid),social_private.require_moderator(),social_private.charge_rate(uuid,text),social_private.check_snapshot_quota(uuid,uuid),social_private.report_json(uuid,boolean)from public,anon,authenticated,service_role;
revoke all on function social_private.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb)to anon,authenticated;
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb)returns jsonb
language sql security invoker set search_path='' as $$select social_private.social_api(p_action,p_payload)$$;
revoke all on function public.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb)to anon,authenticated;

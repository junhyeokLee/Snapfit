-- Accepted membership is the only shared grant. Client writes use atomic APIs.
create schema if not exists album_private;
revoke all on schema album_private from public,anon,authenticated;
grant usage on schema album_private to authenticated,service_role;

create function album_private.can_access_album(p_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_admin() or exists(
  select 1 from public.albums a where a.id=p_id and (a.owner_id=auth.uid() or exists(
   select 1 from public.album_members m where m.album_id=a.id and m.user_id=auth.uid() and m.status='ACCEPTED'))))
$$;
create function album_private.can_edit_album(p_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.is_admin() or exists(
  select 1 from public.albums a where a.id=p_id and (a.owner_id=auth.uid() or exists(
   select 1 from public.album_members m where m.album_id=a.id and m.user_id=auth.uid() and m.status='ACCEPTED' and m.role='EDITOR'))))
$$;
revoke all on function album_private.can_access_album(bigint),album_private.can_edit_album(bigint) from public,anon,authenticated;
grant execute on function album_private.can_access_album(bigint),album_private.can_edit_album(bigint) to authenticated,service_role;
create or replace function public.can_access_album(target_album_id bigint) returns boolean
language sql stable security invoker set search_path='' as $$select album_private.can_access_album(target_album_id)$$;
create or replace function public.can_edit_album(target_album_id bigint) returns boolean
language sql stable security invoker set search_path='' as $$select album_private.can_edit_album(target_album_id)$$;
revoke all on function public.can_access_album(bigint),public.can_edit_album(bigint) from public,anon,authenticated;
grant execute on function public.can_access_album(bigint),public.can_edit_album(bigint) to authenticated,service_role;

drop policy if exists albums_update_member_or_admin on public.albums;
create policy albums_update_member_or_admin on public.albums for update to authenticated
 using(public.can_edit_album(id)) with check(public.can_edit_album(id));
drop policy if exists album_pages_member_crud on public.album_pages;
drop policy if exists album_pages_member_read on public.album_pages;
drop policy if exists album_pages_editor_insert on public.album_pages;
drop policy if exists album_pages_editor_update on public.album_pages;
drop policy if exists album_pages_editor_delete on public.album_pages;
create policy album_pages_member_read on public.album_pages for select to authenticated using(public.can_access_album(album_id));
-- The current editor saves its complete document in albums.cover_layers_json.
-- Legacy per-page direct writes cannot bypass the revision checked document API.
revoke insert,update,delete on public.album_pages from anon,authenticated;
revoke insert,update,delete,select on public.album_members from anon,authenticated;
grant select(id,album_id,user_id,role,status,created_at) on public.album_members to authenticated;
revoke all on public.album_invites from anon;
revoke insert,update,delete on public.album_invites from authenticated;

create function album_private.album_write_guard() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.id is distinct from old.id or new.owner_id is distinct from old.owner_id then
  if auth.uid() is not null then raise exception 'album_owner_change_forbidden' using errcode='42501'; end if;
 end if;
 if current_user in ('authenticated','anon') then
  if (to_jsonb(new)-array['updated_at','sort_order','locked_by_id','locked_by']) is distinct from
     (to_jsonb(old)-array['updated_at','sort_order','locked_by_id','locked_by']) then
   raise exception 'album_atomic_save_required' using errcode='42501';
  end if;
  if new.sort_order is distinct from old.sort_order and old.owner_id<>auth.uid() and not public.is_admin() then
   raise exception 'album_owner_required' using errcode='42501';
  end if;
  if new.locked_by_id is distinct from old.locked_by_id then
   if new.locked_by_id is not null and new.locked_by_id<>auth.uid() or
      old.locked_by_id is not null and old.locked_by_id<>auth.uid() then
    raise exception 'album_lock_conflict' using errcode='PT409';
   end if;
  end if;
 end if;
 return new;
end;
$$;
revoke all on function album_private.album_write_guard() from public,anon,authenticated;
drop trigger if exists albums_protect_owner on public.albums;
create trigger albums_collaboration_guard before update on public.albums for each row execute function album_private.album_write_guard();
create function album_private.album_touch_revision() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if (to_jsonb(new)-array['updated_at','sort_order','locked_by_id','locked_by']) is distinct from
    (to_jsonb(old)-array['updated_at','sort_order','locked_by_id','locked_by']) then
  new.updated_at:=greatest(clock_timestamp(),old.updated_at+interval '1 microsecond');
 else new.updated_at:=old.updated_at;
 end if;
 return new;
end;
$$;
revoke all on function album_private.album_touch_revision() from public,anon,authenticated;
drop trigger if exists albums_set_updated_at on public.albums;
create trigger albums_set_updated_at before update on public.albums for each row execute function album_private.album_touch_revision();

create function album_private.member_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare owner_id uuid; a_id bigint;
begin
 a_id:=case when tg_op='DELETE' then old.album_id else new.album_id end;
 select a.owner_id into owner_id from public.albums a where a.id=a_id for update;
 if tg_op='DELETE' then
  if old.user_id=owner_id and auth.uid() is not null then raise exception 'album_owner_membership_protected' using errcode='42501'; end if;
  return old;
 end if;
 if new.role='OWNER' and new.user_id is distinct from owner_id then raise exception 'album_owner_membership_protected' using errcode='42501'; end if;
 if tg_op='UPDATE' and (new.album_id<>old.album_id or new.user_id<>old.user_id or old.user_id=owner_id and (new.role<>'OWNER' or new.status<>'ACCEPTED')) then
  raise exception 'album_owner_membership_protected' using errcode='42501';
 end if;
 return new;
end;
$$;
revoke all on function album_private.member_guard() from public,anon,authenticated;
create trigger album_members_collaboration_guard before insert or update or delete on public.album_members for each row execute function album_private.member_guard();

-- Keep the service-only Edge API signature; serialize album before invite/member.
create or replace function public.accept_album_invite(p_token text,p_user_id uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare inv public.album_invites; a public.albums; membership public.album_members; v_album_id bigint;
begin
 if p_user_id is null or coalesce(p_token,'')='' then return jsonb_build_object('error','token_required','status',400); end if;
 select i.album_id into v_album_id from public.album_invites i where i.token=p_token;
 if not found then return jsonb_build_object('error','invite_not_found','status',404); end if;
 select * into a from public.albums where id=v_album_id for update;
 if not found then return jsonb_build_object('error','invite_not_found','status',404); end if;
 select * into inv from public.album_invites where token=p_token and album_invites.album_id=a.id for update;
 if not found then return jsonb_build_object('error','invite_not_found','status',404); end if;
 if inv.accepted_at is not null and inv.accepted_by is distinct from p_user_id then return jsonb_build_object('error','invite_used','status',409); end if;
 if inv.accepted_at is null and inv.expires_at<=now() then return jsonb_build_object('error','invite_expired','status',410); end if;
 if a.owner_id=p_user_id then return jsonb_build_object('albumId',a.id,'role','OWNER','success',true); end if;
 select * into membership from public.album_members m where m.album_id=a.id and m.user_id=p_user_id for update;
 if membership.status='ACCEPTED' then return jsonb_build_object('albumId',a.id,'role',case when membership.role='OWNER' then 'VIEWER' else membership.role end,'success',true); end if;
 if inv.accepted_at is not null then return jsonb_build_object('error','invite_used','status',409); end if;
 insert into public.album_members(album_id,user_id,role,status,invited_by,invite_token)
 values(a.id,p_user_id,inv.role,'ACCEPTED',inv.created_by,p_token)
 on conflict(album_id,user_id) do update set role=excluded.role,status='ACCEPTED',invited_by=excluded.invited_by,invite_token=excluded.invite_token;
 update public.album_invites set accepted_by=p_user_id,accepted_at=now() where token=p_token;
 return jsonb_build_object('albumId',a.id,'role',inv.role,'success',true);
end;
$$;
revoke all on function public.accept_album_invite(text,uuid) from public,anon,authenticated;
grant execute on function public.accept_album_invite(text,uuid) to service_role;

create table album_private.save_requests(
 actor_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 album_id bigint not null references public.albums(id) on delete cascade,
 request_fingerprint text not null check(char_length(request_fingerprint)=64),
 result jsonb not null,
 created_at timestamptz not null default clock_timestamp(),
 primary key(actor_id,request_id)
);
create index album_save_requests_album_idx on album_private.save_requests(album_id);
create index album_save_requests_recent_idx on album_private.save_requests(actor_id,album_id,created_at desc);
alter table album_private.save_requests enable row level security;
revoke all on album_private.save_requests from public,anon,authenticated;

create function album_private.member_json(p_album bigint,p_user uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',coalesce(m.id,0),'userId',p_user,'displayName',coalesce(p.display_name,case when a.owner_id=p_user then '앨범 소유자' else '앨범 참여자' end),
 'role',case when a.owner_id=p_user then 'OWNER' when m.role='OWNER' then 'VIEWER' else m.role end,'status',case when a.owner_id=p_user then 'ACCEPTED' else m.status end,'isOwner',a.owner_id=p_user)
 from public.albums a left join public.album_members m on m.album_id=a.id and m.user_id=p_user
 left join public.social_profiles p on p.user_id=p_user where a.id=p_album and (a.owner_id=p_user or m.user_id is not null)
$$;
revoke all on function album_private.member_json(bigint,uuid) from public,anon,authenticated;
create function album_private.collaboration_api(p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a public.albums; target uuid; v_role text; result jsonb; removed_count integer; revoked_tokens text[];
begin
 if actor is null then raise exception 'album_login_required' using errcode='42501'; end if;
 if nullif(p_payload->>'expectedActorId','') is not null and (p_payload->>'expectedActorId')::uuid<>actor then raise exception 'album_editor_session_changed' using errcode='42501'; end if;
 select * into a from public.albums where id=(p_payload->>'albumId')::bigint for update;
 if p_action='leave' then
  if found and actor=a.owner_id then raise exception 'album_owner_cannot_leave' using errcode='42501'; end if;
  delete from public.album_members where album_id=(p_payload->>'albumId')::bigint and user_id=actor;
  get diagnostics removed_count=row_count;
  if removed_count>0 then
   insert into public.notifications(user_id,type,category,title,body,deeplink,data) values(a.owner_id,'album_member_changed','invite','공유 앨범 알림','앨범 참여자가 나갔어요.','snapfit://album?albumId='||a.id,jsonb_build_object('albumId',a.id));
  end if;
  return 'true'::jsonb;
 end if;
 if not found or not album_private.can_access_album(a.id) then raise exception 'album_access_denied' using errcode='42501'; end if;
 if p_action='members' then
  return (select jsonb_agg(album_private.member_json(a.id,u.id) order by u.is_owner desc,u.id) from(
   select a.owner_id id,true is_owner union all select user_id,false from public.album_members where album_id=a.id and user_id<>a.owner_id and status='ACCEPTED')u);
 end if;
 if a.owner_id<>actor and not public.is_admin() then raise exception 'album_owner_required' using errcode='42501'; end if;
 if p_action='revokeInvites' then
  with revoked as(delete from public.album_invites where album_id=a.id and accepted_at is null returning token) select coalesce(array_agg(token),'{}') into revoked_tokens from revoked;
  delete from public.album_members where album_id=a.id and status='PENDING' and user_id<>a.owner_id and invite_token=any(revoked_tokens);
  return to_jsonb(cardinality(revoked_tokens));
 end if;
 target:=(p_payload->>'userId')::uuid;
 if target is null or target=a.owner_id then raise exception 'album_owner_membership_protected' using errcode='42501'; end if;
 if p_action='removeMember' then
  delete from public.album_members where album_id=a.id and user_id=target;get diagnostics removed_count=row_count;
  if removed_count>0 then
   insert into public.notifications(user_id,type,category,title,body,deeplink,data) values(target,'album_member_changed','invite','공유 앨범 알림','공유 앨범 참여가 해제되었어요.','snapfit://album?albumId='||a.id,jsonb_build_object('albumId',a.id));
  end if;
  return 'true'::jsonb;
 elsif p_action='setMemberRole' then
  v_role:=p_payload->>'role';
  if v_role is null or v_role not in('EDITOR','VIEWER') then raise exception 'album_invalid_role' using errcode='22023'; end if;
  update public.album_members set role=v_role where album_id=a.id and user_id=target and status='ACCEPTED';
  if not found then raise exception 'album_member_not_found' using errcode='22023'; end if;
  return album_private.member_json(a.id,target);
 end if;
 raise exception 'album_unknown_action' using errcode='22023';
end;
$$;
revoke all on function album_private.collaboration_api(text,jsonb) from public,anon,authenticated;
grant execute on function album_private.collaboration_api(text,jsonb) to authenticated;
create function public.album_collaboration(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$select album_private.collaboration_api(p_action,p_payload)$$;
revoke all on function public.album_collaboration(text,jsonb) from public,anon;
grant execute on function public.album_collaboration(text,jsonb) to authenticated;

create function album_private.save_album(p_album_id bigint,p_expected_updated_at timestamptz,p_changes jsonb,p_request_id uuid,p_expected_actor_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a public.albums; saved album_private.save_requests; result jsonb; fingerprint text; field text;
begin
 if actor is null then raise exception 'album_login_required' using errcode='42501'; end if;
 if p_expected_actor_id is not null and p_expected_actor_id<>actor then raise exception 'album_editor_session_changed' using errcode='42501'; end if;
 if jsonb_typeof(p_changes) is distinct from 'object' or exists(select 1 from jsonb_object_keys(p_changes) k where k not in('title','ratio','cover_layers_json','cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme','target_pages')) then
  raise exception 'album_invalid_changes' using errcode='22023';
 end if;
 if p_expected_updated_at is null then raise exception 'album_revision_required' using errcode='22023'; end if;
 if p_request_id is not null then perform 1 from auth.users where id=actor for no key update; end if;
 select * into a from public.albums where id=p_album_id for update;
 if not found or not album_private.can_edit_album(a.id) then raise exception 'album_edit_denied' using errcode='42501'; end if;
 if octet_length(p_changes::text)>8388608 then raise exception 'album_document_too_large' using errcode='22023'; end if;
 foreach field in array array['title','ratio','cover_layers_json'] loop
  if p_changes?field and jsonb_typeof(p_changes->field) is distinct from 'string' then raise exception 'album_invalid_changes' using errcode='22023'; end if;
 end loop;
 foreach field in array array['cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme'] loop
  if p_changes?field and jsonb_typeof(p_changes->field) not in('string','null') then raise exception 'album_invalid_changes' using errcode='22023'; end if;
 end loop;
 if p_changes?'ratio' and char_length(p_changes->>'ratio') not between 1 and 50 then raise exception 'album_invalid_changes' using errcode='22023'; end if;
 if p_changes?'target_pages' and (jsonb_typeof(p_changes->'target_pages') is distinct from 'number' or (p_changes->>'target_pages') !~ '^(0|[1-9][0-9]*)$') then raise exception 'album_invalid_target_pages' using errcode='22023'; end if;
 fingerprint:=encode(sha256(convert_to(jsonb_build_object('albumId',p_album_id,'expectedUpdatedAt',p_expected_updated_at,'changes',p_changes)::text,'UTF8')),'hex');
 delete from album_private.save_requests where actor_id=actor and created_at<clock_timestamp()-interval '24 hours';
 if p_request_id is not null then
  -- Actor lock also serializes accidental reuse of one key across different albums.
  select * into saved from album_private.save_requests where actor_id=actor and request_id=p_request_id;
  if found then
   if saved.request_fingerprint<>fingerprint or saved.album_id<>p_album_id then raise exception 'album_save_request_mismatch' using errcode='22023'; end if;
   return saved.result;
  end if;
 end if;
 if p_changes?'title' and (char_length(btrim(p_changes->>'title')) not between 1 and 80) and (p_changes->>'title') is distinct from a.title then raise exception 'album_invalid_title' using errcode='22023'; end if;
 if p_changes?'target_pages' and (p_changes->>'target_pages')::numeric not between 1 and 80 and (p_changes->>'target_pages')::numeric is distinct from a.target_pages::numeric then raise exception 'album_invalid_target_pages' using errcode='22023'; end if;
 if a.updated_at is distinct from p_expected_updated_at then raise exception 'album_revision_conflict' using errcode='PT409'; end if;
 update public.albums set
 title=case when p_changes?'title' then p_changes->>'title' else a.title end,
 ratio=case when p_changes?'ratio' then p_changes->>'ratio' else a.ratio end,
 cover_layers_json=case when p_changes?'cover_layers_json' then p_changes->>'cover_layers_json' else a.cover_layers_json end,
 cover_image_url=case when p_changes?'cover_image_url' then p_changes->>'cover_image_url' else a.cover_image_url end,
 cover_thumbnail_url=case when p_changes?'cover_thumbnail_url' then p_changes->>'cover_thumbnail_url' else a.cover_thumbnail_url end,
 cover_original_url=case when p_changes?'cover_original_url' then p_changes->>'cover_original_url' else a.cover_original_url end,
 cover_preview_url=case when p_changes?'cover_preview_url' then p_changes->>'cover_preview_url' else a.cover_preview_url end,
 cover_theme=case when p_changes?'cover_theme' then p_changes->>'cover_theme' else a.cover_theme end,
 target_pages=case when p_changes?'target_pages' then (p_changes->>'target_pages')::integer else a.target_pages end
 where id=a.id returning to_jsonb(albums.*) into result;
 if p_request_id is not null then insert into album_private.save_requests(actor_id,request_id,album_id,request_fingerprint,result) values(actor,p_request_id,a.id,fingerprint,result);
  delete from album_private.save_requests where actor_id=actor and album_id=a.id and request_id in(select request_id from album_private.save_requests where actor_id=actor and album_id=a.id order by created_at desc,request_id desc offset 16); end if;
 return result;
end;
$$;
revoke all on function album_private.save_album(bigint,timestamptz,jsonb,uuid,uuid) from public,anon,authenticated;
grant execute on function album_private.save_album(bigint,timestamptz,jsonb,uuid,uuid) to authenticated;
create function public.save_album_document(p_album_id bigint,p_expected_updated_at timestamptz,p_changes jsonb,p_request_id uuid default null,p_expected_actor_id uuid default null) returns jsonb
language sql security invoker set search_path='' as $$select album_private.save_album(p_album_id,p_expected_updated_at,p_changes,p_request_id,p_expected_actor_id)$$;
revoke all on function public.save_album_document(bigint,timestamptz,jsonb,uuid,uuid) from public,anon;
grant execute on function public.save_album_document(bigint,timestamptz,jsonb,uuid,uuid) to authenticated;

create index if not exists album_members_user_accepted_idx on public.album_members(user_id,album_id) where status='ACCEPTED';
create index if not exists album_invites_album_idx on public.album_invites(album_id);

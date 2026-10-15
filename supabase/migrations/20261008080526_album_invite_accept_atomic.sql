-- Only the Edge Function's service client may supply the validated Auth user.
create or replace function public.accept_album_invite(p_token text, p_user_id uuid)
returns jsonb
language plpgsql security invoker set search_path = ''
as $$
declare
  v_invite public.album_invites%rowtype;
  v_owner_id uuid;
  v_role text;
  v_status text;
begin
  if p_user_id is null or coalesce(p_token, '') = '' then
    return jsonb_build_object('error', 'token_required', 'status', 400);
  end if;
  -- Serialize claims of one invitation; membership and consumption commit together.
  select * into v_invite from public.album_invites where token = p_token for update;
  if not found then
    return jsonb_build_object('error', 'invite_not_found', 'status', 404);
  end if;
  if v_invite.accepted_at is not null and v_invite.accepted_by is distinct from p_user_id then
    return jsonb_build_object('error', 'invite_used', 'status', 409);
  end if;
  if v_invite.accepted_at is null and v_invite.expires_at <= now() then
    return jsonb_build_object('error', 'invite_expired', 'status', 410);
  end if;
  select owner_id into v_owner_id from public.albums where id = v_invite.album_id;
  if not found then
    return jsonb_build_object('error', 'invite_not_found', 'status', 404);
  end if;
  if v_owner_id = p_user_id then
    return jsonb_build_object('albumId', v_invite.album_id, 'role', 'OWNER', 'success', true);
  end if;
  select role, status into v_role, v_status from public.album_members
    where album_id = v_invite.album_id and user_id = p_user_id for update;
  if v_status = 'ACCEPTED' then
    -- Existing members keep their role and do not consume somebody else's link.
    return jsonb_build_object('albumId', v_invite.album_id, 'role', v_role, 'success', true);
  end if;
  if v_invite.accepted_at is not null then
    -- A removed member cannot reuse a consumed invitation to rejoin.
    return jsonb_build_object('error', 'invite_used', 'status', 409);
  end if;
  insert into public.album_members (album_id, user_id, role, status, invited_by, invite_token)
    values (v_invite.album_id, p_user_id, v_invite.role, 'ACCEPTED', v_invite.created_by, p_token)
    on conflict (album_id, user_id) do update set
      role = case when album_members.role in ('OWNER', 'EDITOR') then album_members.role else excluded.role end,
      status = 'ACCEPTED', invited_by = excluded.invited_by, invite_token = excluded.invite_token
    returning role into v_role;
  update public.album_invites set accepted_by = p_user_id, accepted_at = coalesce(accepted_at, now())
    where token = p_token;
  return jsonb_build_object('albumId', v_invite.album_id, 'role', v_role, 'success', true);
end;
$$;

revoke all on function public.accept_album_invite(text, uuid) from public, anon, authenticated;
grant execute on function public.accept_album_invite(text, uuid) to service_role;

create or replace function public.can_access_album(target_album_id bigint)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.albums a where a.id = target_album_id and (a.owner_id = auth.uid() or public.is_admin()))
    or exists (select 1 from public.album_members m where m.album_id = target_album_id and m.user_id = auth.uid() and m.status = 'ACCEPTED');
$$;

create or replace function public.can_edit_album(target_album_id bigint)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.albums a where a.id = target_album_id and (a.owner_id = auth.uid() or public.is_admin()))
    or exists (select 1 from public.album_members m where m.album_id = target_album_id and m.user_id = auth.uid()
      and m.status = 'ACCEPTED' and m.role in ('OWNER', 'EDITOR'));
$$;
revoke all on function public.can_edit_album(bigint) from public, anon;
grant execute on function public.can_edit_album(bigint) to authenticated, service_role;

drop policy if exists albums_update_member_or_admin on public.albums;
create policy albums_update_member_or_admin on public.albums for update to authenticated
  using (public.can_edit_album(id)) with check (public.can_edit_album(id));
drop policy if exists album_pages_member_crud on public.album_pages;
create policy album_pages_member_read on public.album_pages for select to authenticated
  using (public.can_access_album(album_id));
create policy album_pages_editor_insert on public.album_pages for insert to authenticated
  with check (public.can_edit_album(album_id));
create policy album_pages_editor_update on public.album_pages for update to authenticated
  using (public.can_edit_album(album_id)) with check (public.can_edit_album(album_id));
create policy album_pages_editor_delete on public.album_pages for delete to authenticated
  using (public.can_edit_album(album_id));

create or replace function public.protect_album_owner()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.owner_id is distinct from old.owner_id and auth.uid() is not null
      and old.owner_id is distinct from auth.uid() and not public.is_admin() then
    raise exception 'album_owner_change_forbidden' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger albums_protect_owner before update on public.albums
  for each row execute function public.protect_album_owner();

create index if not exists album_members_user_accepted_idx
  on public.album_members(user_id, album_id) where status = 'ACCEPTED';

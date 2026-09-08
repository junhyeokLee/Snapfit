-- Private notifications and a durable per-device delivery queue. No FCM calls occur in transactions.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.push_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  all_enabled boolean not null default true,
  order_enabled boolean not null default true,
  invite_enabled boolean not null default true,
  comment_enabled boolean not null default true,
  marketing_enabled boolean not null default false,
  new_template_enabled boolean not null default true,
  night_mute boolean not null default false
);
alter table public.push_preferences enable row level security;
create policy push_preferences_own on public.push_preferences for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert, update on public.push_preferences to authenticated;

create table public.push_devices (
  token text primary key check (length(token) between 20 and 4096),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'iOS', 'macOS')),
  timezone_offset_minutes integer not null default 540 check (timezone_offset_minutes between -840 and 840),
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
create index push_devices_user_idx on public.push_devices(user_id);
alter table public.push_devices enable row level security;
create policy push_devices_own_read on public.push_devices for select to authenticated using (user_id = (select auth.uid()));
create policy push_devices_own_delete on public.push_devices for delete to authenticated using (user_id = (select auth.uid()));
grant select, delete on public.push_devices to authenticated;

create or replace function public.register_push_device(p_token text, p_platform text,
  p_timezone_offset_minutes integer, p_enabled boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  -- Token possession binds this installation to its current account, including account switches.
  insert into public.push_devices(token, user_id, platform, timezone_offset_minutes, enabled)
  values (p_token, v_user, p_platform, p_timezone_offset_minutes, p_enabled)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform,
    timezone_offset_minutes = excluded.timezone_offset_minutes, enabled = excluded.enabled, updated_at = now();
end;
$$;
revoke all on function public.register_push_device(text,text,integer,boolean) from public, anon;
grant execute on function public.register_push_device(text,text,integer,boolean) to authenticated;

alter table public.notifications add column if not exists category text not null default 'general';
alter table public.notifications add column if not exists data jsonb not null default '{}'::jsonb;
alter table public.notifications add column if not exists event_key text;
create unique index notifications_recipient_event_idx on public.notifications(user_id, event_key) where event_key is not null;
create index notifications_user_created_idx on public.notifications(user_id, created_at desc);
-- Clients may mark only their own rows read; message content and recipient are server-owned.
drop policy if exists notifications_own_or_admin_read on public.notifications;
drop policy if exists notifications_own_mark_read on public.notifications;
drop policy if exists notifications_admin_insert on public.notifications;
create policy notifications_recipient_read on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) and created_at >= now() - interval '90 days');
create policy notifications_recipient_mark_read on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update(is_read, read_at) on public.notifications to authenticated;
-- Legacy broadcast rows are intentionally not copied: their private recipient cannot be recovered.
revoke all on public.notification_inbox from anon, authenticated;
revoke all on public.notification_reads from anon, authenticated;

create table public.push_outbox (
  id bigint generated always as identity primary key,
  notification_id bigint not null references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  status text not null default 'pending' check (status in ('pending','processing','sent','discarded','failed')),
  attempts integer not null default 0,
  available_at timestamptz not null default now(),
  locked_until timestamptz,
  lease_token uuid,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique(notification_id, token)
);
create index push_outbox_pending_idx on public.push_outbox(available_at) where status in ('pending','processing');
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from public, anon, authenticated;
grant all on public.push_outbox, public.push_devices, public.push_preferences, public.notifications to service_role;
grant usage, select on all sequences in schema public to service_role;

create or replace function private.queue_notification_push()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.push_outbox(notification_id, user_id, token)
  select new.id, new.user_id, d.token from public.push_devices d
    where d.user_id = new.user_id and d.enabled and d.updated_at >= now() - interval '90 days'
  on conflict do nothing;
  return new;
end;
$$;
create trigger notifications_queue_push after insert on public.notifications
for each row execute function private.queue_notification_push();

-- Only the service-role dispatcher can claim delivery work. Expired leases can be retried.
create or replace function public.claim_push_deliveries(p_limit integer default 50)
returns setof public.push_outbox language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'forbidden'; end if;
  return query
  with candidates as (
    select o.id from public.push_outbox o
    where ((o.status = 'pending' and o.available_at <= now())
       or (o.status = 'processing' and o.locked_until < now()))
      and o.attempts < 10
    order by o.available_at limit least(greatest(p_limit, 1), 100)
    for update skip locked
  )
  update public.push_outbox o set status = 'processing', attempts = o.attempts + 1,
    locked_until = now() + interval '2 minutes', lease_token = gen_random_uuid()
  from candidates c where o.id = c.id returning o.*;
end;
$$;
revoke all on function public.claim_push_deliveries(integer) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(integer) to service_role;

create or replace function private.order_status_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_label text;
begin
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status then return new; end if;
  end if;
  if new.status = 'PAYMENT_PENDING' then return new; end if;
  v_label := case new.status when 'PAYMENT_COMPLETED' then '결제완료' when 'IN_PRODUCTION' then '제작중'
    when 'PRINTING' then '인쇄중' when 'SHIPPING' then '배송중' when 'DELIVERED' then '배송완료'
    when 'CANCELED' then '취소' when 'CANCELLED' then '취소' else new.status end;
  insert into public.notifications(user_id, type, category, title, body, deeplink, data, event_key)
  values (new.user_id, 'order_status', 'order', '주문 상태가 변경되었어요',
    '주문 상태가 ' || v_label || '으로 변경되었습니다.', 'snapfit://order/detail?orderId=' || new.order_id,
    jsonb_build_object('orderId',new.order_id,'status',new.status),
    'order:' || new.order_id || ':' || new.status)
  on conflict do nothing;
  return new;
end;
$$;
create trigger orders_notify_status after insert or update of status on public.orders
for each row execute function private.order_status_notification();

-- Invite links have no recipient identity until accepted. Never broadcast the invite secret.
-- Notify the album owner when a member accepts, and a known recipient on direct invitation.
create or replace function private.album_member_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_title text; v_recipient uuid; v_type text; v_body text;
begin
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status and new.role is not distinct from old.role then return new; end if;
  end if;
  select owner_id, title into v_owner, v_title from public.albums where id = new.album_id;
  if new.user_id = v_owner then return new; end if;
  if tg_op = 'UPDATE' and new.role is distinct from old.role and new.status = old.status then
    v_recipient := new.user_id; v_type := 'album_member_changed'; v_body := '공유 앨범의 참여 권한이 변경되었어요.';
  elsif new.status = 'ACCEPTED' then
    v_recipient := v_owner; v_type := 'invite_accepted'; v_body := coalesce(v_title,'앨범') || ' 앨범에 새 멤버가 참여했어요.';
  else
    v_recipient := new.user_id; v_type := 'album_invite'; v_body := coalesce(v_title,'앨범') || ' 앨범 초대가 도착했어요.';
  end if;
  insert into public.notifications(user_id,type,category,title,body,deeplink,data)
  values(v_recipient,v_type,'invite','공유 앨범 알림',v_body,
    'snapfit://album?albumId=' || new.album_id, jsonb_build_object('albumId',new.album_id));
  return new;
end;
$$;
create trigger album_members_notify after insert or update of status, role on public.album_members
for each row execute function private.album_member_notification();

create or replace function private.template_published_notification()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not new.is_active then return new; end if;
  if tg_op = 'UPDATE' then if old.is_active then return new; end if; end if;
  insert into public.notifications(user_id,type,category,title,body,deeplink,data,event_key)
  select p.id,'template_new','new_template','새 템플릿이 등록됐어요',new.title || ' 템플릿을 확인해보세요.',
    'snapfit://template?templateId=' || new.id, jsonb_build_object('templateId',new.id), 'template:' || new.id
  from public.profiles p on conflict do nothing;
  return new;
end;
$$;
create trigger templates_notify_published after insert or update of is_active on public.templates
for each row execute function private.template_published_notification();

create or replace function public.cleanup_notifications()
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_count bigint;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'forbidden'; end if;
  delete from public.notifications where created_at < now() - interval '90 days';
  get diagnostics v_count = row_count;
  delete from public.push_devices where updated_at < now() - interval '90 days';
  update public.push_outbox set status = 'failed', last_error = 'retry_limit'
    where attempts >= 10 and status in ('pending','processing') and (locked_until is null or locked_until < now());
  return v_count;
end;
$$;
revoke all on function public.cleanup_notifications() from public, anon, authenticated;
grant execute on function public.cleanup_notifications() to service_role;

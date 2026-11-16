-- A private photo saved on each actual KST calendar day earns 1,000 free
-- points once per completed month. Existing attendance and purchases remain.
do $reasons$
declare existing_expression text;
begin
 select pg_get_expr(conbin,conrelid) into existing_expression from pg_constraint
 where conrelid='public.point_ledger'::regclass and conname='point_ledger_reason_check' and contype='c';
 if existing_expression is null then raise exception 'point_ledger_reason_constraint_required'; end if;
 alter table public.point_ledger drop constraint point_ledger_reason_check;
 execute format('alter table public.point_ledger add constraint point_ledger_reason_check check ((%s) or reason=%L)',
  existing_expression,'MONTHLY_MOMENT_COMPLETION');
end;
$reasons$;

create table moments_private.monthly_completion_rewards (
 user_id uuid not null references auth.users(id) on delete cascade,
 month date not null check(extract(day from month)=1),
 points integer not null check(points=1000),
 ledger_id bigint not null unique references public.point_ledger(id) deferrable initially deferred,
 awarded_at timestamptz not null,
 primary key(user_id,month)
);
alter table moments_private.monthly_completion_rewards enable row level security;
revoke all on moments_private.monthly_completion_rewards from public,anon,authenticated,service_role;

-- The original created_at is server-written and is never moved by edits. Old
-- backfilled entries remain usable memories but cannot certify a missed day.
create function moments_private.qualifying_record_dates(p_user uuid,p_month date) returns setof date
language sql stable security invoker set search_path='' as $$
 select distinct m.record_date from moments_private.weekly_moments m
 where m.owner_id=p_user and m.deleted_at is null and jsonb_array_length(m.photos)>0
  and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date
  and (m.created_at at time zone 'Asia/Seoul')::date=m.record_date
$$;
revoke all on function moments_private.qualifying_record_dates(uuid,date) from public,anon,authenticated,service_role;

create function moments_private.monthly_reward_status(p_user uuid,p_month date,p_at timestamptz) returns jsonb
language sql stable security invoker set search_path='' as $$
 with context as(select (p_at at time zone 'Asia/Seoul')::date today,(p_month+interval '1 month')::date next_month),
 days as(select d from moments_private.qualifying_record_dates(p_user,p_month)d),
 receipt as(select r.awarded_at from moments_private.monthly_completion_rewards r where r.user_id=p_user and r.month=p_month)
 select jsonb_build_object('points',1000,'recordedDays',(select count(*) from days),
  'daysInMonth',c.next_month-p_month,'awarded',exists(select 1 from receipt),
  'canComplete',exists(select 1 from receipt) or (p_month=date_trunc('month',c.today)::date and not exists(
   select 1 from generate_series(p_month::timestamp,(c.today-1)::timestamp,interval '1 day')g(day)
   where not exists(select 1 from days where d=g.day::date))),
  'awardedAt',(select awarded_at from receipt)) from context c
$$;
revoke all on function moments_private.monthly_reward_status(uuid,date,timestamptz) from public,anon,authenticated,service_role;

create policy monthly_moment_ledger_rpc_only on public.point_ledger as restrictive
 for insert to authenticated with check(reason<>'MONTHLY_MOMENT_COMPLETION' and idempotency_key not like 'monthly_moment_completion:%');

create function moments_private.guard_monthly_completion_ledger() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.reason='MONTHLY_MOMENT_COMPLETION' or new.idempotency_key like 'monthly_moment_completion:%' then
   if new.reason<>'MONTHLY_MOMENT_COMPLETION' or new.amount_delta<>1000
    or new.related_entity_type is distinct from 'monthly_moment_completion'
    or new.related_entity_id is distinct from new.metadata->>'month'
    or new.idempotency_key is distinct from 'monthly_moment_completion:'||new.user_id::text||':'||new.related_entity_id
    or new.metadata->>'timezone' is distinct from 'Asia/Seoul'
    or new.metadata->>'source' is distinct from 'monthly_photo_completion'
    or new.metadata->>'ruleVersion' is distinct from '1' then
    raise exception 'MOMENTS_MONTHLY_LEDGER_INVALID' using errcode='23514';
   end if;
  end if;
  return new;
 end if;
 if old.reason='MONTHLY_MOMENT_COMPLETION' or old.idempotency_key like 'monthly_moment_completion:%'
  or (tg_op='UPDATE' and (new.reason='MONTHLY_MOMENT_COMPLETION' or new.idempotency_key like 'monthly_moment_completion:%')) then
  if tg_op='DELETE' and not exists(select 1 from auth.users where id=old.user_id) then return old; end if;
  raise exception 'MOMENTS_MONTHLY_LEDGER_IMMUTABLE' using errcode='23514';
 end if;
 return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function moments_private.guard_monthly_completion_ledger() from public,anon,authenticated,service_role;
create trigger monthly_moment_completion_ledger_guard before insert or update or delete on public.point_ledger
 for each row execute function moments_private.guard_monthly_completion_ledger();

create function moments_private.guard_monthly_completion_reward() returns trigger
language plpgsql security definer set search_path='' as $$
declare entry public.point_ledger; days integer;
begin
 if tg_op<>'INSERT' then
  if tg_op='DELETE' and not exists(select 1 from auth.users where id=old.user_id) then return old; end if;
  raise exception 'MOMENTS_MONTHLY_REWARD_IMMUTABLE' using errcode='23514';
 end if;
 days:=(new.month+interval '1 month')::date-new.month;
 select * into entry from public.point_ledger where id=new.ledger_id;
 if not found or entry.user_id<>new.user_id or entry.reason<>'MONTHLY_MOMENT_COMPLETION'
  or entry.amount_delta<>new.points or entry.related_entity_type is distinct from 'monthly_moment_completion'
  or entry.related_entity_id is distinct from new.month::text
  or entry.idempotency_key is distinct from 'monthly_moment_completion:'||new.user_id::text||':'||new.month::text
  or entry.metadata->>'daysInMonth' is distinct from days::text
  or entry.created_at is distinct from new.awarded_at
  or (new.awarded_at at time zone 'Asia/Seoul')::date is distinct from (new.month+interval '1 month')::date-1
  or (select count(*) from moments_private.qualifying_record_dates(new.user_id,new.month))<>days then
  raise exception 'MOMENTS_MONTHLY_REWARD_LEDGER_MISMATCH' using errcode='23514';
 end if;
 return new;
end;
$$;
revoke all on function moments_private.guard_monthly_completion_reward() from public,anon,authenticated,service_role;
create trigger monthly_moment_completion_reward_guard before insert or update or delete on moments_private.monthly_completion_rewards
 for each row execute function moments_private.guard_monthly_completion_reward();

-- A ledger credit must have its matching private receipt before commit, even
-- if a trusted role bypasses RLS and tries to forge a structurally valid row.
create function moments_private.check_monthly_completion_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.reason='MONTHLY_MOMENT_COMPLETION' and exists(select 1 from auth.users where id=new.user_id)
  and not exists(select 1 from moments_private.monthly_completion_rewards r where r.ledger_id=new.id and r.user_id=new.user_id) then
  raise exception 'MOMENTS_MONTHLY_REWARD_RECEIPT_REQUIRED' using errcode='23514';
 end if;
 return null;
end;
$$;
revoke all on function moments_private.check_monthly_completion_receipt() from public,anon,authenticated,service_role;
create constraint trigger monthly_moment_completion_receipt_required after insert on public.point_ledger
 deferrable initially deferred for each row execute function moments_private.check_monthly_completion_receipt();

create function moments_private.award_monthly_completion(p_user uuid,p_day date) returns void
language plpgsql volatile security invoker set search_path='' as $$
declare month_start date:=date_trunc('month',p_day)::date; days integer; entry_id bigint; server_time timestamptz;
begin
 days:=(month_start+interval '1 month')::date-month_start;
 if p_day<>(month_start+interval '1 month')::date-1
  or exists(select 1 from moments_private.monthly_completion_rewards r where r.user_id=p_user and r.month=month_start)
  or (select count(*) from moments_private.qualifying_record_dates(p_user,month_start))<>days then return; end if;
 insert into public.point_wallets(user_id,balance) values(p_user,0) on conflict(user_id)do nothing;
 -- Purchases and existing attendance serialize on this same wallet row.
 perform 1 from public.point_wallets where user_id=p_user for update;
 server_time:=moments_private.server_now();
 if (server_time at time zone 'Asia/Seoul')::date<>p_day then
  raise exception 'MOMENTS_DAY_CHANGED' using errcode='22023';
 end if;
 if exists(select 1 from moments_private.monthly_completion_rewards r where r.user_id=p_user and r.month=month_start) then return; end if;
 insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata,created_at)
 values(p_user,1000,'MONTHLY_MOMENT_COMPLETION','monthly_moment_completion:'||p_user::text||':'||month_start::text,
  'monthly_moment_completion',month_start::text,jsonb_build_object('month',month_start::text,'daysInMonth',days,
   'timezone','Asia/Seoul','source','monthly_photo_completion','ruleVersion',1),server_time) returning id into entry_id;
 insert into moments_private.monthly_completion_rewards(user_id,month,points,ledger_id,awarded_at)
 values(p_user,month_start,1000,entry_id,server_time);
 update public.point_wallets set balance=balance+1000 where user_id=p_user;
end;
$$;
revoke all on function moments_private.award_monthly_completion(uuid,date) from public,anon,authenticated,service_role;

-- Preserve the latest editable-photo validation and journal/album contract.
create or replace function moments_private.save_record(p_id uuid,p_record_date date,p_caption text,p_photos jsonb,p_expected_revision integer) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); server_time timestamptz:=moments_private.server_now();
 today date:=(server_time at time zone 'Asia/Seoul')::date; initial_day date:=today;
 record moments_private.weekly_moments; photo jsonb; path text; photo_id uuid; v_caption text:=btrim(coalesce(p_caption,''));
begin
 if p_id is null or p_record_date is null or p_record_date<'1900-01-01'::date
  or char_length(v_caption)>200 or p_expected_revision is null or p_expected_revision<0 then
  raise exception 'MOMENTS_INVALID_RECORD' using errcode='22023'; end if;
 if jsonb_typeof(p_photos) is distinct from 'array' or octet_length(p_photos::text)>409600 then
  raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
 if jsonb_array_length(p_photos) not between 1 and 3 then raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
 select * into record from moments_private.weekly_moments where id=p_id for update;
 if found then
  if record.owner_id<>actor then raise exception 'MOMENTS_ACCESS_DENIED' using errcode='42501'; end if;
  if record.deleted_at is not null then raise exception 'MOMENTS_RECORD_DELETED' using errcode='PT409'; end if;
  -- A lost response may be retried with its original revision and payload.
  if record.record_date=p_record_date and record.caption=v_caption and record.photos=p_photos
   and p_expected_revision in(record.revision,record.revision-1) then return moments_private.record_json(record); end if;
  if record.revision<>p_expected_revision then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
 elsif p_expected_revision<>0 then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
 if record.id is null and p_record_date<>today then raise exception 'MOMENTS_RECORD_TODAY_ONLY' using errcode='22023'; end if;
 if record.id is not null and record.record_date<>p_record_date then raise exception 'MOMENTS_RECORD_DATE_IMMUTABLE' using errcode='22023'; end if;
 if record.id is not null and p_record_date<today and record.photos is distinct from p_photos then
  raise exception 'MOMENTS_PAST_PHOTOS_LOCKED' using errcode='22023'; end if;
 -- Bound list payloads and storage growth without blocking edits to an existing
 -- month. Actor serialization also makes concurrent final-slot saves atomic.
 if record.id is null or date_trunc('month',record.record_date)<>date_trunc('month',p_record_date) then
  if(select count(*) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.id<>p_id
   and m.record_date>=date_trunc('month',p_record_date)::date and m.record_date<(date_trunc('month',p_record_date)+interval '1 month')::date)>=100 then
   raise exception 'MOMENTS_MONTH_FULL' using errcode='22023'; end if;
 end if;
 for photo in select value from jsonb_array_elements(p_photos) loop
  if jsonb_typeof(photo) is distinct from 'object' or exists(select 1 from jsonb_object_keys(photo) k where k not in('id','path','width','height','design'))
   or jsonb_typeof(photo->'id') is distinct from 'string' or (photo->>'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or jsonb_typeof(photo->'path') is distinct from 'string'
   or jsonb_typeof(photo->'width') is distinct from 'number' or (photo->>'width') !~ '^[1-9][0-9]{0,4}$'
   or jsonb_typeof(photo->'height') is distinct from 'number' or (photo->>'height') !~ '^[1-9][0-9]{0,4}$' then
   raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
  if photo?'design'then perform moments_private.validate_photo_design(photo->'design',actor);end if;
  photo_id:=(photo->>'id')::uuid; path:=photo->>'path';
  if path !~ ('^'||actor||'/moments/'||p_id||'/'||photo_id||'[.](jpg|jpeg|png|webp)$') then
   raise exception 'MOMENTS_INVALID_PHOTO_PATH' using errcode='42501'; end if;
  perform 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path
   and coalesce(o.owner_id,o.owner::text)=actor::text
   and coalesce(o.metadata->>'mimetype','') in('image/jpeg','image/png','image/webp') for update;
  if not found then raise exception 'MOMENTS_PHOTO_UNAVAILABLE' using errcode='42501'; end if;
 end loop;
 if (select count(distinct value->>'id') from jsonb_array_elements(p_photos))<>jsonb_array_length(p_photos)
  or(select count(distinct value->>'path') from jsonb_array_elements(p_photos))<>jsonb_array_length(p_photos) then
  raise exception 'MOMENTS_DUPLICATE_PHOTO' using errcode='22023'; end if;
 -- Storage locks may wait across midnight; use the server date again before writing.
 server_time:=moments_private.server_now();
 today:=(server_time at time zone 'Asia/Seoul')::date;
 if p_record_date<>today and (record.id is null or p_record_date=initial_day) then
  raise exception 'MOMENTS_DAY_CHANGED' using errcode='22023'; end if;
 if record.id is null then
  insert into moments_private.weekly_moments(id,owner_id,record_date,caption,photos,created_at,updated_at)
   values(p_id,actor,p_record_date,v_caption,p_photos,server_time,server_time) returning * into record;
 else
  update moments_private.weekly_moments m set record_date=p_record_date,caption=v_caption,photos=p_photos,revision=m.revision+1,updated_at=moments_private.server_now()
   where m.id=p_id returning * into record;
 end if;
 if p_record_date=today then perform moments_private.award_monthly_completion(actor,today); end if;
 return moments_private.record_json(record);
end;
$$;


create or replace function moments_private.journal(p_month date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(); server_time timestamptz:=moments_private.server_now();
 today date:=(server_time at time zone 'Asia/Seoul')::date;
 v_month date:=coalesce(p_month,date_trunc('month',today)::date); week_start date:=date_trunc('week',today)::date; link moments_private.month_albums;
begin
 if extract(day from v_month)<>1 or v_month>date_trunc('month',today)::date or v_month<'1900-01-01'::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 select ma.* into link from moments_private.month_albums ma join public.albums a on a.id=ma.album_id and a.owner_id=actor where ma.owner_id=actor and ma.month=v_month;
 return jsonb_build_object('today',today,'weekStart',week_start,'month',v_month,'timezone','Asia/Seoul',
  'records',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=v_month and m.record_date<(v_month+interval '1 month')::date),'[]'::jsonb),
  'weekRecords',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),'[]'::jsonb),
  'weekPhotoCount',coalesce((select sum(jsonb_array_length(m.photos)) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),0),
  'monthlyAlbumId',link.album_id,'monthlyAlbumPhotoIds',to_jsonb(coalesce(link.imported_photo_ids,'{}'::uuid[])),
  'monthlyReward',moments_private.monthly_reward_status(actor,v_month,server_time));
end;
$$;


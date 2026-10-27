-- Private retention: server-time activity, opt-in weekly reminders, and additive
-- monthly album pages. Existing album content and point transactions are kept.
alter table moments_private.month_albums add column imported_photo_ids uuid[] not null default '{}';

create table moments_private.activity (
 owner_id uuid not null references auth.users(id) on delete cascade,
 event_id uuid not null,
 event text not null check(event in('record_saved','album_created','album_appended','recap_viewed','monthly_previewed','reward_viewed')),
 month date not null check(extract(day from month)=1),
 occurred_at timestamptz not null default clock_timestamp(),
 primary key(owner_id,event_id)
);
create index moments_activity_owner_time_idx on moments_private.activity(owner_id,occurred_at desc);
create index moments_activity_cleanup_idx on moments_private.activity(occurred_at);
create table moments_private.reminder_preferences (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 enabled boolean not null default false,
 weekday integer not null default 7 check(weekday between 1 and 7),
 hour integer not null default 19 check(hour between 8 and 21),
 minute integer not null default 0 check(minute between 0 and 59),
 last_sent_week date,
 updated_at timestamptz not null default clock_timestamp()
);
alter table moments_private.activity enable row level security;
alter table moments_private.reminder_preferences enable row level security;
revoke all on moments_private.activity,moments_private.reminder_preferences from public,anon,authenticated,service_role;

create function moments_private.imported_ids(p_album bigint) returns uuid[]
language sql stable security invoker set search_path='' as $$
 select coalesce(array_agg(distinct substring(p from '/([0-9a-f-]{36})[.](?:jpg|jpeg|png|webp)$')::uuid order by substring(p from '/([0-9a-f-]{36})[.](?:jpg|jpeg|png|webp)$')::uuid),'{}'::uuid[])
 from album_private.album_paths(p_album)p where p ~ '^[0-9a-f-]{36}/moments/[0-9a-f-]{36}/[0-9a-f-]{36}[.](jpg|jpeg|png|webp)$'
$$;
update moments_private.month_albums set imported_photo_ids=moments_private.imported_ids(album_id) where album_id is not null;

create function moments_private.remember_month_album() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.album_id is not null and(tg_op='INSERT' or new.album_id is distinct from old.album_id) then
  new.imported_photo_ids:=moments_private.imported_ids(new.album_id);
  insert into moments_private.activity(owner_id,event_id,event,month,occurred_at)
   values(new.owner_id,gen_random_uuid(),'album_created',new.month,moments_private.server_now());
 end if;
 return new;
end;
$$;
create trigger moments_remember_month_album before insert or update of album_id on moments_private.month_albums for each row execute function moments_private.remember_month_album();
create function moments_private.remember_record_save() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.deleted_at is null and(tg_op='INSERT' or new.record_date is distinct from old.record_date or new.caption is distinct from old.caption or new.photos is distinct from old.photos) then
  insert into moments_private.activity(owner_id,event_id,event,month,occurred_at)
   values(new.owner_id,gen_random_uuid(),'record_saved',date_trunc('month',new.record_date)::date,moments_private.server_now());
 end if;
 return new;
end;
$$;
create trigger moments_remember_record_save after insert or update on moments_private.weekly_moments for each row execute function moments_private.remember_record_save();

create or replace function moments_private.journal(p_month date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 v_month date:=coalesce(p_month,date_trunc('month',today)::date); week_start date:=date_trunc('week',today)::date; link moments_private.month_albums;
begin
 if extract(day from v_month)<>1 or v_month>date_trunc('month',today)::date or v_month<'1900-01-01'::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 select ma.* into link from moments_private.month_albums ma join public.albums a on a.id=ma.album_id and a.owner_id=actor where ma.owner_id=actor and ma.month=v_month;
 return jsonb_build_object('today',today,'weekStart',week_start,'month',v_month,'timezone','Asia/Seoul',
  'records',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=v_month and m.record_date<(v_month+interval '1 month')::date),'[]'::jsonb),
  'weekRecords',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),'[]'::jsonb),
  'weekPhotoCount',coalesce((select sum(jsonb_array_length(m.photos)) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),0),
  'monthlyAlbumId',link.album_id,'monthlyAlbumPhotoIds',to_jsonb(coalesce(link.imported_photo_ids,'{}'::uuid[])));
end;
$$;

create function moments_private.append_month_album(p_month date,p_album_id bigint,p_photo_ids uuid[],p_pages jsonb,p_expected_updated_at timestamptz) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); link moments_private.month_albums; a public.albums; paths text[]; used_paths text[]; doc jsonb; page jsonb; value text; appended jsonb; count_before integer; count_after integer;
begin
 if p_month is null or p_album_id is null then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 -- Album first matches editor/member locks. The actor lock serializes record edits
 -- and duplicate append attempts; collaborators still use album CAS normally.
 select * into a from public.albums where id=p_album_id and owner_id=actor for update;
 if not found then raise exception 'MOMENTS_ACCESS_DENIED' using errcode='42501'; end if;
 select * into link from moments_private.month_albums where owner_id=actor and month=p_month and album_id=a.id for update;
 if not found then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 if p_photo_ids is null or cardinality(p_photo_ids) not between 1 and 9 or array_position(p_photo_ids,null) is not null
  or(select count(distinct p) from unnest(p_photo_ids)p)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 -- Lost responses are safe even if the user edited the album afterwards. An
 -- intentionally removed imported photo is never silently added again.
 if p_photo_ids<@link.imported_photo_ids then return jsonb_build_object('albumId',a.id,'appended',false); end if;
 if p_photo_ids&&link.imported_photo_ids then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if a.locked_by_id is not null and a.locked_by_id<>actor then raise exception 'MOMENTS_ALBUM_LOCKED' using errcode='PT409'; end if;
 if p_expected_updated_at is null or a.updated_at is distinct from p_expected_updated_at then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 select array_agg(p.photo->>'path' order by p.photo->>'path') into paths from moments_private.weekly_moments m
  cross join lateral jsonb_array_elements(m.photos)p(photo)
  where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date and(p.photo->>'id')::uuid=any(p_photo_ids);
 if coalesce(cardinality(paths),0)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if jsonb_typeof(p_pages) is distinct from 'array' or jsonb_array_length(p_pages) not between 1 and 18 or octet_length(p_pages::text)>1048576 then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 for page in select j.value from jsonb_array_elements(p_pages)j(value) loop
  if jsonb_typeof(page) is distinct from 'object' or jsonb_typeof(page->'layers') is distinct from 'array' or jsonb_array_length(page->'layers')>50
   or page->>'isCover' is distinct from 'false' then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 select array_agg(p order by p) into used_paths from album_private.paths(p_pages)p;
 if used_paths is distinct from paths then raise exception 'MOMENTS_ALBUM_PHOTOS_MISMATCH' using errcode='42501'; end if;
 for value in select j.value#>>'{}' from jsonb_path_query(p_pages,'strict $.** ? (@.type() == "object").keyvalue() ? (@.key like_regex "(url|uri|src|path)$" flag "i").value')j(value) where jsonb_typeof(j.value)='string' loop
  if value<>'' and not(value=any(select 'supabase://album-assets/'||p from unnest(paths)p)) then raise exception 'MOMENTS_INVALID_ALBUM_IMAGE' using errcode='42501'; end if;
 end loop;
 foreach value in array paths loop
  perform 1 from storage.objects o where o.bucket_id='album-assets' and o.name=value and coalesce(o.owner_id,o.owner::text)=actor::text
   and coalesce(o.metadata->>'mimetype','') in('image/jpeg','image/png','image/webp') for key share;
  if not found then raise exception 'MOMENTS_PHOTO_UNAVAILABLE' using errcode='42501'; end if;
 end loop;
 if not pg_input_is_valid(a.cover_layers_json,'jsonb') then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 doc:=a.cover_layers_json::jsonb;
 if jsonb_typeof(doc) is distinct from 'object' or jsonb_typeof(doc->'pages') is distinct from 'array' then raise exception 'MOMENTS_ALBUM_CHANGED' using errcode='PT409'; end if;
 count_before:=jsonb_array_length(doc->'pages');count_after:=count_before+jsonb_array_length(p_pages);
 if count_before<1 or count_after>81 or greatest(coalesce(a.target_pages,0),count_after-1)>80 then raise exception 'MOMENTS_ALBUM_FULL' using errcode='22023'; end if;
 select jsonb_agg(jsonb_set(x.page,'{index}',to_jsonb((count_before+ordinality-1)::integer),true)order by ordinality) into appended from jsonb_array_elements(p_pages)with ordinality x(page,ordinality);
 doc:=jsonb_set(doc,'{pages}',(doc->'pages')||appended,false);
 if octet_length(doc::text)>8388608 then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 update public.albums set cover_layers_json=doc::text,total_pages=count_after-1,target_pages=greatest(coalesce(target_pages,0),count_after-1) where id=a.id;
 update moments_private.month_albums set imported_photo_ids=imported_photo_ids||p_photo_ids where owner_id=actor and month=p_month;
 insert into moments_private.activity(owner_id,event_id,event,month,occurred_at) values(actor,gen_random_uuid(),'album_appended',p_month,moments_private.server_now());
 return jsonb_build_object('albumId',a.id,'appended',true);
end;
$$;

create function moments_private.engagement() returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(); prefs moments_private.reminder_preferences; has_records boolean; push_allowed boolean;
begin
 select * into prefs from moments_private.reminder_preferences where owner_id=actor;
 has_records:=exists(select 1 from moments_private.weekly_moments where owner_id=actor and deleted_at is null);
 push_allowed:=coalesce((select all_enabled from public.push_preferences where user_id=actor),true);
 return jsonb_build_object('reminder',jsonb_build_object('enabled',coalesce(prefs.enabled,false),'weekday',coalesce(prefs.weekday,7),'hour',coalesce(prefs.hour,19),'minute',coalesce(prefs.minute,0),'timezone','Asia/Seoul'),'hasRecords',has_records,'canRemind',has_records and push_allowed);
end;
$$;
create function moments_private.save_reminder(p_enabled boolean,p_weekday integer,p_hour integer,p_minute integer) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true);
begin
 if p_enabled is null or p_weekday is null or p_weekday not between 1 and 7 or p_hour is null or p_hour not between 8 and 21 or p_minute is null or p_minute not between 0 and 59 then raise exception 'MOMENTS_INVALID_REMINDER' using errcode='22023'; end if;
 if p_enabled and not exists(select 1 from moments_private.weekly_moments where owner_id=actor and deleted_at is null) then raise exception 'MOMENTS_FIRST_RECORD_REQUIRED' using errcode='22023'; end if;
 insert into moments_private.reminder_preferences(owner_id,enabled,weekday,hour,minute,updated_at) values(actor,p_enabled,p_weekday,p_hour,p_minute,moments_private.server_now())
 on conflict(owner_id)do update set enabled=excluded.enabled,weekday=excluded.weekday,hour=excluded.hour,minute=excluded.minute,updated_at=excluded.updated_at;
 if not p_enabled then
  update public.push_outbox o set status='discarded',last_error='moment_reminder_disabled' from public.notifications n where o.notification_id=n.id and n.user_id=actor and n.type='moment_reminder' and o.status in('pending','processing');
 end if;
 return moments_private.engagement();
end;
$$;
create function moments_private.record_activity(p_event_id uuid,p_event text,p_month date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date; v_month date:=coalesce(p_month,date_trunc('month',today)::date); previous moments_private.activity;
begin
 if p_event_id is null or p_event is null or p_event not in('recap_viewed','monthly_previewed','reward_viewed') or v_month<'1900-01-01'::date or v_month>date_trunc('month',today)::date or extract(day from v_month)<>1 then raise exception 'MOMENTS_INVALID_ACTIVITY' using errcode='22023'; end if;
 if not exists(select 1 from moments_private.weekly_moments where owner_id=actor and deleted_at is null) then return jsonb_build_object('recorded',false); end if;
 select * into previous from moments_private.activity where owner_id=actor and event_id=p_event_id;
 if found then
  if previous.event<>p_event or previous.month<>v_month then raise exception 'MOMENTS_ACTIVITY_MISMATCH' using errcode='22023'; end if;
  return jsonb_build_object('recorded',false);
 end if;
 if(select count(*) from moments_private.activity where owner_id=actor and occurred_at>=moments_private.server_now()-interval '1 day' and event in('recap_viewed','monthly_previewed','reward_viewed'))>=100 then return jsonb_build_object('recorded',false); end if;
 insert into moments_private.activity(owner_id,event_id,event,month,occurred_at) values(actor,p_event_id,p_event,v_month,moments_private.server_now());
 return jsonb_build_object('recorded',true);
end;
$$;

-- Existing notification trigger/dispatcher retains device and quiet-hours policy.
-- No default opt-ins and no photo/caption/album identifiers enter notification data.
create function moments_private.dispatch_reminders() returns integer
language plpgsql volatile security definer set search_path='' as $$
declare now_at timestamptz:=moments_private.server_now(); local_now timestamp:=now_at at time zone 'Asia/Seoul'; week_start date:=date_trunc('week',local_now)::date; prefs moments_private.reminder_preferences; notified bigint; sent integer:=0; scheduled timestamp;
begin
 delete from moments_private.activity where occurred_at<now_at-interval '90 days';
 for prefs in select p.* from moments_private.reminder_preferences p join auth.users u on u.id=p.owner_id
  where p.enabled and u.deleted_at is null and not u.is_anonymous and(u.banned_until is null or u.banned_until<=now_at)
   and p.weekday=extract(isodow from local_now)::integer and p.last_sent_week is distinct from week_start
   and coalesce((select all_enabled from public.push_preferences where user_id=p.owner_id),true)
  order by p.owner_id for update of p skip locked loop
  scheduled:=date_trunc('day',local_now)+make_interval(hours=>prefs.hour,mins=>prefs.minute);
  if local_now<scheduled or local_now>=scheduled+interval '10 minutes' then continue; end if;
  if not exists(select 1 from moments_private.weekly_moments where owner_id=prefs.owner_id and deleted_at is null) then continue; end if;
  if exists(select 1 from moments_private.activity where owner_id=prefs.owner_id and occurred_at>=(week_start::timestamp at time zone 'Asia/Seoul') and occurred_at<=now_at and event in('record_saved','recap_viewed')) then continue; end if;
  notified:=null;
  insert into public.notifications(user_id,type,category,title,body,deeplink,data,event_key,created_at)
   values(prefs.owner_id,'moment_reminder','general','지난 순간을 가볍게 돌아볼까요?','모아 둔 사진을 다시 보고, 기억하고 싶은 한 장을 더 남겨보세요.','snapfit://moments',jsonb_build_object('screen','moments','userId',prefs.owner_id),'moments:weekly:'||week_start,now_at)
   on conflict do nothing returning id into notified;
  update moments_private.reminder_preferences set last_sent_week=week_start where owner_id=prefs.owner_id;
  if notified is not null then sent:=sent+1; end if;
 end loop;
 return sent;
end;
$$;

-- The dispatcher rechecks opt-in and activity immediately before delivery, so
-- disabling or recording after enqueue also cancels a pending notification.
create function moments_private.delivery_allowed(p_user_id uuid,p_notification_id bigint) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare prefs moments_private.reminder_preferences; notification public.notifications; now_at timestamptz:=moments_private.server_now(); local_now timestamp:=now_at at time zone 'Asia/Seoul'; week_start date:=date_trunc('week',local_now)::date; scheduled timestamp;
begin
 select * into prefs from moments_private.reminder_preferences where owner_id=p_user_id and enabled;
 if not found then return false; end if;
 select * into notification from public.notifications where id=p_notification_id and user_id=p_user_id and type='moment_reminder' and event_key='moments:weekly:'||week_start;
 if not found or prefs.updated_at>notification.created_at then return false; end if;
 scheduled:=date_trunc('day',local_now)+make_interval(hours=>prefs.hour,mins=>prefs.minute);
 if prefs.weekday<>extract(isodow from local_now)::integer or local_now<scheduled or local_now>=scheduled+interval '10 minutes' then return false; end if;
 return coalesce((select all_enabled from public.push_preferences where user_id=p_user_id),true)
  and exists(select 1 from auth.users where id=p_user_id and deleted_at is null and not is_anonymous and(banned_until is null or banned_until<=now_at))
  and exists(select 1 from moments_private.weekly_moments where owner_id=p_user_id and deleted_at is null)
  and not exists(select 1 from moments_private.activity where owner_id=p_user_id and occurred_at>=(week_start::timestamp at time zone 'Asia/Seoul') and occurred_at<=now_at and event in('record_saved','recap_viewed'));
end;
$$;
revoke all on function moments_private.delivery_allowed(uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function moments_private.delivery_allowed(uuid,bigint) to service_role;
create function public.is_moment_reminder_delivery_allowed(p_user_id uuid,p_notification_id bigint) returns boolean language sql security invoker set search_path='' as $$select moments_private.delivery_allowed(p_user_id,p_notification_id)$$;
revoke all on function public.is_moment_reminder_delivery_allowed(uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.is_moment_reminder_delivery_allowed(uuid,bigint) to service_role;

revoke all on function moments_private.imported_ids(bigint),moments_private.remember_month_album(),moments_private.remember_record_save(),moments_private.append_month_album(date,bigint,uuid[],jsonb,timestamptz),moments_private.engagement(),moments_private.save_reminder(boolean,integer,integer,integer),moments_private.record_activity(uuid,text,date),moments_private.dispatch_reminders() from public,anon,authenticated,service_role;
grant execute on function moments_private.append_month_album(date,bigint,uuid[],jsonb,timestamptz),moments_private.engagement(),moments_private.save_reminder(boolean,integer,integer,integer),moments_private.record_activity(uuid,text,date) to authenticated;
grant usage on schema moments_private to service_role;
grant execute on function moments_private.dispatch_reminders() to service_role;
create function public.append_moment_month_album(p_month date,p_album_id bigint,p_photo_ids uuid[],p_pages jsonb,p_expected_updated_at timestamptz)returns jsonb language sql security invoker set search_path='' as $$select moments_private.append_month_album(p_month,p_album_id,p_photo_ids,p_pages,p_expected_updated_at)$$;
create function public.get_moment_engagement()returns jsonb language sql security invoker set search_path='' as $$select moments_private.engagement()$$;
create function public.save_moment_reminder(p_enabled boolean,p_weekday integer,p_hour integer,p_minute integer)returns jsonb language sql security invoker set search_path='' as $$select moments_private.save_reminder(p_enabled,p_weekday,p_hour,p_minute)$$;
create function public.record_moment_activity(p_event_id uuid,p_event text,p_month date default null)returns jsonb language sql security invoker set search_path='' as $$select moments_private.record_activity(p_event_id,p_event,p_month)$$;
create function public.dispatch_moment_reminders()returns integer language sql security invoker set search_path='' as $$select moments_private.dispatch_reminders()$$;
revoke all on function public.append_moment_month_album(date,bigint,uuid[],jsonb,timestamptz),public.get_moment_engagement(),public.save_moment_reminder(boolean,integer,integer,integer),public.record_moment_activity(uuid,text,date),public.dispatch_moment_reminders() from public,anon,authenticated,service_role;
grant execute on function public.append_moment_month_album(date,bigint,uuid[],jsonb,timestamptz),public.get_moment_engagement(),public.save_moment_reminder(boolean,integer,integer,integer),public.record_moment_activity(uuid,text,date) to authenticated;
grant execute on function public.dispatch_moment_reminders() to service_role;
-- Runnable on local PostgreSQL without pg_cron; production already has pg_cron.
do $$begin if exists(select 1 from pg_extension where extname='pg_cron') then perform cron.schedule('snapfit-moments-weekly-reminder','* * * * *','select moments_private.dispatch_reminders();'); end if;end$$;

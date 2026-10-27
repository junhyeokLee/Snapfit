-- Private photo records become ordinary editable albums only after an explicit
-- monthly create action. No points, notifications, public posts or existing
-- customer rows are changed by this migration.
create schema moments_private;
revoke all on schema moments_private from public,anon,authenticated,service_role;
grant usage on schema moments_private to authenticated;

create table moments_private.weekly_moments (
 id uuid primary key,
 owner_id uuid not null references auth.users(id) on delete cascade,
 record_date date not null,
 caption text not null default '' check(char_length(caption)<=200),
 photos jsonb not null check(jsonb_typeof(photos)='array'),
 revision integer not null default 1 check(revision>0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 deleted_at timestamptz,
 check((deleted_at is null and jsonb_array_length(photos) between 1 and 3)
  or(deleted_at is not null and photos='[]'::jsonb and caption=''))
);
create index weekly_moments_owner_date_idx on moments_private.weekly_moments(owner_id,record_date desc,id) where deleted_at is null;
create index weekly_moments_photo_paths_idx on moments_private.weekly_moments using gin(photos jsonb_path_ops) where deleted_at is null;
create table moments_private.month_albums (
 owner_id uuid not null references auth.users(id) on delete cascade,
 month date not null check(extract(day from month)=1),
 album_id bigint unique references public.albums(id) on delete set null,
 created_at timestamptz not null default clock_timestamp(),
 primary key(owner_id,month)
);
alter table moments_private.weekly_moments enable row level security;
alter table moments_private.month_albums enable row level security;
revoke all on moments_private.weekly_moments,moments_private.month_albums from public,anon,authenticated,service_role;

create function moments_private.server_now() returns timestamptz
language sql volatile security invoker set search_path='' as $$ select clock_timestamp() $$;

create function moments_private.actor(p_lock boolean default false) returns uuid
language plpgsql volatile security invoker set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null then raise exception 'MOMENTS_LOGIN_REQUIRED' using errcode='42501'; end if;
 if p_lock then
  perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
   and(banned_until is null or banned_until<=moments_private.server_now()) for no key update;
 else
  perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
   and(banned_until is null or banned_until<=moments_private.server_now());
 end if;
 if not found then raise exception 'MOMENTS_ACCOUNT_REQUIRED' using errcode='42501'; end if;
 return actor;
end;
$$;

create function moments_private.record_json(p_record moments_private.weekly_moments) returns jsonb
language sql immutable security invoker set search_path='' as $$
 select to_jsonb(p_record)-'deleted_at'
$$;

create function moments_private.journal(p_month date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 v_month date:=coalesce(p_month,date_trunc('month',today)::date); week_start date:=date_trunc('week',today)::date;
begin
 if extract(day from v_month)<>1 or v_month>date_trunc('month',today)::date or v_month<'1900-01-01'::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 return jsonb_build_object('today',today,'weekStart',week_start,'month',v_month,'timezone','Asia/Seoul',
  'records',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=v_month and m.record_date<(v_month+interval '1 month')::date),'[]'::jsonb),
  'weekRecords',coalesce((select jsonb_agg(moments_private.record_json(m) order by m.record_date desc,m.created_at desc,m.id) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),'[]'::jsonb),
  'weekPhotoCount',coalesce((select sum(jsonb_array_length(m.photos)) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.record_date>=week_start and m.record_date<week_start+7),0),
  'monthlyAlbumId',(select ma.album_id from moments_private.month_albums ma join public.albums a on a.id=ma.album_id and a.owner_id=actor where ma.owner_id=actor and ma.month=v_month));
end;
$$;

create function moments_private.save_record(p_id uuid,p_record_date date,p_caption text,p_photos jsonb,p_expected_revision integer) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 record moments_private.weekly_moments; photo jsonb; path text; photo_id uuid; v_caption text:=btrim(coalesce(p_caption,''));
begin
 if p_id is null or p_record_date is null or p_record_date>today or p_record_date<'1900-01-01'::date
  or char_length(v_caption)>200 or p_expected_revision is null or p_expected_revision<0 then
  raise exception 'MOMENTS_INVALID_RECORD' using errcode='22023'; end if;
 if jsonb_typeof(p_photos) is distinct from 'array' or octet_length(p_photos::text)>8192 then
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
 -- Bound list payloads and storage growth without blocking edits to an existing
 -- month. Actor serialization also makes concurrent final-slot saves atomic.
 if record.id is null or date_trunc('month',record.record_date)<>date_trunc('month',p_record_date) then
  if(select count(*) from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null and m.id<>p_id
   and m.record_date>=date_trunc('month',p_record_date)::date and m.record_date<(date_trunc('month',p_record_date)+interval '1 month')::date)>=100 then
   raise exception 'MOMENTS_MONTH_FULL' using errcode='22023'; end if;
 end if;
 for photo in select value from jsonb_array_elements(p_photos) loop
  if jsonb_typeof(photo) is distinct from 'object' or exists(select 1 from jsonb_object_keys(photo) k where k not in('id','path','width','height'))
   or jsonb_typeof(photo->'id') is distinct from 'string' or (photo->>'id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   or jsonb_typeof(photo->'path') is distinct from 'string'
   or jsonb_typeof(photo->'width') is distinct from 'number' or (photo->>'width') !~ '^[1-9][0-9]{0,4}$'
   or jsonb_typeof(photo->'height') is distinct from 'number' or (photo->>'height') !~ '^[1-9][0-9]{0,4}$' then
   raise exception 'MOMENTS_INVALID_PHOTOS' using errcode='22023'; end if;
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
 if record.id is null then
  insert into moments_private.weekly_moments(id,owner_id,record_date,caption,photos) values(p_id,actor,p_record_date,v_caption,p_photos) returning * into record;
 else
  update moments_private.weekly_moments m set record_date=p_record_date,caption=v_caption,photos=p_photos,revision=m.revision+1,updated_at=moments_private.server_now()
   where m.id=p_id returning * into record;
 end if;
 return moments_private.record_json(record);
end;
$$;

create function moments_private.delete_record(p_id uuid,p_expected_revision integer) returns boolean
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); record moments_private.weekly_moments;
begin
 if p_id is null or p_expected_revision is null or p_expected_revision<1 then raise exception 'MOMENTS_INVALID_RECORD' using errcode='22023'; end if;
 select * into record from moments_private.weekly_moments where id=p_id and owner_id=actor for update;
 if not found or record.deleted_at is not null then return true; end if;
 if record.revision<>p_expected_revision then raise exception 'MOMENTS_REVISION_CONFLICT' using errcode='PT409'; end if;
 -- Keep an empty tombstone so a delayed upload/save cannot recreate a deletion.
 update moments_private.weekly_moments set photos='[]'::jsonb,caption='',revision=revision+1,deleted_at=moments_private.server_now(),updated_at=moments_private.server_now() where id=p_id;
 return true;
end;
$$;

create function moments_private.protect_photo() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.bucket_id<>'album-assets' or old.name !~ '^[0-9a-f-]{36}/moments/' or auth.uid() is null then
  return case when tg_op='DELETE' then old else new end; end if;
 if tg_op='UPDATE' and(to_jsonb(new)-array['last_accessed_at','updated_at'])=(to_jsonb(old)-array['last_accessed_at','updated_at']) then return new; end if;
 perform 1 from storage.objects where bucket_id=old.bucket_id and name=old.name for update;
 if exists(select 1 from moments_private.weekly_moments m where m.deleted_at is null and m.owner_id=split_part(old.name,'/',1)::uuid and m.photos @> jsonb_build_array(jsonb_build_object('path',old.name))) then
  raise exception 'MOMENTS_PHOTO_IN_USE' using errcode='42501'; end if;
 return case when tg_op='DELETE' then old else new end;
end;
$$;
create trigger moments_protect_record_photos before update or delete on storage.objects for each row execute function moments_private.protect_photo();

create function moments_private.create_month_album(p_month date,p_photo_ids uuid[],p_album jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true); today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 existing_id bigint; created_id bigint; paths text[]; used_paths text[]; document jsonb; all_document jsonb; field text; value text;
begin
 if p_month is null or extract(day from p_month)<>1 or p_month>date_trunc('month',today)::date or p_month<'1900-01-01'::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 select ma.album_id into existing_id from moments_private.month_albums ma join public.albums a on a.id=ma.album_id and a.owner_id=actor where ma.owner_id=actor and ma.month=p_month;
 if existing_id is not null then return jsonb_build_object('albumId',existing_id,'created',false); end if;
 if p_photo_ids is null or cardinality(p_photo_ids) not between 1 and 9 or array_position(p_photo_ids,null) is not null
  or(select count(distinct p) from unnest(p_photo_ids)p)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 select array_agg(p.photo->>'path' order by p.photo->>'path') into paths from moments_private.weekly_moments m
  cross join lateral jsonb_array_elements(m.photos)p(photo)
  where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date and(p.photo->>'id')::uuid=any(p_photo_ids);
 if coalesce(cardinality(paths),0)<>cardinality(p_photo_ids) then raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 if jsonb_typeof(p_album) is distinct from 'object' or octet_length(p_album::text)>1048576
  or exists(select 1 from jsonb_object_keys(p_album) k where k not in('title','ratio','cover_layers_json','cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme','target_pages','total_pages')) then
  raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 if jsonb_typeof(p_album->'title') is distinct from 'string' or char_length(btrim(p_album->>'title')) not between 1 and 80
  or jsonb_typeof(p_album->'ratio') is distinct from 'string' or char_length(p_album->>'ratio') not between 1 and 50
  or jsonb_typeof(p_album->'cover_layers_json') is distinct from 'string'
  or not pg_input_is_valid(p_album->>'cover_layers_json','jsonb') then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 foreach field in array array['target_pages','total_pages'] loop
  if jsonb_typeof(p_album->field) is distinct from 'number' or(p_album->>field) !~ '^[1-9][0-9]?$' or(p_album->>field)::integer>80 then
   raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 foreach field in array array['cover_image_url','cover_thumbnail_url','cover_original_url','cover_preview_url','cover_theme'] loop
  if p_album?field and jsonb_typeof(p_album->field) not in('string','null') then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 end loop;
 document:=(p_album->>'cover_layers_json')::jsonb;
 if jsonb_typeof(document) is distinct from 'object' then raise exception 'MOMENTS_INVALID_ALBUM' using errcode='22023'; end if;
 all_document:=jsonb_build_object('document',document,'album',p_album-'cover_layers_json');
 select array_agg(p order by p) into used_paths from album_private.paths(all_document)p;
 if used_paths is distinct from paths then raise exception 'MOMENTS_ALBUM_PHOTOS_MISMATCH' using errcode='42501'; end if;
 -- Every URL-bearing image field must use one of the selected canonical paths.
 for value in select j.value#>>'{}' from jsonb_path_query(all_document,'strict $.** ? (@.type() == "object").keyvalue() ? (@.key like_regex "(url|uri|src|path)$" flag "i").value')j(value) where jsonb_typeof(j.value)='string' loop
  if value<>'' and not(value=any(select 'supabase://album-assets/'||p from unnest(paths)p)) then
   raise exception 'MOMENTS_INVALID_ALBUM_IMAGE' using errcode='42501'; end if;
 end loop;
 insert into public.albums(owner_id,title,ratio,cover_layers_json,cover_image_url,cover_thumbnail_url,cover_original_url,cover_preview_url,cover_theme,target_pages,total_pages)
 values(actor,btrim(p_album->>'title'),p_album->>'ratio',p_album->>'cover_layers_json',nullif(p_album->>'cover_image_url',''),nullif(p_album->>'cover_thumbnail_url',''),nullif(p_album->>'cover_original_url',''),nullif(p_album->>'cover_preview_url',''),p_album->>'cover_theme',(p_album->>'target_pages')::integer,(p_album->>'total_pages')::integer) returning id into created_id;
 insert into moments_private.month_albums(owner_id,month,album_id)values(actor,p_month,created_id)
 on conflict(owner_id,month)do update set album_id=excluded.album_id,created_at=moments_private.server_now();
 return jsonb_build_object('albumId',created_id,'created',true);
end;
$$;

revoke all on all functions in schema moments_private from public,anon,authenticated,service_role;
grant execute on function moments_private.journal(date),moments_private.save_record(uuid,date,text,jsonb,integer),moments_private.delete_record(uuid,integer),moments_private.create_month_album(date,uuid[],jsonb) to authenticated;
create function public.get_moment_journal(p_month date default null) returns jsonb language sql security invoker set search_path='' as $$ select moments_private.journal(p_month) $$;
create function public.save_weekly_moment(p_id uuid,p_record_date date,p_caption text,p_photos jsonb,p_expected_revision integer default 0) returns jsonb language sql security invoker set search_path='' as $$ select moments_private.save_record(p_id,p_record_date,p_caption,p_photos,p_expected_revision) $$;
create function public.delete_weekly_moment(p_id uuid,p_expected_revision integer) returns boolean language sql security invoker set search_path='' as $$ select moments_private.delete_record(p_id,p_expected_revision) $$;
create function public.create_moment_month_album(p_month date,p_photo_ids uuid[],p_album jsonb) returns jsonb language sql security invoker set search_path='' as $$ select moments_private.create_month_album(p_month,p_photo_ids,p_album) $$;
revoke all on function public.get_moment_journal(date),public.save_weekly_moment(uuid,date,text,jsonb,integer),public.delete_weekly_moment(uuid,integer),public.create_moment_month_album(date,uuid[],jsonb) from public,anon,authenticated,service_role;
grant execute on function public.get_moment_journal(date),public.save_weekly_moment(uuid,date,text,jsonb,integer),public.delete_weekly_moment(uuid,integer),public.create_moment_month_album(date,uuid[],jsonb) to authenticated;

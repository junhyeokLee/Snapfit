-- Owner-only month summaries and weekly curation. This creates no albums,
-- publications, point events, uploads or changes to existing journal content.
create table moments_private.week_photo_choices (
 owner_id uuid not null references auth.users(id) on delete cascade,
 week_start date not null check(extract(isodow from week_start)=1),
 photo_ids uuid[] not null default '{}'::uuid[],
 updated_at timestamptz not null default clock_timestamp(),
 primary key(owner_id,week_start),
 check(cardinality(photo_ids) between 0 and 3),
 check(cardinality(photo_ids)=0 or array_ndims(photo_ids)=1),
 check(array_position(photo_ids,null) is null)
);
alter table moments_private.week_photo_choices enable row level security;
revoke all on moments_private.week_photo_choices from public,anon,authenticated,service_role;

create function moments_private.archive_months(p_before_month date,p_limit integer) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor();
 today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
 v_before date:=coalesce(p_before_month,(date_trunc('month',today)+interval '1 month')::date);
 result jsonb;
begin
 if p_limit is null or p_limit not between 1 and 12 or extract(day from v_before)<>1
  or v_before<'1900-01-01'::date or v_before>(date_trunc('month',today)+interval '1 month')::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 -- Seek one prior month at a time using weekly_moments_owner_date_idx. There
 -- are at most 100 records per month; old history is not decoded for this page.
 with recursive keys(month,n) as (
  (select date_trunc('month',m.record_date)::date,1
   from moments_private.weekly_moments m
   where m.owner_id=actor and m.deleted_at is null and m.record_date<v_before
   order by m.record_date desc,m.id limit 1)
  union all
  select prior.month,k.n+1 from keys k cross join lateral (
   select date_trunc('month',m.record_date)::date as month
   from moments_private.weekly_moments m
   where m.owner_id=actor and m.deleted_at is null and m.record_date<k.month
   order by m.record_date desc,m.id limit 1
  )prior where k.n<p_limit
 )
 select coalesce(jsonb_agg(jsonb_build_object(
  'month',k.month,'recordCount',s.records,'photoCount',s.photos,
  'latestRecordDate',s.latest,'coverPhoto',cover.photo) order by k.month desc),'[]'::jsonb)
 into result from keys k cross join lateral (
  select count(*) as records,sum(jsonb_array_length(m.photos)) as photos,max(m.record_date) as latest
  from moments_private.weekly_moments m where m.owner_id=actor and m.deleted_at is null
   and m.record_date>=k.month and m.record_date<(k.month+interval '1 month')::date
 )s cross join lateral (
  select m.photos->0 as photo from moments_private.weekly_moments m
  where m.owner_id=actor and m.deleted_at is null
   and m.record_date>=k.month and m.record_date<(k.month+interval '1 month')::date
  order by m.record_date desc,m.created_at desc,m.id desc limit 1
 )cover;
 return result;
end;
$$;

create function moments_private.week_photo_selection(p_week_start date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor();
 today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
begin
 if p_week_start is null or extract(isodow from p_week_start)<>1 or p_week_start<'1900-01-01'::date
  or p_week_start>date_trunc('week',today)::date then
  raise exception 'MOMENTS_INVALID_WEEK' using errcode='22023'; end if;
 return coalesce((select jsonb_agg(c.photo_id::text order by c.ordinality)
  from moments_private.week_photo_choices w cross join lateral unnest(w.photo_ids)with ordinality c(photo_id,ordinality)
  where w.owner_id=actor and w.week_start=p_week_start and exists(
   select 1 from moments_private.weekly_moments m cross join lateral jsonb_array_elements(m.photos)p(photo)
   where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_week_start and m.record_date<p_week_start+7
    and p.photo->>'id'=c.photo_id::text)), '[]'::jsonb);
end;
$$;

create function moments_private.month_photo_selection(p_month date) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor();
 today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
begin
 if p_month is null or extract(day from p_month)<>1 or p_month<'1900-01-01'::date
  or p_month>date_trunc('month',today)::date then
  raise exception 'MOMENTS_INVALID_MONTH' using errcode='22023'; end if;
 return coalesce((select jsonb_agg(x.photo_id::text order by x.week_start,x.ordinality)from(
  select distinct on(c.photo_id) c.photo_id,w.week_start,c.ordinality
  from moments_private.week_photo_choices w cross join lateral unnest(w.photo_ids)with ordinality c(photo_id,ordinality)
  where w.owner_id=actor and w.week_start>=date_trunc('week',p_month)::date
   and w.week_start<(p_month+interval '1 month')::date and exists(
    select 1 from moments_private.weekly_moments m cross join lateral jsonb_array_elements(m.photos)p(photo)
    where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_month and m.record_date<(p_month+interval '1 month')::date
     and m.record_date>=w.week_start and m.record_date<w.week_start+7 and p.photo->>'id'=c.photo_id::text)
  order by c.photo_id,w.week_start,c.ordinality
 )x),'[]'::jsonb);
end;
$$;

create function moments_private.save_week_photo_selection(p_week_start date,p_photo_ids uuid[]) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=moments_private.actor(true);
 today date:=(moments_private.server_now() at time zone 'Asia/Seoul')::date;
begin
 if p_week_start is null or extract(isodow from p_week_start)<>1 or p_week_start<'1900-01-01'::date
  or p_week_start>date_trunc('week',today)::date then
  raise exception 'MOMENTS_INVALID_WEEK' using errcode='22023'; end if;
 if p_photo_ids is null or cardinality(p_photo_ids) not between 0 and 3
  or(cardinality(p_photo_ids)>0 and array_ndims(p_photo_ids)<>1)
  or array_position(p_photo_ids,null) is not null
  or(select count(distinct p)from unnest(p_photo_ids)p)<>cardinality(p_photo_ids) then
  raise exception 'MOMENTS_INVALID_SELECTION' using errcode='22023'; end if;
 if exists(select 1 from unnest(p_photo_ids)c(photo_id)where(
   select count(*)from moments_private.weekly_moments m cross join lateral jsonb_array_elements(m.photos)p(photo)
   where m.owner_id=actor and m.deleted_at is null and m.record_date>=p_week_start and m.record_date<p_week_start+7
    and p.photo->>'id'=c.photo_id::text)<>1)then
  raise exception 'MOMENTS_SELECTION_CHANGED' using errcode='PT409'; end if;
 insert into moments_private.week_photo_choices(owner_id,week_start,photo_ids,updated_at)
 values(actor,p_week_start,p_photo_ids,moments_private.server_now())
 on conflict(owner_id,week_start)do update set photo_ids=excluded.photo_ids,updated_at=excluded.updated_at
 where week_photo_choices.photo_ids is distinct from excluded.photo_ids;
 return moments_private.week_photo_selection(p_week_start);
end;
$$;

-- An edited/deleted photo never returns later as an old candidate. Other weeks
-- remain untouched, and original record/album/publication data is not changed.
create function moments_private.prune_week_photo_choices()returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update moments_private.week_photo_choices w set photo_ids=array(
  select c.photo_id from unnest(w.photo_ids)with ordinality c(photo_id,ordinality)
  where exists(select 1 from moments_private.weekly_moments m cross join lateral jsonb_array_elements(m.photos)p(photo)
   where m.owner_id=w.owner_id and m.deleted_at is null and m.record_date>=w.week_start and m.record_date<w.week_start+7
    and p.photo->>'id'=c.photo_id::text)order by c.ordinality),updated_at=moments_private.server_now()
 where w.owner_id=old.owner_id and w.week_start=date_trunc('week',old.record_date)::date;
 return new;
end;
$$;
create trigger moments_prune_week_photo_choices after update of photos,record_date,deleted_at
 on moments_private.weekly_moments for each row
 when(old.photos is distinct from new.photos or old.record_date is distinct from new.record_date or old.deleted_at is distinct from new.deleted_at)
 execute function moments_private.prune_week_photo_choices();

revoke all on function moments_private.archive_months(date,integer),moments_private.week_photo_selection(date),
 moments_private.month_photo_selection(date),moments_private.save_week_photo_selection(date,uuid[]),
 moments_private.prune_week_photo_choices() from public,anon,authenticated,service_role;
grant execute on function moments_private.archive_months(date,integer),moments_private.week_photo_selection(date),
 moments_private.month_photo_selection(date),moments_private.save_week_photo_selection(date,uuid[]) to authenticated;

create function public.get_my_moment_months(p_before_month date default null,p_limit integer default 6)returns jsonb
 language sql security invoker set search_path='' as $$select moments_private.archive_months(p_before_month,p_limit)$$;
create function public.get_moment_week_photo_choices(p_week_start date)returns jsonb
 language sql security invoker set search_path='' as $$select moments_private.week_photo_selection(p_week_start)$$;
create function public.get_moment_month_photo_choices(p_month date)returns jsonb
 language sql security invoker set search_path='' as $$select moments_private.month_photo_selection(p_month)$$;
create function public.save_moment_week_photo_choices(p_week_start date,p_photo_ids uuid[])returns jsonb
 language sql security invoker set search_path='' as $$select moments_private.save_week_photo_selection(p_week_start,p_photo_ids)$$;
revoke all on function public.get_my_moment_months(date,integer),public.get_moment_week_photo_choices(date),
 public.get_moment_month_photo_choices(date),public.save_moment_week_photo_choices(date,uuid[])
 from public,anon,authenticated,service_role;
grant execute on function public.get_my_moment_months(date,integer),public.get_moment_week_photo_choices(date),
 public.get_moment_month_photo_choices(date),public.save_moment_week_photo_choices(date,uuid[]) to authenticated;
notify pgrst,'reload schema';

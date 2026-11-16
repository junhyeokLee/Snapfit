-- Owner-selected covers are preferences over public snapshots, never another
-- private photo source. Invalidated choices disappear and fall back naturally.
create table moments_private.public_month_covers(
 owner_id uuid not null references auth.users(id)on delete cascade,
 month date not null check(extract(day from month)=1),
 work_id uuid not null references public.social_works(id)on delete cascade,
 updated_at timestamptz not null default clock_timestamp(),
 primary key(owner_id,month)
);
create index public_month_cover_work_idx on moments_private.public_month_covers(work_id);
alter table moments_private.public_month_covers enable row level security;
revoke all on moments_private.public_month_covers from public,anon,authenticated,service_role;
create function moments_private.clear_unpublished_month_cover()returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.status<>'published'or new.moderation_hidden then delete from moments_private.public_month_covers where work_id=new.id;end if;
 return new;
end;
$$;
revoke all on function moments_private.clear_unpublished_month_cover()from public,anon,authenticated,service_role;
create trigger social_clear_month_cover after update of status,moderation_hidden on public.social_works
 for each row execute function moments_private.clear_unpublished_month_cover();

alter function social_private.social_api(text,jsonb)rename to social_api_safety_v1;
revoke all on function social_private.social_api_safety_v1(text,jsonb)from public,anon,authenticated,service_role;
create function social_private.social_api(p_action text,p_payload jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_target uuid; v_month date; v_cursor_month date; v_cursor_date date; v_cursor_id uuid; v_work public.social_works;
 v_record moments_private.weekly_moments; v_offset integer; v_limit integer; v_items jsonb; v_cursor jsonb; v_next jsonb;
begin
 if p_action='ownMomentRecord'then
  v_actor:=moments_private.actor();
  select m.* into v_record from public.social_works w join social_private.moment_publication_sources b on b.work_id=w.id and b.owner_id=v_actor
   join moments_private.weekly_moments m on m.id=b.record_id and m.owner_id=v_actor
   where w.id=(p_payload->>'workId')::uuid and w.author_id=v_actor and w.kind='moment'and w.status<>'deleted'and m.deleted_at is null;
  if not found then return null;end if;
  return moments_private.record_json(v_record);
 elsif p_action='setMomentMonthCover'then
  v_actor:=moments_private.actor(true);
  if jsonb_typeof(p_payload->'month')is distinct from'string'or(p_payload->>'month')!~'^[0-9]{4}-(0[1-9]|1[0-2])-01$'
   or not pg_input_is_valid(p_payload->>'month','date')then raise exception 'social_invalid_month' using errcode='22023';end if;
  v_month:=(p_payload->>'month')::date;
  if v_month<'1900-01-01'::date then raise exception 'social_invalid_month' using errcode='22023';end if;
  v_cursor_id:=nullif(p_payload->>'workId','')::uuid;
  if v_cursor_id is null then delete from moments_private.public_month_covers where owner_id=v_actor and month=v_month;
  else
   select * into v_work from public.social_works w where w.id=v_cursor_id and w.author_id=v_actor and w.kind='moment'
    and w.record_date>=v_month and w.record_date<(v_month+interval'1 month')::date and social_private.public_work_visible(w.id)for update;
   if not found then raise exception 'social_invalid_month_cover' using errcode='42501';end if;
   insert into moments_private.public_month_covers(owner_id,month,work_id)values(v_actor,v_month,v_cursor_id)
    on conflict(owner_id,month)do update set work_id=excluded.work_id,updated_at=clock_timestamp();
  end if;
  return jsonb_build_object('month',v_month,'workId',v_cursor_id,'selectedWorkId',v_cursor_id);
 end if;
 if p_action is null or p_action not in('profileMomentMonthsPage','profileMomentMonthPage')then return social_private.social_api_safety_v1(p_action,p_payload);end if;
 v_target:=(p_payload->>'userId')::uuid;if v_target is null then raise exception 'social_profile_required' using errcode='22023';end if;
 v_offset:=coalesce((p_payload->>'offset')::integer,0);
 v_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,case when p_action='profileMomentMonthsPage'then 6 else 12 end),1),case when p_action='profileMomentMonthsPage'then 12 else 30 end);
 if v_offset<0 or v_offset>10000 then raise exception 'social_invalid_page_offset' using errcode='22023';end if;
 v_cursor:=p_payload->'cursor';
 if v_cursor is not null and v_cursor<>'null'::jsonb then
  if jsonb_typeof(v_cursor)<>'object'or v_offset<>0 then raise exception 'social_invalid_cursor' using errcode='22023';end if;
  if p_action='profileMomentMonthsPage'then
   if jsonb_typeof(v_cursor->'month')is distinct from'string'or(v_cursor->>'month')!~'^[0-9]{4}-(0[1-9]|1[0-2])-01$'
    or not pg_input_is_valid(v_cursor->>'month','date')then raise exception 'social_invalid_cursor' using errcode='22023';end if;
   v_cursor_month:=(v_cursor->>'month')::date;
  else
   if jsonb_typeof(v_cursor->'recordDate')is distinct from'string'or not pg_input_is_valid(v_cursor->>'recordDate','date')
    or nullif(v_cursor->>'id','')is null then raise exception 'social_invalid_cursor' using errcode='22023';end if;
   v_cursor_date:=(v_cursor->>'recordDate')::date;v_cursor_id:=(v_cursor->>'id')::uuid;
  end if;
 end if;
 if p_action='profileMomentMonthsPage'then
  with visible as materialized(
   select w.id,w.record_date,coalesce(w.published_at,w.created_at)sort_at,date_trunc('month',w.record_date::timestamp)::date calendar_month
   from public.social_works w where w.author_id=v_target and w.kind='moment'and social_private.public_work_visible(w.id)and social_private.social_visible(w.id)
  ),collections as(
   select calendar_month,count(*)record_count,(array_agg(id order by record_date desc,sort_at desc,id desc))[1]cover_id
   from visible group by calendar_month having v_cursor_month is null or calendar_month<v_cursor_month
   order by calendar_month desc offset v_offset limit v_limit+1
  )
  select coalesce(jsonb_agg(jsonb_build_object('month',q.calendar_month,'recordCount',q.record_count,
   'cover',social_private.social_work_json(coalesce(chosen.id,q.cover_id)),
   'selectedWorkId',case when auth.uid()=v_target then chosen.id else null end)order by q.calendar_month desc),'[]'::jsonb)into v_items
  from collections q left join moments_private.public_month_covers preference on preference.owner_id=v_target and preference.month=q.calendar_month
   left join public.social_works chosen on chosen.id=preference.work_id and chosen.author_id=v_target and chosen.kind='moment'
    and chosen.record_date>=q.calendar_month and chosen.record_date<(q.calendar_month+interval'1 month')::date
    and social_private.public_work_visible(chosen.id)and social_private.social_visible(chosen.id);
  if jsonb_array_length(v_items)>v_limit then v_next:=jsonb_build_object('month',v_items->(v_limit-1)->>'month');end if;
 else
  if jsonb_typeof(p_payload->'month')is distinct from'string'or(p_payload->>'month')!~'^[0-9]{4}-(0[1-9]|1[0-2])-01$'
   or not pg_input_is_valid(p_payload->>'month','date')then raise exception 'social_invalid_month' using errcode='22023';end if;
  v_month:=(p_payload->>'month')::date;
  if v_month<'1900-01-01'::date then raise exception 'social_invalid_month' using errcode='22023';end if;
  if v_cursor_date is not null and(v_cursor_date<v_month or v_cursor_date>=(v_month+interval'1 month')::date)then raise exception 'social_invalid_cursor' using errcode='22023';end if;
  select coalesce(jsonb_agg(social_private.social_work_json(q.id)order by q.record_date desc,q.id desc),'[]'::jsonb)into v_items
  from(select w.id,w.record_date from public.social_works w where w.author_id=v_target and w.kind='moment'
   and w.record_date>=v_month and w.record_date<(v_month+interval'1 month')::date
   and social_private.public_work_visible(w.id)and social_private.social_visible(w.id)
   and(v_cursor_date is null or(w.record_date,w.id)<(v_cursor_date,v_cursor_id))
   order by w.record_date desc,w.id desc offset v_offset limit v_limit+1)q;
  if jsonb_array_length(v_items)>v_limit then v_next:=jsonb_build_object('recordDate',v_items->(v_limit-1)->>'recordDate','id',v_items->(v_limit-1)->>'id');end if;
 end if;
 return jsonb_build_object('items',(select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)from jsonb_array_elements(v_items)with ordinality where ordinality<=v_limit),
  'hasMore',jsonb_array_length(v_items)>v_limit,'nextOffset',v_offset+least(jsonb_array_length(v_items),v_limit),'nextCursor',v_next);
end;
$$;
revoke all on function social_private.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb)to anon,authenticated;
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb)returns jsonb
language sql security invoker set search_path='' as $$select social_private.social_api(p_action,p_payload)$$;
revoke all on function public.social_api(text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb)to anon,authenticated;

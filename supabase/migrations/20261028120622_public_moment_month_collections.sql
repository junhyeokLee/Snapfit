-- Public journals are collected by calendar month without exposing private
-- record IDs, original photos or a client-side partial-page count.
create index social_moment_calendar_idx on public.social_works(author_id,record_date desc,id desc)
 where kind='moment' and status='published';

alter function social_private.social_api(text,jsonb) rename to social_api_moments_v1;
revoke all on function social_private.social_api_moments_v1(text,jsonb) from public,anon,authenticated,service_role;

create function social_private.social_api(p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target uuid; v_month date; page_offset integer; page_limit integer; result jsonb;
begin
 if p_action is null or p_action not in('profileMomentMonthsPage','profileMomentMonthPage') then
  return social_private.social_api_moments_v1(p_action,p_payload);
 end if;
 target:=(p_payload->>'userId')::uuid;
 if target is null then raise exception 'social_profile_required' using errcode='22023'; end if;
 page_offset:=coalesce((p_payload->>'offset')::integer,0);
 page_limit:=least(greatest(coalesce((p_payload->>'limit')::integer,
  case when p_action='profileMomentMonthsPage' then 6 else 12 end),1),
  case when p_action='profileMomentMonthsPage' then 12 else 30 end);
 if page_offset<0 or page_offset>10000 then raise exception 'social_invalid_page_offset' using errcode='22023'; end if;

 if p_action='profileMomentMonthsPage' then
  -- Count the entire visible month first. Pagination applies to the grouped
  -- months, never to an already truncated list of twelve photographs.
  with visible as materialized(
   select x.id,x.record_date,coalesce(x.published_at,x.created_at) sort_at,
    date_trunc('month',x.record_date::timestamp)::date calendar_month
   from public.social_works x
   where x.author_id=target and x.kind='moment' and x.status='published'
    and social_private.social_visible(x.id) and social_private.moment_source_current(x.id)
  ),months as(
   select calendar_month,count(*) record_count,
    (array_agg(id order by record_date desc,sort_at desc,id desc))[1] cover_id
   from visible group by calendar_month
   order by calendar_month desc offset page_offset limit page_limit+1
  )
  select coalesce(jsonb_agg(jsonb_build_object('month',q.calendar_month,'recordCount',q.record_count,
   'cover',social_private.social_work_json(q.cover_id)) order by q.calendar_month desc),'[]'::jsonb) into result from months q;
 else
  if jsonb_typeof(p_payload->'month') is distinct from 'string'
   or(p_payload->>'month') !~ '^[0-9]{4}-(0[1-9]|1[0-2])-01$'
   or not pg_input_is_valid(p_payload->>'month','date') then
   raise exception 'social_invalid_month' using errcode='22023';
  end if;
  v_month:=(p_payload->>'month')::date;
  if v_month<'1900-01-01'::date then raise exception 'social_invalid_month' using errcode='22023'; end if;
  select coalesce(jsonb_agg(social_private.social_work_json(q.id) order by q.record_date desc,q.id desc),'[]'::jsonb) into result
  from(select x.id,x.record_date from public.social_works x
   where x.author_id=target and x.kind='moment' and x.status='published'
    and x.record_date>=v_month and x.record_date<(v_month+interval '1 month')::date
    and social_private.social_visible(x.id) and social_private.moment_source_current(x.id)
   order by x.record_date desc,x.id desc offset page_offset limit page_limit+1)q;
 end if;
 return jsonb_build_object('items',
  (select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)from jsonb_array_elements(result)with ordinality where ordinality<=page_limit),
  'hasMore',jsonb_array_length(result)>page_limit,
  'nextOffset',page_offset+least(jsonb_array_length(result),page_limit));
end;
$$;
revoke all on function social_private.social_api(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function social_private.social_api(text,jsonb) to anon,authenticated;

-- Invalidate pooled plans which previously resolved the renamed function.
create or replace function public.social_api(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$select social_private.social_api(p_action,p_payload)$$;
revoke all on function public.social_api(text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.social_api(text,jsonb) to anon,authenticated;

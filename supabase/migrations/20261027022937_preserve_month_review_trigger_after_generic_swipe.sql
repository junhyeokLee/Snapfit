-- Preserve the month-end reminder after viewing its generic introduction.
-- Existing deliveries, quota, schedules, history and RPC signatures are retained.
create or replace function home_news_private.delivery_api(p_operation text,p_campaign_ids text[],p_delivery_id uuid,p_campaign_id text)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=auth.uid(); server_time timestamptz; state jsonb; allowed text[]:='{}'; candidate text;
 kind text; first_kind text; delivery home_news_private.deliveries; new_id uuid;
begin
 if actor is null then raise exception 'HOME_NEWS_LOGIN_REQUIRED'using errcode='42501';end if;
 server_time:=home_news_private.server_now();
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception 'HOME_NEWS_ACCOUNT_REQUIRED'using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('home-news:'||actor::text,0));
 perform 1 from home_news_private.campaigns c order by c.kind for share;
 server_time:=home_news_private.server_now();
 state:=home_news_private.state_json(actor,server_time,false);
 if p_operation='view' then
  select * into delivery from home_news_private.deliveries d where d.id=p_delivery_id and d.user_id=actor for update;
  if not found or server_time>=delivery.expires_at or server_time<delivery.shown_at
   or p_campaign_id is null or not(p_campaign_id=any(delivery.campaign_ids))then
   return state||jsonb_build_object('viewed',false);end if;
  kind:=home_news_private.campaign_kind(actor,p_campaign_id,server_time,false);
  if kind is null then return state||jsonb_build_object('viewed',false);end if;
  -- A generic recap card stays browsable before the real month-end prompt.
  -- Do not consume its once-per-month trigger until photos and timing qualify.
  if kind='monthReview'and home_news_private.campaign_kind(actor,p_campaign_id,server_time,true)is null then
   return state||jsonb_build_object('viewed',false);end if;
  insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at,delivery_id)
  values(actor,p_campaign_id,kind,date_trunc('month',server_time at time zone 'Asia/Seoul')::date,server_time,delivery.id)
  on conflict(user_id,campaign_id)do nothing;
  return home_news_private.state_json(actor,server_time,false)||jsonb_build_object('viewed',true);
 end if;
 if p_operation<>'claim'then raise exception 'HOME_NEWS_INVALID_OPERATION'using errcode='22023';end if;
 if p_campaign_ids is null or cardinality(p_campaign_ids)not between 1 and 4 or array_position(p_campaign_ids,null)is not null
  or array_ndims(p_campaign_ids)<>1 or array_lower(p_campaign_ids,1)<>1
  or(select count(distinct id)from unnest(p_campaign_ids)id)<>cardinality(p_campaign_ids)
  or exists(select 1 from unnest(p_campaign_ids)id where char_length(id)not between 1 and 80)then
  raise exception 'HOME_NEWS_INVALID_CAMPAIGNS'using errcode='22023';end if;
 state:=state||jsonb_build_object('deliveryId',null,'allowedCampaignIds','[]'::jsonb);
 first_kind:=home_news_private.campaign_kind(actor,p_campaign_ids[1],server_time,true);
 if first_kind is null or(state->>'dailyCount')::integer>=1 or(state->>'weeklyCount')::integer>=2
  or exists(select 1 from home_news_private.exposures where user_id=actor and campaign_id=p_campaign_ids[1])then return state;end if;
 foreach candidate in array p_campaign_ids loop
  if home_news_private.campaign_kind(actor,candidate,server_time,false)is not null then allowed:=array_append(allowed,candidate);end if;
 end loop;
 insert into home_news_private.deliveries(user_id,campaign_ids,shown_at,expires_at)
 values(actor,allowed,server_time,server_time+interval'30 minutes')returning id into new_id;
 insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at,delivery_id)
 values(actor,p_campaign_ids[1],first_kind,date_trunc('month',server_time at time zone 'Asia/Seoul')::date,server_time,new_id);
 return home_news_private.state_json(actor,server_time,true)||jsonb_build_object('deliveryId',new_id,'allowedCampaignIds',to_jsonb(allowed));
end;
$$;

-- Home entry is an explicit delivery opportunity. Only remote scheduling and
-- the account's server-dated "hide for today" preference suppress delivery.
create table home_news_private.preferences (
 user_id uuid primary key references auth.users(id)on delete cascade,
 hidden_date date not null,
 updated_at timestamptz not null
);
alter table home_news_private.preferences enable row level security;
revoke all on home_news_private.preferences from public,anon,authenticated,service_role;

-- Bound JSON independently of how often a person opens home: latest 80 first
-- impressions and 50 deliveries, plus the deliveries those impressions refer to.
-- Omitted aggregate counts retain the date/count consistency of older clients.
create or replace function home_news_private.state_json(p_user uuid,p_at timestamptz,p_claimed boolean)returns jsonb
language sql stable security invoker set search_path=''as $$
 with context as(select(p_at at time zone'Asia/Seoul')::date today,
  date_trunc('week',p_at at time zone'Asia/Seoul')::date week_start),
 owned as(select e.* from home_news_private.exposures e where e.user_id=p_user order by e.shown_at desc,e.campaign_id limit 80),
 recent as(select d.id from home_news_private.deliveries d where d.user_id=p_user order by d.shown_at desc,d.id desc limit 50),
 deliveries as(select d.* from home_news_private.deliveries d where d.user_id=p_user
  and(d.id in(select id from recent)or d.id in(select delivery_id from owned where delivery_id is not null))),
 impressions as(select e.shown_at from home_news_private.exposures e,context c where e.user_id=p_user and e.delivery_id is null
   and e.shown_at>=c.week_start::timestamp at time zone'Asia/Seoul'
  union all select d.shown_at from home_news_private.deliveries d,context c where d.user_id=p_user
   and d.shown_at>=c.week_start::timestamp at time zone'Asia/Seoul'),
 included as(select e.shown_at from owned e where e.delivery_id is null union all select d.shown_at from deliveries d),
 counts as(select
  (select count(*)from impressions i where i.shown_at>=c.today::timestamp at time zone'Asia/Seoul')daily_count,
  (select count(*)from impressions)weekly_count,
  (select count(*)from included i where i.shown_at>=c.today::timestamp at time zone'Asia/Seoul')included_daily,
  (select count(*)from included i where i.shown_at>=c.week_start::timestamp at time zone'Asia/Seoul')included_weekly
  from context c),
 preference as(select p.hidden_date from home_news_private.preferences p where p.user_id=p_user)
 select jsonb_build_object('userId',p_user,'serverNow',p_at,'serverDate',c.today::text,'weekStart',c.week_start::text,
  'timezone','Asia/Seoul','claimed',p_claimed,'dailyCount',n.daily_count,'weeklyCount',n.weekly_count,
  'omittedDailyCount',n.daily_count-n.included_daily,'omittedWeeklyCount',n.weekly_count-n.included_weekly,
  'hiddenForToday',coalesce((select hidden_date=c.today from preference),false),
  'hiddenUntil',case when(select hidden_date=c.today from preference)then(c.today+1)::timestamp at time zone'Asia/Seoul'else null end,
  'hasAttendanceEver',exists(select 1 from attendance_private.daily_attendance a where a.user_id=p_user),
  'hasReferralReward',exists(select 1 from referral_private.redemptions r where r.invitee_id=p_user or r.inviter_id=p_user)
   or exists(select 1 from public.point_ledger l where l.user_id=p_user and l.reason in('REFERRAL_INVITER','REFERRAL_INVITEE')),
  'campaigns',home_news_private.campaigns_json(),
  'deliveries',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'shownAt',d.shown_at)order by d.shown_at desc,d.id)from deliveries d),'[]'::jsonb),
  'history',coalesce((select jsonb_agg(jsonb_build_object('id',e.campaign_id,'kind',e.kind,'month',e.month::text,'shownAt',e.shown_at,
   'dismissedAt',e.dismissed_at,'clickedAt',e.clicked_at,'deliveryId',e.delivery_id)order by e.shown_at desc,e.campaign_id)from owned e),'[]'::jsonb))from context c cross join counts n
$$;

create or replace function home_news_private.delivery_api(p_operation text,p_campaign_ids text[],p_delivery_id uuid,p_campaign_id text)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=auth.uid();server_time timestamptz;state jsonb;allowed text[]:='{}';candidate text;
 kind text;first_kind text;delivery home_news_private.deliveries;new_id uuid;
begin
 if actor is null then raise exception'HOME_NEWS_LOGIN_REQUIRED'using errcode='42501';end if;
 server_time:=home_news_private.server_now();
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception'HOME_NEWS_ACCOUNT_REQUIRED'using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('home-news:'||actor::text,0));
 perform 1 from home_news_private.campaigns c order by c.kind for share;
 server_time:=home_news_private.server_now();
 state:=home_news_private.state_json(actor,server_time,false);
 if p_operation='view'then
  select * into delivery from home_news_private.deliveries d where d.id=p_delivery_id and d.user_id=actor for update;
  if not found or server_time>=delivery.expires_at or server_time<delivery.shown_at
   or(state->>'hiddenForToday')::boolean or p_campaign_id is null or not(p_campaign_id=any(delivery.campaign_ids))then
   return state||jsonb_build_object('viewed',false);end if;
  kind:=home_news_private.campaign_kind(actor,p_campaign_id,server_time,false);
  if kind is null then return state||jsonb_build_object('viewed',false);end if;
  insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at,delivery_id)
  values(actor,p_campaign_id,kind,date_trunc('month',server_time at time zone'Asia/Seoul')::date,server_time,delivery.id)
  on conflict(user_id,campaign_id)do nothing;
  return home_news_private.state_json(actor,server_time,false)||jsonb_build_object('viewed',true);
 end if;
 if p_operation<>'claim'then raise exception'HOME_NEWS_INVALID_OPERATION'using errcode='22023';end if;
 if p_campaign_ids is null or cardinality(p_campaign_ids)not between 1 and 4 or array_position(p_campaign_ids,null)is not null
  or array_ndims(p_campaign_ids)<>1 or array_lower(p_campaign_ids,1)<>1
  or(select count(distinct id)from unnest(p_campaign_ids)id)<>cardinality(p_campaign_ids)
  or exists(select 1 from unnest(p_campaign_ids)id where char_length(id)not between 1 and 80)then
  raise exception'HOME_NEWS_INVALID_CAMPAIGNS'using errcode='22023';end if;
 state:=state||jsonb_build_object('deliveryId',null,'allowedCampaignIds','[]'::jsonb);
 if(state->>'hiddenForToday')::boolean then return state;end if;
 foreach candidate in array p_campaign_ids loop
  if home_news_private.campaign_kind(actor,candidate,server_time,false)is not null then allowed:=array_append(allowed,candidate);end if;
 end loop;
 if cardinality(allowed)=0 then return state;end if;
 first_kind:=home_news_private.campaign_kind(actor,allowed[1],server_time,false);
 -- Expired repeated deliveries older than 35 days are not needed for current
 -- statistics. Keep every delivery linked by a first-seen campaign record.
 delete from home_news_private.deliveries d where d.user_id=actor and d.shown_at<server_time-interval'35 days'
  and not exists(select 1 from home_news_private.exposures e where e.user_id=actor and e.delivery_id=d.id);
 insert into home_news_private.deliveries(user_id,campaign_ids,shown_at,expires_at)
 values(actor,allowed,server_time,server_time+interval'30 minutes')returning id into new_id;
 insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at,delivery_id)
 values(actor,allowed[1],first_kind,date_trunc('month',server_time at time zone'Asia/Seoul')::date,server_time,new_id)
 on conflict(user_id,campaign_id)do nothing;
 return home_news_private.state_json(actor,server_time,true)||jsonb_build_object('deliveryId',new_id,'allowedCampaignIds',to_jsonb(allowed));
end;
$$;

create or replace function home_news_private.news_api(p_operation text,p_campaign_id text,p_interaction text)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=auth.uid();server_time timestamptz;
begin
 if p_operation='claim'then return home_news_private.delivery_api('claim',array[p_campaign_id],null,null);end if;
 if actor is null then raise exception'HOME_NEWS_LOGIN_REQUIRED'using errcode='42501';end if;
 server_time:=home_news_private.server_now();
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception'HOME_NEWS_ACCOUNT_REQUIRED'using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('home-news:'||actor::text,0));
 server_time:=home_news_private.server_now();
 if p_operation='state'then return home_news_private.state_json(actor,server_time,false);end if;
 if p_operation='hide'then
  insert into home_news_private.preferences(user_id,hidden_date,updated_at)
  values(actor,(server_time at time zone'Asia/Seoul')::date,server_time)
  on conflict(user_id)do update set hidden_date=excluded.hidden_date,updated_at=excluded.updated_at;
  return home_news_private.state_json(actor,server_time,false);
 end if;
 if p_operation<>'interaction'then raise exception'HOME_NEWS_INVALID_OPERATION'using errcode='22023';end if;
 if p_campaign_id is null or char_length(p_campaign_id)not between 1 and 80 then
  raise exception'HOME_NEWS_INVALID_CAMPAIGN'using errcode='22023';end if;
 if p_interaction='dismiss'then update home_news_private.exposures set dismissed_at=coalesce(dismissed_at,greatest(shown_at,server_time))where user_id=actor and campaign_id=p_campaign_id;
 elsif p_interaction='click'then update home_news_private.exposures set clicked_at=coalesce(clicked_at,greatest(shown_at,server_time))where user_id=actor and campaign_id=p_campaign_id;
 else raise exception'HOME_NEWS_INVALID_INTERACTION'using errcode='22023';end if;
 return home_news_private.state_json(actor,server_time,false);
end;
$$;

create function public.hide_home_news_for_today()returns jsonb
language sql volatile security invoker set search_path=''as $$select home_news_private.news_api('hide',null,null)$$;
revoke all on function public.hide_home_news_for_today()from public,anon,authenticated,service_role;
grant execute on function public.hide_home_news_for_today()to authenticated;

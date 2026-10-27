-- Delivery state only. This feature does not credit points, publish photos,
-- generate albums, or retain any image URL or private record content.
create schema home_news_private;
revoke all on schema home_news_private from public,anon,authenticated,service_role;
grant usage on schema home_news_private to authenticated;

create table home_news_private.exposures (
 user_id uuid not null references auth.users(id) on delete cascade,
 campaign_id text not null check(char_length(campaign_id) between 1 and 80),
 kind text not null check(kind in('monthlyDesign','attendance','referral','monthReview')),
 month date not null check(extract(day from month)=1),
 shown_at timestamptz not null,
 dismissed_at timestamptz,
 clicked_at timestamptz,
 primary key(user_id,campaign_id),
 check(dismissed_at is null or dismissed_at>=shown_at),
 check(clicked_at is null or clicked_at>=shown_at),
 check((kind='monthlyDesign' and campaign_id='monthly-design:'||to_char(month,'YYYY-MM'))
  or(kind='attendance' and campaign_id='attendance-benefit:v1')
  or(kind='referral' and campaign_id='referral-benefit:v1')
  or(kind='monthReview' and campaign_id='month-review:'||to_char(month,'YYYY-MM')))
);
create index home_news_exposures_owner_time_idx on home_news_private.exposures(user_id,shown_at desc);
alter table home_news_private.exposures enable row level security;
revoke all on home_news_private.exposures from public,anon,authenticated,service_role;

-- Kept internal so integration tests can replace it in a disposable database.
-- No RPC accepts a date, timezone, user ID, or client clock override.
create function home_news_private.server_now() returns timestamptz
language sql volatile security invoker set search_path='' as $$ select clock_timestamp() $$;
revoke all on function home_news_private.server_now() from public,anon,authenticated,service_role;

create function home_news_private.state_json(p_user uuid,p_at timestamptz,p_claimed boolean) returns jsonb
language sql stable security invoker set search_path='' as $$
 with context as(
  select (p_at at time zone 'Asia/Seoul')::date today,
   date_trunc('week',p_at at time zone 'Asia/Seoul')::date week_start
 ), owned as(select e.* from home_news_private.exposures e where e.user_id=p_user)
 select jsonb_build_object(
  'userId',p_user,'serverNow',p_at,'serverDate',c.today::text,
  'weekStart',c.week_start::text,'timezone','Asia/Seoul','claimed',p_claimed,
  'dailyCount',(select count(*) from owned e
   where e.shown_at>=c.today::timestamp at time zone 'Asia/Seoul'
    and e.shown_at<(c.today+1)::timestamp at time zone 'Asia/Seoul'),
  'weeklyCount',(select count(*) from owned e
   where e.shown_at>=c.week_start::timestamp at time zone 'Asia/Seoul'
    and e.shown_at<(c.week_start+7)::timestamp at time zone 'Asia/Seoul'),
  'hasAttendanceEver',exists(select 1 from attendance_private.daily_attendance a where a.user_id=p_user),
  'hasReferralReward',exists(select 1 from referral_private.redemptions r where r.invitee_id=p_user or r.inviter_id=p_user)
   or exists(select 1 from public.point_ledger l where l.user_id=p_user and l.reason in('REFERRAL_INVITER','REFERRAL_INVITEE')),
  'history',coalesce((select jsonb_agg(jsonb_build_object(
   'id',e.campaign_id,'kind',e.kind,'month',e.month::text,'shownAt',e.shown_at,
   'dismissedAt',e.dismissed_at,'clickedAt',e.clicked_at) order by e.shown_at desc,e.campaign_id)
   from owned e),'[]'::jsonb))from context c
$$;
revoke all on function home_news_private.state_json(uuid,timestamptz,boolean) from public,anon,authenticated,service_role;

-- All entry points share a per-account transaction lock, including reads and
-- interactions. Concurrent app/web claims cannot consume the same daily slot.
create function home_news_private.news_api(p_operation text,p_campaign_id text,p_interaction text) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=auth.uid(); server_time timestamptz; today date; week_start date;
 campaign_month date; campaign_kind text; state jsonb;
begin
 if actor is null then raise exception 'HOME_NEWS_LOGIN_REQUIRED' using errcode='42501'; end if;
 server_time:=home_news_private.server_now();
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time) for key share;
 if not found then raise exception 'HOME_NEWS_ACCOUNT_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('home-news:'||actor::text,0));
 -- Read after the lock: a request queued across Korean midnight uses the new day.
 server_time:=home_news_private.server_now();
 today:=(server_time at time zone 'Asia/Seoul')::date;
 week_start:=date_trunc('week',today::timestamp)::date;
 campaign_month:=date_trunc('month',today::timestamp)::date;
 if p_operation='state' then return home_news_private.state_json(actor,server_time,false); end if;
 if p_campaign_id is null or char_length(p_campaign_id) not between 1 and 80 then
  raise exception 'HOME_NEWS_INVALID_CAMPAIGN' using errcode='22023'; end if;

 if p_operation='interaction' then
  if p_interaction='dismiss' then
   update home_news_private.exposures set dismissed_at=coalesce(dismissed_at,greatest(shown_at,server_time))
    where user_id=actor and campaign_id=p_campaign_id;
  elsif p_interaction='click' then
   update home_news_private.exposures set clicked_at=coalesce(clicked_at,greatest(shown_at,server_time))
    where user_id=actor and campaign_id=p_campaign_id;
  else raise exception 'HOME_NEWS_INVALID_INTERACTION' using errcode='22023'; end if;
  -- Manual replay does not create a delivery row or consume an automatic slot.
  return home_news_private.state_json(actor,server_time,false);
 end if;
 if p_operation<>'claim' then raise exception 'HOME_NEWS_INVALID_OPERATION' using errcode='22023'; end if;

 state:=home_news_private.state_json(actor,server_time,false);
 if exists(select 1 from home_news_private.exposures where user_id=actor and campaign_id=p_campaign_id)
  or(state->>'dailyCount')::integer>=1 or(state->>'weeklyCount')::integer>=2 then return state; end if;

 if p_campaign_id='monthly-design:'||to_char(campaign_month,'YYYY-MM') then
  campaign_kind:='monthlyDesign';
 elsif p_campaign_id='attendance-benefit:v1' then
  if(state->>'hasAttendanceEver')::boolean then return state; end if;
  campaign_kind:='attendance';
 elsif p_campaign_id='referral-benefit:v1' then
  if(state->>'hasReferralReward')::boolean then return state; end if;
  campaign_kind:='referral';
 elsif p_campaign_id='month-review:'||to_char(campaign_month,'YYYY-MM') then
  if today<(campaign_month+interval '1 month')::date-7
   or not exists(select 1 from moments_private.weekly_moments m
    where m.owner_id=actor and m.deleted_at is null and jsonb_array_length(m.photos)>0
     and m.record_date>=campaign_month and m.record_date<=today)
   or exists(select 1 from moments_private.month_albums m join public.albums a on a.id=m.album_id and a.owner_id=actor
    where m.owner_id=actor and m.month=campaign_month) then return state; end if;
  campaign_kind:='monthReview';
 else
  -- Old/future campaigns cannot claim a new slot. Existing histories remain readable.
  return state;
 end if;

 insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at)
 values(actor,p_campaign_id,campaign_kind,campaign_month,server_time);
 return home_news_private.state_json(actor,server_time,true);
end;
$$;
revoke all on function home_news_private.news_api(text,text,text) from public,anon,authenticated,service_role;
grant execute on function home_news_private.news_api(text,text,text) to authenticated;

create function public.get_home_news_state() returns jsonb
language sql volatile security invoker set search_path='' as $$ select home_news_private.news_api('state',null,null) $$;
create function public.claim_home_news_exposure(p_campaign_id text) returns jsonb
language sql volatile security invoker set search_path='' as $$ select home_news_private.news_api('claim',p_campaign_id,null) $$;
create function public.record_home_news_interaction(p_campaign_id text,p_interaction text) returns jsonb
language sql volatile security invoker set search_path='' as $$ select home_news_private.news_api('interaction',p_campaign_id,p_interaction) $$;
revoke all on function public.get_home_news_state(),public.claim_home_news_exposure(text),public.record_home_news_interaction(text,text)
 from public,anon,authenticated,service_role;
grant execute on function public.get_home_news_state(),public.claim_home_news_exposure(text),public.record_home_news_interaction(text,text)
 to authenticated;

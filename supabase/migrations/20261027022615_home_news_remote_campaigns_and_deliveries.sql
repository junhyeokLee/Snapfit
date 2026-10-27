-- Remotely scheduled home news and a four-card popup counted as one delivery.
-- Existing single-card exposure rows and all point/photo/album data are retained.
create table home_news_private.campaigns (
 kind text primary key check(kind in('monthlyDesign','attendance','referral','monthReview')),
 enabled boolean not null default true,
 starts_at timestamptz,
 ends_at timestamptz,
 sort_order integer not null check(sort_order between -1000 and 1000),
 updated_at timestamptz not null default clock_timestamp(),
 check(starts_at is null or ends_at is null or ends_at>starts_at)
);
insert into home_news_private.campaigns(kind,sort_order) values
 ('monthReview',0),('monthlyDesign',1),('attendance',2),('referral',3);
alter table home_news_private.campaigns enable row level security;
revoke all on home_news_private.campaigns from public,anon,authenticated,service_role;

create table home_news_private.deliveries (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 campaign_ids text[] not null check(cardinality(campaign_ids) between 1 and 4 and array_position(campaign_ids,null) is null),
 shown_at timestamptz not null,
 expires_at timestamptz not null,
 unique(user_id,id),
 check(expires_at=shown_at+interval '30 minutes')
);
create index home_news_deliveries_owner_time_idx on home_news_private.deliveries(user_id,shown_at desc);
alter table home_news_private.deliveries enable row level security;
revoke all on home_news_private.deliveries from public,anon,authenticated,service_role;
alter table home_news_private.exposures add column delivery_id uuid;
alter table home_news_private.exposures add constraint home_news_exposure_delivery_owner_fk
 foreign key(user_id,delivery_id) references home_news_private.deliveries(user_id,id) on delete cascade;
create index home_news_exposures_delivery_idx on home_news_private.exposures(user_id,delivery_id) where delivery_id is not null;

create function home_news_private.campaigns_json() returns jsonb
language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('kind',c.kind,'enabled',c.enabled,
  'startsAt',c.starts_at,'endsAt',c.ends_at,'sortOrder',c.sort_order,'updatedAt',c.updated_at)
  order by c.sort_order,c.kind),'[]'::jsonb) from home_news_private.campaigns c
$$;
revoke all on function home_news_private.campaigns_json() from public,anon,authenticated,service_role;

-- Display cards need an active, current known edition. The first automatic
-- trigger additionally needs the original first-use/month-end eligibility.
create function home_news_private.campaign_kind(p_user uuid,p_id text,p_at timestamptz,p_target boolean) returns text
language plpgsql stable security invoker set search_path='' as $$
declare today date:=(p_at at time zone 'Asia/Seoul')::date;
 campaign_month date:=date_trunc('month',p_at at time zone 'Asia/Seoul')::date;
 v_kind text;
begin
 v_kind:=case p_id
  when 'monthly-design:'||to_char(campaign_month,'YYYY-MM') then 'monthlyDesign'
  when 'attendance-benefit:v1' then 'attendance'
  when 'referral-benefit:v1' then 'referral'
  when 'month-review:'||to_char(campaign_month,'YYYY-MM') then 'monthReview'
  else null end;
 if v_kind is null or not exists(select 1 from home_news_private.campaigns c where c.kind=v_kind and c.enabled
  and(c.starts_at is null or c.starts_at<=p_at) and(c.ends_at is null or c.ends_at>p_at)) then return null; end if;
 if not p_target then return v_kind; end if;
 if v_kind='attendance' and exists(select 1 from attendance_private.daily_attendance a where a.user_id=p_user) then return null; end if;
 if v_kind='referral' and(exists(select 1 from referral_private.redemptions r where r.invitee_id=p_user or r.inviter_id=p_user)
  or exists(select 1 from public.point_ledger l where l.user_id=p_user and l.reason in('REFERRAL_INVITER','REFERRAL_INVITEE'))) then return null; end if;
 if v_kind='monthReview' and(today<(campaign_month+interval '1 month')::date-7
  or not exists(select 1 from moments_private.weekly_moments m where m.owner_id=p_user and m.deleted_at is null
   and jsonb_array_length(m.photos)>0 and m.record_date>=campaign_month and m.record_date<=today)
  or exists(select 1 from moments_private.month_albums m join public.albums a on a.id=m.album_id and a.owner_id=p_user
   where m.owner_id=p_user and m.month=campaign_month)) then return null; end if;
 return v_kind;
end;
$$;
revoke all on function home_news_private.campaign_kind(uuid,text,timestamptz,boolean) from public,anon,authenticated,service_role;

create or replace function home_news_private.state_json(p_user uuid,p_at timestamptz,p_claimed boolean) returns jsonb
language sql stable security invoker set search_path='' as $$
 with context as(select(p_at at time zone 'Asia/Seoul')::date today,
  date_trunc('week',p_at at time zone 'Asia/Seoul')::date week_start),
 owned as(select e.* from home_news_private.exposures e where e.user_id=p_user),
 deliveries as(select d.* from home_news_private.deliveries d where d.user_id=p_user),
 impressions as(select e.shown_at from owned e where e.delivery_id is null union all select d.shown_at from deliveries d)
 select jsonb_build_object(
  'userId',p_user,'serverNow',p_at,'serverDate',c.today::text,'weekStart',c.week_start::text,'timezone','Asia/Seoul','claimed',p_claimed,
  'dailyCount',(select count(*)from impressions i where i.shown_at>=c.today::timestamp at time zone 'Asia/Seoul'
   and i.shown_at<(c.today+1)::timestamp at time zone 'Asia/Seoul'),
  'weeklyCount',(select count(*)from impressions i where i.shown_at>=c.week_start::timestamp at time zone 'Asia/Seoul'
   and i.shown_at<(c.week_start+7)::timestamp at time zone 'Asia/Seoul'),
  'hasAttendanceEver',exists(select 1 from attendance_private.daily_attendance a where a.user_id=p_user),
  'hasReferralReward',exists(select 1 from referral_private.redemptions r where r.invitee_id=p_user or r.inviter_id=p_user)
   or exists(select 1 from public.point_ledger l where l.user_id=p_user and l.reason in('REFERRAL_INVITER','REFERRAL_INVITEE')),
  'campaigns',home_news_private.campaigns_json(),
  'deliveries',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'shownAt',d.shown_at)order by d.shown_at desc,d.id)from deliveries d),'[]'::jsonb),
  'history',coalesce((select jsonb_agg(jsonb_build_object('id',e.campaign_id,'kind',e.kind,'month',e.month::text,'shownAt',e.shown_at,
   'dismissedAt',e.dismissed_at,'clickedAt',e.clicked_at,'deliveryId',e.delivery_id)order by e.shown_at desc,e.campaign_id)from owned e),'[]'::jsonb))from context c
$$;

-- Preserve the old single-card RPC and interaction contract while applying the
-- same remote schedule and the combined legacy+delivery quotas.
create or replace function home_news_private.news_api(p_operation text,p_campaign_id text,p_interaction text) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=auth.uid(); server_time timestamptz; campaign_kind text; state jsonb;
begin
 if actor is null then raise exception 'HOME_NEWS_LOGIN_REQUIRED' using errcode='42501'; end if;
 server_time:=home_news_private.server_now();
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception 'HOME_NEWS_ACCOUNT_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('home-news:'||actor::text,0));
 perform 1 from home_news_private.campaigns c order by c.kind for share;
 server_time:=home_news_private.server_now();
 if p_operation='state' then return home_news_private.state_json(actor,server_time,false); end if;
 if p_campaign_id is null or char_length(p_campaign_id) not between 1 and 80 then
  raise exception 'HOME_NEWS_INVALID_CAMPAIGN' using errcode='22023'; end if;
 if p_operation='interaction' then
  if p_interaction='dismiss' then update home_news_private.exposures set dismissed_at=coalesce(dismissed_at,greatest(shown_at,server_time))where user_id=actor and campaign_id=p_campaign_id;
  elsif p_interaction='click' then update home_news_private.exposures set clicked_at=coalesce(clicked_at,greatest(shown_at,server_time))where user_id=actor and campaign_id=p_campaign_id;
  else raise exception 'HOME_NEWS_INVALID_INTERACTION' using errcode='22023'; end if;
  return home_news_private.state_json(actor,server_time,false);
 end if;
 if p_operation<>'claim' then raise exception 'HOME_NEWS_INVALID_OPERATION' using errcode='22023'; end if;
 state:=home_news_private.state_json(actor,server_time,false);
 campaign_kind:=home_news_private.campaign_kind(actor,p_campaign_id,server_time,true);
 if campaign_kind is null or(state->>'dailyCount')::integer>=1 or(state->>'weeklyCount')::integer>=2
  or exists(select 1 from home_news_private.exposures where user_id=actor and campaign_id=p_campaign_id)then return state; end if;
 insert into home_news_private.exposures(user_id,campaign_id,kind,month,shown_at)
 values(actor,p_campaign_id,campaign_kind,date_trunc('month',server_time at time zone 'Asia/Seoul')::date,server_time);
 return home_news_private.state_json(actor,server_time,true);
end;
$$;

create function home_news_private.delivery_api(p_operation text,p_campaign_ids text[],p_delivery_id uuid,p_campaign_id text)returns jsonb
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
revoke all on function home_news_private.delivery_api(text,text[],uuid,text)from public,anon,authenticated,service_role;
grant execute on function home_news_private.delivery_api(text,text[],uuid,text)to authenticated;

create function public.claim_home_news_delivery(p_campaign_ids text[])returns jsonb
language sql volatile security invoker set search_path=''as $$select home_news_private.delivery_api('claim',p_campaign_ids,null,null)$$;
create function public.record_home_news_delivery_view(p_delivery_id uuid,p_campaign_id text)returns jsonb
language sql volatile security invoker set search_path=''as $$select home_news_private.delivery_api('view',null,p_delivery_id,p_campaign_id)$$;
revoke all on function public.claim_home_news_delivery(text[]),public.record_home_news_delivery_view(uuid,text)from public,anon,authenticated,service_role;
grant execute on function public.claim_home_news_delivery(text[]),public.record_home_news_delivery_view(uuid,text)to authenticated;

-- The existing admin JWT check is paired with current server-owned app
-- metadata, so a removed administrator's unexpired JWT cannot keep editing.
create function home_news_private.admin_api(p_update boolean,p_kind text,p_enabled boolean,p_starts_at timestamptz,p_ends_at timestamptz,p_sort_order integer)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare actor uuid:=auth.uid(); server_time timestamptz:=home_news_private.server_now();
begin
 if actor is null or not public.is_admin()then raise exception 'HOME_NEWS_ADMIN_REQUIRED'using errcode='42501';end if;
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)and raw_app_meta_data->>'role'='admin'for key share;
 if not found then raise exception 'HOME_NEWS_ADMIN_REQUIRED'using errcode='42501';end if;
 if p_update then
  if p_kind is null or p_kind not in('monthlyDesign','attendance','referral','monthReview')or p_enabled is null
   or p_sort_order is null or p_sort_order not between -1000 and 1000
   or(p_starts_at is not null and not isfinite(p_starts_at))or(p_ends_at is not null and not isfinite(p_ends_at))
   or(p_starts_at is not null and p_ends_at is not null and p_ends_at<=p_starts_at)then
   raise exception 'HOME_NEWS_INVALID_SCHEDULE'using errcode='22023';end if;
  update home_news_private.campaigns set enabled=p_enabled,starts_at=p_starts_at,ends_at=p_ends_at,sort_order=p_sort_order,
   updated_at=home_news_private.server_now()where kind=p_kind;
 end if;
 return jsonb_build_object('userId',actor,'serverNow',home_news_private.server_now(),'campaigns',home_news_private.campaigns_json());
end;
$$;
revoke all on function home_news_private.admin_api(boolean,text,boolean,timestamptz,timestamptz,integer)from public,anon,authenticated,service_role;
grant execute on function home_news_private.admin_api(boolean,text,boolean,timestamptz,timestamptz,integer)to authenticated;
create function public.get_admin_home_news_campaigns()returns jsonb
language sql volatile security invoker set search_path=''as $$select home_news_private.admin_api(false,null,null,null,null,null)$$;
create function public.update_admin_home_news_campaign(p_kind text,p_enabled boolean,p_starts_at timestamptz,p_ends_at timestamptz,p_sort_order integer)returns jsonb
language sql volatile security invoker set search_path=''as $$select home_news_private.admin_api(true,p_kind,p_enabled,p_starts_at,p_ends_at,p_sort_order)$$;
revoke all on function public.get_admin_home_news_campaigns(),public.update_admin_home_news_campaign(text,boolean,timestamptz,timestamptz,integer)from public,anon,authenticated,service_role;
grant execute on function public.get_admin_home_news_campaigns(),public.update_admin_home_news_campaign(text,boolean,timestamptz,timestamptz,integer)to authenticated;

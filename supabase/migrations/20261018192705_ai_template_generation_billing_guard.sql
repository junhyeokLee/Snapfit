-- Preserve existing wallets, purchases, prices and historical draft usage.
alter function public.ai_album_draft_point_cost() set search_path='';
create schema if not exists private;
create table private.ai_template_generation_policy (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default true,
  v3_enabled boolean not null default false,
  user_daily_limit integer not null default 6 check (user_daily_limit between 1 and 100),
  project_daily_limit integer not null default 100 check (project_daily_limit between 1 and 10000),
  concurrent_limit integer not null default 4 check (concurrent_limit between 1 and 50)
);
insert into private.ai_template_generation_policy(singleton) values(true);
create table private.ai_template_generation_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  brief_hash text not null check (brief_hash ~ '^[a-f0-9]{64}$'),
  draft_id text not null unique,
  status text not null check (status in ('GENERATING','READY','CONSUMED','FAILED','EXPIRED')),
  point_cost integer not null check (point_cost >= 0),
  reserved_free_credit boolean not null,
  result jsonb,
  created_at timestamptz not null default now(),
  lease_expires_at timestamptz not null default (now()+interval '3 minutes'),
  expires_at timestamptz not null default (now()+interval '24 hours'),
  unique(user_id,request_id)
);
create index ai_template_generation_user_created_idx on private.ai_template_generation_intents(user_id,created_at desc);
create index ai_template_generation_created_idx on private.ai_template_generation_intents(created_at desc);
create index ai_template_generation_active_idx on private.ai_template_generation_intents(lease_expires_at) where status='GENERATING';
alter table private.ai_template_generation_policy enable row level security;
alter table private.ai_template_generation_intents enable row level security;
revoke all on private.ai_template_generation_policy,private.ai_template_generation_intents from public,anon,authenticated;
grant usage on schema private to service_role;
grant select,insert,update,delete on private.ai_template_generation_intents to service_role;
grant select,update on private.ai_template_generation_policy to service_role;

create function public.prepare_ai_template_generation(p_actor uuid,p_request_id uuid,p_brief_hash text,p_design_version integer default 1,p_expected_point_cost integer default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_policy private.ai_template_generation_policy%rowtype;
  v_previous private.ai_template_generation_intents%rowtype;
  v_id uuid := gen_random_uuid();
  v_cost integer;
  v_free boolean;
begin
  if p_actor is null or p_request_id is null or p_brief_hash is null or p_brief_hash !~ '^[a-f0-9]{64}$'
  then raise exception 'ai_generation_invalid_request' using errcode='22023'; end if;
  -- Serialize the short admission transaction, not the external model calls.
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||p_actor::text,0));
  select * into strict v_policy from private.ai_template_generation_policy where singleton;
  if not v_policy.enabled then raise exception 'ai_generation_disabled'; end if;
  if p_design_version not in (1,2,3) or p_design_version is null then raise exception 'ai_generation_invalid_request'; end if;
  if p_design_version=3 and not v_policy.v3_enabled then raise exception 'ai_generation_v3_not_validated'; end if;
  select * into v_previous from private.ai_template_generation_intents
    where user_id=p_actor and request_id=p_request_id;
  if found then
    if v_previous.brief_hash<>p_brief_hash then raise exception 'ai_generation_request_conflict'; end if;
    if v_previous.status in ('READY','CONSUMED') and v_previous.expires_at>now() and v_previous.result is not null then
      return jsonb_build_object('id',v_previous.id,'draftId',v_previous.draft_id,'cached',v_previous.result);
    end if;
    if v_previous.status='GENERATING' and v_previous.lease_expires_at>now()
    then raise exception 'ai_generation_in_progress'; end if;
    raise exception 'ai_generation_request_expired';
  end if;
  if exists(select 1 from private.ai_template_generation_intents where user_id=p_actor and status='GENERATING' and lease_expires_at>now())
  then raise exception 'ai_generation_in_progress'; end if;
  if (select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>=now()-interval '24 hours')>=v_policy.user_daily_limit
     or (select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>now()-interval '1 minute')>=2
  then raise exception 'ai_generation_rate_limited'; end if;
  if (select count(*) from private.ai_template_generation_intents where created_at>=now()-interval '24 hours')>=v_policy.project_daily_limit
     or (select count(*) from private.ai_template_generation_intents where status='GENERATING' and lease_expires_at>now())>=v_policy.concurrent_limit
  then raise exception 'ai_generation_capacity_limited'; end if;
  v_cost:=public.ai_album_draft_point_cost();
  if v_cost is null or v_cost<0 then raise exception 'ai_generation_price_unavailable'; end if;
  v_free:=not exists(select 1 from public.ai_album_free_draft_claims where user_id=p_actor);
  if p_design_version=3 and p_expected_point_cost is null then raise exception 'ai_generation_price_confirmation_required'; end if;
  if p_expected_point_cost is not null and p_expected_point_cost<>(case when v_free then 0 else v_cost end)
  then raise exception 'ai_generation_price_changed'; end if;
  if not v_free then
    perform 1 from public.point_wallets where user_id=p_actor and balance>=v_cost for update;
    if not found then raise exception 'ai_generation_insufficient_points'; end if;
  end if;
  update private.ai_template_generation_intents set status='EXPIRED',result=null
    where user_id=p_actor and (status='READY' or (status='GENERATING' and lease_expires_at<=now()));
  update private.ai_template_generation_intents set result=null where expires_at<=now() and result is not null;
  insert into private.ai_template_generation_intents(id,user_id,request_id,brief_hash,draft_id,status,point_cost,reserved_free_credit)
    values(v_id,p_actor,p_request_id,p_brief_hash,'original-template-'||v_id::text,'GENERATING',v_cost,v_free);
  return jsonb_build_object('id',v_id,'draftId','original-template-'||v_id::text);
end;
$$;

create function public.complete_ai_template_generation(p_actor uuid,p_id uuid,p_result jsonb)
returns void language plpgsql security invoker set search_path='' as $$
declare v_intent private.ai_template_generation_intents%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||p_actor::text,0));
  select * into v_intent from private.ai_template_generation_intents where id=p_id and user_id=p_actor for update;
  if not found or v_intent.status<>'GENERATING' or v_intent.lease_expires_at<=now()
  then raise exception 'ai_generation_not_pending'; end if;
  if p_result is null or jsonb_typeof(p_result)<>'object' or pg_column_size(p_result)>2097152
     or p_result->>'draftId' is distinct from v_intent.draft_id
     or p_result->'requiresUserReview' is distinct from 'true'::jsonb
     or p_result->'alreadyCreatedAlbum' is distinct from 'false'::jsonb
  then raise exception 'ai_generation_invalid_result'; end if;
  update private.ai_template_generation_intents set status='READY',result=p_result,expires_at=now()+interval '24 hours' where id=p_id;
end;
$$;

create function public.fail_ai_template_generation(p_actor uuid,p_id uuid)
returns void language sql security invoker set search_path='' as $$
  update private.ai_template_generation_intents set status='FAILED',result=null
  where id=p_id and user_id=p_actor and status='GENERATING';
$$;
revoke all on function public.prepare_ai_template_generation(uuid,uuid,text,integer,integer),public.complete_ai_template_generation(uuid,uuid,jsonb),public.fail_ai_template_generation(uuid,uuid) from public,anon,authenticated;
grant execute on function public.prepare_ai_template_generation(uuid,uuid,text,integer,integer),public.complete_ai_template_generation(uuid,uuid,jsonb),public.fail_ai_template_generation(uuid,uuid) to service_role;

-- This authenticated boundary requires definer rights because clients must never
-- receive write access to private intents, wallet balances or the point ledger.
create or replace function public.record_ai_album_draft_success(p_draft_id text,p_point_cost integer default null)
returns table(used_free_credit boolean,charged_points integer,remaining_balance integer)
language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := auth.uid();
  v_intent private.ai_template_generation_intents%rowtype;
  v_existing public.ai_album_draft_usages%rowtype;
  v_balance integer;
begin
  if v_user is null then raise exception 'ai_draft_auth_required' using errcode='28000'; end if;
  if p_draft_id is null or length(p_draft_id)>150 or btrim(p_draft_id)='' then raise exception 'ai_draft_invalid_id' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||v_user::text,0));
  select * into v_existing from public.ai_album_draft_usages where user_id=v_user and draft_id=p_draft_id;
  if found then
    if v_existing.status<>'SUCCEEDED' then raise exception 'ai_draft_usage_voided'; end if;
    return query select v_existing.used_free_credit,case when v_existing.used_free_credit then 0 else v_existing.point_cost end,
      coalesce((select balance from public.point_wallets where user_id=v_user),0);
    return;
  end if;
  select * into v_intent from private.ai_template_generation_intents where user_id=v_user and draft_id=p_draft_id for update;
  if not found or v_intent.status<>'READY' or v_intent.result is null or v_intent.expires_at<=now()
  then raise exception 'ai_draft_not_reviewable' using errcode='22023'; end if;
  if p_point_cost is not null and p_point_cost<>v_intent.point_cost
  then raise exception 'ai_draft_price_mismatch' using errcode='22023'; end if;
  insert into public.point_wallets(user_id,balance) values(v_user,0) on conflict(user_id) do nothing;
  select balance into v_balance from public.point_wallets where user_id=v_user for update;
  if v_intent.reserved_free_credit then
    if exists(select 1 from public.ai_album_free_draft_claims where user_id=v_user)
    then raise exception 'ai_draft_free_credit_changed' using errcode='22023'; end if;
    insert into public.ai_album_free_draft_claims(user_id,draft_id) values(v_user,p_draft_id);
  else
    if v_balance<v_intent.point_cost then raise exception 'insufficient points for AI album draft' using errcode='P0001'; end if;
    update public.point_wallets set balance=balance-v_intent.point_cost where user_id=v_user returning balance into v_balance;
  end if;
  insert into public.ai_album_draft_usages(user_id,draft_id,point_cost,used_free_credit)
    values(v_user,p_draft_id,case when v_intent.reserved_free_credit then 0 else v_intent.point_cost end,v_intent.reserved_free_credit);
  insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)
    values(v_user,case when v_intent.reserved_free_credit then 0 else -v_intent.point_cost end,
      case when v_intent.reserved_free_credit then 'AI_ALBUM_DRAFT_FREE' else 'AI_ALBUM_DRAFT_CHARGE' end,
      'ai_template_accept:'||v_user::text||':'||p_draft_id,'ai_album_draft',p_draft_id,
      jsonb_build_object('generation_id',v_intent.id,'point_cost',v_intent.point_cost,'server_verified',true));
  update private.ai_template_generation_intents set status='CONSUMED' where id=v_intent.id;
  return query select v_intent.reserved_free_credit,case when v_intent.reserved_free_credit then 0 else v_intent.point_cost end,v_balance;
end;
$$;
revoke all on function public.record_ai_album_draft_success(text,integer) from public,anon;
grant execute on function public.record_ai_album_draft_success(text,integer) to authenticated;

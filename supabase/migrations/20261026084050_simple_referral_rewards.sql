-- Simple, immediate friend referrals. No waiting period, conversation, contact
-- upload or device tracking. Existing wallets/catalog/ownership remain intact.
create schema referral_private;
revoke all on schema referral_private from public,anon,authenticated,service_role;
grant usage on schema referral_private to authenticated;

do $reasons$
declare existing_expression text;
begin
 select pg_get_expr(conbin,conrelid) into existing_expression from pg_constraint
 where conrelid='public.point_ledger'::regclass and conname='point_ledger_reason_check' and contype='c';
 if existing_expression is null then raise exception 'point_ledger_reason_constraint_required'; end if;
 alter table public.point_ledger drop constraint point_ledger_reason_check;
 execute format('alter table public.point_ledger add constraint point_ledger_reason_check check ((%s) or reason in (%L,%L))',
  existing_expression,'REFERRAL_INVITER','REFERRAL_INVITEE');
end;
$reasons$;

create table referral_private.codes (
 user_id uuid primary key references auth.users(id) on delete cascade,
 code text not null unique check(code~'^[A-HJKMNP-Z2-9]{10}$'),
 created_at timestamptz not null default clock_timestamp()
);
create table referral_private.redemptions (
 invitee_id uuid primary key references auth.users(id) on delete cascade,
 -- Keep the invitee's one-time registration if their inviter deletes an account.
 inviter_id uuid references auth.users(id) on delete set null,
 inviter_ledger_id bigint not null unique,
 invitee_ledger_id bigint not null unique,
 points integer not null check(points=100),
 redeemed_at timestamptz not null,
 check(inviter_id is null or inviter_id<>invitee_id),
 check(inviter_ledger_id<>invitee_ledger_id)
);
create index referral_redemptions_inviter_time_idx on referral_private.redemptions(inviter_id,redeemed_at);
alter table referral_private.codes enable row level security;
alter table referral_private.redemptions enable row level security;
revoke all on referral_private.codes,referral_private.redemptions from public,anon,authenticated,service_role;

create function referral_private.server_now() returns timestamptz
language sql volatile security invoker set search_path='' as $$ select clock_timestamp() $$;
revoke all on function referral_private.server_now() from public,anon,authenticated,service_role;

-- Legacy ledger INSERT policies are permissive; these rewards and their entire
-- idempotency namespace are reserved for the validated, atomic referral RPC.
create policy referral_ledger_rpc_only on public.point_ledger as restrictive
 for insert to authenticated with check(
  reason not in('REFERRAL_INVITER','REFERRAL_INVITEE') and idempotency_key not like 'friend_referral:%');
create function referral_private.guard_ledger() returns trigger
language plpgsql security definer set search_path='' as $$
declare expected_role text;
begin
 if tg_op='INSERT' then
  if new.reason in('REFERRAL_INVITER','REFERRAL_INVITEE') or new.idempotency_key like 'friend_referral:%' then
   expected_role:=case new.reason when 'REFERRAL_INVITER' then 'inviter' when 'REFERRAL_INVITEE' then 'invitee' end;
   if expected_role is null or new.amount_delta<>100
    or new.related_entity_type is distinct from 'friend_referral'
    or new.related_entity_id is null
    or new.idempotency_key is distinct from 'friend_referral:'||expected_role||':'||new.related_entity_id
    or new.metadata->>'source' is distinct from 'friend_referral'
    or new.metadata->>'referralRole' is distinct from expected_role then
    raise exception 'referral_ledger_invalid' using errcode='23514';
   end if;
  end if;
  return new;
 end if;
 if old.reason in('REFERRAL_INVITER','REFERRAL_INVITEE') or old.idempotency_key like 'friend_referral:%'
  or(tg_op='UPDATE' and(new.reason in('REFERRAL_INVITER','REFERRAL_INVITEE')or new.idempotency_key like 'friend_referral:%'))then
  if tg_op='DELETE' and not exists(select 1 from auth.users where id=old.user_id)then return old;end if;
  raise exception 'referral_ledger_immutable' using errcode='23514';
 end if;
 if tg_op='UPDATE'then return new;end if;
 return old;
end;
$$;
revoke all on function referral_private.guard_ledger() from public,anon,authenticated,service_role;
create trigger referral_ledger_guard before insert or update or delete on public.point_ledger
 for each row execute function referral_private.guard_ledger();

create function referral_private.guard_redemption() returns trigger
language plpgsql security definer set search_path='' as $$
declare inviter_entry public.point_ledger; invitee_entry public.point_ledger;
begin
 if tg_op='UPDATE' then
  -- Only the FK's account-deletion anonymization is allowed. The paid invitee
  -- must stay redeemed even if the inviter and the inviter ledger disappear.
  if old.inviter_id is not null and new.inviter_id is null
   and not exists(select 1 from auth.users where id=old.inviter_id)
   and(to_jsonb(new)-'inviter_id')=(to_jsonb(old)-'inviter_id') then return new;end if;
  raise exception 'referral_record_immutable' using errcode='23514';
 elsif tg_op='DELETE' then
  if not exists(select 1 from auth.users where id=old.invitee_id)then return old;end if;
  raise exception 'referral_record_immutable' using errcode='23514';
 end if;
 select * into inviter_entry from public.point_ledger where id=new.inviter_ledger_id;
 select * into invitee_entry from public.point_ledger where id=new.invitee_ledger_id;
 if inviter_entry.id is null or invitee_entry.id is null or new.inviter_id is null
  or inviter_entry.user_id<>new.inviter_id or invitee_entry.user_id<>new.invitee_id
  or inviter_entry.reason<>'REFERRAL_INVITER' or invitee_entry.reason<>'REFERRAL_INVITEE'
  or inviter_entry.amount_delta<>new.points or invitee_entry.amount_delta<>new.points
  or inviter_entry.related_entity_type is distinct from 'friend_referral'
  or invitee_entry.related_entity_type is distinct from 'friend_referral'
  or inviter_entry.related_entity_id is distinct from new.invitee_id::text
  or invitee_entry.related_entity_id is distinct from new.invitee_id::text
  or inviter_entry.idempotency_key is distinct from 'friend_referral:inviter:'||new.invitee_id::text
  or invitee_entry.idempotency_key is distinct from 'friend_referral:invitee:'||new.invitee_id::text then
  raise exception 'referral_record_ledger_mismatch' using errcode='23514';
 end if;
 return new;
end;
$$;
revoke all on function referral_private.guard_redemption()from public,anon,authenticated,service_role;
create trigger referral_redemptions_guard before insert or update or delete on referral_private.redemptions
 for each row execute function referral_private.guard_redemption();

create function referral_private.ensure_code(p_user uuid)returns text
language plpgsql volatile security invoker set search_path=''as $$
declare own_code text; candidate text; attempts integer:=0;
begin
 select code into own_code from referral_private.codes where user_id=p_user;
 if own_code is not null then return own_code;end if;
 loop
  -- More than 49 random bits from cryptographically random UUID bytes. Codes do not embed
  -- the user UUID, email, name or sequence and omit I/L/O/0/1 for manual entry.
  select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789',1+(get_byte(uuid_send(gen_random_uuid()),0)%31),1),'')
   into candidate from generate_series(1,10);
  begin
   insert into referral_private.codes(user_id,code)values(p_user,candidate)on conflict(user_id)do nothing;
   select code into own_code from referral_private.codes where user_id=p_user;
   if own_code is not null then return own_code;end if;
  exception when unique_violation then null;
  end;
  attempts:=attempts+1;if attempts>=10 then raise exception 'REFERRAL_CODE_UNAVAILABLE';end if;
 end loop;
end;
$$;
revoke all on function referral_private.ensure_code(uuid)from public,anon,authenticated,service_role;

create function referral_private.status_json(p_user uuid,p_at timestamptz,p_claimed boolean,p_awarded integer)returns jsonb
language sql stable security invoker set search_path=''as $$
 with user_state as(select u.id,coalesce(u.created_at,'1970-01-01'::timestamptz)+interval'7 days'eligible_until,
  u.email_confirmed_at is not null and nullif(btrim(u.email),'')is not null verified from auth.users u where u.id=p_user),
 month_context as(select date_trunc('month',p_at at time zone'Asia/Seoul')at time zone'Asia/Seoul'month_start,
  (date_trunc('month',p_at at time zone'Asia/Seoul')+interval'1 month')at time zone'Asia/Seoul'month_end),
 referral_state as(select exists(select 1 from referral_private.redemptions where invitee_id=p_user)redeemed,
  (select count(*)from public.point_ledger where user_id=p_user and reason='REFERRAL_INVITER')invited_count,
  (select count(*)from public.point_ledger r,month_context m where r.user_id=p_user and r.reason='REFERRAL_INVITER'and r.created_at>=m.month_start and r.created_at<m.month_end)monthly_count),
 eligibility as(select u.*,r.*,case when r.redeemed then'already_redeemed'when not u.verified then'unverified'when p_at>=u.eligible_until then'expired'else null end reason from user_state u cross join referral_state r)
 select jsonb_build_object('ownCode',(select code from referral_private.codes where user_id=p_user),
  'inviterPoints',100,'inviteePoints',100,'registrationWindowDays',7,'rewardLimit',20,
  'monthlyRewardedCount',s.monthly_count,'remaining',greatest(0,20-s.monthly_count),
  'invitedCount',s.invited_count,'totalEarned',(s.invited_count+case when s.redeemed then 1 else 0 end)*100,
  'balance',coalesce((select balance from public.point_wallets where user_id=p_user),0),
  'canRedeem',s.reason is null,'redeemed',s.redeemed,'eligibleUntil',s.eligible_until,
  'serverTime',p_at,'claimed',p_claimed,'awardedPoints',p_awarded,
  'rewardMonth',to_char(p_at at time zone'Asia/Seoul','YYYY-MM'),'timezone','Asia/Seoul','ineligibleReason',s.reason)from eligibility s
$$;
revoke all on function referral_private.status_json(uuid,timestamptz,boolean,integer)from public,anon,authenticated,service_role;

create function referral_private.referral_api(p_redeem boolean,p_code text)returns jsonb
language plpgsql security definer set search_path=''as $$
declare actor uuid:=auth.uid(); inviter uuid; locked_user uuid; server_time timestamptz;
 actor_created timestamptz; actor_verified boolean; normalized_code text; own_code text;
 month_start timestamptz; month_end timestamptz; rewarded_count integer; inviter_entry bigint; invitee_entry bigint;
begin
 server_time:=referral_private.server_now();
 if actor is null then raise exception 'REFERRAL_LOGIN_REQUIRED'using errcode='42501';end if;
 select coalesce(created_at,'1970-01-01'::timestamptz),email_confirmed_at is not null and nullif(btrim(email),'')is not null
  into actor_created,actor_verified from auth.users where id=actor and not is_anonymous and deleted_at is null
  and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception 'REFERRAL_ACCOUNT_REQUIRED'using errcode='42501';end if;
 own_code:=referral_private.ensure_code(actor);
 if p_redeem is not true then return referral_private.status_json(actor,server_time,false,0);end if;
 -- UID one-time registration also makes lost-response retries safe, even when
 -- the client retries a different code. It does not claim to identify a person
 -- across deletion/re-registration, devices or multiple verified accounts.
 if exists(select 1 from referral_private.redemptions where invitee_id=actor)then
  return referral_private.status_json(actor,server_time,false,0);
 end if;
 if not actor_verified then raise exception 'REFERRAL_UNVERIFIED_ACCOUNT'using errcode='42501';end if;
 if server_time>=actor_created+interval'7 days'then raise exception 'REFERRAL_WINDOW_EXPIRED'using errcode='22023';end if;
 normalized_code:=upper(btrim(p_code));
 if normalized_code is null or normalized_code!~'^[A-HJKMNP-Z2-9]{10}$'then raise exception 'REFERRAL_INVALID_CODE'using errcode='22023';end if;
 select user_id into inviter from referral_private.codes where code=normalized_code;
 if inviter is null then raise exception 'REFERRAL_INVALID_CODE'using errcode='22023';end if;
 if inviter=actor then raise exception 'REFERRAL_SELF_NOT_ALLOWED'using errcode='22023';end if;
 perform 1 from auth.users where id=inviter and not is_anonymous and deleted_at is null and email_confirmed_at is not null
  and nullif(btrim(email),'')is not null and(banned_until is null or banned_until<=server_time)for key share;
 if not found then raise exception 'REFERRAL_INVALID_CODE'using errcode='22023';end if;
 -- Deterministic wallet insertion AND locking avoids A→B / B→A deadlocks and
 -- serializes the inviter's monthly cap with every other point operation.
 for locked_user in select u from unnest(array[actor,inviter])u order by u loop
  insert into public.point_wallets(user_id,balance)values(locked_user,0)on conflict(user_id)do nothing;
  perform 1 from public.point_wallets where user_id=locked_user for update;
 end loop;
 server_time:=referral_private.server_now();
 if exists(select 1 from referral_private.redemptions where invitee_id=actor)then
  return referral_private.status_json(actor,server_time,false,0);
 end if;
 -- Eligibility and the month are re-evaluated after any wallet-lock wait.
 if server_time>=actor_created+interval'7 days'then raise exception 'REFERRAL_WINDOW_EXPIRED'using errcode='22023';end if;
 if exists(select 1 from referral_private.redemptions where invitee_id=inviter and inviter_id=actor)then
  raise exception 'REFERRAL_RECIPROCAL_NOT_ALLOWED'using errcode='22023';end if;
 month_start:=date_trunc('month',server_time at time zone'Asia/Seoul')at time zone'Asia/Seoul';
 month_end:=(date_trunc('month',server_time at time zone'Asia/Seoul')+interval'1 month')at time zone'Asia/Seoul';
 select count(*)into rewarded_count from public.point_ledger where user_id=inviter and reason='REFERRAL_INVITER'
  and created_at>=month_start and created_at<month_end;
 if rewarded_count>=20 then raise exception 'REFERRAL_LIMIT_REACHED'using errcode='22023';end if;
 insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata,created_at)
 values(inviter,100,'REFERRAL_INVITER','friend_referral:inviter:'||actor::text,'friend_referral',actor::text,
  jsonb_build_object('source','friend_referral','referralRole','inviter','ruleVersion',1),server_time)returning id into inviter_entry;
 insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata,created_at)
 values(actor,100,'REFERRAL_INVITEE','friend_referral:invitee:'||actor::text,'friend_referral',actor::text,
  jsonb_build_object('source','friend_referral','referralRole','invitee','ruleVersion',1),server_time)returning id into invitee_entry;
 insert into referral_private.redemptions(invitee_id,inviter_id,inviter_ledger_id,invitee_ledger_id,points,redeemed_at)
 values(actor,inviter,inviter_entry,invitee_entry,100,server_time);
 update public.point_wallets set balance=balance+100 where user_id in(actor,inviter);
 return referral_private.status_json(actor,server_time,true,100);
end;
$$;
revoke all on function referral_private.referral_api(boolean,text)from public,anon,authenticated,service_role;
grant execute on function referral_private.referral_api(boolean,text)to authenticated;

create function public.get_referral_status()returns jsonb
language sql volatile security invoker set search_path=''as $$select referral_private.referral_api(false,null)$$;
create function public.redeem_referral_code(p_code text)returns jsonb
language sql volatile security invoker set search_path=''as $$select referral_private.referral_api(true,p_code)$$;
revoke all on function public.get_referral_status(),public.redeem_referral_code(text)from public,anon,authenticated,service_role;
grant execute on function public.get_referral_status(),public.redeem_referral_code(text)to authenticated;

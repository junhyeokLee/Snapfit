-- Server-dated, free daily attendance. Existing balances, purchases and ownership
-- are preserved; attendance credits use the existing point wallet and ledger.
create schema attendance_private;
revoke all on schema attendance_private from public,anon,authenticated;
grant usage on schema attendance_private to authenticated;

-- Preserve every currently allowed reason while restoring the refund reason
-- accidentally omitted by the signup-bonus migration, then add attendance.
do $reasons$
declare existing_expression text;
begin
 select pg_get_expr(conbin,conrelid) into existing_expression from pg_constraint
 where conrelid='public.point_ledger'::regclass and conname='point_ledger_reason_check' and contype='c';
 if existing_expression is null then raise exception 'point_ledger_reason_constraint_required'; end if;
 alter table public.point_ledger drop constraint point_ledger_reason_check;
 execute format('alter table public.point_ledger add constraint point_ledger_reason_check check ((%s) or reason in (%L,%L))',
  existing_expression,'POINT_PURCHASE_REFUND','DAILY_ATTENDANCE');
end;
$reasons$;

create table attendance_private.daily_attendance (
 user_id uuid not null references auth.users(id) on delete cascade,
 attendance_date date not null,
 points integer not null,
 cycle_day integer not null check(cycle_day between 1 and 7),
 streak integer not null check(streak>0),
 ledger_id bigint not null unique references public.point_ledger(id) deferrable initially deferred,
 claimed_at timestamptz not null,
 primary key(user_id,attendance_date),
 check(cycle_day=1+((streak-1)%7)),
 check(points=(array[10,10,20,10,10,10,30])[cycle_day])
);
alter table attendance_private.daily_attendance enable row level security;
revoke all on attendance_private.daily_attendance from public,anon,authenticated,service_role;

-- The clock is internal and has no client arguments or client-settable GUC.
-- Tests replace this function only inside their disposable local database.
create function attendance_private.server_now() returns timestamptz
language sql volatile security invoker set search_path='' as $$ select clock_timestamp() $$;
revoke all on function attendance_private.server_now() from public,anon,authenticated,service_role;

-- The existing ledger has permissive INSERT policies. An additional restrictive
-- policy protects this reason and its idempotency namespace from direct writes.
create policy attendance_ledger_rpc_only on public.point_ledger as restrictive
 for insert to authenticated with check(
  reason<>'DAILY_ATTENDANCE' and idempotency_key not like 'daily_attendance:%');

create function attendance_private.guard_ledger() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.reason='DAILY_ATTENDANCE' or new.idempotency_key like 'daily_attendance:%' then
   if new.reason<>'DAILY_ATTENDANCE'
    or new.related_entity_type is distinct from 'daily_attendance'
    or new.related_entity_id is distinct from new.metadata->>'attendanceDate'
    or new.idempotency_key is distinct from 'daily_attendance:'||new.user_id::text||':'||new.related_entity_id
    or coalesce(new.amount_delta,0) not in(10,20,30)
    or new.metadata->>'timezone' is distinct from 'Asia/Seoul'
    or new.metadata->>'source' is distinct from 'free_attendance' then
    raise exception 'attendance_ledger_invalid' using errcode='23514';
   end if;
  end if;
  return new;
 end if;
 if old.reason='DAILY_ATTENDANCE' or old.idempotency_key like 'daily_attendance:%'
  or (tg_op='UPDATE' and (new.reason='DAILY_ATTENDANCE' or new.idempotency_key like 'daily_attendance:%')) then
  if tg_op='DELETE' and not exists(select 1 from auth.users where id=old.user_id) then return old; end if;
  raise exception 'attendance_ledger_immutable' using errcode='23514';
 end if;
 if tg_op='UPDATE' then return new; end if;
 return old;
end;
$$;
revoke all on function attendance_private.guard_ledger() from public,anon,authenticated,service_role;
create trigger attendance_ledger_guard before insert or update or delete on public.point_ledger
 for each row execute function attendance_private.guard_ledger();

create function attendance_private.guard_attendance() returns trigger
language plpgsql security definer set search_path='' as $$
declare entry public.point_ledger;
begin
 if tg_op<>'INSERT' then
  if tg_op='DELETE' and not exists(select 1 from auth.users where id=old.user_id) then return old; end if;
  raise exception 'attendance_record_immutable' using errcode='23514';
 end if;
 select * into entry from public.point_ledger where id=new.ledger_id;
 if not found or entry.user_id<>new.user_id or entry.reason<>'DAILY_ATTENDANCE'
  or entry.amount_delta<>new.points or entry.related_entity_type is distinct from 'daily_attendance'
  or entry.related_entity_id is distinct from new.attendance_date::text
  or entry.idempotency_key is distinct from 'daily_attendance:'||new.user_id::text||':'||new.attendance_date::text
  or (entry.metadata->>'cycleDay')::integer is distinct from new.cycle_day
  or (entry.metadata->>'streak')::integer is distinct from new.streak then
  raise exception 'attendance_record_ledger_mismatch' using errcode='23514';
 end if;
 return new;
end;
$$;
revoke all on function attendance_private.guard_attendance() from public,anon,authenticated,service_role;
create trigger daily_attendance_guard before insert or update or delete on attendance_private.daily_attendance
 for each row execute function attendance_private.guard_attendance();

create function attendance_private.status_json(p_user uuid,p_at timestamptz,p_claimed boolean,p_awarded integer) returns jsonb
language sql stable security invoker set search_path='' as $$
 with day_context as(select (p_at at time zone 'Asia/Seoul')::date today),
 latest as(select a.* from attendance_private.daily_attendance a,day_context d where a.user_id=p_user and a.attendance_date<=d.today order by a.attendance_date desc limit 1),
 today_row as(select a.* from attendance_private.daily_attendance a,day_context d where a.user_id=p_user and a.attendance_date=d.today),
 current_state as(select d.today,exists(select 1 from today_row) checked,
  coalesce((select streak from today_row),case when (select attendance_date from latest)=d.today-1 then(select streak from latest)else 0 end) current_streak
  from day_context d),
 cycle_state as(select s.*,coalesce((select cycle_day from today_row),1+(s.current_streak%7)) cycle_day from current_state s),
 month_rows as(select a.* from attendance_private.daily_attendance a,day_context d
  where a.user_id=p_user and a.attendance_date>=date_trunc('month',d.today::timestamp)::date and a.attendance_date<=d.today)
 select jsonb_build_object(
  'serverTime',p_at,'serverDate',s.today::text,'timezone','Asia/Seoul',
  'nextResetAt',(s.today+1)::timestamp at time zone 'Asia/Seoul',
  'checkedInToday',s.checked,'currentStreak',s.current_streak,'cycleDay',s.cycle_day,
  'todayReward',coalesce((select points from today_row),(array[10,10,20,10,10,10,30])[s.cycle_day]),
  'weeklyRewards',jsonb_build_array(10,10,20,10,10,10,30),'month',to_char(s.today,'YYYY-MM'),
  'monthPoints',(select coalesce(sum(points),0)from month_rows),
  'monthAttendanceCount',(select count(*)from month_rows),
  'history',(select coalesce(jsonb_agg(jsonb_build_object('date',attendance_date::text,'points',points,'cycleDay',cycle_day,'streak',streak)order by attendance_date),'[]'::jsonb)from month_rows),
  'claimed',p_claimed,'awardedPoints',p_awarded,
  'balance',coalesce((select balance from public.point_wallets where user_id=p_user),0))from cycle_state s
$$;
revoke all on function attendance_private.status_json(uuid,timestamptz,boolean,integer) from public,anon,authenticated,service_role;

create function attendance_private.attendance_api(p_claim boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 actor uuid:=auth.uid(); server_time timestamptz; today date;
 existing attendance_private.daily_attendance; last_day date; last_streak integer;
 new_streak integer; new_cycle integer; reward integer; entry_id bigint;
begin
 server_time:=attendance_private.server_now();
 if actor is null then raise exception 'attendance_login_required' using errcode='42501'; end if;
 perform 1 from auth.users where id=actor and not is_anonymous and deleted_at is null
  and (banned_until is null or banned_until<=server_time) for key share;
 if not found then raise exception 'attendance_personal_account_required' using errcode='42501'; end if;
 if p_claim is not true then return attendance_private.status_json(actor,server_time,false,0); end if;
 insert into public.point_wallets(user_id,balance) values(actor,0)on conflict(user_id)do nothing;
 -- All point purchases/attendance for this user serialize on the same wallet.
 perform 1 from public.point_wallets where user_id=actor for update;
 -- Read the server clock after the lock, so a request waiting across midnight
 -- cannot receive the previous day's credit using a stale request timestamp.
 server_time:=attendance_private.server_now();
 today:=(server_time at time zone 'Asia/Seoul')::date;
 select * into existing from attendance_private.daily_attendance where user_id=actor and attendance_date=today for update;
 if found then return attendance_private.status_json(actor,server_time,false,0); end if;
 select attendance_date,streak into last_day,last_streak from attendance_private.daily_attendance
  where user_id=actor and attendance_date<today order by attendance_date desc limit 1;
 new_streak:=case when last_day=today-1 then last_streak+1 else 1 end;
 new_cycle:=1+((new_streak-1)%7);
 reward:=(array[10,10,20,10,10,10,30])[new_cycle];
 insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata,created_at)
 values(actor,reward,'DAILY_ATTENDANCE','daily_attendance:'||actor::text||':'||today::text,
  'daily_attendance',today::text,jsonb_build_object('attendanceDate',today::text,'cycleDay',new_cycle,'streak',new_streak,
   'timezone','Asia/Seoul','source','free_attendance','ruleVersion',1),server_time)returning id into entry_id;
 insert into attendance_private.daily_attendance(user_id,attendance_date,points,cycle_day,streak,ledger_id,claimed_at)
 values(actor,today,reward,new_cycle,new_streak,entry_id,server_time);
 update public.point_wallets set balance=balance+reward where user_id=actor;
 return attendance_private.status_json(actor,server_time,true,reward);
end;
$$;
revoke all on function attendance_private.attendance_api(boolean) from public,anon,authenticated,service_role;
grant execute on function attendance_private.attendance_api(boolean) to authenticated;

create function public.get_attendance_status() returns jsonb
language sql volatile security invoker set search_path='' as $$ select attendance_private.attendance_api(false) $$;
create function public.claim_daily_attendance() returns jsonb
language sql volatile security invoker set search_path='' as $$ select attendance_private.attendance_api(true) $$;
revoke all on function public.get_attendance_status(),public.claim_daily_attendance()from public,anon,authenticated,service_role;
grant execute on function public.get_attendance_status(),public.claim_daily_attendance()to authenticated;

-- Administrator QA payments are isolated from customer orders and manufacturing.
-- No schema operation below grants a customer access or enables live checkout.
create schema if not exists private;
create table private.print_payment_test_sessions (
  payment_id text primary key default ('SFPGT_' || gen_random_uuid()::text),
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  scenario text not null check (scenario in ('SOFT_20','HARD_80')),
  request_fingerprint text not null,
  store_id text not null,
  channel_key text not null,
  order_name text not null,
  total_amount integer not null check (total_amount > 0),
  currency text not null default 'KRW' check (currency = 'KRW'),
  environment text not null default 'test' check (environment = 'test'),
  status text not null default 'PREPARED' check (status in ('PREPARED','VERIFIED_TEST')),
  receipt jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  verified_at timestamptz,
  unique (owner_id, request_id),
  check (payment_id ~ '^SFPGT_[0-9a-f-]{36}$'),
  -- SDK routing must be the console-verified TEST pair, not just an env label.
  check (store_id = 'store-33df409e-0ad9-4953-8194-70db7e32efae'
    and channel_key = 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88'),
  check ((scenario = 'SOFT_20' and total_amount = 49900) or (scenario = 'HARD_80' and total_amount = 159900)),
  check ((status = 'PREPARED' and receipt is null and verified_at is null)
    or (status = 'VERIFIED_TEST' and receipt is not null and verified_at is not null))
);
create unique index print_payment_test_transaction_unique
  on private.print_payment_test_sessions ((receipt->>'transactionId')) where receipt is not null;
alter table private.print_payment_test_sessions enable row level security;
revoke all on private.print_payment_test_sessions from public, anon, authenticated, service_role;
grant usage on schema private to service_role;
grant select, insert, update on private.print_payment_test_sessions to service_role;

create or replace function private.guard_print_payment_test_session()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if tg_op='INSERT' then
    if new.status is distinct from 'PREPARED' or new.receipt is not null or new.verified_at is not null then
      raise exception 'test_payment_invalid_state' using errcode='23514'; end if;
    return new;
  end if;
  if row(new.payment_id,new.owner_id,new.request_id,new.scenario,new.request_fingerprint,
      new.store_id,new.channel_key,new.order_name,new.total_amount,new.currency,new.environment,
      new.created_at,new.expires_at)
    is distinct from row(old.payment_id,old.owner_id,old.request_id,old.scenario,old.request_fingerprint,
      old.store_id,old.channel_key,old.order_name,old.total_amount,old.currency,old.environment,
      old.created_at,old.expires_at) then
    raise exception 'test_payment_expectation_immutable' using errcode='23514';
  end if;
  if old.status='VERIFIED_TEST' and row(new.status,new.receipt,new.verified_at)
      is distinct from row(old.status,old.receipt,old.verified_at) then
    raise exception 'test_payment_receipt_immutable' using errcode='23514';
  end if;
  if new.status not in ('PREPARED','VERIFIED_TEST') then
    raise exception 'test_payment_invalid_state' using errcode='23514';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_print_payment_test_session() from public,anon,authenticated;
create trigger print_payment_test_guard before insert or update on private.print_payment_test_sessions
  for each row execute function private.guard_print_payment_test_session();

-- Invoker RPCs bridge an unexposed private table. Only service_role may call;
-- the Edge function verifies the current administrator before creating its client.
create or replace function public.prepare_print_payment_test(
  p_owner uuid,p_request_id uuid,p_scenario text,p_store_id text,p_channel_key text
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_row private.print_payment_test_sessions; v_price jsonb;
  v_product text;v_pages integer;v_amount integer;v_fingerprint text;v_order_name text;
begin
  if p_owner is null or p_request_id is null or p_scenario is null or p_scenario not in ('SOFT_20','HARD_80')
    or p_store_id is distinct from 'store-33df409e-0ad9-4953-8194-70db7e32efae'
    or p_channel_key is distinct from 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88' then
    raise exception 'invalid_test_payment_request' using errcode='22023'; end if;
  v_product:=case when p_scenario='SOFT_20' then 'REDP_200X150_SOFT' else 'REDP_300_HARD' end;
  v_pages:=case when p_scenario='SOFT_20' then 20 else 80 end;
  v_amount:=case when p_scenario='SOFT_20' then 49900 else 159900 end;
  v_order_name:=case when p_scenario='SOFT_20' then '스냅핏 테스트 결제 · 소프트커버 20쪽'
    else '스냅핏 테스트 결제 · 하드커버 80쪽' end;
  v_price:=public.print_combo_pricing_policy(v_product,v_pages);
  if v_price->>'supplierCostVerified' is distinct from 'true'
    or (v_price->>'amount')::integer is distinct from v_amount
    or v_price->>'retailPriceStatus' is distinct from 'PLANNED' then
    raise exception 'test_payment_price_changed' using errcode='23514'; end if;
  -- This fingerprint contains only public QA configuration, never a secret.
  v_fingerprint:=concat_ws('|',p_scenario,p_store_id,p_channel_key,v_amount::text,'KRW','test');
  insert into private.print_payment_test_sessions(owner_id,request_id,scenario,request_fingerprint,
    store_id,channel_key,order_name,total_amount)
  values(p_owner,p_request_id,p_scenario,v_fingerprint,p_store_id,p_channel_key,v_order_name,v_amount)
  on conflict(owner_id,request_id) do nothing returning * into v_row;
  if not found then
    select * into strict v_row from private.print_payment_test_sessions
      where owner_id=p_owner and request_id=p_request_id for share;
    if v_row.request_fingerprint is distinct from v_fingerprint then
      raise exception 'test_payment_request_conflict' using errcode='23514'; end if;
  end if;
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.prepare_print_payment_test(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.prepare_print_payment_test(uuid,uuid,text,text,text) to service_role;

create or replace function public.get_print_payment_test(p_owner uuid,p_payment_id text)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_row private.print_payment_test_sessions;
begin
  select * into v_row from private.print_payment_test_sessions
    where owner_id=p_owner and payment_id=p_payment_id;
  if not found then raise exception 'test_payment_not_found' using errcode='P0002'; end if;
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.get_print_payment_test(uuid,text) from public,anon,authenticated;
grant execute on function public.get_print_payment_test(uuid,text) to service_role;

create or replace function public.verify_print_payment_test(p_owner uuid,p_payment_id text,p_receipt jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_row private.print_payment_test_sessions;v_paid bigint;v_discount bigint;
begin
  select * into v_row from private.print_payment_test_sessions
    where owner_id=p_owner and payment_id=p_payment_id for update;
  if not found then raise exception 'test_payment_not_found' using errcode='P0002'; end if;
  if p_receipt is null or jsonb_typeof(p_receipt) <> 'object'
    or p_receipt-array['provider','version','status','paymentId','transactionId','storeId','channelKey',
      'amount','paidAmount','discountAmount','currency','paidAt','environment','isTest'] <> '{}'::jsonb
    or p_receipt->>'provider' is distinct from 'PORTONE' or p_receipt->>'version' is distinct from 'V2'
    or p_receipt->>'status' is distinct from 'PAID' or p_receipt->>'paymentId' is distinct from v_row.payment_id
    or p_receipt->>'storeId' is distinct from v_row.store_id or p_receipt->>'channelKey' is distinct from v_row.channel_key
    or p_receipt->>'currency' is distinct from 'KRW' or p_receipt->>'environment' is distinct from 'test'
    or p_receipt->'isTest' is distinct from 'true'::jsonb
    or jsonb_typeof(p_receipt->'amount') is distinct from 'number'
    or jsonb_typeof(p_receipt->'paidAmount') is distinct from 'number'
    or jsonb_typeof(p_receipt->'discountAmount') is distinct from 'number'
    or (p_receipt->>'amount')::bigint is distinct from v_row.total_amount
    or coalesce(p_receipt->>'transactionId','') !~ '^[A-Za-z0-9_-]{1,200}$'
    or coalesce(p_receipt->>'paidAt','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$' then
    raise exception 'test_payment_receipt_invalid' using errcode='23514'; end if;
  v_paid:=(p_receipt->>'paidAmount')::bigint;v_discount:=(p_receipt->>'discountAmount')::bigint;
  if v_paid<=0 or v_discount<0 or v_paid+v_discount<>v_row.total_amount then
    raise exception 'test_payment_receipt_invalid' using errcode='23514'; end if;
  if v_row.status='VERIFIED_TEST' then
    if v_row.receipt is distinct from p_receipt then
      raise exception 'test_payment_receipt_conflict' using errcode='23514'; end if;
    return to_jsonb(v_row);
  end if;
  -- Expiry only prevents a new SDK launch; a late PAID response can still be recovered.
  update private.print_payment_test_sessions set status='VERIFIED_TEST',receipt=p_receipt,verified_at=now()
    where payment_id=v_row.payment_id returning * into v_row;
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.verify_print_payment_test(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.verify_print_payment_test(uuid,text,jsonb) to service_role;

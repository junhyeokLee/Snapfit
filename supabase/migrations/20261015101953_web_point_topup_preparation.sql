-- Preparation only. Do not deploy/apply as part of the source-only web work.
-- Legacy billing-* and native store receipts remain retired/unchanged.
-- TEST credit is recorded in a separate, non-spendable ledger, never a wallet.
create table public.web_point_topups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  request_id uuid not null,
  payment_id text not null unique,
  environment text not null check (environment in ('test', 'live')),
  product_id text not null references public.point_products(product_id),
  title text not null,
  points integer not null check (points > 0),
  total_amount integer not null check (total_amount > 0 and total_amount <= 1000000),
  currency text not null check (currency = 'KRW'),
  store_id text not null,
  channel_key text not null,
  status text not null default 'PREPARED' check (status in
    ('PREPARED','PENDING','VERIFIED_TEST','CREDITED','FAILED','VOIDED','REFUNDED','REVIEW')),
  sdk_started_at timestamptz,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  transaction_id text,
  paid_at timestamptz,
  verified_at timestamptz,
  refunded_at timestamptz,
  grant_ledger_id bigint references public.point_ledger(id),
  refund_ledger_id bigint references public.point_ledger(id),
  verified_receipt jsonb,
  reversal_receipt jsonb,
  reconcile_after timestamptz not null default now(),
  reconcile_lease_id uuid,
  reconcile_lease_until timestamptz,
  last_observed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (owner_id, request_id),
  check ((environment = 'test' and payment_id ~ '^SFPTT_[a-f0-9-]{36}$') or
         (environment = 'live' and payment_id ~ '^SFPTL_[a-f0-9-]{36}$')),
  check (environment <> 'test' or (grant_ledger_id is null and refund_ledger_id is null))
);
create unique index web_point_topups_provider_identity on public.web_point_topups(store_id, transaction_id)
  where transaction_id is not null;
create unique index web_point_topups_one_pending_owner on public.web_point_topups(owner_id,environment)
  where status in ('PREPARED','PENDING','REVIEW');
create index web_point_topups_reconcile_due on public.web_point_topups(reconcile_after)
  where status not in ('FAILED','VOIDED','REFUNDED');

create table public.web_point_topup_test_ledger (
  id bigint generated always as identity primary key,
  topup_id uuid not null references public.web_point_topups(id),
  owner_id uuid not null references auth.users(id),
  kind text not null check (kind in ('GRANT','REVERSAL')),
  amount_delta integer not null,
  created_at timestamptz not null default now(),
  unique (topup_id, kind),
  check ((kind = 'GRANT' and amount_delta > 0) or (kind = 'REVERSAL' and amount_delta < 0))
);
alter table public.web_point_topups enable row level security;
alter table public.web_point_topup_test_ledger enable row level security;
revoke all on public.web_point_topups, public.web_point_topup_test_ledger from public, anon, authenticated;
grant all on public.web_point_topups, public.web_point_topup_test_ledger to service_role;
grant usage, select on sequence public.web_point_topup_test_ledger_id_seq to service_role;

-- Independent SQL release gate: an env flag or forged browser response cannot
-- enable real-money charging/credit. A reviewed later migration is required.
create function public.web_point_topup_live_release_ready() returns boolean
language sql immutable security invoker set search_path = '' as $$ select false $$;
revoke all on function public.web_point_topup_live_release_ready() from public, anon, authenticated;
grant execute on function public.web_point_topup_live_release_ready() to service_role;

create function public.prepare_web_point_topup(
  p_owner uuid, p_request_id uuid, p_product_id text, p_store_id text, p_channel_key text,
  p_expected_amount integer, p_expected_points integer, p_environment text default 'test'
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_row public.web_point_topups; v_product public.point_products;
begin
  if p_owner is null or p_request_id is null or p_environment is null or p_environment not in ('test','live') then
    raise exception 'web_point_request_invalid' using errcode='22023';
  end if;
  if p_environment='live' and not public.web_point_topup_live_release_ready() then
    raise exception 'web_point_live_closed' using errcode='42501';
  end if;
  if (p_environment='test' and (
     p_store_id is distinct from 'store-33df409e-0ad9-4953-8194-70db7e32efae' or
     p_channel_key is distinct from 'channel-key-34782ac7-e644-4234-ad27-2767b6904f88')) or
     (p_environment='live' and (p_store_id !~ '^store-[A-Za-z0-9-]{8,100}$' or
      p_channel_key !~ '^channel-key-[A-Za-z0-9-]{8,100}$' or
      p_channel_key='channel-key-34782ac7-e644-4234-ad27-2767b6904f88')) then
    raise exception 'web_point_test_route_required' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('web_point:' || p_owner::text, 0));
  select * into v_row from public.web_point_topups where owner_id=p_owner and request_id=p_request_id for update;
  if found then
    if v_row.product_id is distinct from p_product_id or v_row.environment is distinct from p_environment then
      raise exception 'web_point_request_conflict' using errcode = '22023';
    end if;
    return to_jsonb(v_row);
  end if;
  select * into v_row from public.web_point_topups where owner_id=p_owner
    and environment=p_environment and status in ('PREPARED','PENDING','REVIEW') for update;
  if found then
    -- Expiry or a closed browser is never evidence of no charge.
    raise exception 'web_point_pending_exists' using errcode = '23505';
  end if;
  select * into v_product from public.point_products where product_id=p_product_id
    and is_active and currency='KRW' and amount between 1 and 1000000 for share;
  if not found then raise exception 'web_point_product_unavailable' using errcode='22023'; end if;
  if v_product.amount is distinct from p_expected_amount or v_product.points is distinct from p_expected_points then
    raise exception 'web_point_price_changed' using errcode='22023';
  end if;
  insert into public.web_point_topups(owner_id,request_id,payment_id,environment,
    product_id,title,points,total_amount,currency,store_id,channel_key)
  values(p_owner,p_request_id,(case when p_environment='test' then 'SFPTT_' else 'SFPTL_' end) || pg_catalog.gen_random_uuid()::text,p_environment,
    v_product.product_id,v_product.title,v_product.points,v_product.amount,'KRW',p_store_id,p_channel_key)
  returning * into v_row;
  return to_jsonb(v_row);
end $$;

create function public.start_web_point_topup(p_owner uuid,p_payment_id text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_row public.web_point_topups;
begin
  select * into v_row from public.web_point_topups where owner_id=p_owner and payment_id=p_payment_id for update;
  if not found then raise exception 'web_point_not_found' using errcode='P0002'; end if;
  if v_row.environment='live' and not public.web_point_topup_live_release_ready() then
    raise exception 'web_point_live_closed' using errcode='42501';
  end if;
  if v_row.status <> 'PREPARED' or
     v_row.sdk_started_at is not null then
    raise exception 'web_point_launch_not_available' using errcode='22023';
  end if;
  -- Renew an unopened invoice in place. Never infer non-payment from expiry,
  -- delete its identity, or create a second invoice to recover an old one.
  update public.web_point_topups set sdk_started_at=now(),status='PENDING',reconcile_after=now(),
    expires_at=greatest(expires_at,now()+interval '30 minutes')
    where id=v_row.id returning * into v_row;
  return to_jsonb(v_row);
end $$;

create function public.claim_web_point_topup_reconcile(p_payment_id text,p_owner uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_row public.web_point_topups;
begin
  update public.web_point_topups set reconcile_lease_id=pg_catalog.gen_random_uuid(),
    reconcile_lease_until=now()+interval '45 seconds',last_observed_at=now()
  where payment_id=p_payment_id and (p_owner is null or owner_id=p_owner)
    and sdk_started_at is not null and status not in ('FAILED','VOIDED','REFUNDED')
    and (reconcile_lease_until is null or reconcile_lease_until<=now())
    and (last_observed_at is null or last_observed_at<=now()-interval '15 seconds')
  returning * into v_row;
  return case when found then to_jsonb(v_row) else null end;
end $$;

create function public.finish_web_point_topup_reconcile(p_payment_id text,p_lease_id uuid,p_error text default null)
returns void language sql security invoker set search_path='' as $$
  update public.web_point_topups set reconcile_lease_id=null,reconcile_lease_until=null,
    last_error=left(p_error,80),reconcile_after=now()+case
      when p_error is not null then interval '5 minutes'
      when status in ('VERIFIED_TEST','CREDITED') then interval '24 hours'
      when status='REVIEW' then interval '1 hour' else interval '2 minutes' end
  where payment_id=p_payment_id and reconcile_lease_id=p_lease_id;
$$;

-- Receipts come only from the Edge server's GET to PortOne, never SDK/webhook
-- fields. Table/RPC grants are server-only, and the receipt is checked again.
create function public.apply_web_point_topup_observation(p_payment_id text,p_receipt jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_row public.web_point_topups; v_state text:=p_receipt->>'state';
  v_id bigint; v_paid integer; v_discount integer; v_cancelled integer;
begin
  select * into v_row from public.web_point_topups where payment_id=p_payment_id for update;
  if not found then raise exception 'web_point_not_found' using errcode='P0002'; end if;
  if v_row.environment='live' and not public.web_point_topup_live_release_ready() then
    raise exception 'web_point_live_closed' using errcode='42501';
  end if;
  if p_receipt->>'provider' is distinct from 'PORTONE' or p_receipt->>'version' is distinct from 'V2' or
     p_receipt->>'paymentId' is distinct from v_row.payment_id or p_receipt->>'storeId' is distinct from v_row.store_id or
     p_receipt->>'channelKey' is distinct from v_row.channel_key or p_receipt->>'environment' is distinct from v_row.environment or
     (p_receipt->>'isTest')::boolean is distinct from (v_row.environment='test') or
     p_receipt->>'currency' is distinct from 'KRW' or (p_receipt->>'totalAmount')::integer is distinct from v_row.total_amount or
     v_state not in ('paid','failed','cancelled','review') or v_state is null then
    raise exception 'web_point_receipt_invalid' using errcode='22023';
  end if;
  v_paid:=(p_receipt->>'paidAmount')::integer; v_discount:=(p_receipt->>'discountAmount')::integer;
  v_cancelled:=(p_receipt->>'cancelledAmount')::integer;
  if v_paid is null or v_discount is null or v_cancelled is null or least(v_paid,v_discount,v_cancelled)<0 or
     greatest(v_paid,v_discount,v_cancelled)>v_row.total_amount then
    raise exception 'web_point_receipt_invalid' using errcode='22023';
  end if;
  if v_row.transaction_id is not null and v_row.transaction_id is distinct from p_receipt->>'transactionId' then
    raise exception 'web_point_receipt_conflict' using errcode='22023';
  end if;
  if v_row.status in ('REFUNDED','VOIDED') then return to_jsonb(v_row); end if;
  if v_state='paid' then
    if v_paid<=0 or v_paid+v_discount<>v_row.total_amount or v_cancelled<>0 or
       nullif(p_receipt->>'transactionId','') is null or nullif(p_receipt->>'paidAt','') is null then
      raise exception 'web_point_receipt_invalid' using errcode='22023';
    end if;
    if v_row.verified_at is null then
      if v_row.status in ('FAILED','REVIEW') then
        raise exception 'web_point_review_required' using errcode='22023';
      end if;
      if v_row.environment='test' then
        insert into public.web_point_topup_test_ledger(topup_id,owner_id,kind,amount_delta)
          values(v_row.id,v_row.owner_id,'GRANT',v_row.points);
      else
        insert into public.point_wallets(user_id,balance) values(v_row.owner_id,0) on conflict(user_id) do nothing;
        perform 1 from public.point_wallets where user_id=v_row.owner_id for update;
        insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)
        values(v_row.owner_id,v_row.points,'POINT_PURCHASE','web_point_grant:' || v_row.payment_id,
          'web_point_topup',v_row.payment_id,jsonb_build_object('product_id',v_row.product_id,'platform','PORTONE_WEB',
            'amount',v_row.total_amount,'currency','KRW')) returning id into v_id;
        update public.point_wallets set balance=balance+v_row.points where user_id=v_row.owner_id;
      end if;
      update public.web_point_topups set status=case when environment='test' then 'VERIFIED_TEST' else 'CREDITED' end,
        transaction_id=p_receipt->>'transactionId',paid_at=(p_receipt->>'paidAt')::timestamptz,
        verified_at=now(),verified_receipt=p_receipt,grant_ledger_id=v_id where id=v_row.id;
    end if;
  elsif v_state='cancelled' then
    if v_paid<=0 or v_paid+v_discount<>v_row.total_amount or v_cancelled<v_paid or
       nullif(p_receipt->>'transactionId','') is null or nullif(p_receipt->>'cancelledAt','') is null or
       coalesce((p_receipt->>'fullCancellationVerified')::boolean,false)<>true then
      raise exception 'web_point_receipt_invalid' using errcode='22023';
    end if;
    if v_row.verified_at is not null then
      if v_row.environment='test' then
        insert into public.web_point_topup_test_ledger(topup_id,owner_id,kind,amount_delta)
          values(v_row.id,v_row.owner_id,'REVERSAL',-v_row.points);
      else
        perform 1 from public.point_wallets where user_id=v_row.owner_id for update;
        insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)
        values(v_row.owner_id,-v_row.points,'POINT_PURCHASE_REFUND','web_point_refund:' || v_row.payment_id,
          'web_point_topup',v_row.payment_id,jsonb_build_object('product_id',v_row.product_id,'platform','PORTONE_WEB',
            'grant_ledger_id',v_row.grant_ledger_id)) returning id into v_id;
        -- Spent refunded points become debt; never clamp balance to zero.
        update public.point_wallets set balance=balance-v_row.points where user_id=v_row.owner_id;
      end if;
    end if;
    update public.web_point_topups set status=case when verified_at is null then 'VOIDED' else 'REFUNDED' end,
      refunded_at=now(),refund_ledger_id=v_id,reversal_receipt=p_receipt where id=v_row.id;
  elsif v_state='failed' then
    if v_paid<>0 or v_cancelled<>0 or v_row.verified_at is not null then
      raise exception 'web_point_receipt_conflict' using errcode='22023';
    end if;
    update public.web_point_topups set status='FAILED' where id=v_row.id;
  else
    -- Partial/pending cancellation is not a full refund and must not auto-grant.
    update public.web_point_topups set status='REVIEW' where id=v_row.id;
  end if;
  select * into v_row from public.web_point_topups where id=v_row.id;
  return to_jsonb(v_row);
end $$;

revoke all on function public.prepare_web_point_topup(uuid,uuid,text,text,text,integer,integer,text),
  public.start_web_point_topup(uuid,text),public.claim_web_point_topup_reconcile(text,uuid),
  public.finish_web_point_topup_reconcile(text,uuid,text),public.apply_web_point_topup_observation(text,jsonb)
  from public,anon,authenticated;
grant execute on function public.prepare_web_point_topup(uuid,uuid,text,text,text,integer,integer,text),
  public.start_web_point_topup(uuid,text),public.claim_web_point_topup_reconcile(text,uuid),
  public.finish_web_point_topup_reconcile(text,uuid,text),public.apply_web_point_topup_observation(text,jsonb)
  to service_role;

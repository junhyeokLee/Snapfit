-- Refunds reverse the exact credited amount. A spent balance becomes negative
-- (refund debt); future purchases offset it and paid AI usage remains blocked by
-- the existing balance < point_cost check. Never silently forgive debt with max(0).
alter table public.point_wallets drop constraint if exists point_wallets_balance_check;
alter table public.point_ledger drop constraint if exists point_ledger_reason_check;
alter table public.point_ledger add constraint point_ledger_reason_check check (
  reason in ('AI_ALBUM_DRAFT_FREE', 'AI_ALBUM_DRAFT_CHARGE', 'ADMIN_ADJUSTMENT',
    'POINT_PURCHASE', 'POINT_PURCHASE_REFUND')
);

alter table public.store_purchases
  add column if not exists refund_ledger_id bigint references public.point_ledger(id),
  add column if not exists refunded_at timestamptz,
  add column if not exists revocation_response jsonb,
  add column if not exists last_reconciled_at timestamptz,
  add column if not exists reconcile_after timestamptz not null default now(),
  add column if not exists reconcile_lease_id uuid,
  add column if not exists reconcile_lease_until timestamptz,
  add column if not exists reconcile_attempts integer not null default 0,
  add column if not exists reconcile_error text;

-- Link historical credits without changing their ownership, balance, transaction
-- IDs or ledger keys. Ambiguous token ownership is rejected by the reversal RPC.
update public.store_purchases sp set
  point_ledger_id = pl.id, granted_points = pl.amount_delta
from public.point_ledger pl
where sp.point_ledger_id is null and sp.status in ('VERIFIED', 'REFUNDED')
  and pl.idempotency_key = 'point_purchase:' || sp.platform || ':' || sp.transaction_id
  and pl.reason = 'POINT_PURCHASE' and pl.amount_delta > 0
  and pl.user_id = sp.user_id and pl.metadata ->> 'product_id' = sp.product_id
  and not coalesce(sp.raw_response @> '{"mock":true}'::jsonb, false);

create index if not exists store_purchases_reconcile_due_idx
on public.store_purchases(reconcile_after)
where point_ledger_id is not null and refund_ledger_id is null;

create or replace function public.revoke_verified_point_purchase(
  p_platform text,
  p_transaction_id text,
  p_evidence jsonb default '{}'::jsonb
)
returns table (revoked_points integer, remaining_balance integer, already_revoked boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  v_purchase public.store_purchases%rowtype;
  v_grant public.point_ledger%rowtype;
  v_count integer;
  v_balance integer;
  v_refund_id bigint;
  v_key text;
begin
  if p_platform is null or p_platform not in ('GOOGLE_PLAY', 'APP_STORE')
    or nullif(btrim(p_transaction_id), '') is null then
    raise exception 'invalid_verified_purchase' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_platform || ':' || p_transaction_id, 0)
  );
  select count(*) into v_count from public.store_purchases sp
  where sp.platform = p_platform and (
    sp.canonical_transaction_id = p_transaction_id or sp.transaction_id = p_transaction_id
    or (p_platform = 'GOOGLE_PLAY' and sp.purchase_token = p_transaction_id)
  );
  if v_count <> 1 then
    raise exception 'purchase_legacy_conflict' using errcode = '22023';
  end if;
  select sp.* into v_purchase from public.store_purchases sp
  where sp.platform = p_platform and (
    sp.canonical_transaction_id = p_transaction_id or sp.transaction_id = p_transaction_id
    or (p_platform = 'GOOGLE_PLAY' and sp.purchase_token = p_transaction_id)
  ) for update;
  select pl.* into v_grant from public.point_ledger pl where pl.id = v_purchase.point_ledger_id;
  if not found or v_grant.reason <> 'POINT_PURCHASE' or v_grant.amount_delta <= 0
    or v_grant.user_id <> v_purchase.user_id
    or (v_grant.metadata ->> 'product_id') is distinct from v_purchase.product_id then
    raise exception 'purchase_identity_conflict' using errcode = '22023';
  end if;

  select pw.balance into v_balance from public.point_wallets pw
  where pw.user_id = v_purchase.user_id for update;
  if not found then
    raise exception 'point_wallet_missing' using errcode = '22023';
  end if;
  if v_purchase.refund_ledger_id is not null then
    return query select v_grant.amount_delta, v_balance, true;
    return;
  end if;

  v_key := 'point_purchase_refund:' || v_purchase.id::text;
  insert into public.point_ledger(
    user_id, amount_delta, reason, idempotency_key, related_entity_type, related_entity_id, metadata
  ) values (
    v_purchase.user_id, -v_grant.amount_delta, 'POINT_PURCHASE_REFUND', v_key,
    'store_purchase', v_purchase.transaction_id,
    jsonb_build_object('product_id', v_purchase.product_id, 'platform', p_platform,
      'grant_ledger_id', v_grant.id, 'reason', 'provider_revoked')
  ) returning id into v_refund_id;
  update public.point_wallets pw set balance = pw.balance - v_grant.amount_delta
  where pw.user_id = v_purchase.user_id returning pw.balance into v_balance;
  update public.store_purchases sp set status = 'REFUNDED',
    refund_ledger_id = v_refund_id, refunded_at = now(),
    fail_reason = 'provider_revoked', revocation_response = p_evidence
  where sp.id = v_purchase.id;
  return query select v_grant.amount_delta, v_balance, false;
end;
$$;
revoke all on function public.revoke_verified_point_purchase(text, text, jsonb)
from public, anon, authenticated;
grant execute on function public.revoke_verified_point_purchase(text, text, jsonb) to service_role;

create or replace function public.claim_point_purchase_reconciliation(p_limit integer default 20)
returns table (
  purchase_id bigint, user_id uuid, platform text, product_id text,
  transaction_id text, purchase_token text, lease_id uuid
)
language plpgsql security definer set search_path = ''
as $$
begin
  return query with due as (
    select sp.id from public.store_purchases sp
    where sp.point_ledger_id is not null and sp.refund_ledger_id is null
      and sp.reconcile_after <= now()
      and (sp.reconcile_lease_until is null or sp.reconcile_lease_until <= now())
    order by sp.reconcile_after, sp.id
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update skip locked
  ), claimed as (
    update public.store_purchases sp set
      reconcile_lease_id = pg_catalog.gen_random_uuid(),
      reconcile_lease_until = now() + interval '5 minutes',
      reconcile_attempts = sp.reconcile_attempts + 1
    from due where sp.id = due.id returning sp.*
  ) select c.id, c.user_id, c.platform, c.product_id,
    case when c.platform = 'GOOGLE_PLAY' then c.purchase_token
      else coalesce(c.canonical_transaction_id, c.transaction_id) end,
    c.purchase_token, c.reconcile_lease_id
  from claimed c;
end;
$$;
revoke all on function public.claim_point_purchase_reconciliation(integer) from public, anon, authenticated;
grant execute on function public.claim_point_purchase_reconciliation(integer) to service_role;

create or replace function public.finish_point_purchase_reconciliation(
  p_purchase_id bigint, p_lease_id uuid, p_error text default null
)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare v_updated integer;
begin
  update public.store_purchases sp set
    last_reconciled_at = case when p_error is null then now() else sp.last_reconciled_at end,
    reconcile_after = now() + case when p_error is null then interval '24 hours'
      else make_interval(mins => least(1440, 15 * greatest(1, sp.reconcile_attempts))) end,
    reconcile_error = left(p_error, 200),
    reconcile_attempts = case when p_error is null then 0 else sp.reconcile_attempts end,
    reconcile_lease_id = null, reconcile_lease_until = null
  where sp.id = p_purchase_id and sp.reconcile_lease_id = p_lease_id;
  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;
revoke all on function public.finish_point_purchase_reconciliation(bigint, uuid, text)
from public, anon, authenticated;
grant execute on function public.finish_point_purchase_reconciliation(bigint, uuid, text) to service_role;

-- Preserve the existing admin permission checks and audit fields while removing
-- its old balance floor, which would otherwise silently cancel refund debt.
do $$
declare v_function regprocedure; v_definition text;
begin
  v_function := to_regprocedure('public.admin_adjust_user_points(uuid,integer,text,text,jsonb)');
  if v_function is not null then
    v_definition := pg_get_functiondef(v_function);
    v_definition := replace(v_definition,
      'greatest(0, pw.balance + p_amount_delta)', '(pw.balance + p_amount_delta)');
    execute v_definition;
  end if;
end;
$$;

comment on column public.point_wallets.balance is
'Net point balance. Negative values are outstanding refunded points already spent; future credits offset this debt.';

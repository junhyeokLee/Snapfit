-- Point purchases only. Historical subscriptions and purchase/ledger rows are
-- retained; clients cannot create claims or call the retired credit-only RPC.
update public.billing_plans set is_active = false where plan_code <> 'FREE';

revoke all on function public.grant_point_purchase(uuid, text, text, text)
from public, anon, authenticated, service_role;
drop policy if exists "store_purchases_insert_own_pending" on public.store_purchases;
revoke insert, update, delete on public.store_purchases from anon, authenticated;

alter table public.store_purchases
  add column if not exists canonical_transaction_id text,
  add column if not exists store_account_id uuid,
  add column if not exists granted_points integer not null default 0 check (granted_points >= 0),
  add column if not exists point_ledger_id bigint references public.point_ledger(id);

create unique index if not exists store_purchases_canonical_transaction_idx
on public.store_purchases(platform, canonical_transaction_id)
where canonical_transaction_id is not null;

create index if not exists store_purchases_google_token_idx
on public.store_purchases(purchase_token)
where platform = 'GOOGLE_PLAY' and purchase_token is not null;

create or replace function public.grant_verified_point_purchase(
  p_user_id uuid,
  p_purchase jsonb
)
returns table (
  product_id text,
  granted_points integer,
  remaining_balance integer,
  already_granted boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_platform text := p_purchase ->> 'platform';
  v_product_id text := p_purchase ->> 'productId';
  v_transaction_id text := nullif(btrim(p_purchase ->> 'transactionId'), '');
  v_token text := nullif(btrim(p_purchase ->> 'purchaseToken'), '');
  v_account_id text := nullif(lower(btrim(p_purchase ->> 'storeAccountId')), '');
  v_purchased_at timestamptz := (p_purchase ->> 'purchasedAt')::timestamptz;
  v_product public.point_products%rowtype;
  v_purchase public.store_purchases%rowtype;
  v_ledger public.point_ledger%rowtype;
  v_purchase_count integer;
  v_ledger_count integer;
  v_key text;
  v_legacy_key text;
  v_balance integer;
  v_points integer;
  v_ledger_id bigint;
  v_already_granted boolean := false;
begin
  if p_user_id is null or v_platform is null
    or v_platform not in ('GOOGLE_PLAY', 'APP_STORE')
    or v_transaction_id is null or v_product_id is null or v_purchased_at is null then
    raise exception 'invalid_verified_purchase' using errcode = '22023';
  end if;
  if v_platform = 'GOOGLE_PLAY' and (v_token is null or v_token <> v_transaction_id) then
    raise exception 'purchase_identity_conflict' using errcode = '22023';
  end if;
  if v_platform = 'APP_STORE' and v_transaction_id !~ '^[0-9]{1,64}$' then
    raise exception 'purchase_identity_conflict' using errcode = '22023';
  end if;
  if v_account_id is not null and v_account_id <> p_user_id::text then
    raise exception 'purchase_account_mismatch' using errcode = '42501';
  end if;

  -- Same provider identity is serialized even if callers use different account
  -- IDs or the legacy row still uses an order ID instead of a Google token.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_platform || ':' || v_transaction_id, 0)
  );

  select pp.* into v_product from public.point_products pp
  where pp.product_id = v_product_id for share;
  if not found then
    raise exception 'unknown_point_product' using errcode = '22023';
  end if;

  select count(*) into v_purchase_count from public.store_purchases sp
  where sp.platform = v_platform and (
    sp.canonical_transaction_id = v_transaction_id
    or sp.transaction_id = v_transaction_id
    or (v_platform = 'GOOGLE_PLAY' and sp.purchase_token = v_token)
  );
  if v_purchase_count > 1 then
    -- Do not silently choose an owner from ambiguous historical token replays.
    raise exception 'purchase_legacy_conflict' using errcode = '23505';
  end if;
  if v_purchase_count = 1 then
    select sp.* into v_purchase from public.store_purchases sp
    where sp.platform = v_platform and (
      sp.canonical_transaction_id = v_transaction_id
      or sp.transaction_id = v_transaction_id
      or (v_platform = 'GOOGLE_PLAY' and sp.purchase_token = v_token)
    ) for update;
    -- Old client-inserted PENDING claims are not proof of ownership. A fresh
    -- store account binding may replace one; verified history cannot transfer.
    if v_purchase.status <> 'PENDING' and v_purchase.user_id <> p_user_id then
      raise exception 'purchase_owner_mismatch' using errcode = '42501';
    end if;
    if v_purchase.status <> 'PENDING' and v_purchase.product_id <> v_product_id then
      raise exception 'purchase_identity_conflict' using errcode = '22023';
    end if;
    if v_purchase.status = 'REFUNDED' then
      raise exception 'purchase_revoked' using errcode = '22023';
    end if;
  end if;

  v_key := 'point_purchase:' || v_platform || ':' || v_transaction_id;
  if v_purchase_count = 1 and v_purchase.status <> 'PENDING' then
    v_legacy_key := 'point_purchase:' || v_platform || ':' || v_purchase.transaction_id;
  end if;
  select count(*) into v_ledger_count from public.point_ledger pl
  where pl.idempotency_key in (v_key, v_legacy_key) or pl.id = v_purchase.point_ledger_id;
  if v_ledger_count > 1 then
    raise exception 'purchase_legacy_conflict' using errcode = '23505';
  end if;
  if v_ledger_count = 1 then
    select pl.* into v_ledger from public.point_ledger pl
    where pl.idempotency_key in (v_key, v_legacy_key) or pl.id = v_purchase.point_ledger_id;
    if v_ledger.user_id <> p_user_id then
      raise exception 'purchase_owner_mismatch' using errcode = '42501';
    end if;
    if v_ledger.reason <> 'POINT_PURCHASE' or v_ledger.amount_delta <= 0
      or (v_ledger.metadata ->> 'product_id') is distinct from v_product_id then
      raise exception 'purchase_identity_conflict' using errcode = '22023';
    end if;
    v_already_granted := true;
    v_points := v_ledger.amount_delta;
    v_ledger_id := v_ledger.id;
  end if;

  if v_account_id is null and not (
    v_purchase_count = 1 and v_purchase.status = 'VERIFIED'
    and v_purchase.user_id = p_user_id and v_purchase.product_id = v_product_id
    and v_already_granted and not coalesce(v_purchase.raw_response @> '{"mock":true}'::jsonb, false)
  ) then
    raise exception 'purchase_account_required' using errcode = '42501';
  end if;
  -- is_active controls catalog visibility, not fulfillment of an already paid
  -- allowlisted consumable. Retired SKUs keep their configured point amount.

  insert into public.point_wallets(user_id, balance) values (p_user_id, 0)
  on conflict (user_id) do nothing;
  select pw.balance into v_balance from public.point_wallets pw
  where pw.user_id = p_user_id for update;

  if not v_already_granted then
    v_points := v_product.points;
    insert into public.point_ledger(
      user_id, amount_delta, reason, idempotency_key,
      related_entity_type, related_entity_id, metadata
    ) values (
      p_user_id, v_points, 'POINT_PURCHASE', v_key,
      'store_purchase', v_transaction_id,
      jsonb_build_object('product_id', v_product_id, 'platform', v_platform,
        'amount', v_product.amount, 'currency', v_product.currency)
    ) returning id into v_ledger_id;
    update public.point_wallets pw set balance = pw.balance + v_points
    where pw.user_id = p_user_id returning pw.balance into v_balance;
  end if;

  if v_purchase_count = 0 then
    insert into public.store_purchases(
      user_id, platform, product_id, transaction_id, canonical_transaction_id,
      original_transaction_id, purchase_token, store_account_id, status, plan_code,
      purchased_at, expires_at, raw_response, granted_points, point_ledger_id
    ) values (
      p_user_id, v_platform, v_product_id, v_transaction_id, v_transaction_id,
      coalesce(p_purchase ->> 'originalTransactionId', v_transaction_id), v_token,
      v_account_id::uuid, 'VERIFIED', 'FREE', v_purchased_at, null,
      p_purchase -> 'rawResponse', v_points, v_ledger_id
    );
  else
    -- Preserve the historical transaction_id and ledger key; add the canonical
    -- identity so upgrades never create a second credit for an old Google order.
    update public.store_purchases sp set
      user_id = p_user_id, product_id = v_product_id,
      canonical_transaction_id = v_transaction_id,
      store_account_id = coalesce(v_account_id::uuid, sp.store_account_id),
      purchase_token = v_token, status = 'VERIFIED', plan_code = 'FREE',
      purchased_at = v_purchased_at, expires_at = null,
      raw_response = p_purchase -> 'rawResponse', fail_reason = null,
      granted_points = v_points, point_ledger_id = v_ledger_id
    where sp.id = v_purchase.id;
  end if;

  return query select v_product_id, v_points, v_balance, v_already_granted;
end;
$$;

revoke all on function public.grant_verified_point_purchase(uuid, jsonb)
from public, anon, authenticated;
grant execute on function public.grant_verified_point_purchase(uuid, jsonb) to service_role;

comment on function public.grant_verified_point_purchase(uuid, jsonb) is
'Server-only: call after store API verification. Atomically binds provider identity, records the purchase and credits configured points once.';

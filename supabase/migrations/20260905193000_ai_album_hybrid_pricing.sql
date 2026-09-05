-- High-quality hybrid AI album pricing and native store point packages.
--
-- Policy intent:
-- - SNAPFIT_AI_DRAFT_HYBRID_COST = 900 points, sized for OpenAI Vision + Claude curation.
-- - points are granted only after trusted store receipt verification in iap-verify.
-- - point package grants are idempotent by platform transaction id.

create table if not exists public.point_products (
  product_id text primary key,
  title text not null,
  points integer not null check (points > 0),
  amount integer not null check (amount >= 0),
  currency text not null default 'KRW',
  provider text not null default 'APP_STORE_GOOGLE_PLAY',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists point_products_set_updated_at on public.point_products;
create trigger point_products_set_updated_at
before update on public.point_products
for each row execute function public.set_updated_at();

alter table public.point_products enable row level security;

drop policy if exists "point_products_public_read_active" on public.point_products;
create policy "point_products_public_read_active"
on public.point_products for select
to anon, authenticated
using (is_active = true or public.is_admin());

drop policy if exists "point_products_admin_write" on public.point_products;
create policy "point_products_admin_write"
on public.point_products for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.point_products(product_id, title, points, amount, currency) values
  ('snapfit_points_1500', 'SnapFit 1,500 포인트', 1500, 2200, 'KRW'),
  ('snapfit_points_4500', 'SnapFit 4,500 포인트', 4500, 5900, 'KRW'),
  ('snapfit_points_10000', 'SnapFit 10,000 포인트', 10000, 11900, 'KRW')
on conflict (product_id) do update set
  title = excluded.title,
  points = excluded.points,
  amount = excluded.amount,
  currency = excluded.currency,
  provider = excluded.provider,
  is_active = true;

create or replace function public.ai_album_draft_point_cost()
returns integer
language sql stable
as $$
  select 900;
$$;

create or replace function public.grant_point_purchase(
  p_user_id uuid,
  p_product_id text,
  p_platform text,
  p_transaction_id text
)
returns table (
  product_id text,
  granted_points integer,
  remaining_balance integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.point_products%rowtype;
  v_balance integer;
  v_key text;
begin
  if p_user_id is null then
    raise exception 'point purchase requires user id' using errcode = '22023';
  end if;
  if p_transaction_id is null or btrim(p_transaction_id) = '' then
    raise exception 'point purchase transaction id is required' using errcode = '22023';
  end if;

  select * into v_product
  from public.point_products
  where product_id = p_product_id
    and is_active = true;

  if not found then
    raise exception 'unknown point product' using errcode = '22023';
  end if;

  insert into public.point_wallets(user_id, balance)
  values (p_user_id, 0)
  on conflict (user_id) do nothing;

  v_key := 'point_purchase:' || p_platform || ':' || p_transaction_id;

  insert into public.point_ledger(
    user_id,
    amount_delta,
    reason,
    idempotency_key,
    related_entity_type,
    related_entity_id,
    metadata
  ) values (
    p_user_id,
    v_product.points,
    'POINT_PURCHASE',
    v_key,
    'store_purchase',
    p_transaction_id,
    jsonb_build_object(
      'product_id', v_product.product_id,
      'platform', p_platform,
      'amount', v_product.amount,
      'currency', v_product.currency
    )
  )
  on conflict (idempotency_key) do nothing;

  if found then
    update public.point_wallets
    set balance = balance + v_product.points
    where user_id = p_user_id
    returning balance into v_balance;
  else
    select balance into v_balance
    from public.point_wallets
    where user_id = p_user_id;
  end if;

  return query select v_product.product_id, v_product.points, coalesce(v_balance, 0);
end;
$$;

revoke all on function public.grant_point_purchase(uuid, text, text, text) from public;
grant execute on function public.grant_point_purchase(uuid, text, text, text) to authenticated;

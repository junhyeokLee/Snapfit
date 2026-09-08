-- Digital assets only: a configured point price buys durable per-user ownership.
-- No production prices are seeded and no physical-order spending path is added.
create table public.point_shop_products (
  product_key text primary key,
  asset_id text not null check (asset_id ~ '^[A-Za-z0-9_-][A-Za-z0-9._/-]{0,179}$'),
  kind text not null check (kind in ('template','sticker','phrase','frame')),
  title text not null check (char_length(btrim(title)) between 1 and 200),
  point_price integer check (point_price >= 0),
  is_active boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint point_shop_product_key_matches_asset check (product_key = kind || ':' || asset_id),
  constraint point_shop_active_price_required check (not is_active or point_price is not null)
);
create trigger point_shop_products_set_updated_at before update on public.point_shop_products
  for each row execute function public.set_updated_at();

alter table public.point_ledger drop constraint point_ledger_reason_check;
alter table public.point_ledger add constraint point_ledger_reason_check check (
  reason in ('AI_ALBUM_DRAFT_FREE','AI_ALBUM_DRAFT_CHARGE','ADMIN_ADJUSTMENT',
    'POINT_PURCHASE','POINT_PURCHASE_REFUND','DIGITAL_ITEM_PURCHASE')
);

create table public.point_shop_ownership (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_key text not null references public.point_shop_products(product_key),
  point_price integer not null check (point_price > 0),
  ledger_id bigint not null unique references public.point_ledger(id)
    deferrable initially deferred,
  created_at timestamptz not null default now(),
  primary key (user_id, product_key)
);
create index point_shop_ownership_product_idx on public.point_shop_ownership(product_key);

alter table public.point_shop_products enable row level security;
alter table public.point_shop_ownership enable row level security;
revoke all on public.point_shop_products, public.point_shop_ownership from anon, authenticated, service_role;
grant select on public.point_shop_products to anon, authenticated, service_role;
grant insert, update, delete on public.point_shop_products to authenticated;
grant select on public.point_shop_ownership to authenticated, service_role;

-- Read inactive rows too: a declared unavailable item must never be mistaken
-- for an unregistered legacy free asset by a guest or authenticated client.
create policy point_shop_products_read on public.point_shop_products
  for select to anon, authenticated using (true);
create policy point_shop_products_admin_write on public.point_shop_products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy point_shop_ownership_read_own on public.point_shop_ownership
  for select to authenticated using (user_id = (select auth.uid()));

-- The existing admin ledger policy remains available for normal adjustments,
-- but digital-item debit rows must be inserted by the purchase RPC.
create policy point_shop_ledger_rpc_insert on public.point_ledger as restrictive
  for insert to authenticated with check (reason <> 'DIGITAL_ITEM_PURCHASE');

create function public.guard_point_shop_ownership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_ledger public.point_ledger;
begin
  if tg_op = 'UPDATE' then
    raise exception 'point_shop_ownership_immutable' using errcode = '23514';
  elsif tg_op = 'DELETE' then
    -- Account deletion may cascade; catalog deletion or direct entitlement
    -- deletion must not revoke a customer's durable purchase.
    if exists (select 1 from auth.users u where u.id = old.user_id) then
      raise exception 'point_shop_ownership_immutable' using errcode = '23514';
    end if;
    return old;
  end if;
  select pl.* into v_ledger from public.point_ledger pl where pl.id = new.ledger_id for share;
  if not found or v_ledger.user_id is distinct from new.user_id
    or v_ledger.amount_delta is distinct from -new.point_price
    or v_ledger.reason is distinct from 'DIGITAL_ITEM_PURCHASE'
    or v_ledger.related_entity_type is distinct from 'point_shop_product'
    or v_ledger.related_entity_id is distinct from new.product_key
    or v_ledger.idempotency_key is distinct from ('digital_item:' || new.user_id::text || ':' || new.product_key) then
    raise exception 'point_shop_ledger_mismatch' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_point_shop_ownership() from public, anon, authenticated, service_role;
create trigger point_shop_ownership_guard before insert or update or delete on public.point_shop_ownership
  for each row execute function public.guard_point_shop_ownership();

create function public.guard_digital_point_ledger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if old.reason = 'DIGITAL_ITEM_PURCHASE' or new.reason = 'DIGITAL_ITEM_PURCHASE' then
      raise exception 'digital_point_ledger_immutable' using errcode = '23514';
    end if;
    return new;
  end if;
  if old.reason = 'DIGITAL_ITEM_PURCHASE'
     and exists (select 1 from auth.users u where u.id = old.user_id) then
    raise exception 'digital_point_ledger_immutable' using errcode = '23514';
  end if;
  return old;
end;
$$;
revoke all on function public.guard_digital_point_ledger() from public, anon, authenticated, service_role;
create trigger digital_point_ledger_guard before update or delete on public.point_ledger
  for each row execute function public.guard_digital_point_ledger();

create function public.get_point_shop_access(p_product_key text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_product public.point_shop_products;
  v_owned boolean := false;
  v_balance integer := 0;
begin
  if p_product_key is null or p_product_key !~ '^(template|sticker|phrase|frame):[A-Za-z0-9_-][A-Za-z0-9._/-]{0,179}$' then
    raise exception 'invalid_point_shop_product_key' using errcode = '22023';
  end if;
  if v_user is not null then
    select coalesce(pw.balance,0) into v_balance from public.point_wallets pw where pw.user_id = v_user;
    select exists(select 1 from public.point_shop_ownership po
      where po.user_id = v_user and po.product_key = p_product_key) into v_owned;
  end if;
  select pp.* into v_product from public.point_shop_products pp where pp.product_key = p_product_key;
  if not found then
    return jsonb_build_object('product_key',p_product_key,'title',null,'point_price',0,
      'available',true,'is_free',true,'owned',false,'remaining_balance',coalesce(v_balance,0));
  end if;
  return jsonb_build_object('product_key',p_product_key,'title',v_product.title,'point_price',v_product.point_price,
    'available',v_owned or (v_product.is_active and v_product.point_price is not null),
    'is_free',v_product.is_active and coalesce(v_product.point_price = 0,false),
    'owned',v_owned,'remaining_balance',coalesce(v_balance,0));
end;
$$;
revoke all on function public.get_point_shop_access(text) from public, anon, authenticated, service_role;
grant execute on function public.get_point_shop_access(text) to anon, authenticated, service_role;

create function public.purchase_point_shop_product(p_product_key text, p_expected_price integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_product public.point_shop_products;
  v_balance integer;
  v_ledger_id bigint;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_product_key is null or p_product_key !~ '^(template|sticker|phrase|frame):[A-Za-z0-9_-][A-Za-z0-9._/-]{0,179}$' then
    raise exception 'invalid_point_shop_product_key' using errcode = '22023';
  end if;
  -- Hold the server price stable until the wallet debit/entitlement commit.
  select pp.* into v_product from public.point_shop_products pp
    where pp.product_key = p_product_key for share;
  if not found then
    if p_expected_price is distinct from 0 then
      raise exception 'point_shop_price_changed' using errcode = '22023';
    end if;
    return public.get_point_shop_access(p_product_key) || jsonb_build_object('charged_points',0,'already_owned',false);
  end if;
  -- Durable ownership remains idempotent even after delisting or repricing.
  if exists (select 1 from public.point_shop_ownership po where po.user_id = v_user and po.product_key = p_product_key) then
    return public.get_point_shop_access(p_product_key) || jsonb_build_object('charged_points',0,'already_owned',true);
  end if;
  if not v_product.is_active or v_product.point_price is null then
    raise exception 'point_shop_product_unavailable' using errcode = '22023';
  end if;
  if p_expected_price is distinct from v_product.point_price then
    raise exception 'point_shop_price_changed' using errcode = '22023';
  end if;
  if v_product.point_price = 0 then
    return public.get_point_shop_access(p_product_key) || jsonb_build_object('charged_points',0,'already_owned',false);
  end if;

  insert into public.point_wallets(user_id,balance) values(v_user,0) on conflict(user_id) do nothing;
  select pw.balance into v_balance from public.point_wallets pw where pw.user_id = v_user for update;
  -- Concurrent purchases serialize on the wallet, including different products.
  if exists (select 1 from public.point_shop_ownership po where po.user_id = v_user and po.product_key = p_product_key) then
    return public.get_point_shop_access(p_product_key) || jsonb_build_object('charged_points',0,'already_owned',true);
  end if;
  if v_balance < v_product.point_price then
    raise exception 'insufficient_points' using errcode = '22023';
  end if;
  insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)
    values(v_user,-v_product.point_price,'DIGITAL_ITEM_PURCHASE','digital_item:' || v_user::text || ':' || p_product_key,
      'point_shop_product',p_product_key,jsonb_build_object('product_key',p_product_key,'kind',v_product.kind,
        'asset_id',v_product.asset_id,'title',v_product.title,'point_price',v_product.point_price))
    returning id into v_ledger_id;
  update public.point_wallets pw set balance = pw.balance - v_product.point_price where pw.user_id = v_user;
  insert into public.point_shop_ownership(user_id,product_key,point_price,ledger_id)
    values(v_user,p_product_key,v_product.point_price,v_ledger_id);
  return public.get_point_shop_access(p_product_key) ||
    jsonb_build_object('charged_points',v_product.point_price,'already_owned',false);
end;
$$;
revoke all on function public.purchase_point_shop_product(text,integer) from public, anon, authenticated, service_role;
grant execute on function public.purchase_point_shop_product(text,integer) to authenticated;

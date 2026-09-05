-- Recreate point purchase grant RPC with qualified column references so Supabase
-- plpgsql lint does not confuse return-column names with table columns.

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

  select pp.* into v_product
  from public.point_products pp
  where pp.product_id = p_product_id
    and pp.is_active = true;

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
    update public.point_wallets pw
    set balance = pw.balance + v_product.points
    where pw.user_id = p_user_id
    returning pw.balance into v_balance;
  else
    select pw.balance into v_balance
    from public.point_wallets pw
    where pw.user_id = p_user_id;
  end if;

  return query select v_product.product_id, v_product.points, coalesce(v_balance, 0);
end;
$$;

revoke all on function public.grant_point_purchase(uuid, text, text, text) from public;
grant execute on function public.grant_point_purchase(uuid, text, text, text) to authenticated;

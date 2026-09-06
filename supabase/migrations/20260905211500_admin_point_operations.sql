-- Admin/CS point operations for support workflows.
-- These RPCs are guarded by public.is_admin() and should be used only from
-- admin tooling or Supabase SQL editor with an admin-authenticated user.

create or replace function public.admin_adjust_user_points(
  p_user_id uuid,
  p_amount_delta integer,
  p_reason text default 'CS adjustment',
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  user_id uuid,
  amount_delta integer,
  new_balance integer,
  ledger_id bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance integer;
  v_ledger_id bigint;
  v_key text;
begin
  if not public.is_admin() then
    raise exception 'admin privileges required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'target user id is required' using errcode = '22023';
  end if;
  if coalesce(p_amount_delta, 0) = 0 then
    raise exception 'point adjustment delta must not be zero' using errcode = '22023';
  end if;

  insert into public.point_wallets(user_id, balance)
  values (p_user_id, 0)
  on conflict on constraint point_wallets_pkey do nothing;

  v_key := coalesce(
    nullif(btrim(p_idempotency_key), ''),
    'admin_adjustment:' || p_user_id::text || ':' || extensions.gen_random_uuid()::text
  );

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
    p_amount_delta,
    'ADMIN_ADJUSTMENT',
    v_key,
    'admin_point_adjustment',
    v_key,
    jsonb_build_object(
      'reason', nullif(btrim(coalesce(p_reason, '')), ''),
      'admin_user_id', auth.uid()
    ) || coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (idempotency_key) do nothing
  returning point_ledger.id into v_ledger_id;

  if found then
    update public.point_wallets pw
    set balance = greatest(0, pw.balance + p_amount_delta)
    where pw.user_id = p_user_id
    returning pw.balance into v_balance;
  else
    select pl.id into v_ledger_id
    from public.point_ledger pl
    where pl.idempotency_key = v_key;

    select pw.balance into v_balance
    from public.point_wallets pw
    where pw.user_id = p_user_id;
  end if;

  return query select p_user_id, p_amount_delta, coalesce(v_balance, 0), v_ledger_id;
end;
$$;

revoke all on function public.admin_adjust_user_points(uuid, integer, text, text, jsonb) from public;
grant execute on function public.admin_adjust_user_points(uuid, integer, text, text, jsonb) to authenticated;

create or replace function public.admin_get_user_point_ledger(
  p_user_id uuid,
  p_limit integer default 50
)
returns table (
  ledger_id bigint,
  created_at timestamptz,
  amount_delta integer,
  reason text,
  idempotency_key text,
  related_entity_type text,
  related_entity_id text,
  metadata jsonb,
  remaining_balance integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admin privileges required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'target user id is required' using errcode = '22023';
  end if;

  return query
  select
    pl.id as ledger_id,
    pl.created_at,
    pl.amount_delta,
    pl.reason,
    pl.idempotency_key,
    pl.related_entity_type,
    pl.related_entity_id,
    pl.metadata,
    coalesce(pw.balance, 0) as remaining_balance
  from public.point_ledger pl
  left join public.point_wallets pw on pw.user_id = pl.user_id
  where pl.user_id = p_user_id
  order by pl.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

revoke all on function public.admin_get_user_point_ledger(uuid, integer) from public;
grant execute on function public.admin_get_user_point_ledger(uuid, integer) to authenticated;

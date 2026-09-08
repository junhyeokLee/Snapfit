-- Retire external physical-order payments without deleting existing orders,
-- verified payment history, print snapshots, or applied migration history.
drop function if exists public.confirm_verified_print_payment(text, text, integer, text);
drop function if exists public.record_print_payment_reversal(text, text, integer, text, text);

-- Keep the quote/record implementation for existing print work, but customers
-- cannot create new unpaid checkout orders while physical sales are disabled.
revoke all on function public.create_print_order(bigint, integer, integer, text, text, text, text, text, text, text)
  from public, anon, authenticated, service_role;
revoke insert, update, delete on public.orders from anon, authenticated;

-- A service-role caller is not a source of new payment truth. Neither inserting
-- an already-paid row nor attaching payment evidence to an unpaid row is allowed.
-- Existing verified history can still follow its normal print/shipping lifecycle.
create or replace function public.guard_print_order_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.status is distinct from 'PAYMENT_PENDING'
       or new.verified_payment_id is not null or new.verified_payment_provider is not null
       or new.payment_confirmed_at is not null or new.payment_reversed_at is not null
       or new.payment_reversal_status is not null then
      raise exception 'physical_order_payments_disabled' using errcode = '23514';
    end if;
    return new;
  end if;

  if row(new.user_id,coalesce(new.album_id,old.album_id),new.amount,new.page_count,new.payment_method,new.pricing_version,
         new.payment_currency,new.print_content_snapshot)
     is distinct from
     row(old.user_id,old.album_id,old.amount,old.page_count,old.payment_method,old.pricing_version,
         old.payment_currency,old.print_content_snapshot) then
    raise exception 'order_purchase_details_immutable' using errcode = '23514';
  end if;
  if row(new.verified_payment_id,new.verified_payment_provider,new.payment_confirmed_at,
         new.payment_reversed_at,new.payment_reversal_status)
     is distinct from
     row(old.verified_payment_id,old.verified_payment_provider,old.payment_confirmed_at,
         old.payment_reversed_at,old.payment_reversal_status) then
    raise exception 'physical_order_payments_disabled' using errcode = '23514';
  end if;
  if new.status is distinct from old.status then
    if old.status = 'PAYMENT_PENDING' and new.status = 'PAYMENT_COMPLETED' then
      raise exception 'physical_order_payments_disabled' using errcode = '23514';
    end if;
    if not ((old.status = 'PAYMENT_PENDING' and new.status = 'CANCELED')
       or (old.status = 'PAYMENT_COMPLETED' and new.status in ('IN_PRODUCTION','CANCELED'))
       or (old.status in ('IN_PRODUCTION','PRINTING') and new.status = 'SHIPPING')
       or (old.status = 'SHIPPING' and new.status = 'DELIVERED')) then
      raise exception 'invalid_order_status_transition' using errcode = '23514';
    end if;
    if new.status in ('IN_PRODUCTION','SHIPPING','DELIVERED') and
       (old.payment_reversed_at is not null or coalesce(btrim(old.verified_payment_id),'') = ''
         or coalesce(btrim(old.verified_payment_provider),'') = '' or old.payment_confirmed_at is null) then
      raise exception 'verified_payment_required' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_print_order_update() from public, anon, authenticated;
create trigger orders_guard_purchase_insert before insert on public.orders
  for each row execute function public.guard_print_order_update();

-- This generic lease supports pre-existing verified orders only. It cannot
-- create evidence or move an unpaid order into fulfillment.
create or replace function public.claim_print_package(p_order_id text, p_token uuid)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_order public.orders;
begin
  update public.orders set print_package_lock_token = p_token, print_package_lock_until = now() + interval '5 minutes'
  where order_id = p_order_id and status = 'PAYMENT_COMPLETED'
    and coalesce(btrim(verified_payment_id),'') <> ''
    and coalesce(btrim(verified_payment_provider),'') <> ''
    and payment_confirmed_at is not null and payment_reversed_at is null
    and (print_package_lock_until is null or print_package_lock_until < now())
  returning * into v_order;
  return case when found then to_jsonb(v_order) else null end;
end;
$$;
revoke all on function public.claim_print_package(text, uuid) from public, anon, authenticated;
grant execute on function public.claim_print_package(text, uuid) to service_role;

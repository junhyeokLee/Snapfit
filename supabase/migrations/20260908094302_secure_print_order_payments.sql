-- Physical goods: clients may read orders, but payment facts and prices are server owned.
alter table public.orders
  add column if not exists pricing_version text,
  add column if not exists payment_currency text not null default 'KRW',
  add column if not exists verified_payment_id text,
  add column if not exists verified_payment_provider text,
  add column if not exists print_content_snapshot jsonb,
  add column if not exists payment_reversed_at timestamptz,
  add column if not exists payment_reversal_status text,
  add column if not exists print_package_lock_token uuid,
  add column if not exists print_package_lock_until timestamptz;
create unique index if not exists orders_verified_payment_unique
  on public.orders(verified_payment_provider, verified_payment_id)
  where verified_payment_id is not null;

drop policy if exists orders_insert_own on public.orders;
drop policy if exists orders_owner_limited_update on public.orders;
revoke insert, update, delete on public.orders from anon, authenticated;
grant select on public.orders to authenticated;
grant all on public.orders to service_role;

create or replace function public.get_print_order_quote(p_album_id bigint, p_page_count integer default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_pages integer;
  v_actual integer;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then
    raise exception 'album_access_denied' using errcode = '42501';
  end if;
  select count(*)::integer into v_actual from public.album_pages where album_id = p_album_id;
  v_pages := greatest(12, v_actual, coalesce(p_page_count, 0));
  if p_page_count < 0 or v_pages > 50 then
    raise exception 'invalid_page_count' using errcode = '22023';
  end if;
  return jsonb_build_object('pageCount', v_pages, 'amount', 34900 + greatest(0, v_pages - 12) * 1200,
    'basePages', 12, 'basePrice', 34900, 'extraPageCount', greatest(0, v_pages - 12), 'extraPagePrice', 1200);
end;
$$;
revoke all on function public.get_print_order_quote(bigint, integer) from public, anon;
grant execute on function public.get_print_order_quote(bigint, integer) to authenticated;

create or replace function public.create_print_order(
  p_album_id bigint, p_page_count integer, p_expected_amount integer, p_payment_method text,
  p_recipient_name text, p_recipient_phone text, p_zip_code text, p_address_line1 text,
  p_address_line2 text default '', p_delivery_memo text default ''
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_quote jsonb;
  v_album public.albums;
  v_order public.orders;
  v_pages jsonb;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then
    raise exception 'album_access_denied' using errcode = '42501';
  end if;
  -- Capture content with the quote, so later album edits cannot increase paid page count.
  select * into strict v_album from public.albums where id = p_album_id for share;
  v_quote := public.get_print_order_quote(p_album_id, p_page_count);
  if p_expected_amount is distinct from (v_quote->>'amount')::integer then
    raise exception 'order_quote_changed' using errcode = '22023';
  end if;
  if p_payment_method is null or p_payment_method not in ('TOSS_PAYMENTS','NAVERPAY','KG_INICIS') then
    raise exception 'unsupported_payment_provider' using errcode = '22023';
  end if;
  if coalesce(btrim(p_recipient_name), '') = '' or coalesce(p_recipient_phone, '') !~ '^\d{10,11}$'
     or coalesce(p_zip_code, '') !~ '^\d{5}$' or coalesce(btrim(p_address_line1), '') = '' then
    raise exception 'invalid_delivery_address' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.page_index), '[]'::jsonb) into v_pages
    from public.album_pages p where p.album_id = p_album_id;
  if jsonb_array_length(v_pages) > (v_quote->>'pageCount')::integer then
    raise exception 'order_quote_changed' using errcode = '22023';
  end if;
  insert into public.orders(user_id, album_id, title, amount, page_count, payment_method,
    recipient_name, recipient_phone, zip_code, address_line1, address_line2, delivery_memo,
    status, pricing_version, print_content_snapshot)
  values (auth.uid(), p_album_id, coalesce(nullif(btrim(v_album.title), ''), '스냅핏 포토북'),
    (v_quote->>'amount')::integer, (v_quote->>'pageCount')::integer, p_payment_method,
    btrim(p_recipient_name), p_recipient_phone, p_zip_code, btrim(p_address_line1),
    btrim(coalesce(p_address_line2, '')), btrim(coalesce(p_delivery_memo, '')),
    'PAYMENT_PENDING', 'PRINT_2026_09', jsonb_build_object('album', to_jsonb(v_album), 'pages', v_pages))
  returning * into v_order;
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.create_print_order(bigint, integer, integer, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.create_print_order(bigint, integer, integer, text, text, text, text, text, text, text) to authenticated;

-- Defense in depth for privileged administrative paths too: no accidental free fulfillment,
-- price changes, or backward status transitions after a verified purchase.
create or replace function public.guard_print_order_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if row(new.user_id,coalesce(new.album_id,old.album_id),new.amount,new.page_count,new.payment_method,new.pricing_version,
         new.payment_currency,new.print_content_snapshot)
     is distinct from
     row(old.user_id,old.album_id,old.amount,old.page_count,old.payment_method,old.pricing_version,
         old.payment_currency,old.print_content_snapshot) then
    raise exception 'order_purchase_details_immutable' using errcode = '23514';
  end if;
  if old.verified_payment_id is not null and
     row(new.verified_payment_id,new.verified_payment_provider,new.payment_confirmed_at)
       is distinct from row(old.verified_payment_id,old.verified_payment_provider,old.payment_confirmed_at) then
    raise exception 'verified_payment_immutable' using errcode = '23514';
  end if;
  if old.payment_reversed_at is not null and new.payment_reversed_at is distinct from old.payment_reversed_at then
    raise exception 'payment_reversal_immutable' using errcode = '23514';
  end if;
  if new.status is distinct from old.status then
    if not ((old.status = 'PAYMENT_PENDING' and new.status in ('PAYMENT_COMPLETED','CANCELED'))
       or (old.status = 'PAYMENT_COMPLETED' and new.status in ('IN_PRODUCTION','CANCELED'))
       or (old.status in ('IN_PRODUCTION','PRINTING') and new.status = 'SHIPPING')
       or (old.status = 'SHIPPING' and new.status = 'DELIVERED')) then
      raise exception 'invalid_order_status_transition' using errcode = '23514';
    end if;
    if new.status in ('PAYMENT_COMPLETED','IN_PRODUCTION','SHIPPING','DELIVERED') and
       (new.payment_reversed_at is not null or new.verified_payment_id is null or new.verified_payment_provider is distinct from 'PORTONE'
         or new.payment_confirmed_at is null) then
      raise exception 'verified_payment_required' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_print_order_update() from public, anon, authenticated;
create trigger orders_guard_purchase before update on public.orders
  for each row execute function public.guard_print_order_update();

-- Called only by Edge code after PortOne has verified the payment. Row lock makes
-- simultaneous client retries idempotent and preserves one confirmation timestamp.
create or replace function public.confirm_verified_print_payment(
  p_order_id text, p_payment_id text, p_amount integer, p_currency text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_order public.orders;
begin
  select * into strict v_order from public.orders where order_id = p_order_id for update;
  if p_payment_id is distinct from v_order.order_id or p_amount is distinct from v_order.amount
     or p_currency is distinct from v_order.payment_currency then
    raise exception 'payment_order_mismatch' using errcode = '22023';
  end if;
  if v_order.payment_reversed_at is not null then
    raise exception 'payment_reversed' using errcode = '22023';
  end if;
  if v_order.pricing_version is distinct from 'PRINT_2026_09' then
    raise exception 'legacy_order_requires_review' using errcode = '22023';
  end if;
  if v_order.verified_payment_id = p_payment_id and v_order.status in
     ('PAYMENT_COMPLETED','IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') then
    return to_jsonb(v_order);
  end if;
  if v_order.status <> 'PAYMENT_PENDING' then
    raise exception 'order_not_payable' using errcode = '22023';
  end if;
  update public.orders set status = 'PAYMENT_COMPLETED', payment_confirmed_at = now(),
    verified_payment_id = p_payment_id, verified_payment_provider = 'PORTONE'
    where order_id = p_order_id returning * into v_order;
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.confirm_verified_print_payment(text, text, integer, text) from public, anon, authenticated;
grant execute on function public.confirm_verified_print_payment(text, text, integer, text) to service_role;

create or replace function public.claim_print_package(p_order_id text, p_token uuid)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_order public.orders;
begin
  update public.orders set print_package_lock_token = p_token, print_package_lock_until = now() + interval '5 minutes'
  where order_id = p_order_id and status = 'PAYMENT_COMPLETED' and verified_payment_id is not null and payment_reversed_at is null
    and (print_package_lock_until is null or print_package_lock_until < now())
  returning * into v_order;
  return case when found then to_jsonb(v_order) else null end;
end;
$$;
revoke all on function public.claim_print_package(text, uuid) from public, anon, authenticated;
grant execute on function public.claim_print_package(text, uuid) to service_role;

-- Reversals are independently verified with PortOne. Stop unstarted fulfillment;
-- an already printed/shipped order keeps its lifecycle and is held for manual review.
create or replace function public.record_print_payment_reversal(
  p_order_id text, p_payment_id text, p_amount integer, p_currency text, p_status text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_order public.orders;
begin
  select * into strict v_order from public.orders where order_id = p_order_id for update;
  if p_payment_id is distinct from v_order.order_id or p_amount is distinct from v_order.amount
     or p_currency is distinct from v_order.payment_currency
     or p_status is null or p_status not in ('CANCELLED','PARTIAL_CANCELLED') then
    raise exception 'payment_order_mismatch' using errcode = '22023';
  end if;
  update public.orders set payment_reversed_at = coalesce(payment_reversed_at, now()),
    payment_reversal_status = p_status,
    status = case when status in ('PAYMENT_PENDING','PAYMENT_COMPLETED') then 'CANCELED' else status end,
    print_package_lock_token = null, print_package_lock_until = null
    where order_id = p_order_id returning * into v_order;
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.record_print_payment_reversal(text, text, integer, text, text) from public, anon, authenticated;
grant execute on function public.record_print_payment_reversal(text, text, integer, text, text) to service_role;

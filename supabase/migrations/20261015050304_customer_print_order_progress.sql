-- Read-only purchaser progress. A locally checked PDF is not supplier receipt,
-- and a request to cancel must remain visible while the server checks it.
-- No sales gate, checkout, payment or supplier call is changed here.
create or replace function public.fetch_my_print_order_progress(p_order_id text) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare o public.orders;stage text;preflight boolean;submitted boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501';end if;
  select * into o from public.orders where order_id=p_order_id and user_id=auth.uid();
  if not found then raise exception 'order_access_denied' using errcode='42501';end if;
  preflight:=coalesce(o.print_manifest->'cover'->>'sha256' ~ '^[a-f0-9]{64}$' and o.print_manifest->'interior'->>'sha256' ~ '^[a-f0-9]{64}$'
    and o.print_manifest->>'sourceFingerprint'=o.print_upload_fingerprint
    and o.print_manifest->'spec'->>'specVersion'=o.print_spec_snapshot->>'specVersion'
    and o.print_manifest->'cover'->'pageCount'='1'::jsonb and o.print_manifest->'interior'->>'pageCount'=o.page_count::text
    and o.print_spec_confirmed_at is not null and o.print_cover_pdf_path is not null and o.print_interior_pdf_path is not null,false);
  submitted:=coalesce(o.print_fulfillment_status in('SUBMITTED','ACCEPTED') and o.print_vendor='REDPRINTING'
    and coalesce(btrim(o.print_vendor_order_id),'')<>'' and o.print_vendor_order_id !~* '^(SPP-|TEST|DEMO)' and o.print_submitted_at is not null,false);
  stage:=case
    when o.status='CANCELED' or (o.status='PAYMENT_PENDING' and o.print_preparation_aborted_at is not null and o.payment_confirmed_at is null) then 'CANCELED'
    when o.status='DELIVERED' then 'DELIVERED'
    when o.status='SHIPPING' then 'SHIPPING'
    when o.status in('IN_PRODUCTION','PRINTING') then 'PRODUCTION'
    when o.print_customer_request_hold then 'HOLD'
    when o.status='PAYMENT_PENDING' then 'PAYMENT_PENDING'
    when o.print_requires_action then 'REVIEW_REQUIRED'
    when submitted and o.print_file_checked_at is not null then 'PRODUCTION_PENDING'
    when submitted then 'FILE_CHECKING'
    when o.print_fulfillment_status='RENDERING' then 'RENDERING'
    when o.print_fulfillment_status='READY' and preflight then 'FILES_READY'
    when o.print_fulfillment_status='REVIEW_REQUIRED' then 'REVIEW_REQUIRED'
    else 'PAID' end;
  return jsonb_build_object('orderId',o.order_id,'customerStage',stage,'preflightPassed',preflight,
    'filesReadyAt',case when preflight then o.print_package_generated_at end,
    'vendorAcceptedAt',case when submitted then o.print_submitted_at end,
    'fileCheckedAt',case when submitted then o.print_file_checked_at end,
    'productionStartedAt',case when o.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') then o.print_accepted_at end,
    'shippedAt',case when o.status in('SHIPPING','DELIVERED') then o.shipped_at end,
    'courier',case when o.status in('SHIPPING','DELIVERED') then o.courier end,
    'trackingNumber',case when o.status in('SHIPPING','DELIVERED') then o.tracking_number end,
    'requiresAction',o.print_requires_action or (o.print_customer_request_hold and o.status not in('CANCELED','DELIVERED')));
end;$$;
revoke all on function public.fetch_my_print_order_progress(text) from public,anon;
grant execute on function public.fetch_my_print_order_progress(text) to authenticated;

-- An authenticated purchaser can reopen status from order history on another
-- device. Edge provides p_actor from getUser; this service-only lookup cannot
-- prepare/relaunch payment or disclose another purchaser's invoice.
create function public.get_owned_print_checkout_by_order(p_actor uuid,p_order_id text) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare payment_id text;
begin
  if p_actor is null or coalesce(p_order_id,'') !~ '^ordp_[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$' then
    raise exception 'invalid_print_checkout_request' using errcode='22023';end if;
  select i.payment_id into payment_id from private.print_checkout_intents i where i.user_id=p_actor and i.order_id=p_order_id;
  if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
  return public.get_owned_print_checkout(p_actor,payment_id,null);
end;$$;
revoke all on function public.get_owned_print_checkout_by_order(uuid,text) from public,anon,authenticated;
grant execute on function public.get_owned_print_checkout_by_order(uuid,text) to service_role;

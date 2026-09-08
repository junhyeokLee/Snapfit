-- First physical SKU; retail is server owned and includes ordinary shipping.
-- Supplier costs are conservative estimates, not a confirmed quote or net profit.
alter table public.orders
  add column if not exists print_fulfillment_status text not null default 'AWAITING_RENDER',
  add column if not exists print_upload_id uuid,
  add column if not exists print_upload_fingerprint text,
  add column if not exists print_cover_pdf_path text,
  add column if not exists print_interior_pdf_path text,
  add column if not exists print_manifest_path text,
  add column if not exists print_manifest jsonb,
  add column if not exists print_spec_override jsonb,
  add column if not exists print_spec_confirmed_at timestamptz,
  add column if not exists print_accepted_at timestamptz,
  add column if not exists fulfillment_method text,
  add column if not exists sender_label_confirmed boolean,
  add column if not exists price_slip_omitted_confirmed boolean,
  add column if not exists promotional_materials_omitted_confirmed boolean,
  add column if not exists print_operations_version integer not null default 1;
alter table public.orders add constraint orders_print_fulfillment_status_check
  check (print_fulfillment_status in ('AWAITING_RENDER','RENDERING','REVIEW_REQUIRED','READY','SUBMITTED','ACCEPTED'));

-- Commercial records and supplier correspondence are never selectable by customers.
create table public.print_order_operations (
  order_id text primary key references public.orders(order_id) on delete cascade,
  print_cost_snapshot jsonb not null,
  actual_print_cost integer, actual_shipping_cost integer, actual_packaging_cost integer,
  payment_fee_reserve integer, reprint_reserve integer, operations_reserve integer,
  contribution_margin integer, print_review_note text, fulfillment_confirmation jsonb,
  print_spec_evidence text
);
alter table public.print_order_operations enable row level security;
revoke all on public.print_order_operations from public, anon, authenticated;
grant all on public.print_order_operations to service_role;

-- Full editor documents live in album.cover_layers_json. album_pages is a legacy
-- representation and may be empty; do not silently undercharge or drop content.
create or replace function public.print_source_page_count(p_album jsonb, p_legacy_count integer)
returns integer language plpgsql immutable security invoker set search_path = '' as $$
declare v_document jsonb; v_count integer;
begin
  if jsonb_typeof(p_album->'cover_layers_json') = 'string' then
    v_document := nullif(p_album->>'cover_layers_json','')::jsonb;
  else
    v_document := p_album->'cover_layers_json';
  end if;
  if jsonb_typeof(v_document->'pages') = 'array' and jsonb_array_length(v_document->'pages') > 0 then
    select count(*)::integer into v_count
      from jsonb_array_elements(v_document->'pages') with ordinality as entry(page, position)
      where not coalesce((page->>'isCover')::boolean, coalesce((page->>'index')::integer, position::integer - 1) = 0);
    return v_count;
  end if;
  return p_legacy_count;
end;
$$;
revoke all on function public.print_source_page_count(jsonb, integer) from public, anon, authenticated;
grant execute on function public.print_source_page_count(jsonb, integer) to service_role;

create or replace function public.get_print_order_quote(p_album_id bigint, p_page_count integer default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_actual integer; v_pages integer; v_legacy integer; v_album jsonb;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then
    raise exception 'album_access_denied' using errcode = '42501';
  end if;
  select to_jsonb(a) into strict v_album from public.albums a where id = p_album_id;
  select count(*)::integer into v_legacy from public.album_pages where album_id = p_album_id;
  v_actual := public.print_source_page_count(v_album, v_legacy);
  v_pages := ((greatest(20, v_actual, coalesce(p_page_count, 0)) + 1) / 2) * 2;
  if p_page_count < 0 or v_pages > 80 then raise exception 'invalid_page_count' using errcode = '22023'; end if;
  return jsonb_build_object('pageCount', v_pages, 'amount', 49900 + (v_pages - 20) * 1200,
    'basePages',20,'basePrice',49900,'extraPageCount',v_pages-20,'extraPagePrice',1200,'pricePerTwoPages',2400,
    'sourcePageCount',v_actual,'addedBlankPageCount',v_pages-v_actual,'productCode','REDP_200_SOFT',
    'productName','20×20cm 소프트커버 포토북','trimWidthMm',200,'trimHeightMm',200,
    'shippingIncluded',true,'maxPages',80,'layoutFit','contain','pricingVersion','PRINT_REDP_200_SOFT_V1',
    'spec',jsonb_build_object('id','REDP_200_SOFT','specVersion','REDP_200_SOFT_REVIEW_V1_'||to_char(0.52+0.67*v_pages/2,'FM90.00'),
      'verified',false,'pageCount',v_pages,'productName','20×20cm 소프트커버 포토북','spineMm',0.52+0.67*v_pages/2,
      'interior',jsonb_build_object('trimWidthMm',200,'trimHeightMm',200,'bleedMm',5),
      'cover',jsonb_build_object('widthMm',410.52+0.67*v_pages/2,'heightMm',210,
        'back',jsonb_build_object('xMm',5,'yMm',5,'widthMm',200,'heightMm',200),
        'front',jsonb_build_object('xMm',205.52+0.67*v_pages/2,'yMm',5,'widthMm',200,'heightMm',200)),
      'minInteriorPages',20,'maxInteriorPages',80,'pageMultiple',2,'dpi',300,'minimumPhotoPpi',150,'colorSpace','sRGB','layoutFit','contain'));

end;
$$;
revoke all on function public.get_print_order_quote(bigint, integer) from public, anon;
grant execute on function public.get_print_order_quote(bigint, integer) to authenticated;

create or replace function public.create_print_order(
  p_album_id bigint, p_page_count integer, p_expected_amount integer, p_payment_method text,
  p_recipient_name text, p_recipient_phone text, p_zip_code text, p_address_line1 text,
  p_address_line2 text default '', p_delivery_memo text default ''
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_quote jsonb; v_album public.albums; v_order public.orders; v_pages jsonb; v_actual integer;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then
    raise exception 'album_access_denied' using errcode = '42501';
  end if;
  select * into strict v_album from public.albums where id = p_album_id for share;
  v_quote := public.get_print_order_quote(p_album_id,p_page_count);
  if p_expected_amount is distinct from (v_quote->>'amount')::integer then
    raise exception 'order_quote_changed' using errcode = '22023';
  end if;
  if coalesce(btrim(p_payment_method),'') = '' then
    raise exception 'payment_method_required' using errcode = '22023';
  end if;
  if coalesce(btrim(p_recipient_name),'') = '' or coalesce(p_recipient_phone,'') !~ '^\d{10,11}$'
    or coalesce(p_zip_code,'') !~ '^\d{5}$' or coalesce(btrim(p_address_line1),'') = '' then
    raise exception 'invalid_delivery_address' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.page_index),'[]'::jsonb) into v_pages
    from public.album_pages p where p.album_id = p_album_id;
  v_actual := public.print_source_page_count(to_jsonb(v_album),jsonb_array_length(v_pages));
  if v_actual > (v_quote->>'pageCount')::integer then raise exception 'order_quote_changed' using errcode = '22023'; end if;
  insert into public.orders(user_id,album_id,title,amount,page_count,payment_method,
    recipient_name,recipient_phone,zip_code,address_line1,address_line2,delivery_memo,
    status,pricing_version,print_content_snapshot)
  values(auth.uid(),p_album_id,coalesce(nullif(btrim(v_album.title),''),'스냅핏 포토북'),
    (v_quote->>'amount')::integer,(v_quote->>'pageCount')::integer,p_payment_method,
    btrim(p_recipient_name),p_recipient_phone,p_zip_code,btrim(p_address_line1),
    btrim(coalesce(p_address_line2,'')),btrim(coalesce(p_delivery_memo,'')),
    'PAYMENT_PENDING','PRINT_REDP_200_SOFT_V1',jsonb_build_object('album',to_jsonb(v_album),'pages',v_pages))
  returning * into v_order;
  insert into public.print_order_operations(order_id,print_cost_snapshot) values(v_order.order_id,
    jsonb_build_object('version','REDP_COST_ESTIMATE_2026_09','isEstimate',true,
      'estimatedPrintCost',22600 + (((v_quote->>'pageCount')::integer-20)/2)*1800,
      'estimatedShippingCost',7000,'estimatedPackagingCost',1500,
      'paymentFeeRate',0.04,'reprintReserveRate',0.05,'operationsReserve',3000,'minimumContribution',10000,
      'marginDefinition','수취액-실제제작/배송/포장비-결제수수료충당-재제작충당-운영충당3000원. 세금/잔여인건비/고정비 차감 전'));
  return to_jsonb(v_order);
end;
$$;
-- Physical sales remain disabled irrespective of migration application order.
revoke all on function public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;

create or replace function public.guard_print_fulfillment_update()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_fee integer; v_reserve integer; v_margin integer; v_ops public.print_order_operations;
begin
  if new.pricing_version is distinct from 'PRINT_REDP_200_SOFT_V1' then return new; end if;
  if old.print_fulfillment_status in ('SUBMITTED','ACCEPTED') and
    row(new.print_vendor_order_id,new.print_cover_pdf_path,new.print_interior_pdf_path,new.print_manifest,new.print_spec_override,
      new.fulfillment_method)
      is distinct from row(old.print_vendor_order_id,old.print_cover_pdf_path,old.print_interior_pdf_path,old.print_manifest,old.print_spec_override,
      old.fulfillment_method) then
    raise exception 'submitted_print_details_immutable' using errcode='23514'; end if;
  if new.print_fulfillment_status is distinct from old.print_fulfillment_status then
    if new.verified_payment_id is null or new.payment_reversed_at is not null then raise exception 'verified_payment_required' using errcode='23514'; end if;
    if not (
      (old.print_fulfillment_status in ('AWAITING_RENDER','RENDERING','REVIEW_REQUIRED','READY') and new.print_fulfillment_status in ('AWAITING_RENDER','RENDERING'))
      or (old.print_fulfillment_status='RENDERING' and new.print_fulfillment_status='REVIEW_REQUIRED')
      or (old.print_fulfillment_status='REVIEW_REQUIRED' and new.print_fulfillment_status='READY')
      or (old.print_fulfillment_status='READY' and new.print_fulfillment_status='SUBMITTED')
      or (old.print_fulfillment_status='SUBMITTED' and new.print_fulfillment_status='ACCEPTED')) then
      raise exception 'invalid_print_fulfillment_transition' using errcode='23514'; end if;
  end if;
  if new.print_fulfillment_status in ('REVIEW_REQUIRED','READY','SUBMITTED','ACCEPTED') and
     (new.print_cover_pdf_path is null or new.print_interior_pdf_path is null or new.print_manifest is null) then
    raise exception 'print_files_not_ready' using errcode='23514'; end if;
  if new.print_fulfillment_status in ('READY','SUBMITTED','ACCEPTED') and new.print_spec_confirmed_at is null then
    raise exception 'vendor_spec_review_required' using errcode='23514'; end if;
  if new.print_fulfillment_status in ('SUBMITTED','ACCEPTED') then
    select * into strict v_ops from public.print_order_operations where order_id=new.order_id;
    if coalesce(btrim(new.print_vendor_order_id),'')='' or new.print_vendor_order_id ~* '^(SPP-|TEST|DEMO)' or new.print_submitted_at is null then
      raise exception 'real_vendor_order_id_required' using errcode='23514'; end if;
    if new.fulfillment_method is null or new.fulfillment_method not in ('DIRECT','REPACK') then
      raise exception 'fulfillment_method_required' using errcode='23514'; end if;
    if new.fulfillment_method='DIRECT' and (new.sender_label_confirmed is distinct from true or new.price_slip_omitted_confirmed is distinct from true or new.promotional_materials_omitted_confirmed is distinct from true or length(coalesce(v_ops.fulfillment_confirmation->>'evidence',''))<10) then
      raise exception 'direct_shipping_confirmation_required' using errcode='23514'; end if;
    if v_ops.actual_print_cost is null or v_ops.actual_print_cost<=0 or v_ops.actual_shipping_cost is null or v_ops.actual_shipping_cost<0
      or v_ops.actual_packaging_cost is null or v_ops.actual_packaging_cost<0 then
      raise exception 'actual_vendor_costs_required' using errcode='23514'; end if;
    v_fee:=ceil(new.amount*(v_ops.print_cost_snapshot->>'paymentFeeRate')::numeric)::integer;
    v_reserve:=ceil(new.amount*(v_ops.print_cost_snapshot->>'reprintReserveRate')::numeric)::integer;
    v_margin:=new.amount-v_ops.actual_print_cost-v_ops.actual_shipping_cost-v_ops.actual_packaging_cost-v_fee-v_reserve-(v_ops.print_cost_snapshot->>'operationsReserve')::integer;
    if v_margin is null or v_margin < (v_ops.print_cost_snapshot->>'minimumContribution')::integer
      or v_ops.contribution_margin is distinct from v_margin or v_ops.payment_fee_reserve is distinct from v_fee or v_ops.reprint_reserve is distinct from v_reserve or v_ops.operations_reserve is distinct from (v_ops.print_cost_snapshot->>'operationsReserve')::integer then
      raise exception 'print_margin_below_minimum' using errcode='23514'; end if;
  end if;
  if new.status in ('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') and
    (new.print_fulfillment_status<>'ACCEPTED' or new.print_accepted_at is null) then
    raise exception 'vendor_acceptance_required' using errcode='23514'; end if;
  if new.status='SHIPPING' and (coalesce(btrim(new.courier),'')='' or coalesce(btrim(new.tracking_number),'')='') then
    raise exception 'shipping_details_required' using errcode='23514'; end if;
  return new;
end;
$$;
revoke all on function public.guard_print_fulfillment_update() from public,anon,authenticated;
create trigger orders_guard_fulfillment before update on public.orders for each row execute function public.guard_print_fulfillment_update();

create or replace function public.guard_print_operations_update()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_state text;
begin
  if new.print_cost_snapshot is distinct from old.print_cost_snapshot then
    raise exception 'order_cost_policy_immutable' using errcode='23514'; end if;
  select print_fulfillment_status into v_state from public.orders where order_id=old.order_id;
  if v_state in ('SUBMITTED','ACCEPTED') and new is distinct from old then
    raise exception 'submitted_print_details_immutable' using errcode='23514'; end if;
  return new;
end;
$$;
revoke all on function public.guard_print_operations_update() from public,anon,authenticated;
create trigger print_operations_immutable before update on public.print_order_operations for each row execute function public.guard_print_operations_update();

create or replace function public.submit_print_vendor(p_order_id text,p_order_patch jsonb,p_operations_patch jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_order public.orders;
begin
  select * into strict v_order from public.orders where order_id=p_order_id for update;
  if v_order.status<>'PAYMENT_COMPLETED' or v_order.print_fulfillment_status<>'READY' or v_order.payment_reversed_at is not null then
    raise exception 'print_state_changed' using errcode='23514'; end if;
  update public.print_order_operations set
    actual_print_cost=(p_operations_patch->>'actual_print_cost')::integer,
    actual_shipping_cost=(p_operations_patch->>'actual_shipping_cost')::integer,
    actual_packaging_cost=(p_operations_patch->>'actual_packaging_cost')::integer,
    payment_fee_reserve=(p_operations_patch->>'payment_fee_reserve')::integer,
    reprint_reserve=(p_operations_patch->>'reprint_reserve')::integer,
    operations_reserve=(p_operations_patch->>'operations_reserve')::integer,
    contribution_margin=(p_operations_patch->>'contribution_margin')::integer,
    fulfillment_confirmation=p_operations_patch->'fulfillment_confirmation'
    where order_id=p_order_id;
  update public.orders set print_fulfillment_status='SUBMITTED',print_vendor='REDPRINTING',
    print_vendor_order_id=p_order_patch->>'print_vendor_order_id',print_submitted_at=now(),
    fulfillment_method=p_order_patch->>'fulfillment_method',
    sender_label_confirmed=(p_order_patch->>'sender_label_confirmed')::boolean,
    price_slip_omitted_confirmed=(p_order_patch->>'price_slip_omitted_confirmed')::boolean,
    promotional_materials_omitted_confirmed=(p_order_patch->>'promotional_materials_omitted_confirmed')::boolean
    where order_id=p_order_id returning * into v_order;
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.submit_print_vendor(text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.submit_print_vendor(text,jsonb,jsonb) to service_role;

-- Paths remain private. Only admin-authenticated Edge code issues short-lived
-- download/upload capabilities. Do not add public or owner storage policies.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('print-packages','print-packages',false,104857600,array['application/pdf','application/json'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

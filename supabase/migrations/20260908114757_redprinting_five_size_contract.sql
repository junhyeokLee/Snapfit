-- Expand print preparation to the five official PHBKMYB trim sizes. Supplier
-- prices and inferred spine geometry remain estimates requiring review.
-- Do not change applied migrations or reopen physical order creation/payments.
alter table public.orders add column if not exists print_product_snapshot jsonb;

create or replace function public.print_product_policy(p_product_id text)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_width integer;v_height integer;v_base integer;v_extra integer;v_cost integer;v_cost_extra integer;
begin
  case p_product_id
    when 'REDP_200X150_SOFT' then v_width:=200;v_height:=150;v_base:=49900;v_extra:=2400;v_cost:=22000;v_cost_extra:=1800;
    when 'REDP_200_SOFT' then v_width:=200;v_height:=200;v_base:=49900;v_extra:=2400;v_cost:=22600;v_cost_extra:=1800;
    when 'REDP_250X200_SOFT' then v_width:=250;v_height:=200;v_base:=64900;v_extra:=3600;v_cost:=34000;v_cost_extra:=2600;
    when 'REDP_250_SOFT' then v_width:=250;v_height:=250;v_base:=79900;v_extra:=4400;v_cost:=44000;v_cost_extra:=3200;
    when 'REDP_300_SOFT' then v_width:=300;v_height:=300;v_base:=99900;v_extra:=6000;v_cost:=60000;v_cost_extra:=4400;
    else raise exception 'invalid_print_product' using errcode='22023';
  end case;
  return jsonb_build_object('id',p_product_id,'trimWidthMm',v_width,'trimHeightMm',v_height,
    'productName',(v_width/10)::text||'×'||(v_height/10)::text||'cm 소프트커버 포토북',
    'basePrice',v_base,'pricePerTwoPages',v_extra,'estimatedBasePrintCost',v_cost,'estimatedCostPerTwoPages',v_cost_extra,
    'priceIsEstimate',true,'supplierCostVerified',false,'version','REDP_SIZE_COST_ESTIMATE_V2');
end;
$$;
revoke all on function public.print_product_policy(text) from public,anon,authenticated;
grant execute on function public.print_product_policy(text) to service_role;

create or replace function public.canonical_print_product(p_product jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_policy jsonb;
begin
  if jsonb_typeof(p_product) is distinct from 'object' or jsonb_typeof(p_product->'id') is distinct from 'string' then
    raise exception 'invalid_print_product' using errcode='22023'; end if;
  v_policy:=public.print_product_policy(p_product->>'id');
  if jsonb_typeof(p_product->'trimWidthMm') is distinct from 'number' or jsonb_typeof(p_product->'trimHeightMm') is distinct from 'number'
    or p_product->'trimWidthMm' is distinct from v_policy->'trimWidthMm' or p_product->'trimHeightMm' is distinct from v_policy->'trimHeightMm' then
    raise exception 'invalid_print_product' using errcode='22023'; end if;
  return jsonb_build_object('id',v_policy->>'id','trimWidthMm',v_policy->'trimWidthMm','trimHeightMm',v_policy->'trimHeightMm');
end;
$$;
revoke all on function public.canonical_print_product(jsonb) from public,anon,authenticated;
grant execute on function public.canonical_print_product(jsonb) to service_role;

create or replace function public.resolve_album_print_product(p_album jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_doc jsonb;v_product jsonb;v_raw text;v_parts text[];v_ratio numeric;
begin
  if jsonb_typeof(p_album->'cover_layers_json')='string' then v_doc:=nullif(p_album->>'cover_layers_json','')::jsonb;
  else v_doc:=p_album->'cover_layers_json'; end if;
  if v_doc is not null and jsonb_typeof(v_doc)<>'object' then raise exception 'invalid_print_snapshot' using errcode='22023'; end if;
  v_raw:=btrim(coalesce(p_album->>'ratio',''));
  if v_raw ~ '^\d+(\.\d+)?$' then v_ratio:=v_raw::numeric;
  elsif v_raw ~ '^\d+(\.\d+)?\s*[:/]\s*\d+(\.\d+)?$' then
    v_parts:=regexp_split_to_array(v_raw,'\s*[:/]\s*');
    v_ratio:=v_parts[1]::numeric/nullif(v_parts[2]::numeric,0);
  end if;
  if v_ratio is null or v_ratio<=0 then raise exception 'unsupported_print_product' using errcode='22023'; end if;
  if v_doc->'printProduct' is not null and v_doc->'printProduct'<>'null'::jsonb then
    v_product:=public.canonical_print_product(v_doc->'printProduct');
    if abs(v_ratio-(v_product->>'trimWidthMm')::numeric/(v_product->>'trimHeightMm')::numeric)>0.01 then
      raise exception 'print_product_ratio_mismatch' using errcode='22023'; end if;
    return v_product;
  end if;
  if abs(v_ratio-1)<=0.01 then
    return jsonb_build_object('id','REDP_200_SOFT','trimWidthMm',200,'trimHeightMm',200);
  elsif abs(v_ratio-4.0/3.0)<=0.01 then
    return jsonb_build_object('id','REDP_200X150_SOFT','trimWidthMm',200,'trimHeightMm',150);
  end if;
  raise exception 'unsupported_print_product' using errcode='22023';
end;
$$;
revoke all on function public.resolve_album_print_product(jsonb) from public,anon,authenticated;
grant execute on function public.resolve_album_print_product(jsonb) to service_role;

create or replace function public.get_print_order_quote(p_album_id bigint,p_page_count integer default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_album jsonb;v_product jsonb;v_policy jsonb;v_actual integer;v_legacy integer;v_pages integer;v_width integer;v_height integer;v_spine numeric;v_spec jsonb;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then raise exception 'album_access_denied' using errcode='42501'; end if;
  select to_jsonb(a) into strict v_album from public.albums a where id=p_album_id;
  v_product:=public.resolve_album_print_product(v_album);
  v_policy:=public.print_product_policy(v_product->>'id');
  select count(*)::integer into v_legacy from public.album_pages where album_id=p_album_id;
  v_actual:=public.print_source_page_count(v_album,v_legacy);
  v_pages:=((greatest(20,v_actual,coalesce(p_page_count,0))+1)/2)*2;
  if p_page_count<0 or v_pages>80 then raise exception 'invalid_page_count' using errcode='22023'; end if;
  v_width:=(v_product->>'trimWidthMm')::integer;v_height:=(v_product->>'trimHeightMm')::integer;v_spine:=0.52+0.67*v_pages/2;
  v_spec:=jsonb_build_object('id',v_product->>'id','specVersion',(v_product->>'id')||'_REVIEW_V2_'||to_char(v_spine,'FM90.00'),
    'verified',false,'pageCount',v_pages,'productName',v_policy->>'productName','spineMm',v_spine,
    'geometrySource','동일 용지의 책등 계산 추정. 해당 규격/페이지수 업체 도면과 대조 필요.',
    'interior',jsonb_build_object('trimWidthMm',v_width,'trimHeightMm',v_height,'bleedMm',5),
    'cover',jsonb_build_object('widthMm',2*v_width+10+v_spine,'heightMm',v_height+10,
      'back',jsonb_build_object('xMm',5,'yMm',5,'widthMm',v_width,'heightMm',v_height),
      'front',jsonb_build_object('xMm',5+v_width+v_spine,'yMm',5,'widthMm',v_width,'heightMm',v_height)),
    'minInteriorPages',20,'maxInteriorPages',80,'pageMultiple',2,'dpi',300,'minimumPhotoPpi',150,'colorSpace','sRGB','layoutFit','contain',
    'reviewRequired',jsonb_build_array('vendor_cover_template','spine_width','bleed_and_color','physical_sample'));
  return jsonb_build_object('pageCount',v_pages,'amount',(v_policy->>'basePrice')::integer+((v_pages-20)/2)*(v_policy->>'pricePerTwoPages')::integer,
    'basePages',20,'basePrice',v_policy->'basePrice','extraPageCount',v_pages-20,'extraPagePrice',(v_policy->>'pricePerTwoPages')::integer/2,
    'pricePerTwoPages',v_policy->'pricePerTwoPages','sourcePageCount',v_actual,'addedBlankPageCount',v_pages-v_actual,
    'productCode',v_product->>'id','productName',v_policy->>'productName','printProduct',v_product,
    'trimWidthMm',v_width,'trimHeightMm',v_height,'shippingIncluded',true,'maxPages',80,'layoutFit','contain',
    'pricingVersion','PRINT_REDP_MULTISIZE_V2','priceIsEstimate',true,'supplierCostVerified',false,
    'priceNotice','제작업체 최종 견적 확인 전 예상 판매가입니다. 실물 주문·결제는 아직 제공되지 않습니다.','spec',v_spec);
end;
$$;
revoke all on function public.get_print_order_quote(bigint,integer) from public,anon;
grant execute on function public.get_print_order_quote(bigint,integer) to authenticated;

-- Preserve the disabled preparation routine for a future explicitly approved
-- payment implementation. It is inaccessible to customer AND service roles.
create or replace function public.create_print_order(
  p_album_id bigint,p_page_count integer,p_expected_amount integer,p_payment_method text,
  p_recipient_name text,p_recipient_phone text,p_zip_code text,p_address_line1 text,
  p_address_line2 text default '',p_delivery_memo text default ''
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_quote jsonb;v_album public.albums;v_order public.orders;v_pages jsonb;v_policy jsonb;v_product jsonb;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then raise exception 'album_access_denied' using errcode='42501'; end if;
  select * into strict v_album from public.albums where id=p_album_id for share;
  v_quote:=public.get_print_order_quote(p_album_id,p_page_count);
  v_product:=v_quote->'printProduct';v_policy:=public.print_product_policy(v_product->>'id');
  if p_expected_amount is distinct from (v_quote->>'amount')::integer then raise exception 'order_quote_changed' using errcode='22023'; end if;
  if coalesce(btrim(p_payment_method),'')='' then raise exception 'payment_method_required' using errcode='22023'; end if;
  if coalesce(btrim(p_recipient_name),'')='' or coalesce(p_recipient_phone,'') !~ '^\d{10,11}$' or coalesce(p_zip_code,'') !~ '^\d{5}$'
    or coalesce(btrim(p_address_line1),'')='' then raise exception 'invalid_delivery_address' using errcode='22023'; end if;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.page_index),'[]'::jsonb) into v_pages from public.album_pages p where p.album_id=p_album_id;
  if public.print_source_page_count(to_jsonb(v_album),jsonb_array_length(v_pages))>(v_quote->>'pageCount')::integer then raise exception 'order_quote_changed' using errcode='22023'; end if;
  insert into public.orders(user_id,album_id,title,amount,page_count,payment_method,recipient_name,recipient_phone,zip_code,address_line1,address_line2,
    delivery_memo,status,pricing_version,print_content_snapshot,print_product_snapshot)
  values(auth.uid(),p_album_id,coalesce(nullif(btrim(v_album.title),''),'스냅핏 포토북'),(v_quote->>'amount')::integer,(v_quote->>'pageCount')::integer,
    p_payment_method,btrim(p_recipient_name),p_recipient_phone,p_zip_code,btrim(p_address_line1),btrim(coalesce(p_address_line2,'')),btrim(coalesce(p_delivery_memo,'')),
    'PAYMENT_PENDING','PRINT_REDP_MULTISIZE_V2',jsonb_build_object('album',to_jsonb(v_album),'pages',v_pages,'printProduct',v_product),v_product)
  returning * into v_order;
  insert into public.print_order_operations(order_id,print_cost_snapshot) values(v_order.order_id,
    jsonb_build_object('version',v_policy->>'version','productCode',v_product->>'id','isEstimate',true,'supplierCostVerified',false,
      'estimatedPrintCost',(v_policy->>'estimatedBasePrintCost')::integer+(((v_quote->>'pageCount')::integer-20)/2)*(v_policy->>'estimatedCostPerTwoPages')::integer,
      'estimatedShippingCost',7000,'estimatedPackagingCost',1500,'paymentFeeRate',0.04,'reprintReserveRate',0.05,'operationsReserve',3000,'minimumContribution',10000,
      'marginDefinition','수취액-실제제작/전체배송/포장비-결제수수료충당-재제작충당-운영충당3000원. 세금/잔여인건비/고정비 차감 전'));
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;

create or replace function public.guard_print_product_snapshot()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_product jsonb;
begin
  if tg_op='UPDATE' and new.print_product_snapshot is distinct from old.print_product_snapshot then
    raise exception 'order_print_product_immutable' using errcode='23514'; end if;
  if new.pricing_version='PRINT_REDP_MULTISIZE_V2' then
    v_product:=public.canonical_print_product(new.print_product_snapshot);
    if v_product is distinct from public.canonical_print_product(new.print_content_snapshot->'printProduct')
      or v_product is distinct from public.resolve_album_print_product(new.print_content_snapshot->'album') then
      raise exception 'print_product_snapshot_mismatch' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_print_product_snapshot() from public,anon,authenticated;
create trigger orders_guard_print_product before insert or update on public.orders for each row execute function public.guard_print_product_snapshot();

-- Apply the same private-cost, review, real-submission and acceptance guards to
-- every V2 SKU while retaining the frozen V1 square contract.
create or replace function public.guard_print_fulfillment_update()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_fee integer; v_reserve integer; v_margin integer; v_ops public.print_order_operations;
begin
  if new.pricing_version is null or new.pricing_version not in ('PRINT_REDP_200_SOFT_V1','PRINT_REDP_MULTISIZE_V2') then return new; end if;
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

-- The independent payment-retirement guard and revoked create permissions remain intact.

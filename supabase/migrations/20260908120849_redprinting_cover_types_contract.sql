-- Add cover type selection without changing frozen V1/V2 prices, files or payment retirement.
-- Hardcover prices remain conservative estimates until final supplier review.
create or replace function public.print_product_policy(p_product_id text)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_width integer;v_height integer;v_base integer;v_extra integer;v_cost integer;v_cost_extra integer;v_cover text;
begin
  case p_product_id
    when 'REDP_200X150_SOFT' then v_width:=200;v_height:=150;v_base:=49900;v_extra:=2400;v_cost:=22000;v_cost_extra:=1800;
    when 'REDP_200_SOFT' then v_width:=200;v_height:=200;v_base:=49900;v_extra:=2400;v_cost:=22600;v_cost_extra:=1800;
    when 'REDP_250X200_SOFT' then v_width:=250;v_height:=200;v_base:=64900;v_extra:=3600;v_cost:=34000;v_cost_extra:=2600;
    when 'REDP_250_SOFT' then v_width:=250;v_height:=250;v_base:=79900;v_extra:=4400;v_cost:=44000;v_cost_extra:=3200;
    when 'REDP_300_SOFT' then v_width:=300;v_height:=300;v_base:=99900;v_extra:=6000;v_cost:=60000;v_cost_extra:=4400;
    when 'REDP_200X150_HARD' then v_width:=200;v_height:=150;v_base:=69900;v_extra:=2400;v_cost:=34000;v_cost_extra:=1800;
    when 'REDP_200_HARD' then v_width:=200;v_height:=200;v_base:=69900;v_extra:=2400;v_cost:=34600;v_cost_extra:=1800;
    when 'REDP_250X200_HARD' then v_width:=250;v_height:=200;v_base:=84900;v_extra:=3600;v_cost:=46000;v_cost_extra:=2600;
    when 'REDP_250_HARD' then v_width:=250;v_height:=250;v_base:=99900;v_extra:=4400;v_cost:=56000;v_cost_extra:=3200;
    when 'REDP_300_HARD' then v_width:=300;v_height:=300;v_base:=129900;v_extra:=6000;v_cost:=80000;v_cost_extra:=4400;
    else raise exception 'invalid_print_product' using errcode='22023';
  end case;
  v_cover:=case when right(p_product_id,5)='_HARD' then '하드커버' else '소프트커버' end;
  return jsonb_build_object('id',p_product_id,'trimWidthMm',v_width,'trimHeightMm',v_height,
    'productName',(v_width/10)::text||'×'||(v_height/10)::text||'cm '||v_cover||' 포토북','coverLabel',v_cover,'coverType',case when right(p_product_id,5)='_HARD' then 'HARD' else 'SOFT' end,
    'basePrice',v_base,'pricePerTwoPages',v_extra,'estimatedBasePrintCost',v_cost,'estimatedCostPerTwoPages',v_cost_extra,
    'priceIsEstimate',true,'supplierCostVerified',false,'version','REDP_COVERTYPE_COST_ESTIMATE_V3');
end;
$$;
revoke all on function public.print_product_policy(text) from public,anon,authenticated;
grant execute on function public.print_product_policy(text) to service_role;

-- Structural validation for an exact supplier casewrap; no guessed softcover fallback.
create or replace function public.validate_hardcover_geometry(p_geometry jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_rect jsonb;v_key text;v_name text;v_width numeric;v_height numeric;
begin
  if jsonb_typeof(p_geometry) is distinct from 'object' or p_geometry->>'construction' is distinct from 'casewrap' then
    raise exception 'hardcover_template_required' using errcode='22023'; end if;
  foreach v_key in array array['widthMm','heightMm','bleedMm'] loop
    if jsonb_typeof(p_geometry->v_key) is distinct from 'number' then raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
  end loop;
  v_width:=(p_geometry->>'widthMm')::numeric;v_height:=(p_geometry->>'heightMm')::numeric;
  if v_width<=0 or v_height<=0 or v_width>1000 or v_height>1000 or (p_geometry->>'bleedMm')::numeric<0 or (p_geometry->>'bleedMm')::numeric>50 then
    raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
  foreach v_name in array array['front','back','trim'] loop
    v_rect:=p_geometry->v_name;
    if jsonb_typeof(v_rect) is distinct from 'object' then raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
    foreach v_key in array array['xMm','yMm','widthMm','heightMm'] loop
      if jsonb_typeof(v_rect->v_key) is distinct from 'number' then raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
    end loop;
    if (v_rect->>'xMm')::numeric<0 or (v_rect->>'yMm')::numeric<0 or (v_rect->>'widthMm')::numeric<=0 or (v_rect->>'heightMm')::numeric<=0
      or (v_rect->>'xMm')::numeric+(v_rect->>'widthMm')::numeric>v_width or (v_rect->>'yMm')::numeric+(v_rect->>'heightMm')::numeric>v_height then
      raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
  end loop;
  if (p_geometry#>>'{back,xMm}')::numeric+(p_geometry#>>'{back,widthMm}')::numeric>=(p_geometry#>>'{front,xMm}')::numeric then
    raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
  foreach v_name in array array['front','back'] loop
    v_rect:=p_geometry->v_name;
    if (v_rect->>'xMm')::numeric<(p_geometry#>>'{trim,xMm}')::numeric or (v_rect->>'yMm')::numeric<(p_geometry#>>'{trim,yMm}')::numeric
      or (v_rect->>'xMm')::numeric+(v_rect->>'widthMm')::numeric>(p_geometry#>>'{trim,xMm}')::numeric+(p_geometry#>>'{trim,widthMm}')::numeric
      or (v_rect->>'yMm')::numeric+(v_rect->>'heightMm')::numeric>(p_geometry#>>'{trim,yMm}')::numeric+(p_geometry#>>'{trim,heightMm}')::numeric then
      raise exception 'invalid_hardcover_geometry' using errcode='22023'; end if;
  end loop;
  return p_geometry;
end;
$$;
revoke all on function public.validate_hardcover_geometry(jsonb) from public,anon,authenticated;
grant execute on function public.validate_hardcover_geometry(jsonb) to service_role;

-- Measured hardcover casewrap construction; unsampled page counts remain review estimates.
create or replace function public.hardcover_review_geometry(p_product_id text,p_pages integer)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_policy jsonb;v_width integer;v_height integer;v_spine numeric;
begin
  v_policy:=public.print_product_policy(p_product_id);
  if v_policy->>'coverType'<>'HARD' or p_pages is null or p_pages<20 or p_pages>80 or p_pages%2<>0 then
    raise exception 'hardcover_template_required' using errcode='22023'; end if;
  v_width:=(v_policy->>'trimWidthMm')::integer+6;v_height:=(v_policy->>'trimHeightMm')::integer+6;
  v_spine:=2.40+0.67*p_pages/2;
  return public.validate_hardcover_geometry(jsonb_build_object('construction','casewrap','bleedMm',20,
    'widthMm',2*v_width+v_spine+40,'heightMm',v_height+40,
    'back',jsonb_build_object('xMm',20,'yMm',20,'widthMm',v_width,'heightMm',v_height),
    'front',jsonb_build_object('xMm',20+v_width+v_spine,'yMm',20,'widthMm',v_width,'heightMm',v_height),
    'trim',jsonb_build_object('xMm',20,'yMm',20,'widthMm',2*v_width+v_spine,'heightMm',v_height)));
end;
$$;
revoke all on function public.hardcover_review_geometry(text,integer) from public,anon,authenticated;
grant execute on function public.hardcover_review_geometry(text,integer) to service_role;

create or replace function public.get_print_order_quote(p_album_id bigint,p_page_count integer default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_album jsonb;v_product jsonb;v_policy jsonb;v_actual integer;v_legacy integer;v_pages integer;v_width integer;v_height integer;v_spine numeric;v_spec jsonb;v_cover jsonb;v_measured boolean;
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
  if v_policy->>'coverType'='SOFT' then
  v_spec:=jsonb_build_object('id',v_product->>'id','specVersion',(v_product->>'id')||'_REVIEW_V3_'||to_char(v_spine,'FM90.00'),
    'verified',false,'coverType',v_policy->>'coverType','coverLabel',v_policy->>'coverLabel','pageCount',v_pages,'productName',v_policy->>'productName','spineMm',v_spine,
    'geometrySource','동일 용지의 책등 계산 추정. 해당 규격/페이지수 업체 도면과 대조 필요.',
    'interior',jsonb_build_object('trimWidthMm',v_width,'trimHeightMm',v_height,'bleedMm',5),
    'cover',jsonb_build_object('widthMm',2*v_width+10+v_spine,'heightMm',v_height+10,
      'back',jsonb_build_object('xMm',5,'yMm',5,'widthMm',v_width,'heightMm',v_height),
      'front',jsonb_build_object('xMm',5+v_width+v_spine,'yMm',5,'widthMm',v_width,'heightMm',v_height)),
    'minInteriorPages',20,'maxInteriorPages',80,'pageMultiple',2,'dpi',300,'minimumPhotoPpi',150,'colorSpace','sRGB','layoutFit','contain',
    'reviewRequired',jsonb_build_array('vendor_cover_template','spine_width','bleed_and_color','physical_sample'));
  else
    v_measured:=(v_pages=20 or (v_product->>'id'='REDP_200X150_HARD' and v_pages=22) or (v_product->>'id'='REDP_300_HARD' and v_pages=80));
    v_spine:=2.40+0.67*v_pages/2;
    v_cover:=public.hardcover_review_geometry(v_product->>'id',v_pages);
    v_spec:=jsonb_build_object('id',v_product->>'id','specVersion',(v_product->>'id')||'_REVIEW_V3_'||to_char(v_spine,'FM90.00'),
      'verified',false,'coverType','HARD','coverLabel','하드커버','coverGeometrySource','official_default','templateFamily','REDP_PHBKMYB_CASEWRAP','pageCount',v_pages,'productName',v_policy->>'productName','spineMm',v_spine,
      'geometryMeasured',v_measured,'geometrySource',case when v_measured then '해당 크기·페이지수 공식 하드커버 도면 측정. 보드 +6mm·감싸기20mm. 실제 제작 전 도면·색상·실물 검수 필요.' else '하드커버 공식 20/22/80페이지 도면 측정치에서 추정. 해당 크기·페이지수는 미측정이므로 도면과 대조 필요.' end,
      'interior',jsonb_build_object('trimWidthMm',v_width,'trimHeightMm',v_height,'bleedMm',5),'cover',v_cover,
      'minInteriorPages',20,'maxInteriorPages',80,'pageMultiple',2,'dpi',300,'minimumPhotoPpi',150,'colorSpace','sRGB','layoutFit','contain',
      'reviewRequired',jsonb_build_array('vendor_casewrap_template','spine_and_hinges','bleed_and_color','physical_sample'));
  end if;
  return jsonb_build_object('pageCount',v_pages,'amount',(v_policy->>'basePrice')::integer+((v_pages-20)/2)*(v_policy->>'pricePerTwoPages')::integer,
    'basePages',20,'basePrice',v_policy->'basePrice','extraPageCount',v_pages-20,'extraPagePrice',(v_policy->>'pricePerTwoPages')::integer/2,
    'pricePerTwoPages',v_policy->'pricePerTwoPages','sourcePageCount',v_actual,'addedBlankPageCount',v_pages-v_actual,
    'productCode',v_product->>'id','productName',v_policy->>'productName','printProduct',v_product,'coverType',v_policy->>'coverType','coverLabel',v_policy->>'coverLabel',
    'trimWidthMm',v_width,'trimHeightMm',v_height,'shippingIncluded',true,'maxPages',80,'layoutFit','contain',
    'pricingVersion','PRINT_REDP_COVERTYPE_V3','priceIsEstimate',true,'supplierCostVerified',false,
    'specMissing',v_spec is null,'printPdfAvailable',v_spec is not null,'printTemplateStatus',case when v_spec is null then 'REQUIRES_VENDOR_TEMPLATE' else 'REVIEW_REQUIRED' end,
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
    'PAYMENT_PENDING','PRINT_REDP_COVERTYPE_V3',jsonb_build_object('album',to_jsonb(v_album),'pages',v_pages,'printProduct',v_product),v_product)
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
  if new.pricing_version in ('PRINT_REDP_MULTISIZE_V2','PRINT_REDP_COVERTYPE_V3') then
    v_product:=public.canonical_print_product(new.print_product_snapshot);
    if new.pricing_version='PRINT_REDP_MULTISIZE_V2' and right(v_product->>'id',5)='_HARD' then
      raise exception 'print_product_version_mismatch' using errcode='23514'; end if;
    if v_product is distinct from public.canonical_print_product(new.print_content_snapshot->'printProduct')
      or v_product is distinct from public.resolve_album_print_product(new.print_content_snapshot->'album') then
      raise exception 'print_product_snapshot_mismatch' using errcode='23514'; end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_print_product_snapshot() from public,anon,authenticated;
-- Existing trigger now uses this replaced function.

-- Apply the same private-cost, review, real-submission and acceptance guards to
-- every V3 SKU while retaining frozen V1 and V2 contracts.
create or replace function public.guard_print_fulfillment_update()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_fee integer; v_reserve integer; v_margin integer; v_ops public.print_order_operations;
begin
  if new.pricing_version is null or new.pricing_version not in ('PRINT_REDP_200_SOFT_V1','PRINT_REDP_MULTISIZE_V2','PRINT_REDP_COVERTYPE_V3') then return new; end if;
  if new.pricing_version='PRINT_REDP_COVERTYPE_V3' and right(new.print_product_snapshot->>'id',5)='_HARD'
    and new.print_fulfillment_status in ('RENDERING','REVIEW_REQUIRED','READY','SUBMITTED','ACCEPTED') then
    if new.print_spec_override is null then
      perform public.hardcover_review_geometry(new.print_product_snapshot->>'id',new.page_count);
    else
      if coalesce(new.print_spec_override->>'templateRevision','')='' then raise exception 'hardcover_template_required' using errcode='23514'; end if;
      perform public.validate_hardcover_geometry(new.print_spec_override->'coverGeometry');
    end if;
  end if;
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

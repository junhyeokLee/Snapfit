-- Planned retail prices for the two exact supplier quotations checked on 2026-10-13.
-- Keep the V3 product/geometry contract and every existing order snapshot frozen.
-- Production quotations do not certify delivery costs, file approval, or sales readiness.
create or replace function public.print_combo_pricing_policy(p_product_id text,p_pages integer)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_product jsonb;v_policy jsonb;
begin
  v_product:=public.print_product_policy(p_product_id);
  if p_pages is null or p_pages<20 or p_pages>80 or p_pages%2<>0 then
    raise exception 'invalid_print_page_count' using errcode='22023'; end if;
  v_policy:=jsonb_build_object(
    'version',v_product->>'version','productCode',p_product_id,'pageCount',p_pages,
    'amount',(v_product->>'basePrice')::integer+((p_pages-20)/2)*(v_product->>'pricePerTwoPages')::integer,
    'basePages',20,'basePrice',v_product->'basePrice','extraPageCount',p_pages-20,
    'extraPagePrice',(v_product->>'pricePerTwoPages')::integer/2,'pricePerTwoPages',v_product->'pricePerTwoPages',
    'pricePolicyVersion','PRINT_REDP_COVERTYPE_ESTIMATE_V3','retailPriceStatus','PENDING_SUPPLIER_QUOTE',
    'priceIsEstimate',true,'isEstimate',true,'supplierCostVerified',false,
    'shippingIncluded',true,'shippingCostVerified',false,'packagingCostVerified',false,
    'estimatedPrintCost',(v_product->>'estimatedBasePrintCost')::integer+((p_pages-20)/2)*(v_product->>'estimatedCostPerTwoPages')::integer,
    'estimatedShippingCost',7000,'estimatedPackagingCost',1500,
    'paymentFeeRate',0.04,'reprintReserveRate',0.05,'operationsReserve',3000,'minimumContribution',10000,
    'priceNotice','이 규격·페이지 조합의 제작 견적을 확인하는 중입니다. 견적 확인 후 판매가를 안내합니다.',
    'marginDefinition','수취액-실제제작/전체배송/포장비-결제수수료충당-재제작충당-운영충당3000원. 세금/잔여인건비/고정비 차감 전');
  if (p_product_id='REDP_200X150_SOFT' and p_pages=20) or (p_product_id='REDP_300_HARD' and p_pages=80) then
    v_policy:=v_policy||jsonb_build_object(
      'version','REDP_VERIFIED_COMBO_PLANNED_RETAIL_20261013_V1',
      'pricePolicyVersion','PRINT_REDP_VERIFIED_COMBO_20261013_V1','retailPriceStatus','PLANNED',
      'amount',case when p_pages=20 then 49900 else 159900 end,
      'basePages',p_pages,'basePrice',case when p_pages=20 then 49900 else 159900 end,
      'extraPageCount',0,'extraPagePrice',0,'pricePerTwoPages',0,
      'supplierCostVerified',true,'supplierQuoteDate','2026-10-13',
      'supplierOrderCode',case when p_pages=20 then 'C8E9DC97AA203186584' else 'C8E9D98C73536387071' end,
      'supplierSupplyPrice',case when p_pages=20 then 19300 else 92600 end,
      'supplierVat',case when p_pages=20 then 1930 else 9260 end,
      'estimatedPrintCost',case when p_pages=20 then 21230 else 101860 end,
      'estimatedShippingCost',3500,'estimatedPackagingCost',case when p_pages=20 then 0 else 1500 end,
      'shippingCostVerified',p_pages=20,'packagingCostVerified',p_pages=20,
      'isEstimate',p_pages<>20,'paymentFeeRate',0.05,
      'priceNotice',case when p_pages=20
        then '업체 제작 견적을 확인한 기본 배송 포함 예정 판매가입니다. 현재 주문·결제는 준비 중입니다.'
        else '업체 제작 견적을 반영한 기본 배송 포함 예정 판매가입니다. 배송·포장 비용은 최종 확인 후 확정되며 현재 주문·결제는 준비 중입니다.' end);
  end if;
  return v_policy;
end;
$$;
revoke all on function public.print_combo_pricing_policy(text,integer) from public,anon,authenticated;
grant execute on function public.print_combo_pricing_policy(text,integer) to service_role;

create or replace function public.get_print_order_quote(p_album_id bigint,p_page_count integer default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_album jsonb;v_product jsonb;v_policy jsonb;v_actual integer;v_legacy integer;v_pages integer;v_width integer;v_height integer;v_spine numeric;v_spec jsonb;v_cover jsonb;v_measured boolean;v_price jsonb;
begin
  if auth.uid() is null or not public.can_access_album(p_album_id) then raise exception 'album_access_denied' using errcode='42501'; end if;
  select to_jsonb(a) into strict v_album from public.albums a where id=p_album_id;
  v_product:=public.resolve_album_print_product(v_album);
  v_policy:=public.print_product_policy(v_product->>'id');
  select count(*)::integer into v_legacy from public.album_pages where album_id=p_album_id;
  v_actual:=public.print_source_page_count(v_album,v_legacy);
  v_pages:=((greatest(20,v_actual,coalesce(p_page_count,0))+1)/2)*2;
  if p_page_count<0 or v_pages>80 then raise exception 'invalid_page_count' using errcode='22023'; end if;
  v_price:=public.print_combo_pricing_policy(v_product->>'id',v_pages);
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
  return jsonb_build_object('pageCount',v_pages,'amount',v_price->'amount',
    'basePages',v_price->'basePages','basePrice',v_price->'basePrice','extraPageCount',v_price->'extraPageCount','extraPagePrice',v_price->'extraPagePrice',
    'pricePerTwoPages',v_price->'pricePerTwoPages','sourcePageCount',v_actual,'addedBlankPageCount',v_pages-v_actual,
    'productCode',v_product->>'id','productName',v_policy->>'productName','printProduct',v_product,'coverType',v_policy->>'coverType','coverLabel',v_policy->>'coverLabel',
    'trimWidthMm',v_width,'trimHeightMm',v_height,'shippingIncluded',true,'maxPages',80,'layoutFit','contain',
    'pricingVersion','PRINT_REDP_COVERTYPE_V3','pricePolicyVersion',v_price->'pricePolicyVersion','retailPriceStatus',v_price->'retailPriceStatus',
    'priceIsEstimate',v_price->'priceIsEstimate','supplierCostVerified',v_price->'supplierCostVerified',
    'shippingCostVerified',v_price->'shippingCostVerified','packagingCostVerified',v_price->'packagingCostVerified',
    'specMissing',v_spec is null,'printPdfAvailable',v_spec is not null,'printTemplateStatus',case when v_spec is null then 'REQUIRES_VENDOR_TEMPLATE' else 'REVIEW_REQUIRED' end,
    'priceNotice',v_price->'priceNotice','spec',v_spec);
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
  v_product:=v_quote->'printProduct';v_policy:=public.print_combo_pricing_policy(v_product->>'id',(v_quote->>'pageCount')::integer);
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
    v_policy-array['amount','basePages','basePrice','extraPageCount','extraPagePrice','pricePerTwoPages','priceIsEstimate',
      'priceNotice','pricePolicyVersion','retailPriceStatus','shippingIncluded']);
  return to_jsonb(v_order);
end;
$$;
revoke all on function public.create_print_order(bigint,integer,integer,text,text,text,text,text,text,text) from public,anon,authenticated,service_role;


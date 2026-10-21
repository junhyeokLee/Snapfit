-- Confirmed one-copy supplier observations inform planned retail, never sales activation.
-- Public order quotation/specification functions and all checkout gates stay unchanged.
create schema if not exists private;
create table private.print_supplier_quotes (
  product_id text not null check (product_id in (
    'REDP_200X150_SOFT','REDP_200_SOFT','REDP_250X200_SOFT','REDP_250_SOFT','REDP_300_SOFT',
    'REDP_200X150_HARD','REDP_200_HARD','REDP_250X200_HARD','REDP_250_HARD','REDP_300_HARD')),
  page_count integer not null check (page_count between 20 and 80 and page_count % 2 = 0),
  quantity integer not null default 1 check (quantity = 1),
  currency text not null default 'KRW' check (currency = 'KRW'),
  supply_price integer not null check (supply_price between 0 and 100000000),
  vat_price integer not null check (vat_price between 0 and 100000000),
  total_price integer not null check (total_price between 1 and 100000000),
  source text not null check (source in ('WEBSITE','API')),
  observed_at timestamptz not null check (isfinite(observed_at) and observed_at<=clock_timestamp()+interval '5 minutes'),
  evidence text not null check (length(btrim(evidence)) between 10 and 5000),
  options jsonb not null check (
    jsonb_typeof(options) = 'object'
    and options ?& array['coverPaper','coverFinish','interiorPaper','interiorPrint']
    and jsonb_typeof(options->'coverPaper') = 'string' and length(btrim(options->>'coverPaper')) > 0
    and jsonb_typeof(options->'coverFinish') = 'string' and length(btrim(options->>'coverFinish')) > 0
    and jsonb_typeof(options->'interiorPaper') = 'string' and length(btrim(options->>'interiorPaper')) > 0
    and jsonb_typeof(options->'interiorPrint') = 'string' and length(btrim(options->>'interiorPrint')) > 0),
  confirmed boolean not null default false,
  primary key (product_id,page_count,quantity),
  check (supply_price + vat_price = total_price)
);
alter table private.print_supplier_quotes enable row level security;
revoke all on private.print_supplier_quotes from public,anon,authenticated,service_role;
grant usage on schema private to service_role;
grant select,insert,update,delete on private.print_supplier_quotes to service_role;
comment on table private.print_supplier_quotes is
  'Private manufacture-only quotes for exact product/page/qty=1/options. Website evidence is not API-code, shipping, sample, contract or production approval.';

-- The existing admin saveMapping flow obtains price with qty=1, verifies the
-- vendor code, and requires human confirmation of the entire exact option set.
-- Only that verified observation can update a quote. Description/note evidence
-- must also identify this fixed PHBKMYB stock/finish/duplex contract; missing or
-- contradictory option evidence is skipped rather than guessed.
create function private.sync_print_supplier_quote_from_mapping()
returns trigger language plpgsql security invoker set search_path='' as $$
declare code public.redprinting_dev_codes;s bigint;v bigint;t bigint;description text;note text;hard boolean;
begin
  if new.order_code is null or new.exact_match_confirmed is not true or new.vendor_use_yn<>'Y'
    or new.vendor_order_yn<>'Y' or new.verified_at is null or not isfinite(new.verified_at)
    or new.verified_at>clock_timestamp()+interval '5 minutes' then return null;end if;
  select * into code from public.redprinting_dev_codes where order_code=new.order_code;
  if not found or code.use_yn<>'Y' or new.price_snapshot->>'orderYn' is distinct from 'Y'
    or coalesce(new.price_snapshot->>'totalPrice','')!~'^[0-9]{1,9}$'
    or coalesce(new.price_snapshot->>'supplyPrice','')!~'^[0-9]{1,9}$'
    or coalesce(new.price_snapshot->>'vatPrice','')!~'^[0-9]{1,9}$'
    or (new.price_snapshot?'qty' and new.price_snapshot->>'qty' is distinct from '1') then return null;end if;
  s:=(new.price_snapshot->>'supplyPrice')::bigint;v:=(new.price_snapshot->>'vatPrice')::bigint;t:=(new.price_snapshot->>'totalPrice')::bigint;
  if t<=0 or t>100000000 or s+v<>t then return null;end if;
  description:=regexp_replace(lower(coalesce(nullif(new.detail_snapshot->>'goodsDesc',''),nullif(new.detail_snapshot->>'goods_desc',''),code.goods_desc,'')),'[^a-z0-9가-힣]','','g');
  note:=regexp_replace(lower(new.note),'[^a-z0-9가-힣]','','g');
  hard:=new.product_id like '%_HARD';
  if (hard and (description!~'(하드커버|hardcover)' or description!~'(스노우지?180g|snow180g)' or description~'(소프트커버|softcover)'))
    or (not hard and (description!~'(소프트커버|softcover)' or description!~'(아트지?300g|art300g)' or description~'(하드커버|hardcover)'))
    or description!~'(무광코팅단면|단면무광코팅|무광단면|단면무광)'
    or note!~'glossy' or note!~'285g' or note!~'양면'
    or note!~('내지'||new.page_count::text||'(쪽|페이지|p)') then return null;end if;
  insert into private.print_supplier_quotes as current_quote(product_id,page_count,quantity,currency,supply_price,vat_price,total_price,source,observed_at,evidence,options,confirmed)
  values(new.product_id,new.page_count,1,'KRW',s,v,t,'API',new.verified_at,
    'Verified /v1/code/price qty=1; exact full-option mapping; order_code='||new.order_code,
    jsonb_build_object('coverPaper',case when hard then '스노우지 180g' else '아트지 300g' end,
      'coverFinish','단면 무광코팅','interiorPaper','Glossy Canon 285g','interiorPrint','양면',
      'optionContract','PHBKMYB_GLOSSY285_MATTE_DUPLEX_V1'),true)
  on conflict(product_id,page_count,quantity) do update set
    supply_price=excluded.supply_price,vat_price=excluded.vat_price,total_price=excluded.total_price,
    source=excluded.source,observed_at=excluded.observed_at,evidence=excluded.evidence,options=excluded.options,confirmed=true
  where current_quote.observed_at<excluded.observed_at;
  return null;
end;
$$;
revoke all on function private.sync_print_supplier_quote_from_mapping() from public,anon,authenticated;
grant execute on function private.sync_print_supplier_quote_from_mapping() to service_role;
create trigger redprinting_mapping_sync_supplier_quote
  after insert or update of order_code,exact_match_confirmed,vendor_use_yn,vendor_order_yn,detail_snapshot,price_snapshot,note,verified_at
  on public.redprinting_dev_mappings for each row execute function private.sync_print_supplier_quote_from_mapping();

-- Minimum contribution is an estimate before tax, fixed overhead and advertising.
-- Each reserve is ceil(retail * 5%). Choose the first 9,900-ending 10,000-won tier
-- satisfying both contribution >= 10,000 and contribution >= 20% of retail.
create function private.print_quote_retail_budget(p_print_cost bigint,p_shipping_budget bigint,p_packaging_budget bigint)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare fixed numeric;lower_bound numeric;retail numeric;fee numeric;reserve numeric;contribution numeric;
begin
  if p_print_cost is null or p_print_cost not between 1 and 100000000
    or p_shipping_budget is null or p_shipping_budget not between 0 and 10000000
    or p_packaging_budget is null or p_packaging_budget not between 0 and 10000000 then
    raise exception 'invalid_print_quote_cost' using errcode='22023';
  end if;
  fixed:=p_print_cost::numeric+p_shipping_budget+p_packaging_budget+3000;
  -- Rational numeric arithmetic avoids integer division and binary float rounding.
  lower_bound:=greatest(ceil((fixed+10000)*10/9),ceil(fixed*10/7));
  retail:=greatest(9900,ceil((lower_bound+100)/10000)*10000-100);
  loop
    fee:=ceil(retail/20);reserve:=ceil(retail/20);
    contribution:=retail-fixed-fee-reserve;
    exit when contribution>=10000 and contribution*5>=retail;
    retail:=retail+10000;
  end loop;
  return jsonb_build_object('amount',retail::integer,'estimatedContribution',contribution::integer,
    'paymentFeeReserve',fee::integer,'reprintReserve',reserve::integer,
    'paymentFeeRate',0.05,'reprintReserveRate',0.05,'operationsReserve',3000,
    'minimumContribution',10000,'minimumContributionRate',0.20,'retailRounding','NEXT_9900_TIER');
end;
$$;
revoke all on function private.print_quote_retail_budget(bigint,bigint,bigint) from public,anon,authenticated;
grant execute on function private.print_quote_retail_budget(bigint,bigint,bigint) to service_role;

-- Preserve the old two reviewed prices and every unknown estimate when there is
-- no confirmed exact observation. Their snapshots and customer visibility stay frozen.
create function private.print_legacy_combo_pricing_policy(p_product_id text,p_pages integer)
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
revoke all on function private.print_legacy_combo_pricing_policy(text,integer) from public,anon,authenticated;
grant execute on function private.print_legacy_combo_pricing_policy(text,integer) to service_role;

-- Financial confirmation can be displayed while operational sales remain closed.
-- DRAFT, malformed costs and partially confirmed financial rows cannot be FINAL.
create function private.print_financial_price_valid(c private.print_sales_combinations)
returns boolean language plpgsql immutable security invoker set search_path='' as $$
declare cost jsonb;k text;v numeric;fee numeric;reserve numeric;contribution numeric;
begin
  if c.product_id is null or c.final_price is null or c.final_price<=0
    or not (c.retail_final and c.supplier_cost_confirmed and c.shipping_confirmed and c.packaging_confirmed)
    or c.price_version!~'^[A-Za-z0-9_.-]{1,120}$' or c.price_version like 'DRAFT%' or c.order_code!~'^[A-Za-z0-9_-]{1,100}$'
    or length(btrim(c.approval_evidence))<10 then return false;end if;
  cost:=c.cost_snapshot;
  if cost is null or jsonb_typeof(cost)<>'object'
    or (cost?'draftOnly' and cost->'draftOnly' is distinct from 'false'::jsonb) then return false;end if;
  foreach k in array array['estimatedPrintCost','estimatedShippingCost','estimatedPackagingCost','operationsReserve','minimumContribution'] loop
    if jsonb_typeof(cost->k) is distinct from 'number' then return false;end if;
    v:=(cost->>k)::numeric;
    if v<>trunc(v) or v<0 or v>2147483647 then return false;end if;
  end loop;
  if (cost->>'estimatedPrintCost')::numeric<=0 or (cost->>'operationsReserve')::numeric<3000
    or (cost->>'minimumContribution')::numeric<10000 then return false;end if;
  foreach k in array array['paymentFeeRate','reprintReserveRate'] loop
    if jsonb_typeof(cost->k) is distinct from 'number' then return false;end if;
    v:=(cost->>k)::numeric;if v<0 or v>=1 then return false;end if;
  end loop;
  fee:=ceil(c.final_price*(cost->>'paymentFeeRate')::numeric);
  reserve:=ceil(c.final_price*(cost->>'reprintReserveRate')::numeric);
  contribution:=c.final_price-(cost->>'estimatedPrintCost')::numeric-(cost->>'estimatedShippingCost')::numeric
    -(cost->>'estimatedPackagingCost')::numeric-fee-reserve-(cost->>'operationsReserve')::numeric;
  return contribution>=(cost->>'minimumContribution')::numeric;
end;
$$;
revoke all on function private.print_financial_price_valid(private.print_sales_combinations) from public,anon,authenticated;
grant execute on function private.print_financial_price_valid(private.print_sales_combinations) to service_role;

create or replace function public.print_combo_pricing_policy(p_product_id text,p_pages integer)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare policy jsonb;quote private.print_supplier_quotes;final_row private.print_sales_combinations;
  cost jsonb;budget jsonb;shipping integer:=3500;packaging integer;revision text;
begin
  -- Validates product and pages, and preserves all legacy fallback fields.
  policy:=private.print_legacy_combo_pricing_policy(p_product_id,p_pages);
  select * into final_row from private.print_sales_combinations
    where product_id=p_product_id and page_count=p_pages;
  if found and private.print_financial_price_valid(final_row) then
    cost:=final_row.cost_snapshot;
    return policy||cost||jsonb_build_object(
      'productCode',p_product_id,'pageCount',p_pages,'version',final_row.price_version,'pricePolicyVersion',final_row.price_version,'retailPriceStatus','FINAL',
      'amount',final_row.final_price,'basePages',p_pages,'basePrice',final_row.final_price,
      'extraPageCount',0,'extraPagePrice',0,'pricePerTwoPages',0,
      'supplierOrderCode',final_row.order_code,'supplierCostVerified',true,'shippingCostVerified',true,'packagingCostVerified',true,
      'priceIsEstimate',false,'isEstimate',false,'shippingIncluded',true,
      'priceNotice','기본 배송비가 포함된 확정 판매가입니다. 결제·제작 가능 여부는 별도 운영 준비 상태에 따릅니다.');
  end if;
  select * into quote from private.print_supplier_quotes
    where product_id=p_product_id and page_count=p_pages and quantity=1 and confirmed=true;
  if not found then return policy;end if;
  packaging:=case when p_product_id like '%_HARD' then 1500 else 0 end;
  budget:=private.print_quote_retail_budget(quote.total_price,shipping,packaging);
  revision:=upper(substr(md5(jsonb_build_object('product',p_product_id,'pages',p_pages,'quantity',quote.quantity,
    'source',quote.source,'observedAt',quote.observed_at at time zone 'UTC','supply',quote.supply_price,'vat',quote.vat_price,
    'total',quote.total_price,'options',quote.options,'budget',budget)::text),1,16));
  return policy||budget||jsonb_build_object(
    'version','REDP_SUPPLIER_QUOTE_RETAIL_20261019_V1',
    'pricePolicyVersion','PRINT_REDP_SUPPLIER_MATRIX_V1_'||revision,'retailPriceStatus','PLANNED',
    'amount',budget->'amount','basePages',p_pages,'basePrice',budget->'amount',
    'extraPageCount',0,'extraPagePrice',0,'pricePerTwoPages',0,
    'supplierCostVerified',true,'supplierQuoteDate',(quote.observed_at at time zone 'Asia/Seoul')::date,
    'supplierQuoteSource',quote.source,'supplierQuoteQuantity',quote.quantity,
    'supplierSupplyPrice',quote.supply_price,'supplierVat',quote.vat_price,'estimatedPrintCost',quote.total_price,
    'estimatedShippingCost',shipping,'estimatedPackagingCost',packaging,
    -- A manufacture observation cannot confirm shipping, packaging or PG fees.
    -- The exact legacy softcover's already reviewed delivery evidence survives.
    'shippingCostVerified',coalesce((policy->>'shippingCostVerified')::boolean,false),
    'packagingCostVerified',coalesce((policy->>'packagingCostVerified')::boolean,false),
    'paymentFeeConfirmed',false,'priceIsEstimate',true,'isEstimate',true,'shippingIncluded',true,
    'marginDefinition','판매가-부가세포함제작비-배송/포장예산-결제수수료5%충당-재제작5%충당-운영3000원. 세금/고정비/광고비 차감 전 예상 기여금',
    'priceNotice','확인한 제작비와 배송·포장·결제수수료·재제작·운영 예산을 반영한 예정 판매가입니다. 실제 결제는 준비 중입니다.');
end;
$$;
revoke all on function public.print_combo_pricing_policy(text,integer) from public,anon,authenticated;
grant execute on function public.print_combo_pricing_policy(text,integer) to service_role;

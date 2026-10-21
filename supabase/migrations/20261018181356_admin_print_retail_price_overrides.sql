-- Admin changes adjust planned customer quotation only. No sales/production flags change.
create table private.print_retail_price_overrides (
  product_id text not null,
  page_count integer not null,
  quantity integer not null default 1 check(quantity=1),
  version uuid not null default gen_random_uuid(),
  source_revision text not null check(source_revision~'^[a-f0-9]{64}$'),
  retail_price integer not null check(retail_price between 1 and 100000000),
  shipping_budget integer not null check(shipping_budget between 0 and 10000000),
  packaging_budget integer not null check(packaging_budget between 0 and 10000000),
  note text not null check(length(btrim(note)) between 1 and 1000),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  primary key(product_id,page_count,quantity),
  foreign key(product_id,page_count,quantity) references private.print_supplier_quotes(product_id,page_count,quantity)
);
alter table private.print_retail_price_overrides enable row level security;
revoke all on private.print_retail_price_overrides from public,anon,authenticated,service_role;
grant select on private.print_retail_price_overrides to service_role;

-- A reset has its own generation, so returning to a recommended amount cannot
-- revive a stale pre-edit expected price version (ABA protection).
create table private.print_retail_price_revisions (
  product_id text not null,
  page_count integer not null,
  quantity integer not null default 1 check(quantity=1),
  version uuid not null default gen_random_uuid(),
  primary key(product_id,page_count,quantity),
  foreign key(product_id,page_count,quantity) references private.print_supplier_quotes(product_id,page_count,quantity)
);
alter table private.print_retail_price_revisions enable row level security;
revoke all on private.print_retail_price_revisions from public,anon,authenticated,service_role;
grant select on private.print_retail_price_revisions to service_role;

create table private.print_retail_price_audit (
  id uuid primary key default gen_random_uuid(),
  product_id text not null,
  page_count integer not null,
  action text not null check(action in ('SAVE','RESET')),
  actor_id uuid not null,
  source_revision text not null,
  expected_price_version text not null,
  note text not null check(length(btrim(note)) between 1 and 1000),
  before_record jsonb,
  after_record jsonb,
  created_at timestamptz not null default clock_timestamp()
);
alter table private.print_retail_price_audit enable row level security;
revoke all on private.print_retail_price_audit from public,anon,authenticated,service_role;
grant select on private.print_retail_price_audit to service_role;
create function private.reject_print_retail_audit_mutation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin raise exception 'print_pricing_audit_immutable' using errcode='42501';end;$$;
revoke all on function private.reject_print_retail_audit_mutation() from public,anon,authenticated,service_role;
create trigger print_retail_audit_immutable before update or delete on private.print_retail_price_audit
for each row execute function private.reject_print_retail_audit_mutation();

create function private.assert_print_pricing_actor(p_actor_id uuid)
returns void language plpgsql stable security invoker set search_path='' as $$
begin
  if p_actor_id is null or not exists(select 1 from auth.users where id=p_actor_id and raw_app_meta_data->>'role'='admin') then
    raise exception 'forbidden' using errcode='42501';
  end if;
end;$$;
revoke all on function private.assert_print_pricing_actor(uuid) from public,anon,authenticated,service_role;

create function private.print_supplier_quote_revision(q private.print_supplier_quotes)
returns text language sql immutable security invoker set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('product',q.product_id,'pages',q.page_count,'quantity',q.quantity,
   'currency',q.currency,'source',q.source,'observedAt',q.observed_at at time zone 'UTC','supply',q.supply_price,
   'vat',q.vat_price,'total',q.total_price,'options',q.options,'confirmed',q.confirmed)::text,'UTF8')),'hex')
$$;
revoke all on function private.print_supplier_quote_revision(private.print_supplier_quotes) from public,anon,authenticated;
grant execute on function private.print_supplier_quote_revision(private.print_supplier_quotes) to service_role;

create function private.print_retail_estimate(p_retail integer,p_cost integer,p_shipping integer,p_packaging integer)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare fee integer;contribution integer;
begin
  if p_retail is null or p_retail not between 1 and 100000000 or p_cost is null or p_cost not between 1 and 100000000
    or p_shipping is null or p_shipping not between 0 and 10000000 or p_packaging is null or p_packaging not between 0 and 10000000 then
    raise exception 'invalid_print_pricing' using errcode='22023';end if;
  fee:=ceil(p_retail::numeric/20)::integer;
  contribution:=p_retail-p_cost-p_shipping-p_packaging-2*fee-3000;
  return jsonb_build_object('retailPrice',p_retail,'shippingBudget',p_shipping,'packagingBudget',p_packaging,
    'paymentFeeReserve',fee,'reprintReserve',fee,'operationsReserve',3000,'estimatedContribution',contribution,
    'contributionRate',contribution::numeric/p_retail);
end;$$;
revoke all on function private.print_retail_estimate(integer,integer,integer,integer) from public,anon,authenticated;
grant execute on function private.print_retail_estimate(integer,integer,integer,integer) to service_role;

-- Preserve existing FINAL validation and exact-source default policy.
create function private.print_supplier_matrix_pricing_policy(p_product_id text,p_pages integer)
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
revoke all on function private.print_supplier_matrix_pricing_policy(text,integer) from public,anon,authenticated;
grant execute on function private.print_supplier_matrix_pricing_policy(text,integer) to service_role;

create or replace function public.print_combo_pricing_policy(p_product_id text,p_pages integer)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare policy jsonb;q private.print_supplier_quotes;o private.print_retail_price_overrides;metrics jsonb;generation uuid;
begin
  policy:=private.print_supplier_matrix_pricing_policy(p_product_id,p_pages);
  if policy->>'retailPriceStatus'<>'PLANNED' then return policy;end if;
  select * into q from private.print_supplier_quotes where product_id=p_product_id and page_count=p_pages and quantity=1 and confirmed;
  if not found then return policy;end if;
  select version into generation from private.print_retail_price_revisions where product_id=p_product_id and page_count=p_pages and quantity=1;
  if found then policy:=policy||jsonb_build_object('pricePolicyVersion','PRINT_RETAIL_RECOMMENDED_V1_'||replace(generation::text,'-','')||'_'||right(policy->>'pricePolicyVersion',16));end if;
  select * into o from private.print_retail_price_overrides where product_id=p_product_id and page_count=p_pages and quantity=1;
  if not found or o.source_revision<>private.print_supplier_quote_revision(q) then return policy;end if;
  metrics:=private.print_retail_estimate(o.retail_price,q.total_price,o.shipping_budget,o.packaging_budget);
  -- A corrupt/old low-margin record cannot replace a valid recommended quotation.
  if (metrics->>'estimatedContribution')::integer<10000 or (metrics->>'estimatedContribution')::numeric*5<o.retail_price then return policy;end if;
  return policy||metrics||jsonb_build_object(
    'amount',o.retail_price,'basePrice',o.retail_price,'estimatedShippingCost',o.shipping_budget,'estimatedPackagingCost',o.packaging_budget,
    'pricePolicyVersion','PRINT_RETAIL_OVERRIDE_V1_'||replace(o.version::text,'-',''),
    'version','REDP_ADMIN_PLANNED_RETAIL_V1','retailPriceStatus','PLANNED','priceIsEstimate',true,'isEstimate',true,
    'shippingCostVerified',false,'packagingCostVerified',false,'paymentFeeConfirmed',false,
    'priceNotice','확인한 제작비와 배송·포장·결제수수료·재제작·운영 예산을 반영한 예정 판매가입니다. 실제 결제는 준비 중입니다.');
end;$$;
revoke all on function public.print_combo_pricing_policy(text,integer) from public,anon,authenticated;
grant execute on function public.print_combo_pricing_policy(text,integer) to service_role;

create function private.print_pricing_admin_row(p_product_id text,p_page_count integer)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare q private.print_supplier_quotes;o private.print_retail_price_overrides;recommended jsonb;effective jsonb;policy jsonb;
  source_revision text;shipping integer:=3500;packaging integer;override_json jsonb:=null;product jsonb;
begin
  select * into q from private.print_supplier_quotes where product_id=p_product_id and page_count=p_page_count and quantity=1 and confirmed;
  if not found then raise exception 'print_pricing_source_unavailable' using errcode='P0002';end if;
  source_revision:=private.print_supplier_quote_revision(q);
  product:=public.print_product_policy(p_product_id);
  packaging:=case when p_product_id like '%_HARD' then 1500 else 0 end;
  recommended:=private.print_quote_retail_budget(q.total_price,shipping,packaging);
  recommended:=private.print_retail_estimate((recommended->>'amount')::integer,q.total_price,shipping,packaging);
  policy:=public.print_combo_pricing_policy(p_product_id,p_page_count);
  effective:=private.print_retail_estimate((policy->>'amount')::integer,q.total_price,
    (policy->>'estimatedShippingCost')::integer,(policy->>'estimatedPackagingCost')::integer)||jsonb_build_object(
    'priceVersion',policy->>'pricePolicyVersion','retailPriceStatus',policy->>'retailPriceStatus');
  -- FINAL records may have explicitly approved fee/reserve budgets different from the planning defaults.
  if policy->>'retailPriceStatus'='FINAL' then
    effective:=effective||jsonb_build_object('paymentFeeReserve',ceil((policy->>'amount')::numeric*(policy->>'paymentFeeRate')::numeric)::integer,
      'reprintReserve',ceil((policy->>'amount')::numeric*(policy->>'reprintReserveRate')::numeric)::integer,
      'operationsReserve',(policy->>'operationsReserve')::integer,
      'estimatedContribution',(policy->>'amount')::integer-(policy->>'estimatedPrintCost')::integer-(policy->>'estimatedShippingCost')::integer
       -(policy->>'estimatedPackagingCost')::integer-ceil((policy->>'amount')::numeric*(policy->>'paymentFeeRate')::numeric)::integer
       -ceil((policy->>'amount')::numeric*(policy->>'reprintReserveRate')::numeric)::integer-(policy->>'operationsReserve')::integer);
    effective:=effective||jsonb_build_object('contributionRate',(effective->>'estimatedContribution')::numeric/(policy->>'amount')::numeric);
  end if;
  select * into o from private.print_retail_price_overrides where product_id=p_product_id and page_count=p_page_count and quantity=1;
  if found then override_json:=jsonb_build_object('version',o.version,'sourceRevision',o.source_revision,
    'retailPrice',o.retail_price,'shippingBudget',o.shipping_budget,'packagingBudget',o.packaging_budget,
    'note',o.note,'updatedAt',o.updated_at,'updatedBy',o.updated_by,'stale',o.source_revision<>source_revision);end if;
  return jsonb_build_object('productId',p_product_id,'productName',product->>'productName','pageCount',p_page_count,
    'coverType',case when p_product_id like '%_HARD' then 'HARD' else 'SOFT' end,
    'source',jsonb_build_object('revision',source_revision,'supplyPrice',q.supply_price,'vatPrice',q.vat_price,'totalPrice',q.total_price,
      'currency',q.currency,'source',q.source,'observedAt',q.observed_at,'evidence',q.evidence,'options',q.options),
    'recommended',recommended,'effective',effective,'override',override_json,'locked',policy->>'retailPriceStatus'='FINAL');
end;$$;
revoke all on function private.print_pricing_admin_row(text,integer) from public,anon,authenticated,service_role;

create function public.read_print_pricing_admin(p_actor_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare rows jsonb;
begin
  perform private.assert_print_pricing_actor(p_actor_id);
  select coalesce(jsonb_agg(private.print_pricing_admin_row(q.product_id,q.page_count) order by q.product_id,q.page_count),'[]'::jsonb) into rows
    from private.print_supplier_quotes q where q.confirmed and q.quantity=1;
  return rows;
end;$$;
revoke all on function public.read_print_pricing_admin(uuid) from public,anon,authenticated;
grant execute on function public.read_print_pricing_admin(uuid) to service_role;

create function public.mutate_print_pricing_admin(p_actor_id uuid,p_action text,p_product_id text,p_page_count integer,
 p_source_revision text,p_expected_price_version text,p_retail_price integer,p_shipping_budget integer,p_packaging_budget integer,p_note text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare q private.print_supplier_quotes;before_override private.print_retail_price_overrides;after_override private.print_retail_price_overrides;
  current_policy jsonb;metrics jsonb;source_revision text;previous_json jsonb;next_json jsonb;
begin
  perform private.assert_print_pricing_actor(p_actor_id);
  if p_action is null or p_action not in ('save','reset') or p_source_revision is null or p_source_revision!~'^[a-f0-9]{64}$'
    or p_expected_price_version is null or p_expected_price_version!~'^[A-Za-z0-9_.-]{1,120}$'
    or p_note is null or length(btrim(p_note)) not between 1 and 1000 then
    raise exception 'invalid_print_pricing' using errcode='22023';end if;
  -- Serializes different admin edits and supplier refreshes for this exact observation.
  select * into q from private.print_supplier_quotes where product_id=p_product_id and page_count=p_page_count and quantity=1 and confirmed for update;
  if not found then raise exception 'print_pricing_source_unavailable' using errcode='P0002';end if;
  perform 1 from private.print_sales_combinations where product_id=p_product_id and page_count=p_page_count for update;
  current_policy:=public.print_combo_pricing_policy(p_product_id,p_page_count);
  if current_policy->>'retailPriceStatus'='FINAL' then raise exception 'print_pricing_locked' using errcode='23514';end if;
  source_revision:=private.print_supplier_quote_revision(q);
  if p_source_revision<>source_revision then raise exception 'print_pricing_source_changed' using errcode='23514';end if;
  if p_expected_price_version<>current_policy->>'pricePolicyVersion' then raise exception 'print_pricing_conflict' using errcode='23514';end if;
  select * into before_override from private.print_retail_price_overrides where product_id=p_product_id and page_count=p_page_count and quantity=1 for update;
  previous_json:=case when found then to_jsonb(before_override) else null end;
  if p_action='save' then
    metrics:=private.print_retail_estimate(p_retail_price,q.total_price,p_shipping_budget,p_packaging_budget);
    if (metrics->>'estimatedContribution')::integer<10000 or (metrics->>'estimatedContribution')::numeric*5<p_retail_price then
      raise exception 'print_pricing_margin_too_low' using errcode='22023';end if;
    insert into private.print_retail_price_overrides as current_override(product_id,page_count,quantity,version,source_revision,retail_price,shipping_budget,packaging_budget,note,updated_by,updated_at)
    values(p_product_id,p_page_count,1,gen_random_uuid(),source_revision,p_retail_price,p_shipping_budget,p_packaging_budget,btrim(p_note),p_actor_id,clock_timestamp())
    on conflict(product_id,page_count,quantity) do update set version=excluded.version,source_revision=excluded.source_revision,retail_price=excluded.retail_price,
      shipping_budget=excluded.shipping_budget,packaging_budget=excluded.packaging_budget,note=excluded.note,updated_by=excluded.updated_by,updated_at=excluded.updated_at
    returning * into after_override;
    next_json:=to_jsonb(after_override);
  else
    if p_retail_price is not null or p_shipping_budget is not null or p_packaging_budget is not null then raise exception 'invalid_print_pricing' using errcode='22023';end if;
    delete from private.print_retail_price_overrides where product_id=p_product_id and page_count=p_page_count and quantity=1;
    next_json:=null;
  end if;
  insert into private.print_retail_price_revisions(product_id,page_count,quantity,version) values(p_product_id,p_page_count,1,gen_random_uuid())
    on conflict(product_id,page_count,quantity) do update set version=excluded.version;
  insert into private.print_retail_price_audit(product_id,page_count,action,actor_id,source_revision,expected_price_version,note,before_record,after_record)
    values(p_product_id,p_page_count,upper(p_action),p_actor_id,source_revision,p_expected_price_version,btrim(p_note),previous_json,next_json);
  return private.print_pricing_admin_row(p_product_id,p_page_count);
end;$$;
revoke all on function public.mutate_print_pricing_admin(uuid,text,text,integer,text,text,integer,integer,integer,text) from public,anon,authenticated;
grant execute on function public.mutate_print_pricing_admin(uuid,text,text,integer,text,text,integer,integer,integer,text) to service_role;

comment on table private.print_retail_price_overrides is 'Admin-reviewed planned retail and budget overrides; exact supplier revision required. No payment/sales approvals.';
comment on table private.print_retail_price_audit is 'Append-only admin price change history; source revisions and before/after values. No production activation.';

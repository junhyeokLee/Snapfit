-- Staged bookkeeping only. An approved development code is not commercial
-- production approval. No credentials/configuration/real orders are writable.
alter table private.print_sales_combinations add column draft_version uuid;
alter table private.print_sales_combinations add column draft_source_revision text;
alter table private.print_sales_combinations add column draft_note text not null default '';
alter table private.print_sales_combinations add column draft_updated_at timestamptz;

create function private.print_sales_draft_source_revision(m public.redprinting_dev_mappings,c public.redprinting_dev_codes)
returns text language sql immutable security invoker set search_path='' as $$
 select encode(sha256(convert_to(jsonb_build_object('product',m.product_id,'pages',m.page_count,'orderCode',m.order_code,
   'matched',m.exact_match_confirmed,'use',m.vendor_use_yn,'order',m.vendor_order_yn,'price',m.price_snapshot,
   'verifiedAt',m.verified_at,'updatedAt',m.updated_at,'codeUse',c.use_yn)::text,'UTF8')),'hex')
$$;
create function private.print_sales_draft_source_valid(m public.redprinting_dev_mappings,c public.redprinting_dev_codes)
returns boolean language plpgsql immutable security invoker set search_path='' as $$
declare v bigint;s bigint;t bigint;
begin
 if m.order_code is null or m.order_code is distinct from c.order_code or m.exact_match_confirmed is not true or m.vendor_use_yn<>'Y'
   or m.vendor_order_yn<>'Y' or c.use_yn<>'Y' or m.verified_at is null or m.price_snapshot->>'orderYn' is distinct from 'Y'
   or coalesce(m.price_snapshot->>'totalPrice','')!~'^[0-9]{1,9}$' or coalesce(m.price_snapshot->>'supplyPrice','')!~'^[0-9]{1,9}$'
   or coalesce(m.price_snapshot->>'vatPrice','')!~'^[0-9]{1,9}$' or(m.price_snapshot?'qty' and m.price_snapshot->>'qty' is distinct from '1') then return false;end if;
 t:=(m.price_snapshot->>'totalPrice')::bigint;s:=(m.price_snapshot->>'supplyPrice')::bigint;v:=(m.price_snapshot->>'vatPrice')::bigint;
 return t>0 and t<=100000000 and s+v=t;
end;$$;
create function private.print_sales_draft_json(c private.print_sales_combinations) returns jsonb language sql stable security invoker set search_path='' as $$
 select case when c.draft_version is null then null else jsonb_build_object('version',c.draft_version,'retailPrice',c.final_price,
   'shippingBudget',c.cost_snapshot->'estimatedShippingCost','packagingBudget',c.cost_snapshot->'estimatedPackagingCost',
   'estimatedContribution',c.final_price-(c.cost_snapshot->>'estimatedPrintCost')::integer-(c.cost_snapshot->>'estimatedShippingCost')::integer
     -(c.cost_snapshot->>'estimatedPackagingCost')::integer-2*((c.final_price+19)/20)-3000,
   'note',c.draft_note,'sourceRevision',c.draft_source_revision,'updatedAt',c.draft_updated_at) end
$$;
revoke all on function private.print_sales_draft_source_revision(public.redprinting_dev_mappings,public.redprinting_dev_codes),
 private.print_sales_draft_source_valid(public.redprinting_dev_mappings,public.redprinting_dev_codes),private.print_sales_draft_json(private.print_sales_combinations) from public,anon,authenticated;
grant execute on function private.print_sales_draft_source_revision(public.redprinting_dev_mappings,public.redprinting_dev_codes),
 private.print_sales_draft_source_valid(public.redprinting_dev_mappings,public.redprinting_dev_codes),private.print_sales_draft_json(private.print_sales_combinations) to service_role;

create function public.read_print_sales_draft_candidates() returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(x.row),'[]'::jsonb) from (
   select jsonb_build_object('productId',m.product_id,'pageCount',m.page_count,'observedPrintCost',(m.price_snapshot->>'totalPrice')::integer,
     'observedAt',m.verified_at,'sourceRevision',private.print_sales_draft_source_revision(m,code),
     'locked',coalesce(c.retail_final or c.supplier_cost_confirmed or c.shipping_confirmed or c.packaging_confirmed
       or c.spec_approved or c.file_approved or c.sample_approved,false),'draft',private.print_sales_draft_json(c)) row
   from public.redprinting_dev_mappings m join public.redprinting_dev_codes code on code.order_code=m.order_code
     left join private.print_sales_combinations c on c.product_id=m.product_id and c.page_count=m.page_count
   where private.print_sales_draft_source_valid(m,code) order by m.product_id,m.page_count limit 310
 ) x
$$;

create function public.save_print_sales_draft(p_product_id text,p_page_count integer,p_source_revision text,p_expected_version uuid,
 p_retail_price integer,p_shipping_budget integer,p_packaging_budget integer,p_note text default '')
returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.redprinting_dev_mappings;code public.redprinting_dev_codes;c private.print_sales_combinations;revision text;
begin
 if p_product_id is null or p_page_count is null or p_page_count not between 20 and 80 or p_page_count%2<>0 or p_source_revision is null or p_source_revision!~'^[a-f0-9]{64}$'
   or p_retail_price is null or p_retail_price not between 1 and 100000000 or p_shipping_budget is null or p_shipping_budget not between 0 and 10000000 or p_packaging_budget is null or p_packaging_budget not between 0 and 10000000
   or p_note is null or length(p_note)>1000 then raise exception 'invalid_print_sales_draft' using errcode='22023';end if;
 select * into m from public.redprinting_dev_mappings where product_id=p_product_id and page_count=p_page_count for update;
 if not found then raise exception 'print_sales_draft_source_unavailable' using errcode='P0002';end if;
 select * into code from public.redprinting_dev_codes where order_code=m.order_code for share;
 if not found or not private.print_sales_draft_source_valid(m,code) then raise exception 'print_sales_draft_source_unavailable' using errcode='P0002';end if;
 revision:=private.print_sales_draft_source_revision(m,code);
 if revision is distinct from p_source_revision then raise exception 'print_sales_draft_source_changed' using errcode='23514';end if;
 select * into c from private.print_sales_combinations where product_id=p_product_id and page_count=p_page_count for update;
 if found then
   if c.retail_final or c.supplier_cost_confirmed or c.shipping_confirmed or c.packaging_confirmed or c.spec_approved or c.file_approved or c.sample_approved then
     raise exception 'print_sales_draft_locked' using errcode='23514';end if;
   if c.draft_version is distinct from p_expected_version then raise exception 'print_sales_draft_conflict' using errcode='23514';end if;
 elsif p_expected_version is not null then raise exception 'print_sales_draft_conflict' using errcode='23514';end if;
 insert into private.print_sales_combinations as current_draft(product_id,page_count,final_price,price_version,order_code,cost_snapshot,
   draft_version,draft_source_revision,draft_note,draft_updated_at)
 values(p_product_id,p_page_count,p_retail_price,'DRAFT_V1',m.order_code,jsonb_build_object('estimatedPrintCost',(m.price_snapshot->>'totalPrice')::integer,
   'estimatedShippingCost',p_shipping_budget,'estimatedPackagingCost',p_packaging_budget,'paymentFeeRate',0.05,'reprintReserveRate',0.05,
   'operationsReserve',3000,'minimumContribution',10000,'draftOnly',true),gen_random_uuid(),revision,p_note,now())
 on conflict(product_id,page_count) do update set final_price=excluded.final_price,price_version='DRAFT_V1',order_code=excluded.order_code,cost_snapshot=excluded.cost_snapshot,
   retail_final=false,supplier_cost_confirmed=false,shipping_confirmed=false,packaging_confirmed=false,spec_approved=false,file_approved=false,sample_approved=false,
   draft_version=excluded.draft_version,draft_source_revision=excluded.draft_source_revision,draft_note=excluded.draft_note,draft_updated_at=excluded.draft_updated_at
 where not(current_draft.retail_final or current_draft.supplier_cost_confirmed or current_draft.shipping_confirmed or current_draft.packaging_confirmed
   or current_draft.spec_approved or current_draft.file_approved or current_draft.sample_approved)
   and current_draft.draft_version is not distinct from p_expected_version
 returning * into c;
 if not found then
   select * into c from private.print_sales_combinations where product_id=p_product_id and page_count=p_page_count;
   if c.retail_final or c.supplier_cost_confirmed or c.shipping_confirmed or c.packaging_confirmed or c.spec_approved or c.file_approved or c.sample_approved then
     raise exception 'print_sales_draft_locked' using errcode='23514';end if;
   raise exception 'print_sales_draft_conflict' using errcode='23514';
 end if;
 return jsonb_build_object('productId',m.product_id,'pageCount',m.page_count,'observedPrintCost',(m.price_snapshot->>'totalPrice')::integer,
   'observedAt',m.verified_at,'sourceRevision',revision,'locked',false,'draft',private.print_sales_draft_json(c));
end;$$;
revoke all on function public.read_print_sales_draft_candidates(),public.save_print_sales_draft(text,integer,text,uuid,integer,integer,integer,text) from public,anon,authenticated;
grant execute on function public.read_print_sales_draft_candidates(),public.save_print_sales_draft(text,integer,text,uuid,integer,integer,integer,text) to service_role;

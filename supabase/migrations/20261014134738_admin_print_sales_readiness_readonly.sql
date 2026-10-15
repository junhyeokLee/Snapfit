-- Administrator diagnostics only. This routine does not approve catalog rows,
-- enable sales, inspect a bank balance, alter an order, or call a supplier.
-- Public SDK route identifiers are compared internally, never returned.
create function public.read_print_sales_readiness(p_runtime_store_id text default '',p_runtime_channel_key text default '')
returns jsonb language sql stable security invoker set search_path='' as $$
  select jsonb_build_object(
    'configuration',coalesce((select jsonb_build_object('present',true,'enabled',c.enabled,
      'businessReady',c.business_ready,'portoneLiveReady',c.portone_live_ready,'redprintingLiveReady',c.redprinting_live_ready,
      'rendererReady',c.renderer_ready,'fulfillmentReady',c.fulfillment_ready,'environmentLive',c.environment='live',
      'routeConfigured',c.store_id ~ '^store-[A-Za-z0-9-]+$' and c.channel_key ~ '^channel-key-[A-Za-z0-9-]+$'
        and c.channel_key<>'channel-key-34782ac7-e644-4234-ad27-2767b6904f88',
      'routeMatchesRuntime',c.store_id=p_runtime_store_id and c.channel_key=p_runtime_channel_key,
      'workerLastSeenAt',c.worker_last_seen_at) from private.print_sales_configuration c where c.id=true),'{}'::jsonb),
    'senderConfigured',exists(select 1 from public.redprinting_dev_settings s where s.id=1 and s.sender_name='스냅핏'
      and replace(s.sender_tel,'-','') ~ '^0\d{8,10}$' and s.sender_zipcode ~ '^\d{5}$' and length(btrim(s.sender_address))>0
      and length(btrim(s.sender_address_detail))>0),
    -- Geometry and commercial policy remain internal to the admin Edge code.
    -- Customers and the admin response never receive these private documents.
    'combinations',coalesce((select jsonb_agg(jsonb_build_object('productId',c.product_id,'pageCount',c.page_count,
      'amount',c.final_price,'priceVersion',c.price_version,'retailFinal',c.retail_final,'supplierCostConfirmed',c.supplier_cost_confirmed,
      'shippingConfirmed',c.shipping_confirmed,'packagingConfirmed',c.packaging_confirmed,'specApproved',c.spec_approved,
      'fileApproved',c.file_approved,'sampleApproved',c.sample_approved,'orderCodePresent',c.order_code ~ '^[A-Za-z0-9_-]{1,100}$',
      'approvalEvidencePresent',length(c.approval_evidence)>=10,'approvedSpec',c.approved_spec,'costSnapshot',c.cost_snapshot)
      order by c.product_id,c.page_count) from private.print_sales_combinations c),'[]'::jsonb));
$$;
revoke all on function public.read_print_sales_readiness(text,text) from public,anon,authenticated;
grant execute on function public.read_print_sales_readiness(text,text) to service_role;

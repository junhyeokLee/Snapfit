-- Match the signer's recursive source-field and legacy JSON-string traversal.
-- Unsupported URI spellings fail closed instead of escaping namespace checks.
create function album_private.print_source_refs(p_doc jsonb)
returns setof text language plpgsql immutable security invoker set search_path='' as $$
declare entry record; item jsonb; text_value text;
begin
 if jsonb_typeof(p_doc)='object' then
  for entry in select key,value from jsonb_each(p_doc) loop
   if entry.key in('cover_layers_json','layers_json') and jsonb_typeof(entry.value)='string' then
    text_value:=entry.value#>>'{}';
    if not pg_input_is_valid(text_value,'jsonb') then raise exception 'invalid_print_snapshot' using errcode='22023'; end if;
    return query select * from album_private.print_source_refs(text_value::jsonb);
   elsif entry.key ~ '(originalUrl|previewUrl|imageUrl|textFillImageUrl|original_url|preview_url|image_url|thumbnail_url)$' and jsonb_typeof(entry.value)='string' then
    text_value:=entry.value#>>'{}';
    if text_value<>'' then return next text_value; end if;
   else return query select * from album_private.print_source_refs(entry.value);
   end if;
  end loop;
 elsif jsonb_typeof(p_doc)='array' then
  for item in select value from jsonb_array_elements(p_doc) loop
   return query select * from album_private.print_source_refs(item);
  end loop;
 end if;
 return;
end;
$$;
revoke all on function album_private.print_source_refs(jsonb) from public,anon,authenticated;

create function album_private.print_asset_paths(p_album_id bigint)
returns setof text language plpgsql stable security definer set search_path='' as $$
declare source text; path text;
begin
 for source in
  select r from public.albums a cross join lateral album_private.print_source_refs(to_jsonb(a))r where a.id=p_album_id
  union select r from public.album_pages ap cross join lateral album_private.print_source_refs(to_jsonb(ap))r where ap.album_id=p_album_id
 loop
  path:=album_private.asset_path(source);
  if path is null and source !~ '^((asset:)?assets/|@photo-layer-)' then
   raise exception 'print_asset_access_requires_review' using errcode='42501';
  end if;
  if path is not null then return next path; end if;
 end loop;
 return query select * from album_private.album_paths(p_album_id);
end;
$$;
revoke all on function album_private.print_asset_paths(bigint) from public,anon,authenticated;

-- Authorize only private files actually saved in this album. Membership alone
-- never grants another uploader's namespace to a print snapshot.
create function album_private.print_asset_owners(p_album_id bigint,p_actor uuid)
returns uuid[] language plpgsql stable security definer set search_path='' as $$
declare source_owner uuid; path text; uploader uuid; owners uuid[];
begin
 select a.owner_id into source_owner from public.albums a where a.id=p_album_id;
 if p_actor is null or source_owner is distinct from p_actor then
  raise exception 'album_owner_required' using errcode='42501';
 end if;
 owners:=array[source_owner];
 for path in select distinct p from album_private.print_asset_paths(p_album_id)p loop
  if not exists(select 1 from storage.objects o where o.bucket_id='album-assets' and o.name=path)
   or not coalesce((
    album_private.canonical_album(path)=p_album_id
    or exists(select 1 from album_private.asset_bindings b where b.album_id=p_album_id and b.storage_path=path)
    or album_private.legacy_owner_reference(path,p_album_id)
   ),false) then raise exception 'print_asset_access_requires_review' using errcode='42501'; end if;
  if split_part(path,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
   uploader:=split_part(path,'/',1)::uuid;
  else uploader:=source_owner;
  end if;
  owners:=array_append(owners,uploader);
 end loop;
 return array(select distinct u from unnest(owners)u order by u);
end;
$$;
revoke all on function album_private.print_asset_owners(bigint,uuid) from public,anon,authenticated;
grant execute on function album_private.print_asset_owners(bigint,uuid) to service_role;

-- Historical admin rendering may recover a former contributor's exact saved
-- paths. Frozen intent owner lists remain authoritative and never use this RPC.
create function public.read_album_print_asset_authorization(p_album_id bigint,p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare owners uuid[];
begin
 owners:=album_private.print_asset_owners(p_album_id,p_actor);
 return jsonb_build_object('allowedAssetOwners',to_jsonb(owners),
  'allowedAssetPaths',coalesce((select jsonb_agg(p order by p) from (select distinct p from album_private.print_asset_paths(p_album_id)p) saved),'[]'::jsonb));
end;
$$;
revoke all on function public.read_album_print_asset_authorization(bigint,uuid) from public,anon,authenticated;
grant execute on function public.read_album_print_asset_authorization(bigint,uuid) to service_role;

-- Keep every pricing, payment, consent and snapshot gate unchanged.
create or replace function public.load_owned_print_checkout_context(p_actor uuid,p_album_id bigint)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare a public.albums; pages jsonb;doc jsonb;review jsonb;q jsonb;c private.print_sales_configuration;actual integer;
  combo private.print_sales_combinations;ready boolean;owners uuid[];
begin
  select * into a from public.albums where id=p_album_id and owner_id=p_actor;
  if not found then raise exception 'album_access_denied' using errcode='42501'; end if;
  perform set_config('request.jwt.claim.sub',p_actor::text,true);
  q:=public.get_print_order_quote(p_album_id,null);
  doc:=nullif(btrim(a.cover_layers_json),'')::jsonb;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.page_index),'[]') into pages from public.album_pages p where p.album_id=p_album_id;
  review:=jsonb_build_object('album',to_jsonb(a),'pages',case when jsonb_typeof(doc->'pages')='array' then '[]'::jsonb else pages end);
  actual:=public.print_source_page_count(to_jsonb(a),jsonb_array_length(review->'pages'));
  if actual is distinct from (q->>'sourcePageCount')::integer
    or greatest(20,actual+(actual%2)) is distinct from (q->>'pageCount')::integer then
    raise exception 'print_quote_changed' using errcode='23514';end if;
  select * into c from private.print_sales_configuration where id=true;
  select * into combo from private.print_sales_combinations where product_id=q->>'productCode' and page_count=(q->>'pageCount')::integer;
  ready:=coalesce(c.enabled and c.business_ready and c.portone_live_ready and c.redprinting_live_ready and c.renderer_ready and c.fulfillment_ready
    and c.environment='live' and c.store_id<>'' and c.channel_key<>'' and (case when c.fulfillment_mode='APP_PDF_SUPABASE' then c.scheduler_last_seen_at else c.worker_last_seen_at end)>now()-interval '5 minutes'
    and combo.retail_final and combo.supplier_cost_confirmed and combo.shipping_confirmed and combo.packaging_confirmed
    and combo.spec_approved and combo.file_approved and combo.sample_approved and combo.order_code<>''
    and combo.final_price>0 and combo.price_version<>'' and length(combo.approval_evidence)>=10
    and combo.approved_spec->>'verified'='true' and combo.approved_spec->>'id'=q->>'productCode'
    and coalesce(combo.approved_spec->>'specVersion','')<>'' and combo.approved_spec->>'colorSpace'='sRGB'
    and (combo.approved_spec->>'dpi')::integer=300
    and combo.approved_spec->'interior'->'trimWidthMm'=q->'printProduct'->'trimWidthMm'
    and combo.approved_spec->'interior'->'trimHeightMm'=q->'printProduct'->'trimHeightMm'
    and (combo.approved_spec->'interior'->>'bleedMm')::numeric>=0
    and (combo.approved_spec->>'pageCount')::integer=(q->>'pageCount')::integer
    and (combo.cost_snapshot->>'estimatedPrintCost')::integer>0
    and (combo.cost_snapshot->>'estimatedShippingCost')::integer>=0
    and (combo.cost_snapshot->>'estimatedPackagingCost')::integer>=0,false);
  ready:=ready and coalesce(combo.cost_snapshot->'deliveryPolicy'->>'verified'='true'
    and length(coalesce(combo.cost_snapshot->'deliveryPolicy'->>'evidence',''))>=10
    and (combo.cost_snapshot->'deliveryPolicy'->>'coverage'='NATIONWIDE_FIXED'
      or(combo.cost_snapshot->'deliveryPolicy'->>'coverage'='POSTCODE_RANGES'
        and jsonb_typeof(combo.cost_snapshot->'deliveryPolicy'->'approvedPostcodeRanges')='array'
        and jsonb_array_length(combo.cost_snapshot->'deliveryPolicy'->'approvedPostcodeRanges')>0)),false);
  ready:=ready and coalesce(combo.cost_snapshot->'fulfillmentConfirmation'->>'senderName'='스냅핏'
    and combo.cost_snapshot->'fulfillmentConfirmation'->'senderLabelConfirmed'='true'::jsonb
    and combo.cost_snapshot->'fulfillmentConfirmation'->'priceSlipOmittedConfirmed'='true'::jsonb
    and combo.cost_snapshot->'fulfillmentConfirmation'->'promotionalMaterialsOmittedConfirmed'='true'::jsonb
    and length(coalesce(combo.cost_snapshot->'fulfillmentConfirmation'->>'evidence',''))>=10,false);
  ready:=ready and coalesce(jsonb_typeof(combo.cost_snapshot->'paymentFeeRate')='number'
    and jsonb_typeof(combo.cost_snapshot->'reprintReserveRate')='number'
    and (combo.cost_snapshot->>'paymentFeeRate')::numeric between 0 and 0.999999
    and (combo.cost_snapshot->>'reprintReserveRate')::numeric between 0 and 0.999999
    and (combo.cost_snapshot->>'operationsReserve')::integer>=3000 and (combo.cost_snapshot->>'minimumContribution')::integer>=10000
    and combo.final_price-(combo.cost_snapshot->>'estimatedPrintCost')::integer-(combo.cost_snapshot->>'estimatedShippingCost')::integer
      -(combo.cost_snapshot->>'estimatedPackagingCost')::integer-ceil(combo.final_price*(combo.cost_snapshot->>'paymentFeeRate')::numeric)::integer
      -ceil(combo.final_price*(combo.cost_snapshot->>'reprintReserveRate')::numeric)::integer-(combo.cost_snapshot->>'operationsReserve')::integer
      >=(combo.cost_snapshot->>'minimumContribution')::integer,false);
  if ready then
    q:=q||jsonb_build_object('amount',combo.final_price,'basePrice',combo.final_price,'basePages',q->'pageCount',
      'extraPageCount',0,'extraPagePrice',0,'pricePerTwoPages',0,'priceIsEstimate',false,'retailPriceStatus','FINAL',
      'pricePolicyVersion',combo.price_version,'supplierCostVerified',true,'shippingCostVerified',true,'packagingCostVerified',true,
      'spec',combo.approved_spec,'specMissing',false,'printTemplateStatus','APPROVED','priceNotice','기본 배송비가 포함된 최종 금액입니다.');
  end if;
  owners:=album_private.print_asset_owners(p_album_id,p_actor);
  return jsonb_build_object('snapshot',review,'sourceDigest',encode(sha256(convert_to(jsonb_build_object('snapshot',review,
    'quote',q,'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners),
    'route',jsonb_build_object('storeId',c.store_id,'channelKey',c.channel_key))::text,'UTF8')),'hex'),
    'quote',q,'canPay',ready,'filePreparationRequired',c.fulfillment_mode='APP_PDF_SUPABASE','maxFileBytes',500000000,'maxCoverFileBytes',150000000,'configuration',to_jsonb(c),'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners));
end;$$;

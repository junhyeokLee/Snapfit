-- Client-produced, server-validated PDFs are frozen before any SDK invoice is issued.
-- No operational key, sales approval, paid host, or business approval is enabled.
alter table private.print_sales_configuration add column fulfillment_mode text not null default 'APP_PDF_SUPABASE'
  check(fulfillment_mode in('LEGACY_WORKER','APP_PDF_SUPABASE'));
alter table private.print_sales_configuration add column scheduler_last_seen_at timestamptz;
alter table private.print_checkout_intents add column print_file_source text not null default 'LEGACY_WORKER'
  check(print_file_source in('LEGACY_WORKER','APP_UPLOADED'));
alter table private.print_checkout_intents add column prepayment_package_id uuid;
alter table private.print_checkout_intents add column sdk_issued_at timestamptz;

create table private.print_prepayment_packages (
  id uuid primary key default gen_random_uuid(), intent_id uuid not null unique references private.print_checkout_intents(id),
  state text not null default 'UPLOADING' check(state in('UPLOADING','FILES_VERIFIED','READY','ABANDONED','CLEANING','CLEANED')),
  source_fingerprint text not null check(source_fingerprint ~ '^[a-f0-9]{64}$'), spec_version text not null,
  cover_path text not null unique, interior_path text not null unique, manifest_path text not null unique,
  renderer_manifest jsonb not null, cover_result jsonb, interior_result jsonb, pdf_manifest jsonb,
  max_file_bytes integer not null default 50000000 check(max_file_bytes=50000000),
  expires_at timestamptz not null, created_at timestamptz not null default now(), verified_at timestamptz,
  cleanup_lease_until timestamptz
);
alter table private.print_checkout_intents add constraint print_checkout_prepayment_package
  foreign key(prepayment_package_id) references private.print_prepayment_packages(id) deferrable initially deferred;
alter table private.print_prepayment_packages enable row level security;
revoke all on private.print_prepayment_packages from public,anon,authenticated,service_role;
grant select,insert,update on private.print_prepayment_packages to service_role;

create function private.print_prepayment_ready(p_intent uuid) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from private.print_checkout_intents i join private.print_prepayment_packages p
  on p.id=i.prepayment_package_id and p.intent_id=i.id where i.id=p_intent and i.print_file_source='APP_UPLOADED' and p.state='READY'
  and p.cover_path=i.order_id||'/'||p.id::text||'/cover.pdf' and p.interior_path=i.order_id||'/'||p.id::text||'/interior.pdf'
  and p.manifest_path=i.order_id||'/'||p.id::text||'/manifest.json' and p.verified_at is not null
  and p.spec_version=i.approved_spec->>'specVersion' and p.pdf_manifest->'spec'=i.approved_spec
  and p.pdf_manifest->>'sourceFingerprint'=p.source_fingerprint and p.pdf_manifest->'cover'=p.cover_result
  and p.pdf_manifest->'interior'=p.interior_result and p.pdf_manifest->'vendorReady'='false'::jsonb
  and p.cover_result->'pageCount'='1'::jsonb and p.interior_result->>'pageCount'=i.page_count::text
  and p.cover_result->>'sha256' ~ '^[a-f0-9]{64}$' and p.interior_result->>'sha256' ~ '^[a-f0-9]{64}$'
  and (p.cover_result->>'byteLength')::integer between 100 and p.max_file_bytes
  and (p.interior_result->>'byteLength')::integer between 100 and p.max_file_bytes);
$$;
revoke all on function private.print_prepayment_ready(uuid) from public,anon,authenticated;
grant execute on function private.print_prepayment_ready(uuid) to service_role;

create function private.guard_print_prepayment_package() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if row(new.id,new.intent_id,new.source_fingerprint,new.spec_version,new.cover_path,new.interior_path,new.manifest_path,new.renderer_manifest,
   new.max_file_bytes,new.expires_at,new.created_at) is distinct from row(old.id,old.intent_id,old.source_fingerprint,old.spec_version,
   old.cover_path,old.interior_path,old.manifest_path,old.renderer_manifest,old.max_file_bytes,old.expires_at,old.created_at) then
   raise exception 'print_prepayment_immutable' using errcode='23514';end if;
 if (old.cover_result is not null and new.cover_result is distinct from old.cover_result)
  or(old.interior_result is not null and new.interior_result is distinct from old.interior_result)
  or(old.pdf_manifest is not null and new.pdf_manifest is distinct from old.pdf_manifest)
  or(old.verified_at is not null and new.verified_at is distinct from old.verified_at) then
   raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
 if new.state is distinct from old.state and not ((old.state='UPLOADING' and new.state in('FILES_VERIFIED','ABANDONED'))
  or(old.state='FILES_VERIFIED' and new.state in('READY','ABANDONED')) or(old.state='READY' and new.state='ABANDONED')
  or(old.state='ABANDONED' and new.state='CLEANING') or(old.state='CLEANING' and new.state in('CLEANING','ABANDONED','CLEANED'))) then
   raise exception 'print_prepayment_state_changed' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.guard_print_prepayment_package() from public,anon,authenticated;
create trigger print_prepayment_package_guard before update on private.print_prepayment_packages
 for each row execute function private.guard_print_prepayment_package();
create function private.guard_print_intent_file_binding() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.print_file_source is distinct from old.print_file_source or (new.prepayment_package_id is distinct from old.prepayment_package_id
  and not(old.prepayment_package_id is null and old.status='PREPARED' and old.sdk_issued_at is null and new.prepayment_package_id is not null))
  or (old.sdk_issued_at is not null and new.sdk_issued_at is distinct from old.sdk_issued_at) then
   raise exception 'print_checkout_file_binding_immutable' using errcode='23514';end if;
 if new.prepayment_package_id is not null and not exists(select 1 from private.print_prepayment_packages p
  where p.id=new.prepayment_package_id and p.intent_id=new.id) then raise exception 'print_prepayment_conflict' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.guard_print_intent_file_binding() from public,anon,authenticated;
create trigger print_checkout_file_binding_guard before update on private.print_checkout_intents
 for each row execute function private.guard_print_intent_file_binding();

create function public.print_prepayment_package(p_actor uuid,p_action text,p_request_id uuid,p_order_id text,p_payment_id text,
 p_package_id uuid default null,p_file_kind text default null,p_file_result jsonb default null,p_manifest jsonb default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents;o public.orders;p private.print_prepayment_packages; ops jsonb; held boolean;
 id_new uuid; kind text; declared jsonb; width_mm numeric;height_mm numeric;ready_manifest jsonb;
begin
 if p_actor is null or p_action not in('snapshot','status','uploads','finalize','seal') then
  raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
 select * into i from private.print_checkout_intents where user_id=p_actor and request_id=p_request_id and order_id=p_order_id
  and payment_id=p_payment_id and print_file_source='APP_UPLOADED' for update;
 if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
 select * into strict o from public.orders where order_id=i.order_id and user_id=p_actor for update;
 held:=o.print_customer_request_hold;
 if p_action not in('snapshot','status') then
  if i.status<>'PREPARED' or o.status<>'PAYMENT_PENDING' or i.expires_at<=now() or o.payment_reversed_at is not null then
   raise exception 'print_prepayment_state_changed' using errcode='23514';end if;
  if held then raise exception 'print_request_hold_active' using errcode='23514';end if;
 end if;
 select * into p from private.print_prepayment_packages where intent_id=i.id for update;
 if p_action='uploads' then
  if p_file_result->>'sourceFingerprint' !~ '^[a-f0-9]{64}$' or p_file_result->>'specVersion' is distinct from i.approved_spec->>'specVersion'
   or p_manifest->>'sourceFingerprint' is distinct from p_file_result->>'sourceFingerprint'
   or p_manifest->>'specVersion' is distinct from i.approved_spec->>'specVersion'
   or p_manifest->>'renderer' is distinct from 'flutter-layer-builder-raster-v1'
   or p_manifest->>'productId' is distinct from i.product->>'id' or p_manifest->>'coverType' is distinct from i.approved_spec->>'coverType'
   or p_manifest->>'pageCount' is distinct from i.page_count::text or p_manifest->'dpi' is distinct from '300'::jsonb
   or p_manifest->>'colorSpace' is distinct from 'sRGB' or p_manifest->'iccProfileEmbedded' is distinct from 'true'::jsonb
   or p_manifest->'missingAssets' is distinct from '[]'::jsonb or jsonb_typeof(p_manifest->'warnings') is distinct from 'array'
   or length(p_manifest::text)>160000 then raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
  for kind in select unnest(array['cover','interior']) loop
   declared:=p_manifest->'declaredFiles'->kind;
   if not coalesce(jsonb_typeof(declared->'bytes')='number' and declared->>'bytes' ~ '^[0-9]+$'
    and (declared->>'bytes')::bigint between 100 and 50000000 and declared->>'sha256' ~ '^[a-f0-9]{64}$',false) then
     raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
  end loop;
  if p.id is not null then
   if p.renderer_manifest is distinct from p_manifest or p.source_fingerprint is distinct from p_file_result->>'sourceFingerprint' then
    raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
  else
   id_new:=gen_random_uuid();
   insert into private.print_prepayment_packages(id,intent_id,source_fingerprint,spec_version,renderer_manifest,expires_at,
    cover_path,interior_path,manifest_path) values(id_new,i.id,p_file_result->>'sourceFingerprint',p_file_result->>'specVersion',p_manifest,i.expires_at,
    i.order_id||'/'||id_new::text||'/cover.pdf',i.order_id||'/'||id_new::text||'/interior.pdf',i.order_id||'/'||id_new::text||'/manifest.json') returning * into p;
   update private.print_checkout_intents set prepayment_package_id=p.id where id=i.id returning * into i;
  end if;
 elsif p_action in('finalize','seal') then
  if p.id is null or p.id is distinct from p_package_id then raise exception 'print_prepayment_not_found' using errcode='P0002';end if;
  if p.expires_at<=now() or p.state in('ABANDONED','CLEANING','CLEANED') then raise exception 'print_prepayment_expired' using errcode='23514';end if;
  if p_action='finalize' then
   if p_file_kind not in('cover','interior') or p_manifest is distinct from p.renderer_manifest then
    raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
   declared:=p.renderer_manifest->'declaredFiles'->p_file_kind;
   width_mm:=case when p_file_kind='cover' then (i.approved_spec->'cover'->>'widthMm')::numeric
    else (i.approved_spec->'interior'->>'trimWidthMm')::numeric+2*(i.approved_spec->'interior'->>'bleedMm')::numeric end;
   height_mm:=case when p_file_kind='cover' then (i.approved_spec->'cover'->>'heightMm')::numeric
    else (i.approved_spec->'interior'->>'trimHeightMm')::numeric+2*(i.approved_spec->'interior'->>'bleedMm')::numeric end;
   if not coalesce(p_file_result->>'pageCount'=case when p_file_kind='cover' then '1' else i.page_count::text end
    and p_file_result->'byteLength'=declared->'bytes' and p_file_result->'sha256'=declared->'sha256'
    and jsonb_typeof(p_file_result->'widthMm')='number' and jsonb_typeof(p_file_result->'heightMm')='number'
    and abs((p_file_result->>'widthMm')::numeric-width_mm)<0.001 and abs((p_file_result->>'heightMm')::numeric-height_mm)<0.001
    and p_file_result-array['pageCount','widthMm','heightMm','byteLength','sha256']='{}'::jsonb,false) then
     raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   if (p_file_kind='cover' and p.cover_result is not null and p.cover_result is distinct from p_file_result)
    or(p_file_kind='interior' and p.interior_result is not null and p.interior_result is distinct from p_file_result) then
     raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   update private.print_prepayment_packages set cover_result=case when p_file_kind='cover' then p_file_result else cover_result end,
    interior_result=case when p_file_kind='interior' then p_file_result else interior_result end where id=p.id returning * into p;
   if p.cover_result is not null and p.interior_result is not null and p.state='UPLOADING' then
    ready_manifest:=(p.renderer_manifest-'declaredFiles')||jsonb_build_object('sourceFingerprint',p.source_fingerprint,'spec',i.approved_spec,
     'cover',p.cover_result,'interior',p.interior_result,'generatedAt',now(),'vendorReady',false);
    update private.print_prepayment_packages set state='FILES_VERIFIED',pdf_manifest=ready_manifest where id=p.id returning * into p;
   end if;
  elsif p.state='FILES_VERIFIED' then
   update private.print_prepayment_packages set state='READY',verified_at=now() where id=p.id returning * into p;
  elsif p.state<>'READY' then raise exception 'print_prepayment_state_changed' using errcode='23514';end if;
 end if;
 select to_jsonb(x)-'order_id' into ops from public.print_order_operations x where order_id=o.order_id;
 return jsonb_build_object('intent',to_jsonb(i)||jsonb_build_object('request_hold',held),'order',to_jsonb(o)||coalesce(ops,'{}'::jsonb),'package',case when p.id is null then null else to_jsonb(p) end);
end;$$;
revoke all on function public.print_prepayment_package(uuid,text,uuid,text,text,uuid,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.print_prepayment_package(uuid,text,uuid,text,text,uuid,text,jsonb,jsonb) to service_role;


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
  select array_agg(distinct user_id order by user_id) into owners from (select p_actor user_id union all
    select user_id from public.album_members where album_id=p_album_id and role in ('OWNER','EDITOR')) allowed;
  return jsonb_build_object('snapshot',review,'sourceDigest',encode(sha256(convert_to(jsonb_build_object('snapshot',review,
    'quote',q,'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners),
    'route',jsonb_build_object('storeId',c.store_id,'channelKey',c.channel_key))::text,'UTF8')),'hex'),
    'quote',q,'canPay',ready,'filePreparationRequired',c.fulfillment_mode='APP_PDF_SUPABASE','maxFileBytes',50000000,'configuration',to_jsonb(c),'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners));
end;$$;

create or replace function public.prepare_production_print_checkout(p_actor uuid,p_request_id uuid,p_album_id bigint,p_source_digest text,
  p_reviewed_revision text,p_reviewed_spec_revision text,p_expected_amount integer,p_page_count integer,p_recipient jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare ctx jsonb;q jsonb;c jsonb;combo jsonb;fp text;i private.print_checkout_intents;sid text;
begin
  if p_actor is null or p_request_id is null or coalesce(p_reviewed_revision,'') !~ '^[a-f0-9]{64}$'
    or coalesce(p_reviewed_spec_revision,'') !~ '^[a-f0-9]{64}$'
    or coalesce(p_source_digest,'') !~ '^[a-f0-9]{64}$' or p_expected_amount is null or p_page_count is null or jsonb_typeof(p_recipient) is distinct from 'object' then
    raise exception 'invalid_print_checkout_request' using errcode='22023';end if;
  if length(coalesce(btrim(p_recipient->>'name'),'')) not between 1 and 80 or coalesce(p_recipient->>'phone','') !~ '^\d{10,11}$'
    or coalesce(p_recipient->>'zipCode','') !~ '^\d{5}$' or length(coalesce(btrim(p_recipient->>'addressLine1'),'')) not between 1 and 300
    or length(coalesce(p_recipient->>'addressLine2',''))>300 or length(coalesce(p_recipient->>'deliveryMemo',''))>300
    or p_recipient-array['name','phone','zipCode','addressLine1','addressLine2','deliveryMemo']<>'{}'::jsonb then
    raise exception 'invalid_delivery_address' using errcode='22023';end if;
  fp:=encode(sha256(convert_to(jsonb_build_object('album',p_album_id,'review',p_reviewed_revision,'specReview',p_reviewed_spec_revision,'amount',p_expected_amount,
    'pages',p_page_count,'recipient',p_recipient)::text,'UTF8')),'hex');
  select * into i from private.print_checkout_intents where user_id=p_actor and request_id=p_request_id;
  if found then
    if i.request_fingerprint is distinct from fp then raise exception 'print_checkout_request_conflict' using errcode='23514';end if;
    return to_jsonb(i);
  end if;
  perform 1 from public.albums where id=p_album_id and owner_id=p_actor for update;
  if not found then raise exception 'album_access_denied' using errcode='42501';end if;
  ctx:=public.load_owned_print_checkout_context(p_actor,p_album_id);q:=ctx->'quote';c:=ctx->'configuration';combo:=ctx->'combination';
  if ctx->>'canPay' is distinct from 'true' then raise exception 'print_sales_not_ready' using errcode='23514';end if;
  if ctx->>'sourceDigest' is distinct from p_source_digest then raise exception 'print_album_changed' using errcode='23514';end if;
  if (q->>'amount')::integer is distinct from p_expected_amount or (q->>'pageCount')::integer is distinct from p_page_count then
    raise exception 'print_quote_changed' using errcode='23514';end if;
  if combo->'cost_snapshot'->'deliveryPolicy'->>'coverage' is distinct from 'NATIONWIDE_FIXED'
    and not exists(select 1 from jsonb_array_elements(combo->'cost_snapshot'->'deliveryPolicy'->'approvedPostcodeRanges') r
      where r->>'start' ~ '^\d{5}$' and r->>'end' ~ '^\d{5}$'
        and p_recipient->>'zipCode' between r->>'start' and r->>'end') then
    raise exception 'print_delivery_quote_required' using errcode='23514';end if;
  insert into private.print_checkout_intents(user_id,request_id,album_id,request_fingerprint,source_digest,reviewed_revision,reviewed_spec_revision,delivery_snapshot,
    snapshot,product,approved_spec,cost_snapshot,source_asset_owners,order_code,store_id,channel_key,amount,page_count,print_file_source)
  values(p_actor,p_request_id,p_album_id,fp,p_source_digest,p_reviewed_revision,p_reviewed_spec_revision,p_recipient,
    (ctx->'snapshot')||jsonb_build_object('printProduct',q->'printProduct'),q->'printProduct',combo->'approved_spec',combo->'cost_snapshot',
    array(select jsonb_array_elements_text(ctx->'allowedAssetOwners')::uuid),combo->>'order_code',c->>'store_id',c->>'channel_key',p_expected_amount,p_page_count,case when c->>'fulfillment_mode'='APP_PDF_SUPABASE' then 'APP_UPLOADED' else 'LEGACY_WORKER' end)
  on conflict(user_id,request_id) do nothing returning * into i;
  if not found then
    select * into strict i from private.print_checkout_intents where user_id=p_actor and request_id=p_request_id;
    if i.request_fingerprint is distinct from fp then raise exception 'print_checkout_request_conflict' using errcode='23514';end if;
    return to_jsonb(i);
  end if;
  insert into public.orders(order_id,user_id,album_id,title,amount,page_count,status,payment_method,payment_currency,pricing_version,
    checkout_flow,payment_environment,print_content_snapshot,print_product_snapshot,recipient_name,recipient_phone,zip_code,address_line1,address_line2,delivery_memo,
    print_spec_override,print_spec_snapshot)
  values(i.order_id,p_actor,p_album_id,coalesce(nullif(i.snapshot->'album'->>'title',''),'스냅핏 포토북'),i.amount,i.page_count,'PAYMENT_PENDING',
    'PORTONE','KRW','PRINT_REDP_COVERTYPE_V3','PORTONE_V2_V1','live',i.snapshot,i.product,p_recipient->>'name',p_recipient->>'phone',
    p_recipient->>'zipCode',p_recipient->>'addressLine1',coalesce(p_recipient->>'addressLine2',''),coalesce(p_recipient->>'deliveryMemo',''),
    case when right(i.product->>'id',5)='_HARD' then jsonb_build_object('coverGeometry',i.approved_spec->'cover',
      'templateRevision',i.approved_spec->>'specVersion') else jsonb_build_object('spineMm',i.approved_spec->'spineMm') end,i.approved_spec);
  insert into public.print_order_operations(order_id,print_cost_snapshot) values(i.order_id,i.cost_snapshot);
  return to_jsonb(i);
end;$$;

create or replace function public.get_owned_print_checkout(p_actor uuid,p_payment_id text default null,p_request_id uuid default null)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare i private.print_checkout_intents;c private.print_sales_configuration;combo private.print_sales_combinations;launch_ready boolean;
begin
  if (p_payment_id is null)=(p_request_id is null) then raise exception 'invalid_print_checkout_request' using errcode='22023';end if;
  select * into i from private.print_checkout_intents where user_id=p_actor and
    ((p_payment_id is not null and payment_id=p_payment_id) or (p_request_id is not null and request_id=p_request_id));
  if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
  select * into c from private.print_sales_configuration where id=true;
  select * into combo from private.print_sales_combinations where product_id=i.product->>'id' and page_count=i.page_count;
  launch_ready:=coalesce(c.enabled and c.business_ready and c.portone_live_ready and c.redprinting_live_ready and c.renderer_ready and c.fulfillment_ready
    and c.environment='live' and c.store_id=i.store_id and c.channel_key=i.channel_key and (case when c.fulfillment_mode='APP_PDF_SUPABASE' then c.scheduler_last_seen_at else c.worker_last_seen_at end)>now()-interval '5 minutes'
    and combo.spec_approved and combo.file_approved and combo.sample_approved and combo.retail_final and combo.supplier_cost_confirmed
    and combo.shipping_confirmed and combo.packaging_confirmed and combo.approved_spec=i.approved_spec
    and combo.cost_snapshot=i.cost_snapshot and combo.order_code=i.order_code,false);
  return to_jsonb(i)||jsonb_build_object('prepayment_package_ready',private.print_prepayment_ready(i.id),'launch_ready',launch_ready and (i.print_file_source<>'APP_UPLOADED' or private.print_prepayment_ready(i.id)) and not exists(select 1 from public.orders where order_id=i.order_id and print_customer_request_hold),
    'request_hold',exists(select 1 from public.orders where order_id=i.order_id and print_customer_request_hold),
    'refunded_full',exists(select 1 from private.print_payment_reversals where intent_id=i.id));
end;$$;


create function public.authorize_print_app_pdf_checkout(p_actor uuid,p_payment_id text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents;result jsonb;
begin
 select * into i from private.print_checkout_intents where user_id=p_actor and payment_id=p_payment_id for update;
 if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
 result:=public.get_owned_print_checkout(p_actor,p_payment_id,null);
 if i.print_file_source='APP_UPLOADED' then
  if i.status<>'PREPARED' or i.expires_at<=now() or result->'launch_ready' is distinct from 'true'::jsonb
   or not private.print_prepayment_ready(i.id) then raise exception 'print_files_not_ready' using errcode='23514';end if;
  update private.print_checkout_intents set sdk_issued_at=coalesce(sdk_issued_at,now()) where id=i.id;
 end if;
 return public.get_owned_print_checkout(p_actor,p_payment_id,null);
end;$$;
revoke all on function public.authorize_print_app_pdf_checkout(uuid,text) from public,anon,authenticated;
grant execute on function public.authorize_print_app_pdf_checkout(uuid,text) to service_role;


create or replace function public.commit_production_print_payment(p_actor uuid,p_payment_id text,p_receipt jsonb,p_unpaid boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents; v_state text; p private.print_prepayment_packages; held boolean;
begin
  select * into i from private.print_checkout_intents where user_id=p_actor and payment_id=p_payment_id for update;
  if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
  if p_receipt->>'provider' is distinct from 'PORTONE' or p_receipt->>'version' is distinct from 'V2'
    or p_receipt->>'paymentId' is distinct from i.payment_id or p_receipt->>'storeId' is distinct from i.store_id
    or p_receipt->>'channelKey' is distinct from i.channel_key or p_receipt->>'environment' is distinct from 'live'
    or p_receipt->'isTest' is distinct from 'false'::jsonb or p_receipt->>'currency' is distinct from 'KRW'
    or jsonb_typeof(p_receipt->'amount') is distinct from 'number' or coalesce(p_receipt->>'amount','') !~ '^[0-9]+$' or (p_receipt->>'amount')::integer is distinct from i.amount
    or coalesce(p_receipt->>'transactionId','') !~ '^[A-Za-z0-9_-]{1,200}$' then
    raise exception 'print_payment_receipt_invalid' using errcode='23514';end if;
  if p_unpaid then
    if coalesce(p_receipt->>'status','') not in('FAILED','CANCELLED') or p_receipt->'verifiedUnpaid' is distinct from 'true'::jsonb then
      raise exception 'print_payment_receipt_invalid' using errcode='23514';end if;
    if coalesce(p_receipt->>'paidAmount','') !~ '^[0-9]+$' or coalesce(p_receipt->>'cancelledAmount','') !~ '^[0-9]+$'
      or not((p_receipt->>'status'='FAILED' and (p_receipt->>'paidAmount')::bigint=0 and (p_receipt->>'cancelledAmount')::bigint=0)
        or(p_receipt->>'status'='CANCELLED' and (p_receipt->>'paidAmount')::bigint>0 and (p_receipt->>'cancelledAmount')::bigint>=(p_receipt->>'paidAmount')::bigint
          and (p_receipt->>'cancelledAmount')::bigint<=i.amount)) then
      raise exception 'print_payment_receipt_invalid' using errcode='23514';end if;
    v_state:=case when p_receipt->>'status'='FAILED' then 'FAILED' else 'CANCELED' end;
  else
    if p_receipt->>'status' is distinct from 'PAID' or coalesce(p_receipt->>'paidAmount','') !~ '^[0-9]+$'
      or coalesce(p_receipt->>'discountAmount','') !~ '^[0-9]+$' or coalesce(p_receipt->>'paidAt','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' or (p_receipt->>'paidAmount')::bigint<=0
      or (p_receipt->>'discountAmount')::bigint<0
      or (p_receipt->>'paidAmount')::bigint+(p_receipt->>'discountAmount')::bigint<>i.amount then
      raise exception 'print_payment_receipt_invalid' using errcode='23514';end if;
    v_state:='PAID';
  end if;
  if p_receipt-array['provider','version','status','paymentId','transactionId','storeId','channelKey','amount','paidAmount','discountAmount',
    'cancelledAmount','currency','paidAt','environment','isTest','verifiedUnpaid']<>'{}'::jsonb then
    raise exception 'print_payment_receipt_invalid' using errcode='23514';end if;
  if i.status<>'PREPARED' then
    if i.status=v_state and i.payment_receipt=p_receipt then return to_jsonb(i);end if;
    raise exception 'print_payment_receipt_conflict' using errcode='23514';end if;
  perform 1 from public.orders where order_id=i.order_id and user_id=p_actor and status='PAYMENT_PENDING' for update;
  if not found then raise exception 'print_payment_state_changed' using errcode='23514';end if;
  update private.print_checkout_intents set status=v_state,payment_receipt=p_receipt,verified_at=now()
    where id=i.id returning * into i;
  if not p_unpaid then
    update public.orders set status='PAYMENT_COMPLETED',verified_payment_id=i.payment_id,verified_payment_provider='PORTONE',payment_confirmed_at=i.verified_at
      where order_id=i.order_id;
    select print_customer_request_hold into held from public.orders where order_id=i.order_id;
    if i.print_file_source='APP_UPLOADED' then
      -- Preserve an observed real payment even if a hold or missing package needs
      -- review; never manufacture an unverified file or strand a charged customer.
      if private.print_prepayment_ready(i.id) and i.sdk_issued_at is not null and not held then
        select * into strict p from private.print_prepayment_packages where id=i.prepayment_package_id;
        update public.orders set print_fulfillment_status='RENDERING',print_upload_id=p.id,
          print_upload_fingerprint=p.source_fingerprint where order_id=i.order_id;
        update public.orders set print_cover_pdf_path=p.cover_path,print_interior_pdf_path=p.interior_path,print_manifest_path=p.manifest_path,
          print_manifest=p.pdf_manifest,print_fulfillment_status='REVIEW_REQUIRED',print_package_generated_at=p.verified_at,
          print_asset_count=i.page_count+1,print_vendor='REDPRINTING' where order_id=i.order_id;
        update public.orders set print_fulfillment_status='READY',print_spec_confirmed_at=p.verified_at where order_id=i.order_id;
        insert into private.print_fulfillment_outbox(order_id,event_type,payload) values(i.order_id,'SUBMIT',
          jsonb_build_object('vendorOrderNum','SFO_'||replace(i.id::text,'-',''),'vendorOrderSeq',1,'queryOnly',false,'prepaymentPackageId',p.id))
          on conflict(order_id) do nothing;
      else update public.orders set print_requires_action=true where order_id=i.order_id;end if;
    elsif not held then
      insert into private.print_fulfillment_outbox(order_id,payload) values(i.order_id,
        jsonb_build_object('vendorOrderNum','SFO_'||replace(i.id::text,'-',''),'vendorOrderSeq',1,'queryOnly',false))
        on conflict(order_id) do nothing;
    else update public.orders set print_requires_action=true where order_id=i.order_id;end if;
  else update public.orders set status='CANCELED' where order_id=i.order_id;end if;
  return to_jsonb(i);
end;$$;

create or replace function public.claim_print_app_pdf_fulfillment_job(p_worker_id uuid,p_limit integer default 1,p_lease_seconds integer default 120,p_runtime_ready boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;i private.print_checkout_intents;o public.orders;c private.print_sales_configuration;
begin
  if p_worker_id is null or p_limit<>1 or p_lease_seconds not between 30 and 300 then raise exception 'invalid_worker_claim' using errcode='22023';end if;
  update private.print_sales_configuration set worker_last_seen_at=case when p_runtime_ready is true then now() else null end where id=true returning * into c;
  if p_runtime_ready is not true then return null;end if;
  if c.fulfillment_mode<>'APP_PDF_SUPABASE' then return null;end if;
  if not(c.enabled and c.business_ready and c.portone_live_ready and c.redprinting_live_ready and c.renderer_ready and c.fulfillment_ready and c.environment='live') then return null;end if;
  select job.* into j from private.print_fulfillment_outbox job join public.orders ord on ord.order_id=job.order_id
    join private.print_checkout_intents intent on intent.order_id=job.order_id
    where job.available_at<=now() and (job.state in('PENDING','UNKNOWN') or(job.state='CLAIMED' and job.lease_until<now()))
      and job.event_type in('SUBMIT','CONFIRM','POLL') and intent.print_file_source='APP_UPLOADED'
      and private.print_prepayment_ready(intent.id) and intent.sdk_issued_at is not null
      and ord.print_upload_id=intent.prepayment_package_id and exists(select 1 from private.print_prepayment_packages package
       where package.id=intent.prepayment_package_id and package.cover_path=ord.print_cover_pdf_path
        and package.interior_path=ord.print_interior_pdf_path and package.pdf_manifest=ord.print_manifest)
      and intent.status='PAID' and intent.environment='live' and intent.payment_receipt->'isTest'='false'::jsonb
      and ord.status in('PAYMENT_COMPLETED','IN_PRODUCTION','PRINTING','SHIPPING') and ord.payment_reversed_at is null
      and (not ord.print_customer_request_hold or(job.event_type='POLL' and ord.status in('IN_PRODUCTION','PRINTING','SHIPPING')))
    order by job.available_at for update of job skip locked limit 1;
  if not found then return null;end if;
  update private.print_fulfillment_outbox set state='CLAIMED',lease_owner=p_worker_id,
    lease_until=now()+make_interval(secs=>p_lease_seconds),attempts=attempts+1,updated_at=now() where id=j.id returning * into j;
  select * into strict i from private.print_checkout_intents where order_id=j.order_id;
  select * into strict o from public.orders where order_id=j.order_id;
  update public.orders set print_package_lock_token=p_worker_id,print_package_lock_until=j.lease_until
    where order_id=j.order_id returning * into o;
  return jsonb_build_object('job',to_jsonb(j),'order',to_jsonb(o),'approvedSpec',i.approved_spec,'orderCode',i.order_code,
    'sourceFingerprint',i.reviewed_revision,'allowedAssetOwners',to_jsonb(i.source_asset_owners),'paymentEnvironment',i.payment_receipt->>'environment',
    'approvalCurrent',private.print_intent_approval_current(i.id),'costSnapshot',i.cost_snapshot,'paymentExpectation',jsonb_build_object('paymentId',i.payment_id,'storeId',i.store_id,'channelKey',i.channel_key,
      'amount',i.amount,'currency','KRW','environment','live'));
end;$$;


create function public.record_print_order_scheduler_heartbeat(p_runtime_ready boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 update private.print_sales_configuration set scheduler_last_seen_at=now(),
  worker_last_seen_at=case when p_runtime_ready then now() else null end where id=true and fulfillment_mode='APP_PDF_SUPABASE';
 return jsonb_build_object('recorded',found,'runtimeReady',p_runtime_ready);
end;$$;

-- No automatic cleanup of any uncertain invoice for which an SDK was issued.
create function public.claim_abandoned_print_prepayment_packages(p_limit integer default 1)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare p private.print_prepayment_packages;i private.print_checkout_intents;result jsonb:='[]'::jsonb;
begin
 if p_limit<>1 then raise exception 'invalid_cleanup_limit' using errcode='22023';end if;
 -- Match the payment/package lock order, so a concurrent receipt cannot race
 -- a cleanup candidate into PAID after its PDF has been deleted.
 select intent.* into i from private.print_checkout_intents intent join private.print_prepayment_packages package on package.intent_id=intent.id
  where (intent.status in('FAILED','CANCELED') or(intent.status='PREPARED' and intent.sdk_issued_at is null and intent.expires_at<now()-interval '1 hour'))
   and (package.state in('UPLOADING','FILES_VERIFIED','READY','ABANDONED') or(package.state='CLEANING' and package.cleanup_lease_until<now()))
  order by package.expires_at for update of intent skip locked limit 1;
 if not found then return result;end if;
 select * into strict p from private.print_prepayment_packages where intent_id=i.id for update;
 if p.state in('UPLOADING','FILES_VERIFIED','READY') then
  update private.print_prepayment_packages set state='ABANDONED' where id=p.id returning * into p;end if;
 update private.print_prepayment_packages set state='CLEANING',cleanup_lease_until=now()+interval '10 minutes' where id=p.id returning * into p;
 return jsonb_build_array(jsonb_build_object('id',p.id,'paths',jsonb_build_array(p.cover_path,p.interior_path,p.manifest_path)));
end;$$;
create function public.finish_abandoned_print_prepayment_package(p_id uuid,p_removed boolean)
returns void language plpgsql security invoker set search_path='' as $$
begin
 update private.print_prepayment_packages set state=case when p_removed then 'CLEANED' else 'ABANDONED' end,cleanup_lease_until=null
  where id=p_id and state='CLEANING' and cleanup_lease_until>now();
 if not found then raise exception 'print_cleanup_lease_lost' using errcode='23514';end if;
end;$$;

-- Once attached to a paid app-PDF order, even pre-submission file pointers and
-- validation evidence must remain exactly the frozen, private package.
create function private.guard_app_pdf_order_files() returns trigger language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents;p private.print_prepayment_packages;
begin
 select * into i from private.print_checkout_intents where order_id=old.order_id and print_file_source='APP_UPLOADED';
 if not found or new.status='PAYMENT_PENDING' then return new;end if;
 if old.print_manifest is not null and row(new.print_cover_pdf_path,new.print_interior_pdf_path,new.print_manifest_path,new.print_upload_id,
  new.print_upload_fingerprint,new.print_manifest) is distinct from row(old.print_cover_pdf_path,old.print_interior_pdf_path,old.print_manifest_path,
  old.print_upload_id,old.print_upload_fingerprint,old.print_manifest) then
  raise exception 'print_paid_file_binding_immutable' using errcode='23514';end if;
 if new.print_fulfillment_status in('REVIEW_REQUIRED','READY','SUBMITTED','ACCEPTED') then
  select * into p from private.print_prepayment_packages where id=i.prepayment_package_id and intent_id=i.id and state='READY';
  if p.id is null or new.print_cover_pdf_path is distinct from p.cover_path or new.print_interior_pdf_path is distinct from p.interior_path
   or new.print_manifest_path is distinct from p.manifest_path or new.print_upload_id is distinct from p.id
   or new.print_upload_fingerprint is distinct from p.source_fingerprint or new.print_manifest is distinct from p.pdf_manifest then
    raise exception 'print_paid_file_binding_immutable' using errcode='23514';end if;
 end if;
 return new;
end;$$;
revoke all on function private.guard_app_pdf_order_files() from public,anon,authenticated;
create trigger orders_guard_app_pdf_files before update on public.orders for each row execute function private.guard_app_pdf_order_files();


create or replace function public.read_print_sales_readiness(p_runtime_store_id text default '',p_runtime_channel_key text default '')
returns jsonb language sql stable security invoker set search_path='' as $$
  select jsonb_build_object(
    'configuration',coalesce((select jsonb_build_object('present',true,'enabled',c.enabled,
      'businessReady',c.business_ready,'portoneLiveReady',c.portone_live_ready,'redprintingLiveReady',c.redprinting_live_ready,
      'rendererReady',c.renderer_ready,'fulfillmentReady',c.fulfillment_ready,'environmentLive',c.environment='live',
      'routeConfigured',c.store_id ~ '^store-[A-Za-z0-9-]+$' and c.channel_key ~ '^channel-key-[A-Za-z0-9-]+$'
        and c.channel_key<>'channel-key-34782ac7-e644-4234-ad27-2767b6904f88',
      'routeMatchesRuntime',c.store_id=p_runtime_store_id and c.channel_key=p_runtime_channel_key,
      'workerLastSeenAt',case when c.fulfillment_mode='APP_PDF_SUPABASE' then c.scheduler_last_seen_at else c.worker_last_seen_at end,
      'fulfillmentMode',c.fulfillment_mode,'schedulerLastSeenAt',c.scheduler_last_seen_at,'maxPrepaymentFileBytes',50000000) from private.print_sales_configuration c where c.id=true),'{}'::jsonb),
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

revoke all on function public.load_owned_print_checkout_context(uuid,bigint) from public,anon,authenticated;
grant execute on function public.load_owned_print_checkout_context(uuid,bigint) to service_role;

revoke all on function public.prepare_production_print_checkout(uuid,uuid,bigint,text,text,text,integer,integer,jsonb) from public,anon,authenticated;
grant execute on function public.prepare_production_print_checkout(uuid,uuid,bigint,text,text,text,integer,integer,jsonb) to service_role;

revoke all on function public.get_owned_print_checkout(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.get_owned_print_checkout(uuid,text,uuid) to service_role;

revoke all on function public.commit_production_print_payment(uuid,text,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.commit_production_print_payment(uuid,text,jsonb,boolean) to service_role;

revoke all on function public.claim_print_app_pdf_fulfillment_job(uuid,integer,integer,boolean) from public,anon,authenticated;
grant execute on function public.claim_print_app_pdf_fulfillment_job(uuid,integer,integer,boolean) to service_role;

revoke all on function public.record_print_order_scheduler_heartbeat(boolean) from public,anon,authenticated;
grant execute on function public.record_print_order_scheduler_heartbeat(boolean) to service_role;

revoke all on function public.claim_abandoned_print_prepayment_packages(integer) from public,anon,authenticated;
grant execute on function public.claim_abandoned_print_prepayment_packages(integer) to service_role;

revoke all on function public.finish_abandoned_print_prepayment_package(uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_abandoned_print_prepayment_package(uuid,boolean) to service_role;

revoke all on function public.read_print_sales_readiness(text,text) from public,anon,authenticated;
grant execute on function public.read_print_sales_readiness(text,text) to service_role;

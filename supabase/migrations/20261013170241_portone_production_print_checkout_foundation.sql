-- Software foundation only: every operational approval starts closed.
create schema if not exists private;
create table private.print_sales_configuration (
  id boolean primary key default true check(id), enabled boolean not null default false,
  business_ready boolean not null default false, portone_live_ready boolean not null default false,
  redprinting_live_ready boolean not null default false, renderer_ready boolean not null default false,
  fulfillment_ready boolean not null default false, environment text not null default 'disabled' check(environment in ('disabled','live')),
  store_id text not null default '', channel_key text not null default '', worker_last_seen_at timestamptz,
  updated_at timestamptz not null default now()
);
insert into private.print_sales_configuration(id) values(true);
create table private.print_sales_combinations (
  product_id text not null, page_count integer not null check(page_count between 20 and 80 and page_count%2=0),
  final_price integer check(final_price>0), price_version text not null default '',
  retail_final boolean not null default false, supplier_cost_confirmed boolean not null default false,
  shipping_confirmed boolean not null default false, packaging_confirmed boolean not null default false,
  spec_approved boolean not null default false, file_approved boolean not null default false,
  sample_approved boolean not null default false, order_code text not null default '',
  approved_spec jsonb, cost_snapshot jsonb, approval_evidence text not null default '',
  primary key(product_id,page_count)
);
create table private.print_checkout_intents (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id), request_id uuid not null,
  payment_id text not null unique default ('SFP_'||gen_random_uuid()::text),
  order_id text not null unique default ('ordp_'||gen_random_uuid()::text), album_id bigint not null,
  request_fingerprint text not null, source_digest text not null, reviewed_revision text not null, reviewed_spec_revision text not null, delivery_snapshot jsonb not null,
  snapshot jsonb not null, product jsonb not null, approved_spec jsonb not null, cost_snapshot jsonb not null,
  source_asset_owners uuid[] not null, order_code text not null, store_id text not null, channel_key text not null,
  amount integer not null check(amount>0), page_count integer not null check(page_count between 20 and 80 and page_count%2=0),
  environment text not null default 'live' check(environment='live'), currency text not null default 'KRW' check(currency='KRW'),
  status text not null default 'PREPARED' check(status in ('PREPARED','PAID','FAILED','CANCELED')),
  payment_receipt jsonb, verified_at timestamptz, expires_at timestamptz not null default(now()+interval '24 hours'),
  last_checked_at timestamptz, next_check_at timestamptz not null default now(), created_at timestamptz not null default now(),
  unique(user_id,request_id),
  foreign key(order_id) references public.orders(order_id) deferrable initially deferred,
  check((status='PREPARED' and payment_receipt is null and verified_at is null)
    or(status<>'PREPARED' and payment_receipt is not null and verified_at is not null))
);
create unique index print_checkout_transaction_unique on private.print_checkout_intents((payment_receipt->>'transactionId'))
  where payment_receipt is not null;
create index print_pending_payment_rechecks on private.print_checkout_intents(next_check_at,id) where status='PREPARED';
create table private.print_fulfillment_outbox (
  id uuid primary key default gen_random_uuid(), order_id text not null unique references public.orders(order_id),
  event_type text not null default 'RENDER' check(event_type in ('RENDER','SUBMIT','CONFIRM','POLL')),
  state text not null default 'PENDING' check(state in ('PENDING','CLAIMED','UNKNOWN','DONE','FAILED')),
  payload jsonb not null default '{}'::jsonb, attempts integer not null default 0,
  available_at timestamptz not null default now(), lease_owner uuid, lease_until timestamptz,
  last_error_code text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index print_fulfillment_available_jobs on private.print_fulfillment_outbox(available_at,id) where state in('PENDING','UNKNOWN','CLAIMED');
alter table public.orders add column checkout_flow text;
alter table public.orders add column payment_environment text check(payment_environment is null or payment_environment='live');
alter table public.orders add column print_file_checked_at timestamptz;
alter table public.orders add column print_spec_snapshot jsonb;
alter table public.orders add column print_requires_action boolean not null default false;
alter table public.orders add constraint orders_checkout_flow check(checkout_flow is null or checkout_flow='PORTONE_V2_V1');
alter table private.print_sales_configuration enable row level security;
alter table private.print_sales_combinations enable row level security;
alter table private.print_checkout_intents enable row level security;
alter table private.print_fulfillment_outbox enable row level security;
revoke all on private.print_sales_configuration,private.print_sales_combinations,private.print_checkout_intents,private.print_fulfillment_outbox
  from public,anon,authenticated,service_role;
grant usage on schema private to service_role;
grant select,insert,update on private.print_sales_configuration,private.print_sales_combinations,private.print_checkout_intents,private.print_fulfillment_outbox to service_role;
-- Actor is authenticated by Edge getUser before this service-only RPC.
grant execute on function public.get_print_order_quote(bigint,integer) to service_role;

create function public.load_owned_print_checkout_context(p_actor uuid,p_album_id bigint)
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
    and c.environment='live' and c.store_id<>'' and c.channel_key<>'' and c.worker_last_seen_at>now()-interval '5 minutes'
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
    'quote',q,'canPay',ready,'configuration',to_jsonb(c),'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners));
end;$$;
revoke all on function public.load_owned_print_checkout_context(uuid,bigint) from public,anon,authenticated;
grant execute on function public.load_owned_print_checkout_context(uuid,bigint) to service_role;

create function private.guard_print_checkout_intent() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if row(new.id,new.user_id,new.request_id,new.payment_id,new.order_id,new.album_id,new.request_fingerprint,new.source_digest,new.reviewed_revision,new.reviewed_spec_revision,
    new.snapshot,new.product,new.approved_spec,new.cost_snapshot,new.source_asset_owners,new.order_code,new.store_id,new.channel_key,new.delivery_snapshot,
    new.amount,new.page_count,new.environment,new.currency,new.expires_at,new.created_at)
    is distinct from row(old.id,old.user_id,old.request_id,old.payment_id,old.order_id,old.album_id,old.request_fingerprint,old.source_digest,old.reviewed_revision,old.reviewed_spec_revision,
    old.snapshot,old.product,old.approved_spec,old.cost_snapshot,old.source_asset_owners,old.order_code,old.store_id,old.channel_key,old.delivery_snapshot,
    old.amount,old.page_count,old.environment,old.currency,old.expires_at,old.created_at) then
    raise exception 'print_checkout_immutable' using errcode='23514'; end if;
  if old.status<>'PREPARED' and row(new.status,new.payment_receipt,new.verified_at) is distinct from row(old.status,old.payment_receipt,old.verified_at) then
    raise exception 'print_checkout_receipt_immutable' using errcode='23514'; end if;
  return new;
end;$$;
revoke all on function private.guard_print_checkout_intent() from public,anon,authenticated;
create trigger print_checkout_intent_guard before update on private.print_checkout_intents for each row execute function private.guard_print_checkout_intent();

create function public.prepare_production_print_checkout(p_actor uuid,p_request_id uuid,p_album_id bigint,p_source_digest text,
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
    snapshot,product,approved_spec,cost_snapshot,source_asset_owners,order_code,store_id,channel_key,amount,page_count)
  values(p_actor,p_request_id,p_album_id,fp,p_source_digest,p_reviewed_revision,p_reviewed_spec_revision,p_recipient,
    (ctx->'snapshot')||jsonb_build_object('printProduct',q->'printProduct'),q->'printProduct',combo->'approved_spec',combo->'cost_snapshot',
    array(select jsonb_array_elements_text(ctx->'allowedAssetOwners')::uuid),combo->>'order_code',c->>'store_id',c->>'channel_key',p_expected_amount,p_page_count)
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
revoke all on function public.prepare_production_print_checkout(uuid,uuid,bigint,text,text,text,integer,integer,jsonb) from public,anon,authenticated;
grant execute on function public.prepare_production_print_checkout(uuid,uuid,bigint,text,text,text,integer,integer,jsonb) to service_role;

create function public.get_owned_print_checkout(p_actor uuid,p_payment_id text default null,p_request_id uuid default null)
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
    and c.environment='live' and c.store_id=i.store_id and c.channel_key=i.channel_key and c.worker_last_seen_at>now()-interval '5 minutes'
    and combo.spec_approved and combo.file_approved and combo.sample_approved and combo.retail_final and combo.supplier_cost_confirmed
    and combo.shipping_confirmed and combo.packaging_confirmed and combo.approved_spec=i.approved_spec
    and combo.cost_snapshot=i.cost_snapshot and combo.order_code=i.order_code,false);
  return to_jsonb(i)||jsonb_build_object('launch_ready',launch_ready);
end;$$;
revoke all on function public.get_owned_print_checkout(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.get_owned_print_checkout(uuid,text,uuid) to service_role;

-- New paid transitions require an immutable LIVE receipt in a matching private
-- intent. Historical orders retain their old transitions and payment evidence.
create or replace function public.guard_print_order_update() returns trigger language plpgsql set search_path='' as $$
declare valid_paid boolean;
begin
  if tg_op='INSERT' then
    if new.status is distinct from 'PAYMENT_PENDING' or new.verified_payment_id is not null or new.verified_payment_provider is not null
      or new.payment_confirmed_at is not null or new.payment_reversed_at is not null or new.payment_reversal_status is not null then
      raise exception 'physical_order_payments_disabled' using errcode='23514';end if;
    if new.checkout_flow is not null and not exists(select 1 from private.print_checkout_intents i
      where i.order_id=new.order_id and i.user_id=new.user_id and i.amount=new.amount and i.snapshot=new.print_content_snapshot) then
      raise exception 'print_checkout_required' using errcode='23514';end if;
    return new;
  end if;
  if row(new.user_id,coalesce(new.album_id,old.album_id),new.amount,new.page_count,new.payment_method,new.pricing_version,
    new.payment_currency,new.print_content_snapshot,new.checkout_flow,new.payment_environment)
    is distinct from row(old.user_id,old.album_id,old.amount,old.page_count,old.payment_method,old.pricing_version,
    old.payment_currency,old.print_content_snapshot,old.checkout_flow,old.payment_environment) then
    raise exception 'order_purchase_details_immutable' using errcode='23514';end if;
  if old.checkout_flow='PORTONE_V2_V1' and row(new.recipient_name,new.recipient_phone,new.zip_code,new.address_line1,new.address_line2,
    new.delivery_memo,new.print_spec_override,new.print_spec_snapshot) is distinct from row(old.recipient_name,old.recipient_phone,old.zip_code,old.address_line1,
    old.address_line2,old.delivery_memo,old.print_spec_override,old.print_spec_snapshot) then raise exception 'order_purchase_details_immutable' using errcode='23514';end if;
  valid_paid:=old.checkout_flow='PORTONE_V2_V1' and old.status='PAYMENT_PENDING' and new.status='PAYMENT_COMPLETED'
    and new.pricing_version='PRINT_REDP_COVERTYPE_V3' and new.payment_environment='live' and new.payment_reversed_at is null
    and exists(select 1 from private.print_checkout_intents i where i.order_id=new.order_id and i.user_id=new.user_id
      and i.status='PAID' and i.environment='live' and i.amount=new.amount and i.snapshot=new.print_content_snapshot
      and i.payment_id=new.verified_payment_id and new.verified_payment_provider='PORTONE'
      and i.verified_at=new.payment_confirmed_at and i.payment_receipt->>'status'='PAID'
      and i.payment_receipt->>'environment'='live' and i.payment_receipt->'isTest'='false'::jsonb);
  if row(new.verified_payment_id,new.verified_payment_provider,new.payment_confirmed_at,new.payment_reversed_at,new.payment_reversal_status)
    is distinct from row(old.verified_payment_id,old.verified_payment_provider,old.payment_confirmed_at,old.payment_reversed_at,old.payment_reversal_status)
    and not coalesce(valid_paid,false) then raise exception 'physical_order_payments_disabled' using errcode='23514';end if;
  if new.status is distinct from old.status then
    if not (coalesce(valid_paid,false) or (old.status='PAYMENT_PENDING' and new.status='CANCELED')
      or(old.status='PAYMENT_COMPLETED' and new.status in('IN_PRODUCTION','CANCELED'))
      or(old.status in('IN_PRODUCTION','PRINTING') and new.status='SHIPPING') or(old.status='SHIPPING' and new.status='DELIVERED')) then
      raise exception 'invalid_order_status_transition' using errcode='23514';end if;
    if new.status in('IN_PRODUCTION','SHIPPING','DELIVERED') and (old.payment_reversed_at is not null
      or coalesce(btrim(old.verified_payment_id),'')='' or coalesce(btrim(old.verified_payment_provider),'')='' or old.payment_confirmed_at is null) then
      raise exception 'verified_payment_required' using errcode='23514';end if;
  end if;
  return new;
end;$$;

create function public.commit_production_print_payment(p_actor uuid,p_payment_id text,p_receipt jsonb,p_unpaid boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents; v_state text;
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
    insert into private.print_fulfillment_outbox(order_id,payload) values(i.order_id,
      jsonb_build_object('vendorOrderNum','SFO_'||replace(i.id::text,'-',''),'vendorOrderSeq',1,'queryOnly',false))
      on conflict(order_id) do nothing;
  else update public.orders set status='CANCELED' where order_id=i.order_id;end if;
  return to_jsonb(i);
end;$$;
revoke all on function public.commit_production_print_payment(uuid,text,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.commit_production_print_payment(uuid,text,jsonb,boolean) to service_role;

create function public.claim_production_print_payment_rechecks(p_limit integer default 3)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if p_limit<1 or p_limit>3 then raise exception 'invalid_recheck_limit' using errcode='22023';end if;
  with ready as (select id from private.print_checkout_intents where status='PREPARED' and next_check_at<=now()
    order by next_check_at for update skip locked limit p_limit), claimed as (
    update private.print_checkout_intents i set last_checked_at=now(),next_check_at=now()+interval '1 minute'
    from ready where i.id=ready.id returning i.user_id,i.payment_id)
  select coalesce(jsonb_agg(to_jsonb(claimed)),'[]') into result from claimed;
  return result;
end;$$;
revoke all on function public.claim_production_print_payment_rechecks(integer) from public,anon,authenticated;
grant execute on function public.claim_production_print_payment_rechecks(integer) to service_role;

create function private.print_intent_approval_current(p_intent uuid) returns boolean language sql stable security invoker set search_path='' as $$
  select exists(select 1 from private.print_checkout_intents i join private.print_sales_combinations c
    on c.product_id=i.product->>'id' and c.page_count=i.page_count where i.id=p_intent
    and c.retail_final and c.supplier_cost_confirmed and c.shipping_confirmed and c.packaging_confirmed
    and c.spec_approved and c.file_approved and c.sample_approved and c.approved_spec=i.approved_spec
    and c.order_code=i.order_code and c.cost_snapshot=i.cost_snapshot);
$$;
revoke all on function private.print_intent_approval_current(uuid) from public,anon,authenticated;
grant execute on function private.print_intent_approval_current(uuid) to service_role;

create function public.claim_print_fulfillment_job(p_worker_id uuid,p_limit integer default 1,p_lease_seconds integer default 120,p_runtime_ready boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;i private.print_checkout_intents;o public.orders;c private.print_sales_configuration;
begin
  if p_worker_id is null or p_limit<>1 or p_lease_seconds not between 30 and 300 then raise exception 'invalid_worker_claim' using errcode='22023';end if;
  update private.print_sales_configuration set worker_last_seen_at=case when p_runtime_ready is true then now() else null end where id=true returning * into c;
  if p_runtime_ready is not true then return null;end if;
  if not(c.enabled and c.business_ready and c.portone_live_ready and c.redprinting_live_ready and c.renderer_ready and c.fulfillment_ready and c.environment='live') then return null;end if;
  select job.* into j from private.print_fulfillment_outbox job join public.orders ord on ord.order_id=job.order_id
    join private.print_checkout_intents intent on intent.order_id=job.order_id
    where job.available_at<=now() and (job.state in('PENDING','UNKNOWN') or(job.state='CLAIMED' and job.lease_until<now()))
      and intent.status='PAID' and intent.environment='live' and intent.payment_receipt->'isTest'='false'::jsonb
      and ord.status in('PAYMENT_COMPLETED','IN_PRODUCTION','PRINTING','SHIPPING') and ord.payment_reversed_at is null
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
create function public.renew_print_fulfillment_job(p_id uuid,p_owner uuid,p_lease_seconds integer default 120,p_runtime_ready boolean default false)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare until_at timestamptz;
begin
  if p_lease_seconds not between 30 and 300 then raise exception 'invalid_worker_claim' using errcode='22023';end if;
  if p_runtime_ready is not true then update private.print_sales_configuration set worker_last_seen_at=null where id=true;return null;end if;
  if not exists(select 1 from public.orders where order_id=(select order_id from private.print_fulfillment_outbox where id=p_id)
    and print_package_lock_token=p_owner and print_package_lock_until>now()) then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  update private.print_fulfillment_outbox set lease_until=now()+make_interval(secs=>p_lease_seconds),updated_at=now()
    where id=p_id and lease_owner=p_owner and state='CLAIMED' and lease_until>now() returning lease_until into until_at;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  update private.print_sales_configuration set worker_last_seen_at=now() where id=true;
  update public.orders set print_package_lock_until=until_at where order_id=(select order_id from private.print_fulfillment_outbox where id=p_id)
    and print_package_lock_token=p_owner;
  return until_at;
end;$$;
create function public.record_print_fulfillment_attempt(p_id uuid,p_owner uuid,p_vendor_order_num text,p_vendor_order_seq integer default 1)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;
begin
  select * into j from private.print_fulfillment_outbox where id=p_id and lease_owner=p_owner and lease_until>now()
    and state='CLAIMED' and event_type in('SUBMIT','CONFIRM') for update;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  if j.payload->>'vendorOrderNum' is distinct from p_vendor_order_num or (j.payload->>'vendorOrderSeq')::integer is distinct from p_vendor_order_seq then
    raise exception 'print_vendor_identity_changed' using errcode='23514';end if;
  if not exists(select 1 from public.orders where order_id=j.order_id and print_package_lock_token=p_owner and print_package_lock_until>now()) then
    raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  update private.print_fulfillment_outbox set payload=payload||jsonb_build_object('queryOnly',true,'supplierAttemptedAt',now())
    ||case when event_type='CONFIRM' then jsonb_build_object('depositAttempted',true) else '{}'::jsonb end,updated_at=now()
    where id=j.id returning * into j;
  return to_jsonb(j);
end;$$;
create function public.commit_print_fulfillment_submission(p_id uuid,p_owner uuid,p_vendor_order_id text,p_operations_patch jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;i private.print_checkout_intents;o public.orders;confirmation jsonb;
begin
  select * into j from private.print_fulfillment_outbox where id=p_id and lease_owner=p_owner and lease_until>now()
    and state='CLAIMED' and event_type in('SUBMIT','CONFIRM','POLL') for update;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  select * into strict i from private.print_checkout_intents where order_id=j.order_id;
  select * into strict o from public.orders where order_id=j.order_id for update;
  if o.print_package_lock_token is distinct from p_owner or o.print_package_lock_until is null or o.print_package_lock_until<=now() or i.status<>'PAID'
    or not private.print_intent_approval_current(i.id)
    or i.payment_receipt->>'environment' is distinct from 'live' or i.payment_receipt->'isTest' is distinct from 'false'::jsonb
    or j.payload->>'queryOnly' is distinct from 'true' or j.payload->>'vendorOrderNum' is distinct from 'SFO_'||replace(i.id::text,'-','')
    or p_vendor_order_id is distinct from j.payload->>'vendorOrderNum' then raise exception 'print_worker_submission_invalid' using errcode='23514';end if;
  if o.print_fulfillment_status in('SUBMITTED','ACCEPTED') then
    if o.print_vendor_order_id=p_vendor_order_id then return to_jsonb(o);end if;
    raise exception 'print_vendor_identity_changed' using errcode='23514';end if;
  confirmation:=i.cost_snapshot->'fulfillmentConfirmation';
  if confirmation->>'senderName' is distinct from '스냅핏' or confirmation->'senderLabelConfirmed' is distinct from 'true'::jsonb
    or confirmation->'priceSlipOmittedConfirmed' is distinct from 'true'::jsonb or confirmation->'promotionalMaterialsOmittedConfirmed' is distinct from 'true'::jsonb
    or length(coalesce(confirmation->>'evidence',''))<10 or p_operations_patch->'fulfillment_confirmation' is distinct from confirmation
    or p_operations_patch->'actual_print_cost' is distinct from i.cost_snapshot->'estimatedPrintCost'
    or p_operations_patch->'actual_shipping_cost' is distinct from i.cost_snapshot->'estimatedShippingCost'
    or p_operations_patch->'actual_packaging_cost' is distinct from i.cost_snapshot->'estimatedPackagingCost' then
    raise exception 'print_worker_supply_quote_changed' using errcode='23514';end if;
  return public.submit_print_vendor(j.order_id,jsonb_build_object('print_vendor_order_id',p_vendor_order_id,'fulfillment_method','DIRECT',
    'sender_label_confirmed',true,'price_slip_omitted_confirmed',true,'promotional_materials_omitted_confirmed',true),p_operations_patch);
end;$$;
create function public.finish_print_fulfillment_job(p_id uuid,p_owner uuid,p_expected_stage text,p_result jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;next_stage text;available timestamptz;
begin
  select * into j from private.print_fulfillment_outbox where id=p_id and lease_owner=p_owner and lease_until>now()
    and state='CLAIMED' and event_type=p_expected_stage for update;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  next_stage:=p_result->>'nextStage';available:=coalesce((p_result->>'availableAt')::timestamptz,now());
  if jsonb_typeof(p_result) is distinct from 'object' or p_result-array['nextStage','availableAt','queryOnly','vendorOrderNum','vendorOrderSeq','vendorOrderId',
      'customerStage','supplierStatus','fileCheckedAt','depositAttempted']<>'{}'::jsonb
    or not((j.event_type='RENDER' and next_stage='SUBMIT') or(j.event_type='SUBMIT' and next_stage in('SUBMIT','CONFIRM','POLL'))
      or(j.event_type='CONFIRM' and next_stage in('CONFIRM','POLL')) or(j.event_type='POLL' and next_stage in('POLL','CONFIRM','DONE'))) then
    raise exception 'invalid_print_worker_transition' using errcode='23514';end if;
  if p_result?'vendorOrderNum' and p_result->>'vendorOrderNum' is distinct from j.payload->>'vendorOrderNum' then
    raise exception 'print_vendor_identity_changed' using errcode='23514';end if;
  if p_result?'vendorOrderSeq' and p_result->'vendorOrderSeq' is distinct from j.payload->'vendorOrderSeq' then
    raise exception 'print_vendor_identity_changed' using errcode='23514';end if;
  if j.payload->'depositAttempted'='true'::jsonb and p_result?'depositAttempted' and p_result->'depositAttempted' is distinct from 'true'::jsonb then
    raise exception 'print_deposit_attempt_immutable' using errcode='23514';end if;
  if (p_result?'customerStage' and p_result->>'customerStage' not in('PAYMENT_PENDING','PAID','RENDERING','FILE_CHECKING','PRODUCTION','SHIPPING','DELIVERED','REVIEW_REQUIRED'))
    or(p_result?'supplierStatus' and p_result->>'supplierStatus' !~ '^[A-Za-z0-9_]{1,40}$')
    or(p_result?'depositAttempted' and jsonb_typeof(p_result->'depositAttempted') is distinct from 'boolean') then
    raise exception 'invalid_print_worker_result' using errcode='23514';end if;
  if j.event_type='RENDER' and not exists(select 1 from public.orders where order_id=j.order_id and print_fulfillment_status='READY'
    and print_cover_pdf_path is not null and print_interior_pdf_path is not null and print_spec_confirmed_at is not null) then
    raise exception 'print_files_not_ready' using errcode='23514';end if;
  if next_stage='DONE' and not exists(select 1 from public.orders where order_id=j.order_id and status='DELIVERED') then
    raise exception 'print_delivery_not_confirmed' using errcode='23514';end if;
  update private.print_fulfillment_outbox set event_type=case when next_stage='DONE' then event_type else next_stage end,
    state=case when next_stage='DONE' then 'DONE' else 'PENDING' end,payload=payload||(p_result-array['nextStage','availableAt']),
    available_at=available,lease_owner=null,lease_until=null,last_error_code=null,updated_at=now() where id=j.id returning * into j;
  update public.orders set print_package_lock_token=null,print_package_lock_until=null,print_requires_action=false where order_id=j.order_id and print_package_lock_token=p_owner;
  return to_jsonb(j);
end;$$;
create function public.fail_print_fulfillment_job(p_id uuid,p_owner uuid,p_error_code text,p_available_at timestamptz,p_terminal boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;attempted boolean;
begin
  if p_error_code !~ '^[a-z0-9_]{1,80}$' then raise exception 'invalid_worker_error' using errcode='22023';end if;
  select * into j from private.print_fulfillment_outbox where id=p_id and lease_owner=p_owner and lease_until>now() and state='CLAIMED' for update;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  attempted:=coalesce(j.payload->'queryOnly'='true'::jsonb
    or(j.event_type='SUBMIT' and j.payload?'supplierAttemptedAt') or(j.event_type='CONFIRM' and j.payload->'depositAttempted'='true'::jsonb),false);
  update private.print_fulfillment_outbox set state=case when p_terminal then 'FAILED' when event_type in('SUBMIT','CONFIRM') and attempted then 'UNKNOWN' else 'PENDING' end,
    payload=case when event_type in('SUBMIT','CONFIRM') and attempted then payload||jsonb_build_object('queryOnly',true) else payload end,
    available_at=greatest(coalesce(p_available_at,now()+interval '1 minute'),now()),last_error_code=p_error_code,
    lease_owner=null,lease_until=null,updated_at=now() where id=p_id and lease_owner=p_owner and lease_until>now() and state='CLAIMED' returning * into j;
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  update public.orders set print_package_lock_token=null,print_package_lock_until=null,print_requires_action=p_terminal where order_id=j.order_id and print_package_lock_token=p_owner;
  return to_jsonb(j);
end;$$;
create function public.get_print_fulfillment_job(p_id uuid,p_owner uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare j private.print_fulfillment_outbox;i private.print_checkout_intents;o public.orders;
begin
  select * into j from private.print_fulfillment_outbox where id=p_id and lease_owner=p_owner and lease_until>now() and state='CLAIMED';
  if not found then raise exception 'print_worker_lease_lost' using errcode='23514';end if;
  select * into strict i from private.print_checkout_intents where order_id=j.order_id;
  select * into strict o from public.orders where order_id=j.order_id;
  return jsonb_build_object('job',to_jsonb(j),'order',to_jsonb(o),'approvedSpec',i.approved_spec,'orderCode',i.order_code,
    'sourceFingerprint',i.reviewed_revision,'allowedAssetOwners',to_jsonb(i.source_asset_owners),'paymentEnvironment',i.payment_receipt->>'environment',
    'approvalCurrent',private.print_intent_approval_current(i.id),'costSnapshot',i.cost_snapshot,'paymentExpectation',jsonb_build_object('paymentId',i.payment_id,'storeId',i.store_id,'channelKey',i.channel_key,
      'amount',i.amount,'currency','KRW','environment','live'));
end;$$;
create function public.list_print_fulfillment_jobs(p_limit integer default 50,p_order_id text default null) returns jsonb language sql stable security invoker set search_path='' as $$
  select coalesce(jsonb_agg(to_jsonb(j)),'[]') from(select id,order_id,event_type,state,attempts,available_at,lease_until,last_error_code,updated_at
    from private.print_fulfillment_outbox where p_order_id is null or order_id=p_order_id
    order by updated_at desc limit greatest(1,least(p_limit,100)))j;
$$;
revoke all on function public.claim_print_fulfillment_job(uuid,integer,integer,boolean),public.renew_print_fulfillment_job(uuid,uuid,integer,boolean),
  public.record_print_fulfillment_attempt(uuid,uuid,text,integer),public.finish_print_fulfillment_job(uuid,uuid,text,jsonb),
  public.fail_print_fulfillment_job(uuid,uuid,text,timestamptz,boolean),public.get_print_fulfillment_job(uuid,uuid),public.list_print_fulfillment_jobs(integer,text),
  public.commit_print_fulfillment_submission(uuid,uuid,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.claim_print_fulfillment_job(uuid,integer,integer,boolean),public.renew_print_fulfillment_job(uuid,uuid,integer,boolean),
  public.record_print_fulfillment_attempt(uuid,uuid,text,integer),public.finish_print_fulfillment_job(uuid,uuid,text,jsonb),
  public.fail_print_fulfillment_job(uuid,uuid,text,timestamptz,boolean),public.get_print_fulfillment_job(uuid,uuid),public.list_print_fulfillment_jobs(integer,text),
  public.commit_print_fulfillment_submission(uuid,uuid,text,jsonb) to service_role;

-- Private worker state is exposed only as sanitized progress for its purchaser.
create function public.fetch_my_print_order_progress(p_order_id text) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare o public.orders;stage text;preflight boolean;submitted boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501';end if;
  select * into o from public.orders where order_id=p_order_id and user_id=auth.uid();
  if not found then raise exception 'order_access_denied' using errcode='42501';end if;
  preflight:=coalesce(o.print_manifest->'cover'->>'sha256' ~ '^[a-f0-9]{64}$' and o.print_manifest->'interior'->>'sha256' ~ '^[a-f0-9]{64}$'
    and o.print_manifest->>'sourceFingerprint'=o.print_upload_fingerprint
    and o.print_manifest->'spec'->>'specVersion'=o.print_spec_snapshot->>'specVersion'
    and o.print_manifest->'cover'->'pageCount'='1'::jsonb and o.print_manifest->'interior'->>'pageCount'=o.page_count::text
    and o.print_spec_confirmed_at is not null and o.print_cover_pdf_path is not null and o.print_interior_pdf_path is not null,false);
  submitted:=coalesce(o.print_fulfillment_status in('SUBMITTED','ACCEPTED') and o.print_vendor='REDPRINTING'
    and coalesce(btrim(o.print_vendor_order_id),'')<>'' and o.print_vendor_order_id !~* '^(SPP-|TEST|DEMO)' and o.print_submitted_at is not null,false);
  stage:=case when o.status='CANCELED' then 'CANCELED' when o.status='DELIVERED' then 'DELIVERED' when o.status='SHIPPING' then 'SHIPPING'
    when o.status in('IN_PRODUCTION','PRINTING') then 'PRODUCTION' when o.status='PAYMENT_PENDING' then 'PAYMENT_PENDING'
    when o.print_requires_action then 'REVIEW_REQUIRED' when o.print_file_checked_at is not null and submitted then 'PRODUCTION_PENDING'
    when o.print_fulfillment_status='RENDERING' then 'RENDERING'
    when o.print_fulfillment_status in('SUBMITTED','READY','REVIEW_REQUIRED') then 'FILE_CHECKING' else 'PAID' end;
  return jsonb_build_object('orderId',o.order_id,'customerStage',stage,'preflightPassed',preflight,
    'filesReadyAt',case when preflight then o.print_package_generated_at end,'vendorAcceptedAt',case when submitted then o.print_submitted_at end,
    'fileCheckedAt',case when submitted then o.print_file_checked_at end,
    'productionStartedAt',case when o.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') then o.print_accepted_at end,
    'shippedAt',case when o.status in('SHIPPING','DELIVERED') then o.shipped_at end,
    'courier',o.courier,'trackingNumber',o.tracking_number,'requiresAction',o.print_requires_action);
end;$$;
revoke all on function public.fetch_my_print_order_progress(text) from public,anon;
grant execute on function public.fetch_my_print_order_progress(text) to authenticated;

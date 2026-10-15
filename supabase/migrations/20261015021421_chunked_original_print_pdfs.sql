-- Original PDF transport: each Storage object stays below Free's 50MB limit.
-- No re-encoding, DPI reduction, public bucket, sales activation or paid plan.
alter table private.print_prepayment_packages drop constraint print_prepayment_packages_max_file_bytes_check;
alter table private.print_prepayment_packages alter column max_file_bytes set default 500000000;
alter table private.print_prepayment_packages add constraint print_prepayment_packages_max_file_bytes_check check(max_file_bytes in(50000000,500000000));
alter table private.print_prepayment_packages add column transport_version text not null default 'DIRECT_V1' check(transport_version in('DIRECT_V1','CHUNKED_V1'));
alter table private.print_prepayment_packages add column file_parts jsonb not null default '{}'::jsonb;
alter table private.print_prepayment_packages add column part_results jsonb not null default '{}'::jsonb;

create function private.print_package_parts_verified(p_package uuid,p_kind text) returns boolean
language sql stable security invoker set search_path='' as $$
 select coalesce((select case when not(p.file_parts ? p_kind) then true else
  jsonb_typeof(p.file_parts->p_kind)='array' and jsonb_array_length(p.file_parts->p_kind)>0
  and jsonb_typeof(p.part_results->p_kind)='object'
  and(select count(*) from jsonb_object_keys(p.part_results->p_kind))=jsonb_array_length(p.file_parts->p_kind)
  and not exists(select 1 from jsonb_array_elements(p.file_parts->p_kind) d where
   p.part_results->p_kind->(d->>'index') is distinct from
    jsonb_build_object('index',d->'index','byteLength',d->'byteLength','sha256',d->'sha256')) end
 from private.print_prepayment_packages p where p.id=p_package),false);
$$;
revoke all on function private.print_package_parts_verified(uuid,text) from public,anon,authenticated;
grant execute on function private.print_package_parts_verified(uuid,text) to service_role;

create or replace function private.guard_print_prepayment_package() returns trigger language plpgsql security invoker set search_path='' as $$
declare kind text;v jsonb;n text;r jsonb;d jsonb;
begin
 if row(new.id,new.intent_id,new.source_fingerprint,new.spec_version,new.cover_path,new.interior_path,new.manifest_path,new.renderer_manifest,
  new.max_file_bytes,new.expires_at,new.created_at,new.transport_version,new.file_parts) is distinct from
  row(old.id,old.intent_id,old.source_fingerprint,old.spec_version,old.cover_path,old.interior_path,old.manifest_path,old.renderer_manifest,
  old.max_file_bytes,old.expires_at,old.created_at,old.transport_version,old.file_parts) then
  raise exception 'print_prepayment_immutable' using errcode='23514';end if;
 if(old.cover_result is not null and new.cover_result is distinct from old.cover_result)
  or(old.interior_result is not null and new.interior_result is distinct from old.interior_result)
  or(old.pdf_manifest is not null and new.pdf_manifest is distinct from old.pdf_manifest)
  or(old.verified_at is not null and new.verified_at is distinct from old.verified_at)
  or not(new.part_results @> old.part_results) then
   raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
 if jsonb_typeof(new.part_results)<>'object' then raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
 for kind,v in select * from jsonb_each(new.part_results) loop
  if kind not in('cover','interior') or jsonb_typeof(v)<>'object' then raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
  for n,r in select * from jsonb_each(v) loop
   if n !~ '^(0|[1-9][0-9]?)$' then raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   d:=new.file_parts->kind->(n::integer);
   if d is null or r is distinct from jsonb_build_object('index',d->'index','byteLength',d->'byteLength','sha256',d->'sha256') then
    raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
  end loop;
 end loop;
 if new.state is distinct from old.state and not((old.state='UPLOADING' and new.state in('FILES_VERIFIED','ABANDONED'))
  or(old.state='FILES_VERIFIED' and new.state in('READY','ABANDONED')) or(old.state='READY' and new.state='ABANDONED')
  or(old.state='ABANDONED' and new.state='CLEANING') or(old.state='CLEANING' and new.state in('CLEANING','ABANDONED','CLEANED'))) then
  raise exception 'print_prepayment_state_changed' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.guard_print_prepayment_package() from public,anon,authenticated;
create or replace function private.print_prepayment_ready(p_intent uuid) returns boolean
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
  and(p.cover_result->>'byteLength')::integer between 100 and least(p.max_file_bytes,150000000)
  and private.print_package_parts_verified(p.id,'cover') and private.print_package_parts_verified(p.id,'interior')
  and((p.transport_version='DIRECT_V1' and p.file_parts='{}'::jsonb) or(p.transport_version='CHUNKED_V1'
   and p.pdf_manifest->'fileTransport'=jsonb_build_object('version','CHUNKED_V1','files',p.file_parts)))
  and (p.interior_result->>'byteLength')::integer between 100 and p.max_file_bytes);
$$;
revoke all on function private.print_prepayment_ready(uuid) from public,anon,authenticated;
grant execute on function private.print_prepayment_ready(uuid) to service_role;


create or replace function public.print_prepayment_package(p_actor uuid,p_action text,p_request_id uuid,p_order_id text,p_payment_id text,
 p_package_id uuid default null,p_file_kind text default null,p_file_result jsonb default null,p_manifest jsonb default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents;o public.orders;p private.print_prepayment_packages; ops jsonb; held boolean;
 id_new uuid; kind text; declared jsonb;parts_new jsonb:='{}'::jsonb;part jsonb;part_index integer;part_count integer;file_bytes bigint;expected_bytes bigint;part_declaration jsonb; width_mm numeric;height_mm numeric;ready_manifest jsonb;
begin
 if p_actor is null or p_action not in('snapshot','status','uploads','verify_part','finalize','seal') then
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
   or p_manifest->'missingAssets' is distinct from '[]'::jsonb or jsonb_typeof(p_manifest->'warnings') is distinct from 'array' or p_manifest ? 'fileTransport'
   or length(p_manifest::text)>160000 then raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
  id_new:=coalesce(p.id,gen_random_uuid());
  for kind in select unnest(array['cover','interior']) loop
   declared:=p_manifest->'declaredFiles'->kind;
   if not coalesce(jsonb_typeof(declared->'bytes')='number' and declared->>'bytes' ~ '^[0-9]+$'
    and(declared->>'bytes')::bigint between 100 and case when kind='cover' then 150000000 else 500000000 end
    and declared->>'sha256' ~ '^[a-f0-9]{64}$' and declared-array['bytes','sha256','parts']='{}'::jsonb,false) then
    raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
   file_bytes:=(declared->>'bytes')::bigint;
   if file_bytes>50000000 then
    part_count:=((file_bytes+15999999)/16000000)::integer;
    if jsonb_typeof(declared->'parts') is distinct from 'array' or jsonb_array_length(declared->'parts')<>part_count then
     raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
    parts_new:=jsonb_set(parts_new,array[kind],'[]'::jsonb,true);
    for part_index in 0..part_count-1 loop
     part:=declared->'parts'->part_index;expected_bytes:=least(16000000,file_bytes-part_index::bigint*16000000);
     if not coalesce(part-array['bytes','sha256']='{}'::jsonb and part->'bytes'=to_jsonb(expected_bytes)
      and part->>'sha256' ~ '^[a-f0-9]{64}$',false) then
      raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
     part_declaration:=jsonb_build_object('index',part_index,'path',i.order_id||'/'||id_new::text||'/'||kind||'/part-'||lpad(part_index::text,3,'0')||'.bin',
      'byteLength',expected_bytes,'sha256',part->>'sha256');
     parts_new:=jsonb_set(parts_new,array[kind],(parts_new->kind)||jsonb_build_array(part_declaration),true);
    end loop;
   elsif declared ? 'parts' then raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
  end loop;
  if p.id is not null then
   if p.renderer_manifest is distinct from p_manifest or p.source_fingerprint is distinct from p_file_result->>'sourceFingerprint' then
    raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
  else
   insert into private.print_prepayment_packages(id,intent_id,source_fingerprint,spec_version,renderer_manifest,expires_at,
    cover_path,interior_path,manifest_path,file_parts,transport_version) values(id_new,i.id,p_file_result->>'sourceFingerprint',p_file_result->>'specVersion',p_manifest,i.expires_at,
    i.order_id||'/'||id_new::text||'/cover.pdf',i.order_id||'/'||id_new::text||'/interior.pdf',i.order_id||'/'||id_new::text||'/manifest.json',parts_new,case when parts_new='{}'::jsonb then 'DIRECT_V1' else 'CHUNKED_V1' end) returning * into p;
   update private.print_checkout_intents set prepayment_package_id=p.id where id=i.id returning * into i;
  end if;
 elsif p_action in('verify_part','finalize','seal') then
  if p.id is null or p.id is distinct from p_package_id then raise exception 'print_prepayment_not_found' using errcode='P0002';end if;
  if p.expires_at<=now() or p.state in('ABANDONED','CLEANING','CLEANED') then raise exception 'print_prepayment_expired' using errcode='23514';end if;
  if p_action='verify_part' then
   if p_file_kind not in('cover','interior') or p_manifest is distinct from p.renderer_manifest
    or jsonb_typeof(p_file_result->'index') is distinct from 'number' or coalesce(p_file_result->>'index','') !~ '^(0|[1-9][0-9]?)$' then
    raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   part_index:=(p_file_result->>'index')::integer;part:=p.file_parts->p_file_kind->part_index;
   if part is null or p_file_result is distinct from jsonb_build_object('index',part_index,'byteLength',part->'byteLength','sha256',part->'sha256') then
    raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   if p.part_results->p_file_kind->(part_index::text) is not null and p.part_results->p_file_kind->(part_index::text) is distinct from p_file_result then
    raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   update private.print_prepayment_packages set part_results=jsonb_set(part_results,array[p_file_kind],
    coalesce(part_results->p_file_kind,'{}'::jsonb)||jsonb_build_object(part_index::text,p_file_result),true) where id=p.id returning * into p;
  elsif p_action='finalize' then
   if not private.print_package_parts_verified(p.id,p_file_kind) then raise exception 'print_prepayment_parts_incomplete' using errcode='23514';end if;
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
     'cover',p.cover_result,'interior',p.interior_result,'generatedAt',now(),'vendorReady',false)||case when p.transport_version='CHUNKED_V1' then jsonb_build_object('fileTransport',jsonb_build_object('version','CHUNKED_V1','files',p.file_parts)) else '{}'::jsonb end;
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
create or replace function public.claim_abandoned_print_prepayment_packages(p_limit integer default 1)
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
 return jsonb_build_array(jsonb_build_object('id',p.id,'paths',jsonb_build_array(p.cover_path,p.interior_path,p.manifest_path)||coalesce((select jsonb_agg(v->>'path' order by k,v->>'index') from jsonb_each(p.file_parts) f(k,a) cross join lateral jsonb_array_elements(a) v),'[]'::jsonb)));
end;$$;
revoke all on function public.claim_abandoned_print_prepayment_packages(integer) from public,anon,authenticated;
grant execute on function public.claim_abandoned_print_prepayment_packages(integer) to service_role;

create function public.read_print_file_delivery(p_order_id text,p_package_id uuid,p_kind text)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare i private.print_checkout_intents;p private.print_prepayment_packages;o public.orders;r jsonb;
begin
 if p_kind not in('cover','interior') then raise exception 'print_file_not_found' using errcode='P0002';end if;
 select * into i from private.print_checkout_intents where order_id=p_order_id and prepayment_package_id=p_package_id;
 if not found then raise exception 'print_file_not_found' using errcode='P0002';end if;
 select * into p from private.print_prepayment_packages where id=p_package_id and intent_id=i.id;
 select * into o from public.orders where order_id=p_order_id;
 if p.id is null or o.order_id is null or i.status<>'PAID' or i.sdk_issued_at is null or i.environment<>'live'
  or i.payment_receipt->'isTest' is distinct from 'false'::jsonb or i.payment_receipt->>'environment' is distinct from 'live'
  or o.checkout_flow<>'PORTONE_V2_V1' or o.status not in('PAYMENT_COMPLETED','IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED')
  or o.verified_payment_id is distinct from i.payment_id or o.verified_payment_provider is distinct from 'PORTONE'
  or o.payment_reversed_at is not null or o.print_customer_request_hold or not private.print_prepayment_ready(i.id)
  or p.transport_version<>'CHUNKED_V1' or not(p.file_parts ? p_kind)
  or o.print_manifest is distinct from p.pdf_manifest or o.print_upload_id is distinct from p.id
  or o.print_cover_pdf_path is distinct from p.cover_path or o.print_interior_pdf_path is distinct from p.interior_path then
  raise exception 'print_file_not_found' using errcode='P0002';end if;
 r:=case when p_kind='cover' then p.cover_result else p.interior_result end;
 return jsonb_build_object('orderId',i.order_id,'packageId',p.id,'kind',p_kind,'result',r,'parts',p.file_parts->p_kind);
end;$$;
revoke all on function public.read_print_file_delivery(text,uuid,text) from public,anon,authenticated;
grant execute on function public.read_print_file_delivery(text,uuid,text) to service_role;

-- Parts are byte slices, not individual PDFs. Bucket remains private and the
-- actual Free object limit is unchanged; all chunks are at most 16,000,000 B.
update storage.buckets set allowed_mime_types=case when allowed_mime_types is null then null
 when 'application/octet-stream'=any(allowed_mime_types) then allowed_mime_types
 else array_append(allowed_mime_types,'application/octet-stream') end where id='print-packages';
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
    'quote',q,'canPay',ready,'filePreparationRequired',c.fulfillment_mode='APP_PDF_SUPABASE','maxFileBytes',500000000,'maxCoverFileBytes',150000000,'configuration',to_jsonb(c),'combination',to_jsonb(combo),'allowedAssetOwners',to_jsonb(owners));
end;$$;
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
      'fulfillmentMode',c.fulfillment_mode,'schedulerLastSeenAt',c.scheduler_last_seen_at,'maxPrepaymentFileBytes',500000000,'maxPrepaymentCoverBytes',150000000,'maxStorageObjectBytes',50000000,'printPartBytes',16000000) from private.print_sales_configuration c where c.id=true),'{}'::jsonb),
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

notify pgrst,'reload schema';

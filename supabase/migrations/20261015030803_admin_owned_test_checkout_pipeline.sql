-- Admin-owned end-to-end TEST checkout. Never inserts customer/LIVE orders.
create table private.print_dev_checkouts (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),request_id uuid not null,
 order_id text not null unique,payment_id text not null unique references private.print_payment_test_sessions(payment_id),
 album_id bigint not null,snapshot jsonb not null,product jsonb not null,spec jsonb not null,source_asset_owners uuid[] not null,
 reviewed_revision text not null check(reviewed_revision~'^[a-f0-9]{64}$'),reviewed_spec_revision text not null check(reviewed_spec_revision~'^[a-f0-9]{64}$'),
 source_digest text not null,order_code text not null,recipient jsonb not null,total_amount integer not null default 159900 check(total_amount=159900),
 currency text not null default 'KRW' check(currency='KRW'),environment text not null default 'test' check(environment='test'),
 status text not null default 'PREPARING' check(status in('PREPARING','READY','PAYMENT_VERIFIED','SUBMITTING','UNKNOWN','ACCEPTED','FILE_CHECKED','FAILED')),
 package_id uuid,sdk_issued_at timestamptz,vendor_status jsonb not null default '{}',vendor_result_id text,submitted_at timestamptz,last_status_at timestamptz,error_code text,
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '24 hours',unique(owner_id,request_id),
 check(order_id='ordp_'||id::text),check(product->>'id'='REDP_300_HARD' and spec->>'pageCount'='80' and spec->'verified'='false'::jsonb)
);
create table private.print_dev_packages (like private.print_prepayment_packages including defaults including constraints);
alter table private.print_dev_packages rename column intent_id to checkout_id;
alter table private.print_dev_packages add primary key(id);
alter table private.print_dev_packages add unique(checkout_id);
alter table private.print_dev_packages add foreign key(checkout_id) references private.print_dev_checkouts(id);
alter table private.print_dev_checkouts add foreign key(package_id) references private.print_dev_packages(id) deferrable initially deferred;
create table private.print_dev_fulfillment_outbox (
 id uuid primary key default gen_random_uuid(),checkout_id uuid not null unique references private.print_dev_checkouts(id),
 event_type text not null default 'PAYMENT' check(event_type in('PAYMENT','SUBMIT','POLL')),
 state text not null default 'PENDING' check(state in('PENDING','CLAIMED','UNKNOWN','DONE','FAILED')),
 lease_owner uuid,lease_until timestamptz,available_at timestamptz not null default now(),attempts integer not null default 0,
 last_error_code text,payload jsonb not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create index print_dev_outbox_pending on private.print_dev_fulfillment_outbox(available_at) where state in('PENDING','UNKNOWN','CLAIMED');
alter table private.print_dev_checkouts enable row level security;
alter table private.print_dev_packages enable row level security;
alter table private.print_dev_fulfillment_outbox enable row level security;
revoke all on private.print_dev_checkouts,private.print_dev_packages,private.print_dev_fulfillment_outbox from public,anon,authenticated,service_role;
grant select,insert,update on private.print_dev_checkouts,private.print_dev_packages,private.print_dev_fulfillment_outbox to service_role;
create function private.print_dev_parts_verified(p_package uuid,p_kind text) returns boolean
language sql stable security invoker set search_path='' as $$
 select coalesce((select case when not(p.file_parts ? p_kind) then true else
  jsonb_typeof(p.file_parts->p_kind)='array' and jsonb_array_length(p.file_parts->p_kind)>0
  and jsonb_typeof(p.part_results->p_kind)='object'
  and(select count(*) from jsonb_object_keys(p.part_results->p_kind))=jsonb_array_length(p.file_parts->p_kind)
  and not exists(select 1 from jsonb_array_elements(p.file_parts->p_kind) d where
   p.part_results->p_kind->(d->>'index') is distinct from
    jsonb_build_object('index',d->'index','byteLength',d->'byteLength','sha256',d->'sha256')) end
 from private.print_dev_packages p where p.id=p_package),false);
$$;
revoke all on function private.print_dev_parts_verified(uuid,text) from public,anon,authenticated;
grant execute on function private.print_dev_parts_verified(uuid,text) to service_role;

create or replace function private.guard_print_dev_package() returns trigger language plpgsql security invoker set search_path='' as $$
declare kind text;v jsonb;n text;r jsonb;d jsonb;
begin
 if row(new.id,new.checkout_id,new.source_fingerprint,new.spec_version,new.cover_path,new.interior_path,new.manifest_path,new.renderer_manifest,
  new.max_file_bytes,new.expires_at,new.created_at,new.transport_version,new.file_parts) is distinct from
  row(old.id,old.checkout_id,old.source_fingerprint,old.spec_version,old.cover_path,old.interior_path,old.manifest_path,old.renderer_manifest,
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
revoke all on function private.guard_print_dev_package() from public,anon,authenticated;
create trigger print_dev_package_guard before update on private.print_dev_packages for each row execute function private.guard_print_dev_package();
create function private.print_dev_ready(p_checkout uuid) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from private.print_dev_checkouts c join private.print_dev_packages p on p.checkout_id=c.id and p.id=c.package_id where c.id=p_checkout
 and p.state='READY' and p.spec_version=c.spec->>'specVersion' and p.pdf_manifest->'spec'=c.spec
 and p.cover_path=c.order_id||'/'||p.id::text||'/cover.pdf' and p.interior_path=c.order_id||'/'||p.id::text||'/interior.pdf'
 and p.manifest_path=c.order_id||'/'||p.id::text||'/manifest.json' and p.verified_at is not null
 and p.pdf_manifest->>'sourceFingerprint'=p.source_fingerprint and p.pdf_manifest->'cover'=p.cover_result and p.pdf_manifest->'interior'=p.interior_result
 and p.pdf_manifest->'vendorReady'='false'::jsonb and p.pdf_manifest->'productionApproved'='false'::jsonb
 and p.cover_result->'pageCount'='1'::jsonb and p.interior_result->'pageCount'='80'::jsonb
 and p.cover_result->>'sha256'~'^[a-f0-9]{64}$' and p.interior_result->>'sha256'~'^[a-f0-9]{64}$'
 and(p.cover_result->>'byteLength')::integer between 100 and 150000000 and(p.interior_result->>'byteLength')::integer between 100 and 500000000
 and private.print_dev_parts_verified(p.id,'cover') and private.print_dev_parts_verified(p.id,'interior')
 and((p.transport_version='DIRECT_V1' and p.file_parts='{}'::jsonb) or(p.transport_version='CHUNKED_V1' and p.pdf_manifest->'fileTransport'=jsonb_build_object('version','CHUNKED_V1','files',p.file_parts))));
$$;
create function private.guard_print_dev_checkout() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if row(new.id,new.owner_id,new.request_id,new.order_id,new.payment_id,new.album_id,new.snapshot,new.product,new.spec,new.source_asset_owners,
 new.reviewed_revision,new.reviewed_spec_revision,new.source_digest,new.order_code,new.recipient,new.total_amount,new.currency,new.environment,new.created_at,new.expires_at)
 is distinct from row(old.id,old.owner_id,old.request_id,old.order_id,old.payment_id,old.album_id,old.snapshot,old.product,old.spec,old.source_asset_owners,
 old.reviewed_revision,old.reviewed_spec_revision,old.source_digest,old.order_code,old.recipient,old.total_amount,old.currency,old.environment,old.created_at,old.expires_at)
 or(old.sdk_issued_at is not null and new.sdk_issued_at is distinct from old.sdk_issued_at)
 or(old.package_id is not null and new.package_id is distinct from old.package_id) then raise exception 'print_dev_checkout_immutable' using errcode='23514';end if;
 if new.package_id is not null and not exists(select 1 from private.print_dev_packages p where p.id=new.package_id and p.checkout_id=new.id) then raise exception 'print_dev_package_conflict' using errcode='23514';end if;
 return new;
end;$$;
create trigger print_dev_checkout_guard before update on private.print_dev_checkouts for each row execute function private.guard_print_dev_checkout();
create function public.get_print_dev_checkout(p_actor uuid,p_run_id uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare c private.print_dev_checkouts;p private.print_dev_packages;s private.print_payment_test_sessions;
begin
 select * into c from private.print_dev_checkouts where id=p_run_id and owner_id=p_actor;
 if not found then raise exception 'print_dev_checkout_not_found' using errcode='P0002';end if;
 select * into p from private.print_dev_packages where id=c.package_id and checkout_id=c.id;
 select * into strict s from private.print_payment_test_sessions where payment_id=c.payment_id and owner_id=p_actor;
 return jsonb_build_object('checkout',to_jsonb(c),'package',case when p.id is null then null else to_jsonb(p) end,'session',to_jsonb(s));
end;$$;
create function public.prepare_print_dev_checkout(p_actor uuid,p_request_id uuid,p_album_id bigint,p_reviewed_revision text,p_reviewed_spec_revision text,
 p_source_digest text,p_spec jsonb,p_recipient jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c private.print_dev_checkouts;ctx jsonb;q jsonb;m public.redprinting_dev_mappings;s jsonb;v_id uuid:=gen_random_uuid();
begin
 if p_actor is null or p_request_id is null or p_album_id is null or p_reviewed_revision!~'^[a-f0-9]{64}$' or p_reviewed_spec_revision!~'^[a-f0-9]{64}$' then raise exception 'invalid_print_dev_request' using errcode='22023';end if;
 select * into c from private.print_dev_checkouts where owner_id=p_actor and request_id=p_request_id for update;
 if found then
 if c.album_id<>p_album_id or c.reviewed_revision<>p_reviewed_revision or c.reviewed_spec_revision<>p_reviewed_spec_revision or c.recipient<>p_recipient then raise exception 'print_dev_request_conflict' using errcode='23514';end if;
 return public.get_print_dev_checkout(p_actor,c.id);end if;
 ctx:=public.load_owned_print_checkout_context(p_actor,p_album_id);q:=ctx->'quote';
 if ctx->>'sourceDigest' is distinct from p_source_digest then raise exception 'print_album_changed' using errcode='23514';end if;
 if q->>'productCode'<>'REDP_300_HARD' or q->>'pageCount'<>'80' or q->>'sourcePageCount'<>'80'
 or p_spec->>'id'<>'REDP_300_HARD' or p_spec->>'pageCount'<>'80' or p_spec->'verified' is distinct from 'false'::jsonb
 or p_spec->'dpi' is distinct from '300'::jsonb or p_spec->>'colorSpace'<>'sRGB' or p_spec->'interior' is distinct from q->'spec'->'interior'
 or p_spec->>'layoutFit'<>'contain' then raise exception 'print_dev_hard80_required' using errcode='23514';end if;
 select * into m from public.redprinting_dev_mappings where product_id='REDP_300_HARD' and page_count=80;
 if not found or not m.exact_match_confirmed or m.vendor_use_yn<>'Y' or m.vendor_order_yn<>'Y' or m.verified_at is null or coalesce(m.order_code,'')='' then raise exception 'print_dev_mapping_not_ready' using errcode='23514';end if;
 s:=public.prepare_print_payment_test(p_actor,p_request_id,'HARD_80','store-33df409e-0ad9-4953-8194-70db7e32efae','channel-key-34782ac7-e644-4234-ad27-2767b6904f88');
 insert into private.print_dev_checkouts(id,owner_id,request_id,order_id,payment_id,album_id,snapshot,product,spec,source_asset_owners,reviewed_revision,reviewed_spec_revision,source_digest,order_code,recipient)
 values(v_id,p_actor,p_request_id,'ordp_'||v_id::text,s->>'payment_id',p_album_id,(ctx->'snapshot')||jsonb_build_object('printProduct',q->'printProduct'),q->'printProduct',p_spec,
 array(select jsonb_array_elements_text(ctx->'allowedAssetOwners')::uuid),p_reviewed_revision,p_reviewed_spec_revision,p_source_digest,m.order_code,p_recipient);
 return public.get_print_dev_checkout(p_actor,v_id);
end;$$;
create function public.print_dev_package(p_actor uuid,p_run_id uuid,p_action text,p_package_id uuid default null,p_kind text default null,p_result jsonb default null,p_manifest jsonb default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c private.print_dev_checkouts;p private.print_dev_packages;id_new uuid;kind text;declared jsonb;parts_new jsonb:='{}';part jsonb;part_index integer;part_count integer;file_bytes bigint;expected_bytes bigint;part_declaration jsonb;width_mm numeric;height_mm numeric;ready_manifest jsonb;
 p_file_kind text:=p_kind;p_file_result jsonb:=p_result;
begin
 select * into c from private.print_dev_checkouts where id=p_run_id and owner_id=p_actor for update;
 if not found then raise exception 'print_dev_checkout_not_found' using errcode='P0002';end if;
 if p_action not in('snapshot','uploads','verify_part','finalize','seal') then raise exception 'invalid_print_dev_request' using errcode='22023';end if;
 if p_action<>'snapshot' and(c.sdk_issued_at is not null or c.expires_at<=now() or c.status not in('PREPARING','READY')) then raise exception 'print_dev_state_changed' using errcode='23514';end if;
 select * into p from private.print_dev_packages where checkout_id=c.id for update;
 if p_action='uploads' then
  if p_file_result->>'sourceFingerprint' !~ '^[a-f0-9]{64}$' or p_file_result->>'specVersion' is distinct from c.spec->>'specVersion'
   or p_manifest->>'sourceFingerprint' is distinct from p_file_result->>'sourceFingerprint'
   or p_manifest->>'specVersion' is distinct from c.spec->>'specVersion'
   or p_manifest->>'renderer' is distinct from 'flutter-layer-builder-raster-v1'
   or p_manifest->>'productId' is distinct from c.product->>'id' or p_manifest->>'coverType' is distinct from c.spec->>'coverType'
   or p_manifest->>'pageCount' is distinct from 80::text or p_manifest->'dpi' is distinct from '300'::jsonb
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
     part_declaration:=jsonb_build_object('index',part_index,'path',c.order_id||'/'||id_new::text||'/'||kind||'/part-'||lpad(part_index::text,3,'0')||'.bin',
      'byteLength',expected_bytes,'sha256',part->>'sha256');
     parts_new:=jsonb_set(parts_new,array[kind],(parts_new->kind)||jsonb_build_array(part_declaration),true);
    end loop;
   elsif declared ? 'parts' then raise exception 'invalid_print_prepayment_request' using errcode='22023';end if;
  end loop;
  if p.id is not null then
   if p.renderer_manifest is distinct from p_manifest or p.source_fingerprint is distinct from p_file_result->>'sourceFingerprint' then
    raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
  else
   insert into private.print_dev_packages(id,checkout_id,source_fingerprint,spec_version,renderer_manifest,expires_at,
    cover_path,interior_path,manifest_path,file_parts,transport_version) values(id_new,c.id,p_file_result->>'sourceFingerprint',p_file_result->>'specVersion',p_manifest,c.expires_at,
    c.order_id||'/'||id_new::text||'/cover.pdf',c.order_id||'/'||id_new::text||'/interior.pdf',c.order_id||'/'||id_new::text||'/manifest.json',parts_new,case when parts_new='{}'::jsonb then 'DIRECT_V1' else 'CHUNKED_V1' end) returning * into p;
   update private.print_dev_checkouts set package_id=p.id where id=c.id returning * into c;
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
   update private.print_dev_packages set part_results=jsonb_set(part_results,array[p_file_kind],
    coalesce(part_results->p_file_kind,'{}'::jsonb)||jsonb_build_object(part_index::text,p_file_result),true) where id=p.id returning * into p;
  elsif p_action='finalize' then
   if not private.print_dev_parts_verified(p.id,p_file_kind) then raise exception 'print_prepayment_parts_incomplete' using errcode='23514';end if;
   if p_file_kind not in('cover','interior') or p_manifest is distinct from p.renderer_manifest then
    raise exception 'print_prepayment_manifest_conflict' using errcode='23514';end if;
   declared:=p.renderer_manifest->'declaredFiles'->p_file_kind;
   width_mm:=case when p_file_kind='cover' then (c.spec->'cover'->>'widthMm')::numeric
    else (c.spec->'interior'->>'trimWidthMm')::numeric+2*(c.spec->'interior'->>'bleedMm')::numeric end;
   height_mm:=case when p_file_kind='cover' then (c.spec->'cover'->>'heightMm')::numeric
    else (c.spec->'interior'->>'trimHeightMm')::numeric+2*(c.spec->'interior'->>'bleedMm')::numeric end;
   if not coalesce(p_file_result->>'pageCount'=case when p_file_kind='cover' then '1' else 80::text end
    and p_file_result->'byteLength'=declared->'bytes' and p_file_result->'sha256'=declared->'sha256'
    and jsonb_typeof(p_file_result->'widthMm')='number' and jsonb_typeof(p_file_result->'heightMm')='number'
    and abs((p_file_result->>'widthMm')::numeric-width_mm)<0.001 and abs((p_file_result->>'heightMm')::numeric-height_mm)<0.001
    and p_file_result-array['pageCount','widthMm','heightMm','byteLength','sha256']='{}'::jsonb,false) then
     raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   if (p_file_kind='cover' and p.cover_result is not null and p.cover_result is distinct from p_file_result)
    or(p_file_kind='interior' and p.interior_result is not null and p.interior_result is distinct from p_file_result) then
     raise exception 'print_prepayment_file_conflict' using errcode='23514';end if;
   update private.print_dev_packages set cover_result=case when p_file_kind='cover' then p_file_result else cover_result end,
    interior_result=case when p_file_kind='interior' then p_file_result else interior_result end where id=p.id returning * into p;
   if p.cover_result is not null and p.interior_result is not null and p.state='UPLOADING' then
    ready_manifest:=(p.renderer_manifest-'declaredFiles')||jsonb_build_object('sourceFingerprint',p.source_fingerprint,'spec',c.spec,
     'cover',p.cover_result,'interior',p.interior_result,'generatedAt',now(),'vendorReady',false,'productionApproved',false)||case when p.transport_version='CHUNKED_V1' then jsonb_build_object('fileTransport',jsonb_build_object('version','CHUNKED_V1','files',p.file_parts)) else '{}'::jsonb end;
    update private.print_dev_packages set state='FILES_VERIFIED',pdf_manifest=ready_manifest where id=p.id returning * into p;
   end if;
  elsif p.state='FILES_VERIFIED' then
   update private.print_dev_packages set state='READY',verified_at=now() where id=p.id returning * into p;
  elsif p.state<>'READY' then raise exception 'print_prepayment_state_changed' using errcode='23514';end if;
 end if;

 if p.state='READY' and c.status='PREPARING' then update private.print_dev_checkouts set status='READY' where id=c.id;end if;
 return public.get_print_dev_checkout(p_actor,c.id);
end;$$;
create function public.authorize_print_dev_checkout(p_actor uuid,p_run_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare c private.print_dev_checkouts;
begin
 select * into c from private.print_dev_checkouts where id=p_run_id and owner_id=p_actor for update;
 if not found then raise exception 'print_dev_checkout_not_found' using errcode='P0002';end if;
 if c.expires_at<=now() or c.status not in('READY','PAYMENT_VERIFIED','SUBMITTING','UNKNOWN','ACCEPTED','FILE_CHECKED') or not private.print_dev_ready(c.id) then raise exception 'print_dev_files_not_ready' using errcode='23514';end if;
 if c.sdk_issued_at is null then
 update private.print_dev_checkouts set sdk_issued_at=now() where id=c.id;
 insert into private.print_dev_fulfillment_outbox(checkout_id,payload) values(c.id,jsonb_build_object('vendorOrderNum','SFD'||replace(c.id::text,'-',''),'vendorOrderSeq',1,'queryOnly',false));
 end if;
 return public.get_print_dev_checkout(p_actor,c.id);
end;$$;

create function private.guard_print_dev_outbox() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.payload->>'vendorOrderNum' is distinct from 'SFD'||replace(new.checkout_id::text,'-','') or new.payload->'vendorOrderSeq' is distinct from '1'::jsonb
 or new.payload-array['vendorOrderNum','vendorOrderSeq','queryOnly']<>'{}'::jsonb or jsonb_typeof(new.payload->'queryOnly') is distinct from 'boolean'
 or(tg_op='UPDATE' and(row(new.id,new.checkout_id,new.created_at) is distinct from row(old.id,old.checkout_id,old.created_at)
  or(old.payload->'queryOnly'='true'::jsonb and new.payload->'queryOnly' is distinct from 'true'::jsonb))) then raise exception 'print_dev_outbox_immutable' using errcode='23514';end if;
 return new;
end;$$;
create trigger print_dev_outbox_guard before insert or update on private.print_dev_fulfillment_outbox for each row execute function private.guard_print_dev_outbox();
revoke all on function private.guard_print_dev_outbox() from public,anon,authenticated;
grant execute on function private.guard_print_dev_outbox() to service_role;
create function private.print_dev_claim_json(p_id uuid,p_owner uuid) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare j private.print_dev_fulfillment_outbox;c private.print_dev_checkouts;p private.print_dev_packages;s private.print_payment_test_sessions;
begin
 select * into j from private.print_dev_fulfillment_outbox where id=p_id and lease_owner=p_owner and state='CLAIMED' and lease_until>now();
 if not found then raise exception 'print_dev_lease_lost' using errcode='23514';end if;
 select * into strict c from private.print_dev_checkouts where id=j.checkout_id;
 select * into strict p from private.print_dev_packages where id=c.package_id and checkout_id=c.id;
 select * into strict s from private.print_payment_test_sessions where payment_id=c.payment_id and owner_id=c.owner_id;
 if c.sdk_issued_at is null or not private.print_dev_ready(c.id) or c.status='FAILED'
 or s.environment<>'test' or(j.event_type<>'PAYMENT' and(s.status<>'VERIFIED_TEST' or s.receipt->'isTest' is distinct from 'true'::jsonb or s.receipt->>'environment' is distinct from 'test')) then raise exception 'print_dev_files_not_ready' using errcode='23514';end if;
 return jsonb_build_object('job',to_jsonb(j),'checkout',to_jsonb(c),'package',to_jsonb(p),'paymentExpectation',jsonb_build_object('paymentId',s.payment_id,'storeId',s.store_id,'channelKey',s.channel_key,'amount',s.total_amount,'currency','KRW','environment','test'));
end;$$;
create function public.claim_print_dev_fulfillment_job(p_worker_id uuid,p_limit integer default 1,p_lease_seconds integer default 120)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare j private.print_dev_fulfillment_outbox;
begin
 if p_worker_id is null or p_limit<>1 or p_lease_seconds not between 30 and 300 then raise exception 'invalid_print_dev_request' using errcode='22023';end if;
 select job.* into j from private.print_dev_fulfillment_outbox job join private.print_dev_checkouts c on c.id=job.checkout_id
 where job.available_at<=now() and(job.state in('PENDING','UNKNOWN') or(job.state='CLAIMED' and job.lease_until<now())) and c.status<>'FAILED' and c.sdk_issued_at is not null and private.print_dev_ready(c.id)
 order by job.available_at for update of job skip locked limit 1;
 if not found then return null;end if;
 update private.print_dev_fulfillment_outbox set state='CLAIMED',lease_owner=p_worker_id,lease_until=now()+make_interval(secs=>p_lease_seconds),attempts=attempts+1,updated_at=now() where id=j.id;
 return private.print_dev_claim_json(j.id,p_worker_id);
end;$$;
create function public.get_print_dev_fulfillment_job(p_id uuid,p_owner uuid) returns jsonb language sql stable security invoker set search_path='' as $$select private.print_dev_claim_json(p_id,p_owner)$$;
create function public.commit_print_dev_payment(p_id uuid,p_owner uuid,p_receipt jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare ctx jsonb;c private.print_dev_checkouts;
begin
 perform 1 from private.print_dev_fulfillment_outbox where id=p_id for update;ctx:=private.print_dev_claim_json(p_id,p_owner);
 select * into strict c from private.print_dev_checkouts where id=(ctx->'checkout'->>'id')::uuid for update;
 perform public.verify_print_payment_test(c.owner_id,c.payment_id,p_receipt);
 if c.status in('READY','PAYMENT_VERIFIED') then update private.print_dev_checkouts set status='PAYMENT_VERIFIED',error_code=null where id=c.id;end if;
 return private.print_dev_claim_json(p_id,p_owner);
end;$$;
create function public.record_print_dev_submission_attempt(p_id uuid,p_owner uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare ctx jsonb;j private.print_dev_fulfillment_outbox;c private.print_dev_checkouts;
begin
 select * into j from private.print_dev_fulfillment_outbox where id=p_id for update;ctx:=private.print_dev_claim_json(p_id,p_owner);
 select * into strict c from private.print_dev_checkouts where id=j.checkout_id for update;
 if j.event_type<>'SUBMIT' or c.status<>'PAYMENT_VERIFIED' or c.submitted_at is not null or j.payload->'queryOnly' is distinct from 'false'::jsonb then raise exception 'print_dev_submission_already_attempted' using errcode='23514';end if;
 update private.print_dev_checkouts set status='SUBMITTING',submitted_at=now(),error_code=null where id=c.id;
 update private.print_dev_fulfillment_outbox set payload=jsonb_set(payload,'{queryOnly}','true'),updated_at=now() where id=p_id;
 return private.print_dev_claim_json(p_id,p_owner);
end;$$;
create function public.finish_print_dev_fulfillment_job(p_id uuid,p_owner uuid,p_result jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare ctx jsonb;j private.print_dev_fulfillment_outbox;c private.print_dev_checkouts;next_stage text:=p_result->>'nextStage';next_status text:=p_result->>'status';available timestamptz:=coalesce((p_result->>'availableAt')::timestamptz,now()+interval '2 minutes');vs jsonb:=p_result->'vendorStatus';
begin
 select * into j from private.print_dev_fulfillment_outbox where id=p_id for update;ctx:=private.print_dev_claim_json(p_id,p_owner);
 select * into strict c from private.print_dev_checkouts where id=j.checkout_id for update;
 if p_result-array['nextStage','status','vendorStatus','vendorResultId','errorCode','availableAt']<>'{}'::jsonb or next_stage not in('SUBMIT','POLL','DONE') or available>now()+interval '1 day' then raise exception 'invalid_print_dev_result' using errcode='22023';end if;
 if next_stage='SUBMIT' then
  if j.event_type<>'PAYMENT' or c.status<>'PAYMENT_VERIFIED' or next_status<>'PAYMENT_VERIFIED' then raise exception 'print_dev_state_changed' using errcode='23514';end if;
 elsif j.event_type not in('SUBMIT','POLL') or c.submitted_at is null or next_status not in('ACCEPTED','FILE_CHECKED') or jsonb_typeof(vs) is distinct from 'object' then raise exception 'print_dev_state_changed' using errcode='23514';
 end if;
 if next_stage='DONE' and(next_status<>'FILE_CHECKED' or vs->>'fileProcessYn' is distinct from 'Y' or vs->'fileError'='true'::jsonb or vs->'fileErrorDetailPresent'='true'::jsonb or vs->>'statusCodeOrg' in('PGS_06','PGS_01','PGS_02') or vs->>'statusCode' in('PGS_01','PGS_60')) then raise exception 'print_dev_file_check_required' using errcode='23514';end if;
 update private.print_dev_checkouts set status=next_status,vendor_status=coalesce(vs,vendor_status),vendor_result_id=coalesce(nullif(p_result->>'vendorResultId',''),vendor_result_id),last_status_at=case when vs is null then last_status_at else now() end,error_code=nullif(p_result->>'errorCode','') where id=c.id;
 update private.print_dev_fulfillment_outbox set event_type=case when next_stage='DONE' then event_type else next_stage end,state=case when next_stage='DONE' then 'DONE' else 'PENDING' end,available_at=available,lease_owner=null,lease_until=null,last_error_code=null,updated_at=now() where id=p_id;
 return public.get_print_dev_checkout(c.owner_id,c.id);
end;$$;
create function public.fail_print_dev_fulfillment_job(p_id uuid,p_owner uuid,p_error_code text,p_available_at timestamptz,p_terminal boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare ctx jsonb;j private.print_dev_fulfillment_outbox;c private.print_dev_checkouts;
begin
 select * into j from private.print_dev_fulfillment_outbox where id=p_id for update;ctx:=private.print_dev_claim_json(p_id,p_owner);
 if p_error_code!~'^[a-z0-9_]{1,80}$' or p_available_at>now()+interval '1 day' then raise exception 'invalid_print_dev_result' using errcode='22023';end if;
 update private.print_dev_fulfillment_outbox set state=case when p_terminal then 'FAILED' when payload->'queryOnly'='true'::jsonb then 'UNKNOWN' else 'PENDING' end,available_at=p_available_at,lease_owner=null,lease_until=null,last_error_code=p_error_code,updated_at=now() where id=p_id;
 update private.print_dev_checkouts set status=case when p_terminal then 'FAILED' when submitted_at is not null then 'UNKNOWN' else status end,error_code=p_error_code where id=j.checkout_id returning * into c;
 return public.get_print_dev_checkout(c.owner_id,c.id);
end;$$;
create function public.read_print_dev_file_delivery(p_order_id text,p_package_id uuid,p_kind text) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare c private.print_dev_checkouts;p private.print_dev_packages;s private.print_payment_test_sessions;r jsonb;
begin
 if p_kind not in('cover','interior') then raise exception 'print_file_not_found' using errcode='P0002';end if;
 select * into c from private.print_dev_checkouts where order_id=p_order_id and package_id=p_package_id;
 select * into p from private.print_dev_packages where id=p_package_id and checkout_id=c.id;
 select * into s from private.print_payment_test_sessions where payment_id=c.payment_id and owner_id=c.owner_id;
 if c.id is null or c.sdk_issued_at is null or c.status not in('PAYMENT_VERIFIED','SUBMITTING','UNKNOWN','ACCEPTED','FILE_CHECKED') or not private.print_dev_ready(c.id)
 or s.status<>'VERIFIED_TEST' or s.receipt->'isTest' is distinct from 'true'::jsonb or s.receipt->>'environment' is distinct from 'test' then raise exception 'print_file_not_found' using errcode='P0002';end if;
 r:=case when p_kind='cover' then p.cover_result else p.interior_result end;
 return jsonb_build_object('orderId',c.order_id,'packageId',p.id,'kind',p_kind,'result',r,'parts',coalesce(p.file_parts->p_kind,'[]'::jsonb),'path',case when p.file_parts?p_kind then null when p_kind='cover' then p.cover_path else p.interior_path end);
end;$$;
revoke all on function private.print_dev_parts_verified(uuid,text) from public,anon,authenticated;
grant execute on function private.print_dev_parts_verified(uuid,text) to service_role;
revoke all on function private.guard_print_dev_package() from public,anon,authenticated;
grant execute on function private.guard_print_dev_package() to service_role;
revoke all on function private.print_dev_ready(uuid) from public,anon,authenticated;
grant execute on function private.print_dev_ready(uuid) to service_role;
revoke all on function private.guard_print_dev_checkout() from public,anon,authenticated;
grant execute on function private.guard_print_dev_checkout() to service_role;
revoke all on function public.get_print_dev_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_print_dev_checkout(uuid,uuid) to service_role;
revoke all on function public.prepare_print_dev_checkout(uuid,uuid,bigint,text,text,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.prepare_print_dev_checkout(uuid,uuid,bigint,text,text,text,jsonb,jsonb) to service_role;
revoke all on function public.print_dev_package(uuid,uuid,text,uuid,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.print_dev_package(uuid,uuid,text,uuid,text,jsonb,jsonb) to service_role;
revoke all on function public.authorize_print_dev_checkout(uuid,uuid) from public,anon,authenticated;
grant execute on function public.authorize_print_dev_checkout(uuid,uuid) to service_role;
revoke all on function private.print_dev_claim_json(uuid,uuid) from public,anon,authenticated;
grant execute on function private.print_dev_claim_json(uuid,uuid) to service_role;
revoke all on function public.claim_print_dev_fulfillment_job(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.claim_print_dev_fulfillment_job(uuid,integer,integer) to service_role;
revoke all on function public.get_print_dev_fulfillment_job(uuid,uuid) from public,anon,authenticated;
grant execute on function public.get_print_dev_fulfillment_job(uuid,uuid) to service_role;
revoke all on function public.commit_print_dev_payment(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.commit_print_dev_payment(uuid,uuid,jsonb) to service_role;
revoke all on function public.record_print_dev_submission_attempt(uuid,uuid) from public,anon,authenticated;
grant execute on function public.record_print_dev_submission_attempt(uuid,uuid) to service_role;
revoke all on function public.finish_print_dev_fulfillment_job(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_print_dev_fulfillment_job(uuid,uuid,jsonb) to service_role;
revoke all on function public.fail_print_dev_fulfillment_job(uuid,uuid,text,timestamptz,boolean) from public,anon,authenticated;
grant execute on function public.fail_print_dev_fulfillment_job(uuid,uuid,text,timestamptz,boolean) to service_role;
revoke all on function public.read_print_dev_file_delivery(text,uuid,text) from public,anon,authenticated;
grant execute on function public.read_print_dev_file_delivery(text,uuid,text) to service_role;
notify pgrst,'reload schema';

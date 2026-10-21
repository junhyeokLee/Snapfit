-- Preparation only. No files are deleted by this migration, default setting or
-- scheduled job. Original albums, photos, financial and consent records remain.
create table private.print_file_retention_settings (
 id boolean primary key default true check(id), enabled boolean not null default false,
 days_after_shipment integer not null default 120 check(days_after_shipment=120)
);
insert into private.print_file_retention_settings(id) values(true);
create table private.print_file_retention (
 order_id text primary key references public.orders(order_id),
 hold boolean not null default false, hold_note text not null default '',
 state text not null default 'RETAINED' check(state in('RETAINED','REMOVING','REMOVED')),
 lease_owner uuid, lease_until timestamptz, removed_at timestamptz,
 updated_at timestamptz not null default now(),
 check((state='REMOVED')=(removed_at is not null))
);
create table private.print_file_retention_audit (
 id bigint generated always as identity primary key, order_id text not null,
 actor_id uuid, action text not null check(action in('HOLD','RELEASE','CLAIM','REMOVED','RETRY')),
 note text not null default '', created_at timestamptz not null default now()
);
alter table private.print_file_retention_settings enable row level security;
alter table private.print_file_retention enable row level security;
alter table private.print_file_retention_audit enable row level security;
revoke all on private.print_file_retention_settings,private.print_file_retention,private.print_file_retention_audit from public,anon,authenticated,service_role;
grant select on private.print_file_retention_settings to service_role;
grant select,insert,update on private.print_file_retention to service_role;
grant select,insert on private.print_file_retention_audit to service_role;
grant usage,select on sequence private.print_file_retention_audit_id_seq to service_role;

create function private.print_file_retention_eligible(p_order text) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from public.orders o
 join private.print_checkout_intents i on i.order_id=o.order_id
 join private.print_prepayment_packages p on p.id=i.prepayment_package_id and p.intent_id=i.id
 left join private.print_file_retention r on r.order_id=o.order_id
 where o.order_id=p_order and o.checkout_flow='PORTONE_V2_V1' and o.payment_environment='live'
 and o.status in('SHIPPING','DELIVERED') and o.shipped_at is not null and o.shipped_at<=now()-interval '120 days'
 and o.shipped_at>i.verified_at and o.shipped_at<=now()
 and i.status='PAID' and i.verified_at is not null and i.payment_receipt->>'status'='PAID'
 and i.payment_receipt->'isTest'='false'::jsonb and i.print_file_source='APP_UPLOADED'
 and o.payment_reversed_at is null and not o.print_customer_request_hold and not o.print_requires_action
 and o.print_vendor='REDPRINTING' and o.print_vendor_order_id='SFO_'||replace(i.id::text,'-','')
 and o.print_upload_id=p.id and p.state='READY' and p.verified_at is not null
 and p.cover_path=o.order_id||'/'||p.id::text||'/cover.pdf'
 and p.interior_path=o.order_id||'/'||p.id::text||'/interior.pdf'
 and p.manifest_path=o.order_id||'/'||p.id::text||'/manifest.json'
 and o.print_cover_pdf_path=p.cover_path and o.print_interior_pdf_path=p.interior_path
 and coalesce(r.hold,false)=false and coalesce(r.state,'RETAINED')<>'REMOVED'
 and not exists(select 1 from private.print_order_requests q where q.order_id=o.order_id and q.status<>'COMPLETED')
 and not exists(select 1 from private.print_fulfillment_outbox j where j.order_id=o.order_id
  and (j.state in('UNKNOWN','CLAIMED') or j.event_type in('SUBMIT','CONFIRM') and j.state<>'DONE')))
$$;
revoke all on function private.print_file_retention_eligible(text) from public,anon,authenticated;
grant execute on function private.print_file_retention_eligible(text) to service_role;

create function public.manage_print_file_retention(p_actor uuid,p_action text,p_order_id text default null,p_note text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r private.print_file_retention;
begin
 if not exists(select 1 from auth.users where id=p_actor and raw_app_meta_data->>'role'='admin') then raise exception 'forbidden' using errcode='42501';end if;
 if p_action='overview' and p_order_id is null and p_note is null then
  return jsonb_build_object('enabled',(select enabled from private.print_file_retention_settings where id),
   'daysAfterShipment',120,'basis','CONFIRMED_SHIPMENT','originalPhotosDeleted',false,
   'eligibleCount',(select count(*) from public.orders o where private.print_file_retention_eligible(o.order_id)),
   'records',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select order_id,hold,hold_note,state,lease_until,removed_at,updated_at
    from private.print_file_retention order by updated_at desc limit 100) x));
 end if;
 if p_action not in('hold','release') or p_order_id is null or length(btrim(coalesce(p_note,''))) not between 1 and 1000 then
  raise exception 'invalid_retention_request' using errcode='22023';end if;
 perform 1 from public.orders where order_id=p_order_id and checkout_flow='PORTONE_V2_V1' for update;
 if not found then raise exception 'retention_order_not_found' using errcode='P0002';end if;
 insert into private.print_file_retention(order_id) values(p_order_id) on conflict do nothing;
 select * into strict r from private.print_file_retention where order_id=p_order_id for update;
 if r.state='REMOVED' then raise exception 'retention_files_already_removed' using errcode='23514';end if;
 if r.state='REMOVING' and r.lease_until>now() then raise exception 'retention_removal_in_progress' using errcode='23514';end if;
 update private.print_file_retention set hold=p_action='hold',hold_note=btrim(p_note),state='RETAINED',lease_owner=null,lease_until=null,updated_at=now()
  where order_id=p_order_id returning * into r;
 insert into private.print_file_retention_audit(order_id,actor_id,action,note) values(p_order_id,p_actor,case when p_action='hold' then 'HOLD' else 'RELEASE' end,btrim(p_note));
 return to_jsonb(r);
end;$$;
revoke all on function public.manage_print_file_retention(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.manage_print_file_retention(uuid,text,text,text) to service_role;

create function public.claim_print_file_retention(p_owner uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare oid text; p private.print_prepayment_packages; r private.print_file_retention;
begin
 if p_owner is null then raise exception 'invalid_retention_owner' using errcode='22023';end if;
 if not coalesce((select enabled from private.print_file_retention_settings where id),false) then return '{}'::jsonb;end if;
 select o.order_id into oid from public.orders o where private.print_file_retention_eligible(o.order_id)
  and not exists(select 1 from private.print_file_retention held where held.order_id=o.order_id and held.lease_until>now())
  order by o.shipped_at for update of o skip locked limit 1;
 if oid is null then return '{}'::jsonb;end if;
 insert into private.print_file_retention(order_id) values(oid) on conflict do nothing;
 select * into strict r from private.print_file_retention where order_id=oid for update;
 if not private.print_file_retention_eligible(oid) or r.lease_until>now() then return '{}'::jsonb;end if;
 select p2.* into strict p from private.print_prepayment_packages p2 join private.print_checkout_intents i on i.prepayment_package_id=p2.id where i.order_id=oid;
 update private.print_file_retention set state='REMOVING',lease_owner=p_owner,lease_until=now()+interval '5 minutes',updated_at=now() where order_id=oid;
 insert into private.print_file_retention_audit(order_id,action) values(oid,'CLAIM');
 return jsonb_build_object('orderId',oid,'packageId',p.id,'owner',p_owner,
  'paths',jsonb_build_array(p.cover_path,p.interior_path,p.manifest_path)||coalesce((select jsonb_agg(v->>'path' order by k,v->>'index')
    from jsonb_each(p.file_parts) f(k,a) cross join lateral jsonb_array_elements(a) v),'[]'::jsonb));
end;$$;
revoke all on function public.claim_print_file_retention(uuid) from public,anon,authenticated;
grant execute on function public.claim_print_file_retention(uuid) to service_role;

create function public.finish_print_file_retention(p_order_id text,p_owner uuid,p_removed boolean) returns boolean
language plpgsql security invoker set search_path='' as $$
begin
 if p_removed is null then raise exception 'invalid_retention_result' using errcode='22023';end if;
 update private.print_file_retention set state=case when p_removed then 'REMOVED' else 'RETAINED' end,
  removed_at=case when p_removed then now() else null end,lease_owner=null,lease_until=null,updated_at=now()
  where order_id=p_order_id and state='REMOVING' and lease_owner=p_owner and lease_until>now();
 if not found then raise exception 'retention_lease_lost' using errcode='23514';end if;
 insert into private.print_file_retention_audit(order_id,action) values(p_order_id,case when p_removed then 'REMOVED' else 'RETRY' end);
 return true;
end;$$;
revoke all on function public.finish_print_file_retention(text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_print_file_retention(text,uuid,boolean) to service_role;

-- A second, independent gate: even after a later explicit DB enable, the job
-- stays inactive until intentionally activated. It reuses the existing Vault
-- capability, with a domain-separated signature; it never sends a secret key.
do $retention_job$
declare jid bigint;
begin
 if pg_catalog.to_regnamespace('cron') is null then return;end if;
 if exists(select 1 from cron.job where jobname='snapfit-print-file-retention' and username<>current_user) then
  raise exception 'retention_job_owner_conflict' using errcode='42501';end if;
 jid:=cron.schedule('snapfit-print-file-retention','17 19 * * *',$retention_command$
  with configuration as (
   select max(decrypted_secret) filter(where name='snapfit_print_order_scheduler_project_url') as project_url,
    max(decrypted_secret) filter(where name='snapfit_print_order_scheduler_secret') as secret
   from vault.decrypted_secrets where name in('snapfit_print_order_scheduler_project_url','snapfit_print_order_scheduler_secret')
   having count(*)=2 and count(*) filter(where name='snapfit_print_order_scheduler_project_url' and decrypted_secret='https://rrbhxdtriummqpztpjrk.supabase.co')=1
    and count(*) filter(where name='snapfit_print_order_scheduler_secret' and decrypted_secret~'^[a-f0-9]{64}$')=1
  ), fresh as (
   insert into private.print_order_scheduler_nonces(id,signed_at,expires_at)
    select gen_random_uuid(),floor(extract(epoch from now()))::bigint,now()+interval '5 minutes' from configuration
     where coalesce((select enabled from private.print_file_retention_settings where id),false)
    returning id,signed_at
  )
  select net.http_post(url:=configuration.project_url||'/functions/v1/print-file-retention-worker',
   headers:=jsonb_build_object('Content-Type','application/json','X-Snapfit-Retention-Timestamp',fresh.signed_at::text,
    'X-Snapfit-Retention-Nonce',fresh.id::text,'X-Snapfit-Retention-Signature',encode(extensions.hmac(
     'snapfit-print-file-retention:v1'||chr(10)||fresh.signed_at::text||chr(10)||fresh.id::text||chr(10)||'{}',configuration.secret,'sha256'),'hex')),
   body:='{}'::jsonb,timeout_milliseconds:=45000) from configuration cross join fresh;
 $retention_command$);
 perform cron.alter_job(jid,active:=false);
end;
$retention_job$;

-- Recheck immediately before Storage deletion. A prior lease never overrides
-- a new dispute, operational hold, changed order or disabled setting.
create function public.authorize_print_file_retention_removal(p_order_id text,p_owner uuid) returns boolean
language sql stable security invoker set search_path='' as $$
 select coalesce((select enabled from private.print_file_retention_settings where id),false)
  and private.print_file_retention_eligible(p_order_id)
  and exists(select 1 from private.print_file_retention where order_id=p_order_id and state='REMOVING' and lease_owner=p_owner and lease_until>now());
$$;
revoke all on function public.authorize_print_file_retention_removal(text,uuid) from public,anon,authenticated;
grant execute on function public.authorize_print_file_retention_removal(text,uuid) to service_role;

-- Customer requests are not cancellations. Money/manufacturing may change only
-- after independently observed provider evidence. No runtime approval is enabled.
alter table public.orders add column print_customer_request_hold boolean not null default false;
create table private.print_order_requests (
  id uuid primary key default gen_random_uuid(), request_id uuid not null unique, user_id uuid not null references auth.users(id),
  intent_id uuid not null references private.print_checkout_intents(id), order_id text not null references public.orders(order_id),
  type text not null check(type in('CANCEL','REFUND','GENERAL')), reason text not null check(length(reason) between 1 and 1000),
  fingerprint text not null, status text not null default 'REQUESTED' check(status in('REQUESTED','WAITING_PROVIDER','REVIEW_REQUIRED','COMPLETED')),
  resolution text not null default 'NONE' check(resolution in('NONE','CANCELLED_UNPAID','REFUNDED_FULL')),
  supplier_cancel_attempt_id uuid, supplier_cancel_attempted_at timestamptz, supplier_cancel_evidence jsonb,
  pg_cancel_attempt_id uuid, pg_cancel_attempted_at timestamptz, refund_evidence jsonb,
  supplier_production_evidence jsonb,
  lease_owner uuid, lease_until timestamptz, last_error_code text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(user_id,request_id),
  check((resolution='NONE' and status<>'COMPLETED') or(resolution<>'NONE' and status='COMPLETED' and type<>'GENERAL'))
);
create unique index print_one_cancellation_request on private.print_order_requests(intent_id) where type in('CANCEL','REFUND');
create index print_request_resolution_pending on private.print_order_requests(updated_at,id) where type<>'GENERAL' and status in('REQUESTED','WAITING_PROVIDER');
create table private.print_payment_reversals (
  intent_id uuid primary key references private.print_checkout_intents(id), request_id uuid not null unique references private.print_order_requests(id),
  order_id text not null unique references public.orders(order_id), payment_id text not null unique,
  receipt jsonb not null, verified_at timestamptz not null default now()
);
alter table private.print_order_requests enable row level security;
alter table private.print_payment_reversals enable row level security;
revoke all on private.print_order_requests,private.print_payment_reversals from public,anon,authenticated,service_role;
grant select,insert,update on private.print_order_requests to service_role;
grant select,insert on private.print_payment_reversals to service_role;

create function private.print_request_public(r private.print_order_requests) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('requestId',r.request_id,'type',r.type,'status',r.status,'resolution',r.resolution,
   'replacementAllowed',r.status='COMPLETED' and r.resolution in('CANCELLED_UNPAID','REFUNDED_FULL'),
   'orderId',r.order_id,'paymentId',(select i.payment_id from private.print_checkout_intents i where i.id=r.intent_id),
   'checkoutRequestId',(select i.request_id from private.print_checkout_intents i where i.id=r.intent_id),
   'createdAt',r.created_at,'updatedAt',r.updated_at)
$$;
revoke all on function private.print_request_public(private.print_order_requests) from public,anon,authenticated;
grant execute on function private.print_request_public(private.print_order_requests) to service_role;

create function public.create_owned_print_order_request(p_actor uuid,p_request_id uuid,p_type text,p_reason text,
  p_order_id text default null,p_payment_id text default null,p_checkout_request_id uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare i private.print_checkout_intents;r private.print_order_requests;o public.orders;fp text;
begin
 if p_actor is null or p_request_id is null or p_type not in('CANCEL','REFUND','GENERAL') or p_reason is null or length(btrim(p_reason)) not between 1 and 1000
   or num_nonnulls(p_order_id,p_payment_id,p_checkout_request_id)<>1 then raise exception 'invalid_print_order_request' using errcode='22023';end if;
 select * into i from private.print_checkout_intents where user_id=p_actor and
   ((p_order_id is not null and order_id=p_order_id) or(p_payment_id is not null and payment_id=p_payment_id)
    or(p_checkout_request_id is not null and request_id=p_checkout_request_id)) for update;
 if not found then raise exception 'print_checkout_not_found' using errcode='P0002';end if;
 fp:=encode(sha256(convert_to(jsonb_build_object('intent',i.id,'type',p_type,'reason',btrim(p_reason))::text,'UTF8')),'hex');
 select * into r from private.print_order_requests where user_id=p_actor and request_id=p_request_id;
 if found then
   if r.fingerprint is distinct from fp then raise exception 'print_order_request_conflict' using errcode='23514';end if;
   return private.print_request_public(r);
 end if;
 if p_type<>'GENERAL' and exists(select 1 from private.print_order_requests where intent_id=i.id and type<>'GENERAL') then
   raise exception 'print_order_request_already_exists' using errcode='23514';end if;
 select * into strict o from public.orders where order_id=i.order_id and user_id=p_actor for update;
 insert into private.print_order_requests(request_id,user_id,intent_id,order_id,type,reason,fingerprint,status)
 values(p_request_id,p_actor,i.id,i.order_id,p_type,btrim(p_reason),fp,
   case when p_type<>'GENERAL' and o.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') then 'REVIEW_REQUIRED' else 'REQUESTED' end)
 returning * into r;
 if p_type<>'GENERAL' then
   -- Lock order before any new supplier attempt. Already-started attempts remain
   -- durable and must be resolved at the supplier, never inferred absent.
   update public.orders set print_customer_request_hold=true,print_requires_action=true,print_package_lock_token=null,print_package_lock_until=null
     where order_id=i.order_id;
 end if;
 return private.print_request_public(r);
end;$$;
create function public.get_owned_print_order_request(p_actor uuid,p_request_id uuid default null,p_order_id text default null,
 p_payment_id text default null,p_checkout_request_id uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r private.print_order_requests;
begin
 if p_actor is null or num_nonnulls(p_request_id,p_order_id,p_payment_id,p_checkout_request_id)<>1 then raise exception 'invalid_print_order_request' using errcode='22023';end if;
 select q.* into r from private.print_order_requests q join private.print_checkout_intents i on i.id=q.intent_id
 where q.user_id=p_actor and ((p_request_id is not null and q.request_id=p_request_id) or(p_order_id is not null and q.order_id=p_order_id)
   or(p_payment_id is not null and i.payment_id=p_payment_id) or(p_checkout_request_id is not null and i.request_id=p_checkout_request_id))
 order by q.created_at desc,q.id desc limit 1;
 if not found then raise exception 'print_order_request_not_found' using errcode='P0002';end if;
 return private.print_request_public(r);
end;$$;

-- Serializes a supplier attempt's durable marker with customer hold creation.
-- It does not erase a worker's prior attempt or silently refund an unknown order.
create function private.guard_print_request_fulfillment() returns trigger language plpgsql security invoker set search_path='' as $$
declare held boolean;tracking_only boolean;
begin
 select print_customer_request_hold,new.event_type='POLL' and status in('IN_PRODUCTION','PRINTING','SHIPPING') into held,tracking_only
   from public.orders where order_id=new.order_id for share;
 if coalesce(held,false) and (not coalesce(tracking_only,false) and new.state='CLAIMED' and (tg_op='INSERT' or old.state is distinct from new.state or new.lease_until>old.lease_until)
   or(tg_op='UPDATE' and new.payload->'supplierAttemptedAt' is distinct from old.payload->'supplierAttemptedAt')
   or(tg_op='UPDATE' and new.payload->'depositAttempted' is distinct from old.payload->'depositAttempted')) then
   raise exception 'print_customer_request_hold' using errcode='23514';end if;
 return new;
end;$$;
create trigger print_customer_request_fulfillment_guard before insert or update on private.print_fulfillment_outbox
 for each row execute function private.guard_print_request_fulfillment();

create function public.claim_print_order_request(p_request_id uuid,p_owner uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r private.print_order_requests;i private.print_checkout_intents;o public.orders;j private.print_fulfillment_outbox;never_attempted boolean;
begin
 if p_owner is null then raise exception 'invalid_print_order_request' using errcode='22023';end if;
 select * into r from private.print_order_requests where request_id=p_request_id and type<>'GENERAL' for update;
 if not found then raise exception 'print_order_request_not_found' using errcode='P0002';end if;
 if r.status='COMPLETED' then return jsonb_build_object('request',private.print_request_public(r),'completed',true);end if;
 if r.lease_until>now() then raise exception 'print_order_request_busy' using errcode='23514';end if;
 update private.print_order_requests set lease_owner=p_owner,lease_until=now()+interval '3 minutes' where id=r.id returning * into r;
 select * into strict i from private.print_checkout_intents where id=r.intent_id;
 select * into strict o from public.orders where order_id=r.order_id;
 select * into j from private.print_fulfillment_outbox where order_id=r.order_id;
 never_attempted:=j.payload->'supplierAttemptedAt' is null and coalesce(j.payload->>'queryOnly','false')='false'
   and coalesce(j.payload->>'depositAttempted','false')='false' and o.print_submitted_at is null and coalesce(o.print_vendor_order_id,'')='';
 return jsonb_build_object('request',private.print_request_public(r),'id',r.id,'owner',p_owner,'intent',to_jsonb(i),
   'productionStarted',o.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') or o.print_accepted_at is not null,
   'supplierNeverAttempted',never_attempted,'supplierOrderNum','SFO_'||replace(i.id::text,'-',''),'supplierOrderSeq',1,
   'supplierCancelAttempted',r.supplier_cancel_attempted_at is not null,'supplierCancelEvidence',r.supplier_cancel_evidence,
   'pgCancelAttempted',r.pg_cancel_attempted_at is not null,'pgAttemptId',r.pg_cancel_attempt_id,
   'supplierAttemptId',r.supplier_cancel_attempt_id,'leaseUntil',r.lease_until);
end;$$;

create function public.advance_print_order_request(p_id uuid,p_owner uuid,p_step text,p_evidence jsonb default '{}'::jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r private.print_order_requests;i private.print_checkout_intents;o public.orders;j private.print_fulfillment_outbox;
 never_attempted boolean;v private.print_payment_reversals;paid bigint;discount bigint;cancelled bigint;
begin
 select * into r from private.print_order_requests where id=p_id and lease_owner=p_owner and lease_until>now() for update;
 if not found then raise exception 'print_order_request_lease_lost' using errcode='23514';end if;
 select * into strict i from private.print_checkout_intents where id=r.intent_id;
 if p_step='PRODUCTION_REVIEW' then select * into j from private.print_fulfillment_outbox where order_id=r.order_id for update;end if;
 select * into strict o from public.orders where order_id=r.order_id for update;
 if p_step='PRODUCTION_REVIEW' then
   if r.type='GENERAL' or not o.print_customer_request_hold or i.status<>'PAID' or i.payment_receipt->>'environment' is distinct from 'live'
     or i.payment_receipt->'isTest' is distinct from 'false'::jsonb or r.pg_cancel_attempted_at is not null or o.payment_reversed_at is not null
     or j.id is null or j.event_type not in('CONFIRM','POLL') or j.payload->'depositAttempted' is distinct from 'true'::jsonb
     or j.payload->>'vendorOrderNum' is distinct from 'SFO_'||replace(i.id::text,'-','') or j.payload->'vendorOrderSeq' is distinct from '1'::jsonb
     or o.print_fulfillment_status not in('SUBMITTED','ACCEPTED') or o.print_vendor_order_id is distinct from 'SFO_'||replace(i.id::text,'-','')
     or p_evidence-array['orderNum','orderSeq','statusCode','statusCodeOrg','courier','trackingNumber']<>'{}'::jsonb
     or p_evidence->>'orderNum' is distinct from o.print_vendor_order_id or p_evidence->'orderSeq' is distinct from '1'::jsonb
     or coalesce(p_evidence->>'statusCode','') not in('PGS_20','PGS_50','PGS_55')
     or coalesce(p_evidence->>'statusCodeOrg','')!~'^(PGS_[0-9]{2})?$'
     or jsonb_typeof(p_evidence->'courier') is distinct from 'string' or jsonb_typeof(p_evidence->'trackingNumber') is distinct from 'string'
     or length(p_evidence->>'courier')>80 or length(p_evidence->>'trackingNumber')>100
     or p_evidence->>'courier'~'[[:cntrl:]]' or p_evidence->>'trackingNumber'~'[[:cntrl:]]' then
       raise exception 'print_order_request_proof_required' using errcode='23514';end if;
   -- A deposit was already attempted; this GET proves it reached production.
   -- Preserve hold/operator review, but recover tracking without another POST.
   if r.supplier_production_evidence is not null and r.supplier_production_evidence<>p_evidence then
     raise exception 'print_order_request_proof_conflict' using errcode='23514';end if;
   update private.print_order_requests set supplier_production_evidence=p_evidence,status='REVIEW_REQUIRED',last_error_code='production_review_required',
     lease_owner=null,lease_until=null,updated_at=now() where id=r.id returning * into r;
   update public.orders set print_fulfillment_status='ACCEPTED',print_accepted_at=coalesce(print_accepted_at,now()),status='IN_PRODUCTION',
     print_customer_request_hold=true,print_requires_action=true,print_package_lock_token=null,print_package_lock_until=null where order_id=r.order_id;
   update private.print_fulfillment_outbox set event_type='POLL',state='PENDING',available_at=now(),lease_owner=null,lease_until=null,
     last_error_code='production_review_required',updated_at=now() where id=j.id;
   return private.print_request_public(r);
 end if;
 if p_step in('WAITING','REVIEW') then
   if p_evidence-array['code']<>'{}'::jsonb or coalesce(p_evidence->>'code','')!~'^[a-z_]{1,80}$' then raise exception 'invalid_print_order_request' using errcode='22023';end if;
   update private.print_order_requests set status=case p_step when 'WAITING' then 'WAITING_PROVIDER' else 'REVIEW_REQUIRED' end,
     last_error_code=p_evidence->>'code',lease_owner=null,lease_until=null,updated_at=now() where id=r.id returning * into r;
   return private.print_request_public(r);
 end if;
 if r.type='GENERAL' or not o.print_customer_request_hold or o.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') or o.print_accepted_at is not null then
   raise exception 'print_order_request_review_required' using errcode='23514';end if;
 if p_step='UNPAID' then
   if i.status not in('FAILED','CANCELED') or i.payment_receipt->'verifiedUnpaid' is distinct from 'true'::jsonb then raise exception 'print_order_request_proof_required' using errcode='23514';end if;
   update private.print_order_requests set status='COMPLETED',resolution='CANCELLED_UNPAID',lease_owner=null,lease_until=null,updated_at=now() where id=r.id returning * into r;
   return private.print_request_public(r);
 end if;
 if i.status<>'PAID' or i.payment_receipt->>'environment' is distinct from 'live' or i.payment_receipt->'isTest' is distinct from 'false'::jsonb then
   raise exception 'print_order_request_proof_required' using errcode='23514';end if;
 if p_step='SUPPLIER_ATTEMPT' then
   if r.supplier_cancel_attempted_at is not null then raise exception 'print_order_request_attempt_already_recorded' using errcode='23514';end if;
   update private.print_order_requests set supplier_cancel_attempt_id=gen_random_uuid(),supplier_cancel_attempted_at=now(),updated_at=now() where id=r.id returning * into r;
 elsif p_step='SUPPLIER_CANCELED' then
   if p_evidence-array['orderNum','orderSeq','statusCode','statusCodeOrg']<>'{}'::jsonb or p_evidence->>'orderNum' is distinct from 'SFO_'||replace(i.id::text,'-','')
     or p_evidence->'orderSeq' is distinct from '1'::jsonb or not coalesce(p_evidence->>'statusCode'='PGS_01' or p_evidence->>'statusCodeOrg' in('PGS_01','PGS_02'),false) then
     raise exception 'print_order_request_proof_required' using errcode='23514';end if;
   if r.supplier_cancel_evidence is not null and r.supplier_cancel_evidence<>p_evidence then raise exception 'print_order_request_proof_conflict' using errcode='23514';end if;
   update private.print_order_requests set supplier_cancel_evidence=p_evidence,updated_at=now() where id=r.id returning * into r;
 elsif p_step in('PG_ATTEMPT','REFUND') then
   select * into j from private.print_fulfillment_outbox where order_id=r.order_id;
   never_attempted:=j.payload->'supplierAttemptedAt' is null and coalesce(j.payload->>'queryOnly','false')='false'
     and coalesce(j.payload->>'depositAttempted','false')='false' and o.print_submitted_at is null and coalesce(o.print_vendor_order_id,'')='';
   if not coalesce(never_attempted,false) and r.supplier_cancel_evidence is null then raise exception 'print_supplier_cancel_proof_required' using errcode='23514';end if;
   if p_step='PG_ATTEMPT' then
     if r.pg_cancel_attempted_at is not null then raise exception 'print_order_request_attempt_already_recorded' using errcode='23514';end if;
     update private.print_order_requests set pg_cancel_attempt_id=gen_random_uuid(),pg_cancel_attempted_at=now(),updated_at=now() where id=r.id returning * into r;
   else
     if p_evidence-array['provider','version','status','paymentId','transactionId','storeId','channelKey','amount','paidAmount','discountAmount','cancelledAmount','currency',
        'environment','isTest','cancelledAt','cancellationIds','verifiedFullRefund']<>'{}'::jsonb
       or p_evidence->>'provider' is distinct from 'PORTONE' or p_evidence->>'version' is distinct from 'V2' or p_evidence->>'status' is distinct from 'CANCELLED'
       or p_evidence->>'paymentId' is distinct from i.payment_id or p_evidence->>'transactionId' is distinct from i.payment_receipt->>'transactionId'
       or p_evidence->>'storeId' is distinct from i.store_id or p_evidence->>'channelKey' is distinct from i.channel_key
       or p_evidence->>'environment' is distinct from 'live' or p_evidence->'isTest' is distinct from 'false'::jsonb or p_evidence->>'currency' is distinct from 'KRW'
       or p_evidence->'verifiedFullRefund' is distinct from 'true'::jsonb or p_evidence->'amount' is distinct from to_jsonb(i.amount)
       or p_evidence->'paidAmount' is distinct from i.payment_receipt->'paidAmount' or p_evidence->'discountAmount' is distinct from i.payment_receipt->'discountAmount'
       or jsonb_typeof(p_evidence->'cancellationIds') is distinct from 'array' or jsonb_array_length(p_evidence->'cancellationIds')=0
       or coalesce(p_evidence->>'cancelledAmount','')!~'^[0-9]+$' or coalesce(p_evidence->>'cancelledAt','')!~'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' then
       raise exception 'print_order_request_proof_required' using errcode='23514';end if;
     paid:=(p_evidence->>'paidAmount')::bigint;discount:=(p_evidence->>'discountAmount')::bigint;cancelled:=(p_evidence->>'cancelledAmount')::bigint;
     if paid<=0 or paid+discount<>i.amount or cancelled<paid or cancelled>i.amount or exists(select 1 from jsonb_array_elements_text(p_evidence->'cancellationIds') x where x!~'^[A-Za-z0-9_-]{1,200}$') then
       raise exception 'print_order_request_proof_required' using errcode='23514';end if;
     select * into v from private.print_payment_reversals where intent_id=i.id;
     if found and v.receipt<>p_evidence then raise exception 'print_order_request_proof_conflict' using errcode='23514';end if;
     insert into private.print_payment_reversals(intent_id,request_id,order_id,payment_id,receipt) values(i.id,r.id,i.order_id,i.payment_id,p_evidence)
       on conflict(intent_id) do nothing;
     select * into strict v from private.print_payment_reversals where intent_id=i.id;
     update public.orders set status='CANCELED',payment_reversed_at=v.verified_at,payment_reversal_status='FULL_REFUND',print_requires_action=false,
       print_package_lock_token=null,print_package_lock_until=null where order_id=i.order_id;
     update private.print_order_requests set status='COMPLETED',resolution='REFUNDED_FULL',refund_evidence=p_evidence,lease_owner=null,lease_until=null,updated_at=now()
       where id=r.id returning * into r;
   end if;
 else raise exception 'invalid_print_order_request' using errcode='22023';end if;
 return private.print_request_public(r)||jsonb_build_object('pgAttemptId',r.pg_cancel_attempt_id,'supplierAttemptId',r.supplier_cancel_attempt_id);
end;$$;

create function private.guard_print_request_immutable() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if row(new.id,new.request_id,new.user_id,new.intent_id,new.order_id,new.type,new.reason,new.fingerprint,new.created_at)
    is distinct from row(old.id,old.request_id,old.user_id,old.intent_id,old.order_id,old.type,old.reason,old.fingerprint,old.created_at)
   or(old.supplier_cancel_attempted_at is not null and row(new.supplier_cancel_attempt_id,new.supplier_cancel_attempted_at) is distinct from row(old.supplier_cancel_attempt_id,old.supplier_cancel_attempted_at))
   or(old.pg_cancel_attempted_at is not null and row(new.pg_cancel_attempt_id,new.pg_cancel_attempted_at) is distinct from row(old.pg_cancel_attempt_id,old.pg_cancel_attempted_at))
   or(old.supplier_cancel_evidence is not null and new.supplier_cancel_evidence is distinct from old.supplier_cancel_evidence)
   or(old.refund_evidence is not null and new.refund_evidence is distinct from old.refund_evidence)
   or(old.supplier_production_evidence is not null and new.supplier_production_evidence is distinct from old.supplier_production_evidence)
   or(old.status='COMPLETED' and row(new.status,new.resolution,new.refund_evidence) is distinct from row(old.status,old.resolution,old.refund_evidence)) then
   raise exception 'print_order_request_immutable' using errcode='23514';end if;
 return new;
end;$$;
create trigger print_order_request_immutable before update on private.print_order_requests for each row execute function private.guard_print_request_immutable();

revoke all on function public.create_owned_print_order_request(uuid,uuid,text,text,text,text,uuid),public.get_owned_print_order_request(uuid,uuid,text,text,uuid),
 public.claim_print_order_request(uuid,uuid),public.advance_print_order_request(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.create_owned_print_order_request(uuid,uuid,text,text,text,text,uuid),public.get_owned_print_order_request(uuid,uuid,text,text,uuid),
 public.claim_print_order_request(uuid,uuid),public.advance_print_order_request(uuid,uuid,text,jsonb) to service_role;

create function public.list_print_order_requests(p_limit integer default 50,p_order_id text default null,p_pending_only boolean default false)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;
begin
 if p_limit not between 1 and 50 or(p_order_id is not null and p_order_id!~'^ordp_[a-f0-9-]{36}$') then raise exception 'invalid_print_order_request' using errcode='22023';end if;
 select coalesce(jsonb_agg(x.item),'[]'::jsonb) into result from (
   select private.print_request_public(r)||case when p_pending_only then '{}'::jsonb else jsonb_build_object('reason',r.reason) end item
   from private.print_order_requests r where(p_order_id is null or r.order_id=p_order_id)
     and(not p_pending_only or(r.type<>'GENERAL' and r.status in('REQUESTED','WAITING_PROVIDER') and(r.lease_until is null or r.lease_until<=now())
       and r.updated_at<=now()-interval '1 minute'))
   order by case when p_pending_only then r.updated_at else null end,r.created_at desc,r.id limit p_limit
 ) x;
 return result;
end;$$;
revoke all on function public.list_print_order_requests(integer,text,boolean) from public,anon,authenticated;
grant execute on function public.list_print_order_requests(integer,text,boolean) to service_role;

-- Frozen checkout stays observable; a customer hold never permits another SDK launch.
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
    and c.environment='live' and c.store_id=i.store_id and c.channel_key=i.channel_key and c.worker_last_seen_at>now()-interval '5 minutes'
    and combo.spec_approved and combo.file_approved and combo.sample_approved and combo.retail_final and combo.supplier_cost_confirmed
    and combo.shipping_confirmed and combo.packaging_confirmed and combo.approved_spec=i.approved_spec
    and combo.cost_snapshot=i.cost_snapshot and combo.order_code=i.order_code,false);
  return to_jsonb(i)||jsonb_build_object('launch_ready',launch_ready and not exists(select 1 from public.orders where order_id=i.order_id and print_customer_request_hold),
    'request_hold',exists(select 1 from public.orders where order_id=i.order_id and print_customer_request_hold),
    'refunded_full',exists(select 1 from private.print_payment_reversals where intent_id=i.id));
end;$$;
create or replace function public.guard_print_order_update() returns trigger language plpgsql set search_path='' as $$
declare valid_paid boolean;valid_refund boolean;
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
  valid_refund:=old.checkout_flow='PORTONE_V2_V1' and old.status='PAYMENT_COMPLETED' and new.status='CANCELED'
    and row(new.verified_payment_id,new.verified_payment_provider,new.payment_confirmed_at) is not distinct from row(old.verified_payment_id,old.verified_payment_provider,old.payment_confirmed_at)
    and new.payment_reversal_status='FULL_REFUND' and exists(select 1 from private.print_payment_reversals r
      where r.order_id=old.order_id and r.payment_id=old.verified_payment_id and r.verified_at=new.payment_reversed_at
      and r.receipt->'verifiedFullRefund'='true'::jsonb and r.receipt->>'environment'='live' and r.receipt->'isTest'='false'::jsonb);
  if row(new.verified_payment_id,new.verified_payment_provider,new.payment_confirmed_at,new.payment_reversed_at,new.payment_reversal_status)
    is distinct from row(old.verified_payment_id,old.verified_payment_provider,old.payment_confirmed_at,old.payment_reversed_at,old.payment_reversal_status)
    and not (coalesce(valid_paid,false) or coalesce(valid_refund,false)) then raise exception 'physical_order_payments_disabled' using errcode='23514';end if;
  if old.checkout_flow='PORTONE_V2_V1' and new.status='CANCELED' and old.status is distinct from new.status
    and not(coalesce(valid_refund,false) or exists(select 1 from private.print_checkout_intents i where i.order_id=old.order_id
      and i.status in('FAILED','CANCELED') and i.payment_receipt->'verifiedUnpaid'='true'::jsonb)) then
    raise exception 'print_order_request_proof_required' using errcode='23514';end if;
  if old.print_customer_request_hold and old.status not in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') and new.status in('IN_PRODUCTION','PRINTING','SHIPPING','DELIVERED') and new.status is distinct from old.status
    and not(new.status='IN_PRODUCTION' and exists(select 1 from private.print_order_requests r join private.print_checkout_intents i on i.id=r.intent_id
      where r.order_id=old.order_id and r.status='REVIEW_REQUIRED' and r.supplier_production_evidence->>'orderNum'=old.print_vendor_order_id
        and r.supplier_production_evidence->'orderSeq'='1'::jsonb and r.supplier_production_evidence->>'statusCode' in('PGS_20','PGS_50','PGS_55')
        and i.status='PAID' and i.payment_receipt->>'environment'='live' and i.payment_receipt->'isTest'='false'::jsonb)) then
    raise exception 'print_customer_request_hold' using errcode='23514';end if;
  if old.print_customer_request_hold and not new.print_customer_request_hold then raise exception 'print_customer_request_hold' using errcode='23514';end if;
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
create or replace function public.claim_print_fulfillment_job(p_worker_id uuid,p_limit integer default 1,p_lease_seconds integer default 120,p_runtime_ready boolean default false)
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

-- Deposit shortage is visible, and a successful retry preserves an unrelated customer hold.
create or replace function public.fail_print_fulfillment_job(p_id uuid,p_owner uuid,p_error_code text,p_available_at timestamptz,p_terminal boolean default false)
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
  update public.orders set print_package_lock_token=null,print_package_lock_until=null,print_requires_action=print_customer_request_hold or p_terminal or p_error_code in('supplier_deposit_insufficient','supplier_deposit_unavailable') where order_id=j.order_id and print_package_lock_token=p_owner;
  return to_jsonb(j);
end;$$;
create or replace function public.finish_print_fulfillment_job(p_id uuid,p_owner uuid,p_expected_stage text,p_result jsonb)
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
  update public.orders set print_package_lock_token=null,print_package_lock_until=null,print_requires_action=print_customer_request_hold where order_id=j.order_id and print_package_lock_token=p_owner;
  return to_jsonb(j);
end;$$;

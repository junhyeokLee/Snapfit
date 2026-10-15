-- A preparation withdrawal is not a PG payment/refund receipt. It preserves
-- the original PREPARED intent and all payment references for later observation.
alter table public.orders add column print_preparation_aborted_at timestamptz;

alter table private.print_order_requests drop constraint print_order_requests_resolution_check;
alter table private.print_order_requests add constraint print_order_requests_resolution_check
 check(resolution in('NONE','CANCELLED_UNPAID','REFUNDED_FULL','PRE_SDK_ABORTED'));
create table private.print_pre_sdk_aborts (
 intent_id uuid primary key references private.print_checkout_intents(id),
 request_id uuid not null unique references private.print_order_requests(id),
 order_id text not null unique references public.orders(order_id), payment_id text not null unique,
 pg_absence_observation jsonb not null, aborted_at timestamptz not null default now()
);
alter table private.print_pre_sdk_aborts enable row level security;
revoke all on private.print_pre_sdk_aborts from public,anon,authenticated,service_role;
grant select,insert on private.print_pre_sdk_aborts to service_role;

create function private.print_pre_sdk_abort_verified(p_intent uuid) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from private.print_pre_sdk_aborts a
 join private.print_checkout_intents i on i.id=a.intent_id
 join public.orders o on o.order_id=i.order_id
 join private.print_order_requests r on r.id=a.request_id
 where i.id=p_intent and i.print_file_source='APP_UPLOADED' and i.status='PREPARED'
 and i.sdk_issued_at is null and i.payment_receipt is null and i.verified_at is null
 and o.status='PAYMENT_PENDING' and o.print_customer_request_hold
 and o.verified_payment_id is null and o.verified_payment_provider is null and o.payment_confirmed_at is null
 and o.payment_reversed_at is null and o.payment_reversal_status is null
 and a.order_id=i.order_id and a.payment_id=i.payment_id and r.intent_id=i.id
 and r.status='COMPLETED' and r.resolution='PRE_SDK_ABORTED' and r.type<>'GENERAL'
 and a.pg_absence_observation->>'provider'='PORTONE' and a.pg_absence_observation->>'version'='V2'
 and a.pg_absence_observation->>'status'='NOT_FOUND' and a.pg_absence_observation->'httpStatus'='404'::jsonb
 and a.pg_absence_observation->>'paymentId'=i.payment_id and a.pg_absence_observation->>'storeId'=i.store_id
 and a.pg_absence_observation->>'channelKey'=i.channel_key and a.pg_absence_observation->'amount'=to_jsonb(i.amount)
 and not exists(select 1 from private.print_payment_reversals v where v.intent_id=i.id)
 and not exists(select 1 from private.print_fulfillment_outbox j where j.order_id=i.order_id));
$$;
revoke all on function private.print_pre_sdk_abort_verified(uuid) from public,anon,authenticated;
grant execute on function private.print_pre_sdk_abort_verified(uuid) to service_role;

create or replace function private.print_request_public(r private.print_order_requests) returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('requestId',r.request_id,'type',r.type,'status',r.status,'resolution',r.resolution,
  'replacementAllowed',r.status='COMPLETED' and (r.resolution in('CANCELLED_UNPAID','REFUNDED_FULL')
    or(r.resolution='PRE_SDK_ABORTED' and private.print_pre_sdk_abort_verified(r.intent_id))),
  'preSdkAbortVerified',r.resolution='PRE_SDK_ABORTED' and private.print_pre_sdk_abort_verified(r.intent_id),
  'orderId',r.order_id,'paymentId',(select i.payment_id from private.print_checkout_intents i where i.id=r.intent_id),
  'checkoutRequestId',(select i.request_id from private.print_checkout_intents i where i.id=r.intent_id),
  'createdAt',r.created_at,'updatedAt',r.updated_at);
$$;

create function private.guard_print_preparation_abort_label() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if old.print_preparation_aborted_at is not null and new.print_preparation_aborted_at is distinct from old.print_preparation_aborted_at then
  raise exception 'print_pre_sdk_abort_immutable' using errcode='23514';end if;
 if old.print_preparation_aborted_at is null and new.print_preparation_aborted_at is not null and not(
  old.status='PAYMENT_PENDING' and new.status='PAYMENT_PENDING' and exists(select 1 from private.print_pre_sdk_aborts a
   where a.order_id=old.order_id and a.aborted_at=new.print_preparation_aborted_at
    and private.print_pre_sdk_abort_verified(a.intent_id))) then
  raise exception 'print_pre_sdk_abort_proof_required' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.guard_print_preparation_abort_label() from public,anon,authenticated;
create trigger orders_guard_preparation_abort_label before update on public.orders
 for each row execute function private.guard_print_preparation_abort_label();

create function public.abort_print_pre_sdk_request(p_request_id uuid,p_owner uuid,p_pg_observation jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare seed private.print_order_requests; r private.print_order_requests; i private.print_checkout_intents;
 o public.orders; a private.print_pre_sdk_aborts; observed_at timestamptz;
begin
 if p_request_id is null or p_owner is null then raise exception 'invalid_print_order_request' using errcode='22023';end if;
 select * into seed from private.print_order_requests where request_id=p_request_id;
 if not found then raise exception 'print_order_request_not_found' using errcode='P0002';end if;
 -- The same intent-first order as checkout authorization and request creation:
 -- a concurrent SDK grant must finish first or see the already-established hold.
 select * into strict i from private.print_checkout_intents where id=seed.intent_id for update;
 select * into strict o from public.orders where order_id=i.order_id for update;
 select * into strict r from private.print_order_requests where id=seed.id for update;
 if r.status='COMPLETED' then return jsonb_build_object('aborted',r.resolution='PRE_SDK_ABORTED'
   and private.print_pre_sdk_abort_verified(i.id),'request',private.print_request_public(r));end if;
 if r.lease_owner is distinct from p_owner or r.lease_until is null or r.lease_until<=now() then
  raise exception 'print_order_request_lease_lost' using errcode='23514';end if;
 if i.print_file_source<>'APP_UPLOADED' or i.status<>'PREPARED' or i.sdk_issued_at is not null
  or i.payment_receipt is not null or i.verified_at is not null or r.type='GENERAL'
  or r.user_id is distinct from i.user_id or r.order_id is distinct from i.order_id
  or o.user_id is distinct from i.user_id or o.status<>'PAYMENT_PENDING' or not o.print_customer_request_hold
  or o.verified_payment_id is not null or o.verified_payment_provider is not null or o.payment_confirmed_at is not null
  or o.payment_reversed_at is not null or o.payment_reversal_status is not null
  or o.print_submitted_at is not null or coalesce(o.print_vendor_order_id,'')<>'' or o.print_accepted_at is not null
  or o.print_file_checked_at is not null or o.shipped_at is not null
  or o.print_package_lock_token is not null or o.print_package_lock_until is not null
  or r.supplier_cancel_attempt_id is not null or r.supplier_cancel_attempted_at is not null or r.supplier_cancel_evidence is not null
  or r.pg_cancel_attempt_id is not null or r.pg_cancel_attempted_at is not null or r.refund_evidence is not null or r.supplier_production_evidence is not null
  or exists(select 1 from private.print_fulfillment_outbox j where j.order_id=i.order_id)
  or exists(select 1 from private.print_payment_reversals v where v.intent_id=i.id) then
  return jsonb_build_object('aborted',false);end if;
 -- A server-authenticated GET 404 is also required. An absent SDK grant alone
 -- is insufficient: payment IDs are public and must not hide an observed charge.
 if p_pg_observation is null or jsonb_typeof(p_pg_observation)<>'object'
  or p_pg_observation-array['provider','version','status','paymentId','storeId','channelKey','amount','currency','environment','httpStatus','observedAt']<>'{}'::jsonb
  or p_pg_observation->>'provider' is distinct from 'PORTONE' or p_pg_observation->>'version' is distinct from 'V2'
  or p_pg_observation->>'status' is distinct from 'NOT_FOUND' or p_pg_observation->'httpStatus' is distinct from '404'::jsonb
  or p_pg_observation->>'paymentId' is distinct from i.payment_id or p_pg_observation->>'storeId' is distinct from i.store_id
  or p_pg_observation->>'channelKey' is distinct from i.channel_key or p_pg_observation->'amount' is distinct from to_jsonb(i.amount)
  or p_pg_observation->>'currency' is distinct from 'KRW' or p_pg_observation->>'environment' is distinct from 'live'
  or i.environment<>'live' or i.channel_key='channel-key-34782ac7-e644-4234-ad27-2767b6904f88'
  or coalesce(p_pg_observation->>'observedAt','') !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$' then
  raise exception 'print_order_request_proof_required' using errcode='23514';end if;
 observed_at:=(p_pg_observation->>'observedAt')::timestamptz;
 if observed_at<now()-interval '3 minutes' or observed_at>now()+interval '5 seconds' then
  raise exception 'print_order_request_proof_required' using errcode='23514';end if;
 insert into private.print_pre_sdk_aborts(intent_id,request_id,order_id,payment_id,pg_absence_observation)
  values(i.id,r.id,i.order_id,i.payment_id,p_pg_observation) on conflict(intent_id) do nothing;
 select * into strict a from private.print_pre_sdk_aborts where intent_id=i.id;
 if a.request_id is distinct from r.id or a.order_id is distinct from i.order_id or a.payment_id is distinct from i.payment_id then
  raise exception 'print_order_request_proof_conflict' using errcode='23514';end if;
 -- No status or payment receipt is fabricated. The persistent hold rejects new
 -- SDK/package work, while a later real receipt can still be recorded for review.
 update private.print_order_requests set status='COMPLETED',resolution='PRE_SDK_ABORTED',lease_owner=null,lease_until=null,
  last_error_code=null,updated_at=now() where id=r.id returning * into r;
 update public.orders set print_requires_action=false,print_preparation_aborted_at=a.aborted_at where order_id=i.order_id;
 return jsonb_build_object('aborted',true,'request',private.print_request_public(r));
end;$$;
revoke all on function public.abort_print_pre_sdk_request(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.abort_print_pre_sdk_request(uuid,uuid,jsonb) to service_role;

-- Ordinary unissued preparations require no PG polling. Withdrawn references
-- receive a seven-day bounded observation window for any unexpected later money.
create or replace function public.claim_production_print_payment_rechecks(p_limit integer default 3)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
 if p_limit<1 or p_limit>3 then raise exception 'invalid_recheck_limit' using errcode='22023';end if;
 with ready as (select i.id from private.print_checkout_intents i where i.status='PREPARED' and i.next_check_at<=now()
  and(i.print_file_source<>'APP_UPLOADED' or i.sdk_issued_at is not null
   or exists(select 1 from private.print_pre_sdk_aborts a where a.intent_id=i.id and a.aborted_at>now()-interval '7 days'))
  order by i.next_check_at for update of i skip locked limit p_limit),claimed as (
   update private.print_checkout_intents i set last_checked_at=now(),next_check_at=now()+interval '1 minute'
   from ready where i.id=ready.id returning i.user_id,i.payment_id)
 select coalesce(jsonb_agg(to_jsonb(claimed)),'[]') into result from claimed;
 return result;
end;$$;
revoke all on function public.claim_production_print_payment_rechecks(integer) from public,anon,authenticated;
grant execute on function public.claim_production_print_payment_rechecks(integer) to service_role;

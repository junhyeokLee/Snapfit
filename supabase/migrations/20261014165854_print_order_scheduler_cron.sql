-- Provision these two Vault entries outside this migration, without printing
-- their decrypted contents. The 64hex value must match the Edge secret named
-- PRINT_ORDER_SCHEDULER_SECRET. No Supabase service-role key goes into Cron.
--   snapfit_print_order_scheduler_secret
--   snapfit_print_order_scheduler_project_url
-- This migration updates the payment recheck filter and this task's own Cron
-- job. Pending HTTP headers contain only a single-use HMAC signature, never the
-- long-lived secret; protected extension-owner ACLs are not modified. It does not
-- enable customer sales, production payments, deposits or factory production.
-- Unissued app-PDF preparation has no SDK transaction to observe. Legacy
-- recovery is preserved, and issued ambiguous payments have no expiry cutoff.
create or replace function public.claim_production_print_payment_rechecks(p_limit integer default 3)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare result jsonb;
begin
  if p_limit<1 or p_limit>3 then raise exception 'invalid_recheck_limit' using errcode='22023';end if;
  with ready as (select id from private.print_checkout_intents where status='PREPARED' and next_check_at<=now()
    and (print_file_source<>'APP_UPLOADED' or sdk_issued_at is not null)
    order by next_check_at for update skip locked limit p_limit), claimed as (
    update private.print_checkout_intents i set last_checked_at=now(),next_check_at=now()+interval '1 minute'
    from ready where i.id=ready.id returning i.user_id,i.payment_id)
  select coalesce(jsonb_agg(to_jsonb(claimed)),'[]') into result from claimed;
  return result;
end;$$;
revoke all on function public.claim_production_print_payment_rechecks(integer) from public,anon,authenticated;
grant execute on function public.claim_production_print_payment_rechecks(integer) to service_role;

create table if not exists private.print_order_scheduler_nonces (
  id uuid primary key,
  signed_at bigint not null check (signed_at between 1000000000 and 9999999999),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);
alter table private.print_order_scheduler_nonces enable row level security;
revoke all on private.print_order_scheduler_nonces from public, anon, authenticated;
grant select, update on private.print_order_scheduler_nonces to service_role;

create or replace function public.consume_print_order_scheduler_nonce(p_nonce uuid, p_signed_at bigint)
returns boolean language sql security invoker set search_path = '' as $$
  with consumed as (
    update private.print_order_scheduler_nonces set consumed_at = now()
      where id = p_nonce and signed_at = p_signed_at and consumed_at is null
        and expires_at > now()
        and p_signed_at >= floor(extract(epoch from now())) - 120
        and p_signed_at <= floor(extract(epoch from now())) + 120
      returning id
  ) select exists(select 1 from consumed);
$$;
revoke all on function public.consume_print_order_scheduler_nonce(uuid,bigint) from public, anon, authenticated;
grant execute on function public.consume_print_order_scheduler_nonce(uuid,bigint) to service_role;

do $scheduler_install$
declare
  own_job_name constant text := 'snapfit-print-order-scheduler';
  expected_project_url constant text := 'https://rrbhxdtriummqpztpjrk.supabase.co';
  secret_count integer;
  project_count integer;
begin
  if (select count(*) from pg_catalog.pg_extension
      where extname in ('pg_cron', 'pg_net', 'supabase_vault')) <> 3 then
    raise exception 'print_scheduler_extensions_required' using errcode = '55000';
  end if;

  if pg_catalog.to_regprocedure('extensions.hmac(text,text,text)') is null then
    raise exception 'print_scheduler_hmac_required' using errcode = '55000';
  end if;
  -- Vault plaintext must remain private. pg_net's extension-owned queue may
  -- be publicly readable, so it receives only short-lived one-use signatures.
  if exists (
    select 1 from (values ('anon'), ('authenticated')) as role_name(name)
    where (pg_catalog.has_schema_privilege(role_name.name, 'vault', 'USAGE')
       and pg_catalog.has_table_privilege(role_name.name, 'vault.decrypted_secrets', 'SELECT'))
  ) then
    raise exception 'print_scheduler_credentials_not_private' using errcode = '42501';
  end if;

  select count(*) into secret_count from vault.decrypted_secrets
    where name = 'snapfit_print_order_scheduler_secret'
      and decrypted_secret ~ '^[a-f0-9]{64}$';
  select count(*) into project_count from vault.decrypted_secrets
    where name = 'snapfit_print_order_scheduler_project_url'
      and decrypted_secret = expected_project_url;
  if secret_count <> 1 or project_count <> 1
      or (select count(*) from vault.decrypted_secrets
          where name in ('snapfit_print_order_scheduler_secret', 'snapfit_print_order_scheduler_project_url')) <> 2 then
    raise exception 'print_scheduler_vault_configuration_required' using errcode = '55000';
  end if;

  if exists (select 1 from cron.job where jobname = own_job_name and username <> current_user) then
    raise exception 'print_scheduler_job_owner_conflict' using errcode = '42501';
  end if;

  -- cron.schedule is an idempotent upsert for the exact case-sensitive job
  -- name. No other job is unscheduled, renamed, activated or modified.
  perform cron.schedule(own_job_name, '*/2 * * * *', $scheduler_command$
    -- Retain seven days of this job's run metadata only. Other jobs and all
    -- customer payment/order records are preserved.
    delete from cron.job_run_details
      where jobid in (select jobid from cron.job
        where jobname = 'snapfit-print-order-scheduler' and username = current_user)
        and end_time < now() - interval '7 days';
    delete from private.print_order_scheduler_nonces where expires_at < now() - interval '10 minutes';

    with configuration as (
      select
        max(decrypted_secret) filter (where name = 'snapfit_print_order_scheduler_project_url') as project_url,
        max(decrypted_secret) filter (where name = 'snapfit_print_order_scheduler_secret') as secret
      from vault.decrypted_secrets
      where name in ('snapfit_print_order_scheduler_project_url', 'snapfit_print_order_scheduler_secret')
      having count(*) = 2
        and count(*) filter (where name = 'snapfit_print_order_scheduler_project_url'
          and decrypted_secret = 'https://rrbhxdtriummqpztpjrk.supabase.co') = 1
        and count(*) filter (where name = 'snapfit_print_order_scheduler_secret'
          and decrypted_secret ~ '^[a-f0-9]{64}$') = 1
    ), fresh as (
      insert into private.print_order_scheduler_nonces(id, signed_at, expires_at)
        select pg_catalog.gen_random_uuid(), floor(extract(epoch from now()))::bigint, now() + interval '5 minutes'
        from configuration returning id, signed_at
    )
    select net.http_post(
      url := configuration.project_url || '/functions/v1/print-order-scheduler',
      headers := pg_catalog.jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Snapfit-Scheduler-Timestamp', fresh.signed_at::text,
        'X-Snapfit-Scheduler-Nonce', fresh.id::text,
        'X-Snapfit-Scheduler-Signature', pg_catalog.encode(extensions.hmac(
          'snapfit-print-order-scheduler:v1' || chr(10) || fresh.signed_at::text || chr(10) || fresh.id::text || chr(10) || '{}',
          configuration.secret, 'sha256'), 'hex')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 125000
    ) as request_id from configuration cross join fresh;
  $scheduler_command$);
end;
$scheduler_install$;

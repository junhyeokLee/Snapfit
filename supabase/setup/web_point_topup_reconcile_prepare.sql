-- Prepare the recovery schedule WITHOUT running it. Execute only after the
-- matching Edge secret and Vault secrets have been configured and verified.
-- The active schedule script is a separate later activation step.
begin;

do $prepare$
begin
  if to_regprocedure('cron.schedule_in_database(text,text,text,text,text,boolean)') is null then
    raise exception 'web_point_topup_inactive_schedule_not_supported';
  end if;
  if not exists (
    select 1 from vault.decrypted_secrets
    where name = 'snapfit_web_point_topup_reconcile_url'
      and decrypted_secret = 'https://rrbhxdtriummqpztpjrk.supabase.co/functions/v1/web-point-topup-reconcile'
  ) or not exists (
    select 1 from vault.decrypted_secrets
    where name = 'snapfit_web_point_topup_reconcile_secret'
      and length(decrypted_secret) >= 32
  ) then
    raise exception 'web_point_topup_reconcile_vault_not_ready';
  end if;
  if exists (
    select 1 from cron.job
    where jobname = 'snapfit-web-point-topup-reconcile'
      and (active or username <> current_user or database <> current_database())
  ) then
    raise exception 'web_point_topup_schedule_requires_review';
  end if;
end;
$prepare$;

-- active=false is supplied at creation, so a scheduler cannot invoke the job
-- between its registration and a later deactivation. No HTTP call runs here.
select cron.schedule_in_database(
  'snapfit-web-point-topup-reconcile',
  '*/5 * * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets
        where name = 'snapfit_web_point_topup_reconcile_url'),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret
          from vault.decrypted_secrets
          where name = 'snapfit_web_point_topup_reconcile_secret')
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $job$,
  current_database(),
  NULL,
  false
);

commit;

-- Configuration-only verification; never show the command or secret values.
select jobname, schedule, active, database, username
from cron.job where jobname = 'snapfit-web-point-topup-reconcile';

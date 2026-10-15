-- Optional activation step, not executed during web preparation.
-- First deploy web-point-topup-reconcile with its matching server secret.
-- Store the HTTPS /functions/v1/web-point-topup-reconcile URL in Vault as
-- snapfit_web_point_topup_reconcile_url and a 32+ character matching bearer
-- secret as snapfit_web_point_topup_reconcile_secret. No secrets belong here.
-- Only this new job is replaced. Existing push/IAP/print schedules are retained.
do $$
begin
  if not exists (select 1 from vault.decrypted_secrets
      where name = 'snapfit_web_point_topup_reconcile_url'
        and decrypted_secret ~ '^https://[^/]+/functions/v1/web-point-topup-reconcile$')
    or not exists (select 1 from vault.decrypted_secrets
      where name = 'snapfit_web_point_topup_reconcile_secret'
        and length(decrypted_secret) >= 32) then
    raise exception 'web_point_topup_reconcile_vault_not_ready';
  end if;
end;
$$;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.unschedule(jobid) from cron.job
where jobname = 'snapfit-web-point-topup-reconcile';
select cron.schedule('snapfit-web-point-topup-reconcile', '*/5 * * * *', $job$
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
$job$);

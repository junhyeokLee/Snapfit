-- Run after deploying iap-reconcile and configuring its matching Vault secrets.
-- Never store the bearer secret in this file or in cron.job.command.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.unschedule(jobid) from cron.job where jobname = 'snapfit-iap-reconcile';
select cron.schedule('snapfit-iap-reconcile', '*/5 * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
      where name = 'snapfit_iap_reconcile_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets
        where name = 'snapfit_iap_reconcile_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);

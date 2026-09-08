-- Run once after deploying push-dispatch and configuring its secrets.
-- Save matching Vault secrets named snapfit_push_dispatch_url and snapfit_push_dispatch_secret first.
-- The URL must be your project's /functions/v1/push-dispatch endpoint.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.unschedule(jobid) from cron.job where jobname = 'snapfit-push-dispatch';
select cron.schedule('snapfit-push-dispatch', '* * * * *', $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'snapfit_push_dispatch_url'),
    headers := jsonb_build_object('Content-Type', 'application/json', 'X-Push-Secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'snapfit_push_dispatch_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
$job$);

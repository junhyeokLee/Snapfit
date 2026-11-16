-- Avoid repeatedly scanning the large run-history heap during live work.
-- Remove repeated history scans from exactly two existing worker commands.
-- cron.job_run_details is extension-managed: no extension DDL/index/ACL changes.
-- Source identities come from the two authored cron migrations, including whitespace.
-- No Vault secret or HTTP header value is read, changed, returned or logged.
do $bounded_history_install$
declare
  change record;
  before_job cron.job%rowtype;
  after_job cron.job%rowtype;
  next_command text;
  marker constant text := '-- SnapFit history cleanup moved to bounded daily retention v1.';
  maintenance_name constant text := 'snapfit-owned-cron-history-retention';
  maintenance_schedule constant text := '17 19 * * *'; -- 04:17 Asia/Seoul.
  maintenance_command constant text := $daily_history$-- Only these two owned jobs retain seven days of completed run metadata.
-- A bounded batch leaves all other jobs, current runs and customer data intact.
begin;
set local lock_timeout = '1s';
set local statement_timeout = '5s';
with owned_jobs as materialized (
  select jobid from cron.job
  where username = current_user
    and jobname in ('snapfit-print-order-scheduler', 'snapfit-ai-template-worker')
), expired as materialized (
  select runid from cron.job_run_details
  where jobid in (select jobid from owned_jobs)
    and end_time < now() - interval '7 days'
  order by runid
  limit 10000
)
delete from cron.job_run_details as history
using expired where history.runid = expired.runid;
commit;
$daily_history$;
  maintenance_id bigint;
begin
  -- Serialize this installer without requiring UPDATE on extension metadata.
  -- The supported API cannot provide CAS against unrelated operator changes;
  -- run this installation under the project's single-owner change procedure.
  if not pg_try_advisory_xact_lock(hashtextextended('snapfit:bounded-cron-history-install:v1', 0)) then
    raise exception 'cron_history_installer_busy';
  end if;
  -- The whole DO block rolls back if either source or ownership is unexpected.
  for change in
    select * from (values
      ('snapfit-print-order-scheduler', '793625fa553006e30d962df84be8d50a', 'f0b9ef8e0ee2f77e605a7955f47e9b3b', $cleanup$delete from cron.job_run_details
      where jobid in (select jobid from cron.job
        where jobname = 'snapfit-print-order-scheduler' and username = current_user)
        and end_time < now() - interval '7 days';$cleanup$),
      ('snapfit-ai-template-worker', 'e799617d2c9365d63d51a35f1ee6ff21', '19afd7c32e0bd0b31af374d97ce0c91b', $cleanup$delete from cron.job_run_details where jobid in(select jobid from cron.job where jobname='snapfit-ai-template-worker' and username=current_user)
     and end_time<now()-interval '7 days';$cleanup$)
    ) as source(job_name, original_md5, refined_md5, cleanup_fragment)
  loop
    if (select count(*) from cron.job where jobname = change.job_name) <> 1 then
      raise exception 'cron_history_source_missing_or_ambiguous';
    end if;
    select * into strict before_job from cron.job
      where jobname = change.job_name;
    if before_job.username <> current_user then
      raise exception 'cron_history_source_owner_conflict';
    end if;
    if md5(before_job.command) = change.refined_md5 then
      continue; -- Reapplication never recreates or reactivates an existing job.
    end if;
    if md5(before_job.command) <> change.original_md5 then
      raise exception 'cron_history_source_command_not_recognized';
    end if;
    if (length(before_job.command) - length(replace(before_job.command, change.cleanup_fragment, '')))
       <> length(change.cleanup_fragment) then
      raise exception 'cron_history_cleanup_fragment_not_unique';
    end if;
    next_command := replace(before_job.command, change.cleanup_fragment, marker);
    if md5(next_command) <> change.refined_md5 then
      raise exception 'cron_history_refined_command_mismatch';
    end if;
    perform cron.alter_job(before_job.jobid, command := next_command);
    select * into strict after_job from cron.job where jobid = before_job.jobid;
    if (to_jsonb(after_job) - 'command') is distinct from (to_jsonb(before_job) - 'command')
       or after_job.command is distinct from next_command then
      raise exception 'cron_history_existing_job_state_changed';
    end if;
  end loop;

  if (select count(*) from cron.job where jobname = maintenance_name) > 1 then
    raise exception 'cron_history_maintenance_job_ambiguous';
  end if;
  select * into before_job from cron.job where jobname = maintenance_name;
  if found then
    if before_job.username <> current_user then
      raise exception 'cron_history_maintenance_owner_conflict';
    end if;
    if before_job.command is distinct from maintenance_command
       or before_job.schedule is distinct from maintenance_schedule then
      raise exception 'cron_history_maintenance_definition_not_recognized';
    end if;
    -- Preserve an operator's active=false choice and every other existing field.
  else
    maintenance_id := cron.schedule(maintenance_name, maintenance_schedule, maintenance_command);
    select * into strict after_job from cron.job where jobid = maintenance_id;
    if after_job.username <> current_user or after_job.jobname <> maintenance_name
       or after_job.schedule <> maintenance_schedule or after_job.command <> maintenance_command then
      raise exception 'cron_history_maintenance_installation_mismatch';
    end if;
  end if;
end;
$bounded_history_install$;

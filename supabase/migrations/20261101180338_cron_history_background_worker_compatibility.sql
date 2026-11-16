-- Preserve the deployed migration and worker commands. This follow-up only
-- removes explicit transaction control from the owned daily history job.
-- The current project uses libpq jobs (cron.use_background_workers=off), where
-- both versions work. Background-worker mode wraps a job in its own transaction
-- and rejects BEGIN/COMMIT: keep this job compatible with either execution mode.
-- Reference: citusdata/pg_cron src/pg_cron.c ExecuteSqlString.
do $cron_history_worker_compatibility$
declare
  before_job cron.job%rowtype;
  after_job cron.job%rowtype;
  next_command text;
  job_name constant text := 'snapfit-owned-cron-history-retention';
  original_md5 constant text := 'd5bb01f09134a8160c21a2da8b2e619c';
  compatible_md5 constant text := '4fc777efbace063251dcb81701804329';
begin
  if not pg_try_advisory_xact_lock(hashtextextended('snapfit:bounded-cron-history-install:v1', 0)) then
    raise exception 'cron_history_installer_busy';
  end if;
  if (select count(*) from cron.job where jobname = job_name) <> 1 then
    raise exception 'cron_history_compatibility_job_missing_or_ambiguous';
  end if;
  select * into strict before_job from cron.job where jobname = job_name;
  if before_job.username <> current_user then
    raise exception 'cron_history_compatibility_owner_conflict';
  end if;
  if md5(before_job.command) = compatible_md5 then
    return;
  end if;
  if md5(before_job.command) <> original_md5 then
    raise exception 'cron_history_compatibility_command_not_recognized';
  end if;
  next_command := replace(replace(before_job.command, E'\nbegin;\n', E'\n'), E'\ncommit;\n', E'\n');
  if md5(next_command) <> compatible_md5 then
    raise exception 'cron_history_compatible_command_mismatch';
  end if;
  perform cron.alter_job(before_job.jobid, command := next_command);
  select * into strict after_job from cron.job where jobid = before_job.jobid;
  if (to_jsonb(after_job) - 'command') is distinct from (to_jsonb(before_job) - 'command')
     or after_job.command is distinct from next_command then
    raise exception 'cron_history_compatibility_job_state_changed';
  end if;
end;
$cron_history_worker_compatibility$;

-- Roll forward the prepared job only. It remains inactive; no HTTP request or
-- file deletion is executed here, and the SQL/runtime switches remain closed.
do $retention_cadence$
declare jid bigint;
begin
 if pg_catalog.to_regnamespace('cron') is null then return;end if;
 select jobid into jid from cron.job where jobname='snapfit-print-file-retention' and username=current_user;
 if jid is null then raise exception 'retention_job_missing' using errcode='55000';end if;
 perform cron.alter_job(jid,schedule:='17 * * * *',active:=false);
end;
$retention_cadence$;

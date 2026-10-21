-- AI-only Vault capability; the existing print scheduler is not modified.
-- Provision snapfit_ai_template_worker_secret and
-- snapfit_ai_template_worker_project_url separately without printing values.
-- The Edge runtime uses AI_TEMPLATE_WORKER_SECRET. Queue headers contain only
-- a short-lived HMAC over an exact empty request and a private single-use nonce.
do $ai_worker_install$
declare own_name constant text:='snapfit-ai-template-worker'; own_id bigint;
 expected_url constant text:='https://rrbhxdtriummqpztpjrk.supabase.co';
begin
 if(select count(*) from pg_catalog.pg_extension where extname in('pg_cron','pg_net','supabase_vault'))<>3
   or pg_catalog.to_regprocedure('extensions.hmac(text,text,text)') is null then raise exception 'ai_worker_extensions_required';end if;
 if exists(select 1 from(values('anon'),('authenticated')) r(name)
   where pg_catalog.has_schema_privilege(r.name,'vault','USAGE') and pg_catalog.has_table_privilege(r.name,'vault.decrypted_secrets','SELECT'))
   then raise exception 'ai_worker_credentials_not_private';end if;
 if(select count(*) from vault.decrypted_secrets where name in('snapfit_ai_template_worker_secret','snapfit_ai_template_worker_project_url'))<>2
   or(select count(*) from vault.decrypted_secrets where name='snapfit_ai_template_worker_secret' and decrypted_secret~'^[a-f0-9]{64}$')<>1
   or(select count(*) from vault.decrypted_secrets where name='snapfit_ai_template_worker_project_url' and decrypted_secret=expected_url)<>1
   then raise exception 'ai_worker_vault_configuration_required';end if;
 if exists(select 1 from cron.job where jobname=own_name and username<>current_user) then raise exception 'ai_worker_job_owner_conflict';end if;
 own_id:=cron.schedule(own_name,'* * * * *',$ai_worker_command$
   select pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
   delete from private.ai_template_free_worker_nonces where expires_at<now()-interval '10 minutes';
   -- Durable payload retention is bounded even when no customer polls and no
   -- further HTTP work is due. Preserve consumed billing/audit records.
   with expired as(update private.ai_template_free_jobs set state=case when state='canceled' then state else 'failed' end,
       checkpoint=null,lease_owner=null,lease_until=null,last_error=case when expires_at<=now() then 'ai_generation_request_expired' else 'ai_generation_attempts_exhausted' end,updated_at=now()
     where(expires_at<=now() and(checkpoint is not null or state in('queued','running','waiting','ready')))
       or(attempts>=100 and state in('queued','waiting','running') and coalesce(lease_until,now())<=now()) returning intent_id,expires_at)
   update private.ai_template_generation_intents i set status=case when i.status='CONSUMED' then i.status when expired.expires_at<=now() then 'EXPIRED' else 'FAILED' end,
     result=null,lease_expires_at=now() from expired where i.id=expired.intent_id;
   delete from cron.job_run_details where jobid in(select jobid from cron.job where jobname='snapfit-ai-template-worker' and username=current_user)
     and end_time<now()-interval '7 days';
   with configuration as(
     select max(decrypted_secret) filter(where name='snapfit_ai_template_worker_project_url') as project_url,
       max(decrypted_secret) filter(where name='snapfit_ai_template_worker_secret') as secret
     from vault.decrypted_secrets where name in('snapfit_ai_template_worker_project_url','snapfit_ai_template_worker_secret')
     having count(*)=2 and count(*) filter(where name='snapfit_ai_template_worker_project_url' and decrypted_secret='https://rrbhxdtriummqpztpjrk.supabase.co')=1
       and count(*) filter(where name='snapfit_ai_template_worker_secret' and decrypted_secret~'^[a-f0-9]{64}$')=1
   ), fresh as(
     insert into private.ai_template_free_worker_nonces(id,signed_at,expires_at)
       select gen_random_uuid(),floor(extract(epoch from now()))::bigint,now()+interval '5 minutes' from configuration
       where exists(select 1 from private.ai_template_generation_policy p cross join private.ai_template_free_runtime r
         where p.singleton and r.singleton and p.enabled and p.free_jobs_enabled
           and coalesce(r.lease_until,now())<=now() and r.next_start_at<=now() and r.cooldown_until<=now())
       and exists(select 1 from private.ai_template_free_jobs j join private.ai_template_generation_intents i on i.id=j.intent_id
         where j.state in('queued','waiting','running') and j.expires_at>now() and j.attempts<100 and j.next_attempt_at<=now()
           and coalesce(j.lease_until,now())<=now() and i.status='GENERATING' and i.expires_at>now())
       returning id,signed_at
   )
   select net.http_post(url:=configuration.project_url||'/functions/v1/ai-template-worker',
     headers:=jsonb_build_object('Content-Type','application/json','X-Snapfit-AI-Timestamp',fresh.signed_at::text,
       'X-Snapfit-AI-Nonce',fresh.id::text,
       'X-Snapfit-AI-Signature',encode(extensions.hmac('snapfit-ai-template-worker:v1'||chr(10)||fresh.signed_at::text||chr(10)||fresh.id::text||chr(10)||'{}',configuration.secret,'sha256'),'hex')),
     body:='{}'::jsonb,timeout_milliseconds:=125000) from configuration cross join fresh;
 $ai_worker_command$);
 -- Installation cannot start generation. The separate policy gate also stays
 -- false until the route and read-back contracts are verified by the operator.
 perform cron.alter_job(own_id,active:=false);
end;
$ai_worker_install$;

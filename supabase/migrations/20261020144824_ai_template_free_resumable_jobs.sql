-- Structured, non-personal design options only. No customer prompt/photos,
-- credentials or preview files enter the durable queue. Activation is separate.
alter table private.ai_template_generation_policy
  add column free_jobs_enabled boolean not null default false;

create table private.ai_template_free_jobs (
  intent_id uuid primary key references private.ai_template_generation_intents(id) on delete cascade,
  safe_options jsonb not null check(jsonb_typeof(safe_options)='object' and octet_length(safe_options::text)<=4096),
  state text not null default 'queued' check(state in('queued','running','waiting','ready','failed','canceled')),
  stage text not null default 'direction' check(stage in('direction','composition','review','complete')),
  checkpoint jsonb check(checkpoint is null or (jsonb_typeof(checkpoint)='object' and octet_length(checkpoint::text)<=2097152)),
  lease_owner uuid, lease_until timestamptz,
  next_attempt_at timestamptz not null default now(),
  expires_at timestamptz not null default(now()+interval '7 days'),
  attempts integer not null default 0 check(attempts between 0 and 100),
  consecutive_failures integer not null default 0 check(consecutive_failures between 0 and 100),
  last_error text check(last_error is null or last_error ~ '^[a-z][a-z0-9_:-]{0,99}$'),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index ai_template_free_due_idx on private.ai_template_free_jobs(next_attempt_at,created_at)
  where state in('queued','running','waiting');
create table private.ai_template_free_runtime (
  singleton boolean primary key default true check(singleton),
  lease_owner uuid, lease_until timestamptz,
  next_start_at timestamptz not null default now(),
  cooldown_until timestamptz not null default now()
);
insert into private.ai_template_free_runtime(singleton) values(true);
create table private.ai_template_free_worker_nonces (
  id uuid primary key, signed_at bigint not null check(signed_at between 1000000000 and 9999999999),
  expires_at timestamptz not null, consumed_at timestamptz
);
alter table private.ai_template_free_jobs enable row level security;
alter table private.ai_template_free_runtime enable row level security;
alter table private.ai_template_free_worker_nonces enable row level security;
revoke all on private.ai_template_free_jobs,private.ai_template_free_runtime,private.ai_template_free_worker_nonces from public,anon,authenticated;
grant select,insert,update,delete on private.ai_template_free_jobs,private.ai_template_free_runtime,private.ai_template_free_worker_nonces to service_role;

create function private.valid_free_ai_template_options(v jsonb,p_pages integer)
returns boolean language plpgsql immutable set search_path='' as $$
declare product jsonb; dims integer[]; aspect text;
begin
  if v is null or jsonb_typeof(v)<>'object' then return false;end if;
  if octet_length(v::text)>4096
    or v-'version'-'topic'-'mood'-'palette'-'density'-'pageCount'-'aspect'-'printProduct'<>'{}'::jsonb
    or not(v ?& array['version','topic','mood','palette','density','pageCount','aspect'])
    or v->'version' is distinct from '1'::jsonb or v->'pageCount' is distinct from to_jsonb(p_pages)
    or p_pages is null or p_pages not between 20 and 80 or p_pages%2<>0
    or coalesce(v->>'topic','') not in('travel','family','baby','couple','friends','daily','celebration')
    or coalesce(v->>'mood','') not in('editorial','warm','minimal','playful','elegant')
    or coalesce(v->>'palette','') not in('neutral','warm','cool','pastel','vivid')
    or coalesce(v->>'density','') not in('quiet','balanced','layered')
    or coalesce(v->>'aspect','') not in('portrait','square','landscape')
    or exists(select 1 from jsonb_each(v) e where e.key in('topic','mood','palette','density','aspect') and jsonb_typeof(e.value)<>'string')
  then return false;end if;
  if v ? 'printProduct' then
    product:=v->'printProduct';
    if jsonb_typeof(product)<>'object' or product-'id'-'trimWidthMm'-'trimHeightMm'<>'{}'::jsonb
      or not(product ?& array['id','trimWidthMm','trimHeightMm']) then return false;end if;
    dims:=case product->>'id'
      when 'REDP_200X150_SOFT' then array[200,150] when 'REDP_200X150_HARD' then array[200,150]
      when 'REDP_200_SOFT' then array[200,200] when 'REDP_200_HARD' then array[200,200]
      when 'REDP_250X200_SOFT' then array[250,200] when 'REDP_250X200_HARD' then array[250,200]
      when 'REDP_250_SOFT' then array[250,250] when 'REDP_250_HARD' then array[250,250]
      when 'REDP_300_SOFT' then array[300,300] when 'REDP_300_HARD' then array[300,300] else null end;
    aspect:=case when dims[1]>dims[2] then 'landscape' else 'square' end;
    if dims is null or product->'trimWidthMm' is distinct from to_jsonb(dims[1])
      or product->'trimHeightMm' is distinct from to_jsonb(dims[2]) or v->>'aspect'<>aspect then return false;end if;
  end if;
  return true;
end;$$;
revoke all on function private.valid_free_ai_template_options(jsonb,integer) from public,anon,authenticated;
grant execute on function private.valid_free_ai_template_options(jsonb,integer) to service_role;

create function private.free_ai_template_job_response(p_id uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('job',jsonb_strip_nulls(jsonb_build_object(
   'id',i.request_id,'safeDesign',j.safe_options,'alreadyAccepted',i.status='CONSUMED',
   'state',case when i.status='CONSUMED' then 'consumed'
     when j.expires_at<=now() or i.status='EXPIRED' then 'failed'
     when j.state='canceled' then 'canceled' when i.status='FAILED' then 'failed' else j.state end,
   'stage',j.stage,'completedStages',coalesce(jsonb_array_length(j.checkpoint->'responses'),0),
   'nextAttemptAt',case when j.state in('queued','running','waiting') then greatest(j.next_attempt_at,r.cooldown_until,r.next_start_at) else j.next_attempt_at end,'expiresAt',j.expires_at,
   'error',case when j.expires_at<=now() or i.status='EXPIRED' then 'ai_generation_request_expired' else j.last_error end)))
   ||case when j.state='ready' and j.expires_at>now() and i.status in('READY','CONSUMED') and i.expires_at>now() and i.result is not null
     then jsonb_build_object('draft',i.result) else '{}'::jsonb end
 from private.ai_template_free_jobs j join private.ai_template_generation_intents i on i.id=j.intent_id
 cross join private.ai_template_free_runtime r where r.singleton and j.intent_id=p_id;
$$;
revoke all on function private.free_ai_template_job_response(uuid) from public,anon,authenticated;
grant execute on function private.free_ai_template_job_response(uuid) to service_role;

create function public.prepare_free_ai_template_job(p_actor uuid,p_request_id uuid,p_hash text,p_options jsonb,p_expected_point_cost integer,p_page_count integer)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare policy private.ai_template_generation_policy%rowtype; previous private.ai_template_generation_intents%rowtype;
  identity uuid:=gen_random_uuid(); until_at timestamptz:=now()+interval '7 days'; cost integer; is_free boolean;
begin
  if p_actor is null or p_request_id is null or p_hash is null or p_hash!~'^[a-f0-9]{64}$'
    or private.valid_free_ai_template_options(p_options,p_page_count) is not true then raise exception 'ai_generation_invalid_request';end if;
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||p_actor::text,0));
  select * into strict policy from private.ai_template_generation_policy where singleton;
  if not policy.enabled or not policy.free_jobs_enabled then raise exception 'ai_generation_disabled';end if;
  select * into previous from private.ai_template_generation_intents where user_id=p_actor and request_id=p_request_id;
  if found then
    if previous.brief_hash<>p_hash then raise exception 'ai_generation_request_conflict';end if;
    if not exists(select 1 from private.ai_template_free_jobs where intent_id=previous.id and safe_options=p_options)
      then raise exception 'ai_generation_request_conflict';end if;
    return private.free_ai_template_job_response(previous.id);
  end if;
  -- A waiting job owns its user's pending slot, but does not occupy execution
  -- capacity. Legacy admissions see its seven-day lease and cannot replace it.
  if exists(select 1 from private.ai_template_generation_intents i where i.user_id=p_actor and i.status='GENERATING' and i.lease_expires_at>now())
    then raise exception 'ai_generation_in_progress';end if;
  if (select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>=now()-interval '24 hours')>=policy.user_daily_limit
    or(select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>now()-interval '1 minute')>=2
    then raise exception 'ai_generation_rate_limited';end if;
  if (select count(*) from private.ai_template_generation_intents where created_at>=now()-interval '24 hours')>=policy.project_daily_limit
    or(select count(*) from private.ai_template_free_jobs where state in('queued','running','waiting') and expires_at>now())>=100
    then raise exception 'ai_generation_capacity_limited';end if;
  cost:=public.ai_album_draft_point_cost_for_pages(p_page_count);
  if cost is null or cost<0 then raise exception 'ai_generation_price_unavailable';end if;
  is_free:=not exists(select 1 from public.ai_album_free_draft_claims where user_id=p_actor);
  if p_expected_point_cost is null then raise exception 'ai_generation_price_confirmation_required';end if;
  if p_expected_point_cost<>(case when is_free then 0 else cost end) then raise exception 'ai_generation_price_changed';end if;
  if not is_free then
    perform 1 from public.point_wallets where user_id=p_actor and balance>=cost for update;
    if not found then raise exception 'ai_generation_insufficient_points';end if;
  end if;
  update private.ai_template_generation_intents set status='EXPIRED',result=null
    where user_id=p_actor and(status='READY' or(status='GENERATING' and lease_expires_at<=now()));
  update private.ai_template_generation_intents set result=null where expires_at<=now() and result is not null;
  insert into private.ai_template_generation_intents(id,user_id,request_id,brief_hash,draft_id,status,point_cost,reserved_free_credit,lease_expires_at,expires_at)
    values(identity,p_actor,p_request_id,p_hash,'original-template-'||identity::text,'GENERATING',cost,is_free,until_at,until_at);
  insert into private.ai_template_free_jobs(intent_id,safe_options,expires_at) values(identity,p_options,until_at);
  return private.free_ai_template_job_response(identity);
end;$$;

create function public.read_free_ai_template_job(p_actor uuid,p_request_id uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare selected_id uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
 update private.ai_template_generation_intents i set status='EXPIRED',result=null,lease_expires_at=now()
   from private.ai_template_free_jobs j where j.intent_id=i.id and i.user_id=p_actor and j.expires_at<=now() and i.status in('GENERATING','READY');
 update private.ai_template_free_jobs j set state='failed',checkpoint=null,lease_owner=null,lease_until=null,last_error='ai_generation_request_expired',updated_at=now()
   from private.ai_template_generation_intents i where i.id=j.intent_id and i.user_id=p_actor and j.expires_at<=now() and j.state in('queued','running','waiting','ready');
 select i.id into selected_id from private.ai_template_generation_intents i
 join private.ai_template_free_jobs j on j.intent_id=i.id where i.user_id=p_actor and(p_request_id is null or i.request_id=p_request_id)
 order by j.created_at desc,i.id desc limit 1;
 return private.free_ai_template_job_response(selected_id);
end;
$$;

create function public.cancel_free_ai_template_job(p_actor uuid,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare selected_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||coalesce(p_actor::text,''),0));
  select i.id into selected_id from private.ai_template_generation_intents i join private.ai_template_free_jobs j on j.intent_id=i.id
    where i.user_id=p_actor and i.request_id=p_request_id for update of i,j;
  if not found then return null;end if;
  if exists(select 1 from private.ai_template_generation_intents where id=selected_id and status='CONSUMED')
    then return private.free_ai_template_job_response(selected_id);end if;
  update private.ai_template_free_jobs set state='canceled',checkpoint=null,lease_owner=null,lease_until=null,last_error='ai_generation_canceled',updated_at=now() where intent_id=selected_id;
  update private.ai_template_generation_intents set status='FAILED',result=null,lease_expires_at=now() where id=selected_id;
  -- A canceled HTTP model call may still be running. Keep the global lease
  -- until its original deadline so a new user's call cannot overlap it.
  return private.free_ai_template_job_response(selected_id);
end;$$;

create function public.claim_free_ai_template_job()
returns jsonb language plpgsql security invoker set search_path='' as $$
declare runtime private.ai_template_free_runtime%rowtype; task private.ai_template_free_jobs%rowtype;
  intent private.ai_template_generation_intents%rowtype; owner uuid:=gen_random_uuid();
begin
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  if not exists(select 1 from private.ai_template_generation_policy where singleton and enabled and free_jobs_enabled) then return null;end if;
  select * into strict runtime from private.ai_template_free_runtime where singleton for update;
  if runtime.lease_until>now() or runtime.next_start_at>now() or runtime.cooldown_until>now() then return null;end if;
  -- Terminal cleanup never revives an old result. Expired/crashed workers lose
  -- their owner token, and every subsequent persistence operation is fenced.
  with ended as(update private.ai_template_free_jobs j set state='failed',checkpoint=null,lease_owner=null,lease_until=null,
      last_error=case when j.expires_at<=now() then 'ai_generation_request_expired' else 'ai_generation_attempts_exhausted' end,updated_at=now()
    where state in('queued','running','waiting') and(expires_at<=now() or(attempts>=100 and coalesce(lease_until,now())<=now())) returning intent_id,expires_at)
  update private.ai_template_generation_intents i set status=case when ended.expires_at<=now() then 'EXPIRED' else 'FAILED' end,result=null,lease_expires_at=now()
    from ended where i.id=ended.intent_id and i.status='GENERATING';
  select j.* into task from private.ai_template_free_jobs j join private.ai_template_generation_intents i on i.id=j.intent_id
    where j.state in('queued','waiting','running') and j.next_attempt_at<=now() and j.expires_at>now() and j.attempts<100
      and(j.lease_until is null or j.lease_until<=now()) and i.status='GENERATING' and i.expires_at>now()
    order by j.next_attempt_at,j.created_at for update of j skip locked limit 1;
  if not found then return null;end if;
  select * into strict intent from private.ai_template_generation_intents where id=task.intent_id;
  update private.ai_template_free_jobs set state='running',lease_owner=owner,lease_until=now()+interval '150 seconds',attempts=attempts+1,updated_at=now()
    where intent_id=task.intent_id returning * into task;
  update private.ai_template_free_runtime set lease_owner=owner,lease_until=task.lease_until,next_start_at=now()+interval '65 seconds' where singleton;
  return jsonb_build_object('id',intent.id,'actor',intent.user_id,'requestId',intent.request_id,'draftId',intent.draft_id,
    'safeOptions',task.safe_options,'checkpoint',task.checkpoint,'stage',task.stage,'leaseOwner',owner,'attempts',task.attempts,'consecutiveFailures',task.consecutive_failures);
end;$$;

create function public.save_free_ai_template_checkpoint(p_id uuid,p_owner uuid,p_checkpoint jsonb,p_stage text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  if p_checkpoint is null or jsonb_typeof(p_checkpoint)<>'object' or octet_length(p_checkpoint::text)>2097152
    or jsonb_typeof(p_checkpoint->'responses') is distinct from 'array' or jsonb_array_length(p_checkpoint->'responses')>100
    or p_stage is null or p_stage not in('direction','composition','review','complete') then raise exception 'ai_generation_invalid_checkpoint';end if;
  update private.ai_template_free_jobs j set checkpoint=p_checkpoint,stage=p_stage,consecutive_failures=0,updated_at=now()
    where j.intent_id=p_id and j.state='running' and j.lease_owner=p_owner and j.lease_until>now() and j.expires_at>now()
      and exists(select 1 from private.ai_template_free_runtime r where singleton and r.lease_owner=p_owner and r.lease_until>now())
      and exists(select 1 from private.ai_template_generation_intents i where i.id=p_id and i.status='GENERATING' and i.expires_at>now());
  if not found then raise exception 'ai_generation_lease_lost';end if;
end;$$;

create function public.settle_free_ai_template_job(p_id uuid,p_owner uuid,p_state text,p_stage text,p_retry_seconds integer default 60,p_error text default null,p_result jsonb default null)
returns void language plpgsql security invoker set search_path='' as $$
declare task private.ai_template_free_jobs%rowtype; intent private.ai_template_generation_intents%rowtype; delay_seconds integer; actor uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  if p_state is null or p_state not in('queued','waiting','ready','failed') or p_stage is null or p_stage not in('direction','composition','review','complete')
    or p_retry_seconds is null or p_retry_seconds<0 or p_retry_seconds>172800
    or(p_error is not null and p_error!~'^[a-z][a-z0-9_:-]{0,99}$') then raise exception 'ai_generation_invalid_request';end if;
  -- Match acceptance/cancellation's user-advisory -> intent-row lock order.
  -- Looking up ownership here deliberately takes no row lock first.
  select user_id into actor from private.ai_template_generation_intents where id=p_id;
  if actor is null then raise exception 'ai_generation_lease_lost';end if;
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||actor::text,0));
  select * into task from private.ai_template_free_jobs where intent_id=p_id for update;
  if not found or task.state<>'running' or task.lease_owner is distinct from p_owner or task.lease_until<=now() or task.expires_at<=now()
    or not exists(select 1 from private.ai_template_free_runtime where singleton and lease_owner=p_owner and lease_until>now()) then raise exception 'ai_generation_lease_lost';end if;
  select * into strict intent from private.ai_template_generation_intents where id=p_id for update;
  if intent.status<>'GENERATING' or intent.expires_at<=now() then raise exception 'ai_generation_lease_lost';end if;
  if p_state='ready' then
    if p_stage<>'complete' then raise exception 'ai_generation_invalid_result';end if;
    perform public.complete_ai_template_generation(intent.user_id,p_id,p_result);
    update private.ai_template_generation_intents set expires_at=task.expires_at,lease_expires_at=task.expires_at where id=p_id;
  elsif p_state='failed' then
    update private.ai_template_generation_intents set status='FAILED',result=null,lease_expires_at=now() where id=p_id;
  elsif p_result is not null then raise exception 'ai_generation_invalid_result';end if;
  delay_seconds:=case when p_state='waiting' then greatest(65,p_retry_seconds) else p_retry_seconds end;
  update private.ai_template_free_jobs set state=p_state,stage=p_stage,next_attempt_at=now()+make_interval(secs=>delay_seconds),
    checkpoint=case when p_state='failed' then null else checkpoint end,lease_owner=null,lease_until=null,last_error=p_error,
    consecutive_failures=case when p_state='waiting' then least(100,consecutive_failures+1) when p_state='ready' then 0 else consecutive_failures end,updated_at=now() where intent_id=p_id;
  update private.ai_template_free_runtime set lease_owner=null,lease_until=null,
    cooldown_until=case when p_state='waiting' then greatest(cooldown_until,now()+make_interval(secs=>delay_seconds)) else cooldown_until end where singleton and lease_owner=p_owner;
end;$$;

create function public.consume_free_ai_template_worker_nonce(p_nonce uuid,p_signed_at bigint)
returns boolean language sql security invoker set search_path='' as $$
 with consumed as(update private.ai_template_free_worker_nonces set consumed_at=now()
  where id=p_nonce and signed_at=p_signed_at and consumed_at is null and expires_at>now()
    and p_signed_at between floor(extract(epoch from now()))-120 and floor(extract(epoch from now()))+120 returning id)
 select exists(select 1 from consumed);
$$;
revoke all on function public.prepare_free_ai_template_job(uuid,uuid,text,jsonb,integer,integer),public.read_free_ai_template_job(uuid,uuid),public.cancel_free_ai_template_job(uuid,uuid),
 public.claim_free_ai_template_job(),public.save_free_ai_template_checkpoint(uuid,uuid,jsonb,text),public.settle_free_ai_template_job(uuid,uuid,text,text,integer,text,jsonb),
 public.consume_free_ai_template_worker_nonce(uuid,bigint) from public,anon,authenticated;
grant execute on function public.prepare_free_ai_template_job(uuid,uuid,text,jsonb,integer,integer),public.read_free_ai_template_job(uuid,uuid),public.cancel_free_ai_template_job(uuid,uuid),
 public.claim_free_ai_template_job(),public.save_free_ai_template_checkpoint(uuid,uuid,jsonb,text),public.settle_free_ai_template_job(uuid,uuid,text,text,integer,text,jsonb),
 public.consume_free_ai_template_worker_nonce(uuid,bigint) to service_role;

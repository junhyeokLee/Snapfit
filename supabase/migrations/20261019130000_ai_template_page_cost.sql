-- AI 템플릿 페이지 수 기반 포인트 비용.
--
-- 공식: 300 + pageCount * 10
-- 20쪽=500P, 30쪽=600P, 40쪽=700P, 50쪽=800P, 60쪽=900P, 70쪽=1000P, 80쪽=1100P
--
-- prepare_ai_template_generation 에 p_page_count 파라미터 추가.
-- 기존 시그니처(p_page_count 없음)를 삭제하고 새 시그니처로 대체.

create or replace function public.ai_album_draft_point_cost_for_pages(p_page_count integer)
returns integer language sql stable set search_path = ''
as $$
  select 300 + least(80, greatest(20, coalesce(p_page_count, 20))) * 10;
$$;

-- Drop old 5-argument overload, recreate with p_page_count (6 arguments).
drop function if exists public.prepare_ai_template_generation(uuid,uuid,text,integer,integer);

create function public.prepare_ai_template_generation(
  p_actor uuid,
  p_request_id uuid,
  p_brief_hash text,
  p_design_version integer default 1,
  p_expected_point_cost integer default null,
  p_page_count integer default 20
)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_policy private.ai_template_generation_policy%rowtype;
  v_previous private.ai_template_generation_intents%rowtype;
  v_id uuid := gen_random_uuid();
  v_cost integer;
  v_free boolean;
begin
  if p_actor is null or p_request_id is null or p_brief_hash is null or p_brief_hash !~ '^[a-f0-9]{64}$'
  then raise exception 'ai_generation_invalid_request' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-generation',0));
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||p_actor::text,0));
  select * into strict v_policy from private.ai_template_generation_policy where singleton;
  if not v_policy.enabled then raise exception 'ai_generation_disabled'; end if;
  if p_design_version not in (1,2,3) or p_design_version is null then raise exception 'ai_generation_invalid_request'; end if;
  if p_design_version=3 and not v_policy.v3_enabled then raise exception 'ai_generation_v3_not_validated'; end if;
  select * into v_previous from private.ai_template_generation_intents
    where user_id=p_actor and request_id=p_request_id;
  if found then
    if v_previous.brief_hash<>p_brief_hash then raise exception 'ai_generation_request_conflict'; end if;
    if v_previous.status in ('READY','CONSUMED') and v_previous.expires_at>now() and v_previous.result is not null then
      return jsonb_build_object('id',v_previous.id,'draftId',v_previous.draft_id,'cached',v_previous.result);
    end if;
    if v_previous.status='GENERATING' and v_previous.lease_expires_at>now()
    then raise exception 'ai_generation_in_progress'; end if;
    raise exception 'ai_generation_request_expired';
  end if;
  if exists(select 1 from private.ai_template_generation_intents where user_id=p_actor and status='GENERATING' and lease_expires_at>now())
  then raise exception 'ai_generation_in_progress'; end if;
  if (select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>=now()-interval '24 hours')>=v_policy.user_daily_limit
     or (select count(*) from private.ai_template_generation_intents where user_id=p_actor and created_at>now()-interval '1 minute')>=2
  then raise exception 'ai_generation_rate_limited'; end if;
  if (select count(*) from private.ai_template_generation_intents where created_at>=now()-interval '24 hours')>=v_policy.project_daily_limit
     or (select count(*) from private.ai_template_generation_intents where status='GENERATING' and lease_expires_at>now())>=v_policy.concurrent_limit
  then raise exception 'ai_generation_capacity_limited'; end if;
  v_cost:=public.ai_album_draft_point_cost_for_pages(p_page_count);
  if v_cost is null or v_cost<0 then raise exception 'ai_generation_price_unavailable'; end if;
  v_free:=not exists(select 1 from public.ai_album_free_draft_claims where user_id=p_actor);
  if p_design_version=3 and p_expected_point_cost is null then raise exception 'ai_generation_price_confirmation_required'; end if;
  if p_expected_point_cost is not null and p_expected_point_cost<>(case when v_free then 0 else v_cost end)
  then raise exception 'ai_generation_price_changed'; end if;
  if not v_free then
    perform 1 from public.point_wallets where user_id=p_actor and balance>=v_cost for update;
    if not found then raise exception 'ai_generation_insufficient_points'; end if;
  end if;
  update private.ai_template_generation_intents set status='EXPIRED',result=null
    where user_id=p_actor and (status='READY' or (status='GENERATING' and lease_expires_at<=now()));
  update private.ai_template_generation_intents set result=null where expires_at<=now() and result is not null;
  insert into private.ai_template_generation_intents(id,user_id,request_id,brief_hash,draft_id,status,point_cost,reserved_free_credit)
    values(v_id,p_actor,p_request_id,p_brief_hash,'original-template-'||v_id::text,'GENERATING',v_cost,v_free);
  return jsonb_build_object('id',v_id,'draftId','original-template-'||v_id::text);
end;
$$;

revoke all on function public.prepare_ai_template_generation(uuid,uuid,text,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.prepare_ai_template_generation(uuid,uuid,text,integer,integer,integer) to service_role;

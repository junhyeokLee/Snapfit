-- Keep billing policy, wallet arithmetic and idempotency unchanged. Capture only
-- the generated template name before bounded result retention removes it.
create or replace function public.record_ai_album_draft_success(p_draft_id text,p_point_cost integer default null)
returns table(used_free_credit boolean,charged_points integer,remaining_balance integer)
language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := auth.uid();
  v_intent private.ai_template_generation_intents%rowtype;
  v_existing public.ai_album_draft_usages%rowtype;
  v_balance integer;
begin
  if v_user is null then raise exception 'ai_draft_auth_required' using errcode='28000'; end if;
  if p_draft_id is null or length(p_draft_id)>150 or btrim(p_draft_id)='' then raise exception 'ai_draft_invalid_id' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('snapfit:ai-user:'||v_user::text,0));
  select * into v_existing from public.ai_album_draft_usages where user_id=v_user and draft_id=p_draft_id;
  if found then
    if v_existing.status<>'SUCCEEDED' then raise exception 'ai_draft_usage_voided'; end if;
    return query select v_existing.used_free_credit,case when v_existing.used_free_credit then 0 else v_existing.point_cost end,
      coalesce((select balance from public.point_wallets where user_id=v_user),0);
    return;
  end if;
  select * into v_intent from private.ai_template_generation_intents where user_id=v_user and draft_id=p_draft_id for update;
  if not found or v_intent.status<>'READY' or v_intent.result is null or v_intent.expires_at<=now()
  then raise exception 'ai_draft_not_reviewable' using errcode='22023'; end if;
  if p_point_cost is not null and p_point_cost<>v_intent.point_cost
  then raise exception 'ai_draft_price_mismatch' using errcode='22023'; end if;
  insert into public.point_wallets(user_id,balance) values(v_user,0) on conflict(user_id) do nothing;
  select balance into v_balance from public.point_wallets where user_id=v_user for update;
  if v_intent.reserved_free_credit then
    if exists(select 1 from public.ai_album_free_draft_claims where user_id=v_user)
    then raise exception 'ai_draft_free_credit_changed' using errcode='22023'; end if;
    insert into public.ai_album_free_draft_claims(user_id,draft_id) values(v_user,p_draft_id);
  else
    if v_balance<v_intent.point_cost then raise exception 'insufficient points for AI album draft' using errcode='P0001'; end if;
    update public.point_wallets set balance=balance-v_intent.point_cost where user_id=v_user returning balance into v_balance;
  end if;
  insert into public.ai_album_draft_usages(user_id,draft_id,point_cost,used_free_credit)
    values(v_user,p_draft_id,case when v_intent.reserved_free_credit then 0 else v_intent.point_cost end,v_intent.reserved_free_credit);
  insert into public.point_ledger(user_id,amount_delta,reason,idempotency_key,related_entity_type,related_entity_id,metadata)
    values(v_user,case when v_intent.reserved_free_credit then 0 else -v_intent.point_cost end,
      case when v_intent.reserved_free_credit then 'AI_ALBUM_DRAFT_FREE' else 'AI_ALBUM_DRAFT_CHARGE' end,
      'ai_template_accept:'||v_user::text||':'||p_draft_id,'ai_album_draft',p_draft_id,
      jsonb_build_object('generation_id',v_intent.id,'point_cost',v_intent.point_cost,'server_verified',true)
      -- Only a server-generated string is a display title; never stringify JSON.
      || jsonb_strip_nulls(jsonb_build_object('title',
        case when jsonb_typeof(v_intent.result->'title')='string'
          then nullif(btrim(v_intent.result->>'title',E' \t\r\n'),'')
          else null end)));
  update private.ai_template_generation_intents set status='CONSUMED' where id=v_intent.id;
  return query select v_intent.reserved_free_credit,case when v_intent.reserved_free_credit then 0 else v_intent.point_cost end,v_balance;
end;
$$;
revoke all on function public.record_ai_album_draft_success(text,integer) from public,anon;
grant execute on function public.record_ai_album_draft_success(text,integer) to authenticated;


-- Recover only titles whose trusted generation result still exists. Older
-- purged results keep the generic UI fallback, and existing titles stay intact.
update public.point_ledger ledger
set metadata=ledger.metadata || jsonb_build_object(
  'title', btrim(intent.result->>'title',E' \t\r\n'))
from private.ai_template_generation_intents intent
where ledger.reason in('AI_ALBUM_DRAFT_FREE','AI_ALBUM_DRAFT_CHARGE')
  and ledger.related_entity_type='ai_album_draft'
  and ledger.user_id=intent.user_id
  and ledger.related_entity_id=intent.draft_id
  and jsonb_typeof(intent.result->'title')='string'
  and nullif(btrim(intent.result->>'title',E' \t\r\n'),'') is not null
  and (not(ledger.metadata ? 'title')
    or jsonb_typeof(ledger.metadata->'title')<>'string'
    or nullif(btrim(ledger.metadata->>'title',E' \t\r\n'),'') is null);

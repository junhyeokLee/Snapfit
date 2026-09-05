-- Admin-only operational metrics for hybrid AI albums and native IAP rollout.
-- Views are revoked from client roles; admins should use the guarded RPC below
-- or inspect the views through service-role/admin SQL tooling.

create or replace view public.ai_album_daily_metrics as
select
  date_trunc('day', e.created_at)::date as metric_date,
  count(*) filter (where e.event_type = 'AI_DRAFT_PROVIDER_RESULT') as ai_draft_result_count,
  count(*) filter (where e.event_type = 'AI_DRAFT_PROVIDER_ERROR') as ai_draft_error_count,
  count(*) filter (
    where e.event_type = 'AI_DRAFT_PROVIDER_RESULT'
      and coalesce((e.metadata->>'fallbackUsed')::boolean, false)
  ) as fallback_count,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED') as point_purchase_verified_count,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_DUPLICATE') as point_purchase_duplicate_count,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_FAILED') as point_purchase_failed_count,
  coalesce(sum(e.point_delta) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED'), 0)::integer as purchased_points,
  coalesce(sum(pp.amount) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED'), 0)::integer as estimated_revenue_krw
from public.ai_album_operational_events e
left join public.point_products pp on pp.product_id = e.product_id
group by 1;

create or replace view public.ai_album_product_metrics as
select
  e.product_id,
  pp.title,
  pp.points,
  pp.amount as amount_krw,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED') as verified_count,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_DUPLICATE') as duplicate_count,
  count(*) filter (where e.event_type = 'POINT_PURCHASE_FAILED') as failed_count,
  coalesce(sum(pp.amount) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED'), 0)::integer as estimated_revenue_krw,
  coalesce(sum(e.point_delta) filter (where e.event_type = 'POINT_PURCHASE_VERIFIED'), 0)::integer as granted_points
from public.ai_album_operational_events e
left join public.point_products pp on pp.product_id = e.product_id
where e.product_id is not null
group by e.product_id, pp.title, pp.points, pp.amount;

revoke all on public.ai_album_daily_metrics from public;
revoke all on public.ai_album_daily_metrics from anon;
revoke all on public.ai_album_daily_metrics from authenticated;
revoke all on public.ai_album_product_metrics from public;
revoke all on public.ai_album_product_metrics from anon;
revoke all on public.ai_album_product_metrics from authenticated;

create or replace function public.get_ai_album_operations_summary(p_days integer default 7)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 7), 90)));
  v_summary jsonb;
begin
  if not public.is_admin() then
    raise exception 'admin privileges required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'windowDays', greatest(1, least(coalesce(p_days, 7), 90)),
    'aiDrafts', jsonb_build_object(
      'results', count(*) filter (where event_type = 'AI_DRAFT_PROVIDER_RESULT'),
      'errors', count(*) filter (where event_type = 'AI_DRAFT_PROVIDER_ERROR'),
      'fallbacks', count(*) filter (
        where event_type = 'AI_DRAFT_PROVIDER_RESULT'
          and coalesce((metadata->>'fallbackUsed')::boolean, false)
      ),
      'hybridResults', count(*) filter (where event_type = 'AI_DRAFT_PROVIDER_RESULT' and provider = 'hybrid'),
      'metadataResults', count(*) filter (where event_type = 'AI_DRAFT_PROVIDER_RESULT' and provider = 'metadata')
    ),
    'billing', jsonb_build_object(
      'pointPurchaseVerified', count(*) filter (where event_type = 'POINT_PURCHASE_VERIFIED'),
      'pointPurchaseDuplicate', count(*) filter (where event_type = 'POINT_PURCHASE_DUPLICATE'),
      'pointPurchaseFailed', count(*) filter (where event_type = 'POINT_PURCHASE_FAILED'),
      'subscriptionVerified', count(*) filter (where event_type = 'SUBSCRIPTION_VERIFIED'),
      'subscriptionFailed', count(*) filter (where event_type = 'SUBSCRIPTION_FAILED'),
      'grantedPoints', coalesce(sum(point_delta) filter (where event_type = 'POINT_PURCHASE_VERIFIED'), 0)
    )
  ) into v_summary
  from public.ai_album_operational_events
  where created_at >= v_since;

  return v_summary || jsonb_build_object(
    'dailyMetrics', coalesce((
      select jsonb_agg(to_jsonb(d) order by d.metric_date desc)
      from public.ai_album_daily_metrics d
      where d.metric_date >= v_since::date
    ), '[]'::jsonb),
    'productMetrics', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.estimated_revenue_krw desc, p.product_id)
      from public.ai_album_product_metrics p
    ), '[]'::jsonb),
    'recent_events', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.created_at desc)
      from (
        select
          created_at,
          event_type,
          provider,
          platform,
          product_id,
          transaction_id,
          point_delta,
          metadata
        from public.ai_album_operational_events
        where created_at >= v_since
        order by created_at desc
        limit 20
      ) r
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_ai_album_operations_summary(integer) from public;
grant execute on function public.get_ai_album_operations_summary(integer) to authenticated;

# AI Album Admin SQL Runbook

No secret values belong in this runbook. Use placeholders such as `USER_UUID_HERE`; never paste service-role keys, access tokens, API keys, receipts, purchase tokens, or private keys into SQL snippets that may be copied to chat or Git.

Run these from Supabase SQL Editor or another admin-authenticated SQL console. All support RPCs guard with `public.is_admin()`.

## 1. Seven-day operations summary

```sql
select public.get_ai_album_operations_summary(7);
```

Use this first during rollout. It returns AI draft success/error/fallback counts, point purchase success/duplicate/failure counts, product metrics, daily metrics, and recent events.

## 2. Daily AI and billing metrics

```sql
select *
from public.ai_album_daily_metrics
order by metric_date desc
limit 30;
```

Watch:

- `ai_draft_result_count`
- `ai_draft_error_count`
- `fallback_count`
- `point_purchase_verified_count`
- `point_purchase_duplicate_count`
- `estimated_revenue_krw`

## 3. Product revenue and point metrics

```sql
select *
from public.ai_album_product_metrics
order by estimated_revenue_krw desc, product_id;
```

Use this to see which package converts best:

- `snapfit_points_2500`
- `snapfit_points_8000`
- `snapfit_points_18000`

## 4. User point ledger for CS

```sql
select *
from public.admin_get_user_point_ledger('USER_UUID_HERE', 50);
```

Use when a user says:

- 결제했는데 포인트가 안 들어왔어요.
- AI 생성 실패했는데 포인트가 차감됐나요?
- 포인트가 갑자기 줄었어요.

Check `reason`:

- `POINT_PURCHASE`: verified store purchase grant.
- `AI_ALBUM_DRAFT_FREE`: first free AI draft.
- `AI_ALBUM_DRAFT_CHARGE`: paid AI draft charge.
- `ADMIN_ADJUSTMENT`: manual support correction.

## 5. Manual point grant for QA or CS

```sql
select *
from public.admin_adjust_user_points(
  'USER_UUID_HERE',
  2500,
  'sandbox QA test points',
  'qa-test-USER_UUID_HERE-YYYYMMDD',
  '{"source":"qa"}'::jsonb
);
```

Use a stable `p_idempotency_key` for repeatable support actions so accidental re-run does not double-apply.

## 6. Manual point recovery/correction

```sql
select *
from public.admin_adjust_user_points(
  'USER_UUID_HERE',
  -700,
  'manual correction after support review',
  'cs-correction-USER_UUID_HERE-YYYYMMDD-001',
  '{"source":"cs"}'::jsonb
);
```

The wallet cannot go below zero.

## 7. Purchase troubleshooting

```sql
select
  created_at,
  event_type,
  platform,
  product_id,
  transaction_id,
  point_delta,
  metadata
from public.ai_album_operational_events
where transaction_id = 'STORE_TRANSACTION_ID_HERE'
order by created_at desc;
```

Then compare with ledger:

```sql
select *
from public.admin_get_user_point_ledger('USER_UUID_HERE', 100)
where related_entity_id = 'STORE_TRANSACTION_ID_HERE'
   or idempotency_key like '%STORE_TRANSACTION_ID_HERE%';
```

Expected duplicate behavior:

- First verified delivery: `POINT_PURCHASE_VERIFIED`, positive `point_delta`.
- Replayed delivery: `POINT_PURCHASE_DUPLICATE`, `point_delta = 0`.

## 8. Hybrid AI fallback troubleshooting

```sql
select
  created_at,
  provider,
  request_id,
  metadata->>'fallbackUsed' as fallback_used,
  metadata->>'fallbackReason' as fallback_reason,
  metadata->>'candidateCount' as candidate_count,
  metadata->>'recommendedCount' as recommended_count
from public.ai_album_operational_events
where event_type = 'AI_DRAFT_PROVIDER_RESULT'
order by created_at desc
limit 50;
```

If fallbacks spike, use metadata rollback until provider keys/billing/model status are fixed.

## 9. Emergency metadata rollback

Run from VPS/container terminal, not SQL, and do not print secret values:

```bash
cd /srv/projects/Snapfit
export SUPABASE_ACCESS_TOKEN=$(cat /opt/data/.supabase/access-token 2>/dev/null || cat /opt/data/home/.supabase/access-token)
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   AI_ALBUM_DRAFT_PROVIDER="metadata"
```

Hybrid re-enable after QA:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   AI_ALBUM_DRAFT_PROVIDER="hybrid"
```

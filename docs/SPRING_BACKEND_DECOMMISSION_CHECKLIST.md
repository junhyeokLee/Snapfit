# Spring Backend Decommission Checklist

This checklist tracks the remaining non-code gates before the legacy Spring Boot backend can be archived.

## Current status

The Flutter runtime Spring REST fallback paths have been removed. The app no longer has active `/api/auth`, `/api/billing`, `/api/notifications`, `/api/support`, `/api/orders`, or `/api/admin` calls, and the old `Env.baseUrl`/Dio provider stack has been deleted.

Current runtime paths:

- Auth/profile/consent/account deletion: Supabase Auth + `profiles` + `account-delete` Edge Function.
- Templates/design catalog: Supabase `templates` / `template_likes`.
- Albums/members/invites: Supabase DB + Supabase Storage + `album-invites` Edge Function.
- Notifications/support: Supabase tables.
- Point purchases: native Apple/Google consumable IAP + `iap-verify`, with scheduled `iap-reconcile` refund handling. No subscription is sold.
- Legacy external subscription billing: disabled; `billing-prepare`, `billing-approve`, and `billing-webhook` return HTTP 410.
- Admin operations: `admin-ops` Edge Function.
- Existing orders/print package: history and authorized admin operations remain available. External checkout/confirmation are retired with no replacement provider.

Remaining non-Spring compatibility code:

- `DioException` handling remains in UI/error utilities because some third-party/network layers still surface Dio-style errors.
- Firebase remains for FCM and for reading old `gs://` image URLs during data migration. New album uploads use Supabase Storage only.
- Generated/freezed comments and package paths containing `data/api` are not REST backend calls.

## Blockers before archiving Spring

1. Kakao Supabase provider configuration must be verified on real devices.
2. Google Play / App Store receipt verification code is implemented in `iap-verify`, but real provider credentials must be set as Supabase secrets and sandbox purchases must be smoke-tested.
3. Print vendor production contract must be confirmed:
   - Current Supabase package creates JSON/ZIP/summary PDF and includes source images where reachable.
   - If the vendor requires press-ready flattened PDFs, add a renderer pipeline for album layer JSON.
4. Address search requires `SNAPFIT_ADDRESS_JUSO_KEY` to be set as a Supabase secret.
5. Admin screens require `SNAPFIT_ADMIN_KEY` or an admin JWT role.
6. Run production smoke tests for auth, album save/upload, address search, point IAP, retained order history, admin, notifications, and support.

## Safe shutdown sequence

1. Keep Spring backend running while Supabase flows are tested with production data.
2. Configure Google Play/App Store verification credentials; mock verification has been removed.
3. Run `python3 tool/supabase_readiness_check.py` and ensure it passes.
4. Run physical-device smoke tests from `docs/PRODUCTION_SMOKE_TEST_CHECKLIST.md`.
5. Monitor production logs/network traffic and confirm no `/api/*` traffic reaches Spring for one full release cycle.
6. Archive Spring only after the release cycle is clean.

## Supabase configuration reference

Current remote secret presence and deployment outcomes are recorded in [deployment status](PAYMENT_PUSH_DEPLOYMENT_STATUS.md). Do not infer current configuration from the original migration audit. The current payment key list is in [point payment keys](ORDER_PAYMENT_KEYS.md); push/worker settings are in [release instructions](POINT_PAYMENTS_AND_PUSH_RELEASE.md). There is no external checkout key setup or optional activation path.

## Automated readiness check

Run this before each production smoke-test pass:

```bash
cd /srv/projects/Snapfit
python3 tool/supabase_readiness_check.py
```

The script verifies that legacy Spring backend patterns are absent, required Supabase secret names are present, and deployed Edge Functions respond to `OPTIONS`. It intentionally reports only secret names, never secret values.

For code-only verification when production secrets are not configured yet:

```bash
python3 tool/supabase_readiness_check.py --skip-remote
```

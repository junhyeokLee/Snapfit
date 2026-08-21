# Spring Backend Decommission Checklist

This checklist tracks the remaining non-code gates before the legacy Spring Boot backend can be archived.

## Current status

The Flutter runtime Spring REST fallback paths have been removed. The app no longer has active `/api/auth`, `/api/billing`, `/api/notifications`, `/api/support`, `/api/orders`, or `/api/admin` calls, and the old `Env.baseUrl`/Dio provider stack has been deleted.

Current runtime paths:

- Auth/profile/consent/account deletion: Supabase Auth + `profiles` + `account-delete` Edge Function.
- Templates/design catalog: Supabase `templates` / `template_likes`.
- Albums/members/invites: Supabase DB + Supabase Storage + `album-invites` Edge Function.
- Notifications/support: Supabase tables.
- Billing entitlement: native store IAP flow + `iap-verify` Edge Function.
- Legacy external subscription billing: disabled; `billing-prepare`, `billing-approve`, and `billing-webhook` return `410 native_iap_required`.
- Admin operations: `admin-ops` Edge Function.
- Orders/print package: `order-confirm-payment` / `admin-ops.preparePrintPackage` generate private Supabase Storage artifacts.

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
5. Physical order checkout requires `SNAPFIT_ORDER_CHECKOUT_BASE_URL` to be set as a Supabase secret.
6. Admin screens require `SNAPFIT_ADMIN_KEY` or an admin JWT role.
7. Run production smoke tests for auth, album save/upload, checkout/address search, IAP, admin, notifications, and support.

## Safe shutdown sequence

1. Keep Spring backend running while Supabase flows are tested with production data.
2. Keep `SNAPFIT_IAP_MOCK_VERIFY` unset/false and configure real Google Play/App Store secrets.
3. Run `python3 tool/supabase_readiness_check.py` and ensure it passes.
4. Run physical-device smoke tests from `docs/PRODUCTION_SMOKE_TEST_CHECKLIST.md`.
5. Monitor production logs/network traffic and confirm no `/api/*` traffic reaches Spring for one full release cycle.
6. Archive Spring only after the release cycle is clean.

## Current Supabase secret audit

Current audit shows only Supabase built-in secrets are present. These production secrets still need to be set directly in Supabase before the final smoke-test pass:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` or `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` + `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`
- `APP_STORE_ISSUER_ID`
- `APP_STORE_KEY_ID`
- `APP_STORE_BUNDLE_ID`
- `APP_STORE_PRIVATE_KEY`
- `APP_STORE_ENVIRONMENT`
- `SNAPFIT_ADDRESS_JUSO_KEY`
- `SNAPFIT_ORDER_CHECKOUT_BASE_URL`
- `SNAPFIT_ADMIN_KEY`

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

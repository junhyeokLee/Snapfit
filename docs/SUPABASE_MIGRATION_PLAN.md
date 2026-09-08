# SnapFit Supabase Migration Plan

## Current status

SnapFit's Flutter runtime has been cut over from the legacy Spring REST backend to Supabase/Supabase Edge Functions.

Code-only readiness is enforced locally and in CI:

```bash
python3 tool/supabase_readiness_check.py --skip-remote
```

Full production readiness additionally requires Supabase production secrets and real-device smoke tests:

```bash
python3 tool/supabase_readiness_check.py
```

## Current runtime mapping

| Area | Current implementation |
| --- | --- |
| Auth/profile/session | Supabase Auth + `profiles` |
| Account deletion | `account-delete` Edge Function |
| Templates | Supabase `templates` / `template_likes` |
| Albums/pages | Supabase `albums` / `album_pages` |
| Album members/invites | Supabase `album_members` / `album_invites` + `album-invites` Edge Function |
| New album asset uploads | Supabase Storage `album-assets` |
| Avatar uploads | Supabase Storage `avatars` |
| Notifications | Supabase `notification_inbox` / `notification_reads` |
| Support inquiries | Supabase `support_inquiries` |
| Consumable point purchases | Native Apple/Google IAP + `iap-verify`; `iap-reconcile` refunds |
| Legacy external subscription billing | Disabled; `billing-prepare`, `billing-approve`, `billing-webhook` return HTTP 410 |
| Storage quota | Supabase `storage_quotas` |
| Address search | `address-search` Edge Function |
| External physical order checkout | Retired; no replacement integration |
| Existing orders/print package | Historical data and authorized admin operations; private `print-packages` bucket |
| Admin operations | `admin-ops` Edge Function |
| Template publishing tool | `tool/publish_store_templates_to_server.dart` calls `admin-ops`, not Spring REST |

## Removed legacy runtime dependencies

- Old Spring Retrofit API clients and generated files for auth/albums/members/templates.
- Old Spring repository implementations and old tests.
- `Env.baseUrl` and `BASE_URL` runtime dependency.
- `dio_provider`, `DioClient`, old `AuthInterceptor`, and `legacy_backend_guard`.
- `ENABLE_LEGACY_BACKEND_FALLBACK` rollback flag.
- Remaining `/api/*` fallback calls in billing, notifications, support, orders, and admin operations.
- Toss/NaverPay-style subscription billing methods and DTOs from the Flutter app.

## Deliberate compatibility code

- Firebase remains for FCM and for reading old `gs://` image URLs during data migration. New album uploads use Supabase Storage only.
- `DioException` handling remains in UI/error mapping where third-party/network errors can still surface as Dio-style exceptions.
- `data/api` package path names are legacy folder names, not active REST calls.

## Required Supabase secrets before production smoke tests

Android IAP:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` **or** `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` + `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`

Apple IAP:

- `APP_STORE_ISSUER_ID`
- `APP_STORE_KEY_ID`
- `APP_STORE_BUNDLE_ID`
- `APP_STORE_PRIVATE_KEY`
- `APP_STORE_ENVIRONMENT`

Workers:

- `SNAPFIT_IAP_RECONCILE_SECRET`
- `PUSH_DISPATCH_SECRET`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `PUSH_DELIVERY_ENABLED`

Operations:

- `SNAPFIT_ADDRESS_JUSO_KEY`
- `SNAPFIT_ADMIN_KEY`

Do not paste secret values into chat or commit them to the repository. Set them directly through the Supabase CLI or Dashboard.

## Current execution priority

App Store verification credentials and sandbox product setup can be prepared before the iOS release. Android Play products, service-account API permissions and license testing must likewise be checked before Android sales. See [Android preparation](ANDROID_POINT_PURCHASE_CHECKLIST.md). External physical-order checkout is retired; it is not a deferred provider-selection task.

The core profile checks Android IAP and operations only:

```bash
python3 tool/supabase_readiness_check.py --profile supabase-core
```

The full profile includes both stores, refund workers and push. Passing configuration checks still requires real-device validation:

```bash
python3 tool/supabase_readiness_check.py --profile production
```

Preserve already applied migrations. Use the follow-up external-payment retirement migration instead of rewriting the original payment migration; actual application status is in [deployment status](PAYMENT_PUSH_DEPLOYMENT_STATUS.md).

## Final production gate

1. Set the required Supabase secrets.
2. Run `python3 tool/supabase_readiness_check.py` and make it pass.
3. Run the real-device checklist in `docs/PRODUCTION_SMOKE_TEST_CHECKLIST.md`.
4. Monitor logs and confirm no legacy `/api/*` traffic reaches Spring for one full release cycle.
5. Archive the Spring backend only after the release cycle is clean.

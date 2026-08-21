# Spring Backend Decommission Checklist

This checklist tracks the remaining risk before the legacy Spring Boot backend can be turned off.

## Current status

Most user-facing SnapFit flows now prefer Supabase directly or Supabase Edge Functions:

- Auth/profile/consent/account deletion: Supabase Auth + `profiles` + `account-delete` Edge Function.
- Templates/design catalog: Supabase `templates` / `template_likes`.
- Albums/members/invites: Supabase DB + Storage + `album-invites` Edge Function.
- Notifications/support: Supabase tables.
- Billing entitlement: native store IAP flow + `iap-verify` Edge Function. Legacy external subscription billing functions now return `410 native_iap_required`.
- Admin operations: `admin-ops` Edge Function.
- Orders/print package: `order-confirm-payment` / `admin-ops.preparePrintPackage` generate private Supabase Storage artifacts.

## Remaining legacy REST code

The Flutter runtime Spring REST fallback paths have been removed. The current app code no longer has active `/api/auth`, `/api/billing`, `/api/notifications`, `/api/support`, `/api/orders`, or `/api/admin` calls, and the old `Env.baseUrl`/Dio provider stack has been deleted.

Remaining non-Spring compatibility code:

- `DioException` handling remains in UI/error utilities because some third-party/network layers still surface Dio-style errors.
- Firebase services remain for FCM and for reading old `gs://` image URLs during data migration.
- Generated/freezed comments and package paths containing `data/api` are not REST backend calls.

## Blockers before disabling Spring

1. Kakao Supabase provider configuration must be verified on real devices.
2. Google Play / App Store receipt verification code is now implemented in `iap-verify`, but real provider credentials must be set as Supabase secrets and sandbox purchases must be smoke-tested.
3. Print vendor production contract must be confirmed:
   - Current Supabase package creates JSON/ZIP/summary PDF and includes source images where reachable.
   - If the vendor requires press-ready flattened PDFs, add a renderer pipeline for album layer JSON.
4. Address search has been moved to the `address-search` Supabase Edge Function. Production requires `SNAPFIT_ADDRESS_JUSO_KEY` to be set as a Supabase secret.
5. Run production smoke tests for auth, album save/upload, order payment confirmation, admin print package generation, notification reads, and support inquiry submission.

## Safe shutdown sequence

1. Keep Spring backend running while Supabase flows are tested with production data.
2. Keep `SNAPFIT_IAP_MOCK_VERIFY` unset/false and configure real Google Play/App Store secrets. The legacy `billing-prepare`, `billing-approve`, and `billing-webhook` functions are disabled and return `410 native_iap_required`.
3. Run physical-device smoke tests for auth, album save/upload, checkout/address search, IAP, admin, notifications, and support.
4. Monitor production logs/network traffic and confirm no `/api/*` traffic reaches Spring for a full release cycle.
5. Archive the Spring backend after the release cycle is clean.


## Address search cutover

`OrderRepository.searchAddress` now calls the Supabase `address-search` Edge Function when Supabase is available. The function mirrors the old Spring `AddressSearchService` response shape and calls Korea Juso (`business.juso.go.kr`) using server-side Supabase secrets.

Required Supabase secret before production checkout testing:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set SNAPFIT_ADDRESS_JUSO_KEY='***'
```

Optional tuning secrets:

- `SNAPFIT_ADDRESS_JUSO_ENABLED=false`
- `SNAPFIT_ADDRESS_JUSO_COUNT_PER_PAGE=10`
- `SNAPFIT_ADDRESS_JUSO_TIMEOUT_MS=4000`
- `SNAPFIT_ADDRESS_JUSO_BASE_URL=https://business.juso.go.kr/addrlink/addrLinkApi.do`


## Physical order checkout cutover

`OrderRepository.buildOrderCheckoutUrl` now calls the Supabase `order-checkout` Edge Function when Supabase is available. The legacy `/api/orders/{id}/payment/checkout` URL is retained only as a no-Supabase fallback.

Production external payment opening requires a server-side checkout provider URL to be configured:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set SNAPFIT_ORDER_CHECKOUT_BASE_URL='https://your-checkout-provider.example/checkout'
```

Until that secret/provider is configured, the function returns `order_checkout_provider_not_configured` instead of silently falling back to Spring or marking an order as paid. This is intentional: paid physical orders must not be auto-confirmed without a real payment provider callback.


## Runtime provider cleanup

The main Riverpod runtime providers no longer expose the old Retrofit `AlbumApi`, `AlbumMemberApi`, or `TemplateApi` providers. Those legacy API classes remain in the tree for fallback repositories/tests during the migration window, but the active app provider graph routes albums, members, and templates through Supabase repositories.


## Legacy Spring fallback disabled by default

`Env.enableLegacyBackendFallback` now defaults to `false`. All remaining direct Spring/Dio fallback paths are guarded with `assertLegacyBackendFallbackAllowed`, so production builds fail fast instead of silently calling `/api/*` on the old Spring backend.

Temporary rollback testing can opt in explicitly:

```bash
flutter run --dart-define=ENABLE_LEGACY_BACKEND_FALLBACK=true
```

This flag should remain `false` for production Supabase-only releases.


## Legacy Retrofit files removed

The old Spring Retrofit clients for auth/albums/album members/templates and their old repository implementations have been deleted from the app codebase. Runtime auth/profile, album, member, and template flows no longer depend on Spring REST API client classes.


## IAP verification production secrets

`iap-verify` now supports real provider verification and fails closed when credentials are absent.

Required Android secrets:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   GOOGLE_PLAY_PACKAGE_NAME='com.yourcompany.snapfit'   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='<service-account-json>'
```

Required iOS secrets:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   APP_STORE_ISSUER_ID='<issuer-id>'   APP_STORE_KEY_ID='<key-id>'   APP_STORE_BUNDLE_ID='<bundle-id>'   APP_STORE_PRIVATE_KEY='<p8-private-key>'   APP_STORE_ENVIRONMENT='sandbox'
```

Switch `APP_STORE_ENVIRONMENT` to `production` only after sandbox purchase verification passes.


## Current Supabase secret audit

Current audit shows only Supabase built-in secrets are present. The following production secrets still need to be set directly in Supabase before the final smoke-test pass:

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

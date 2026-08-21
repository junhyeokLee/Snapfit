# SnapFit Supabase migration plan

## Project

- Supabase project ref: `rrbhxdtriummqpztpjrk`
- Supabase URL: `https://rrbhxdtriummqpztpjrk.supabase.co`
- Migration applied: `supabase/migrations/20260820140500_initial_snapfit_schema.sql`

## What is done in phase 1

1. Added Supabase Flutter configuration points in `lib/config/env.dart`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
2. Initialized Supabase in `lib/main.dart` next to Firebase initialization.
3. Added `supabase_flutter` to `pubspec.yaml`.
4. Added a Riverpod provider in `lib/core/supabase/supabase_provider.dart`.
5. Created and applied the first remote Supabase migration with:
   - `profiles`
   - `templates`, `template_likes`
   - `albums`, `album_pages`, `album_members`, `album_invites`
   - `billing_plans`, `subscriptions`, `storage_quotas`
   - `orders`
   - `notifications`
   - `support_inquiries`
   - Storage buckets: `avatars`, `album-assets`, `template-assets`
   - RLS policies for user-owned data and admin-only operations.

## Current REST API inventory

See `docs/SUPABASE_MIGRATION_API_INVENTORY.md`.

High-impact existing API areas:

- Auth: `/api/auth/login/kakao`, `/api/auth/login/google`, `/api/auth/refresh`, `/api/auth/profile`
- Albums: `/api/albums`, locks, invites, members
- Store templates: `/api/templates`, likes, template-to-album creation
- Billing/orders: `/api/billing/*`, `/api/orders/*`
- Notifications/support/admin operations

## Important migration notes

The existing app stores `UserInfo.id` as an `int`, but Supabase Auth user IDs are `uuid` strings. The auth migration must change the app's user-id model before replacing API calls fully.

Billing/payment/order checkout operations should not be implemented directly from the Flutter client with the anon key. They need Supabase Edge Functions or another trusted server path because provider secrets and service-role privileges are required.

Admin operations should also go through Edge Functions or an admin-only app session with custom claims (`app_metadata.role = admin`).

## Recommended next phases

### Phase 2: Auth

- Add Supabase Auth social providers for Google/Kakao in the Supabase dashboard.
- Change `UserInfo.id` from `int` to `String` or add a separate `supabaseUserId`.
- Replace custom `/api/auth/*` calls with `Supabase.instance.client.auth`.
- Store profile rows in `public.profiles`.

### Phase 3: Templates and albums

- Replace template list/detail/like calls with Supabase queries.
- Replace album CRUD with `albums` and `album_pages` queries.
- Move image uploads to Supabase Storage buckets.

### Phase 4: Edge Functions

- Implement payment prepare/approve/cancel.
- Implement order checkout redirect generation.
- Implement admin order/template operations.
- Implement server-side notification inserts.

### Phase 5: Cleanup

- Remove old REST API DTOs/interceptors where unused.
- Remove default `BASE_URL` dependency once no `/api/*` calls remain.
- Run Flutter code generation and app tests locally.

## Phase 2 progress update

Applied `supabase/migrations/20260820152000_backend_gap_alignment.sql` to the remote Supabase project.

Added backend-parity schema elements after inspecting `Snapfit-BackEnd`:

- `billing_orders`
- `templates.new_until`
- `album_pages.page_number`, `image_url`, `original_url`, `preview_url`
- `album_members.status`, `invited_by`, `invite_token`
- `subscriptions.last_order_id`
- `support_inquiries.category`, `resolved_at`, `resolved_by`
- `notification_inbox`, `notification_reads`
- indexes for order/support/billing queries

Created and deployed Supabase Edge Function scaffolds:

- `billing-prepare` — functional mock-mode subscription prepare path using `billing_orders` and `orders`.
- `billing-approve` — functional mock-mode approval path that updates `billing_orders`, `subscriptions`, and `orders`.
- `admin-ops` — authenticated admin skeleton.
- `billing-webhook` — deployed placeholder; provider signature verification still needs porting from Spring.
- `order-confirm-payment` — deployed placeholder; print package/PDF/ZIP/vendor logic still needs porting from Spring `OrderService`.

Flutter wiring started:

- `UserInfo.id` moved from `int` to `String` for Supabase UUID compatibility.
- Store template repository now uses Supabase queries for template list/detail/like/create-from-template.
- Album repository now uses Supabase queries for album CRUD/reorder/lock/unlock.
- Billing repository now reads plans/subscription/quota from Supabase and calls `billing-prepare` / `billing-approve` functions.

Remaining before removing the old backend completely:

1. Configure Supabase Auth providers for Google and Kakao in the Dashboard.
2. Replace custom `/api/auth/*` login/profile endpoints with Supabase Auth + `profiles` upsert.
3. Port order print package generation and payment provider integrations into Edge Functions.
4. Port admin template/order/support operations into Edge Functions or Supabase admin UI.
5. Run `flutter pub get`, `dart run build_runner build`, and `flutter analyze` on a Flutter-capable machine.

## Payment direction change: native in-app purchases

Decision: mobile subscriptions should use native store billing, not Toss/NaverPay external checkout.

- Android: Google Play Billing through Flutter `in_app_purchase`.
- iOS: App Store / StoreKit through Flutter `in_app_purchase`.
- Server side: Supabase Edge Function `iap-verify` verifies purchase tokens/receipts and materializes `subscriptions`.
- Legacy `billing-prepare` / `billing-approve` functions remain only as temporary mock-mode/admin testing scaffolds and should not be used for production mobile checkout.

Added:

- `in_app_purchase` dependency in `pubspec.yaml`.
- `store_purchases` table in `20260820161000_store_iap_entitlements.sql`.
- `iap-verify` Edge Function scaffold.

Still required for production:

1. Google Play Developer API service account credentials in Supabase Function secrets.
2. App Store Server API issuer/key credentials in Supabase Function secrets.
3. Replace mock verification in `iap-verify` with real Google/Apple receipt validation.
4. Build Flutter purchase UI/flow around `in_app_purchase` and call `iap-verify` after purchase updates.

## Phase 3 progress update

Additional migration work:

- Added and deployed `album-invites` Edge Function for invite creation, invite info, and invite acceptance.
- Wired album member/invite repository to Supabase Edge Functions and `album_members` queries.
- Wired Google login token exchange to Supabase Auth (`signInWithIdToken`) and profile upsert. Kakao still requires Supabase Dashboard/provider flow finalization.
- Wired order history/page/summary/create/quote and payment-confirm/shipping/delivered/print-package actions to Supabase tables / `order-confirm-payment` Edge Function.
- Replaced Firebase-first album asset upload path with Supabase Storage `album-assets` when a Supabase client is available, keeping Firebase as fallback.
- Replaced storage quota preflight and subscription cancel fallback paths with Supabase DB logic.

Remaining high-risk items:

1. Kakao Supabase Auth provider configuration and login flow finalization.
2. Production-grade Google Play/App Store receipt verification in `iap-verify`.
3. Real print package/PDF/ZIP/vendor submission inside `order-confirm-payment` instead of current state-transition scaffold.
4. Admin screens still need full `admin-ops` action routing.
5. Flutter-capable validation is required: `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`.

## Phase 4 progress update

Admin migration work:

- Expanded `admin-ops` Edge Function into action-based admin API:
  - dashboard metrics
  - CS/support signals
  - paged order listing
  - shipping/delivered/print-package state transitions
  - template paging/detail/upsert/active toggle
- Wired `AdminOpsRepository` to call Supabase `admin-ops` when Supabase is available.
- `admin-ops` accepts either a JWT user with `app_metadata.role = admin` or the existing `ORDER_ADMIN_KEY`/`SNAPFIT_ADMIN_KEY` as an Edge Function secret.

Operational note: for admin-key based screens to work against Supabase Edge Functions, set the same admin key as a Supabase secret:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set SNAPFIT_ADMIN_KEY='...'
```

Do not paste this secret in chat; set it directly in the container/root shell.


## Phase 5 progress update

Auth/profile migration work:

- Kakao login now attempts Supabase Auth via `signInWithIdToken(provider: OAuthProvider.kakao)` when the Kakao SDK supplies an ID token, with the legacy `/api/auth/login/kakao` path retained as a fallback.
- Supabase session refresh is used before the legacy `/api/auth/refresh` fallback.
- Consent sync now writes directly to `public.profiles` (`terms_version`, `privacy_version`, `marketing_opt_in`, `consented_at`) before trying the legacy `/api/auth/consents` endpoint.
- Added and deployed `account-delete` Edge Function so account deletion can use the authenticated Supabase JWT and service-role server-side user deletion instead of exposing privileged keys to the app.

Still required:

1. Confirm Kakao OpenID Connect / ID token issuance in Kakao developer settings and Supabase Auth provider configuration.
2. Once Kakao/Google auth is verified on-device, remove or hard-disable the legacy auth REST fallback paths.
3. Continue with production IAP receipt verification and order print/PDF package generation.


## Phase 6 progress update

Native store billing / IAP wiring:

- Added `IAP_PRO_MONTHLY_PRODUCT_ID` app config with default `snapfit_pro_monthly`.
- Added a Flutter `BillingManagementScreen` connected from My Page → 구독 및 결제 관리.
- The screen queries Google Play/App Store product details through `in_app_purchase`, starts the native subscription purchase, listens for purchase updates, restores purchases, and calls the Supabase `iap-verify` function for server-side entitlement materialization.
- `BillingRepository.verifyStorePurchase` maps `PurchaseDetails` into the `iap-verify` request and refreshes subscription/quota providers after verification.
- Updated and redeployed `iap-verify` to accept app-provided `planCode` and map known product IDs to `SNAPFIT_PRO_MONTHLY`.

Important production blocker:

- `iap-verify` still intentionally returns `iap_provider_verification_not_configured` unless real Google Play Developer API / App Store Server API secrets and verification logic are configured. This prevents granting paid entitlements from unverified receipts in production.


## Phase 7 progress update

Order / PDF / Print package migration work:

- Ported the Spring `OrderService` print-package flow into Supabase Edge Functions.
- Added a private `print-packages` Supabase Storage bucket via migration.
- Added shared Edge Function helper `_shared/print-package.ts` that builds:
  - `print-package.json` containing order, album, recipient, and asset metadata.
  - `print-package.zip` containing the JSON, an asset manifest, and downloadable album images where URLs are reachable.
  - `print-package.pdf` summary document for print/package inspection.
- Updated `order-confirm-payment` so payment confirmation generates print artifacts and advances the order to `IN_PRODUCTION`.
- Updated `admin-ops.preparePrintPackage` so admins can regenerate the package and refresh order metadata.
- Uploaded artifacts are stored in private Supabase Storage and order rows receive signed URLs in:
  - `print_package_json_url`
  - `print_file_zip_url`
  - `print_file_pdf_url`
  - `print_asset_count`
  - `print_package_generated_at`
  - `print_vendor`
  - `print_vendor_order_id`
  - `print_submitted_at`

Remaining production gap:

- The generated PDF is currently an inspection/summary PDF. The ZIP contains the print manifest and source images. If the print vendor requires a press-ready flattened PDF per page, add a dedicated renderer pipeline that flattens Flutter album layer JSON into print-resolution page images/PDFs before vendor submission.
- Real vendor API submission is represented by `SUPABASE_PRINT_PACKAGE` metadata for now. Actual vendor credentials/API contract should be added as Supabase secrets and called from the Edge Function.


## Phase 8 progress update

Final backend dependency scan / decommission preparation:

- Scanned remaining `/api/*`, Retrofit, Dio, Firebase Storage, and hard-coded backend URL references.
- Confirmed most old REST classes are now fallback or test-era implementations rather than the primary provider path.
- Routed debug/admin order controls in `order_history_screen.dart` and `admin_order_management_screen.dart` through `admin-ops` instead of `order-confirm-payment`, so `SNAPFIT_ADMIN_KEY`/`ORDER_ADMIN_KEY` header-based admin auth works consistently.
- Added `docs/SPRING_BACKEND_DECOMMISSION_CHECKLIST.md` documenting remaining blockers before the Spring backend can be shut down.

Remaining active blocker identified in scan:

- Address search still uses legacy `/api/orders/address/search`. Replace it with a public address lookup API or a Supabase Edge Function before turning off Spring if checkout address search is required.


## Phase 9 progress update

Address search migration:

- Added and deployed the `address-search` Supabase Edge Function.
- Ported the Spring `AddressSearchService` Juso API integration shape to Deno Edge Functions.
- Updated `OrderRepository.searchAddress` to prefer `supabase.functions.invoke('address-search')` and retain the old REST endpoint only as a fallback if Supabase is unavailable.
- The function requires `SNAPFIT_ADDRESS_JUSO_KEY` as a Supabase secret before production checkout address lookup can succeed.


## Phase 10 progress update

Physical order checkout migration:

- Added and deployed the `order-checkout` Supabase Edge Function.
- Updated `OrderRepository.buildOrderCheckoutUrl` to prefer `supabase.functions.invoke('order-checkout')` and keep the Spring checkout URL only as a no-Supabase fallback.
- The function validates the authenticated user owns the order, ensures the order is `PAYMENT_PENDING`, and refuses unsupported providers.
- Production checkout opening now requires `SNAPFIT_ORDER_CHECKOUT_BASE_URL` as a Supabase secret. Without it, the function returns `order_checkout_provider_not_configured` instead of falsely confirming payment.


## Phase 11 progress update

Legacy provider graph cleanup:

- Removed unused runtime Riverpod providers for the old Retrofit `AlbumApi`, `AlbumMemberApi`, and `TemplateApi`.
- The generated Retrofit clients remain only for legacy repository tests/fallback classes during the migration window.
- Active album/member/template provider wiring now stays Supabase-only at the runtime provider graph level.


## Phase 12 progress update

Spring fallback shutdown guard:

- Added `Env.enableLegacyBackendFallback`, defaulting to `false`.
- Added `LegacyBackendDisabledException` and `assertLegacyBackendFallbackAllowed`.
- Guarded remaining Spring/Dio fallback calls across auth, billing, notifications, support, orders, admin ops, and the old Dio auth refresh interceptor.
- Updated tests to assert legacy Spring fallback is blocked by default.

This does not delete every legacy Retrofit class yet, but it prevents production runtime from silently falling back to the Spring backend unless a developer explicitly opts in with `ENABLE_LEGACY_BACKEND_FALLBACK=true`.


## Phase 13 progress update

Legacy Retrofit deletion:

- Removed the old Spring Retrofit API clients for auth, albums, album members, and templates.
- Removed old Spring repository implementations and their unit tests:
  - `AlbumRepositoryImpl`
  - `AlbumMemberRepositoryImpl`
  - `TemplateRepositoryImpl`
- Refactored `AuthService` and `AuthViewModel` so auth/profile image flows no longer depend on `AuthApi` or REST profile fallback.

The remaining Dio fallback code is guarded by `ENABLE_LEGACY_BACKEND_FALLBACK=false` by default while the active runtime path uses Supabase/Edge Functions.


## Phase 14 progress update

Final Spring fallback removal and IAP verification hardening:

- Removed the remaining Flutter runtime Spring/Dio fallback paths for billing, notifications, support inquiries, orders, and admin operations.
- Removed obsolete runtime networking infrastructure tied to the old Spring base URL:
  - `Env.baseUrl`
  - `dio_provider.dart` / generated provider
  - `DioClient`
  - `AuthInterceptor`
  - `legacy_backend_guard`
  - `ENABLE_LEGACY_BACKEND_FALLBACK`
- Verified the app code no longer contains active `/api/auth`, `/api/billing`, `/api/notifications`, `/api/support`, `/api/orders`, or `/api/admin` references.
- Reworked and redeployed `iap-verify` so it no longer only supports local mock entitlement grants:
  - Google Play path uses Android Publisher API `purchases.subscriptionsv2.get` with a service-account JWT.
  - App Store path uses App Store Server API `inApps/v1/transactions/{transactionId}` with ES256 server JWT auth.
  - Mock verification is still available only when `SNAPFIT_IAP_MOCK_VERIFY=true` is explicitly set.
  - Missing provider credentials now fail closed with `*_credentials_not_configured` instead of granting entitlements.

Required Supabase secrets before production IAP smoke testing:

```bash
# Android / Google Play
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   GOOGLE_PLAY_PACKAGE_NAME='com.yourcompany.snapfit'   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='<service-account-json>'

# iOS / App Store Server API
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   APP_STORE_ISSUER_ID='<issuer-id>'   APP_STORE_KEY_ID='<key-id>'   APP_STORE_BUNDLE_ID='<bundle-id>'   APP_STORE_PRIVATE_KEY='<p8-private-key>'   APP_STORE_ENVIRONMENT='sandbox'
```

Keep `SNAPFIT_IAP_MOCK_VERIFY` unset or `false` for production.

Remaining production blockers:

1. Set the real Google Play and App Store secrets above.
2. Verify Google/Kakao login on physical devices with the Supabase Auth provider settings.
3. Smoke-test a real sandbox purchase on Android and iOS; confirm `store_purchases` and `subscriptions` materialize correctly.
4. Confirm print vendor requirements. Current Supabase package generation produces manifest JSON, ZIP, and an inspection PDF; vendor-specific press-ready PDF/API submission may still be required.
5. Set operational secrets for address search, order checkout, and admin key if not already set:
   - `SNAPFIT_ADDRESS_JUSO_KEY`
   - `SNAPFIT_ORDER_CHECKOUT_BASE_URL`
   - `SNAPFIT_ADMIN_KEY`

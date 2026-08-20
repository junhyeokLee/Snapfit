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

# Spring Backend Decommission Checklist

This checklist tracks the remaining risk before the legacy Spring Boot backend can be turned off.

## Current status

Most user-facing SnapFit flows now prefer Supabase directly or Supabase Edge Functions:

- Auth/profile/consent/account deletion: Supabase Auth + `profiles` + `account-delete` Edge Function.
- Templates/design catalog: Supabase `templates` / `template_likes`.
- Albums/members/invites: Supabase DB + Storage + `album-invites` Edge Function.
- Notifications/support: Supabase tables.
- Billing entitlement scaffold: native store IAP flow + `iap-verify` Edge Function.
- Admin operations: `admin-ops` Edge Function.
- Orders/print package: `order-confirm-payment` / `admin-ops.preparePrintPackage` generate private Supabase Storage artifacts.

## Remaining legacy REST code

The app still contains Retrofit/Dio API classes and fallback code paths for the old backend. These are mostly inactive when `supabaseClientProvider` is available, but they remain compiled and are useful as temporary rollback/fallback paths until production smoke tests are complete.

Known fallback areas:

- `auth_api.dart` and `AuthService` legacy fallback for Kakao ID-token/provider setup gaps.
- `template_api.dart`, `album_api.dart`, `album_member_api.dart` and generated Retrofit files retained for old repository tests/fallbacks.
- `billing_repository.dart` fallback Toss/NaverPay-style endpoints; production direction is native store IAP.
- `order_repository.dart` admin fallback endpoints. Address search now prefers `address-search`; checkout URL creation now prefers `order-checkout`.
- `notification_repository.dart` and `support_inquiry_repository.dart` legacy fallback endpoints.
- Firebase Storage helpers remain only for old `gs://` URLs and upload fallback during data migration.

## Blockers before disabling Spring

1. Kakao Supabase provider configuration must be verified on real devices.
2. Google Play / App Store receipt verification must be implemented with real provider secrets in Supabase secrets.
3. Print vendor production contract must be confirmed:
   - Current Supabase package creates JSON/ZIP/summary PDF and includes source images where reachable.
   - If the vendor requires press-ready flattened PDFs, add a renderer pipeline for album layer JSON.
4. Address search has been moved to the `address-search` Supabase Edge Function. Production requires `SNAPFIT_ADDRESS_JUSO_KEY` to be set as a Supabase secret.
5. Run production smoke tests for auth, album save/upload, order payment confirmation, admin print package generation, notification reads, and support inquiry submission.

## Safe shutdown sequence

1. Keep Spring backend running while Supabase flows are tested with production data.
2. Turn off legacy UI entry points that call checkout/address-search/Toss/NaverPay paths.
3. Remove or feature-flag `Env.baseUrl`/Dio fallback once smoke tests pass.
4. Delete legacy Retrofit API providers and generated files only after tests are rewritten around Supabase repositories.
5. Archive the Spring backend after no production traffic hits `/api/*` for a full release cycle.


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

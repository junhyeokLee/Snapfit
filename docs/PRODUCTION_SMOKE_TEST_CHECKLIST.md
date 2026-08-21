# SnapFit Production Smoke Test Checklist

Use this checklist after the Supabase production secrets are set. Do not paste secret values into chat or commit them to the repository.

## 0. Readiness audit

Run from the VPS/container clone:

```bash
cd /srv/projects/Snapfit
python3 tool/supabase_readiness_check.py
```

Expected before real production smoke testing:

- No legacy Spring/backend patterns found.
- Required Supabase secret names are present.
- Supabase Edge Functions respond to `OPTIONS`.

If secrets are not set yet, the script will fail only those secret checks and show the missing names without exposing values.

## 1. Required Supabase secrets

Set these directly in the VPS/container shell, never in Discord or GitHub.

### Android IAP

Use either a full JSON service account secret:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set \
  GOOGLE_PLAY_PACKAGE_NAME='com.yourcompany.snapfit' \
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='<service-account-json>'
```

Or split email/key values:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set \
  GOOGLE_PLAY_PACKAGE_NAME='com.yourcompany.snapfit' \
  GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL='<service-account-email>' \
  GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY='<private-key>'
```

### iOS IAP

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set \
  APP_STORE_ISSUER_ID='<issuer-id>' \
  APP_STORE_KEY_ID='<key-id>' \
  APP_STORE_BUNDLE_ID='<bundle-id>' \
  APP_STORE_PRIVATE_KEY='<p8-private-key>' \
  APP_STORE_ENVIRONMENT='sandbox'
```

Switch `APP_STORE_ENVIRONMENT` to `production` only after sandbox passes.

### Operations

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set \
  SNAPFIT_ADDRESS_JUSO_KEY='<juso-key>' \
  SNAPFIT_ORDER_CHECKOUT_BASE_URL='<checkout-provider-url>' \
  SNAPFIT_ADMIN_KEY='<admin-key>'
```

## 2. Auth smoke tests

- [ ] Fresh install launches without initialization errors.
- [ ] Google login succeeds and creates/updates `profiles`.
- [ ] Kakao login succeeds with Supabase Auth ID-token flow.
- [ ] Logout clears session.
- [ ] Session refresh works after app restart.
- [ ] Account deletion calls `account-delete` and removes auth/profile state.

## 3. Album/template smoke tests

- [ ] Create album.
- [ ] Save cover and pages.
- [ ] Upload/replace album images.
- [ ] Reopen app and confirm album state persists.
- [ ] Generate invite link.
- [ ] Open invite on another account/device and accept.
- [ ] Template list/detail loads.
- [ ] Like/unlike template.
- [ ] Create album from template.

## 4. Notification/support smoke tests

- [ ] Notification inbox loads.
- [ ] Mark one notification read.
- [ ] Mark all notifications read.
- [ ] Support inquiry creates a row in `support_inquiries`.

## 5. Native IAP smoke tests

Android sandbox:

- [ ] Product `snapfit_pro_monthly` loads from Google Play.
- [ ] Sandbox purchase completes.
- [ ] `iap-verify` returns active subscription.
- [ ] `store_purchases` contains a verified row.
- [ ] `subscriptions` contains/updates active entitlement.
- [ ] Restore purchases works.

Apple sandbox:

- [ ] Product `snapfit_pro_monthly` loads from App Store Connect.
- [ ] Sandbox purchase completes.
- [ ] `iap-verify` returns active subscription.
- [ ] `store_purchases` contains a verified row.
- [ ] `subscriptions` contains/updates active entitlement.
- [ ] Restore purchases works.

## 6. Physical order/admin smoke tests

- [ ] Address search succeeds through `address-search`.
- [ ] Physical print order is created.
- [ ] `order-checkout` returns a provider checkout URL when `SNAPFIT_ORDER_CHECKOUT_BASE_URL` is configured.
- [ ] Success deep link confirms payment through `order-confirm-payment`.
- [ ] Print package is generated in private Supabase Storage.
- [ ] Admin dashboard loads with `SNAPFIT_ADMIN_KEY` or admin JWT.
- [ ] Admin order list loads.
- [ ] Admin prepare print package regenerates artifacts.
- [ ] Admin shipping/delivered transitions work.

## 7. Backend shutdown gate

Only archive or power down Spring after:

- [ ] The readiness script passes.
- [ ] All smoke tests above pass on real devices/sandbox accounts.
- [ ] Supabase logs show no unexpected function failures.
- [ ] Spring logs show no `/api/*` traffic for one release cycle.

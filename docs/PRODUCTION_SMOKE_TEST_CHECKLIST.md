# SnapFit Production Smoke Test Checklist

Current billing supports Apple/Google consumable point purchases. External physical-order checkout has been retired without a replacement. Preserve existing order and payment history. Confirm actual server changes and outstanding setup in [deployment status](PAYMENT_PUSH_DEPLOYMENT_STATUS.md).

## 1. Configuration and local checks

Run from the app repository:

```bash
python3 tool/supabase_readiness_check.py --skip-remote
python3 test/server/test_supabase_readiness.py
bash -n scripts/configure_supabase_production_secrets.sh
```

When configuring the authorized SnapFit project, use `scripts/configure_supabase_production_secrets.sh` in a private terminal. It does not accept external checkout settings. The helper uploads entered values and then runs remote readiness checks; the commands above are offline.

Required payment secrets and product IDs are listed in [payment keys](ORDER_PAYMENT_KEYS.md). Worker credentials/schedules are covered by [point operations](POINT_PURCHASE_OPERATIONS.md) and [push operations](push_notifications.md). Secret-name checks and `OPTIONS` responses do not prove credential validity or successful store purchases.

## 2. Native point purchase tests

Complete [Android console preparation](ANDROID_POINT_PURCHASE_CHECKLIST.md) or Apple's sandbox setup before these tests. Use the device's native test payment methods and the corresponding configured server environment.

- [ ] All three configured point SKUs load with the correct localized price/currency.
- [ ] Missing verification configuration blocks opening the native purchase sheet.
- [ ] Successful purchase adds exactly the configured number of points once.
- [ ] A repeated receipt does not add points again.
- [ ] Android consumes only after verified delivery and permits another purchase of the same SKU.
- [ ] Cancelled/declined/pending purchases do not add points; later approval can complete delivery.
- [ ] App restart, background/foreground and interrupted network recover unfinished purchases.
- [ ] Switching app accounts cannot deliver another account's purchase.
- [ ] Verified refunds reverse the original grant once; spent points remain as debt.
- [ ] No subscription is sold or activated.

## 3. Auth, albums and templates

- [ ] Fresh install and Google/Kakao sign-in succeed.
- [ ] Profile, logout, session refresh and account deletion work.
- [ ] Album creation, editing, save and image upload persist after restart.
- [ ] An invited second account can open and accept its invitation.
- [ ] Template list/detail/like/use remain functional.
- [ ] AI generation checks the point balance and charges only the intended cost.

## 4. Push, inbox and support

- [ ] Test foreground, background and terminated-app push receipt and tap navigation.
- [ ] Read-one and read-all update only the current user's inbox state.
- [ ] Permission denial, notification preferences and quiet hours are respected.
- [ ] Logout prevents delivery of the previous account's private notifications.
- [ ] A support inquiry creates the expected record.

## 5. Retired checkout and existing order history

- [ ] External checkout, payment retry and manual payment-confirmation actions are absent.
- [ ] An old payment return link does not mark an order paid or begin production.
- [ ] Compatibility checkout/confirmation endpoints reject old clients without changing order state.
- [ ] Existing orders, addresses, tracking and status history remain readable.
- [ ] Authorized admin handling of existing orders retains historical records and private artifacts.
- [ ] Address search and admin authorization work for the retained operations.

## 6. Legacy backend shutdown gate

- [ ] The authorized project's configuration checks pass.
- [ ] Applicable sandbox/device checks pass with results recorded.
- [ ] Supabase logs show no unexpected failures.
- [ ] Spring logs show no `/api/*` traffic for one release cycle before archiving Spring.

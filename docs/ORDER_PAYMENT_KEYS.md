# Order and Billing Production Keys

Legacy Toss/NaverPay subscription billing is disabled. Mobile subscriptions use native Google Play Billing / App Store purchases verified by the `iap-verify` Supabase Edge Function.

Required production/sandbox secrets are tracked in `docs/PRODUCTION_SMOKE_TEST_CHECKLIST.md` and checked by:

```bash
python3 tool/supabase_readiness_check.py
```

Do not use the retired Spring/external-subscription billing flow.

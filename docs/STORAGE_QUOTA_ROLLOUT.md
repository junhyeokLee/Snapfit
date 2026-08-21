# Storage Quota Rollout

Storage quota is now checked through Supabase-backed billing/quota state.

## Runtime path

- Flutter calls `BillingRepository.preflightStorage(...)`.
- The repository reads the user's quota from Supabase `storage_quotas`.
- New album uploads go to Supabase Storage `album-assets`.
- Upload is blocked before storage write when the projected usage exceeds the hard limit.

## Verification

Run:

```bash
flutter test test/unit/album_persistence_service_test.dart
flutter analyze
python3 tool/supabase_readiness_check.py --skip-remote
```

Production smoke testing should include:

- Upload within quota succeeds.
- Upload over quota throws `StorageQuotaExceededException` and does not write assets.
- `myStorageQuotaProvider` refreshes after successful upload/purchase entitlement changes.

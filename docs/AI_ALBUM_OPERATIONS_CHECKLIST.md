# AI Album Operations Checklist

No secret values belong in this document, Git, Discord, issue comments, or screenshots. Do not paste OpenAI, Anthropic, Supabase, Google, or Apple private keys into chat or committed files.

## Current production policy

- AI album provider: `hybrid` after keys are installed and QA passes.
- OpenAI role: small-preview vision understanding.
- Anthropic role: final Korean photobook curation and JSON composition.
- High-quality AI draft cost: 700 points.
- Active point products:
  - `snapfit_points_2500` — 2,500P / 2,200 KRW
  - `snapfit_points_8000` — 8,000P / 5,900 KRW
  - `snapfit_points_18000` — 18,000P / 11,900 KRW

## Required server secrets before enabling hybrid

Set these in Supabase secrets from the VPS/container terminal, not chat:

- `OPENAI_API_KEY`
- `OPENAI_MODEL=gpt-4o`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_MODEL=claude-sonnet-4-5`
- `AI_ALBUM_DRAFT_PROVIDER=hybrid`
- `AI_ALBUM_DRAFT_TIMEOUT_MS=20000`

metadata rollback without app release:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set   AI_ALBUM_DRAFT_PROVIDER="metadata"
```

## Store setup

Register point products as consumable IAP products in Google Play Console and App Store Connect:

- `snapfit_points_2500`
- `snapfit_points_8000`
- `snapfit_points_18000`

Keep subscription product separate:

- `snapfit_pro_monthly`

## Android sandbox QA

1. Add tester account in Google Play Console license testing.
2. Confirm package name matches `GOOGLE_PLAY_PACKAGE_NAME` in Supabase secrets.
3. Register all three consumable products and activate them for the internal/sandbox track.
4. Install a build signed/configured for the same application id.
5. Open billing screen and confirm all point products are returned.
6. Buy `snapfit_points_2500` in sandbox.
7. Confirm `iap-verify` returns a `pointPurchase` payload and the app balance refreshes.
8. Trigger the same purchase update again if the device/store redelivers it; confirm duplicate purchase update does not grant points twice.
9. Confirm admin metrics show `POINT_PURCHASE_VERIFIED` and, if replayed, `POINT_PURCHASE_DUPLICATE`.

## iOS sandbox QA

1. Add Sandbox Apple Account in App Store Connect.
2. Confirm bundle id matches `APP_STORE_BUNDLE_ID` in Supabase secrets.
3. Register all three consumable products in App Store Connect.
4. Install a TestFlight or local build using the same bundle id.
5. Open billing screen and confirm all point products are returned.
6. Buy `snapfit_points_2500` with the sandbox account.
7. Confirm `iap-verify` verifies the App Store transaction and refreshes the point balance.
8. Reopen the app and confirm pending transaction delivery does not double-grant points.
9. Confirm admin metrics show purchase and duplicate/failure events correctly.

## AI album QA scenarios

1. Product query shows all active point products.
2. Sandbox point purchase verifies through `iap-verify`.
3. Purchase writes one `store_purchases` row and one idempotent `POINT_PURCHASE` ledger entry.
4. Replayed purchase update does not double-grant points.
5. AI album point confirmation shows live wallet balance.
6. Insufficient points leads to the billing/point charge screen.
7. Hybrid AI success shows reviewable draft and charges only after user accepts.
8. Hybrid AI failure/timeout falls back safely or fails without charging points.
9. Preview objects are cleaned by best-effort deletion and TTL cleanup.
10. metadata rollback returns usable metadata-only drafts if external providers fail or budget is paused.

## Billing failure UX acceptance

During sandbox and real-device QA, every failed billing state should be understandable without exposing raw store or server internals:

- Store unavailable: tell the tester to check Google Play/App Store login and sandbox account state.
- Missing product: mention sandbox/store product registration and show only safe product IDs.
- Purchase canceled: confirm points were not charged.
- Network failure: tell the tester to retry or use purchase restore.
- Verification failure: explain that the purchase was received but server confirmation did not complete; ask the tester to use purchase restore if points are not visible.
- Duplicate purchase update: explain that the purchase was already handled and points were not double-granted.
- Credential/server setup failure: say the purchase confirmation server setting is not ready; never show private key, service account, token, receipt, or raw provider payload values.
- Support code / 문의 코드: show a short code like `SF-PAY-7K2D` instead of raw transaction id, receipt, token, or provider payload.

## Release gate

Before turning on `AI_ALBUM_DRAFT_PROVIDER=hybrid` for real users:

- Supabase Edge Functions are deployed and JWT verification is enabled where expected.
- `supabase db lint --linked` passes.
- GitHub CI is green.
- Android sandbox purchase passed.
- iOS sandbox purchase passed, or iOS release is held back.
- At least one real-device AI album draft succeeds with hybrid enabled.
- Failure path confirms no album is created and no points are charged.
- Admin summary RPC returns recent AI/billing events.

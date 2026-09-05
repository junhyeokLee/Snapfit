# AI Album Operations Checklist

This checklist intentionally excludes secret values. Do not paste OpenAI, Anthropic, Supabase, Google, or Apple private keys into chat or committed files.

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

Rollback provider without app release:

```bash
SUPABASE_TELEMETRY_DISABLED=1 npx supabase@latest secrets set \
  AI_ALBUM_DRAFT_PROVIDER="metadata"
```

## Store setup

Register point products as consumable IAP products in Google Play Console and App Store Connect:

- `snapfit_points_2500`
- `snapfit_points_8000`
- `snapfit_points_18000`

Keep subscription product separate:

- `snapfit_pro_monthly`

## QA scenarios

1. Product query shows all active point products.
2. Sandbox point purchase verifies through `iap-verify`.
3. Purchase writes one `store_purchases` row and one idempotent `POINT_PURCHASE` ledger entry.
4. Replayed purchase update does not double-grant points.
5. AI album point confirmation shows live wallet balance.
6. Insufficient points leads to the billing/point charge screen.
7. Hybrid AI success shows reviewable draft and charges only after user accepts.
8. Hybrid AI failure/timeout falls back safely or fails without charging points.
9. Preview objects are cleaned by best-effort deletion and TTL cleanup.

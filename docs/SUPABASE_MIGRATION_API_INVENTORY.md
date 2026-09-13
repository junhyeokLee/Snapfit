# SnapFit Supabase Cutover Inventory

This document supersedes the old REST inventory. The Flutter runtime no longer calls the legacy Spring `/api/*` endpoints.

## Final runtime mapping

| Legacy area | Current runtime path |
| --- | --- |
| Auth login/profile/refresh/delete | Supabase Auth, `profiles`, `account-delete` Edge Function |
| Album CRUD/reorder/locks | Supabase `albums`, `album_pages` |
| Album members/invites | Supabase `album_members`, `album_invites`, `album-invites` Edge Function |
| Template list/detail/like/use | Supabase `templates`, `template_likes`, `albums` |
| Album/profile image upload | Supabase Storage buckets (`album-assets`, `avatars`) |
| Notifications | Supabase `notification_inbox`, `notification_reads` |
| Support inquiries | Supabase `support_inquiries` |
| Storage quota | Supabase `storage_quotas`; historical subscription rows retained without new sales |
| Consumable point purchases | Google Play / App Store + `iap-verify`; `iap-reconcile` refund handling |
| External subscription billing | Disabled; `billing-prepare`, `billing-approve`, and `billing-webhook` return HTTP 410 |
| Address lookup | `address-search` Edge Function |
| External physical order checkout | Retired with no replacement integration |
| Existing orders/print package | Order history, authorized admin operations and private `print-packages` bucket |
| Admin dashboard/orders/templates | `admin-ops` Edge Function |

## Verification

Run:

```bash
python3 tool/supabase_readiness_check.py --skip-remote
```

The production-ready remote check additionally requires Supabase secrets:

```bash
python3 tool/supabase_readiness_check.py
```

The code-only check is also enforced by GitHub Actions.

# SnapFit backend → Supabase gap analysis

Source backend: `https://github.com/junhyeokLee/Snapfit-BackEnd` cloned at `/srv/projects/Snapfit-BackEnd`.

## Backend stack

- Spring Boot 3.3.5 / Java 17
- Spring Data JPA
- MySQL
- Redis
- Firebase Admin SDK
- PDFBox for print package export
- JWT custom auth

## Important finding

The first Supabase migration was generated from the Flutter client and is a useful baseline, but the backend repo shows several mismatches and missing privileged flows. Do not consider the migration complete until the gaps below are resolved.

## Endpoint inventory summary

The backend exposes ~93 route mappings. Major groups:

- `/api/auth/*`
- `/api/albums/*`
- `/api/templates/*`
- `/api/billing/*`
- `/api/orders/*`
- `/api/notifications/*`
- `/api/support/inquiries`
- `/api/admin/*`, `/api/ops/*`
- public invite pages `/invite*`

## Schema gaps vs current Supabase migration

### User IDs

Backend `UserEntity` uses numeric `Long id` and table name ``user``. Flutter `UserInfo.id` is also `int`.

Supabase Auth uses UUID user IDs. Migration introduced `profiles.id uuid`. This is the correct direction, but client model and every old `userId` query path must be changed from numeric/string legacy IDs to Supabase Auth UUID strings.

### Albums

Backend tables:

- `album`
- `album_page`
- `album_member`

Backend fields not fully represented yet:

- `album_page.page_number` uses 1-based page numbers; current migration uses `page_index`.
- `album_page.image_url`, `original_url`, `preview_url`, `thumbnail_url` are distinct; current migration only has `thumbnail_url`.
- `album_member` has `id`, `status`, `invited_by`, `invite_token`; current migration separated `album_members` and `album_invites`, but does not mirror status/invited_by on members.

### Templates

Backend table names are singular:

- `template`
- `template_like`

Current Supabase migration uses plural names:

- `templates`
- `template_likes`

That is fine for a new Supabase-native design, but Flutter repository code must map to the new names. If any data export/import from MySQL is planned, we need transform scripts.

Backend `TemplateEntity` stores:

- `previewImagesJson` as LONGTEXT JSON
- `tagsJson` as LONGTEXT JSON
- `newUntil` timestamp, not just boolean `is_new`
- `active`

Current migration normalized preview/tags to text arrays and omitted `new_until`. Add `new_until` if admin/template release operations need the exact backend behavior.

### Billing

Backend has separate `billing_order` table. Current migration has `billing_plans`, `subscriptions`, `orders`, but no `billing_orders` equivalent.

Need to add `billing_orders` with:

- `order_id`
- `user_id`
- `plan_code`
- `provider`
- `status`
- `amount`
- `currency`
- `checkout_url`
- `reserve_id`
- `transaction_id`
- `fail_reason`
- `approved_at`
- timestamps

Billing logic uses provider secrets and webhook signature verification, so it must be Supabase Edge Functions or another trusted server path. It cannot be replaced by direct Flutter anon-key queries.

### Orders / print fulfillment

Backend order logic does much more than CRUD:

- quote calculation with configurable page pricing
- idempotent recent pending order detection
- checkout HTML/deeplink pages
- payment confirmation
- print package JSON generation
- PDF/ZIP export
- print vendor submission
- admin shipping/delivered transitions
- push notifications on status changes

These need Edge Functions or a retained backend service. Direct Supabase client queries are only appropriate for user-owned order reads and simple order creation after validation is replicated.

### Notifications

Backend has broadcast-like `notification_inbox` plus read tracking via `NotificationReadEntity` (separate read table). Current migration simplified to per-user `notifications` with `is_read`.

Choose one model:

1. Keep simplified per-user notifications, easier for Supabase.
2. Mirror backend broadcast/read model with `notification_inbox` + `notification_reads`, better if topic/broadcast semantics matter.

### Support inquiries

Backend requires:

- `user_id` non-null
- `category`
- `subject`
- `message`
- `status`
- `resolved_at`
- `resolved_by`

Current migration lacks `category`, `resolved_at`, `resolved_by`, and allows null `user_id`. Add these if admin CS views are being migrated.

## Edge Functions required

These should not be direct Flutter/Supabase DB calls:

- `billing-prepare`
- `billing-approve`
- `billing-webhook`
- `billing-cancel`
- `order-checkout-page` / deeplink return pages
- `order-payment-confirm`
- `order-print-package-prepare`
- `order-print-package-download` or storage-backed equivalent
- `admin-dashboard`
- `admin-cs-signals`
- `admin-template-upsert/validate/ai-draft`
- notification broadcast/send operations
- address search proxy, if external API keys are involved

## Recommended next migration step

Create a second Supabase migration to align the schema with backend entities before changing Flutter repositories:

1. Add `billing_orders`.
2. Add missing `album_pages` URL fields and page number compatibility.
3. Add `album_members.status`, `invited_by`, `invite_token` or adjust invite design deliberately.
4. Add `templates.new_until`.
5. Add support inquiry fields.
6. Decide notification model and update schema accordingly.

Then migrate Auth model in Flutter from legacy numeric user ID to Supabase UUID strings.

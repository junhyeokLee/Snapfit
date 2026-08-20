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

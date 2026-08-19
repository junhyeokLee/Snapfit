# Snapfit Supabase migration

This branch starts the Firebase-to-Supabase migration for the Flutter app.

## Migration scope

- Auth users are provided by Supabase Auth.
- User profiles are mirrored into `public.profiles` by an Auth trigger.
- Albums, members, invitations, photos, edit logs, snapshots, and orders are stored in Postgres.
- Album media is stored in the private `album-media` Storage bucket.
- Row Level Security is enabled for all application tables and Storage objects.

## Apply the database migration

Run the SQL file in the Supabase project's SQL Editor:

`supabase/migrations/20260819144300_initial_snapfit.sql`

The migration is intended for a new Supabase project. It is idempotent for tables, indexes, and the Storage bucket. Policies and triggers should only be applied once in a fresh project.

## Required client configuration

The Flutter app must read these values from a non-committed environment/configuration source:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Never put a Supabase service-role key in the Flutter application or commit it to GitHub.

## Storage path convention

Use the album UUID as the first path segment:

`<album-id>/<user-id>/<photo-id>.<extension>`

This is required by the Storage RLS policies in the migration.

## Next code migration steps

1. Add the Supabase Flutter package.
2. Replace Firebase initialization in `lib/main.dart`.
3. Replace Firebase Auth adapters with Supabase Auth adapters.
4. Replace Firestore/Storage repositories with Postgres/Storage repositories.
5. Keep domain entities independent from the backend client.
6. Run Flutter analysis and tests before merging the migration branch.

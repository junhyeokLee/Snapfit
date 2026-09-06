# Supabase Admin Access Runbook

Do not paste service-role keys, access tokens, JWTs, database passwords, OAuth secrets, Google service account JSON, Apple private keys, purchase receipts, or transaction tokens into chat, Git, support notes, or screenshots.

## Current admin model

Snapfit currently decides admin access with `public.is_admin()`:

```sql
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;
```

That means an app/Supabase user becomes an admin only when their Supabase Auth `auth.users.raw_app_meta_data` / JWT `app_metadata` contains:

```json
{"role":"admin"}
```

There is no public in-app admin login screen yet. Admin entry is currently through Supabase Dashboard/SQL Editor or future internal admin tooling after signing in as an admin user.

## How an admin enters today

1. Create or identify the operator's normal Supabase Auth user.
2. Grant `app_metadata.role = admin` from Supabase Dashboard or a secure service-role/admin SQL environment.
3. Have the operator sign out/in so the JWT is refreshed.
4. Verify admin access with a guarded RPC.
5. Run admin operations from Supabase SQL Editor or a trusted internal console.

## Verify current user is admin

Run as the signed-in operator/session:

```sql
select public.is_admin();
```

Expected:

```text
true
```

Also verify a guarded function works:

```sql
select public.get_ai_album_operations_summary(7);
```

If this returns `admin privileges required`, the operator's JWT either does not have `app_metadata.role = admin` or they need to sign out/in to refresh the token.

## Grant admin role safely

Preferred: Supabase Dashboard → Authentication → Users → select user → Raw app metadata → add `role: admin`.

If using SQL, run only in Supabase SQL Editor or another trusted admin/service-role SQL session. Replace only the UUID placeholder. Do not paste secrets into chat.

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where id = 'USER_UUID_HERE';
```

Then the operator must sign out/in.

## Remove admin role

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) - 'role'
where id = 'USER_UUID_HERE';
```

Then the operator must sign out/in.

## Admin operations available now

Operations/metrics:

```sql
select public.get_ai_album_operations_summary(7);
select * from public.ai_album_daily_metrics order by metric_date desc limit 30;
select * from public.ai_album_product_metrics order by estimated_revenue_krw desc;
```

Point support:

```sql
select * from public.admin_get_user_point_ledger('USER_UUID_HERE', 50);

select * from public.admin_adjust_user_points(
  'USER_UUID_HERE',
  2500,
  'support adjustment',
  'cs-USER_UUID_HERE-YYYYMMDD-001',
  '{"source":"cs"}'::jsonb
);
```

## What is still missing

A dedicated in-app/web admin console is not built yet. Until then, admin access means:

- admin role in Supabase `app_metadata`, plus
- Supabase SQL Editor/trusted console access, plus
- guarded RPCs/views such as `get_ai_album_operations_summary`, `admin_adjust_user_points`, and `admin_get_user_point_ledger`.

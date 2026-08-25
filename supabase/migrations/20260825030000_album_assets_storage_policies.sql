-- Allow authenticated users to manage only their own album-assets folder.
-- Snapfit client uploads album images/covers under: <auth.uid()>/albums/...
-- Without these policies Supabase Storage rejects inserts with:
--   new row violates row-level security policy (403 Unauthorized)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'album-assets',
  'album-assets',
  false,
  52428800,
  array['image/jpeg','image/png','image/webp','application/pdf','application/zip']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$ begin
  create policy "album_assets_own_or_admin_read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'album-assets'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_own_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_own_or_admin_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'album-assets'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  )
  with check (
    bucket_id = 'album-assets'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_own_or_admin_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'album-assets'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );
exception when duplicate_object then null;
end $$;

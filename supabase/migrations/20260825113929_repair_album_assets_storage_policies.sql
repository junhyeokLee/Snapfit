-- Repair album-assets Storage policies that were skipped on the remote project
-- because an earlier local migration reused the 20260825030000 timestamp.
--
-- Current clients upload under: <auth.uid()>/albums/...
-- Older installed clients may still upload under: albums/...

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

do $$ begin
  create policy "album_assets_legacy_authenticated_read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = 'albums'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_legacy_authenticated_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = 'albums'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_legacy_authenticated_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = 'albums'
  )
  with check (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = 'albums'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "album_assets_legacy_authenticated_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'album-assets'
    and (storage.foldername(name))[1] = 'albums'
  );
exception when duplicate_object then null;
end $$;

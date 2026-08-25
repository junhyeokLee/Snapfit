-- Temporary compatibility policies for already-installed clients that still upload
-- album assets under the legacy path: albums/...
-- New clients use <auth.uid()>/albums/... and are covered by 20260825030000.
-- Keep these policies until all production clients have upgraded.

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

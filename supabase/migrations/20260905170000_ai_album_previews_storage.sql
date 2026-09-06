-- Private, short-lived preview images used only after explicit advanced AI consent.
-- Object path: <auth.uid()>/<draft_id>/<asset_id>.webp

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ai-album-previews',
  'ai-album-previews',
  false,
  2097152,
  array['image/webp','image/jpeg']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

do $$ begin
  create policy "ai_album_previews_own_read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'ai-album-previews'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "ai_album_previews_own_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'ai-album-previews'
    and (storage.foldername(name))[1] = auth.uid()::text
    and lower(storage.extension(name)) in ('webp', 'jpg', 'jpeg')
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create policy "ai_album_previews_own_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'ai-album-previews'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
exception when duplicate_object then null;
end $$;

create or replace function public.delete_expired_ai_album_previews(
  p_older_than interval default interval '2 hours'
)
returns integer
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_deleted integer;
begin
  delete from storage.objects
  where bucket_id = 'ai-album-previews'
    and created_at < now() - p_older_than;

  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

grant execute on function public.delete_expired_ai_album_previews(interval) to service_role;

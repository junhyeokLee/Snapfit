-- Private storage bucket for generated print package artifacts.
insert into storage.buckets (id, name, public)
values ('print-packages', 'print-packages', false)
on conflict (id) do update set public = excluded.public;

-- Admins can inspect generated print package artifacts from Supabase Storage.
do $$ begin
  create policy "print_packages_admin_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'print-packages' and public.is_admin());
exception when duplicate_object then null; end $$;

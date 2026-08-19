-- Snapfit initial Supabase migration
-- Generated for the Firebase -> Supabase migration.
-- Safe to run once in a new Supabase project.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  email text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.albums (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  cover_image_url text,
  status text not null default 'active' check (status in ('active', 'frozen', 'archived')),
  is_private boolean not null default true,
  share_token text unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.album_members (
  album_id uuid not null references public.albums(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'viewer' check (role in ('owner', 'editor', 'viewer')),
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (album_id, user_id)
);

create table if not exists public.album_invites (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  invited_by uuid not null references auth.users(id) on delete cascade,
  email text,
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  role text not null default 'viewer' check (role in ('editor', 'viewer')),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked', 'expired')),
  expires_at timestamptz not null default timezone('utc', now()) + interval '7 days',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  uploaded_by uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  thumbnail_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  width integer,
  height integer,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.edit_logs (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  entity_type text,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.album_snapshots (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.albums(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  album_id uuid references public.albums(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  snapshot_id uuid references public.album_snapshots(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'processing', 'completed', 'cancelled', 'refunded')),
  provider text,
  provider_order_id text,
  amount numeric(12, 2),
  currency text not null default 'KRW',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists albums_owner_id_idx on public.albums(owner_id);
create index if not exists album_members_user_id_idx on public.album_members(user_id);
create index if not exists photos_album_id_sort_order_idx on public.photos(album_id, sort_order, created_at);
create index if not exists edit_logs_album_id_created_at_idx on public.edit_logs(album_id, created_at desc);
create index if not exists orders_user_id_created_at_idx on public.orders(user_id, created_at desc);

create or replace function public.is_album_member(target_album_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.album_members
    where album_id = target_album_id and user_id = auth.uid()
  ) or exists (
    select 1 from public.albums
    where id = target_album_id and owner_id = auth.uid()
  );
$$;

create or replace function public.album_role(target_album_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select 'owner' from public.albums where id = target_album_id and owner_id = auth.uid()),
    (select role from public.album_members where album_id = target_album_id and user_id = auth.uid())
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name'), new.email)
  on conflict (id) do update set email = excluded.email, updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

insert into storage.buckets (id, name, public)
values ('album-media', 'album-media', false)
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.albums enable row level security;
alter table public.album_members enable row level security;
alter table public.album_invites enable row level security;
alter table public.photos enable row level security;
alter table public.edit_logs enable row level security;
alter table public.album_snapshots enable row level security;
alter table public.orders enable row level security;

create policy profiles_select_own on public.profiles for select using (id = auth.uid());
create policy profiles_insert_own on public.profiles for insert with check (id = auth.uid());
create policy profiles_update_own on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy albums_select_member on public.albums for select using (owner_id = auth.uid() or public.is_album_member(id));
create policy albums_insert_owner on public.albums for insert with check (owner_id = auth.uid());
create policy albums_update_editor on public.albums for update using (public.album_role(id) in ('owner', 'editor')) with check (owner_id = auth.uid() or public.album_role(id) in ('owner', 'editor'));
create policy albums_delete_owner on public.albums for delete using (owner_id = auth.uid());

create policy members_select_member on public.album_members for select using (user_id = auth.uid() or public.album_role(album_id) in ('owner', 'editor'));
create policy members_insert_editor on public.album_members for insert with check (public.album_role(album_id) in ('owner', 'editor'));
create policy members_update_owner on public.album_members for update using (public.album_role(album_id) = 'owner') with check (public.album_role(album_id) = 'owner');
create policy members_delete_owner on public.album_members for delete using (public.album_role(album_id) = 'owner' or user_id = auth.uid());

create policy invites_select_editor on public.album_invites for select using (invited_by = auth.uid() or public.album_role(album_id) in ('owner', 'editor'));
create policy invites_insert_editor on public.album_invites for insert with check (invited_by = auth.uid() and public.album_role(album_id) in ('owner', 'editor'));
create policy invites_update_editor on public.album_invites for update using (invited_by = auth.uid() or public.album_role(album_id) in ('owner', 'editor'));

create policy photos_select_member on public.photos for select using (public.is_album_member(album_id));
create policy photos_insert_editor on public.photos for insert with check (uploaded_by = auth.uid() and public.album_role(album_id) in ('owner', 'editor'));
create policy photos_update_editor on public.photos for update using (public.album_role(album_id) in ('owner', 'editor')) with check (public.album_role(album_id) in ('owner', 'editor'));
create policy photos_delete_editor on public.photos for delete using (public.album_role(album_id) in ('owner', 'editor'));

create policy logs_select_member on public.edit_logs for select using (public.is_album_member(album_id));
create policy logs_insert_member on public.edit_logs for insert with check (user_id = auth.uid() and public.is_album_member(album_id));
create policy snapshots_select_member on public.album_snapshots for select using (public.is_album_member(album_id));
create policy snapshots_insert_editor on public.album_snapshots for insert with check (created_by = auth.uid() and public.album_role(album_id) in ('owner', 'editor'));
create policy orders_select_own on public.orders for select using (user_id = auth.uid());
create policy orders_insert_own on public.orders for insert with check (user_id = auth.uid());

create policy storage_select_album_member on storage.objects for select using (
  bucket_id = 'album-media' and public.is_album_member((storage.foldername(name))[1]::uuid)
);
create policy storage_insert_album_editor on storage.objects for insert with check (
  bucket_id = 'album-media' and public.album_role((storage.foldername(name))[1]::uuid) in ('owner', 'editor')
);
create policy storage_update_album_editor on storage.objects for update using (
  bucket_id = 'album-media' and public.album_role((storage.foldername(name))[1]::uuid) in ('owner', 'editor')
);
create policy storage_delete_album_editor on storage.objects for delete using (
  bucket_id = 'album-media' and public.album_role((storage.foldername(name))[1]::uuid) in ('owner', 'editor')
);

create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger albums_set_updated_at before update on public.albums for each row execute procedure public.set_updated_at();
create trigger photos_set_updated_at before update on public.photos for each row execute procedure public.set_updated_at();
create trigger orders_set_updated_at before update on public.orders for each row execute procedure public.set_updated_at();

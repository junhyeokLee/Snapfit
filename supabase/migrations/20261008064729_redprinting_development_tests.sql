-- Vendor development fixtures are isolated from customer orders and payments.
create table public.redprinting_dev_settings (
  id integer primary key default 1 check (id = 1),
  environment text not null default 'development' check (environment = 'development'),
  sender_name text not null default '스냅핏' check (sender_name = '스냅핏'),
  sender_tel text not null default '', sender_zipcode text not null default '',
  sender_address text not null default '', sender_address_detail text not null default '',
  color_mode text not null default 'UNCONFIRMED' check (color_mode in ('UNCONFIRMED','RGB','CMYK')),
  color_approval_note text not null default '', color_approved_at timestamptz,
  test_deposit_enabled boolean not null default false,
  development_rgb_test_acknowledged boolean not null default false,
  development_geometry_test_acknowledged boolean not null default false,
  codes_synced_at timestamptz,
  updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now()
);
insert into public.redprinting_dev_settings(id) values (1);

create table public.redprinting_dev_codes (
  order_code text primary key, goods_desc text not null default '', product_name text not null default '',
  work_size text not null default '', cut_size text not null default '', use_yn text not null default '',
  synced_at timestamptz not null default now()
);
create table public.redprinting_dev_mappings (
  product_id text not null check (product_id in ('REDP_200X150_SOFT','REDP_200_SOFT','REDP_250X200_SOFT','REDP_250_SOFT','REDP_300_SOFT',
    'REDP_200X150_HARD','REDP_200_HARD','REDP_250X200_HARD','REDP_250_HARD','REDP_300_HARD')),
  page_count integer not null check (page_count between 20 and 80 and page_count % 2 = 0),
  order_code text references public.redprinting_dev_codes(order_code),
  exact_match_confirmed boolean not null default false,
  vendor_use_yn text not null default '', vendor_order_yn text not null default '',
  detail_snapshot jsonb not null default '{}'::jsonb, price_snapshot jsonb not null default '{}'::jsonb,
  note text not null default '', verified_at timestamptz, updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(), primary key(product_id,page_count)
);
insert into public.redprinting_dev_mappings(product_id,page_count)
select product_id, page_count from unnest(array['REDP_200X150_SOFT','REDP_200_SOFT','REDP_250X200_SOFT','REDP_250_SOFT','REDP_300_SOFT',
  'REDP_200X150_HARD','REDP_200_HARD','REDP_250X200_HARD','REDP_250_HARD','REDP_300_HARD']) as product_id
cross join generate_series(20,80,2) as page_count;
-- Each approval identifies one complete specification, not a size/cover family.
create unique index redprinting_dev_mappings_order_code_unique on public.redprinting_dev_mappings(order_code) where order_code is not null;

create table public.redprinting_dev_tests (
  id uuid primary key default gen_random_uuid(), request_id uuid not null unique,
  environment text not null default 'development' check (environment = 'development'),
  product_id text not null, page_count integer not null,
  foreign key(product_id,page_count) references public.redprinting_dev_mappings(product_id,page_count),
  order_num text not null unique, order_seq integer not null default 1 check (order_seq = 1),
  order_code text, label text not null default '', recipient jsonb not null,
  status text not null default 'DRAFT' check(status in ('DRAFT','FILES_READY','SUBMITTING','UNKNOWN','ACCEPTED','REJECTED','CONFIRMED','CANCELED')),
  upload_id uuid, cover_path text, interior_path text, source_fingerprint text,
  pdf_manifest jsonb not null default '{}'::jsonb, price_snapshot jsonb not null default '{}'::jsonb,
  settings_snapshot jsonb not null default '{}'::jsonb,
  vendor_result_id text, vendor_status jsonb not null default '{}'::jsonb,
  error_code text, submitted_at timestamptz, last_status_at timestamptz,
  confirmed_at timestamptz, canceled_at timestamptz,
  lock_owner uuid, lock_until timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index redprinting_dev_tests_created_at_idx on public.redprinting_dev_tests(created_at desc);

-- All tables are private to the admin Edge Function. Users, including app
-- administrators, cannot bypass its authorization/validation via the Data API.
alter table public.redprinting_dev_settings enable row level security;
alter table public.redprinting_dev_codes enable row level security;
alter table public.redprinting_dev_mappings enable row level security;
alter table public.redprinting_dev_tests enable row level security;
revoke all on public.redprinting_dev_settings, public.redprinting_dev_codes, public.redprinting_dev_mappings, public.redprinting_dev_tests from public, anon, authenticated;
grant all on public.redprinting_dev_settings, public.redprinting_dev_codes, public.redprinting_dev_mappings, public.redprinting_dev_tests to service_role;

create table public.redprinting_dev_api_gate (
  id integer primary key default 1 check(id = 1), next_call_at timestamptz not null default now(),
  lock_owner uuid, lock_until timestamptz
);
insert into public.redprinting_dev_api_gate(id) values(1);
alter table public.redprinting_dev_api_gate enable row level security;
revoke all on public.redprinting_dev_api_gate from public, anon, authenticated;
grant all on public.redprinting_dev_api_gate to service_role;

-- A database lease spaces ALL account calls, including authentication, across
-- isolates/invocations. No raw API key or signed PDF URL is stored in Postgres.
create function public.redprinting_dev_acquire_slot(p_owner uuid)
returns integer language plpgsql security invoker set search_path = '' as $$
declare gate public.redprinting_dev_api_gate; wait_until timestamptz;
begin
  select * into gate from public.redprinting_dev_api_gate where id = 1 for update;
  wait_until := greatest(gate.next_call_at, coalesce(gate.lock_until, '-infinity'::timestamptz));
  if wait_until > clock_timestamp() then
    return greatest(1, ceil(extract(epoch from wait_until - clock_timestamp()) * 1000)::integer);
  end if;
  update public.redprinting_dev_api_gate set lock_owner = p_owner, lock_until = clock_timestamp() + interval '35 seconds',
    next_call_at = clock_timestamp() + interval '600 milliseconds' where id = 1;
  return 0;
end $$;
create function public.redprinting_dev_release_slot(p_owner uuid)
returns void language sql security invoker set search_path = '' as $$
  update public.redprinting_dev_api_gate set lock_owner = null, lock_until = null where id = 1 and lock_owner = p_owner;
$$;
create function public.redprinting_dev_acquire_test(p_id uuid,p_owner uuid)
returns boolean language sql security invoker set search_path = '' as $$
  with claimed as (
    update public.redprinting_dev_tests set lock_owner = p_owner, lock_until = clock_timestamp() + interval '110 seconds'
    where id = p_id and (lock_until is null or lock_until < clock_timestamp()) returning id
  ) select exists(select 1 from claimed);
$$;
create function public.redprinting_dev_release_test(p_id uuid,p_owner uuid)
returns void language sql security invoker set search_path = '' as $$
  update public.redprinting_dev_tests set lock_owner = null, lock_until = null where id = p_id and lock_owner = p_owner;
$$;
revoke all on function public.redprinting_dev_acquire_slot(uuid),public.redprinting_dev_release_slot(uuid),
  public.redprinting_dev_acquire_test(uuid,uuid),public.redprinting_dev_release_test(uuid,uuid) from public,anon,authenticated;
grant execute on function public.redprinting_dev_acquire_slot(uuid),public.redprinting_dev_release_slot(uuid),
  public.redprinting_dev_acquire_test(uuid,uuid),public.redprinting_dev_release_test(uuid,uuid) to service_role;

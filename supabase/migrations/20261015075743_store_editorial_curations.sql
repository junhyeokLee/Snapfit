-- Public merchandising metadata only. Prices and ownership stay in the shop.
create table public.store_curations (
  placement text primary key check (placement in ('templates', 'materials')),
  title text not null check (char_length(btrim(title)) between 1 and 48),
  subtitle text not null default '' check (char_length(subtitle) <= 120),
  enabled boolean not null default true,
  product_keys text[] not null default '{}' check (cardinality(product_keys) <= 12),
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default now()
);
alter table public.store_curations enable row level security;
revoke all on public.store_curations from public, anon, authenticated, service_role;
grant select on public.store_curations to anon, authenticated, service_role;
grant update (title, subtitle, enabled, product_keys, version, updated_at)
  on public.store_curations to service_role;
-- Hidden/empty configurations must also be readable so clients do not restore
-- default promotions after an administrator deliberately hides a section.
create policy store_curations_public_read on public.store_curations
  for select to anon, authenticated using (true);

insert into public.store_curations (placement, title, subtitle, product_keys) values
 ('templates', '오래 간직하고 싶은 장면들', '사진이 한 권의 이야기가 되는 디자인',
  array['template:shore-days','template:silk-vows','template:lightbound','template:reading-room']),
 ('materials', '한 끗을 더하는 소재', '종이의 결부터 작은 매듭까지',
  array['frame:materialLinenOval','sticker:atelierColorSlips','sticker:atelierRibbonPlate','phrase:collage-atelier-ribbon']);

create function public.save_store_curation(
  p_placement text, p_title text, p_subtitle text, p_enabled boolean,
  p_product_keys text[], p_expected_version integer
) returns public.store_curations
language plpgsql security invoker set search_path = '' as $$
declare saved public.store_curations;
begin
  if p_placement not in ('templates','materials') or p_placement is null
     or p_title is null or char_length(btrim(p_title)) not between 1 and 48
     or p_subtitle is null or char_length(p_subtitle) > 120 or p_enabled is null
     or p_product_keys is null or cardinality(p_product_keys) > 12
     or p_expected_version is null or p_expected_version < 1
     or exists (select 1 from unnest(p_product_keys) k where k is null)
     or cardinality(p_product_keys) <> (select count(distinct k) from unnest(p_product_keys) k)
  then raise exception 'invalid_curation'; end if;
  -- Validate against current sale state, including free products; never mint
  -- products, change prices, or grant materials through merchandising edits.
  if p_enabled and exists (
    select 1 from unnest(p_product_keys) k
    left join public.point_shop_products p on p.product_key = k
    where p.product_key is null or not p.is_active or p.point_price is null
       or (p_placement = 'templates' and p.kind <> 'template')
       or (p_placement = 'materials' and p.kind not in ('frame','sticker','phrase'))
  ) then raise exception 'curation_product_unavailable'; end if;
  update public.store_curations set title = btrim(p_title), subtitle = btrim(p_subtitle),
    enabled = p_enabled, product_keys = p_product_keys, version = version + 1, updated_at = clock_timestamp()
    where placement = p_placement and version = p_expected_version returning * into saved;
  if not found then raise exception 'curation_changed'; end if;
  return saved;
end $$;
revoke all on function public.save_store_curation(text,text,text,boolean,text[],integer)
  from public, anon, authenticated;
grant execute on function public.save_store_curation(text,text,text,boolean,text[],integer) to service_role;

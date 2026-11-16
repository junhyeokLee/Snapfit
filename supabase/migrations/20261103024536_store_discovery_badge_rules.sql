-- Publication is independent of edits, price updates and app installation.
-- No customer balance, ownership, album or existing product row is changed.
create schema if not exists store_private;
revoke all on schema store_private from public;
grant usage on schema store_private to anon, authenticated, service_role;

create table store_private.product_publications (
  product_key text primary key references public.point_shop_products(product_key),
  first_published_at timestamptz not null
);
alter table store_private.product_publications enable row level security;
revoke all on store_private.product_publications from public, anon, authenticated, service_role;
grant select, insert on store_private.product_publications to service_role;

-- This release's actual successful production registration time. Unknown
-- historical publication dates stay unknown rather than all becoming NEW.
insert into store_private.product_publications(product_key,first_published_at)
select product_key, '2026-11-02T18:01:39Z'::timestamptz
from public.point_shop_products
where product_key = any(array[
  'template:story-coffee-notebook','template:story-night-city-archive',
  'frame:cafeGlassine','frame:cafeLedgerMat','frame:cafeReceiptFold',
  'frame:nocturneContact','frame:nocturneTransit','frame:nocturneDuplex',
  'sticker:story-coffee-notebook-paper','sticker:story-coffee-notebook-motif',
  'sticker:cafeRoastedLeaf','sticker:story-night-city-archive-paper',
  'sticker:story-night-city-archive-motif','sticker:nocturneGlassine',
  'phrase:collage-story-coffee-notebook','phrase:collage-sensory-coffee-note',
  'phrase:collage-story-night-city-archive','phrase:collage-sensory-night-index'
])
on conflict (product_key) do nothing;

create index point_shop_ownership_recent_discovery_idx
  on public.point_shop_ownership(created_at,product_key) include(user_id);

-- Intentionally public aggregate. The definer is private, has no arguments or
-- writes, a fixed empty search path, and returns no owner IDs or small counts.
-- Only ledger-backed durable point acquisitions can qualify; arbitrary legacy
-- is_best/weekly_score flags, likes, views and developer previews cannot.
create function store_private.product_discovery()
returns table(product_key text,first_published_at timestamptz,best_rank integer)
language sql stable security definer set search_path = '' as $discovery$
  with qualified as (
    select p.product_key,p.kind,count(distinct o.user_id) as owners
    from public.point_shop_products p
    join public.point_shop_ownership o on o.product_key=p.product_key
    where p.is_active and p.point_price is not null
      and o.created_at >= now()-interval '30 days'
      and o.created_at <= now()
    group by p.product_key,p.kind
    having count(distinct o.user_id) >= 10
  ), ranked as (
    select q.product_key,
      row_number() over(partition by q.kind order by q.owners desc,q.product_key)::integer as rank
    from qualified q
  )
  select p.product_key,publication.first_published_at,
    case when ranked.rank <= 5 then ranked.rank end
  from public.point_shop_products p
  left join store_private.product_publications publication using(product_key)
  left join ranked using(product_key)
  where p.is_active and p.point_price is not null
  order by p.product_key;
$discovery$;
revoke all on function store_private.product_discovery() from public, anon, authenticated, service_role;
grant execute on function store_private.product_discovery() to anon, authenticated, service_role;

create function public.get_store_product_discovery()
returns table(product_key text,first_published_at timestamptz,best_rank integer)
language sql stable security invoker set search_path = '' as $discovery$
  select * from store_private.product_discovery();
$discovery$;
revoke all on function public.get_store_product_discovery() from public, anon, authenticated, service_role;
grant execute on function public.get_store_product_discovery() to anon, authenticated, service_role;

-- Owner-approved prices: 2026-09-10-catalog-5.
-- Only the explicit keys below change. Wallets and ownership are untouched.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
do $check$
begin
  if exists (
    select 1 from public.point_shop_products p
    join jsonb_to_recordset('[{"product_key":"template:vow-keepsake","asset_id":"vow-keepsake","kind":"template","title":"약속을 묶은 책","point_price":2500,"is_active":true},{"product_key":"template:luminous-edition","asset_id":"luminous-edition","kind":"template","title":"둘만의 여행","point_price":2500,"is_active":true},{"product_key":"template:daily-cabinet","asset_id":"daily-cabinet","kind":"template","title":"하루의 수집함","point_price":2500,"is_active":true},{"product_key":"template:first-year-keepsake","asset_id":"first-year-keepsake","kind":"template","title":"너의 첫 계절","point_price":2500,"is_active":true},{"product_key":"template:table-stories","asset_id":"table-stories","kind":"template","title":"우리 집 식탁","point_price":2500,"is_active":true},{"product_key":"template:two-tickets","asset_id":"two-tickets","kind":"template","title":"둘이 모은 장면","point_price":2500,"is_active":true},{"product_key":"template:walk-and-nap","asset_id":"walk-and-nap","kind":"template","title":"산책하고 낮잠","point_price":2500,"is_active":true},{"product_key":"template:silk-vows","asset_id":"silk-vows","kind":"template","title":"서약의 결","point_price":1800,"is_active":true},{"product_key":"template:shore-days","asset_id":"shore-days","kind":"template","title":"해변에서 보낸 날","point_price":1800,"is_active":true},{"product_key":"template:reading-room","asset_id":"reading-room","kind":"template","title":"문장을 모으는 생활","point_price":1800,"is_active":true},{"product_key":"template:first-wardrobe","asset_id":"first-wardrobe","kind":"template","title":"너의 작은 옷장","point_price":1800,"is_active":true},{"product_key":"template:sunday-picnic","asset_id":"sunday-picnic","kind":"template","title":"일요일의 피크닉","point_price":1800,"is_active":true},{"product_key":"template:shared-seasons","asset_id":"shared-seasons","kind":"template","title":"같이 사는 계절","point_price":1800,"is_active":true},{"product_key":"template:little-companion","asset_id":"little-companion","kind":"template","title":"작은 동거인","point_price":1800,"is_active":true}]'::jsonb)
      as s(product_key text, asset_id text, kind text, is_active boolean)
      on s.product_key = p.product_key
    where p.kind <> s.kind or p.asset_id <> s.asset_id
      or (s.kind = 'template' and not s.is_active and p.is_active)
  ) then
    raise exception 'catalog_identity_or_active_template_changed';
  end if;
end
$check$;
insert into public.point_shop_products as p
  (product_key, asset_id, kind, title, point_price, is_active)
select product_key, asset_id, kind, title, point_price, is_active
from jsonb_to_recordset('[{"product_key":"template:vow-keepsake","asset_id":"vow-keepsake","kind":"template","title":"약속을 묶은 책","point_price":2500,"is_active":true},{"product_key":"template:luminous-edition","asset_id":"luminous-edition","kind":"template","title":"둘만의 여행","point_price":2500,"is_active":true},{"product_key":"template:daily-cabinet","asset_id":"daily-cabinet","kind":"template","title":"하루의 수집함","point_price":2500,"is_active":true},{"product_key":"template:first-year-keepsake","asset_id":"first-year-keepsake","kind":"template","title":"너의 첫 계절","point_price":2500,"is_active":true},{"product_key":"template:table-stories","asset_id":"table-stories","kind":"template","title":"우리 집 식탁","point_price":2500,"is_active":true},{"product_key":"template:two-tickets","asset_id":"two-tickets","kind":"template","title":"둘이 모은 장면","point_price":2500,"is_active":true},{"product_key":"template:walk-and-nap","asset_id":"walk-and-nap","kind":"template","title":"산책하고 낮잠","point_price":2500,"is_active":true},{"product_key":"template:silk-vows","asset_id":"silk-vows","kind":"template","title":"서약의 결","point_price":1800,"is_active":true},{"product_key":"template:shore-days","asset_id":"shore-days","kind":"template","title":"해변에서 보낸 날","point_price":1800,"is_active":true},{"product_key":"template:reading-room","asset_id":"reading-room","kind":"template","title":"문장을 모으는 생활","point_price":1800,"is_active":true},{"product_key":"template:first-wardrobe","asset_id":"first-wardrobe","kind":"template","title":"너의 작은 옷장","point_price":1800,"is_active":true},{"product_key":"template:sunday-picnic","asset_id":"sunday-picnic","kind":"template","title":"일요일의 피크닉","point_price":1800,"is_active":true},{"product_key":"template:shared-seasons","asset_id":"shared-seasons","kind":"template","title":"같이 사는 계절","point_price":1800,"is_active":true},{"product_key":"template:little-companion","asset_id":"little-companion","kind":"template","title":"작은 동거인","point_price":1800,"is_active":true}]'::jsonb)
  as s(product_key text, asset_id text, kind text, title text,
       point_price integer, is_active boolean)
on conflict (product_key) do update set
  title = excluded.title,
  point_price = excluded.point_price,
  is_active = excluded.is_active
where (p.title, p.point_price, p.is_active)
  is distinct from (excluded.title, excluded.point_price, excluded.is_active);
commit;

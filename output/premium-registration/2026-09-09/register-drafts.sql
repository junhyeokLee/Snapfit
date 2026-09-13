-- Registration only: no live price, publication, or customer charge.
-- Existing rows, including already configured prices, are never overwritten.
insert into public.point_shop_products
  (product_key, asset_id, kind, title, point_price, is_active)
select product_key, asset_id, kind, title, null, false
from jsonb_to_recordset('[{"product_key":"template:vow-keepsake","asset_id":"vow-keepsake","kind":"template","title":"약속을 묶은 책"},{"product_key":"template:luminous-edition","asset_id":"luminous-edition","kind":"template","title":"둘만의 여행"},{"product_key":"template:daily-cabinet","asset_id":"daily-cabinet","kind":"template","title":"하루의 수집함"},{"product_key":"template:first-year-keepsake","asset_id":"first-year-keepsake","kind":"template","title":"너의 첫 계절"},{"product_key":"template:table-stories","asset_id":"table-stories","kind":"template","title":"우리 집 식탁"},{"product_key":"template:two-tickets","asset_id":"two-tickets","kind":"template","title":"둘이 모은 장면"},{"product_key":"template:walk-and-nap","asset_id":"walk-and-nap","kind":"template","title":"산책하고 낮잠"}]'::jsonb)
  as draft(product_key text, asset_id text, kind text, title text)
on conflict (product_key) do nothing
returning product_key, title, point_price, is_active;

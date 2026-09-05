-- Profit-safe adjustment for high-quality hybrid AI album pricing.
--
-- SNAPFIT_AI_DRAFT_HYBRID_COST = 700 points.
-- Native-store consumables balance user value with stronger margins:
-- - snapfit_points_2500  / 2,200 KRW  => 3 high-quality AI drafts + 400P
-- - snapfit_points_8000  / 5,900 KRW  => 11 high-quality AI drafts + 300P
-- - snapfit_points_18000 / 11,900 KRW => 25 high-quality AI drafts + 500P

update public.point_products
set is_active = false
where product_id in (
  'snapfit_points_1500',
  'snapfit_points_4500',
  'snapfit_points_10000',
  'snapfit_points_3500',
  'snapfit_points_11000',
  'snapfit_points_25000'
);

insert into public.point_products(product_id, title, points, amount, currency, provider, is_active) values
  ('snapfit_points_2500', 'SnapFit 2,500 포인트', 2500, 2200, 'KRW', 'APP_STORE_GOOGLE_PLAY', true),
  ('snapfit_points_8000', 'SnapFit 8,000 포인트', 8000, 5900, 'KRW', 'APP_STORE_GOOGLE_PLAY', true),
  ('snapfit_points_18000', 'SnapFit 18,000 포인트', 18000, 11900, 'KRW', 'APP_STORE_GOOGLE_PLAY', true)
on conflict (product_id) do update set
  title = excluded.title,
  points = excluded.points,
  amount = excluded.amount,
  currency = excluded.currency,
  provider = excluded.provider,
  is_active = excluded.is_active;

create or replace function public.ai_album_draft_point_cost()
returns integer
language sql stable
as $$
  select 700;
$$;

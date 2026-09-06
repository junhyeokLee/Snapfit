-- Adjust high-quality hybrid AI pricing so point packages feel generous while
-- keeping enough margin for OpenAI Vision + Claude curation, retries, storage,
-- and store fees.
--
-- SNAPFIT_AI_DRAFT_HYBRID_COST = 700 points.
-- Suggested native-store consumables:
-- - snapfit_points_3500  / 2,200 KRW  => 5 high-quality AI drafts
-- - snapfit_points_11000 / 5,900 KRW  => 15 high-quality AI drafts + buffer
-- - snapfit_points_25000 / 11,900 KRW => 35 high-quality AI drafts + buffer

update public.point_products
set is_active = false
where product_id in (
  'snapfit_points_1500',
  'snapfit_points_4500',
  'snapfit_points_10000'
);

insert into public.point_products(product_id, title, points, amount, currency, provider, is_active) values
  ('snapfit_points_3500', 'SnapFit 3,500 포인트', 3500, 2200, 'KRW', 'APP_STORE_GOOGLE_PLAY', true),
  ('snapfit_points_11000', 'SnapFit 11,000 포인트', 11000, 5900, 'KRW', 'APP_STORE_GOOGLE_PLAY', true),
  ('snapfit_points_25000', 'SnapFit 25,000 포인트', 25000, 11900, 'KRW', 'APP_STORE_GOOGLE_PLAY', true)
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

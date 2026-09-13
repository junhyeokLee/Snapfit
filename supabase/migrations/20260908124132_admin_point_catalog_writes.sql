-- The protected admin-ops endpoint uses service_role only after administrator
-- authentication. Permit catalog configuration without granting ownership,
-- ledger, deletion, identity rewriting or payment privileges.
grant insert (product_key, asset_id, kind, title, point_price, is_active)
  on public.point_shop_products to service_role;
grant update (title, point_price, is_active)
  on public.point_shop_products to service_role;

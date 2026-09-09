import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';

/// Explicit owner-approved catalog update. Exporting does not execute SQL.
List<Map<String, dynamic>> pointShopPriceApplicationRows() {
  final known = {for (final p in pointShopKnownProducts) p.productKey: p};
  return [
    for (final entry in pointShopLaunchPrices.entries)
      {
        'product_key': entry.key,
        'asset_id': known[entry.key]!.assetId,
        'kind': known[entry.key]!.kind,
        'title': known[entry.key]!.title,
        'point_price': entry.value.points,
        'is_active': !isPendingTemplateProduct(entry.key),
      },
  ];
}

String pointShopPriceApplicationSql(List<Map<String, dynamic>> rows) {
  final json = jsonEncode(rows).replaceAll("'", "''");
  return '''-- Owner-approved prices: $pointShopPricingRevision.
-- Only the explicit keys below change. Wallets and ownership are untouched.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
do \$check\$
begin
  if exists (
    select 1 from public.point_shop_products p
    join jsonb_to_recordset('$json'::jsonb)
      as s(product_key text, asset_id text, kind text, is_active boolean)
      on s.product_key = p.product_key
    where p.kind <> s.kind or p.asset_id <> s.asset_id
      or (s.kind = 'template' and not s.is_active and p.is_active)
  ) then
    raise exception 'catalog_identity_or_active_template_changed';
  end if;
end
\$check\$;
insert into public.point_shop_products as p
  (product_key, asset_id, kind, title, point_price, is_active)
select product_key, asset_id, kind, title, point_price, is_active
from jsonb_to_recordset('$json'::jsonb)
  as s(product_key text, asset_id text, kind text, title text,
       point_price integer, is_active boolean)
on conflict (product_key) do update set
  title = excluded.title,
  point_price = excluded.point_price,
  is_active = excluded.is_active
where (p.title, p.point_price, p.is_active)
  is distinct from (excluded.title, excluded.point_price, excluded.is_active);
commit;
''';
}

String pointShopPriceVerificationSql(List<Map<String, dynamic>> rows) {
  final json = jsonEncode(rows).replaceAll("'", "''");
  return '''select s.product_key, p.point_price, p.is_active,
  p.product_key is not null and
    (p.kind, p.asset_id, p.title, p.point_price, p.is_active) is not distinct from
    (s.kind, s.asset_id, s.title, s.point_price, s.is_active) as matches_expected,
  public.get_point_shop_access(s.product_key) as access
from jsonb_to_recordset('$json'::jsonb)
  as s(product_key text, asset_id text, kind text, title text,
       point_price integer, is_active boolean)
left join public.point_shop_products p on p.product_key = s.product_key
order by s.product_key;
''';
}

Map<String, dynamic> exportPriceApplication(Directory output) {
  final rows = pointShopPriceApplicationRows();
  final data = <String, dynamic>{
    'revision': pointShopPricingRevision,
    'targetProject': 'rrbhxdtriummqpztpjrk',
    'status': 'prepared-not-executed',
    'changesWallets': false,
    'grantsIncludedMaterials': false,
    'rows': rows,
  };
  output.createSync(recursive: true);
  File(
    '${output.path}/application.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  File(
    '${output.path}/apply-prices.sql',
  ).writeAsStringSync(pointShopPriceApplicationSql(rows));
  File(
    '${output.path}/verify-prices.sql',
  ).writeAsStringSync(pointShopPriceVerificationSql(rows));
  return data;
}

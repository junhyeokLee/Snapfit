import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_catalog_release.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';

/// Explicit owner-approved catalog update. Exporting does not execute SQL.
List<Map<String, dynamic>> pointShopPriceApplicationRows() {
  final known = {for (final p in pointShopKnownProducts) p.productKey: p};
  for (final key in pointShopLaunchPrices.keys) {
    if (!known.containsKey(key)) {
      throw StateError('Missing product metadata: $key');
    }
  }
  return [
    for (final entry in pointShopLaunchPrices.entries)
      {
        'product_key': entry.key,
        'asset_id': known[entry.key]!.assetId,
        'kind': known[entry.key]!.kind,
        'title': known[entry.key]!.title,
        'point_price': entry.value.points,
        'is_active':
            !isPendingTemplateProduct(entry.key) &&
            !isPendingAtelierMaterialProduct(entry.key),
      },
  ];
}

/// Development-only gate for the complete published catalog. It reads metadata,
/// never renders artwork, grants ownership, or substitutes client purchase prices.
void validatePointShopCatalogRelease(List<Map<String, dynamic>> rows) {
  final known = {for (final p in pointShopKnownProducts) p.productKey: p};
  final tiers = <String, bool>{
    for (final template in publishedCreationTemplates)
      pointShopTemplateKey(template): template.isPremium,
    for (final edition in storyEditions)
      for (final key in edition.materialKeys) key: edition.isPremium,
  };
  final expected = {
    ...pointShopLaunchPrices.keys,
    ...tiers.keys,
    // Shared frames keep their own price tier, rather than inheriting the
    // containing book's premium flag. They must still be registered and live.
    for (final edition in storyEditions) ...edition.includedMaterialKeys,
  };
  final seen = <String>{};
  final issues = <String>[];
  for (final row in rows) {
    final key = row['product_key'];
    if (key is! String || key.isEmpty) {
      issues.add('invalid_product_key');
      continue;
    }
    if (!seen.add(key)) issues.add('duplicate_product: $key');
    final product = known[key];
    if (product == null || !expected.contains(key)) {
      issues.add('unregistered_product: $key');
    } else if (row['asset_id'] != product.assetId ||
        row['kind'] != product.kind ||
        key != '${product.kind}:${product.assetId}') {
      issues.add('identity_mismatch: $key');
    }
    if (row['title'] is! String || (row['title'] as String).trim().isEmpty) {
      issues.add('missing_title: $key');
    }
    final price = row['point_price'];
    if (price is! int || price < 0) {
      issues.add('invalid_price: $key');
    } else {
      final scheduled = pointShopLaunchPrices[key];
      if (scheduled == null) {
        issues.add('missing_price: $key');
      } else if (price != scheduled.points) {
        issues.add('price_mismatch: $key');
      }
      if (pointShopRequiresFreePrice(key) || tiers[key] == false) {
        if (price != 0) issues.add('free_product_priced: $key');
      } else if (tiers[key] == true && price == 0) {
        issues.add('paid_product_unpriced: $key');
      }
    }
    if (row['is_active'] != true) issues.add('inactive_product: $key');
  }
  for (final key in expected.difference(seen)) {
    issues.add('missing_product: $key');
  }
  if (issues.isNotEmpty) {
    throw StateError('Catalog release incomplete:\n${issues.join('\n')}');
  }
}

String pointShopPriceApplicationSql(
  List<Map<String, dynamic>> rows, {
  bool protectPaidPrices = false,
  bool activateOnly = false,
}) {
  final selected = activateOnly
      ? rows.where((row) => row['is_active'] == true).toList()
      : rows;
  final json = jsonEncode(selected).replaceAll("'", "''");
  final paidPriceGuard = protectPaidPrices || activateOnly
      ? '''
  if exists (
    select 1 from public.point_shop_products p
    join jsonb_to_recordset('$json'::jsonb)
      as s(product_key text, point_price integer)
      on s.product_key = p.product_key
    where s.point_price = 0 and p.point_price > 0
  ) then
    raise exception 'free_catalog_paid_price_conflict';
  end if;
  if exists (
    select 1 from public.point_shop_products p
    join jsonb_to_recordset('$json'::jsonb)
      as s(product_key text, point_price integer)
      on s.product_key = p.product_key
    where s.point_price > 0 and p.point_price = 0
  ) then
    raise exception 'paid_catalog_free_price_conflict';
  end if;
'''
      : '';
  final update = activateOnly
      ? '''point_price = coalesce(p.point_price, excluded.point_price),
  is_active = true
where not p.is_active;'''
      : '''title = excluded.title,
  point_price = excluded.point_price,
  is_active = excluded.is_active
where (p.title, p.point_price, p.is_active)
  is distinct from (excluded.title, excluded.point_price, excluded.is_active);''';
  return '''-- Owner-approved prices: $pointShopPricingRevision.
-- Only the explicit keys below change. Wallets and ownership are untouched.
${activateOnly ? '-- Activation only: existing configured prices and active listings are preserved.\n' : ''}begin;
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
      or (not s.is_active and p.is_active)
  ) then
    raise exception 'catalog_identity_or_active_template_changed';
  end if;
$paidPriceGuard
end
\$check\$;
insert into public.point_shop_products as p
  (product_key, asset_id, kind, title, point_price, is_active)
select product_key, asset_id, kind, title, point_price, is_active
from jsonb_to_recordset('$json'::jsonb)
  as s(product_key text, asset_id text, kind text, title text,
       point_price integer, is_active boolean)
on conflict (product_key) do update set
  $update
commit;
''';
}

String pointShopActivationVerificationSql(List<Map<String, dynamic>> rows) {
  final approved = rows.where((row) => row['is_active'] == true).toList();
  final json = jsonEncode(approved).replaceAll("'", "''");
  return '''select s.product_key, p.point_price, p.is_active,
  p.product_key is not null and p.kind = s.kind and p.asset_id = s.asset_id
    and p.is_active and p.point_price is not null
    and case when s.point_price = 0 then p.point_price = 0
      else p.point_price > 0 end as matches_expected
from jsonb_to_recordset('$json'::jsonb)
  as s(product_key text, asset_id text, kind text, point_price integer)
left join public.point_shop_products p on p.product_key = s.product_key
order by s.product_key;
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
  // Fail before writing release files if any published product remains pending.
  validatePointShopCatalogRelease(rows);
  final data = <String, dynamic>{
    'revision': pointShopPricingRevision,
    'targetProject': 'rrbhxdtriummqpztpjrk',
    'status': 'prepared-not-executed',
    'ownerApprovalRevision': pointShopCatalogApprovalRevision,
    'previouslyHeldProductKeys': ownerApprovedCatalogProductKeys.toList()
      ..sort(),
    'activeProductCount': rows.where((row) => row['is_active'] == true).length,
    'remoteVerified': false,
    'activationPreservesConfiguredPrices': true,
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
  File(
    '${output.path}/activate-products.sql',
  ).writeAsStringSync(pointShopPriceApplicationSql(rows, activateOnly: true));
  File(
    '${output.path}/verify-activation.sql',
  ).writeAsStringSync(pointShopActivationVerificationSql(rows));
  return data;
}

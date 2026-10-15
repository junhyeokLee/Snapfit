import 'dart:convert';
import 'dart:io';

import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'export_price_application.dart';

/// Prepared release only. It never executes SQL or changes paid product prices.
Map<String, dynamic> exportFreeMaterialPolicy(Directory output) {
  final rows = pointShopPriceApplicationRows()
      .where((row) => pointShopRequiresFreePrice(row['product_key'] as String))
      .toList();
  for (final row in rows) {
    if (row['point_price'] != 0 || row['is_active'] != true) {
      throw StateError('invalid_free_material_price:${row['product_key']}');
    }
  }
  final collections = [
    for (final collection in authoredCollections)
      {
        'id': collection.id,
        'title': collection.title,
        'category': collection.category,
        'coverTreatment':
            collection.document(CollectionAspect.square)['coverTreatment'] ??
            'composed',
        'materialKeys': templateVisualMaterialKeys(
          collection.catalogDocument(),
        ).toList()..sort(),
        'issues': freeTemplateMaterialIssues(
          collection.catalogDocument(),
        ).toList(),
      },
  ];
  if (collections.any((book) => (book['issues'] as List).isNotEmpty)) {
    throw StateError('free_material_release_validation_failed');
  }
  final data = {
    'revision': freeTemplateMaterialPolicyRevision,
    'pricingRevision': pointShopPricingRevision,
    'targetProject': 'rrbhxdtriummqpztpjrk',
    'status': 'prepared-not-executed',
    'changesPaidProducts': false,
    'changesWallets': false,
    'grantsOwnership': false,
    'rows': rows,
    'collections': collections,
  };
  output.createSync(recursive: true);
  File(
    '${output.path}/manifest.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  File('${output.path}/apply-free-catalog.sql').writeAsStringSync(
    pointShopPriceApplicationSql(rows, protectPaidPrices: true),
  );
  File(
    '${output.path}/verify-free-catalog.sql',
  ).writeAsStringSync(pointShopPriceVerificationSql(rows));
  return data;
}

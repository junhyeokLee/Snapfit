import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';

import '../../tool/template_studio/export_price_application.dart';

void main() {
  test('export only the fourteen complete diversity books and their kits', () {
    final all = pointShopPriceApplicationRows();
    validatePointShopCatalogRelease(all);
    final editions = [...hobbyExpansionEditions, ...milestoneExpansionEditions];
    final keys = {
      for (final edition in editions) ...{
        edition.productKey,
        ...edition.includedMaterialKeys,
      },
    };
    final rows = all.where((row) => keys.contains(row['product_key'])).toList()
      ..sort(
        (a, b) =>
            (a['product_key'] as String).compareTo(b['product_key'] as String),
      );
    expect(editions, hasLength(14));
    expect(keys, hasLength(70));
    expect(rows, hasLength(70));
    expect(rows.where((r) => r['point_price'] == 0), hasLength(25));
    expect(rows.every((r) => r['is_active'] == true), isTrue);
    final output = File('output/diversity-expansion-20261103/price-rows.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  }, skip: !const bool.fromEnvironment('EXPORT_DIVERSITY_RELEASE'));
}

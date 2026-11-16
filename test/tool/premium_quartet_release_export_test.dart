import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';

import '../../tool/template_studio/export_price_application.dart';

void main() {
  test('export all44 premium quartets and their352 independent materials', () {
    final all = pointShopPriceApplicationRows();
    validatePointShopCatalogRelease(all);
    final keys = {
      for (final book in premiumQuartetEditions) book.productKey,
      for (final book in premiumQuartetEditions) ...book.includedMaterialKeys,
    };
    final rows = all.where((r) => keys.contains(r['product_key'])).toList()
      ..sort(
        (a, b) =>
            (a['product_key'] as String).compareTo(b['product_key'] as String),
      );
    expect(premiumQuartetEditions, hasLength(44));
    expect(keys, hasLength(396));
    expect(rows, hasLength(396));
    expect(
      rows.every(
        (r) => r['is_active'] == true && (r['point_price'] as int) > 0,
      ),
      isTrue,
    );
    final root = Directory('output/premium-four-per-topic-20261103')
      ..createSync(recursive: true);
    File(
      '${root.path}/price-rows.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    File(
      '${root.path}/complete-price-rows.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all));
  }, skip: !const bool.fromEnvironment('EXPORT_PREMIUM_QUARTET_RELEASE'));
}

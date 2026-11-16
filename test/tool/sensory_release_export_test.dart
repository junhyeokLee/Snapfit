import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import '../../tool/template_studio/export_price_application.dart';

void main() {
  test('export only the delivered sensory collection product rows', () {
    final all = pointShopPriceApplicationRows();
    validatePointShopCatalogRelease(all);
    final keys = {
      for (final e in sensoryStoryEditions) e.productKey,
      for (final e in sensoryStoryEditions) ...e.includedMaterialKeys,
    };
    final rows = all.where((r) => keys.contains(r['product_key'])).toList()
      ..sort(
        (a, b) =>
            (a['product_key'] as String).compareTo(b['product_key'] as String),
      );
    expect(rows, hasLength(18));
    expect(rows.where((r) => r['point_price'] == 0), hasLength(10));
    final out = File('output/sensory-editions-20261103/price-rows.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  }, skip: !const bool.fromEnvironment('EXPORT_SENSORY_RELEASE'));
}

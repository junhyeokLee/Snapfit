import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';

import '../../tool/template_studio/export_price_application.dart';

void main() {
  test(
    'export the exact four free reading products after the release gate',
    () {
      final all = pointShopPriceApplicationRows();
      validatePointShopCatalogRelease(all);
      final edition = readingStoryEditions.single;
      final keys = {edition.productKey, ...edition.materialKeys};
      final rows = all.where((r) => keys.contains(r['product_key'])).toList()
        ..sort(
          (a, b) => (a['product_key'] as String).compareTo(
            b['product_key'] as String,
          ),
        );
      expect(rows, hasLength(4));
      expect(
        rows.every((r) => r['point_price'] == 0 && r['is_active'] == true),
        isTrue,
      );
      final output = File('output/reading-edition-20261103/price-rows.json');
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(rows),
      );
    },
    skip: !const bool.fromEnvironment('EXPORT_READING_RELEASE'),
  );
}

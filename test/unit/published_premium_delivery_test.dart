import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import '../../tool/template_studio/export_price_application.dart';

void main() {
  test(
    'all paid editions deliver complete native pages in all three sizes',
    () {
      final keys = <String>{};
      for (final template in publishedPremiumTemplates) {
        expect(keys.add(pointShopTemplateKey(template)), true);
        final volume = publishedPremiumVolume(template.id);
        final editions = volume == null
            ? [jsonDecode(template.templateJson!) as Map<String, dynamic>]
            : [
                for (final count in volume.pageCounts)
                  premiumCatalogDocument(volume, innerPages: count),
              ];
        for (final edition in editions) {
          final count = edition['innerPageCount'] as int;
          for (final aspect in CollectionAspect.values) {
            final document =
                edition['variants'][aspect.name] as Map<String, dynamic>;
            final pages = templateDocumentPages(document);
            expect(pages, hasLength(count + 1));
            for (final page in pages) {
              final layers = page['layers'] as List;
              expect(layers, isNotEmpty);
              final parsed = DataTemplateEngine.buildLayersFromJson({
                'strictLayout': true,
                'designWidth': document['designWidth'],
                'designHeight': document['designHeight'],
                'layers': layers,
              }, aspect.canvas);
              expect(parsed, hasLength(layers.length));
              for (final layer in layers) {
                final image = layer['imageUrl'];
                if (image is String && image.startsWith('asset:')) {
                  expect(
                    File(image.substring(6)).existsSync(),
                    true,
                    reason: image,
                  );
                }
              }
            }
          }
        }
      }
      expect(keys, hasLength(26));
    },
  );

  test('owner-approved sale registration includes every delivered edition', () {
    final keys = publishedPremiumTemplates.map(pointShopTemplateKey).toSet();
    final rows = pointShopPriceApplicationRows()
        .where((row) => keys.contains(row['product_key']))
        .toList();
    expect(rows, hasLength(26));
    expect(rows.where((row) => row['point_price'] == 2500), hasLength(7));
    expect(rows.where((row) => row['point_price'] == 1800), hasLength(7));
    expect(rows.where((row) => row['point_price'] == 2800), hasLength(12));
    expect(rows.where((row) => row['is_active'] == true), hasLength(26));
    expect(rows.where((row) => row['is_active'] == false), isEmpty);
    if (const bool.fromEnvironment('EXPORT_PREMIUM_SALE')) {
      final out = Directory('output/premium-registration/sale-2026-10-18')
        ..createSync(recursive: true);
      File(
        '${out.path}/apply.sql',
      ).writeAsStringSync(pointShopPriceApplicationSql(rows));
      File(
        '${out.path}/verify.sql',
      ).writeAsStringSync(pointShopPriceVerificationSql(rows));
    }
  });
}

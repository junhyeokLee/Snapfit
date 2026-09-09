import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';

import '../../tool/template_studio/export_premium_registration.dart';

void main() {
  test('seven drafts do not publish or reprice the existing catalog', () {
    expect(pendingPremiumVolumeProducts, hasLength(7));
    expect(
      pendingPremiumVolumeProducts.map((p) => p.productKey).toSet(),
      hasLength(7),
    );
    for (final product in pendingPremiumVolumeProducts) {
      expect(product.pointPrice, isNull);
      expect(product.isActive, false);
      final volume = pendingPremiumVolumeForKey(product.productKey)!;
      expect(product.title, volume.title);
      expect(product.assetId, volume.id);
      expect(
        bundledCreationTemplates.any((p) => p.title == volume.title),
        false,
      );
    }
    expect(bundledCreationTemplates, hasLength(37));
    expect(pendingPremiumVolumeForKey('template:lightbound'), isNull);
    expect(pendingPremiumVolumeForKey('template:server-1'), isNull);
    expect(pendingConceptVolumeProducts, hasLength(7));
    for (final product in pendingConceptVolumeProducts) {
      expect(product.pointPrice, isNull);
      expect(product.isActive, false);
      expect(
        pendingConceptVolumeForKey(product.productKey)!.id,
        product.assetId,
      );
      expect(isPendingTemplateProduct(product.productKey), true);
      expect(
        bundledCreationTemplates.any((p) => p.title == product.title),
        false,
      );
    }
    expect(isPendingTemplateProduct('template:lightbound'), false);
    expect(pendingTemplateContentsLabel('template:lightbound'), isNull);
  });

  test('registration SQL cannot activate, price or overwrite products', () {
    final sql = premiumVolumeDraftSql();
    expect(sql, contains('kind, title, null, false'));
    expect(sql, contains('on conflict (product_key) do nothing'));
    expect(sql.toLowerCase(), isNot(contains('do update')));
    expect(sql, isNot(contains('2500')));
    expect(sql, isNot(contains('template:lightbound')));
    for (final product in pendingPremiumVolumeProducts) {
      expect(sql, contains('"product_key":"${product.productKey}"'));
      expect(sql, contains('"title":"${product.title}"'));
    }
  });

  test('delivery package contains all 36 documents and 1044 native pages', () {
    const export = bool.fromEnvironment('EXPORT_REGISTRATION');
    final output = export
        ? Directory('output/premium-registration/2026-09-09')
        : Directory.systemTemp.createTempSync('snapfit-registration-');
    if (!export) addTearDown(() => output.deleteSync(recursive: true));
    final manifest = exportPremiumRegistration(output);
    final products = (manifest['products'] as List).cast<Map>();
    expect(products, hasLength(7));
    var documents = 0;
    var pages = 0;
    for (final product in products) {
      expect(product['pointPrice'], isNull);
      expect(product['launchPointPrice'], 2500);
      expect(product['releaseGates']['price'], 'launch-price-set-sale-held');
      expect(product['isActive'], false);
      expect(product['localAssets'], isNotEmpty);
      expect(product['fontFamilies'], isNotEmpty);
      expect(
        product['releaseGates']['distributionRights'],
        'pending-asset-and-font-review',
      );
      for (final edition in product['editions'] as List) {
        final document =
            jsonDecode(
                  File(
                    '${output.path}/${edition['document']}',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final content = templateDocumentPages(document);
        expect(content.length, (edition['innerPages'] as int) + 1);
        expect(document['catalogPublishable'], false);
        expect(document['approvalStatus'], 'approved-volume-design');
        documents++;
        pages += content.length;
      }
    }
    expect(documents, 36);
    expect(pages, 1044);
  });
}

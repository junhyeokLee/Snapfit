import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import '../../tool/template_studio/export_launch_pricing.dart';
import '../../tool/template_studio/export_price_application.dart';

void main() {
  test(
    'price book covers 83 materials, 37 free and 14 premium collections',
    () {
      final expected = {
        ...[
          ...conceptWaveDecorations,
          ...keepsakeDecorations,
          ...atelierCompositionDecorations,
        ].map((s) => 'sticker:${s.id}'),
        ...[
          ...keepsakePhotoFrames,
          ...atelierEditionPhotoFrames,
        ].map((s) => 'frame:$s'),
        ...atelierWordArts.map((a) => a.productKey),
        ...pendingPremiumVolumeProducts.map((p) => p.productKey),
        ...pendingConceptVolumeProducts.map((p) => p.productKey),
        ...authoredCollections.map(pointShopAuthoredTemplateKey),
      };
      expect(expected, hasLength(134));
      expect(pointShopLaunchPrices.keys.toSet(), expected);
      expect(
        pointShopLaunchPrices.values.where((p) => p.points == 0),
        hasLength(49),
      );
      for (final e in pointShopLaunchPrices.entries) {
        expect(e.value.reason, isNotEmpty);
        expect({0, 100, 200, 300, 400, 1800, 2500}, contains(e.value.points));
        final product = pointShopKnownProducts.singleWhere(
          (p) => p.productKey == e.key,
        );
        expect(
          product.pointPrice,
          isNull,
          reason: 'Launch schedule must not become live fallback pricing',
        );
        expect(product.isActive, false);
      }
      expect(pointShopLaunchPrices['template:lightbound']!.points, 0);
      expect(pointShopLaunchPrices['frame:atelier-not-reviewed'], isNull);
      expect(pointShopLaunchPrices['phrase:collage-bold-cut'], isNull);
      expect(() => pointShopLaunchPrices.clear(), throwsUnsupportedError);
    },
  );

  test(
    'native editions share one collection price without per-size charges',
    () {
      for (final product in pendingPremiumVolumeProducts) {
        expect(pointShopLaunchPrices[product.productKey]!.points, 2500);
        final volume = pendingPremiumVolumeForKey(product.productKey)!;
        for (final count in volume.pageCounts) {
          expect(pointShopLaunchPrices['${product.productKey}:$count'], isNull);
        }
      }
      for (final product in pendingConceptVolumeProducts) {
        expect(pointShopLaunchPrices[product.productKey]!.points, 1800);
        expect(isPendingTemplateProduct(product.productKey), true);
        expect(
          pendingTemplateContentsLabel(product.productKey),
          contains('24쪽'),
        );
      }
    },
  );

  test('export is a schedule, not a payment or publication command', () {
    const export = bool.fromEnvironment('EXPORT_PRICING');
    final out = export
        ? Directory('output/pricing/launch-2026-09-09')
        : Directory.systemTemp.createTempSync('snapfit-prices-');
    if (!export) addTearDown(() => out.deleteSync(recursive: true));
    final result = exportLaunchPricing(out);
    expect(result['changesCustomerAccess'], false);
    expect(result['grantsIncludedMaterials'], false);
    expect(result['marketValidated'], false);
    expect(result['products'], hasLength(134));
    expect(
      jsonDecode(File('${out.path}/prices.json').readAsStringSync()),
      result,
    );
    expect(out.listSync().map((f) => f.path.split('/').last).toSet(), {
      'prices.json',
      'PRICES.md',
    });
    final book = File('${out.path}/PRICES.md').readAsStringSync();
    expect(book, contains('아르데코 계단 창'));
    expect(book, contains('가격 책정 완료, 실제 판매 활성화 전'));
  });

  test('free templates do not require separately paid new materials', () {
    for (final collection in authoredCollections) {
      for (final aspect in CollectionAspect.values) {
        for (final key in templateVisualMaterialKeys(
          collection.document(aspect),
        )) {
          expect(
            pointShopLaunchPrices[key]?.points ?? 0,
            0,
            reason: '${collection.id}/${aspect.name}: $key',
          );
        }
      }
    }
  });

  test(
    'owner application activates materials and free books, but holds premium delivery',
    () {
      final rows = pointShopPriceApplicationRows();
      expect(rows, hasLength(134));
      expect(rows.map((r) => r['product_key']).toSet(), hasLength(134));
      expect(rows.where((r) => r['point_price'] == 0), hasLength(49));
      expect(rows.where((r) => r['is_active'] == true), hasLength(120));
      for (final row in rows) {
        final held =
            row['kind'] == 'template' && (row['point_price'] as int) > 0;
        expect(row['is_active'], !held);
      }
      final sql = pointShopPriceApplicationSql(rows);
      expect(sql, contains('on conflict (product_key) do update'));
      expect(sql, contains('is distinct from'));
      expect(sql, contains('catalog_identity_or_active_template_changed'));
      expect(sql, isNot(contains('point_wallets')));
      expect(sql, isNot(contains('point_shop_ownership')));
      expect(sql.toLowerCase(), isNot(contains('delete from')));
      const export = bool.fromEnvironment('EXPORT_PRICE_APPLICATION');
      final out = export
          ? Directory('output/pricing/catalog-2026-09-10')
          : Directory.systemTemp.createTempSync('snapfit-price-application-');
      if (!export) addTearDown(() => out.deleteSync(recursive: true));
      final data = exportPriceApplication(out);
      expect(data['status'], 'prepared-not-executed');
      expect(data['changesWallets'], false);
      expect(data['rows'], rows);
      expect(File('${out.path}/apply-prices.sql').readAsStringSync(), sql);
      expect(
        File('${out.path}/verify-prices.sql').readAsStringSync(),
        pointShopPriceVerificationSql(rows),
      );
    },
  );
}

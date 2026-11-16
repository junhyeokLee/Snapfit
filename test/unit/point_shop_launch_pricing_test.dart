import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_photo_frame_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_catalog_release.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import '../../tool/template_studio/export_launch_pricing.dart';
import '../../tool/template_studio/export_price_application.dart';

const _refinedFreeWordArts = {
  'bold-cut': (title: '볼드 컷아웃', text: '같이 찍자!'),
  'ticket-label': (title: '티켓 라벨', text: '오늘의 기분 : 맑음'),
  'hand-note': (title: '손글씨 밑줄', text: '다음 장도 함께'),
  'diecut': (title: '겹인쇄 스티커', text: '반짝반짝'),
};

void main() {
  test(
    'price book covers approved catalog without client-side live pricing',
    () {
      final expected = {
        for (final edition in sensoryStoryEditions)
          ...edition.includedMaterialKeys,
        ...freeTemplateMaterialProductKeys,
        ...[
          ...conceptWaveDecorations,
          ...keepsakeDecorations,
          ...atelierCompositionDecorations,
          ...atelierEditionDecorations,
        ].map((s) => 'sticker:${s.id}'),
        ...[
          ...keepsakePhotoFrames,
          ...atelierEditionPhotoFrames,
          ...atelierSignaturePhotoFrames,
          ...atelierStoryPhotoFrames,
        ].map((s) => 'frame:$s'),
        ...atelierWordArts.map((a) => a.productKey),
        ..._refinedFreeWordArts.keys.map((id) => 'phrase:collage-$id'),
        ...storyEditionWordArts.map((a) => a.productKey),
        ...hobbyExpansionWordArts.map((a) => a.productKey),
        ...milestoneExpansionWordArts.map((a) => a.productKey),
        ...storyEditionDecorations.map((a) => 'sticker:${a.id}'),
        ...hobbyExpansionDecorations.map((a) => 'sticker:${a.id}'),
        ...milestoneExpansionDecorations.map((a) => 'sticker:${a.id}'),
        for (final edition in [
          ...hobbyExpansionEditions,
          ...milestoneExpansionEditions,
        ])
          for (final frame in edition.photoFrames) 'frame:$frame',
        for (final edition in premiumQuartetEditions)
          ...edition.includedMaterialKeys,
        ...pendingStoryEditionProducts.map((p) => p.productKey),
        ...pendingPremiumVolumeProducts.map((p) => p.productKey),
        ...pendingConceptVolumeProducts.map((p) => p.productKey),
        ...pendingAtelierEditionProducts.map((p) => p.productKey),
        ...pendingStudioEditionProducts.map((p) => p.productKey),
        ...authoredCollections.map(pointShopAuthoredTemplateKey),
        ...storyEditions.where((e) => !e.isPremium).map((e) => e.productKey),
      };
      expect(expected, hasLength(974));
      expect(pointShopLaunchPrices.keys.toSet(), expected);
      expect(
        pointShopLaunchPrices.values.where((p) => p.points == 0),
        hasLength(156),
      );
      for (final e in pointShopLaunchPrices.entries) {
        expect(e.value.reason, isNotEmpty);
        expect({
          0,
          100,
          150,
          200,
          300,
          400,
          1800,
          2500,
          2800,
        }, contains(e.value.points));
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
      expect(pointShopLaunchPrices['phrase:collage-not-reviewed'], isNull);
      expect(() => pointShopLaunchPrices.clear(), throwsUnsupportedError);
    },
  );

  test('refined starter word art registers free with unchanged identities', () {
    final rows = pointShopPriceApplicationRows();
    for (final entry in _refinedFreeWordArts.entries) {
      final id = entry.key;
      final key = 'phrase:collage-$id';
      final art = studioWordArtById(id)!;
      final product = pointShopKnownProducts.singleWhere(
        (product) => product.productKey == key,
      );
      expect(art.productKey, key);
      expect(art.favoriteKey, 'textStyle:luminous-edition:$id');
      expect(art.insertionValue, 'wordart:$id');
      expect(art.label, entry.value.title);
      expect(art.text, entry.value.text);
      expect(pointShopLaunchPrices[key]!.points, 0);
      expect(pointShopLaunchPrices[key]!.reason, contains('기존 무료'));
      expect(product.pointPrice, isNull, reason: 'no live price fallback');
      expect(product.isActive, isFalse);
      expect(isPendingAtelierMaterialProduct(key), isFalse);
      expect(isPendingTemplateProduct(key), isFalse);
      expect(ownerApprovedCatalogProductKeys, isNot(contains(key)));
      expect(freeTemplateMaterialProductKeys, isNot(contains(key)));
      expect(rows.singleWhere((row) => row['product_key'] == key), {
        'product_key': key,
        'asset_id': 'collage-$id',
        'kind': 'phrase',
        'title': entry.value.title,
        'point_price': 0,
        'is_active': true,
      });
    }
    expect(() => validatePointShopCatalogRelease(rows), returnsNormally);
  });

  test(
    'the new reading book and its three editable materials are all free',
    () {
      const keys = {
        'template:story-reading-room',
        'sticker:story-reading-room-paper',
        'sticker:story-reading-room-motif',
        'phrase:collage-story-reading-room',
      };
      final rows = pointShopPriceApplicationRows();
      expect(
        rows.where((row) => keys.contains(row['product_key'])),
        hasLength(4),
      );
      for (final key in keys) {
        final row = rows.singleWhere((row) => row['product_key'] == key);
        expect(row['point_price'], 0, reason: key);
        expect(row['is_active'], isTrue, reason: key);
        expect(pointShopRequiresFreePrice(key), isTrue, reason: key);
        expect(pointShopLaunchPrices[key]!.points, 0, reason: key);
        expect(ownerApprovedCatalogProductKeys, isNot(contains(key)));
      }
      expect(() => validatePointShopCatalogRelease(rows), returnsNormally);
    },
  );

  test(
    'fourteen new complete books register seventy distinct matching products',
    () {
      const freeIds = {-9772, -9773, -9775, -9781, -9782};
      const publishedIds = {
        -9772,
        -9773,
        -9774,
        -9775,
        -9776,
        -9777,
        -9778,
        -9779,
        -9780,
        -9781,
        -9782,
        -9783,
        -9784,
        -9785,
      };
      final editions = [
        ...hobbyExpansionEditions,
        ...milestoneExpansionEditions,
      ];
      expect(editions.map((e) => e.catalogId).toSet(), publishedIds);
      expect(
        editions.where((e) => !e.isPremium).map((e) => e.catalogId).toSet(),
        freeIds,
      );
      expect(editions.expand((e) => e.photoFrames).toSet(), hasLength(14));
      final rows = pointShopPriceApplicationRows();
      final productKeys = <String>{};
      var freeProducts = 0;
      for (final edition in editions) {
        final free = freeIds.contains(edition.catalogId);
        final keys = {edition.productKey, ...edition.includedMaterialKeys};
        expect(keys, hasLength(5), reason: edition.id);
        for (final key in keys) {
          expect(
            productKeys.add(key),
            isTrue,
            reason: 'New books must have independent kits: $key',
          );
          final row = rows.singleWhere((row) => row['product_key'] == key);
          expect(row['is_active'], isTrue, reason: key);
          expect(row['point_price'], free ? 0 : greaterThan(0), reason: key);
          expect(pointShopRequiresFreePrice(key), free, reason: key);
          if (free) freeProducts++;
        }
        expect(
          pointShopLaunchPrices[edition.productKey]!.points,
          free ? 0 : 1800,
        );
      }
      expect(productKeys, hasLength(70));
      expect(freeProducts, 25);
      expect(() => validatePointShopCatalogRelease(rows), returnsNormally);
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
        expect(isPendingTemplateProduct(product.productKey), false);
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
    expect(result['products'], hasLength(974));
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
      for (final aspect in CollectionAspect.printable) {
        for (final key in templateVisualMaterialKeys(
          collection.document(aspect),
        )) {
          expect(
            pointShopLaunchPrices[key]?.points,
            0,
            reason: '${collection.id}/${aspect.name}: $key',
          );
        }
      }
    }
  });

  test('owner application includes delivered premium books', () {
    final rows = pointShopPriceApplicationRows();
    expect(rows, hasLength(974));
    expect(rows.map((r) => r['product_key']).toSet(), hasLength(974));
    expect(rows.where((r) => r['point_price'] == 0), hasLength(156));
    expect(rows.where((r) => r['is_active'] == true), hasLength(974));
    expect(ownerApprovedCatalogProductKeys, hasLength(733));
    expect(
      ownerApprovedCatalogProductKeys.where(
        (key) => key.startsWith('template:'),
      ),
      hasLength(126),
    );
    expect(
      ownerApprovedCatalogProductKeys.where(
        (key) => !key.startsWith('template:'),
      ),
      hasLength(607),
    );
    for (final key in ownerApprovedCatalogProductKeys) {
      expect(
        rows.singleWhere((row) => row['product_key'] == key)['is_active'],
        true,
      );
      expect(pointShopLaunchPrices[key]!.points, greaterThan(0));
      expect(freeTemplateMaterialProductKeys, isNot(contains(key)));
    }
    for (final row in rows) {
      expect(
        row['is_active'],
        !isPendingTemplateProduct(row['product_key'] as String) &&
            !isPendingAtelierMaterialProduct(row['product_key'] as String),
      );
    }
    final sql = pointShopPriceApplicationSql(rows);
    expect(sql, contains('on conflict (product_key) do update'));
    expect(sql, contains('is distinct from'));
    expect(sql, contains('catalog_identity_or_active_template_changed'));
    expect(sql, isNot(contains('point_wallets')));
    expect(sql, isNot(contains('point_shop_ownership')));
    expect(sql.toLowerCase(), isNot(contains('delete from')));
    final activation = pointShopPriceApplicationSql(rows, activateOnly: true);
    expect(
      activation,
      contains('coalesce(p.point_price, excluded.point_price)'),
    );
    expect(activation, contains('where not p.is_active'));
    expect(activation, contains('free_catalog_paid_price_conflict'));
    expect(activation, isNot(contains('point_wallets')));
    expect(activation, isNot(contains('point_shop_ownership')));
    const export = bool.fromEnvironment('EXPORT_PRICE_APPLICATION');
    final out = export
        ? Directory(
            const String.fromEnvironment(
              'PRICE_APPLICATION_DIRECTORY',
              defaultValue: 'output/pricing/catalog-2026-10-25',
            ),
          )
        : Directory.systemTemp.createTempSync('snapfit-price-application-');
    if (!export) addTearDown(() => out.deleteSync(recursive: true));
    final data = exportPriceApplication(out);
    expect(data['status'], 'prepared-not-executed');
    expect(data['remoteVerified'], false);
    expect(data['activeProductCount'], 974);
    expect(data['ownerApprovalRevision'], pointShopCatalogApprovalRevision);
    expect(data['activationPreservesConfiguredPrices'], true);
    expect(data['changesWallets'], false);
    expect(data['rows'], rows);
    expect(File('${out.path}/apply-prices.sql').readAsStringSync(), sql);
    expect(
      File('${out.path}/activate-products.sql').readAsStringSync(),
      activation,
    );
    expect(
      File('${out.path}/verify-prices.sql').readAsStringSync(),
      pointShopPriceVerificationSql(rows),
    );
  });
}

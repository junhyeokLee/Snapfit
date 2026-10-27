import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';

import '../../tool/template_studio/export_price_application.dart';

void main() {
  const paidTemplate = 'template:story-club-run-together';
  const freeTemplate = 'template:story-club-photowalk';
  const companionMaterial = 'sticker:story-club-run-together-paper';

  List<Map<String, dynamic>> rows() => [
    for (final row in pointShopPriceApplicationRows()) Map.of(row),
  ];

  Matcher rejects(String issue) => throwsA(
    isA<StateError>().having(
      (e) => e.message,
      'release issue',
      contains(issue),
    ),
  );

  test('every published template and its release rows are ready', () {
    final products = rows();
    expect(() => validatePointShopCatalogRelease(products), returnsNormally);
    final keys = products.map((r) => r['product_key']).toSet();
    expect(
      keys,
      containsAll(publishedCreationTemplates.map(pointShopTemplateKey)),
    );
  });

  for (final key in [
    paidTemplate,
    freeTemplate,
    companionMaterial,
    'frame:studioPhotoCorners',
  ]) {
    test('release fails when a published product is omitted: $key', () {
      final products = rows()..removeWhere((r) => r['product_key'] == key);
      expect(
        () => validatePointShopCatalogRelease(products),
        rejects('missing_product: $key'),
      );
    });
  }

  test('priced templates cannot silently remain on sale hold', () {
    final products = rows();
    products.singleWhere((r) => r['product_key'] == paidTemplate)['is_active'] =
        false;
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('inactive_product: $paidTemplate'),
    );
  });

  for (final price in <Object?>[null, -1, 1800.5, '1800']) {
    test('a missing or invalid price fails release: $price', () {
      final products = rows();
      products.singleWhere(
        (r) => r['product_key'] == paidTemplate,
      )['point_price'] = price;
      expect(
        () => validatePointShopCatalogRelease(products),
        rejects('invalid_price: $paidTemplate'),
      );
    });
  }

  test('paid products cannot be released as free', () {
    final products = rows();
    products.singleWhere(
      (r) => r['product_key'] == paidTemplate,
    )['point_price'] = 0;
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('paid_product_unpriced: $paidTemplate'),
    );
  });

  test('free products cannot be released with a charge', () {
    final products = rows();
    products.singleWhere(
      (r) => r['product_key'] == freeTemplate,
    )['point_price'] = 1800;
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('free_product_priced: $freeTemplate'),
    );
  });

  test('registration must use the configured price and stable identity', () {
    final products = rows();
    final product = products.singleWhere(
      (r) => r['product_key'] == paidTemplate,
    );
    product['point_price'] = 2500;
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('price_mismatch: $paidTemplate'),
    );
    product['point_price'] = 1800;
    product['asset_id'] = 'another-template';
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('identity_mismatch: $paidTemplate'),
    );
  });

  test('duplicated and unknown products cannot pass the release check', () {
    final products = rows();
    products.add(Map.of(products.first));
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('duplicate_product: ${products.first['product_key']}'),
    );
    products.removeLast();
    products.add({
      'product_key': 'template:unregistered-draft',
      'asset_id': 'unregistered-draft',
      'kind': 'template',
      'title': 'Unregistered draft',
      'point_price': 1800,
      'is_active': true,
    });
    expect(
      () => validatePointShopCatalogRelease(products),
      rejects('unregistered_product: template:unregistered-draft'),
    );
  });
}

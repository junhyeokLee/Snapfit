import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

void main() {
  test(
    'store and creation/editor share one key for every authored collection',
    () {
      final byId = {
        for (final collection in authoredCollections)
          collection.bundledId: collection,
      };
      for (final template in bundledCreationTemplates) {
        expect(
          pointShopTemplateKey(template),
          pointShopAuthoredTemplateKey(byId[template.id]!),
        );
        expect(template.tags, isNot(contains('무료')));
      }
      expect(
        pointShopTemplateKey(bundledCreationTemplates.first),
        'template:lightbound',
      );
      const server = PremiumTemplate(
        id: 42,
        title: 'Server',
        coverImageUrl: '',
        previewImages: [],
        pageCount: 2,
        userCount: 0,
      );
      expect(pointShopTemplateKey(server), 'template:server-42');
    },
  );

  test(
    'known product identities are unique, case preserving and never seeded paid',
    () {
      final keys = pointShopKnownProducts
          .map((item) => item.productKey)
          .toSet();
      expect(keys.length, pointShopKnownProducts.length);
      expect(
        keys,
        containsAll([
          'sticker:studioCottonRag',
          'frame:studyArchWindow',
          'phrase:vow-day',
        ]),
      );
      expect(
        pointShopKnownProducts.every(
          (item) => item.pointPrice == null && !item.isActive,
        ),
        isTrue,
      );
    },
  );

  test(
    'approved materials are discoverable without publishing candidate albums',
    () {
      final keys = pointShopKnownProducts
          .map((item) => item.productKey)
          .toSet();
      expect(
        keys,
        containsAll([
          'frame:editionLace',
          'frame:zineContact',
          'sticker:zineCamera',
          'sticker:luminousRibbon',
          'phrase:collage-bold-cut',
        ]),
      );
      expect(keys, isNot(contains('template:luminous-edition')));
      for (final collection in retiredAuthoredCollections) {
        expect(keys, isNot(contains(pointShopAuthoredTemplateKey(collection))));
      }
      expect(keys, isNot(contains('frame:')));
    },
  );
}

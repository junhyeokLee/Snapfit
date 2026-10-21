import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import '../../tool/template_studio/export_free_material_policy.dart';

Map<String, dynamic> documentWith(Map<String, dynamic> layer) => {
  'id': 'policy-fixture',
  'cover': {
    'layers': [layer],
  },
  'pages': <Map<String, dynamic>>[],
};

void main() {
  test(
    'free release only configures free products and preserves paid prices',
    () {
      const export = bool.fromEnvironment('EXPORT_FREE_MATERIAL_POLICY');
      final out = export
          ? Directory('output/pricing/free-policy-2026-10-07')
          : Directory.systemTemp.createTempSync('snapfit-free-policy-');
      if (!export) addTearDown(() => out.deleteSync(recursive: true));
      final data = exportFreeMaterialPolicy(out);
      expect(data['status'], 'prepared-not-executed');
      expect(data['changesPaidProducts'], false);
      expect(data['grantsOwnership'], false);
      final rows = (data['rows'] as List).cast<Map>();
      expect(rows, hasLength(93));
      expect(rows.map((r) => r['product_key']).toSet(), hasLength(93));
      expect(rows.every((r) => r['point_price'] == 0), true);
      expect(
        rows.every(
          (r) => pointShopRequiresFreePrice(r['product_key'] as String),
        ),
        true,
      );
      expect(data['collections'], hasLength(42));
      expect(
        jsonDecode(File('${out.path}/manifest.json').readAsStringSync()),
        data,
      );
      final sql = File('${out.path}/apply-free-catalog.sql').readAsStringSync();
      expect(sql, contains('frame:studioGallery'));
      expect(sql, contains('free_catalog_paid_price_conflict'));
      expect(sql, contains('s.point_price = 0 and p.point_price > 0'));
      expect(sql, isNot(contains('frame:atelierDeco')));
      expect(sql, isNot(contains('sticker:materialRose')));
      expect(sql, isNot(contains('template:silk-vows')));
      expect(sql, isNot(contains('point_shop_ownership')));
    },
  );
  test(
    'all 42 free books and every size use only explicitly free materials',
    () {
      final used = <String>{};
      expect(authoredCollections, hasLength(42));
      for (final collection in authoredCollections) {
        final document = collection.catalogDocument();
        expect(
          document['materialPolicyRevision'],
          freeTemplateMaterialPolicyRevision,
        );
        expect(
          freeTemplateMaterialIssues(document),
          isEmpty,
          reason: collection.id,
        );
        used.addAll(templateVisualMaterialKeys(document));
      }
      expect(
        used,
        isEmpty,
        reason:
            'The photo-led free books now use editable photographs, text '
            'and basic paper shapes without priced ornaments.',
      );
      for (final key in used) {
        expect(freeTemplateMaterialProductKeys, contains(key));
        expect(pointShopLaunchPrices[key]?.points, 0, reason: key);
      }
    },
  );

  test(
    'free kit has explicit zero prices and registered stable identities',
    () {
      expect(freeTemplateMaterialProductKeys, hasLength(51));
      for (final key in freeTemplateMaterialProductKeys) {
        expect(pointShopLaunchPrices[key]?.points, 0, reason: key);
        expect(
          pointShopKnownProducts.where((p) => p.productKey == key),
          hasLength(1),
        );
        expect(pointShopRequiresFreePrice(key), true);
      }
      for (final collection in authoredCollections) {
        expect(pointShopRequiresFreePrice('template:${collection.id}'), true);
      }
      expect(pointShopLaunchPrices['frame:atelierDeco']!.points, 400);
      expect(pointShopLaunchPrices['sticker:materialRose']!.points, 300);
      expect(pointShopLaunchPrices['phrase:collage-atelier-vow']!.points, 400);
      expect(pointShopRequiresFreePrice('frame:atelierDeco'), false);
      expect(pointShopRequiresFreePrice('template:silk-vows'), false);
    },
  );

  test('paid frames and their included assets cannot enter a free book', () {
    final document = documentWith({
      'type': 'image',
      'frame': 'materialLaceMount',
    });
    expect(
      freeTemplateMaterialIssues(document),
      containsAll(['frame:materialLaceMount', 'sticker:materialLace']),
    );
    expect(() => validateFreeTemplateMaterials(document), throwsStateError);
  });

  test(
    'saved payloads, image aliases and aspect overrides stay classified',
    () {
      final rose = studioDecorationById('materialRose')!.insertionValue;
      for (final layer in <Map<String, dynamic>>[
        {
          'type': 'IMAGE',
          'payload': {'imageBackground': 'materialLaceMount'},
        },
        {'type': 'image', 'previewUrl': rose},
        {
          'type': 'STICKER',
          'payload': {'originalUrl': rose},
        },
        {
          'type': 'image',
          'frame': 'none',
          'aspectOverrides': {
            'landscape': {'frame': 'signatureRailWallet'},
          },
        },
        {
          'type': 'text',
          'payload': {'textFillImageUrl': rose},
        },
        {
          'type': 'text',
          'style': {'textFillImageUrl': rose},
        },
      ]) {
        final document = documentWith(layer);
        expect(
          freeTemplateMaterialIssues(document),
          isNotEmpty,
          reason: '$layer',
        );
        expect(() => validateFreeTemplateMaterials(document), throwsStateError);
      }
      final saved = documentWith({
        'type': 'IMAGE',
        'payload': {'imageBackground': 'materialLaceMount'},
      });
      expect(
        templateVisualMaterialKeys(saved),
        containsAll(['frame:materialLaceMount', 'sticker:materialLace']),
      );
      final listVariant = {
        ...documentWith({'type': 'text', 'text': '기본 문구'}),
        'variants': [
          {
            ...documentWith({'type': 'image', 'frame': 'signatureRailWallet'}),
            'aspect': 'landscape',
          },
        ],
      };
      expect(
        freeTemplateMaterialIssues(listVariant),
        contains('frame:signatureRailWallet'),
      );
      expect(
        templateVisualMaterialKeys(listVariant),
        contains('frame:signatureRailWallet'),
      );
      expect(
        freeTemplateMaterialIssues({
          'layers': [
            {'type': 'image', 'frame': 'signatureRailWallet'},
          ],
        }),
        contains('frame:signatureRailWallet'),
      );
    },
  );

  test(
    'saved free frames remain free without mutating the source document',
    () {
      final document = documentWith({
        'type': 'IMAGE',
        'payload': {
          'imageBackground': 'studioGallery',
          'previewUrl': 'asset:sample-photo.png',
        },
        'aspectOverrides': {
          'portrait': {
            'payload': {'imageBackground': 'studioPhotoCorners'},
          },
        },
      });
      final before = jsonEncode(document);
      expect(freeTemplateMaterialIssues(document), isEmpty);
      expect(
        templateVisualMaterialKeys(document),
        containsAll(['frame:studioGallery', 'frame:studioPhotoCorners']),
      );
      expect(jsonEncode(document), before);
    },
  );

  test(
    'paid raster and procedural decorations cannot be disguised as photos',
    () {
      for (final id in ['materialRose', 'materialContourMap']) {
        final spec = studioDecorationById(id)!;
        for (final type in ['image', 'sticker', 'decoration']) {
          final document = documentWith({
            'type': type,
            if (spec.assetPath != null) 'imageUrl': spec.insertionValue,
            if (spec.assetPath == null) 'style': id,
          });
          expect(freeTemplateMaterialIssues(document), contains('sticker:$id'));
        }
      }
    },
  );

  test(
    'unreviewed frames, artwork and text styles fail closed in variants',
    () {
      for (final layer in [
        {'type': 'image', 'frame': 'unreviewedFrame'},
        {'type': 'sticker', 'imageUrl': 'asset:assets/new-paid-art.png'},
        {'type': 'decoration', 'style': 'unreviewedPaper'},
        {'type': 'text', 'textFillImageUrl': 'asset:assets/new-paid-fill.png'},
        {'type': 'text', 'wordArtId': 'atelier-vow'},
      ]) {
        final document = {
          ...documentWith({'type': 'text', 'text': '기본 문구'}),
          'variants': {'landscape': documentWith(layer)},
        };
        expect(freeTemplateMaterialIssues(document), isNotEmpty);
        expect(() => validateFreeTemplateMaterials(document), throwsStateError);
      }
    },
  );

  test('ordinary editable photo slots and basic text require no purchase', () {
    expect(
      freeTemplateMaterialIssues(
        documentWith({
          'type': 'image',
          'frame': 'none',
          'imageUrl': 'asset:sample-photo.png',
        }),
      ),
      isEmpty,
    );
    expect(
      freeTemplateMaterialIssues(
        documentWith({
          'type': 'text',
          'text': '우리의 사진',
          'style': {'fontFamily': 'NotoSans'},
        }),
      ),
      isEmpty,
    );
    expect(
      freeTemplateMaterialIssues(
        documentWith({'type': 'decoration', 'fillColor': '#FFFFFF'}),
      ),
      isEmpty,
    );
    expect(
      freeTemplateMaterialIssues(
        documentWith({
          'type': 'sticker',
          'frame': 'rasterCover',
          'imageUrl': 'asset:assets/templates/prose_study/woodcut_ink.png',
        }),
      ),
      isEmpty,
    );
    expect(
      freeTemplateMaterialIssues(
        documentWith({
          'type': 'sticker',
          'frame': 'rasterCover',
          'imageUrl': 'asset:assets/new-paid-art.png',
        }),
      ),
      isNotEmpty,
    );
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_known_products.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/domain/premium_volume_registration.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_preview_composition.dart';

Future<void> loadStoryFonts() async {
  for (final entry
      in jsonDecode(await rootBundle.loadString('FontManifest.json')) as List) {
    if (![
      'NotoSans',
      'BookMyungjo',
      'Cormorant Garamond',
      'Poppins',
      'Raleway',
    ].contains(entry['family']))
      continue;
    final loader = FontLoader(entry['family'] as String);
    for (final asset in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStoryFonts);
  test('65 story identities, including five free and five paid club books', () {
    expect(storyEditions, hasLength(65));
    expect(storyEditions.map((e) => e.id).toSet(), hasLength(65));
    expect(storyEditions.map((e) => e.catalogId).toSet(), hasLength(65));
    for (final topic in templateTopicOrder) {
      final selected = storyEditions.where((e) => e.category == topic);
      expect(
        selected,
        hasLength(
          topic == '동아리'
              ? 15
              : topic == '스포츠·도전'
              ? 10
              : 5,
        ),
      );
      expect(
        selected.map((e) => e.coverStyle).toSet(),
        topic == '동아리'
            ? {10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24}
            : topic == '스포츠·도전'
            ? {5, 6, 7, 8, 9, 25, 26, 27, 28, 29}
            : selected.first.exclusivePhotography
            ? {5, 6, 7, 8, 9}
            : {0, 1, 2, 3, 4},
      );
    }
    expect(bundledCreationTemplates, hasLength(47));
    expect(publishedCreationTemplates, hasLength(133));
    for (final e in storyEditions) {
      final item = publishedCreationTemplates.singleWhere(
        (t) => t.id == e.catalogId,
      );
      expect(item.isPremium, e.isPremium);
      expect(item.pageCount, 24);
      expect(item.documentBuilder, isNotNull);
      expect(item.tags, containsAll(e.discoveryTags));
      expect(
        publishedDesignTemplates.singleWhere((d) => d.id == e.id).tags,
        containsAll(e.discoveryTags),
      );
      expect(pointShopTemplateKey(item), e.productKey);
      expect(pointShopRequiresFreePrice(e.productKey), !e.isPremium);
      expect(
        pointShopLaunchPrices[e.productKey]?.points,
        e.isPremium ? 1800 : 0,
      );
      expect(isPendingTemplateProduct(e.productKey), false);
      expect(
        pointShopKnownProducts
            .singleWhere((p) => p.productKey == e.productKey)
            .isActive,
        false,
      );
    }
  });

  test(
    '195 matching materials are editable, individually priced and theme-correct',
    () {
      expect(storyEditionDecorations, hasLength(130));
      expect(storyEditionWordArts, hasLength(65));
      final keys = <String>{};
      for (final e in storyEditions) {
        for (final key in e.materialKeys) {
          expect(keys.add(key), true);
          expect(pointShopRequiresFreePrice(key), !e.isPremium);
          expect(isPendingAtelierMaterialProduct(key), false);
          expect(
            pointShopKnownProducts.where((p) => p.productKey == key),
            hasLength(1),
          );
          expect(
            bundledMaterials.singleWhere((m) => m.productKey == key).isPremium,
            e.isPremium,
          );
          final preview = MaterialPreviewComposition.forProduct(
            key,
            key == e.phraseKey
                ? '문구'
                : key.endsWith('paper')
                ? '종이'
                : '스티커',
          );
          expect(preview.photoAsset, e.photoAssets.first);
          final other = MaterialPreviewComposition.forProduct(
            key,
            '소재',
            photoIndex: 1,
          );
          expect(other.photoAsset, e.photoAssets[1]);
          expect(
            preview.materialRect.overlaps(
              Offset.zero & MaterialPreviewComposition.canvas,
            ),
            true,
          );
        }
        final art = studioWordArts.singleWhere((a) => a.id == e.wordArtId);
        expect(
          art.previewLayers().where((l) => l.type == LayerType.text).length,
          greaterThanOrEqualTo(2),
        );
        for (final l in art.previewLayers().where(
          (l) => l.type == LayerType.text,
        )) {
          expect(l.isTemplateContent, true);
          _fits(l, art.sourceSize);
        }
      }
      expect(keys, hasLength(195));
    },
  );

  for (final e in storyEditions) {
    for (final aspect in CollectionAspect.printable) {
      test(
        '${e.id}/${aspect.name}: complete authored pages, fitting type and save roundtrip',
        () {
          final doc = storyEditionDocument(e, aspect);
          final pages = templateDocumentPages(doc);
          expect(pages, hasLength(25));
          expect(doc['accessTier'], e.isPremium ? 'premium' : 'free');
          expect(doc['catalogPublishable'], false);
          expect(doc['chapters'], hasLength(12));
          final materialKeys = templateVisualMaterialKeys(doc);
          expect(
            materialKeys.containsAll(e.materialKeys),
            true,
            reason: '$materialKeys',
          );
          final editor = publishedDesignTemplates.singleWhere(
            (d) => d.id == e.id,
          );
          final editorCover = editor.buildLayers(aspect.canvas);
          final originalCover = DataTemplateEngine.buildLayersFromJson(
            pages.first,
            aspect.canvas,
          );
          expect(editorCover.map((l) => l.id), originalCover.map((l) => l.id));
          expect(
            editorCover.map((l) => l.imageUrl),
            originalCover.map((l) => l.imageUrl),
          );
          final bodyTexts = <String>[];
          for (final page in pages.skip(1)) {
            for (final layer in (page['layers'] as List).cast<Map>()) {
              if (layer['editorialTextRole'] == 'body')
                bodyTexts.add(layer['text'] as String);
            }
          }
          expect(
            bodyTexts.toSet(),
            hasLength(bodyTexts.length),
            reason: 'Do not fill a paid book with repeated sample paragraphs',
          );
          final ids = <String>{};
          final signatures = <String>{};
          for (final entry in pages.indexed) {
            final page = entry.$2;
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            expect(layers, hasLength((page['layers'] as List).length));
            for (final l in layers) {
              expect(ids.add(l.id), true, reason: l.id);
              _fits(l, aspect.canvas);
              if (l.imageUrl case final String path
                  when path.startsWith('asset:')) {
                expect(
                  File(path.substring(6)).existsSync(),
                  true,
                  reason: path,
                );
              }
              if (l.type == LayerType.image || l.type == LayerType.text) {
                expect(
                  l.isTemplateContent,
                  true,
                  reason:
                      'Sample content must not complete a user album: ${l.id}',
                );
              }
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(l, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.isTemplateContent, l.isTemplateContent);
              expect(restored.text, l.text);
              expect(restored.imageBackground, l.imageBackground);
              expect(restored.imageUrl, l.imageUrl);
              expect(restored.imageOffset, l.imageOffset);
              expect((restored.width - l.width).abs(), lessThan(.001));
            }
            if (entry.$1 > 0 && entry.$1.isOdd) {
              signatures.add(
                jsonEncode([
                  for (final p in pages.skip(entry.$1).take(2))
                    [
                      for (final l in (p['layers'] as List).where(
                        (l) => l['type'] == 'image',
                      ))
                        [l['x'], l['y'], l['w'], l['h']],
                    ],
                ]),
              );
            }
          }
          expect(signatures, hasLength(12));
        },
      );
    }
  }
}

void _fits(LayerModel l, Size canvas) {
  final r = l.position & Size(l.width, l.height);
  expect(r.left, greaterThanOrEqualTo(-.1), reason: l.id);
  expect(r.top, greaterThanOrEqualTo(-.1), reason: l.id);
  expect(r.right, lessThanOrEqualTo(canvas.width + .1), reason: l.id);
  expect(r.bottom, lessThanOrEqualTo(canvas.height + .1), reason: l.id);
  if (l.type != LayerType.text) return;
  final p = TextPainter(
    text: TextSpan(text: l.text, style: l.textStyle),
    textDirection: TextDirection.ltr,
    textAlign: l.textAlign ?? TextAlign.left,
    strutStyle: StrutStyle.fromTextStyle(l.textStyle!, forceStrutHeight: true),
  )..layout(maxWidth: l.width);
  final height = p.height;
  p.dispose();
  expect(
    height,
    lessThanOrEqualTo(l.height + .6),
    reason: '${l.id}: ${l.text}',
  );
}

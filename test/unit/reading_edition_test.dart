import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final edition = readingStoryEditions.single;

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final item in manifest.cast<Map>()) {
      final loader = FontLoader(item['family'] as String);
      for (final face in (item['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'new hobby book has five exclusive photographs and a free complete catalog entry',
    () {
      expect(edition.catalogId, -9771);
      expect(edition.category, '취미·기록');
      expect(edition.isPremium, isFalse);
      expect(edition.photoAssets.toSet(), hasLength(5));
      final otherPhotos = storyEditions
          .where((e) => e.id != edition.id)
          .expand((e) => e.photoAssets)
          .toSet();
      expect(edition.photoAssets.toSet().intersection(otherPhotos), isEmpty);
      expect(
        edition.photoAssets.every((path) => File(path).existsSync()),
        isTrue,
      );
      expect(
        edition.photoAssets
            .map(
              (path) => sha256.convert(File(path).readAsBytesSync()).toString(),
            )
            .toSet(),
        hasLength(5),
      );
      final catalog = publishedCreationTemplateById(edition.catalogId)!;
      expect(catalog.title, edition.title);
      expect(catalog.category, edition.category);
      expect(catalog.tags, containsAll(['독서', '북클럽', '독서기록']));
      expect(catalog.isPremium, isFalse);
      expect(catalog.pageCount, 24);
    },
  );

  for (final aspect in CollectionAspect.printable) {
    test(
      '${aspect.name}: the full book uses every declared material and sample, with native editable text',
      () {
        final document = storyEditionDocument(edition, aspect);
        expect(document['pages'], hasLength(24));
        expect(document['chapters'], hasLength(12));
        expect(document['accessTier'], 'free');
        expect(document['publicationStatus'], 'bundled');
        expect(document['qualityRevision'], readingEditionRevision);
        expect(freeTemplateMaterialIssues(document), isEmpty);
        expect(
          templateVisualMaterialKeys(document),
          edition.includedMaterialKeys.toSet(),
        );
        final photos = <String>{};
        final pages = [
          document['cover'],
          ...document['pages'] as List,
        ].cast<Map<String, dynamic>>();
        for (final (pageIndex, page) in pages.indexed) {
          final layers = DataTemplateEngine.buildLayersFromJson(
            page,
            aspect.canvas,
          );
          final photoRects = <Rect>[];
          final textRects = <Rect>[];
          for (final layer in layers) {
            final restored = LayerExportMapper.fromJson(
              LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
              canvasSize: aspect.canvas,
            );
            expect(restored.id, layer.id);
            expect(restored.type, layer.type);
            expect(restored.text, layer.text);
            expect(restored.imageUrl, layer.imageUrl);
            expect(restored.imageBackground, layer.imageBackground);
            expect(restored.imageOffset, layer.imageOffset);
            expect(restored.isTemplateContent, layer.isTemplateContent);
            expect(
              (restored.position - layer.position).distance,
              lessThan(.001),
            );
            expect((restored.width - layer.width).abs(), lessThan(.001));
            expect((restored.height - layer.height).abs(), lessThan(.001));
            final bounds = layer.position & Size(layer.width, layer.height);
            final context = '${aspect.name}/$pageIndex/${layer.id}';
            expect(bounds.left, greaterThanOrEqualTo(-.5), reason: context);
            expect(bounds.top, greaterThanOrEqualTo(-.5), reason: context);
            expect(
              bounds.right,
              lessThanOrEqualTo(aspect.canvas.width + .5),
              reason: context,
            );
            expect(
              bounds.bottom,
              lessThanOrEqualTo(aspect.canvas.height + .5),
              reason: context,
            );
            if (layer.type == LayerType.image) photoRects.add(bounds);
            if (layer.type != LayerType.text) continue;
            textRects.add(bounds);
            final painter = TextPainter(
              text: TextSpan(text: layer.text, style: layer.textStyle),
              textDirection: TextDirection.ltr,
              textAlign: layer.textAlign ?? TextAlign.left,
            )..layout(maxWidth: layer.width);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + 1.25),
              reason: '$context: ${layer.text}',
            );
            expect(
              painter.computeLineMetrics().every(
                (line) => line.width <= layer.width + 1,
              ),
              isTrue,
              reason: context,
            );
            painter.dispose();
          }
          for (final text in textRects) {
            expect(
              photoRects.any(
                (photo) => photo.deflate(.5).overlaps(text.deflate(.5)),
              ),
              isFalse,
              reason:
                  '${aspect.name}/$pageIndex: writing must not cover photographs',
            );
          }
          for (final raw in (page['layers'] as List).cast<Map>()) {
            if (raw['type'] != 'image') continue;
            photos.add((raw['imageUrl'] as String).replaceFirst('asset:', ''));
            final size = Size(
              (raw['w'] as num).toDouble() * aspect.canvas.width,
              (raw['h'] as num).toDouble() * aspect.canvas.height,
            );
            final aperture = StudioMaterial.photoInsets(
              raw['frame'] as String,
              size,
            ).deflateRect(Offset.zero & size);
            expect(
              aperture.width / aperture.height,
              closeTo(1.5, .00001),
              reason:
                  '${aspect.name}/$pageIndex: whole photograph must fit the actual frame aperture',
            );
          }
          final rawLayers = (page['layers'] as List).cast<Map>();
          final cardIndex = rawLayers.indexWhere(
            (raw) => raw['style'] == edition.paperId,
          );
          if (cardIndex >= 0) {
            Rect normalized(Map raw) => Rect.fromLTWH(
              (raw['x'] as num).toDouble(),
              (raw['y'] as num).toDouble(),
              (raw['w'] as num).toDouble(),
              (raw['h'] as num).toDouble(),
            );
            final card = normalized(rawLayers[cardIndex]);
            final fields = rawLayers
                .skip(cardIndex + 1)
                .where(
                  (raw) =>
                      raw['type'] == 'text' &&
                      !'${raw['id']}'.contains('_folio_'),
                );
            expect(fields, hasLength(3));
            for (final field in fields) {
              final bounds = normalized(field);
              expect(
                bounds.left,
                greaterThanOrEqualTo(card.left + card.width * .15),
                reason: 'card margin and punched holes',
              );
              expect(
                bounds.right,
                lessThanOrEqualTo(card.right),
                reason: 'writing must remain on the fitted card',
              );
              expect(bounds.top, greaterThanOrEqualTo(card.top));
              expect(
                bounds.bottom,
                lessThanOrEqualTo(card.top + card.height * .84),
                reason: 'writing must clear the printed bottom rule',
              );
            }
          }
        }
        expect(photos, edition.photoAssets.toSet());
        expect(
          studioWordArtById(
            edition.wordArtId,
          )!.buildLayers(aspect.canvas).where((l) => l.type == LayerType.text),
          hasLength(3),
        );
      },
    );
  }
}

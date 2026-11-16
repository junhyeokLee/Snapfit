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
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/shared/widgets/milestone_expansion_frame.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';

void _typeFits(LayerModel layer, String context) {
  if (layer.type != LayerType.text) return;
  final painter = TextPainter(
    text: TextSpan(text: layer.text, style: layer.textStyle),
    textDirection: TextDirection.ltr,
    textAlign: layer.textAlign ?? TextAlign.left,
  )..layout(maxWidth: layer.width);
  expect(
    painter.height,
    lessThanOrEqualTo(layer.height + 1.25),
    reason: '$context ${layer.text}',
  );
  expect(
    painter.computeLineMetrics().every(
      (line) => line.width <= layer.width + 1.25,
    ),
    isTrue,
    reason: context,
  );
  painter.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const needed = {
      'NotoSans',
      'BookMyungjo',
      'Poppins',
      'Cormorant Garamond',
      'Arita',
      'Eulyoo',
      'NanumPen',
      'Samlip',
      'Tenada',
    };
    for (final row
        in (jsonDecode(await rootBundle.loadString('FontManifest.json'))
                as List)
            .cast<Map>()) {
      if (!needed.contains(row['family'])) continue;
      final loader = FontLoader(row['family'] as String);
      for (final face in (row['fonts'] as List).cast<Map>())
        loader.addFont(rootBundle.load(face['asset'] as String));
      await loader.load();
    }
  });
  test(
    'five independent milestones complete the topic without shared photography or new kits',
    () {
      expect(milestoneExpansionEditions.map((e) => e.catalogId), [
        -9781,
        -9782,
        -9783,
        -9784,
        -9785,
      ]);
      expect(
        milestoneExpansionEditions.where((e) => !e.isPremium),
        hasLength(2),
      );
      expect(
        milestoneExpansionEditions.every((e) => e.category == '졸업·새출발'),
        isTrue,
      );
      final photos = <String>{},
          hashes = <String>{},
          materials = <String>{},
          covers = <String>{};
      final older = storyEditions
          .where((e) => e.qualityRevision != milestoneExpansionRevision)
          .expand((e) => e.photoAssets)
          .toSet();
      for (final e in milestoneExpansionEditions) {
        expect(e.photoAssets, hasLength(5));
        expect(e.photoAssets.toSet().intersection(older), isEmpty);
        for (final asset in e.photoAssets) {
          expect(photos.add(asset), isTrue);
          expect(File(asset).existsSync(), isTrue, reason: asset);
          expect(
            hashes.add(
              sha256.convert(File(asset).readAsBytesSync()).toString(),
            ),
            isTrue,
          );
        }
        expect(e.includedMaterialKeys, hasLength(4));
        for (final key in e.includedMaterialKeys)
          expect(
            materials.add(key),
            isTrue,
            reason:
                'The new kits must not be color variants of shared products: $key',
          );
        expect(MilestoneExpansionFrame.styles, contains(e.photoFrames.single));
        final catalog = publishedCreationTemplateById(e.catalogId)!;
        expect(catalog.category, e.category);
        expect(catalog.isPremium, e.isPremium);
        expect(catalog.pageCount, 24);
        final cover = storyEditionCover(e, CollectionAspect.square);
        covers.add(
          jsonEncode([
            (cover['layers'] as List)
                .where((l) => l['type'] == 'image')
                .map((l) => [l['x'], l['y'], l['w'], l['h']])
                .toList(),
            (cover['layers'] as List)
                .where((l) => l['type'] == 'text')
                .map((l) => [l['x'], l['y'], l['w'], l['h']])
                .toList(),
          ]),
        );
      }
      expect(photos, hasLength(25));
      expect(hashes, hasLength(25));
      expect(materials, hasLength(20));
      expect(covers, hasLength(5));
    },
  );
  for (final edition in milestoneExpansionEditions) {
    for (final aspect in CollectionAspect.printable) {
      test(
        '${edition.id}/${aspect.name}: fitting editable pages, full photo apertures and exact used kit',
        () {
          final document = storyEditionDocument(edition, aspect);
          expect(document['pages'], hasLength(24));
          expect(document['chapters'], hasLength(12));
          expect(document['qualityRevision'], milestoneExpansionRevision);
          expect(
            templateVisualMaterialKeys(document),
            edition.includedMaterialKeys.toSet(),
          );
          if (!edition.isPremium)
            expect(freeTemplateMaterialIssues(document), isEmpty);
          final pages = templateDocumentPages(document),
              photos = <String>{},
              ids = <String>{},
              signatures = <String>{};
          for (final (index, page) in pages.indexed) {
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            final photoRects = <Rect>[], textRects = <Rect>[];
            for (final layer in layers) {
              final context = '${edition.id}/${aspect.name}/$index/${layer.id}';
              expect(ids.add(layer.id), isTrue, reason: context);
              final bounds = layer.position & Size(layer.width, layer.height);
              expect(bounds.left, greaterThanOrEqualTo(-.6), reason: context);
              expect(bounds.top, greaterThanOrEqualTo(-.6), reason: context);
              expect(
                bounds.right,
                lessThanOrEqualTo(aspect.canvas.width + .6),
                reason: context,
              );
              expect(
                bounds.bottom,
                lessThanOrEqualTo(aspect.canvas.height + .6),
                reason: context,
              );
              _typeFits(layer, context);
              if (layer.type == LayerType.text) textRects.add(bounds);
              if (layer.type == LayerType.image) {
                photoRects.add(bounds);
                photos.add(layer.imageUrl!.replaceFirst('asset:', ''));
                final aperture = StudioMaterial.photoInsets(
                  layer.imageBackground ?? 'none',
                  Size(layer.width, layer.height),
                ).deflateRect(Offset.zero & Size(layer.width, layer.height));
                expect(
                  aperture.width / aperture.height,
                  closeTo(1.5, .0001),
                  reason: context,
                );
              }
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
              expect(restored.id, layer.id);
              expect(restored.text, layer.text);
              expect(restored.imageUrl, layer.imageUrl);
              expect(restored.imageBackground, layer.imageBackground);
              expect(restored.isTemplateContent, layer.isTemplateContent);
              expect(
                (restored.position - layer.position).distance,
                lessThan(.001),
              );
              expect((restored.width - layer.width).abs(), lessThan(.001));
            }
            for (final text in textRects)
              expect(
                photoRects.any((p) => p.deflate(.5).overlaps(text.deflate(.5))),
                isFalse,
                reason:
                    '${edition.id}/${aspect.name}/$index: writing must not cover photographs',
              );
            final raw = (page['layers'] as List).cast<Map>();
            final cardIndex = raw.indexWhere(
              (l) => l['style'] == edition.paperId,
            );
            if (cardIndex >= 0) {
              Rect rect(Map l) => Rect.fromLTWH(
                (l['x'] as num).toDouble(),
                (l['y'] as num).toDouble(),
                (l['w'] as num).toDouble(),
                (l['h'] as num).toDouble(),
              );
              final card = rect(raw[cardIndex]);
              final fields = raw
                  .skip(cardIndex + 1)
                  .where(
                    (l) =>
                        l['type'] == 'text' &&
                        !('${l['id']}').contains('_folio_'),
                  );
              expect(fields, hasLength(2));
              for (final field in fields) {
                final b = rect(field);
                expect(
                  b.left,
                  greaterThanOrEqualTo(card.left + card.width * .13),
                );
                expect(
                  b.right,
                  lessThanOrEqualTo(card.left + card.width * .87),
                );
                expect(
                  b.top,
                  greaterThanOrEqualTo(card.top + card.height * .15),
                );
                expect(
                  b.bottom,
                  lessThanOrEqualTo(card.top + card.height * .75),
                );
              }
            }
            if (index > 0 && index.isOdd)
              signatures.add(
                jsonEncode([
                  for (final p in pages.skip(index).take(2))
                    [
                      for (final l in (p['layers'] as List).where(
                        (l) => l['type'] == 'image',
                      ))
                        [l['x'], l['y'], l['w'], l['h']],
                    ],
                ]),
              );
          }
          expect(photos, edition.photoAssets.toSet());
          expect(signatures, hasLength(12));
          final art = studioWordArtById(edition.wordArtId)!;
          expect(
            art.previewLayers().where((l) => l.type == LayerType.text),
            hasLength(3),
          );
          for (final layer in art.previewLayers())
            _typeFits(layer, '${edition.id}/word-art');
        },
      );
    }
  }
}

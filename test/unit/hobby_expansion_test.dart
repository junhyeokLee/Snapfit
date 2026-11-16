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

Rect _rawBounds(Map layer) => Rect.fromLTWH(
  (layer['x'] as num).toDouble(),
  (layer['y'] as num).toDouble(),
  (layer['w'] as num).toDouble(),
  (layer['h'] as num).toDouble(),
);
String _photoGeometry(Map page) => jsonEncode([
  for (final l in (page['layers'] as List).cast<Map>())
    if (l['type'] == 'image') [l['x'], l['y'], l['w'], l['h'], l['frame']],
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final needed = {
      'BookMyungjo',
      'NotoSans',
      'Poppins',
      'Cormorant Garamond',
      ...hobbyExpansionSpecs.values.map((s) => s.font),
    };
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final item in manifest.cast<Map>().where(
      (f) => needed.contains(f['family']),
    )) {
      final loader = FontLoader(item['family'] as String);
      for (final face in (item['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(face['asset'] as String));
      }
      await loader.load();
      needed.remove(item['family']);
    }
    expect(needed, isEmpty, reason: 'Every designed typeface must be bundled.');
  });

  test(
    'nine distinct hobbies complete the ten-book topic without shared sample photos or kit keys',
    () {
      expect(hobbyExpansionEditions.map((e) => e.catalogId).toSet(), {
        -9772,
        -9773,
        -9774,
        -9775,
        -9776,
        -9777,
        -9778,
        -9779,
        -9780,
      });
      expect(hobbyExpansionEditions.where((e) => !e.isPremium), hasLength(3));
      expect(hobbyExpansionEditions.where((e) => e.isPremium), hasLength(6));
      expect(
        publishedCreationTemplates.where((t) => t.category == '취미·기록'),
        hasLength(14),
      );
      final olderPhotos = storyEditions
          .where((e) => e.qualityRevision != hobbyExpansionRevision)
          .expand((e) => e.photoAssets)
          .toSet();
      final paths = <String>{};
      final hashes = <String>{};
      final kits = <String>{};
      final coverGeometries = <String>{};
      final sequences = <String>{};
      for (final e in hobbyExpansionEditions) {
        expect(e.photoAssets, hasLength(5));
        expect(
          e.photoAssets.toSet().intersection(olderPhotos),
          isEmpty,
          reason: e.id,
        );
        expect(e.includedMaterialKeys, hasLength(4));
        expect(e.photoFrames, hasLength(1));
        for (final key in e.includedMaterialKeys)
          expect(kits.add(key), isTrue, reason: key);
        for (final path in e.photoAssets) {
          expect(paths.add(path), isTrue, reason: path);
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: path);
          expect(
            hashes.add(sha256.convert(file.readAsBytesSync()).toString()),
            isTrue,
            reason: path,
          );
        }
        final published = publishedCreationTemplateById(e.catalogId)!;
        expect(published.title, e.title);
        expect(published.category, '취미·기록');
        expect(published.isPremium, e.isPremium);
        expect(published.pageCount, 24);
        final spec = hobbyExpansionSpecs[e.id]!;
        expect(spec.spreadOrder, hasLength(12));
        expect(spec.spreadOrder.toSet(), hasLength(12));
        expect(sequences.add(jsonEncode(spec.spreadOrder)), isTrue);
        expect(
          coverGeometries.add(
            _photoGeometry(storyEditionCover(e, CollectionAspect.square)),
          ),
          isTrue,
          reason: 'A new photograph or palette alone is not a distinct jacket.',
        );
      }
      expect(paths, hasLength(45));
      expect(hashes, hasLength(45));
      expect(kits, hasLength(36));
    },
  );

  test(
    'all14 independent phrase products keep real font bounds after insertion',
    () {
      for (final e in [
        ...hobbyExpansionEditions,
        ...milestoneExpansionEditions,
      ]) {
        final art = studioWordArtById(e.wordArtId)!;
        for (final aspect in CollectionAspect.printable) {
          final layers = art.buildLayers(aspect.canvas);
          final text = layers.where((layer) => layer.type == LayerType.text);
          expect(text.length, greaterThanOrEqualTo(2));
          for (final layer in text) {
            final context =
                '${e.id}/${aspect.name}/inserted-phrase/${layer.id}';
            final painter = TextPainter(
              text: TextSpan(text: layer.text, style: layer.textStyle),
              textDirection: TextDirection.ltr,
              textAlign: layer.textAlign ?? TextAlign.left,
            )..layout(maxWidth: layer.width);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + 1.25),
              reason: context,
            );
            expect(
              painter.computeLineMetrics().every(
                (line) => line.width <= layer.width + 1,
              ),
              isTrue,
              reason: context,
            );
            painter.dispose();
            final bounds = layer.position & Size(layer.width, layer.height);
            expect(bounds.left, greaterThanOrEqualTo(0), reason: context);
            expect(bounds.top, greaterThanOrEqualTo(0), reason: context);
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
          }
        }
      }
    },
  );

  for (final e in hobbyExpansionEditions) {
    for (final aspect in CollectionAspect.printable) {
      test(
        '${e.id}/${aspect.name}: complete native artwork, whole-source aperture, readable stock and save restoration',
        () {
          final doc = storyEditionDocument(e, aspect);
          expect(doc['pages'], hasLength(24));
          expect(doc['chapters'], hasLength(12));
          expect(doc['qualityRevision'], hobbyExpansionRevision);
          expect(
            templateVisualMaterialKeys(doc),
            e.includedMaterialKeys.toSet(),
          );
          if (!e.isPremium) expect(freeTemplateMaterialIssues(doc), isEmpty);
          final pages = [
            doc['cover'],
            ...doc['pages'] as List,
          ].cast<Map<String, dynamic>>();
          final ids = <String>{};
          final usedPhotos = <String>{};
          final layouts = <String>{};
          final recordLabels = <String>{};
          final recordPrompts = <String>{};
          final recordFooters = <String>{};
          for (final (pageIndex, page) in pages.indexed) {
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            final photos = <Rect>[];
            final texts = <Rect>[];
            for (final layer in layers) {
              final context = '${e.id}/${aspect.name}/$pageIndex/${layer.id}';
              expect(ids.add(layer.id), isTrue, reason: context);
              final bounds = layer.position & Size(layer.width, layer.height);
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
              if (layer.type == LayerType.image) photos.add(bounds);
              if (layer.type == LayerType.text) {
                texts.add(bounds);
                final painter = TextPainter(
                  text: TextSpan(text: layer.text, style: layer.textStyle),
                  textDirection: TextDirection.ltr,
                  textAlign: layer.textAlign ?? TextAlign.left,
                )..layout(maxWidth: layer.width);
                expect(
                  painter.height,
                  lessThanOrEqualTo(layer.height + 1.25),
                  reason: context,
                );
                expect(
                  painter.computeLineMetrics().every(
                    (l) => l.width <= layer.width + 1,
                  ),
                  isTrue,
                  reason: context,
                );
                painter.dispose();
              }
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                canvasSize: aspect.canvas,
              );
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
            }
            for (final text in texts)
              expect(
                photos.any(
                  (photo) => photo.deflate(.5).overlaps(text.deflate(.5)),
                ),
                isFalse,
                reason:
                    '${e.id}/${aspect.name}/$pageIndex: type over a photograph',
              );
            final rawLayers = (page['layers'] as List).cast<Map>();
            for (final raw in rawLayers.where((l) => l['type'] == 'image')) {
              usedPhotos.add(
                (raw['imageUrl'] as String).replaceFirst('asset:', ''),
              );
              final bounds = _rawBounds(raw);
              final size = Size(
                bounds.width * aspect.canvas.width,
                bounds.height * aspect.canvas.height,
              );
              final aperture = StudioMaterial.photoInsets(
                raw['frame'] as String,
                size,
              ).deflateRect(Offset.zero & size);
              expect(
                aperture.width / aperture.height,
                closeTo(1.5, .00001),
                reason:
                    '${e.id}/${aspect.name}/$pageIndex: complete source photograph',
              );
            }
            final cards = rawLayers.where((l) => l['hobbyRecordCard'] == true);
            for (final cardLayer in cards) {
              final card = _rawBounds(cardLayer);
              final fields = rawLayers.where(
                (l) => l['hobbyRecordField'] == true,
              );
              expect(fields, hasLength(3));
              final copy = fields
                  .map((field) => field['text'] as String)
                  .toList();
              expect(
                recordLabels.add(copy[0]),
                isTrue,
                reason:
                    '${e.id}: record headings must follow their own chapter',
              );
              expect(
                recordPrompts.add(copy[1]),
                isTrue,
                reason: '${e.id}: each record must ask a different question',
              );
              expect(
                recordFooters.add(copy[2]),
                isTrue,
                reason: '${e.id}: closing hints must describe this record',
              );
              for (final f in fields) {
                final bounds = _rawBounds(f);
                expect(
                  bounds.left,
                  greaterThanOrEqualTo(card.left + card.width * .12),
                );
                expect(
                  bounds.right,
                  lessThanOrEqualTo(card.left + card.width * .88),
                );
                expect(
                  bounds.top,
                  greaterThanOrEqualTo(card.top + card.height * .16),
                );
                expect(
                  bounds.bottom,
                  lessThanOrEqualTo(card.top + card.height * .84 + .000001),
                  reason:
                      'Writing must clear printed rules, stitches and perforations.',
                );
              }
            }
            if (pageIndex > 0 && pageIndex.isOdd)
              layouts.add(
                jsonEncode([
                  _photoGeometry(page),
                  _photoGeometry(pages[pageIndex + 1]),
                ]),
              );
          }
          expect(usedPhotos, e.photoAssets.toSet());
          expect(layouts, hasLength(12));
          expect(recordLabels.length, greaterThanOrEqualTo(2));
          expect(recordPrompts.length, recordLabels.length);
          final art = studioWordArtById(e.wordArtId)!;
          final lettering = art.previewLayers().where(
            (l) => l.type == LayerType.text,
          );
          expect(lettering.length, greaterThanOrEqualTo(2));
          for (final layer in lettering) {
            final bounds = layer.position & Size(layer.width, layer.height);
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.top, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(art.sourceSize.width + .5));
            expect(bounds.bottom, lessThanOrEqualTo(art.sourceSize.height + 1));
          }
        },
      );
    }
  }
}

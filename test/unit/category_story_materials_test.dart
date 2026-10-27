import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/shared/widgets/studio_material.dart';

import '../../tool/template_studio/export_price_application.dart';
import 'story_editions_test.dart' show loadStoryFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadStoryFonts);
  final selected = storyEditions.where(
    (e) => e.qualityRevision == categoryStoryMaterialRevision,
  );
  // Captured from the bundled native-font snapshots before this refinement.
  final baseline =
      jsonDecode(
            utf8.decode(
              GZipDecoder().decodeBytes(
                File(
                  'test/fixtures/category_story_material_baseline.json.gz',
                ).readAsBytesSync(),
              ),
            ),
          )
          as Map<String, dynamic>;

  test('forty books keep their tiers and reuse registered free frames', () {
    expect(selected, hasLength(40));
    expect(selected.map((e) => e.category).toSet(), hasLength(8));
    final rows = pointShopPriceApplicationRows();
    validatePointShopCatalogRelease(rows);
    for (final e in selected) {
      expect(e.photoFrames.toSet(), hasLength(2));
      expect(e.photoAspectRatios, hasLength(e.photoAssets.length));
      for (final frame in {...e.photoFrames, ...e.preservedPhotoFrames}) {
        final key = 'frame:$frame';
        expect(freeTemplateMaterialProductKeys, contains(key));
        final row = rows.singleWhere((r) => r['product_key'] == key);
        expect(row['point_price'], 0);
        expect(row['is_active'], true);
      }
      expect(
        rows.singleWhere(
          (r) => r['product_key'] == e.productKey,
        )['point_price'],
        1800,
      );
    }
  });

  test(
    'source ratios match asset headers without decoding photo pixels',
    () async {
      final sizes = <String, double>{};
      for (final e in selected) {
        for (final entry in e.photoAssets.indexed) {
          final path = entry.$2;
          if (!sizes.containsKey(path)) {
            final buffer = await ui.ImmutableBuffer.fromUint8List(
              File(path).readAsBytesSync(),
            );
            ui.ImageDescriptor? descriptor;
            try {
              descriptor = await ui.ImageDescriptor.encoded(buffer);
              sizes[path] = descriptor.width / descriptor.height;
            } finally {
              descriptor?.dispose();
              buffer.dispose();
            }
          }
          expect(
            e.photoAspectRatios[entry.$1],
            closeTo(sizes[path]!, .000000001),
          );
        }
      }
    },
  );

  for (final aspect in CollectionAspect.printable) {
    test(
      '${aspect.name}: covers, hero photographs and wording stay unchanged',
      () {
        for (final e in selected) {
          final d = storyEditionDocument(e, aspect);
          final previous = baseline[e.id][aspect.name] as Map;
          expect(d['cover'], previous['cover'], reason: '${e.id}: cover');
          final heroes = (d['pages'] as List)
              .where(
                (p) =>
                    (p['role'] == 'story-0' && p['side'] == 'right') ||
                    (p['role'] == 'story-4' && p['side'] == 'left'),
              )
              .toList();
          expect(
            heroes,
            previous['heroes'],
            reason: '${e.id}: main photographs',
          );
          final texts =
              templateDocumentPages(d)
                  .expand((p) => (p['layers'] as List).cast<Map>())
                  .where((l) => l['type'] == 'text')
                  .map(
                    (l) => l['text'] ?? (l['payload'] as Map?)?['text'] ?? '',
                  )
                  .cast<String>()
                  .toList()
                ..sort();
          expect(texts, previous['texts'], reason: '${e.id}: original wording');
        }
      },
    );

    test(
      '${aspect.name}: mounts retain complete photos and stationery stays below them',
      () {
        for (final e in selected) {
          final d = storyEditionDocument(e, aspect);
          final pages = templateDocumentPages(d);
          expect(
            templateVisualMaterialKeys(d),
            e.includedMaterialKeys.toSet(),
            reason: e.id,
          );
          final mounted = pages
              .expand((p) => (p['layers'] as List).cast<Map>())
              .where((l) => l['storyPhotoSourceAspect'] != null)
              .toList();
          expect(mounted.length, greaterThanOrEqualTo(4));
          expect(mounted.map((l) => l['frame']).toSet(), e.photoFrames.toSet());
          for (final photo in mounted) {
            final size = Size(
              (photo['w'] as num) * aspect.canvas.width,
              (photo['h'] as num) * aspect.canvas.height,
            );
            final insets = StudioMaterial.photoInsets(
              photo['frame'] as String,
              size,
            );
            expect(
              (size.width - insets.horizontal) /
                  (size.height - insets.vertical),
              closeTo(photo['storyPhotoSourceAspect'] as num, .000001),
              reason: '${e.id}/${photo['frame']}',
            );
            expect(photo['templateContent'], true);
          }
          final paperPage = pages.singleWhere(
            (p) => p['role'] == 'story-7' && p['side'] == 'left',
          );
          final layers = (paperPage['layers'] as List).cast<Map>();
          final paper = layers.singleWhere((l) => l['style'] == e.paperId);
          final photo = layers.singleWhere((l) => l['type'] == 'image');
          Rect bounds(Map l) => Rect.fromLTWH(
            (l['x'] as num).toDouble(),
            (l['y'] as num).toDouble(),
            (l['w'] as num).toDouble(),
            (l['h'] as num).toDouble(),
          );
          expect(paper['z'] as num, lessThan(photo['z'] as num));
          expect(bounds(paper).contains(bounds(photo).topLeft), true);
          expect(bounds(paper).contains(bounds(photo).bottomRight), true);
          final caption = layers.singleWhere(
            (l) => l['type'] == 'text' && l['editorialTextRole'] == 'caption',
          );
          expect(bounds(photo).overlaps(bounds(caption)), false);
          expect(bounds(paper).overlaps(bounds(caption)), false);
        }
      },
    );
  }
}

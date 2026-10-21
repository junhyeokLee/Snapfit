import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../widget/studio_decorations_test.dart' show capture;

// Reading-order contracts allow shared grids while each jacket keeps its own
// subject, palette and editable typography. No export path exists in this test.
const _directions = {
  'masthead': FreeCollectionVolume.vows,
  'gallery': FreeCollectionVolume.letters,
  'split': FreeCollectionVolume.postcards,
  'band': FreeCollectionVolume.cinema,
  'archive': FreeCollectionVolume.objects,
  'field': FreeCollectionVolume.city,
  'inset': FreeCollectionVolume.garden,
  'horizon': FreeCollectionVolume.seaside,
};

Rect _rect(LayerModel layer) =>
    layer.position & Size(layer.width, layer.height);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.whereType<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  test('32 photo jackets preserve subjects and editable personal fields', () {
    expect(FreeCollectionVolume.values, hasLength(32));
    expect(
      FreeCollectionVolume.values.map((v) => v.category).toSet(),
      hasLength(7),
    );
    for (final aspect in CollectionAspect.values) {
      final photos = <String>{};
      for (final volume in FreeCollectionVolume.values) {
        final document = volume.document(aspect);
        final cover = document['cover'] as Map<String, dynamic>;
        final layers = DataTemplateEngine.buildLayersFromJson(
          cover,
          aspect.canvas,
        );
        final images = layers.where((l) => l.type == LayerType.image).toList();
        expect(images.length, inInclusiveRange(1, 2), reason: volume.id);
        expect(photos.add(images.first.imageUrl!), isTrue, reason: volume.id);
        for (final image in images) expect(image.imageBackground, 'none');
        final title = (cover['layers'] as List).cast<Map>().singleWhere(
          (l) => l['typographyRole'] == 'signature-title',
        );
        expect(
          (title['text'] as String).replaceAll(RegExp(r'\s+'), ''),
          volume.title.replaceAll(RegExp(r'\s+'), ''),
          reason: volume.id,
        );
        expect(
          layers.where((l) => l.type == LayerType.text).map((l) => l.text),
          containsAll([
            volume.defaultCopy.place,
            volume.defaultCopy.byline,
            volume.defaultCopy.period,
          ]),
          reason: volume.id,
        );
        final cleared = AlbumCreationTemplate.preparePages(
          [layers],
          sourceCanvas: aspect.canvas,
          cover: aspect.cover,
        ).single;
        expect(
          cleared
              .where((l) => l.type == LayerType.image)
              .every((l) => !l.hasImageSource),
          isTrue,
        );
        expect(
          cleared.where((l) => l.type == LayerType.text).length,
          layers.where((l) => l.type == LayerType.text).length,
        );
        expect(document['innerPageCount'], 24);
        expect(document['accessTier'], 'free');
        expect(document['artDirection'], volume.id);
      }
    }
  });

  test(
    'eight jacket directions retain reading order and photograph protection',
    () {
      expect(_directions, hasLength(8));
      for (final aspect in CollectionAspect.values) {
        for (final entry in _directions.entries) {
          final cover =
              entry.value.document(aspect)['cover'] as Map<String, dynamic>;
          final layers = DataTemplateEngine.buildLayersFromJson(
            cover,
            aspect.canvas,
          );
          final hero = layers.firstWhere((l) => l.type == LayerType.image);
          final titleId = ((cover['layers'] as List).cast<Map>().singleWhere(
            (l) => l['typographyRole'] == 'signature-title',
          ))['id'];
          final title = layers.singleWhere((l) => l.id == titleId);
          final label = '${entry.key}/${aspect.name}';
          if (entry.key == 'horizon') {
            expect(_rect(hero), Offset.zero & aspect.canvas, reason: label);
            expect(
              layers.any((l) => l.id.endsWith('_signature_title_stock')),
              isTrue,
            );
            expect(
              layers.any((l) => l.id.endsWith('_signature_information_stock')),
              isTrue,
            );
            continue;
          }
          expect(_rect(hero).overlaps(_rect(title)), isFalse, reason: label);
          if (entry.key == 'archive') {
            expect(
              layers.where((l) => l.type == LayerType.image),
              hasLength(2),
            );
          }
          if (aspect == CollectionAspect.landscape) {
            if (entry.key == 'gallery' || entry.key == 'band') {
              expect(
                _rect(hero).right,
                lessThanOrEqualTo(_rect(title).left),
                reason: label,
              );
            } else {
              expect(
                _rect(title).right,
                lessThanOrEqualTo(_rect(hero).left),
                reason: label,
              );
            }
          } else if (entry.key == 'gallery') {
            expect(
              _rect(hero).bottom,
              lessThanOrEqualTo(_rect(title).top),
              reason: label,
            );
          } else {
            expect(
              _rect(title).bottom,
              lessThanOrEqualTo(_rect(hero).top),
              reason: label,
            );
            if (entry.key == 'field') {
              expect(
                layers.any((l) => l.id.endsWith('_signature_top_edge')),
                isTrue,
              );
            }
            if (entry.key == 'split') {
              expect(
                layers.any((l) => l.id.endsWith('_signature_color_edge')),
                isTrue,
              );
            }
          }
        }
      }
    },
  );

  for (final style in ['photoCoverShadeTop', 'photoCoverShadeBottom']) {
    testWidgets('$style survives saving and matches editor print pixels', (
      tester,
    ) async {
      const size = Size(200, 200);
      final layer = LayerModel(
        id: 'photo-shade',
        type: LayerType.decoration,
        position: Offset.zero,
        width: size.width,
        height: size.height,
        imageBackground: style,
        opacity: .64,
      );
      final restored = LayerExportMapper.fromJson(
        LayerExportMapper.toJson(layer, canvasSize: size),
        canvasSize: size,
      );
      expect(restored.imageBackground, style);
      expect(restored.opacity, layer.opacity);
      final preview = await capture(
        tester,
        TemplatePageRenderer(
          layers: [layer],
          width: size.width,
          height: size.height,
          designCanvasSize: size,
          showCanvasChrome: false,
        ),
      );
      final native = await capture(
        tester,
        ProviderScope(
          child: SizedBox.fromSize(
            size: size,
            child: PrintAlbumPageCanvas(
              page: PrintAlbumPage(
                index: 0,
                isCover: true,
                canvasSize: size,
                layers: [restored],
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      );
      try {
        final a = (await tester.runAsync(
          () => preview.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!.buffer.asUint8List();
        final b = (await tester.runAsync(
          () => native.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!.buffer.asUint8List();
        expect(a, orderedEquals(b));
        final alphaTop = a[(10 * 200 + 100) * 4 + 3];
        final alphaBottom = a[(190 * 200 + 100) * 4 + 3];
        expect(alphaTop > alphaBottom, style == 'photoCoverShadeTop');
      } finally {
        preview.dispose();
        native.dispose();
      }
    });
  }

  for (final aspect in CollectionAspect.values) {
    testWidgets('eight jacket directions render in RAM: ${aspect.name}', (
      tester,
    ) async {
      for (final volume in _directions.values) {
        final image = await capture(
          tester,
          TemplatePageRenderer(
            layers: DataTemplateEngine.buildLayersFromJson(
              volume.document(aspect)['cover'],
              aspect.canvas,
            ),
            width: 320,
            height: 320 / aspect.canvas.aspectRatio,
            designCanvasSize: aspect.canvas,
            preserveTypography: true,
            showCanvasChrome: false,
          ),
        );
        image.dispose();
        expect(tester.takeException(), isNull, reason: volume.id);
      }
    });
  }
}

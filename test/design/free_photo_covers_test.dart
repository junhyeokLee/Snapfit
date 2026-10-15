import 'dart:io';
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
import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;
import '../widget/studio_decorations_test.dart' show capture;

const _export = bool.fromEnvironment('EXPORT_FREE_PHOTO_COVERS');
List<FreeCollectionVolume> get _volumes => FreeCollectionVolume.values
    .where(
      (volume) =>
          volume.document(CollectionAspect.square)['coverTreatment'] ==
          'full-bleed-photo',
    )
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'Eulyoo',
    )..addFont(rootBundle.load('assets/fonts/Eulyoo1945-Regular.ttf'))).load();
  });

  test('nine full photo covers span seven themes without duplicate images', () {
    expect(_volumes, hasLength(9));
    expect(_volumes.map((v) => v.category).toSet(), hasLength(7));
    for (final aspect in CollectionAspect.values) {
      final photos = <String>{};
      for (final volume in _volumes) {
        final document = volume.document(aspect);
        final cover = document['cover'] as Map<String, dynamic>;
        final layers = DataTemplateEngine.buildLayersFromJson(
          cover,
          aspect.canvas,
        );
        final photo = layers.singleWhere((l) => l.type == LayerType.image);
        expect(photo.position, Offset.zero);
        expect(Size(photo.width, photo.height), aspect.canvas);
        expect(photo.imageBackground, 'none');
        expect(photos.add(photo.imageUrl!), true);
        final cleared = AlbumCreationTemplate.preparePages(
          [layers],
          sourceCanvas: aspect.canvas,
          cover: aspect.cover,
        ).single;
        expect(
          cleared.singleWhere((l) => l.type == LayerType.image).imageUrl,
          isNull,
        );
        expect(
          cleared.where((l) => l.type == LayerType.text).length,
          layers.where((l) => l.type == LayerType.text).length,
        );
        expect(document['innerPageCount'], 24);
        expect(document['accessTier'], 'free');
      }
    }
  });

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
    testWidgets('full photo cover native review: ${aspect.name}', (
      tester,
    ) async {
      final images = <ui.Image>[];
      final width = 320.0;
      final height = width / aspect.canvas.aspectRatio;
      for (final volume in _volumes) {
        final image = await capture(
          tester,
          TemplatePageRenderer(
            layers: DataTemplateEngine.buildLayersFromJson(
              volume.document(aspect)['cover'],
              aspect.canvas,
            ),
            width: width,
            height: height,
            designCanvasSize: aspect.canvas,
            preserveTypography: true,
            showCanvasChrome: false,
          ),
        );
        images.add(image);
        expect(tester.takeException(), isNull, reason: volume.id);
        if (_export) {
          await tester.runAsync(() async {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'output/settings-template-qa/free-photo-${volume.id}-${aspect.name}.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
      if (_export) {
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFFECF1F0), BlendMode.src);
          for (final entry in images.indexed) {
            final x = 20 + entry.$1 % 4 * (width + 20);
            final y = 20 + entry.$1 ~/ 4 * (height + 48);
            final image = entry.$2;
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              Rect.fromLTWH(x, y, width, height),
              Paint(),
            );
            final label = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(
                text: '${_volumes[entry.$1].title} · 무료',
                style: const TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: 14,
                  color: Color(0xFF283C36),
                ),
              ),
            )..layout(maxWidth: width);
            label.paint(canvas, Offset(x, y + height + 9));
            label.dispose();
          }
          final picture = recorder.endRecording();
          final overview = await picture.toImage(
            1380,
            ((_volumes.length / 4).ceil() * (height + 48) + 20).ceil(),
          );
          final bytes = await overview.toByteData(
            format: ui.ImageByteFormat.png,
          );
          File(
            'output/settings-template-qa/free-photo-${aspect.name}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          overview.dispose();
          picture.dispose();
        });
      }
      for (final image in images) image.dispose();
    });
  }
}

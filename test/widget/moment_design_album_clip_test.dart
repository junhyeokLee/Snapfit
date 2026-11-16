import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/monthly_album_builder.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

void main() {
  testWidgets(
    'portrait artwork stays clipped after editable import to a landscape album',
    (tester) async {
      const canvas = Size(400, 200);
      final original = MomentPhoto(
        id: 'photo',
        path: 'owner/moments/record/photo.jpg',
        width: 100,
        height: 200,
      );
      final design = MomentPhotoDesign.fromLayers(
        canvasSize: const Size(100, 200),
        backgroundColor: Colors.white,
        photoSource: original.storageUri,
        layers: [
          LayerModel(
            id: 'original',
            type: LayerType.image,
            position: Offset.zero,
            width: 100,
            height: 200,
            originalUrl: original.storageUri,
            previewUrl: original.storageUri,
            imageUrl: original.storageUri,
          ),
          // This deliberately crosses the source artboard and is rotated and
          // enlarged. Its hidden part must not appear in album side margins.
          LayerModel(
            id: 'rotated',
            type: LayerType.decoration,
            position: const Offset(-40, 40),
            width: 100,
            height: 70,
            rotation: 30,
            scale: 1.25,
            imageBackground: 'stickerTapeBeige',
            decorationFillColor: '#FFFF0000',
            zIndex: 1,
          ),
        ],
      );
      final raw = buildMonthlyMomentAppendPages(
        month: DateTime.utc(2026, 11),
        records: [
          MomentRecord(
            id: 'record',
            recordDate: DateTime.utc(2026, 11, 3),
            caption: '피드에만 남길 글',
            photos: [original.withDesign(design)],
            revision: 1,
          ),
        ],
        selectedPhotoIds: ['photo'],
        canvasSize: canvas,
      ).single;
      final layers = (raw['layers'] as List)
          .map(
            (value) => LayerExportMapper.fromJson(
              Map<String, dynamic>.from(value as Map),
              canvasSize: canvas,
            ),
          )
          .toList();
      final background = Color(raw['backgroundColor'] as int);
      final editable = layers.singleWhere(
        (layer) => layer.id.endsWith('-rotated'),
      );
      expect(editable.rotation, 30);
      expect(editable.scale, 1.25);
      expect(editable.position.dx, lessThan(editable.canvasClip!.left));
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 100, 200),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final photo = await tester.runAsync(() => picture.toImage(100, 200));
      picture.dispose();
      try {
        for (final (print, clipped) in [
          (false, true),
          (false, false),
          (true, true),
          (true, false),
        ]) {
          final renderLayers = clipped
              ? layers
              : layers
                    .map((layer) => layer.copyWith(clearCanvasClip: true))
                    .toList();
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: key,
                    child: SizedBox.fromSize(
                      size: canvas,
                      child: ColoredBox(
                        color: background,
                        child: print
                            ? PrintAlbumPageCanvas(
                                page: PrintAlbumPage(
                                  index: 1,
                                  isCover: false,
                                  canvasSize: canvas,
                                  layers: renderLayers,
                                  backgroundColor: background,
                                ),
                                images: {original.storageUri: photo!},
                              )
                            : TemplatePageRenderer(
                                layers: renderLayers,
                                width: canvas.width,
                                height: canvas.height,
                                designCanvasSize: canvas,
                                photoBuilder: (_, _) =>
                                    const ColoredBox(color: Colors.blue),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage();
            try {
              final pixels = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              Color colorAt(int x, int y) {
                final offset = (y * image.width + x) * 4;
                return Color.fromARGB(
                  pixels.getUint8(offset + 3),
                  pixels.getUint8(offset),
                  pixels.getUint8(offset + 1),
                  pixels.getUint8(offset + 2),
                );
              }

              expect(
                colorAt(130, 75).toARGB32(),
                clipped ? background.toARGB32() : isNot(background.toARGB32()),
                reason: clipped
                    ? 'Hidden rotated artwork must not leak into margins.'
                    : 'This fixture really paints beyond its source artboard.',
              );
              expect(
                colorAt(160, 75).toARGB32(),
                isNot(Colors.blue.toARGB32()),
                reason: 'The visible decoration must remain in the artwork.',
              );
              expect(colorAt(160, 75).toARGB32(), isNot(background.toARGB32()));
              expect(colorAt(160, 10).toARGB32(), Colors.blue.toARGB32());
              expect(colorAt(300, 75).toARGB32(), background.toARGB32());
            } finally {
              image.dispose();
            }
          });
          expect(tester.takeException(), isNull);
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        photo?.dispose();
      }
    },
  );
}

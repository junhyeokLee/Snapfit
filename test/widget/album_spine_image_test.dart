import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/album_spine_image.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/cover.dart';

Future<ui.Image> _coordinatePhoto({int alpha = 255}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var x = 0; x < 500; x++) {
    // The narrow binding gets a visible pattern; the flat front has unique UVs.
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), 0, 1, 800),
      Paint()..color = Color.fromARGB(alpha, x < 26 ? x * 8 : x % 256, 90, 140),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(500, 800);
  picture.dispose();
  return image;
}

Future<ByteData> _raster(
  ui.Image source,
  Size size, {
  required bool curve,
  Alignment alignment = Alignment.center,
  double zoom = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (curve) {
    AlbumSpineImagePainter(
      image: source,
      alignment: alignment,
      zoom: zoom,
    ).paint(canvas, size);
  } else {
    final anchor = Offset(
      size.width * (alignment.x + 1) / 2,
      size.height * (alignment.y + 1) / 2,
    );
    canvas.clipRect(Offset.zero & size);
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(zoom);
    canvas.translate(-anchor.dx, -anchor.dy);
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: source,
      fit: BoxFit.cover,
      alignment: alignment,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the rounded binding is monotonic and rejoins the untouched front', () {
    var previous = 0.0;
    for (var i = 1; i <= 1000; i++) {
      final u = AlbumSpineSurface.flatStart * i / 1000;
      final x = AlbumSpineSurface.projectedX(u);
      expect(x, greaterThan(previous));
      previous = x;
    }
    expect(AlbumSpineSurface.projectedX(0), closeTo(0, 1e-9));
    expect(AlbumSpineSurface.projectedX(.008), lessThan(.006));
    expect(
      AlbumSpineSurface.projectedX(AlbumSpineSurface.flatStart),
      AlbumSpineSurface.flatStart,
    );
    expect(AlbumSpineSurface.projectedX(.2), .2);
    expect(AlbumSpineSurface.edgeInset(AlbumSpineSurface.flatStart), 0);
  });

  for (final ratio in [.75, 1.0, 4 / 3]) {
    for (final width in [200.0, 500.0]) {
      test(
        'photo UVs actually wrap, with no front seam: $ratio / $width',
        () async {
          final source = await _coordinatePhoto();
          try {
            final size = Size(width, width / ratio);
            final curved = await _raster(source, size, curve: true);
            final flat = await _raster(source, size, curve: false);
            final row = size.height ~/ 2;
            final stride = size.width.ceil();
            var displaced = 0;
            for (var x = 1; x < width * .03; x++) {
              final index = (row * stride + x) * 4;
              if ((curved.getUint8(index) - flat.getUint8(index)).abs() > 3) {
                displaced++;
              }
              expect(curved.getUint8(index + 3), 255);
            }
            expect(displaced, greaterThan(width * .012));
            for (var x = 1; x < width - 1; x++) {
              expect(curved.getUint8((row * stride + x) * 4 + 3), 255);
            }
            // Including the mesh-to-front join: no blank seam, crop or alpha jump.
            for (
              var x = (width * AlbumSpineSurface.flatStart).ceil();
              x < width;
              x++
            ) {
              final index = (row * stride + x) * 4;
              for (var channel = 0; channel < 4; channel++) {
                expect(
                  (curved.getUint8(index + channel) -
                          flat.getUint8(index + channel))
                      .abs(),
                  lessThanOrEqualTo(1),
                  reason: 'Mesh sampling may round one RGB level differently.',
                );
              }
            }
          } finally {
            source.dispose();
          }
        },
      );
    }
  }

  for (final zoom in [1.0, 1.4, 3.0]) {
    for (final alignment in [
      Alignment.topLeft,
      Alignment.center,
      Alignment.bottomRight,
    ]) {
      test(
        'crop and zoom preserve the original front: $zoom / $alignment',
        () async {
          final source = await _coordinatePhoto();
          try {
            const size = Size(500, 400);
            final curved = await _raster(
              source,
              size,
              curve: true,
              zoom: zoom,
              alignment: alignment,
            );
            final flat = await _raster(
              source,
              size,
              curve: false,
              zoom: zoom,
              alignment: alignment,
            );
            for (final y in [30, 180, 370]) {
              for (var x = 22; x < 490; x += 13) {
                final index = (y * 500 + x) * 4;
                for (var c = 0; c < 4; c++) {
                  expect(
                    (curved.getUint8(index + c) - flat.getUint8(index + c))
                        .abs(),
                    lessThanOrEqualTo(1),
                  );
                }
              }
            }
          } finally {
            source.dispose();
          }
        },
      );
    }
  }

  test(
    'transparent artwork is not doubled across the mesh-to-front join',
    () async {
      final source = await _coordinatePhoto(alpha: 128);
      try {
        for (final width in [200.0, 500.0]) {
          final size = Size(width, width);
          final curved = await _raster(source, size, curve: true);
          final flat = await _raster(source, size, curve: false);
          final row = size.height ~/ 2;
          for (var x = 1; x < width - 1; x++) {
            final alpha = (row * width.toInt() + x) * 4 + 3;
            expect(curved.getUint8(alpha), flat.getUint8(alpha));
          }
        }
      } finally {
        source.dispose();
      }
    },
  );

  testWidgets(
    'only a closed full-bleed photo uses the surface, never text or frames',
    (tester) async {
      final photo = LayerModel(
        id: 'photo',
        type: LayerType.image,
        position: const Offset(14, 0),
        width: 486,
        height: 500,
        imageUrl: 'asset:photo.jpg',
      );
      final layers = [
        photo,
        photo.copyWith(id: 'framed', imageBackground: 'polaroid'),
        photo.copyWith(
          id: 'inset',
          position: const Offset(80, 80),
          width: 300,
          height: 300,
        ),
        photo.copyWith(id: 'text', type: LayerType.text),
      ];
      for (final wrap in [false, true]) {
        final curved = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: CoverLayout(
                  aspect: 1,
                  layers: layers,
                  isInteracting: false,
                  leftSpine: 14,
                  wrapSpineArtwork: wrap,
                  theme: CoverTheme.classic,
                  onCoverSizeChanged: (_) {},
                  sortedByZ: (layers) => layers,
                  buildImage: (_) => const SizedBox(),
                  buildText: (_) => const SizedBox(),
                  buildWrappedImage: (layer) {
                    curved.add(layer.id);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        expect(curved, wrap ? ['photo'] : isEmpty);
        expect(photo.position, const Offset(14, 0));
        expect(photo.width, 486);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'an arriving or replaced image updates without freezing a snapshot',
    (tester) async {
      final providers = (await tester.runAsync(() async {
        final result = <MemoryImage>[];
        for (var i = 0; i < 2; i++) {
          final image = await _coordinatePhoto();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          image.dispose();
          result.add(MemoryImage(bytes));
        }
        return result;
      }))!;
      ui.Image? previous;
      for (var i = 0; i < providers.length; i++) {
        final provider = providers[i];
        final zoom = i == 0 ? 1.0 : 2.0;
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 300,
              height: 400,
              child: AlbumSpineImage(image: provider, zoom: zoom),
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            provider,
            tester.element(find.byType(AlbumSpineImage)),
          );
        });
        await tester.pump();
        final paint = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<AlbumSpineImagePainter>()
            .single;
        expect(paint.zoom, zoom);
        if (previous != null) expect(paint.image, isNot(same(previous)));
        previous = paint.image;
        expect(find.byType(SnapshotWidget), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}

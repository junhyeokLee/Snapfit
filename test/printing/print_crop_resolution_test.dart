import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';

Map<String, dynamic> _spec() => {
  'id': 'REDP_200_SOFT',
  'specVersion': 'REDP_200_SOFT_REVIEW_V3_CROP_TEST',
  'pageCount': 20,
  'dpi': 300,
  'minimumPhotoPpi': 150,
  'colorSpace': 'sRGB',
  'interior': {'trimWidthMm': 200, 'trimHeightMm': 200, 'bleedMm': 5},
  'cover': {
    'widthMm': 417.22,
    'heightMm': 210,
    'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
    'front': {'xMm': 212.22, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
  },
};

Map<String, dynamic> _snapshot({
  required double zoom,
  double frameFraction = .762,
  String type = 'IMAGE',
  double rotation = 0,
  String frame = 'round',
}) => {
  'album': {
    'ratio': 1,
    'cover_layers_json': {
      'printProduct': {
        'id': 'REDP_200_SOFT',
        'trimWidthMm': 200,
        'trimHeightMm': 200,
      },
      'pages': [
        {
          'index': 0,
          'isCover': true,
          'layers': [],
          'backgroundColor': 0xffffffff,
        },
        {
          'index': 1,
          'isCover': false,
          'layers': [
            {
              'id': 'crop-photo',
              'type': type,
              'x': .1,
              'y': .1,
              'width': frameFraction,
              'height': frameFraction,
              'scale': 1,
              'rotation': rotation,
              'opacity': 1,
              'zIndex': 0,
              'payload': {
                'originalUrl': 'memory:crop-source',
                'previewUrl': 'memory:thumbnail',
                'imageBackground': frame,
                'imageZoom': zoom,
                'imageOffsetRatio': {'x': .2, 'y': -.15},
              },
            },
          ],
        },
      ],
    },
  },
  'pages': [],
};

Future<Uint8List> _sourceImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xff234e70),
  );
  canvas.drawRect(
    Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xfff29e4c),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '150ppi unzoomed photograph passes but its 4x crop is rejected at 37.5ppi',
    (tester) async {
      await tester.runAsync(() async {
        final source = await _sourceImage(900, 900);
        final exporter = AlbumPrintExporter(assetLoader: (_) async => source);
        final spec = PrintVendorSpec.fromJson(_spec());
        final plain = await exporter.verify(
          snapshot: _snapshot(zoom: 1),
          spec: spec,
        );
        final resolution = (plain['imageResolution'] as List).single as Map;
        expect(resolution['effectivePpi'], 150.0);
        expect(resolution['cropZoom'], 1.0);
        await expectLater(
          exporter.verify(snapshot: _snapshot(zoom: 4), spec: spec),
          throwsA(
            isA<PrintPreflightException>()
                .having((e) => e.code, 'code', 'print_image_resolution_too_low')
                .having(
                  (e) => e.details.last,
                  'visible crop resolution',
                  '38ppi',
                ),
          ),
        );
      });
    },
  );

  testWidgets(
    'sufficient cropped originals retain 4x decode pixels despite rotation and frame alignment',
    (tester) async {
      await tester.runAsync(() async {
        final source = await _sourceImage(3600, 3600);
        final exporter = AlbumPrintExporter(assetLoader: (_) async => source);
        final spec = PrintVendorSpec.fromJson(_spec());
        Future<Map> row(double zoom, {double rotation = 0}) async {
          final report = await exporter.verify(
            snapshot: _snapshot(
              zoom: zoom,
              frameFraction: .254,
              rotation: rotation,
            ),
            spec: spec,
          );
          return (report['imageResolution'] as List).single as Map;
        }

        final plain = await row(1);
        final crop = await row(4, rotation: 33);
        expect(plain['effectivePpi'], 1800.0);
        expect(crop['effectivePpi'], 450.0);
        expect(plain['decodedWidthPx'], closeTo(600, 1));
        expect(plain['decodedHeightPx'], closeTo(600, 1));
        expect(crop['decodedWidthPx'], closeTo(2400, 1));
        expect(crop['decodedHeightPx'], closeTo(2400, 1));
      });
    },
  );

  testWidgets(
    'cover fitting retains enough pixels for a rectangular original crop',
    (tester) async {
      await tester.runAsync(() async {
        final source = await _sourceImage(4800, 2400);
        final exporter = AlbumPrintExporter(assetLoader: (_) async => source);
        final report = await exporter.verify(
          snapshot: _snapshot(zoom: 4, frameFraction: .254),
          spec: PrintVendorSpec.fromJson(_spec()),
        );
        final row = (report['imageResolution'] as List).single as Map;
        // BoxFit.cover uses the short side for a square photo frame.
        expect(row['effectivePpi'], 300.0);
        expect(row['decodedWidthPx'], 4800);
        expect(row['decodedHeightPx'], 2400);
      });
    },
  );

  testWidgets('sticker containment ignores photograph zoom metadata', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await _sourceImage(3600, 1800);
      final report = await AlbumPrintExporter(assetLoader: (_) async => source)
          .verify(
            snapshot: _snapshot(zoom: 4, frameFraction: .254, type: 'STICKER'),
            spec: PrintVendorSpec.fromJson(_spec()),
          );
      final row = (report['imageResolution'] as List).single as Map;
      expect(row['cropZoom'], 1.0);
      expect(row['effectivePpi'], 1800.0);
      expect(row['decodedWidthPx'], closeTo(600, 1));
      expect(row['decodedHeightPx'], closeTo(300, 1));
    });
  });

  testWidgets('photo crop does not magnify its separate printed frame asset', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final original = await _sourceImage(3600, 3600);
      final frame = await _sourceImage(900, 900);
      final requested = <String>[];
      final report =
          await AlbumPrintExporter(
            assetLoader: (source) async {
              requested.add(source);
              return source.startsWith('asset:') ? frame : original;
            },
          ).verify(
            snapshot: _snapshot(zoom: 4, frame: 'materialLaceMount'),
            spec: PrintVendorSpec.fromJson(_spec()),
          );
      expect(
        requested,
        contains('asset:assets/sticker/studio/material_lace.png'),
      );
      final rows = (report['imageResolution'] as List).cast<Map>();
      final frameRow = rows.singleWhere((row) => row['widthPx'] == 900);
      final photoRow = rows.singleWhere((row) => row['widthPx'] == 3600);
      expect(frameRow['cropZoom'], 1.0);
      expect(frameRow['effectivePpi'], 150.0);
      expect(photoRow['cropZoom'], 4.0);
      expect(photoRow['effectivePpi'], 150.0);
    });
  });
}

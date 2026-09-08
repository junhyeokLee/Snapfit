import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';

Map<String, dynamic> specJson({int pages = 20}) => {
  'id': 'redprinting-softcover-200',
  'specVersion': 'test-official-geometry-v1',
  'verified': false,
  'dpi': 300,
  'minimumPhotoPpi': 150,
  'colorSpace': 'sRGB',
  'pageCount': pages,
  'minInteriorPages': 20,
  'maxInteriorPages': 80,
  'pageMultiple': 2,
  'interior': {'trimWidthMm': 200, 'trimHeightMm': 200, 'bleedMm': 5},
  'cover': {
    'widthMm': 410 + .52 + .67 * pages / 2,
    'heightMm': 210,
    'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 200},
    'front': {
      'xMm': 205 + .52 + .67 * pages / 2,
      'yMm': 5,
      'widthMm': 200,
      'heightMm': 200,
    },
  },
};

Map<String, dynamic> photo({
  String? original = 'memory:original',
  double scale = 1,
}) => {
  'id': 'photo',
  'type': 'IMAGE',
  'x': .1,
  'y': .2,
  'width': .8,
  'height': .5,
  'scale': scale,
  'rotation': 8,
  'zIndex': 0,
  'opacity': 1,
  'payload': {
    'originalUrl': original,
    'previewUrl': 'memory:thumbnail',
    'imageBackground': 'round',
    'imageOffsetRatio': {'x': .2, 'y': 0},
  },
};

Map<String, dynamic> snapshot({
  String? original = 'memory:original',
  double scale = 1,
}) => {
  'album': {
    'ratio': '0.75',
    'cover_layers_json': jsonEncode({
      'pages': [
        {
          'index': 0,
          'isCover': true,
          'backgroundColor': 0xffffefdf,
          'layers': [
            photo(original: original, scale: scale),
            {
              'id': 'title',
              'type': 'TEXT',
              'x': .1,
              'y': .08,
              'width': .8,
              'height': .1,
              'scale': 1,
              'rotation': 0,
              'zIndex': 1,
              'payload': {
                'text': '우리의 여름 기록',
                'textAlign': 'center',
                'textStyle': {
                  'fontFamily': 'NotoSans',
                  'fontSizeRatio': .06,
                  'color': '#FF263D35',
                },
              },
            },
            {
              'id': 'star',
              'type': 'DECORATION',
              'x': .67,
              'y': .7,
              'width': .2,
              'height': .15,
              'scale': 1,
              'rotation': 20,
              'zIndex': 2,
              'payload': {'imageBackground': 'stickerBlueStar'},
            },
          ],
        },
        {
          'index': 1,
          'isCover': false,
          'backgroundColor': 0xffe2ecf1,
          'layers': [photo(original: original, scale: scale)],
        },
      ],
    }),
  },
  // A stale table row must not replace the whole document stored above.
  'pages': [
    {'page_index': 99, 'layers_json': '{}'},
  ],
};

Future<ui.Image> sourceImage({int size = 1800}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xff173f5f),
  );
  canvas.drawRect(
    Rect.fromLTWH(size / 2, 0, size / 2, size.toDouble()),
    Paint()..color = const Color(0xffed553b),
  );
  canvas.drawCircle(
    Offset(size * .6, size * .4),
    size * .2,
    Paint()..color = const Color(0xfff6d55c),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('full album snapshot wins; strips only decorative cover spine', () {
    final doc = PrintAlbumDocument.fromSnapshot(snapshot());
    expect(doc.pages.length, 2);
    expect(doc.interiors.length, 1);
    expect(doc.cover.canvasSize.width, 486);
    expect(doc.interiors.first.canvasSize, const Size(500, 500 / .75));
    expect(doc.cover.layers.first.position.dx, closeTo(48.6, .001));
    expect(
      doc.cover.layers.first.imageOffset!.dx,
      closeTo(doc.cover.layers.first.width * .2, .001),
    );
  });
  test('rejects malformed spec, duplicate pages and page limits', () {
    expect(
      () => PrintVendorSpec.fromJson({...specJson(), 'pageMultiple': 0}),
      throwsFormatException,
    );
    expect(
      () => PrintVendorSpec.fromJson(specJson(pages: 21)),
      throwsFormatException,
    );
    final invalid = snapshot();
    invalid['album']['cover_layers_json'] =
        '{"pages":[{"index":0,"isCover":true,"layers":[]},{"index":0,"isCover":false,"layers":[]}]}';
    expect(
      () => PrintAlbumDocument.fromSnapshot(invalid),
      throwsFormatException,
    );
  });
  test(
    'legacy zero-based table pages stay after the separately stored cover',
    () {
      final doc = PrintAlbumDocument.fromSnapshot({
        'album': {
          'ratio': '1',
          'cover_layers_json': '{"layers":[]}',
          'cover_theme': 'classic2',
        },
        'pages': [
          {
            'page_index': 1,
            'layers_json': '{"layers":[],"backgroundColor":4294901760}',
          },
          {'page_index': 0, 'layers_json': '{"layers":[]}'},
        ],
      });
      expect(doc.pages.map((p) => p.index), [0, 1, 2]);
      expect(doc.cover.backgroundColor.toARGB32(), 0xff232526);
      expect(doc.interiors.last.backgroundColor.toARGB32(), 0xffff0000);
    },
  );
  testWidgets(
    'offscreen contain retains the requested media size without stretching',
    (tester) async {
      await tester.runAsync(() async {
        final image = await renderPrintWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: Colors.white,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 100,
                  height: 200,
                  child: ColoredBox(color: Color(0xffff0000)),
                ),
              ),
            ),
          ),
          const Size(200, 200),
          1,
        );
        try {
          expect(image.width, 200);
          expect(image.height, 200);
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          List<int> pixel(int x, int y) =>
              rgba.sublist((y * 200 + x) * 4, (y * 200 + x) * 4 + 4);
          expect(pixel(10, 100), [255, 255, 255, 255]);
          expect(pixel(100, 100), [255, 0, 0, 255]);
          expect(pixel(190, 100), [255, 255, 255, 255]);
        } finally {
          image.dispose();
        }
      });
    },
  );
  testWidgets('render failures abort instead of printing an ErrorWidget', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await expectLater(
        renderPrintWidget(
          Builder(
            builder: (_) => throw StateError('deliberate-render-failure'),
          ),
          const Size(100, 100),
          1,
        ),
        throwsA(
          isA<PrintPreflightException>().having(
            (e) => e.code,
            'code',
            'print_render_failed',
          ),
        ),
      );
    });
  });
  testWidgets(
    'refuses thumbnails and fails low resolution even at 300 output dpi',
    (tester) async {
      await tester.runAsync(() async {
        final source = await sourceImage(size: 40);
        final bytes = (await source.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        source.dispose();
        final exporter = AlbumPrintExporter(assetLoader: (_) async => bytes);
        final spec = PrintVendorSpec.fromJson(specJson());
        await expectLater(
          exporter.verify(snapshot: snapshot(original: null), spec: spec),
          throwsA(
            isA<PrintPreflightException>().having(
              (e) => e.code,
              'code',
              'print_original_missing',
            ),
          ),
        );
        await expectLater(
          exporter.verify(snapshot: snapshot(), spec: spec),
          throwsA(
            isA<PrintPreflightException>().having(
              (e) => e.code,
              'code',
              'print_image_resolution_too_low',
            ),
          ),
        );
        await expectLater(
          AlbumPrintExporter(
            assetLoader: (_) async => throw StateError('missing'),
          ).verify(snapshot: snapshot(), spec: spec),
          throwsA(
            isA<PrintPreflightException>().having(
              (e) => e.code,
              'code',
              'print_original_load_failed',
            ),
          ),
        );
      });
    },
  );
  testWidgets(
    'many high resolution originals decode to print need while retaining original PPI',
    (tester) async {
      await tester.runAsync(() async {
        final source = await sourceImage(size: 3600);
        final bytes = (await source.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        source.dispose();
        final frozen = snapshot();
        final document =
            jsonDecode(frozen['album']['cover_layers_json'] as String) as Map;
        document['pages'][0]['layers'] = [
          for (int index = 0; index < 12; index++)
            {
              ...photo(original: 'memory:$index'),
              'id': 'tiny-$index',
              'x': (index % 4) * .2,
              'y': (index ~/ 4) * .2,
              'width': .1,
              'height': .1,
            },
        ];
        document['pages'][1]['layers'] = [];
        frozen['album']['cover_layers_json'] = jsonEncode(document);
        final requested = <String>[];
        final report =
            await AlbumPrintExporter(
              assetLoader: (url) async {
                requested.add(url);
                return bytes;
              },
            ).verify(
              snapshot: frozen,
              spec: PrintVendorSpec.fromJson(specJson()),
              sourceUrls: {
                'memory:0': 'https://private.example/signed-original',
              },
            );
        final images = (report['imageResolution'] as List).cast<Map>();
        expect(images.length, 12);
        expect(requested, contains('https://private.example/signed-original'));
        expect(
          images.every(
            (row) => row['widthPx'] == 3600 && row['heightPx'] == 3600,
          ),
          true,
        );
        expect(images.every((row) => row['effectivePpi'] > 4000), true);
        expect(
          images.every(
            (row) =>
                row['decodedWidthPx'] < 300 && row['decodedHeightPx'] < 300,
          ),
          true,
        );
      });
    },
  );
  testWidgets(
    'exports actual layered artwork, geometry, ICC and paid blank pages',
    (tester) async {
      await tester.runAsync(() async {
        final source = await sourceImage();
        final bytes = (await source.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        source.dispose();
        final requested = <String>[];
        final exporter = AlbumPrintExporter(
          assetLoader: (source) async {
            requested.add(source);
            return bytes;
          },
        );
        final output = await exporter.generate(
          snapshot: snapshot(),
          spec: PrintVendorSpec.fromJson(specJson()),
        );
        expect(requested, everyElement('memory:original'));
        expect(output.interiorPageCount, 20);
        expect(output.report['blankPagesAdded'], 19);
        expect(output.report['iccProfileEmbedded'], true);
        expect(
          output.report['warnings'],
          contains('page_0_fit_contain_with_margins'),
        );
        expect(
          output.report['warnings'],
          contains('vendor_spec_requires_review'),
        );
        final cover = latin1.decode(output.coverPdf);
        final interior = latin1.decode(output.interiorPdf);
        expect(RegExp(r'/Type /Page\b').allMatches(cover).length, 1);
        expect(RegExp(r'/Type /Page\b').allMatches(interior).length, 20);
        expect(cover, contains('/MediaBox [0 0 1182.67087 595.27559]'));
        expect(
          interior,
          contains('/TrimBox [14.17323 14.17323 581.10236 581.10236]'),
        );
        expect(interior, contains('/Width 2481 /Height 2481'));
        expect(cover, contains('/ICCBased'));
        expect(cover, contains('/DCTDecode'));
        expect(output.interiorPdf.length, lessThan(10 * 1024 * 1024));
        final directory = Directory('output/pdf/print-export-proof')
          ..createSync(recursive: true);
        File('${directory.path}/cover.pdf').writeAsBytesSync(output.coverPdf);
        File(
          '${directory.path}/interior.pdf',
        ).writeAsBytesSync(output.interiorPdf);
        File('${directory.path}/report.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(output.report),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

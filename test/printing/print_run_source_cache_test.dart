import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_run_source_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'identical frozen URI coalesces one in-flight fetch and preserves original bytes',
    () async {
      var calls = 0;
      final wait = Completer<Uint8List>();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final cache = PrintRunSourceCache((_) {
        calls++;
        return wait.future;
      });
      final first = cache.load(
        'supabase://album-assets/owner/albums/photo.png',
      );
      final second = cache.load(
        'supabase://album-assets/owner/albums/photo.png',
      );
      wait.complete(bytes);
      expect(identical(await first, bytes), isTrue);
      expect(identical(await second, bytes), isTrue);
      expect(
        identical(
          await cache.load('supabase://album-assets/owner/albums/photo.png'),
          bytes,
        ),
        isTrue,
      );
      expect(calls, 1);
      expect(cache.retainedBytes, 3);
      cache.clear();
      expect(cache.retainedBytes, 0);
    },
  );
  test(
    'over-entry-budget originals are read unchanged but never retained',
    () async {
      var calls = 0;
      final original = Uint8List(5);
      final cache = PrintRunSourceCache(
        (_) async {
          calls++;
          return original;
        },
        maxEntryBytes: 4,
        maxTotalBytes: 6,
      );
      expect(identical(await cache.load('large'), original), isTrue);
      expect(identical(await cache.load('large'), original), isTrue);
      expect(calls, 2);
      expect(cache.retainedBytes, 0);
    },
  );
  test(
    'different originals obey the complete run budget and evict the least recently used',
    () async {
      final calls = <String, int>{};
      final cache = PrintRunSourceCache(
        (source) async {
          calls[source] = (calls[source] ?? 0) + 1;
          return Uint8List(3);
        },
        maxEntryBytes: 4,
        maxTotalBytes: 6,
      );
      await cache.load('a');
      await cache.load('b');
      await cache.load('b');
      await cache.load('c');
      expect(cache.retainedBytes, 6);
      await cache.load('b');
      expect(calls['b'], 1);
      await cache.load('a');
      expect(calls['a'], 2);
      expect(cache.retainedBytes, lessThanOrEqualTo(6));
    },
  );
  test(
    'cleanup prevents late requests from retaining bytes in a finished run',
    () async {
      var calls = 0;
      final wait = Completer<Uint8List>();
      final cache = PrintRunSourceCache((_) {
        calls++;
        return calls == 1 ? wait.future : Future.value(Uint8List(3));
      });
      final pending = cache.load('owned');
      cache.clear();
      wait.complete(Uint8List(3));
      await pending;
      expect(cache.retainedBytes, 0);
      await cache.load('owned');
      expect(calls, 2);
    },
  );
  test('failed downloads are not reused as successful cached data', () async {
    var calls = 0;
    final cache = PrintRunSourceCache((_) async {
      if (++calls == 1) throw StateError('network');
      return Uint8List(3);
    });
    await expectLater(cache.load('owned'), throwsStateError);
    await cache.load('owned');
    expect(calls, 2);
  });
  testWidgets(
    'verify and generate each load a repeated private URI once, while every page retains PPI checks',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff234e70), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(64, 64);
        picture.dispose();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        const original = 'supabase://album-assets/owner/albums/photo.png';
        const signed = 'https://example.test/owner/photo.png?token=frozen-run';
        final snapshot = <String, dynamic>{
          'album': {
            'id': 69,
            'ratio': '1',
            'cover_theme': 'classic',
            'cover_layers_json': {
              'pages': [
                {'index': 0, 'isCover': true, 'layers': []},
                for (var index = 1; index <= 2; index++)
                  {
                    'index': index,
                    'isCover': false,
                    'layers': [
                      {
                        'id': 'photo-$index',
                        'type': 'IMAGE',
                        'x': .1,
                        'y': .1,
                        'width': .1,
                        'height': .1,
                        'scale': 1,
                        'rotation': 0,
                        'opacity': 1,
                        'zIndex': 0,
                        'payload': {
                          'originalUrl': original,
                          'imageBackground': 'round',
                          'imageZoom': 1,
                        },
                      },
                    ],
                  },
              ],
            },
          },
          'pages': [],
        };
        final spec = PrintVendorSpec.fromJson({
          'id': 'CACHE_TEST',
          'specVersion': 'CACHE_ONLY_V1',
          'pageCount': 2,
          'minInteriorPages': 1,
          'maxInteriorPages': 80,
          'pageMultiple': 1,
          'dpi': 300,
          'minimumPhotoPpi': 150,
          'colorSpace': 'sRGB',
          'interior': {'trimWidthMm': 10, 'trimHeightMm': 10, 'bleedMm': 1},
          'cover': {
            'widthMm': 23,
            'heightMm': 12,
            'back': {'xMm': 1, 'yMm': 1, 'widthMm': 10, 'heightMm': 10},
            'front': {'xMm': 12, 'yMm': 1, 'widthMm': 10, 'heightMm': 10},
          },
        });
        var sourceLoads = 0;
        final exporter = AlbumPrintExporter(
          loadOnlyUsedFonts: true,
          assetLoader: (source) async {
            expect(source, signed);
            sourceLoads++;
            return bytes;
          },
        );
        final first = await exporter.verify(
          snapshot: snapshot,
          spec: spec,
          sourceUrls: {original: signed},
        );
        expect(sourceLoads, 1);
        expect((first['imageResolution'] as List).map((e) => e['page']), [
          1,
          2,
        ]);
        final second = await exporter.verify(
          snapshot: snapshot,
          spec: spec,
          sourceUrls: {original: signed},
        );
        expect(sourceLoads, 2);
        expect((second['imageResolution'] as List).length, 2);
        final pdf = await exporter.generate(
          snapshot: snapshot,
          spec: spec,
          sourceUrls: {original: signed},
        );
        expect(sourceLoads, 3);
        expect(pdf.interiorPageCount, 2);
        expect((pdf.report['imageResolution'] as List).length, 2);
        expect(pdf.report['dpi'], 300);
        expect(pdf.report['imageEncoding'], 'JPEG quality 95');
        expect(pdf.report['iccProfileEmbedded'], isTrue);
      });
    },
  );
}

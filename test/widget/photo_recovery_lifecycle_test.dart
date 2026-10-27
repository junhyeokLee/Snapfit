import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

class _Photos extends Fake implements BaseCacheManager, ImageCacheManager {
  final requests = <String>[];
  final failures = <String>{};
  final gates = <String, Completer<void>>{};
  bool failAll = false;
  final file = MemoryFileSystem().file('/photo.png')
    ..writeAsBytesSync(browserPhotoFixture());

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) => getFileStream(
    url,
    key: key,
    headers: headers,
    withProgress: withProgress,
  );

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requests.add(url);
    final gate = gates[url];
    if (gate != null) await gate.future;
    if (failAll || failures.contains(url)) throw StateError('unavailable:$url');
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(hours: 1)),
      url,
    );
  }
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);
Widget _box(Widget child) => SizedBox(width: 140, height: 140, child: child);
Finder get _pixels =>
    find.byWidgetPredicate((w) => w is RawImage && w.image != null);

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 120 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

void main() {
  setUp(() {
    MemoryPressureCaches.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    MemoryPressureCaches.clear();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'visible twins and reader preparation share a failed URL renewal and decoded pixels',
    (tester) async {
      final cache = _Photos();
      var resolutions = 0;
      const old = 'https://photo.test/old';
      const fresh = 'https://photo.test/fresh';
      SnapfitImage photo() => SnapfitImage(
        urlOrGs: 'supabase://album-assets/shared/photo',
        cacheManager: cache,
        memCacheWidth: 128,
        memCacheHeight: 128,
        resolveStorageUrlForTesting: (_) async =>
            ++resolutions == 1 ? old : fresh,
        imageBuilder: (_, provider) => Image(image: provider),
      );
      await tester.pumpWidget(_app(_box(photo())));
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      cache.failures.add(old);
      final oldGate = Completer<void>();
      cache.gates[old] = oldGate;
      final gate = Completer<void>();
      cache.gates[fresh] = gate;
      final contextKey = GlobalKey();
      await tester.pumpWidget(
        _app(
          Row(
            key: contextKey,
            mainAxisSize: MainAxisSize.min,
            children: [_box(photo()), _box(photo())],
          ),
        ),
      );
      final prepared = photo().prepareImage(contextKey.currentContext!);
      await _until(
        tester,
        () => cache.requests.where((url) => url == old).length == 2,
      );
      // Keep the failure pending until both visible listeners and preparation
      // have joined it; this exercises actual concurrent work, not a later retry
      // after the cache has already evicted an immediately failed stream.
      await tester.pump();
      oldGate.complete();
      await _until(tester, () => cache.requests.contains(fresh));
      expect(resolutions, 2);
      gate.complete();
      await _until(tester, () => _pixels.evaluate().length == 2);
      final provider = (await prepared)!;
      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).width, 128);
      expect(cache.requests.where((url) => url == old), hasLength(2));
      expect(cache.requests.where((url) => url == fresh), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native permanent failures stop after one refresh; explicit retry remains usable',
    (tester) async {
      final cache = _Photos()..failAll = true;
      var resolutions = 0;
      await tester.pumpWidget(
        _app(
          _box(
            SnapfitImage(
              urlOrGs: 'supabase://album-assets/limited/photo',
              cacheManager: cache,
              resolveStorageUrlForTesting: (_) async =>
                  'https://photo.test/attempt-${++resolutions}',
              imageBuilder: (_, __) => const Text('recovered'),
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('storage-image-retry'));
      await _until(tester, () => retry.evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 5));
      expect(resolutions, 2);
      expect(cache.requests, hasLength(2));
      cache.failAll = false;
      await tester.tap(retry);
      await _until(tester, () => find.text('recovered').evaluate().isNotEmpty);
      expect(resolutions, 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preparing while fallback downloads does not request a known-bad preview again',
    (tester) async {
      final cache = _Photos();
      const preview = 'https://photo.test/failed-preview';
      const original = 'https://photo.test/pending-original';
      cache.failures.add(preview);
      final gate = Completer<void>();
      cache.gates[original] = gate;
      final photo = SnapfitImage(
        urlOrGs: preview,
        fallbackSources: const [preview, original],
        cacheManager: cache,
        memCacheWidth: 128,
        imageBuilder: (_, provider) => Image(image: provider),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(SizedBox(key: key, width: 140, height: 140, child: photo)),
      );
      await _until(tester, () => cache.requests.contains(original));
      final prepared = photo.prepareImage(key.currentContext!);
      // Give preparation a chance to join the already-downloading original.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      gate.complete();
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(await prepared, isNotNull);
      expect(cache.requests, [preview, original]);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallback is reused on route return and decoded pixels remain bounded',
    (tester) async {
      final cache = _Photos();
      const preview = 'https://photo.test/reopen-preview';
      const original = 'https://photo.test/reopen-original';
      cache.failures.add(preview);
      final imageCache = PaintingBinding.instance.imageCache;
      final oldBudget = imageCache.maximumSizeBytes;
      imageCache.maximumSizeBytes = 2 * 1024 * 1024;
      addTearDown(() => imageCache.maximumSizeBytes = oldBudget);
      for (var i = 0; i < 8; i++) {
        await tester.pumpWidget(
          _app(
            _box(
              SnapfitImage(
                urlOrGs: preview,
                fallbackSources: const [original],
                cacheManager: cache,
                memCacheWidth: 128,
                memCacheHeight: 128,
              ),
            ),
          ),
        );
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        final provider =
            tester.widget<Image>(find.byType(Image).last).image as ResizeImage;
        expect(provider.width, 128);
        expect(provider.height, 128);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(imageCache.liveImageCount, 0);
        expect(imageCache.pendingImageCount, 0);
        expect(imageCache.currentSizeBytes, lessThanOrEqualTo(2 * 1024 * 1024));
      }
      expect(cache.requests, [preview, original]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late failed renewal cannot replace a new photo or report an unhandled error',
    (tester) async {
      final cache = _Photos()..failAll = true;
      final renewal = Completer<String>();
      var resolutions = 0;
      await tester.pumpWidget(
        _app(
          _box(
            SnapfitImage(
              urlOrGs: 'supabase://album-assets/replaced/photo',
              cacheManager: cache,
              resolveStorageUrlForTesting: (_) => ++resolutions == 1
                  ? Future.value('https://photo.test/replaced-old')
                  : renewal.future,
              imageBuilder: (_, __) => const Text('old photo'),
            ),
          ),
        ),
      );
      await _until(tester, () => resolutions == 2);
      cache.failAll = false;
      await tester.pumpWidget(
        _app(
          _box(
            SnapfitImage(
              urlOrGs: 'https://photo.test/new-source',
              cacheManager: cache,
              imageBuilder: (_, __) => const Text('new photo'),
            ),
          ),
        ),
      );
      renewal.completeError(StateError('expired-after-dispose'));
      await _until(tester, () => find.text('new photo').evaluate().isNotEmpty);
      expect(find.text('old photo'), findsNothing);
      expect(resolutions, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a remembered original can fall back to its repaired preview on a later visit',
    (tester) async {
      final cache = _Photos();
      const preview = 'https://photo.test/repaired-preview';
      const original = 'https://photo.test/later-failed-original';
      cache.failures.add(preview);
      Widget photo() => _app(
        _box(
          SnapfitImage(
            urlOrGs: preview,
            fallbackSources: const [original],
            cacheManager: cache,
            memCacheWidth: 128,
            memCacheHeight: 128,
          ),
        ),
      );
      await tester.pumpWidget(photo());
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      cache.failures.remove(preview);
      cache.failures.add(original);
      await tester.pumpWidget(photo());
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(cache.requests, [preview, original, original, preview]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing during a fallback download never starts its remaining alternative',
    (tester) async {
      final cache = _Photos()..failAll = true;
      final gate = Completer<void>();
      const active = 'https://photo.test/closing-original';
      cache.gates[active] = gate;
      await tester.pumpWidget(
        _app(
          _box(
            SnapfitImage(
              urlOrGs: 'https://photo.test/closing-preview',
              fallbackSources: const [
                active,
                'https://photo.test/must-not-start',
              ],
              cacheManager: cache,
            ),
          ),
        ),
      );
      await _until(tester, () => cache.requests.contains(active));
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await _until(
        tester,
        () => PaintingBinding.instance.imageCache.pendingImageCount == 0,
      );
      expect(cache.requests, ['https://photo.test/closing-preview', active]);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a bundled original can recover a remote preview using the same decode bound',
    (tester) async {
      final cache = _Photos()..failAll = true;
      await tester.pumpWidget(
        _app(
          _box(
            SnapfitImage(
              urlOrGs: 'https://photo.test/bundled-preview',
              cacheManager: cache,
              fallbackSources: const ['asset:assets/snapfit_home_square.jpg'],
              memCacheWidth: 128,
              memCacheHeight: 128,
            ),
          ),
        ),
      );
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(cache.requests, ['https://photo.test/bundled-preview']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

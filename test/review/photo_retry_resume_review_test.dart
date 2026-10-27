import 'dart:async';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

class _Photos extends Fake implements BaseCacheManager, ImageCacheManager {
  final requests = <String>[];
  final failures = <String>{};
  final gates = <String, Completer<void>>{};
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
  }) => getFileStream(url, key: key, headers: headers);

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requests.add(url);
    await gates[url]?.future;
    if (failures.contains(url)) throw StateError('unavailable:$url');
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
Finder get _pixels => find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 120 && !ready(); i++) {
    await _frames(tester, 1);
  }
  expect(ready(), isTrue);
}

void _clear() {
  MemoryPressureCaches.clear();
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

void main() {
  setUp(_clear);
  tearDown(_clear);

  testWidgets(
    'rapid retry hiding rotation and preparation share one successful recovery and release images',
    (tester) async {
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        previous?.call(image);
      };
      addTearDown(() => ui.Image.onCreate = previous);
      final photos = _Photos();
      const old = 'https://review.test/retry-hidden-old';
      const renewed = 'https://review.test/retry-hidden-renewed';
      const retryUrl = 'https://review.test/retry-hidden-success';
      photos.failures.addAll([old, renewed]);
      final signed = Completer<String>();
      final active = ValueNotifier(true);
      final width = ValueNotifier(128);
      addTearDown(active.dispose);
      addTearDown(width.dispose);
      var resolutions = 0;
      SnapfitImage photo(int width) => SnapfitImage(
        urlOrGs: 'supabase://album-assets/retry-hide-rotate/photo',
        cacheManager: photos,
        memCacheWidth: width,
        memCacheHeight: width,
        resolveStorageUrlForTesting: (_) {
          resolutions++;
          if (resolutions == 1) return Future.value(old);
          if (resolutions == 2) return Future.value(renewed);
          return signed.future;
        },
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, enabled, __) => TickerMode(
              enabled: enabled,
              child: ValueListenableBuilder<int>(
                valueListenable: width,
                builder: (_, width, __) => SizedBox(
                  key: key,
                  width: 140,
                  height: 140,
                  child: photo(width),
                ),
              ),
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('storage-image-retry'));
      await _until(tester, () => retry.evaluate().isNotEmpty);
      expect(resolutions, 2);
      for (var i = 0; i < 8; i++) {
        await tester.tap(retry);
      }
      expect(resolutions, 3);
      active.value = false;
      await tester.pump();
      width.value = 256;
      await tester.pump();
      signed.complete(retryUrl);
      await _frames(tester, 10);
      expect(photos.requests, [old, renewed]);
      active.value = true;
      await tester.pump();
      final prepared = photo(256).prepareImage(key.currentContext!);
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(await prepared, isNotNull);
      for (var i = 0; i < 4; i++) {
        active.value = false;
        await tester.pump();
        active.value = true;
        await tester.pump();
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
      }
      expect(resolutions, 3);
      expect(photos.requests, [old, renewed, retryUrl]);
      await tester.pumpWidget(const SizedBox());
      _clear();
      await _frames(tester);
      expect(created.where((image) => !image.debugDisposed), isEmpty);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final refresh in [false, true])
    testWidgets(
      'review: hidden reader rotation ${refresh ? 'with a refreshed photo' : 'without data change'} defers live-image work',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final photos = _Photos();
        CachedNetworkImageProvider.defaultCacheManager = photos;
        final pages = PageController();
        final canvas = coverCanvasBaseSize(defaultCoverSize);
        final interaction = LayerInteractionManager.printPreview(() => canvas);
        addTearDown(pages.dispose);
        addTearDown(interaction.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final readerKey = GlobalKey();
        final revision = ValueNotifier(0);
        addTearDown(revision.dispose);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigator,
              home: Scaffold(
                body: ValueListenableBuilder<int>(
                  valueListenable: revision,
                  builder: (_, revision, __) => AlbumReaderSinglePageView(
                    key: readerKey,
                    allPages: [
                      for (var i = 0; i < 3; i++)
                        AlbumPage(
                          id: 'offstage-$i',
                          pageIndex: i,
                          isCover: i == 0,
                          layers: [
                            LayerModel(
                              id: 'photo-$i',
                              type: LayerType.image,
                              position: Offset.zero,
                              width: canvas.width,
                              height: canvas.height,
                              imageUrl:
                                  'https://review.test/offstage-photo-$revision-$i',
                            ),
                          ],
                        ),
                    ],
                    selectedCover: defaultCoverSize,
                    coverTheme: CoverTheme.classic,
                    pageController: pages,
                    interaction: interaction,
                    layerBuilder: LayerBuilder(interaction, () => canvas),
                    canvasKey: GlobalKey(),
                    openingCoverKey: GlobalKey(),
                    onCanvasSizeChanged: (_) {},
                    onPageChanged: (_) {},
                    onStateChanged: () {},
                    focusMode: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await _until(
          tester,
          () =>
              find.byType(BookFlip).evaluate().isNotEmpty &&
              tester
                  .widget<BookFlip>(find.byType(BookFlip))
                  .controller!
                  .isReady,
        );
        unawaited(
          navigator.currentState!.push<void>(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  const Scaffold(body: Center(child: Text('covering route'))),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(TickerMode.of(readerKey.currentContext!), isFalse);
        final before = List<String>.of(photos.requests);
        if (refresh) revision.value = 1;
        tester.view.physicalSize = const Size(844, 390);
        await tester.pump();
        await _frames(tester);
        final after = List<String>.of(photos.requests);
        navigator.currentState!.pop();
        await tester.pump();
        await _until(
          tester,
          () =>
              find.byType(BookFlip).evaluate().isNotEmpty &&
              tester
                  .widget<BookFlip>(find.byType(BookFlip))
                  .controller!
                  .isReady,
        );
        expect(_pixels, findsWidgets);
        if (refresh) {
          for (var i = 0; i < 3; i++) {
            expect(
              photos.requests.where(
                (url) => url == 'https://review.test/offstage-photo-1-$i',
              ),
              hasLength(1),
            );
          }
        }
        await tester.pumpWidget(const SizedBox());
        _clear();
        await _frames(tester);
        expect(tester.takeException(), isNull);
        expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
        expect(
          after,
          before,
          reason:
              'Rotating a maintained hidden reader must not load another cover resolution',
        );
      },
    );

  testWidgets(
    'review: a storage photo mounted while hidden must defer its initial signing request',
    (tester) async {
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      final photos = _Photos();
      var resolutions = 0;
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (_, enabled, __) => TickerMode(
              enabled: enabled,
              child: SizedBox.square(
                dimension: 140,
                child: SnapfitImage(
                  urlOrGs: 'supabase://album-assets/offstage-initial/photo',
                  cacheManager: photos,
                  memCacheWidth: 128,
                  resolveStorageUrlForTesting: (_) async {
                    resolutions++;
                    return 'https://review.test/offstage-initial';
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await _frames(tester, 10);
      final hiddenSignings = resolutions;
      expect(photos.requests, isEmpty);
      active.value = true;
      await tester.pump();
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(resolutions, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        hiddenSignings,
        0,
        reason:
            'The visibility guard must precede signing, not only pixel loading',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: URL and storage aliases of one rejected photo must share recovery',
    (tester) async {
      final photos = _Photos();
      const old = 'https://review.test/alias-rejected';
      const fresh = 'https://review.test/alias-fresh';
      photos.failures.add(old);
      var resolutions = 0;
      final key = GlobalKey();
      SnapfitImage storage() => SnapfitImage(
        urlOrGs: 'supabase://album-assets/alias-rejected/photo',
        cacheManager: photos,
        memCacheWidth: 128,
        memCacheHeight: 128,
        resolveStorageUrlForTesting: (_) async =>
            ++resolutions == 1 ? old : fresh,
      );
      await tester.pumpWidget(
        _app(
          Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 140,
                child: SnapfitImage(
                  urlOrGs: old,
                  fallbackSources: const [fresh],
                  cacheManager: photos,
                  memCacheWidth: 128,
                  memCacheHeight: 128,
                ),
              ),
              SizedBox.square(dimension: 140, child: storage()),
            ],
          ),
        ),
      );
      final prepared = storage().prepareImage(key.currentContext!);
      await _until(tester, () => _pixels.evaluate().length == 2);
      await prepared;
      final requests = List<String>.of(photos.requests);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(resolutions, 2);
      expect(
        requests.where((url) => url == old),
        hasLength(1),
        reason: 'Both aliases use exactly the same cache/decode key: $requests',
      );
      expect(requests.where((url) => url == fresh), hasLength(1));
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a newly resolved storage alias skips a URL already rejected by a single direct photo',
    (tester) async {
      final photos = _Photos();
      const old = 'https://review.test/late-alias-rejected';
      const fresh = 'https://review.test/late-alias-fresh';
      photos.failures.add(old);
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      var resolutions = 0;
      await tester.pumpWidget(
        _app(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 140,
                child: SnapfitImage(
                  urlOrGs: old,
                  cacheManager: photos,
                  memCacheWidth: 128,
                  error: const Text('direct failed'),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, show, __) => show
                    ? SizedBox.square(
                        dimension: 140,
                        child: SnapfitImage(
                          urlOrGs: 'gs://review-images/late-alias/photo',
                          cacheManager: photos,
                          memCacheWidth: 128,
                          resolveStorageUrlForTesting: (_) async =>
                              ++resolutions == 1 ? old : fresh,
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      await _until(
        tester,
        () => find.text('direct failed').evaluate().isNotEmpty,
      );
      visible.value = true;
      await tester.pump();
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(photos.requests, [old, fresh]);
      expect(resolutions, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final background in [false, true]) {
    for (final scheme in ['https', 'gs', 'supabase']) {
      testWidgets(
        'initial $scheme photo defers signing and pixels during ${background ? 'app background' : 'hidden route'}',
        (tester) async {
          final active = ValueNotifier(background);
          addTearDown(active.dispose);
          addTearDown(
            () => tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            ),
          );
          if (background)
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
          final photos = _Photos();
          var resolutions = 0;
          const loadedUrl = 'https://review.test/initial-activity-photo';
          final source = switch (scheme) {
            'gs' => 'gs://review-images/initial-activity/photo',
            'supabase' => 'supabase://album-assets/initial-activity/photo',
            _ => loadedUrl,
          };
          await tester.pumpWidget(
            _app(
              ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, enabled, __) => TickerMode(
                  enabled: enabled,
                  child: SizedBox.square(
                    dimension: 140,
                    child: SnapfitImage(
                      urlOrGs: source,
                      cacheManager: photos,
                      memCacheWidth: 128,
                      resolveStorageUrlForTesting: (_) async {
                        resolutions++;
                        return loadedUrl;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await _frames(tester, 5);
          expect(resolutions, 0);
          expect(photos.requests, isEmpty);
          expect(_pixels, findsNothing);
          if (background) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          } else {
            active.value = true;
          }
          await tester.pump();
          await _until(tester, () => _pixels.evaluate().isNotEmpty);
          expect(resolutions, scheme == 'https' ? 0 : 1);
          expect(photos.requests, [loadedUrl]);
          await tester.pumpWidget(const SizedBox());
          _clear();
          await _frames(tester, 3);
          expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
          expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'different storage URIs resolving to the same URL share rejection and decoded requests',
    (tester) async {
      final photos = _Photos();
      const old = 'https://review.test/two-storage-old';
      const fresh = 'https://review.test/two-storage-fresh';
      photos.failures.add(old);
      final resolutions = <String, int>{};
      SnapfitImage photo(String source) => SnapfitImage(
        urlOrGs: source,
        cacheManager: photos,
        memCacheWidth: 128,
        resolveStorageUrlForTesting: (source) async {
          final count = resolutions.update(
            source,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
          return count == 1 ? old : fresh;
        },
      );
      const a = 'gs://review-images/two-storage/photo';
      const b = 'supabase://album-assets/two-storage/photo';
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 140, child: photo(a)),
              SizedBox.square(dimension: 140, child: photo(b)),
            ],
          ),
        ),
      );
      final preparation = photo(b).prepareImage(key.currentContext!);
      await _until(tester, () => _pixels.evaluate().length == 2);
      await preparation;
      expect(resolutions, {a: 2, b: 2});
      expect(photos.requests, [old, fresh]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

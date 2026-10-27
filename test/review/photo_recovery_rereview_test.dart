import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:book_page_flip/src/engine.dart' show BookFlipPageRasterizer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' show File;
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
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

class _CacheFiles implements FileSystem {
  final _files = MemoryFileSystem();
  @override
  Future<File> createFile(String name) async => _files.file('/$name');
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Finder get _pixels => find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

Future<void> _frames(WidgetTester tester, [int count = 60]) async {
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
    'review: repeated cover collection reader visits and entry rotations release image handles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        previous?.call(image);
      };
      addTearDown(() => ui.Image.onCreate = previous);
      final photos = _Photos();
      CachedNetworkImageProvider.defaultCacheManager = photos;
      const preview = 'https://review.test/navigation-preview';
      const original = 'https://review.test/navigation-original';
      photos.failures.add(preview);
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final photo = LayerModel(
        id: 'navigation-photo',
        type: LayerType.image,
        position: Offset.zero,
        width: canvas.width,
        height: canvas.height,
        previewUrl: preview,
        originalUrl: original,
      );
      final album = Album(
        id: 20261025,
        ratio: '1',
        coverLayersJson: jsonEncode({
          'pages': [
            {
              'index': 0,
              'isCover': true,
              'layers': [
                LayerExportMapper.toJson(
                  photo,
                  canvasSize: canvas,
                  isCover: true,
                ),
              ],
            },
          ],
        }),
      );
      final navigator = GlobalKey<NavigatorState>();
      final collection = ValueNotifier(false);
      addTearDown(collection.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: collection,
                  builder: (_, list, __) => list
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < 2; i++)
                              HomeAlbumCoverThumbnail(
                                album: album,
                                height: 128,
                                maxWidth: 128,
                              ),
                          ],
                        )
                      : HomeAlbumCoverThumbnail(
                          album: album,
                          height: 160,
                          maxWidth: 160,
                        ),
                ),
              ),
            ),
          ),
        ),
      );
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      for (var visit = 0; visit < 3; visit++) {
        collection.value = !collection.value;
        await tester.pump();
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        final pages = PageController();
        final opening = ValueNotifier(false);
        final interaction = LayerInteractionManager.printPreview(() => canvas);
        final reader = AlbumReaderSinglePageView(
          allPages: [
            for (var i = 0; i < 5; i++)
              AlbumPage(
                id: 'navigation-page-$i',
                pageIndex: i,
                isCover: i == 0,
                layers: [photo],
              ),
          ],
          selectedCover: defaultCoverSize,
          coverTheme: CoverTheme.classic,
          pageController: pages,
          interaction: interaction,
          layerBuilder: LayerBuilder(interaction, () => canvas),
          canvasKey: GlobalKey(),
          openingCoverKey: GlobalKey(),
          openingCoverVisible: opening,
          onCanvasSizeChanged: (_) {},
          onPageChanged: (_) {},
          onStateChanged: () {},
          focusMode: true,
        );
        final closed = navigator.currentState!.push<void>(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Scaffold(body: reader),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        await tester.pump();
        for (var rotation = 0; rotation < 4; rotation++) {
          tester.view.physicalSize = rotation.isEven
              ? const Size(844, 390)
              : const Size(390, 844);
          await tester.pump();
          if (rotation == 1) opening.value = true;
        }
        await _until(
          tester,
          () =>
              find.byType(BookFlip).evaluate().isNotEmpty &&
              tester
                  .widget<BookFlip>(find.byType(BookFlip))
                  .controller!
                  .isReady,
        );
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        expect(tester.takeException(), isNull);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        await closed;
        pages.dispose();
        opening.dispose();
        interaction.dispose();
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        expect(tester.takeException(), isNull);
      }
      expect(photos.requests.where((url) => url == preview), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      _clear();
      await _frames(tester);
      expect(created.where((image) => !image.debugDisposed), isEmpty);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: leaving during slow photo entry and rotation releases superseded reader work',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        previous?.call(image);
      };
      addTearDown(() => ui.Image.onCreate = previous);
      final photos = _Photos();
      CachedNetworkImageProvider.defaultCacheManager = photos;
      const slow = 'https://review.test/slow-entry-cover';
      final gate = Completer<void>();
      photos.gates[slow] = gate;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      for (var visit = 0; visit < 4; visit++) {
        final pages = PageController();
        final opening = ValueNotifier(false);
        final interaction = LayerInteractionManager.printPreview(() => canvas);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: AlbumReaderSinglePageView(
                  allPages: [
                    for (var i = 0; i < 5; i++)
                      AlbumPage(
                        id: 'pending-page-$i',
                        pageIndex: i,
                        isCover: i == 0,
                        layers: [
                          LayerModel(
                            id: 'pending-photo-$i',
                            type: LayerType.image,
                            position: Offset.zero,
                            width: canvas.width,
                            height: canvas.height,
                            previewUrl: i == 0
                                ? slow
                                : 'https://review.test/must-not-start-$i',
                            originalUrl:
                                'https://review.test/must-not-recover-$i',
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
                  openingCoverVisible: opening,
                  onCanvasSizeChanged: (_) {},
                  onPageChanged: (_) {},
                  onStateChanged: () {},
                  focusMode: true,
                ),
              ),
            ),
          ),
        );
        await _until(tester, () => photos.requests.isNotEmpty);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pump();
        opening.value = true;
        tester.view.physicalSize = const Size(390, 844);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        pages.dispose();
        opening.dispose();
        interaction.dispose();
        expect(tester.takeException(), isNull);
      }
      photos.failures.add(slow);
      gate.complete();
      await _until(
        tester,
        () => PaintingBinding.instance.imageCache.pendingImageCount == 0,
      );
      _clear();
      await _frames(tester);
      expect(photos.requests, isNotEmpty);
      expect(photos.requests.every((url) => url == slow), isTrue);
      expect(created.where((image) => !image.debugDisposed), isEmpty);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: explicit retry must reconsider a repaired preview after all sources failed',
    (tester) async {
      final photos = _Photos();
      const preview = 'https://review.test/repaired-preview';
      const original = 'https://review.test/still-broken-original';
      photos.failures.addAll([preview, original]);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 140,
            height: 140,
            child: SnapfitImage(
              urlOrGs: preview,
              fallbackSources: const [original],
              cacheManager: photos,
              memCacheWidth: 128,
              memCacheHeight: 128,
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('storage-image-retry'));
      await _until(tester, () => retry.evaluate().isNotEmpty);
      expect(photos.requests, [preview, original]);
      photos.failures.remove(preview);
      await tester.tap(retry);
      await _frames(tester);
      final decoded = _pixels.evaluate().length;
      final requests = List<String>.of(photos.requests);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        decoded,
        greaterThan(0),
        reason: 'A usable preview exists after retry; downloads=$requests',
      );
      expect(requests.where((url) => url == preview), hasLength(2));
    },
  );

  testWidgets(
    'review: hiding an in-flight reader must pause fallback and later photo batches',
    (tester) async {
      final photos = _Photos();
      CachedNetworkImageProvider.defaultCacheManager = photos;
      const preview = 'https://review.test/hidden-preview';
      const original = 'https://review.test/hidden-original';
      const later = 'https://review.test/hidden-fourth-photo';
      final gate = Completer<void>();
      photos.gates[preview] = gate;
      photos.failures.add(preview);
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final interaction = LayerInteractionManager.printPreview(
        () => const Size(100, 100),
      );
      addTearDown(interaction.dispose);
      final builder = LayerBuilder(
        interaction,
        () => const Size(100, 100),
        previewImageDecodeWidth: 128,
      );
      final layers = [
        for (var i = 0; i < 4; i++)
          LayerModel(
            id: 'hidden-$i',
            type: LayerType.image,
            position: Offset.zero,
            width: 100,
            height: 100,
            previewUrl: i == 0
                ? preview
                : i == 3
                ? later
                : 'https://review.test/hidden-photo-$i',
            originalUrl: i == 0 ? original : null,
          ),
      ];
      var captured = false;
      final reader = BookFlipPageRasterizer(
        logicalSize: const Size(100, 100),
        pixelRatio: 1,
        pages: const [ColoredBox(color: Colors.orange)],
        preparePage: (context, _) => builder.prepareImages(context, layers),
        onCaptured: (images) {
          captured = true;
          for (final image in images) {
            image.dispose();
          }
        },
      );
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            child: reader,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          ),
        ),
      );
      await _until(tester, () => photos.requests.length >= 3);
      active.value = false;
      await tester.pump();
      final before = List<String>.of(photos.requests);
      gate.complete();
      await _frames(tester);
      final after = List<String>.of(photos.requests);
      expect(captured, isFalse);
      expect(tester.takeException(), isNull);
      expect(
        after,
        before,
        reason: 'Hidden readers must not start new fallback or batch work',
      );
      active.value = true;
      await tester.pump();
      await _until(tester, () => captured);
      expect(photos.requests.where((url) => url == preview), hasLength(1));
      expect(photos.requests.where((url) => url == original), hasLength(1));
      expect(photos.requests.where((url) => url == later), hasLength(1));
      for (var i = 1; i < 3; i++) {
        expect(
          photos.requests.where(
            (url) => url == 'https://review.test/hidden-photo-$i',
          ),
          hasLength(1),
          reason: 'Completed photos are reused when preparation resumes',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a hidden reader mounts no photo provider until it becomes visible',
    (tester) async {
      final photos = _Photos();
      final active = ValueNotifier(false);
      addTearDown(active.dispose);
      final captured = <ui.Image>[];
      final photo = SnapfitImage(
        urlOrGs: 'https://review.test/initially-hidden',
        cacheManager: photos,
        memCacheWidth: 128,
      );
      final reader = BookFlipPageRasterizer(
        pages: [photo],
        logicalSize: const Size(100, 100),
        pixelRatio: 1,
        preparePage: (context, _) async {
          await photo.prepareImage(context);
        },
        onCaptured: captured.addAll,
      );
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            child: reader,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          ),
        ),
      );
      await _frames(tester, 10);
      expect(photos.requests, isEmpty);
      expect(captured, isEmpty);
      active.value = true;
      await tester.pump();
      await _until(tester, () => captured.isNotEmpty);
      expect(photos.requests, ['https://review.test/initially-hidden']);
      final bytes = await tester.runAsync(() => captured.single.toByteData());
      final center = (50 * captured.single.width + 50) * 4;
      expect(bytes!.getUint8(center), closeTo(230, 2));
      expect(bytes.getUint8(center + 1), closeTo(100, 2));
      expect(bytes.getUint8(center + 2), closeTo(40, 2));
      await tester.pumpWidget(const SizedBox());
      for (final image in captured) {
        image.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a signing result received while hidden waits for visibility before downloading',
    (tester) async {
      final photos = _Photos();
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      final signed = Completer<String>();
      var resolutions = 0;
      var captured = false;
      final photo = SnapfitImage(
        urlOrGs: 'supabase://album-assets/hidden-signing/photo',
        cacheManager: photos,
        memCacheWidth: 128,
        resolveStorageUrlForTesting: (_) {
          resolutions++;
          return signed.future;
        },
      );
      final reader = BookFlipPageRasterizer(
        pages: [photo],
        logicalSize: const Size(100, 100),
        preparePage: (context, _) async {
          await photo.prepareImage(context);
        },
        onCaptured: (images) {
          captured = true;
          for (final image in images) {
            image.dispose();
          }
        },
      );
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            child: reader,
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          ),
        ),
      );
      expect(resolutions, 1);
      active.value = false;
      await tester.pump();
      signed.complete('https://review.test/hidden-signing-result');
      await _frames(tester, 10);
      expect(photos.requests, isEmpty);
      expect(captured, isFalse);
      active.value = true;
      await tester.pump();
      await _until(tester, () => captured);
      expect(resolutions, 1);
      expect(photos.requests, ['https://review.test/hidden-signing-result']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final background in [false, true])
    testWidgets(
      'a rejected storage URL resumes after ${background ? 'app background' : 'route hiding'}',
      (tester) async {
        final photos = _Photos();
        const old = 'https://review.test/hidden-rejected';
        const fresh = 'https://review.test/hidden-renewed';
        final gate = Completer<void>();
        photos.gates[old] = gate;
        photos.failures.add(old);
        final active = ValueNotifier(true);
        addTearDown(active.dispose);
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        var resolutions = 0;
        var captured = false;
        final photo = SnapfitImage(
          urlOrGs: 'supabase://album-assets/hidden-renewal/photo',
          cacheManager: photos,
          memCacheWidth: 128,
          resolveStorageUrlForTesting: (_) async =>
              ++resolutions == 1 ? old : fresh,
        );
        final reader = BookFlipPageRasterizer(
          pages: [photo],
          logicalSize: const Size(100, 100),
          preparePage: (context, _) async {
            await photo.prepareImage(context);
          },
          onCaptured: (images) {
            captured = true;
            for (final image in images) {
              image.dispose();
            }
          },
        );
        await tester.pumpWidget(
          _app(
            ValueListenableBuilder<bool>(
              valueListenable: active,
              child: reader,
              builder: (_, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
            ),
          ),
        );
        await _until(tester, () => photos.requests.contains(old));
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          active.value = false;
        }
        await tester.pump();
        gate.complete();
        await _frames(tester, 10);
        expect(resolutions, 1);
        expect(photos.requests, [old]);
        expect(captured, isFalse);
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          active.value = true;
        }
        await tester.pump();
        await _until(tester, () => captured);
        expect(resolutions, 2);
        expect(photos.requests, [old, fresh]);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

  testWidgets(
    'unchanged renewed URLs stay bounded and a later explicit retry can recover',
    (tester) async {
      final photos = _Photos();
      const url = 'https://review.test/unchanged-renewal';
      photos.failures.add(url);
      var resolutions = 0;
      await tester.pumpWidget(
        _app(
          SizedBox.square(
            dimension: 140,
            child: SnapfitImage(
              urlOrGs: 'supabase://album-assets/unchanged-renewal/photo',
              cacheManager: photos,
              memCacheWidth: 128,
              resolveStorageUrlForTesting: (_) async {
                resolutions++;
                return url;
              },
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('storage-image-retry'));
      await _until(tester, () => retry.evaluate().isNotEmpty);
      expect(resolutions, 2);
      expect(photos.requests, [url]);
      photos.failures.remove(url);
      await tester.tap(retry);
      await tester.tap(retry);
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(resolutions, 3);
      expect(photos.requests, [url, url]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'direct preview failures are shared before the next error-widget frame',
    (tester) async {
      final photos = _Photos();
      const preview = 'https://review.test/direct-rejected';
      const original = 'https://review.test/direct-original';
      final gate = Completer<void>();
      photos.gates[original] = gate;
      photos.failures.add(preview);
      SnapfitImage photo() => SnapfitImage(
        urlOrGs: preview,
        fallbackSources: const [original],
        cacheManager: photos,
        memCacheWidth: 128,
        memCacheHeight: 128,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 140, child: photo()),
              SizedBox.square(dimension: 140, child: photo()),
            ],
          ),
        ),
      );
      final prepared = photo().prepareImage(key.currentContext!);
      await _until(tester, () => photos.requests.contains(original));
      gate.complete();
      await _until(tester, () => _pixels.evaluate().length == 2);
      await prepared;
      expect(photos.requests, [preview, original]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'concurrent permanent rejection shares its failed renewal without another signing loop',
    (tester) async {
      final photos = _Photos();
      const old = 'https://review.test/permanent-old';
      const fresh = 'https://review.test/permanent-fresh';
      photos.failures.addAll([old, fresh]);
      var resolutions = 0;
      SnapfitImage photo() => SnapfitImage(
        urlOrGs: 'supabase://album-assets/concurrent-permanent/photo',
        cacheManager: photos,
        memCacheWidth: 128,
        memCacheHeight: 128,
        resolveStorageUrlForTesting: (_) async =>
            ++resolutions == 1 ? old : fresh,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 140, child: photo()),
              SizedBox.square(dimension: 140, child: photo()),
            ],
          ),
        ),
      );
      var prepared = false;
      Object? failure;
      final preparation = photo()
          .prepareImage(key.currentContext!)
          .then<void>(
            (_) {
              prepared = true;
            },
            onError: (Object e, StackTrace _) {
              failure = e;
              prepared = true;
            },
          );
      final retry = find.byKey(const ValueKey('storage-image-retry'));
      await _until(tester, () => prepared && retry.evaluate().length == 2);
      await preparation;
      await _frames(tester, 10);
      expect(failure, isNotNull);
      expect(resolutions, 2);
      expect(photos.requests, [old, fresh]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final alias in [false, true])
    testWidgets(
      'real cache-manager transport shares rejected URLs across ${alias ? 'URL and storage aliases' : 'storage consumers'}',
      (tester) async {
        const stale = 'https://review.test/real-cache-stale';
        const fresh = 'https://review.test/real-cache-fresh';
        final requests = <String>[];
        final gate = Completer<void>();
        var rejectStale = false;
        CacheManager newCache() => CacheManager(
          Config(
            'photo-recovery-rereview',
            repo: NonStoringObjectProvider(),
            fileSystem: _CacheFiles(),
            fileService: HttpFileService(
              httpClient: MockClient((request) async {
                final url = request.url.toString();
                requests.add(url);
                if (url == fresh) await gate.future;
                return http.Response.bytes(
                  browserPhotoFixture(),
                  rejectStale && url == stale ? 403 : 200,
                  headers: {'content-type': 'image/png'},
                );
              }),
            ),
          ),
        );
        var cache = newCache();
        final caches = [cache];
        addTearDown(() async {
          if (!gate.isCompleted) gate.complete();
          for (final manager in caches) {
            await manager.dispose();
          }
        });
        var resolutions = 0;
        SnapfitImage photo() => SnapfitImage(
          urlOrGs: 'supabase://album-assets/review-real-cache/photo',
          cacheManager: cache,
          memCacheWidth: 128,
          memCacheHeight: 128,
          resolveStorageUrlForTesting: (_) async =>
              ++resolutions == 1 ? stale : fresh,
        );
        await tester.pumpWidget(
          _app(SizedBox.square(dimension: 140, child: photo())),
        );
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        await tester.pumpWidget(const SizedBox());
        cache = newCache();
        caches.add(cache);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        rejectStale = true;
        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            Row(
              key: key,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 140,
                  child: alias
                      ? SnapfitImage(
                          urlOrGs: stale,
                          fallbackSources: const [fresh],
                          cacheManager: cache,
                          memCacheWidth: 128,
                          memCacheHeight: 128,
                        )
                      : photo(),
                ),
                SizedBox.square(dimension: 140, child: photo()),
              ],
            ),
          ),
        );
        final prepared = photo().prepareImage(key.currentContext!);
        await _frames(tester, 120);
        expect(
          requests,
          contains(fresh),
          reason:
              'resolutions=$resolutions, decoded=${_pixels.evaluate().length}',
        );
        gate.complete();
        await _until(tester, () => _pixels.evaluate().length == 2);
        await prepared;
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        for (final manager in caches) {
          await manager.dispose();
        }
        caches.clear();
        // CacheStore's test RAM repository still schedules a 10s cleanup timer;
        // flush that fixture housekeeping before widget-test invariants run.
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
        expect(resolutions, 2);
        expect(requests.where((url) => url == fresh), hasLength(1));
        expect(
          requests.where((url) => url == stale),
          hasLength(2),
          reason: 'Warm-up plus only one rejected transport call: $requests',
        );
        expect(tester.takeException(), isNull);
      },
    );

  testWidgets(
    'review: immediate stale failures share a renewed download across paint and preparation',
    (tester) async {
      final photos = _Photos();
      const stale = 'https://review.test/immediate-stale';
      const fresh = 'https://review.test/immediate-fresh';
      var resolutions = 0;
      SnapfitImage photo() => SnapfitImage(
        urlOrGs: 'supabase://album-assets/review-immediate/photo',
        cacheManager: photos,
        memCacheWidth: 128,
        memCacheHeight: 128,
        resolveStorageUrlForTesting: (_) async =>
            ++resolutions == 1 ? stale : fresh,
      );
      await tester.pumpWidget(
        _app(SizedBox.square(dimension: 140, child: photo())),
      );
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      photos.failures.add(stale);
      final gate = Completer<void>();
      photos.gates[fresh] = gate;
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          Row(
            key: key,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 140, child: photo()),
              SizedBox.square(dimension: 140, child: photo()),
            ],
          ),
        ),
      );
      final prepared = photo().prepareImage(key.currentContext!);
      await _until(tester, () => photos.requests.contains(fresh));
      gate.complete();
      await _until(tester, () => _pixels.evaluate().length == 2);
      await prepared;
      final requests = List<String>.of(photos.requests);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(resolutions, 2);
      expect(requests.where((url) => url == fresh), hasLength(1));
      expect(
        requests.where((url) => url == stale),
        hasLength(2),
        reason: 'One warm-up and one failed download must suffice: $requests',
      );
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

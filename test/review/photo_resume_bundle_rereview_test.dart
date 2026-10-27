import 'dart:async';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
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

class _ReviewAssets extends CachingAssetBundle {
  final loads = <String>[];
  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/review/hidden-photo-')) {
      loads.add(key);
      final bytes = browserPhotoFixture();
      return bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    }
    return rootBundle.load(key);
  }
}

void main() {
  setUp(_clear);
  tearDown(_clear);

  testWidgets(
    'mixed bundled local and remote reader survives hidden replacement rotation and repeated return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final local = <BrowserPhotoAsset>[];
      for (var i = 0; i < 3; i++) {
        local.add(
          (await tester.runAsync(
            () => BrowserPhotoAsset.fromBytes(
              ownerId: 'review',
              name: 'local-$i.png',
              bytes: browserPhotoFixture(width: 20 + i),
            ),
          ))!,
        );
      }
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        previous?.call(image);
      };
      addTearDown(() => ui.Image.onCreate = previous);
      final photos = _Photos();
      photos.failures.addAll([
        for (var i = 0; i < 3; i++) 'https://review.test/mixed-$i-preview',
      ]);
      CachedNetworkImageProvider.defaultCacheManager = photos;
      final assets = _ReviewAssets();
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final readerKey = GlobalKey();
      final pages = PageController();
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(pages.dispose);
      addTearDown(interaction.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigator,
            home: DefaultAssetBundle(
              bundle: assets,
              child: Scaffold(
                body: ValueListenableBuilder<int>(
                  valueListenable: revision,
                  builder: (_, rev, __) => AlbumReaderSinglePageView(
                    key: readerKey,
                    allPages: [
                      for (var i = 0; i < 3; i++)
                        AlbumPage(
                          id: 'mixed-$i',
                          pageIndex: i,
                          isCover: i == 0,
                          layers: [
                            LayerModel(
                              id: 'mixed-photo-$i',
                              type: LayerType.image,
                              position: Offset.zero,
                              width: canvas.width,
                              height: canvas.height,
                              asset: i == 1 ? local[rev] : null,
                              previewUrl: i == 2
                                  ? 'https://review.test/mixed-$rev-preview'
                                  : null,
                              imageUrl: i == 0
                                  ? 'asset:assets/review/hidden-photo-$rev-0.png'
                                  : i == 2
                                  ? 'https://review.test/mixed-$rev-original'
                                  : null,
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
        ),
      );
      bool ready() =>
          find.byType(BookFlip).evaluate().isNotEmpty &&
          tester.widget<BookFlip>(find.byType(BookFlip)).controller!.isReady;
      await _until(tester, ready);
      for (var visit = 0; visit < 3; visit++) {
        unawaited(
          navigator.currentState!.push<void>(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  const Scaffold(body: Text('covering route')),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(TickerMode.of(readerKey.currentContext!), isFalse);
        final beforeAssets = List.of(assets.loads);
        final beforeRequests = List.of(photos.requests);
        for (var turn = 0; turn < 3; turn++) {
          revision.value = (visit + turn) % 3;
          tester.view.physicalSize = turn.isEven
              ? const Size(844, 390)
              : const Size(390, 844);
          await tester.pump();
        }
        await _frames(tester, 10);
        expect(assets.loads, beforeAssets);
        expect(photos.requests, beforeRequests);
        navigator.currentState!.pop();
        await tester.pump();
        await _until(tester, ready);
        expect(_pixels, findsWidgets);
        expect(tester.takeException(), isNull);
      }
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

  for (final sameUrl in [false, true]) {
    testWidgets(
      'shared recovery survives pressure during signing with ${sameUrl ? 'the same' : 'a fresh'} URL and rapid retry',
      (tester) async {
        final photos = _Photos();
        const old = 'https://review.test/pressure-rejected';
        final fresh = sameUrl ? old : 'https://review.test/pressure-recovered';
        photos.failures.add(old);
        final created = <ui.Image>[];
        final previous = ui.Image.onCreate;
        ui.Image.onCreate = (image) {
          created.add(image);
          previous?.call(image);
        };
        addTearDown(() => ui.Image.onCreate = previous);
        final active = ValueNotifier(true);
        addTearDown(active.dispose);
        final signed = Completer<String>();
        addTearDown(() {
          if (!signed.isCompleted) signed.complete(fresh);
        });
        var resolutions = 0;
        SnapfitImage photo() => SnapfitImage(
          urlOrGs: 'supabase://album-assets/pressure-shared/photo',
          cacheManager: photos,
          memCacheWidth: 128,
          resolveStorageUrlForTesting: (_) =>
              ++resolutions <= 2 ? Future.value(old) : signed.future,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          _app(
            Row(
              key: key,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: 140, child: photo()),
                ValueListenableBuilder<bool>(
                  valueListenable: active,
                  child: SizedBox.square(dimension: 140, child: photo()),
                  builder: (_, enabled, child) =>
                      TickerMode(enabled: enabled, child: child!),
                ),
              ],
            ),
          ),
        );
        final retry = find.byKey(const ValueKey('storage-image-retry'));
        await _until(tester, () => retry.evaluate().length == 2);
        active.value = false;
        await tester.pump();
        photos.failures.clear();
        for (var i = 0; i < 8; i++) {
          await tester.tap(retry);
        }
        expect(resolutions, 3);
        MemoryPressureCaches.clear();
        final prepared = photo().prepareImage(key.currentContext!);
        signed.complete(fresh);
        await _until(tester, () => _pixels.evaluate().length == 1);
        expect(await prepared, isNotNull);
        active.value = true;
        await tester.pump();
        await _until(tester, () => _pixels.evaluate().length == 2);
        for (var i = 0; i < 5; i++) {
          active.value = false;
          await tester.pump();
          active.value = true;
          await tester.pump();
        }
        await _frames(tester, 5);
        expect(resolutions, 3);
        expect(photos.requests, [old, fresh]);
        expect(retry, findsNothing);
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
  }
}

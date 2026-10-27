import 'dart:async';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
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

  for (final differentSources in [false, true]) {
    for (final sameUrl in [false, true]) {
      testWidgets(
        'a hidden consumer resumes pixels recovered by another consumer with ${sameUrl ? 'an identical' : 'a new'} URL and ${differentSources ? 'different aliases' : 'matching sources'}',
        (tester) async {
          final photos = _Photos();
          const rejected = 'https://review.test/shared-resume-rejected';
          final recovered = sameUrl
              ? rejected
              : 'https://review.test/shared-resume-recovered';
          photos.failures.add(rejected);
          final secondActive = ValueNotifier(true);
          addTearDown(secondActive.dispose);
          var resolutions = 0;
          SnapfitImage photo({bool secondary = false}) => SnapfitImage(
            urlOrGs: 'supabase://album-assets/shared-resume/photo',
            fallbackSources: secondary && differentSources
                ? const [rejected]
                : const [],
            cacheManager: photos,
            memCacheWidth: 128,
            resolveStorageUrlForTesting: (_) async =>
                ++resolutions <= 2 ? rejected : recovered,
          );
          await tester.pumpWidget(
            _app(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(dimension: 140, child: photo()),
                  ValueListenableBuilder<bool>(
                    valueListenable: secondActive,
                    child: SizedBox.square(
                      dimension: 140,
                      child: photo(secondary: true),
                    ),
                    builder: (_, active, child) =>
                        TickerMode(enabled: active, child: child!),
                  ),
                ],
              ),
            ),
          );
          final retry = find.byKey(const ValueKey('storage-image-retry'));
          await _until(tester, () => retry.evaluate().length == 2);
          expect(resolutions, 2);
          secondActive.value = false;
          await tester.pump();
          photos.failures.clear();
          for (var i = 0; i < 8; i++) {
            await tester.tap(retry);
          }
          await _until(tester, () => _pixels.evaluate().length == 1);
          expect(resolutions, 3);
          secondActive.value = true;
          await tester.pump();
          await _frames(tester, 25);
          final decoded = _pixels.evaluate().length;
          final retryCount = retry.evaluate().length;
          final requestLog = List.of(photos.requests);
          debugPrint(
            'shared-resume sameUrl=$sameUrl pixels=$decoded retry=$retryCount signing=$resolutions requests=$requestLog',
          );
          await tester.pumpWidget(const SizedBox());
          _clear();
          await _frames(tester, 5);
          expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
          expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
          expect(
            decoded,
            2,
            reason:
                'The other consumer already decoded the recovered photo; the resumed one must show it too. retries=$retryCount, requests=$requestLog',
          );
          expect(resolutions, 3);
          expect(requestLog, [rejected, recovered]);
        },
      );
    }
  }

  testWidgets(
    'a hidden reader defers new bundled-photo loads through a data update and rotation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assets = _ReviewAssets();
      final created = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        created.add(image);
        previous?.call(image);
      };
      addTearDown(() => ui.Image.onCreate = previous);
      final controller = PageController();
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(controller.dispose);
      addTearDown(interaction.dispose);
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final readerKey = GlobalKey();
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
                          id: 'asset-reader-$i',
                          pageIndex: i,
                          isCover: i == 0,
                          layers: [
                            LayerModel(
                              id: 'asset-photo-$i',
                              type: LayerType.image,
                              position: Offset.zero,
                              width: canvas.width,
                              height: canvas.height,
                              imageUrl:
                                  'asset:assets/review/hidden-photo-$rev-$i.png',
                            ),
                          ],
                        ),
                    ],
                    selectedCover: defaultCoverSize,
                    coverTheme: CoverTheme.classic,
                    pageController: controller,
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
      final before = List.of(assets.loads);
      revision.value = 1;
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await _frames(tester, 25);
      final hiddenLoads = List.of(assets.loads);
      navigator.currentState!.pop();
      await tester.pump();
      await _until(tester, ready);
      expect(_pixels, findsWidgets);
      debugPrint('bundled-photo before=$before whileHidden=$hiddenLoads');
      await tester.pumpWidget(const SizedBox());
      _clear();
      await _frames(tester);
      expect(created.where((image) => !image.debugDisposed), isEmpty);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      expect(
        hiddenLoads,
        before,
        reason: 'Hidden local photos must be deferred just like remote photos',
      );
    },
  );

  testWidgets(
    'a resumed shared original can still recover through its repaired preview',
    (tester) async {
      final photos = _Photos();
      const preview = 'https://review.test/resumed-repaired-preview';
      const original = 'https://review.test/resumed-failed-original';
      photos.failures.add(preview);
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<bool>(
            valueListenable: active,
            child: SizedBox.square(
              dimension: 140,
              child: SnapfitImage(
                urlOrGs: preview,
                fallbackSources: const [original],
                cacheManager: photos,
                memCacheWidth: 128,
              ),
            ),
            builder: (_, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          ),
        ),
      );
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(photos.requests, [preview, original]);
      active.value = false;
      await tester.pump();
      photos.failures
        ..remove(preview)
        ..add(original);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      active.value = true;
      await tester.pump();
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      expect(photos.requests, [preview, original, original, preview]);
      expect(find.byKey(const ValueKey('storage-image-retry')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      _clear();
      await _frames(tester, 3);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

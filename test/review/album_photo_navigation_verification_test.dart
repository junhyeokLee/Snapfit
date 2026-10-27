import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:book_page_flip/book_page_flip.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    if (failures.contains(url)) throw StateError('photo_not_available:$url');
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(hours: 1)),
      url,
    );
  }
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue);
}

Finder get _pixels => find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void _clearImages() {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

Album _album(LayerModel photo) => Album(
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
            canvasSize: const Size(500, 500),
            isCover: true,
          ),
        ],
      },
    ],
  }),
);

void main() {
  setUp(_clearImages);
  tearDown(_clearImages);

  testWidgets(
    'review: native route return must recover a rejected cached storage URL',
    (tester) async {
      final photos = _Photos();
      const oldUrl = 'https://fixture.invalid/navigation-signed-old.png';
      const freshUrl = 'https://fixture.invalid/navigation-signed-fresh.png';
      var resolutions = 0;
      Widget photo() => _app(
        SizedBox(
          width: 160,
          height: 160,
          child: SnapfitImage(
            urlOrGs: 'supabase://album-assets/review-navigation/photo.png',
            enableWebStorageRecoveryForTesting: false,
            resolveStorageUrlForTesting: (_) async =>
                ++resolutions == 1 ? oldUrl : freshUrl,
            cacheManager: photos,
            memCacheWidth: 128,
            imageBuilder: (_, __) => const Text('native photo decoded'),
          ),
        ),
      );
      await tester.pumpWidget(photo());
      await _until(
        tester,
        () => find.text('native photo decoded').evaluate().isNotEmpty,
      );
      // Leaving the route releases its live stream. Later navigation/pressure can
      // evict the decoded pixels while an old signed URL is no longer accepted.
      await tester.pumpWidget(const SizedBox());
      _clearImages();
      photos.failures.add(oldUrl);
      await tester.pumpWidget(photo());
      await _until(
        tester,
        () =>
            find.text('native photo decoded').evaluate().isNotEmpty ||
            find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty,
      );
      final requestLog = List<String>.of(photos.requests);
      await tester.pumpWidget(const SizedBox());
      expect(
        resolutions,
        2,
        reason:
            'A failed saved URL must allow bounded refresh; downloads=$requestLog',
      );
      expect(requestLog.last, freshUrl);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: home cover must use the valid original when its preview is unavailable',
    (tester) async {
      final photos = _Photos();
      const preview = 'https://fixture.invalid/home-missing-preview.png';
      const original = 'https://fixture.invalid/home-existing-original.png';
      photos.failures.add(preview);
      CachedNetworkImageProvider.defaultCacheManager = photos;
      final album = _album(
        LayerModel(
          id: 'home-photo',
          type: LayerType.image,
          position: Offset.zero,
          width: 500,
          height: 500,
          previewUrl: preview,
          originalUrl: original,
        ),
      );
      await tester.pumpWidget(
        _app(HomeAlbumCoverThumbnail(album: album, height: 160, maxWidth: 160)),
      );
      await _until(
        tester,
        () =>
            _pixels.evaluate().isNotEmpty ||
            find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty,
      );
      final decoded = _pixels.evaluate().length;
      final requests = List<String>.of(photos.requests);
      await tester.pumpWidget(const SizedBox());
      expect(
        decoded,
        greaterThan(0),
        reason: 'The original exists but was not used; downloads=$requests',
      );
      expect(requests, contains(original));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: reader photo preparation must recover through the valid original',
    (tester) async {
      final photos = _Photos();
      const preview = 'https://fixture.invalid/reader-missing-preview.png';
      const original = 'https://fixture.invalid/reader-existing-original.png';
      photos.failures.add(preview);
      CachedNetworkImageProvider.defaultCacheManager = photos;
      final interaction = LayerInteractionManager.printPreview(
        () => const Size(500, 500),
      );
      addTearDown(interaction.dispose);
      final builder = LayerBuilder(interaction, () => const Size(500, 500));
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(SizedBox(key: key, width: 100, height: 100)),
      );
      final prepared = builder.prepareImages(key.currentContext!, [
        LayerModel(
          id: 'reader-photo',
          type: LayerType.image,
          position: Offset.zero,
          width: 500,
          height: 500,
          previewUrl: preview,
          originalUrl: original,
        ),
      ]);
      Object? failure;
      final completed = Completer<void>();
      prepared.then(
        (_) => completed.complete(),
        onError: (Object e, StackTrace _) {
          failure = e;
          completed.complete();
        },
      );
      await _until(tester, () => completed.isCompleted);
      await tester.pumpWidget(const SizedBox());
      expect(
        failure,
        isNull,
        reason:
            'The reader must try the valid source; downloads=${photos.requests}',
      );
      expect(photos.requests, contains(original));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home cover recovers after repeated hidden/resume and memory-pressure cycles',
    (tester) async {
      final photos = _Photos();
      CachedNetworkImageProvider.defaultCacheManager = photos;
      final album = _album(
        LayerModel(
          id: 'stable-photo',
          type: LayerType.image,
          position: Offset.zero,
          width: 500,
          height: 500,
          imageUrl: 'https://fixture.invalid/stable-home.png',
        ),
      );
      Widget cover(bool enabled) => _app(
        TickerMode(
          enabled: enabled,
          child: HomeAlbumCoverThumbnail(
            album: album,
            height: 160,
            maxWidth: 160,
          ),
        ),
      );
      for (var visit = 0; visit < 8; visit++) {
        await tester.pumpWidget(cover(true));
        await _until(tester, () => _pixels.evaluate().isNotEmpty);
        await tester.pumpWidget(cover(false));
        await tester.pumpAndSettle();
        expect(_pixels, findsNothing);
        MemoryPressureCaches.clear();
        _clearImages();
      }
      await tester.pumpWidget(cover(true));
      await _until(tester, () => _pixels.evaluate().isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.liveImageCount, 0);
      expect(cache.pendingImageCount, 0);
      expect(photos.requests.length, lessThanOrEqualTo(9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review: rotating the reader while its entry cover is visible must not mutate layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opening = ValueNotifier(false);
      final pages = PageController();
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(opening.dispose);
      addTearDown(pages.dispose);
      addTearDown(interaction.dispose);
      await tester.pumpWidget(
        _app(
          AlbumReaderSinglePageView(
            allPages: [
              for (var i = 0; i < 3; i++)
                AlbumPage(
                  id: 'entry-rotation-$i',
                  pageIndex: i,
                  isCover: i == 0,
                  layers: [],
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
      );
      await _until(
        tester,
        () =>
            find.byType(BookFlip).evaluate().isNotEmpty &&
            tester.widget<BookFlip>(find.byType(BookFlip)).controller!.isReady,
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      final failure = tester.takeException();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(failure, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reader entry handoff and reduced motion preserve the prepared renderer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opening = ValueNotifier(false);
      final pages = PageController();
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(opening.dispose);
      addTearDown(pages.dispose);
      addTearDown(interaction.dispose);
      final allPages = [
        for (var i = 0; i < 3; i++)
          AlbumPage(
            id: 'stable-handoff-$i',
            pageIndex: i,
            isCover: i == 0,
            layers: [],
          ),
      ];
      final builder = LayerBuilder(interaction, () => canvas);
      final canvasKey = GlobalKey(), openingKey = GlobalKey();
      Widget reader({bool reduced = false}) => _app(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduced,
          ),
          child: AlbumReaderSinglePageView(
            allPages: allPages,
            selectedCover: defaultCoverSize,
            coverTheme: CoverTheme.classic,
            pageController: pages,
            interaction: interaction,
            layerBuilder: builder,
            canvasKey: canvasKey,
            openingCoverKey: openingKey,
            openingCoverVisible: opening,
            onCanvasSizeChanged: (_) {},
            onPageChanged: (_) {},
            onStateChanged: () {},
            focusMode: true,
          ),
        ),
      );
      await tester.pumpWidget(reader());
      await _until(
        tester,
        () =>
            find.byType(BookFlip).evaluate().isNotEmpty &&
            tester.widget<BookFlip>(find.byType(BookFlip)).controller!.isReady,
      );
      final renderer = tester.element(find.byType(BookFlip));
      opening.value = true;
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(BookFlip)), same(renderer));
      await tester.pumpWidget(reader(reduced: true));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(BookFlip)), same(renderer));
      expect(
        tester.widget<BookFlip>(find.byType(BookFlip)).controller!.isReady,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:book_page_flip/src/engine.dart'
    show BookFlip, BookFlipController, BookFlipPageRasterizer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

class _DelayedPhotos extends Fake
    implements BaseCacheManager, ImageCacheManager {
  bool fail = false;
  final ready = Completer<void>();
  final requests = <String>[];
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
    await ready.future;
    if (fail) throw StateError('temporary_reader_photo_failure');
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

void main() {
  testWidgets(
    'a jump during atlas preparation keeps the newest spread when ready',
    (tester) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(() => picture.toImage(100, 100)))!;
      picture.dispose();
      addTearDown(image.dispose);
      final controller = BookFlipController();
      addTearDown(controller.dispose);
      var requestedDuringPreparation = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BookFlip(
            pages: List.filled(6, image),
            controller: controller,
            loadingBuilder: (_) {
              if (!requestedDuringPreparation) {
                expect(controller.isReady, isFalse);
                controller.goToSpread(1);
                controller.goToSpread(2);
                requestedDuringPreparation = true;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(requestedDuringPreparation, isTrue);
      await _until(tester, () => controller.isReady);
      expect(controller.currentSpread, 2);
      expect(controller.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reader retry is reachable and replaces failed live photo widgets',
    (tester) async {
      final cache = _DelayedPhotos()..fail = true;
      cache.ready.complete();
      CachedNetworkImageProvider.defaultCacheManager = cache;
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      var focused = 0;
      final pages = PageController(initialPage: 0);
      addTearDown(pages.dispose);
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(interaction.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AlbumReaderSinglePageView(
                allPages: [
                  for (var i = 0; i < 3; i++)
                    AlbumPage(
                      id: 'retry-page-$i',
                      pageIndex: i,
                      isCover: i == 0,
                      layers: [
                        LayerModel(
                          id: 'retry-photo-$i',
                          type: LayerType.image,
                          position: Offset.zero,
                          width: canvas.width,
                          height: canvas.height,
                          imageUrl:
                              'https://fixture.test/retry-reader-photo-$i.png',
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
                onCanvasSizeChanged: (_) {},
                onPageChanged: (_) {},
                onStateChanged: () {},
                onFocusPageChanged: (page) => focused = page,
                focusMode: true,
              ),
            ),
          ),
        ),
      );
      final retry = find.byKey(const ValueKey('reader-retry-photos'));
      await _until(tester, () => retry.hitTestable().evaluate().isNotEmpty);
      expect(retry.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pump();
      expect(
        focused,
        1,
        reason: 'Photo preparation must not delay opening the first spread',
      );
      cache.fail = false;
      await tester.tap(retry);
      await _until(tester, () {
        final book = find.byType(BookFlip);
        return book.evaluate().isNotEmpty &&
            tester.widget<BookFlip>(book).controller!.isReady;
      });
      expect(retry, findsNothing);
      final live = find.byKey(const ValueKey('reader-live-spread'));
      final decodedPhotos = find.descendant(
        of: live,
        matching: find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        ),
      );
      await _until(tester, () => decodedPhotos.evaluate().length == 2);
      expect(decodedPhotos, findsNWidgets(2));
      expect(
        find.descendant(
          of: live,
          matching: find.byIcon(Icons.broken_image_outlined),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late network photos are painted before the reader snapshot is frozen',
    (tester) async {
      final cache = _DelayedPhotos();
      // This test isolate never starts the plugin-backed disk cache.
      CachedNetworkImageProvider.defaultCacheManager = cache;
      addTearDown(() {
        if (!cache.ready.isCompleted) cache.ready.complete();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      const canvas = Size(100, 100);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(interaction.dispose);
      final builder = LayerBuilder(
        interaction,
        () => canvas,
        previewImageDecodeWidth: 128,
      );
      final photo = LayerModel(
        id: 'late-photo',
        type: LayerType.image,
        position: Offset.zero,
        width: 100,
        height: 100,
        imageUrl: 'https://fixture.test/late-reader-photo.png',
      );
      final captures = <ui.Image>[];
      addTearDown(() {
        for (final image in captures) {
          image.dispose();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: BookFlipPageRasterizer(
              pages: [
                ColoredBox(
                  color: Colors.white,
                  child: Stack(children: [builder.buildImage(photo)]),
                ),
              ],
              logicalSize: canvas,
              pixelRatio: 2,
              preparePage: (context, index) =>
                  builder.prepareImages(context, [photo]),
              onCaptured: captures.addAll,
            ),
          ),
        ),
      );
      await _until(tester, () => cache.requests.isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(
        captures,
        isEmpty,
        reason: 'A painted placeholder is not a loaded photo',
      );
      cache.ready.complete();
      await _until(tester, () => captures.isNotEmpty);
      expect(captures.single.width, 200);
      expect(captures.single.height, 200);
      final bytes = await tester.runAsync(
        () => captures.single.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final center = (100 * captures.single.width + 100) * 4;
      expect(bytes!.getUint8(center), closeTo(230, 2));
      expect(bytes.getUint8(center + 1), closeTo(100, 2));
      expect(bytes.getUint8(center + 2), closeTo(40, 2));
      expect(cache.requests, [
        'https://fixture.test/late-reader-photo.png',
      ], reason: 'Visible images and preparation share one decode/download');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'leaving during preparation never captures or starts another page',
    (tester) async {
      final gate = Completer<void>();
      final prepared = <int>[];
      var captured = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BookFlipPageRasterizer(
            logicalSize: const Size(100, 100),
            pages: const [
              ColoredBox(color: Colors.blue),
              ColoredBox(color: Colors.red),
            ],
            preparePage: (_, index) {
              prepared.add(index);
              return gate.future;
            },
            onCaptured: (images) {
              captured = true;
              for (final image in images) {
                image.dispose();
              }
            },
          ),
        ),
      );
      expect(prepared, [0]);
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      expect(prepared, [0]);
      expect(captured, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden captures pause and preparation errors do not freeze empty pages',
    (tester) async {
      var enabled = false;
      var preparations = 0;
      var failures = 0;
      var captured = false;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              change = setState;
              return TickerMode(
                enabled: enabled,
                child: BookFlipPageRasterizer(
                  logicalSize: const Size(100, 100),
                  pages: const [ColoredBox(color: Colors.blue)],
                  preparePage: (_, __) async {
                    preparations++;
                    throw StateError('photo download failed');
                  },
                  onError: (_, __) => failures++,
                  onCaptured: (images) {
                    captured = true;
                    for (final image in images) {
                      image.dispose();
                    }
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(preparations, 0);
      change(() => enabled = true);
      await tester.pump();
      await tester.pump();
      expect(preparations, 1);
      expect(failures, 1);
      expect(captured, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

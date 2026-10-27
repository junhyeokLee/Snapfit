import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/features/album/presentation/utils/album_document_worker.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/album_open_origin.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_tab_screen.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

Album _album(int id, String text) => Album(
  id: id,
  ratio: '1',
  title: 'Album $id',
  coverLayersJson: jsonEncode({
    'pages': [
      {
        'index': 0,
        'backgroundColor': '#123456',
        'layers': [
          LayerExportMapper.toJson(
            LayerModel(
              id: 'text',
              type: LayerType.text,
              text: text,
              position: const Offset(80, 80),
              width: 200,
              height: 80,
            ),
            canvasSize: const Size(500, 500),
            isCover: true,
          ),
        ],
      },
    ],
  }),
);

Widget _thumbnail(Album album, {Key? key, double height = 120}) =>
    HomeAlbumCoverThumbnail(
      key: key,
      album: album,
      height: height,
      maxWidth: height,
      showBookDepth: true,
    );

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  bool enabled = true,
  bool reduced = false,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 2,
        ).copyWith(disableAnimations: reduced),
        child: TickerMode(
          enabled: enabled,
          child: Scaffold(body: child),
        ),
      ),
    ),
  ),
);

CoverLayout _artwork(WidgetTester tester, Key key) =>
    tester.widget<CoverLayout>(
      find.descendant(of: find.byKey(key), matching: find.byType(CoverLayout)),
    );

class _DeferredPhysics extends ScrollPhysics {
  final ValueNotifier<bool> defer;
  const _DeferredPhysics(this.defer, {super.parent});

  @override
  _DeferredPhysics applyTo(ScrollPhysics? ancestor) =>
      _DeferredPhysics(defer, parent: buildParent(ancestor));

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) => defer.value;
}

void main() {
  testWidgets(
    'cover and collection agree for legacy targets and photo deletion',
    (tester) async {
      Album document(int filled, {int target = 2, bool zeroBased = false}) =>
          _album(9094, 'cover').copyWith(
            targetPages: target,
            totalPages: 24,
            coverLayersJson: jsonEncode({
              'pages': [
                {'index': 0, 'isCover': true, 'layers': []},
                for (var index = 1; index <= 2; index++)
                  {
                    'index': zeroBased ? index - 1 : index,
                    'isCover': false,
                    'layers': [
                      {
                        'type': 'IMAGE',
                        'templateContent': index > filled,
                        'payload': {
                          'previewUrl': index <= filled
                              ? 'https://uploads.test/$index.jpg'
                              : '',
                        },
                      },
                      {
                        'type': 'TEXT',
                        'templateContent': true,
                        'payload': {'text': 'Our days'},
                      },
                    ],
                  },
              ],
            }),
          );
      for (final state in [
        for (final zeroBased in [false, true])
          for (final value in [(0, 2), (1, 2), (2, 2), (1, 2), (2, 0)])
            (value.$1, value.$2, zeroBased),
      ]) {
        final album = document(state.$1, target: state.$2, zeroBased: state.$3);
        final complete = state.$1 == 2;
        await _show(
          tester,
          HomeAlbumSlider(albums: [album], showHeader: false),
          reduced: true,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('home-focused-album-status')),
              )
              .data,
          '${complete ? '완성한 앨범' : '만드는 중'} · ${state.$1}/2쪽',
        );
        await _show(
          tester,
          HomeAlbumTabScreen(
            allAlbums: [album],
            currentUserId: '',
            albumTabIndex: 0,
            favoriteAlbumIds: const {},
            onAlbumTabChanged: (_) {},
            onToggleFavorite: (_) {},
            onRefresh: () async {},
            showHeader: false,
          ),
          reduced: true,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('완성'));
        await tester.pumpAndSettle();
        expect(find.text('앨범 ${complete ? 1 : 0}권'), findsOneWidget);
        await tester.tap(find.text('만드는 중'));
        await tester.pumpAndSettle();
        expect(find.text('앨범 ${complete ? 0 : 1}권'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('legacy captions stay in working until every page is authored', (
    tester,
  ) async {
    Album exampleBook(int verifiedPages) => _album(9090, 'cover').copyWith(
      targetPages: 2,
      totalPages: 24,
      coverLayersJson: jsonEncode({
        'pages': [
          {'index': 0, 'layers': []},
          for (var index = 1; index <= 2; index++)
            {
              'index': index,
              'layers': [
                {
                  'type': 'TEXT',
                  if (index <= verifiedPages) 'templateContent': false,
                  'payload': {
                    'text': index <= verifiedPages
                        ? '내 기록 $index'
                        : '예시 문구 $index',
                  },
                },
                {
                  'type': 'DECORATION',
                  'templateContent': false,
                  'payload': {'fillColor': '#E7ECEB'},
                },
              ],
            },
        ],
      }),
    );
    Widget collection(Album album) => HomeAlbumTabScreen(
      allAlbums: [album],
      currentUserId: '',
      albumTabIndex: 0,
      favoriteAlbumIds: const {},
      onAlbumTabChanged: (_) {},
      onToggleFavorite: (_) {},
      onRefresh: () async {},
      showHeader: false,
    );
    await _show(tester, collection(exampleBook(0)), reduced: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('완성'));
    await tester.pumpAndSettle();
    expect(find.text('앨범 0권'), findsOneWidget);
    await tester.tap(find.text('만드는 중'));
    await tester.pumpAndSettle();
    expect(find.text('앨범 1권'), findsOneWidget);
    expect(find.byTooltip(albumCompletionCriteria), findsOneWidget);
    await tester.tap(find.text('완성'));
    await tester.pumpAndSettle();
    await _show(tester, collection(exampleBook(1)), reduced: true);
    await tester.pumpAndSettle();
    expect(find.text('앨범 0권'), findsOneWidget);
    await _show(tester, collection(exampleBook(2)), reduced: true);
    await tester.pumpAndSettle();
    expect(find.text('앨범 1권'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'cover status explains why decoration-only pages stay unfinished',
    (tester) async {
      final album = _album(9091, 'cover').copyWith(
        targetPages: 1,
        totalPages: 24,
        coverLayersJson: jsonEncode({
          'pages': [
            {'index': 0, 'layers': []},
            {
              'index': 1,
              'layers': [
                {
                  'type': 'STICKER',
                  'templateContent': false,
                  'payload': {'imageBackground': 'studioSageRibbon'},
                },
              ],
            },
          ],
        }),
      );
      await _show(
        tester,
        HomeAlbumSlider(albums: [album], showHeader: false),
        reduced: true,
      );
      await tester.pumpAndSettle();
      final status = find.byKey(const ValueKey('home-focused-album-status'));
      expect(tester.widget<Text>(status).data, '만드는 중 · 0/1쪽');
      expect(find.byTooltip(albumCompletionCriteria), findsOneWidget);
      await tester.longPress(status);
      await tester.pumpAndSettle();
      expect(find.text(albumCompletionCriteria), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'large cover size never decodes the document during first build',
    (tester) async {
      final release = Completer<int>();
      final blocker = AlbumDocumentWorker.run(
        () => release.future,
        isCurrent: () => true,
      );
      final album = _album(9020, 'size').copyWith(
        coverLayersJson: jsonEncode({
          'padding': 'x' * (33 * 1024),
          'printProduct': {
            'id': 'REDP_300_HARD',
            'trimWidthMm': 300,
            'trimHeightMm': 300,
          },
          'pages': [],
        }),
      );
      try {
        await _show(
          tester,
          HomeAlbumSliderCard(
            album: album,
            index: 0,
            currentPage: 0,
            animateIdle: false,
          ),
        );
        expect(find.byType(HomeAlbumCoverThumbnail), findsOneWidget);
        expect(album.cachedPhysicalCoverSize, isNull);
        expect(cachedAlbumProgress(album), isNull);
        await tester.pump();
        expect(album.cachedPhysicalCoverSize, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        // Detach before releasing the slot: no real compute worker is started.
        await tester.pumpWidget(const SizedBox());
        release.complete(0);
        await tester.pump();
        await blocker;
      }
    },
  );

  testWidgets(
    'collection refresh cancels pending status work and keeps the selected filter',
    (tester) async {
      // Hold the shared slot so the old large document stays queued. This
      // regression checks cancellation without starting a real compute worker.
      final release = Completer<int>();
      final blocker = AlbumDocumentWorker.run(
        () => release.future,
        isCurrent: () => true,
      );
      addTearDown(() {
        if (!release.isCompleted) release.complete(0);
      });
      final old = _album(9010, 'old').copyWith(
        targetPages: 1,
        coverLayersJson: jsonEncode({
          'padding': 'x' * (33 * 1024),
          'pages': [],
        }),
      );
      final current = _album(9011, 'new').copyWith(
        targetPages: 1,
        totalPages: 1,
        coverLayersJson: jsonEncode({
          'pages': [
            {'index': 0, 'layers': []},
            {
              'index': 1,
              'layers': [
                {
                  'type': 'TEXT',
                  'templateContent': false,
                  'payload': {'text': '직접 작성한 기록'},
                },
              ],
            },
          ],
        }),
      );
      Widget collection(List<Album> albums) => HomeAlbumTabScreen(
        allAlbums: albums,
        currentUserId: '',
        albumTabIndex: 0,
        favoriteAlbumIds: const {},
        onAlbumTabChanged: (_) {},
        onToggleFavorite: (_) {},
        onRefresh: () async {},
        showHeader: false,
      );
      await _show(tester, collection([old]));
      await tester.tap(find.text('완성'));
      await tester.pump();
      await tester.pump();
      expect(find.text('앨범 확인 중'), findsOneWidget);
      await _show(tester, collection([current]));
      release.complete(0);
      await tester.pumpAndSettle();
      await blocker;
      expect(find.text('앨범 1권'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-collection-album-9011')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-collection-album-9010')),
        findsNothing,
      );
      expect(cachedAlbumProgress(old), isNull);
      await tester.tap(find.text('만드는 중'));
      await tester.pumpAndSettle();
      expect(find.text('앨범 0권'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'progress clients share results and cancellation does not refill cache',
    (tester) async {
      final album = _album(
        9001,
        'shared progress',
      ).copyWith(targetPages: 10, totalPages: 3);
      final first = AlbumProgressLoader.request(album);
      final second = AlbumProgressLoader.request(album);
      first.cancel();
      await tester.pump();
      expect(await first.result, isNull);
      final result = await second.result;
      expect(result!.completedPages, 0);
      expect(result.targetPages, 10);
      expect(result.coverSize!.realSize, const Size(20, 20));
      expect(album.cachedPhysicalCoverSize, same(result.coverSize));
      expect(cachedAlbumProgress(album), same(result));
      MemoryPressureCaches.clear();
      expect(cachedAlbumProgress(album), isNull);
      final cancelled = AlbumProgressLoader.request(album);
      cancelled.cancel();
      await tester.pump();
      expect(await cancelled.result, isNull);
      expect(cachedAlbumProgress(album), isNull);
      final refreshed = AlbumProgressLoader.request(album);
      await tester.pump();
      expect((await refreshed.result)!.completedPages, 0);
    },
  );

  testWidgets('first frame is a skeleton; artwork mounts one cover per frame', (
    tester,
  ) async {
    await _show(
      tester,
      Row(
        children: [
          _thumbnail(_album(1, 'paced first')),
          _thumbnail(_album(2, 'paced second')),
        ],
      ),
    );
    expect(find.byType(CoverLayout), findsNothing);
    await tester.pump();
    expect(find.byType(CoverLayout), findsOneWidget);
    await tester.pump();
    expect(find.byType(CoverLayout), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage and shelf share parsed data across rebuilds and sizes', (
    tester,
  ) async {
    final album = _album(10, 'shared immutable artwork');
    const first = ValueKey('large-cover');
    const second = ValueKey('small-cover');
    Widget covers(Album a, {double height = 160}) => Row(
      children: [
        _thumbnail(a, key: first, height: height),
        _thumbnail(a.copyWith(id: 11), key: second, height: 64),
      ],
    );
    await _show(tester, covers(album));
    await tester.pump();
    await tester.pump();
    final layers = _artwork(tester, first).layers;
    expect(_artwork(tester, second).layers, same(layers));
    expect(_artwork(tester, first).backgroundColor, const Color(0xff123456));
    expect(() => layers.clear(), throwsUnsupportedError);

    await _show(tester, covers(album.copyWith(title: 'Renamed'), height: 200));
    expect(_artwork(tester, first).layers, same(layers));
    final edited = _album(10, 'edited artwork');
    await _show(tester, covers(edited));
    await tester.pump();
    await tester.pump();
    expect(_artwork(tester, first).layers.single.text, 'edited artwork');
    expect(_artwork(tester, first).layers, isNot(same(layers)));
    expect(
      _artwork(tester, second).layers,
      same(_artwork(tester, first).layers),
    );
  });

  testWidgets('shared cover cache evicts older document sources', (
    tester,
  ) async {
    const key = ValueKey('eviction-cover');
    final original = _album(20, 'eviction original');
    await _show(tester, _thumbnail(original, key: key));
    await tester.pump();
    final layers = _artwork(tester, key).layers;
    for (var i = 0; i < 25; i++) {
      await _show(tester, _thumbnail(_album(21 + i, 'evict $i'), key: key));
      await tester.pump();
    }
    await _show(tester, _thumbnail(original, key: key));
    await tester.pump();
    expect(_artwork(tester, key).layers, isNot(same(layers)));
    expect(_artwork(tester, key).layers.single.text, 'eviction original');
  });

  testWidgets('cover cache includes canvas ratio in its key', (tester) async {
    const key = ValueKey('ratio-cover');
    final album = _album(60, 'ratio-sensitive artwork');
    await _show(tester, _thumbnail(album, key: key));
    await tester.pump();
    final original = _artwork(tester, key).layers;
    await _show(tester, _thumbnail(album.copyWith(ratio: '0.75'), key: key));
    await tester.pump();
    expect(_artwork(tester, key).aspect, .75);
    expect(_artwork(tester, key).layers, isNot(same(original)));
    expect(
      _artwork(tester, key).layers.single.position.dy,
      closeTo(original.single.position.dy / .75, .001),
    );
  });

  testWidgets(
    'hidden and scrolling previews defer loading and safely dispose',
    (tester) async {
      final album = _album(70, 'deferred cover');
      await _show(tester, _thumbnail(album), enabled: false);
      await tester.pump();
      expect(find.byType(CoverLayout), findsNothing);
      await _show(tester, _thumbnail(album));
      await tester.pump();
      expect(find.byType(CoverLayout), findsOneWidget);

      final defer = ValueNotifier(true);
      addTearDown(defer.dispose);
      await _show(
        tester,
        ListView(
          physics: _DeferredPhysics(defer),
          children: [_thumbnail(_album(71, 'scroll deferred cover'))],
        ),
      );
      await tester.pump();
      expect(find.byType(CoverLayout), findsNothing);
      defer.value = false;
      await tester.pump();
      expect(find.byType(CoverLayout), findsOneWidget);
      await _show(tester, _thumbnail(_album(72, 'cancel pending load')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback skips empty URLs and bounds image decode size', (
    tester,
  ) async {
    const album = Album(
      coverThumbnailUrl: '',
      coverPreviewUrl: ' ',
      coverImageUrl: 'https://example.com/cover.jpg',
      ratio: '1',
    );
    await _show(tester, _thumbnail(album));
    final images = tester.widgetList<SnapfitImage>(find.byType(SnapfitImage));
    expect(images, isNotEmpty);
    for (final image in images) {
      expect(image.urlOrGs, album.coverImageUrl);
      // 120 logical pixels at DPR 2 use the shared 128-pixel decode bucket.
      expect(image.memCacheWidth, 256);
      // One decode dimension preserves the source crop for curved covers.
      expect(image.memCacheHeight, isNull);
    }
  });

  testWidgets('photos inside layered covers use thumbnail-sized decoding', (
    tester,
  ) async {
    final album = Album(
      id: 73,
      ratio: '1',
      coverLayersJson: jsonEncode({
        'layers': [
          LayerExportMapper.toJson(
            LayerModel(
              id: 'photo',
              type: LayerType.image,
              position: const Offset(40, 0),
              previewUrl: 'https://example.com/layered-cover.jpg',
              width: 500,
              height: 500,
            ),
            canvasSize: const Size(500, 500),
            isCover: true,
          ),
        ],
      }),
    );
    await _show(tester, _thumbnail(album));
    await tester.pump();
    final small = tester.widgetList<SnapfitImage>(find.byType(SnapfitImage));
    expect(small, isNotEmpty);
    expect(small.map((image) => image.memCacheWidth), everyElement(256));
    await _show(tester, _thumbnail(album, height: 220));
    final large = tester.widgetList<SnapfitImage>(find.byType(SnapfitImage));
    expect(large.map((image) => image.memCacheWidth), everyElement(512));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resting stage mounts one card and preserves selection on refresh',
    (tester) async {
      final albums = List.generate(30, (i) => _album(100 + i, 'lazy stage $i'));
      await _show(tester, HomeAlbumSlider(albums: albums));
      expect(find.byType(HomeAlbumSliderCard), findsOneWidget);
      final state = tester.state(find.byType(HomeAlbumSlider));
      final card = tester.widget<HomeAlbumSliderCard>(
        find.byType(HomeAlbumSliderCard),
      );
      (card.pagePosition! as ValueNotifier<double>).value = .4;
      await tester.pump();
      expect(find.byType(HomeAlbumSliderCard), findsNWidgets(2));
      (card.pagePosition! as ValueNotifier<double>).value = 0;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-shelf-album-101')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester
            .widget<HomeAlbumSliderCard>(find.byType(HomeAlbumSliderCard))
            .album
            .id,
        101,
      );
      await _show(tester, HomeAlbumSlider(albums: albums.reversed.toList()));
      await tester.pump();
      expect(tester.state(find.byType(HomeAlbumSlider)), same(state));
      expect(
        tester
            .widget<HomeAlbumSliderCard>(find.byType(HomeAlbumSliderCard))
            .album
            .id,
        101,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'float pauses offstage, off focus, on reduced motion and inactive app',
    (tester) async {
      final position = ValueNotifier<double>(0);
      final originKey = GlobalKey();
      addTearDown(position.dispose);
      Widget card(ValueNotifier<double> page) => SizedBox(
        width: 390,
        height: 480,
        child: HomeAlbumSliderCard(
          album: _album(200, 'motion lifecycle'),
          index: 0,
          currentPage: 0,
          pagePosition: page,
          coverOriginKey: originKey,
        ),
      );
      List<double> pose() =>
          List.of(AlbumOpenOrigin.capture(originKey)!.transform.storage);
      Future<void> expectStopped() async {
        final before = pose();
        await tester.pump(const Duration(milliseconds: 450));
        expect(pose(), orderedEquals(before));
      }

      Future<void> expectMoving() async {
        await tester.pump();
        final before = pose();
        await tester.pump(const Duration(milliseconds: 450));
        expect(pose(), isNot(orderedEquals(before)));
      }

      await _show(tester, card(position));
      await tester.pump();
      await expectMoving();
      position.value = 1;
      await tester.pump();
      await expectStopped();
      position.value = 0;
      await tester.pump();
      await expectMoving();
      await _show(tester, card(position), enabled: false);
      await expectStopped();
      await _show(tester, card(position));
      await expectMoving();
      await _show(tester, card(position), reduced: true);
      await expectStopped();
      await _show(tester, card(position));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await expectStopped();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await expectMoving();

      final replacement = ValueNotifier<double>(1);
      addTearDown(replacement.dispose);
      await _show(tester, card(replacement));
      position.value = .5; // The old notifier must no longer control the card.
      await tester.pump();
      await expectStopped();
      replacement.value = 0;
      await tester.pump();
      await expectMoving();
      await tester.pumpWidget(const SizedBox());
      position.value = 0;
      replacement.value = 1;
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

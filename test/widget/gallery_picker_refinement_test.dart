import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/gallery_notifier.dart';
import 'package:snap_fit/shared/widgets/editor_modal_scope.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Photo extends Mock implements AssetEntity {}

late List<Uint8List> _images;
AssetEntity _photo(int index) {
  final photo = _Photo();
  when(() => photo.id).thenReturn('photo-$index');
  when(
    () => photo.createDateTime,
  ).thenReturn(DateTime(2026, 10, 8).subtract(Duration(days: index)));
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => _images[index % _images.length]);
  return photo;
}

class _Gallery implements GalleryRepository {
  _Gallery({int count = 12, int extraAlbums = 0}) {
    photos = List.generate(count, _photo);
    albums = [
      AssetPathEntity(id: 'all', name: 'Recent', isAll: true),
      AssetPathEntity(id: 'family', name: '가족과 함께한 날들'),
      AssetPathEntity(id: 'travel', name: '여행'),
      for (var i = 0; i < extraAlbums; i++)
        AssetPathEntity(id: 'extra-$i', name: '사진첩 $i'),
    ];
  }
  late List<AssetEntity> photos;
  late List<AssetPathEntity> albums;
  final requests = <({String id, int page, int size})>[];
  int refreshes = 0;
  final dateQueries = <DateTimeCond?>[];

  List<AssetEntity> items(String id) => switch (id) {
    'all' => photos,
    'family' => photos.skip(8).take(2).toList(),
    _ => photos.take(5).toList(),
  };

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    refreshes++;
    return albums;
  }

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async => albums.first;
  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) async {
    requests.add((id: album.id, page: page, size: size));
    final filter = album.filterOption;
    final dates = filter is FilterOptionGroup ? filter.createTimeCond : null;
    dateQueries.add(dates);
    final matching = items(album.id).where(
      (photo) =>
          dates == null ||
          dates.ignore ||
          (!photo.createDateTime.isBefore(dates.min) &&
              !photo.createDateTime.isAfter(dates.max)),
    );
    return matching.skip(page * size).take(size).toList();
  }
}

Widget _app(
  _Gallery gallery, {
  required ValueChanged<List<AssetEntity>?> onResult,
  bool dark = false,
  bool multiple = true,
  double textScale = 1,
  GlobalKey? capture,
}) => ProviderScope(
  overrides: [galleryRepositoryProvider.overrideWithValue(gallery)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: RepaintBoundary(key: capture, child: child!),
    ),
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, _) => Center(
          child: FilledButton(
            onPressed: () async {
              final result = multiple
                  ? await showPhotosSelectionSheet(
                      context,
                      ref,
                      maxSelection: 10,
                    )
                  : [
                      if (await showPhotoSelectionSheet(context, ref)
                          case final photo?)
                        photo,
                    ];
              onResult(result);
            },
            child: const Text('사진 추가'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GALLERY_PICKER_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/gallery-picker-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _enterDateRange(
  WidgetTester tester,
  String start,
  String end,
) async {
  await tester.tap(find.byKey(const ValueKey('gallery-date-range')));
  await tester.pumpAndSettle();
  final localizations = MaterialLocalizations.of(
    tester.element(find.byType(DateRangePickerDialog)),
  );
  await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(DateRangePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), start);
  await tester.enterText(fields.at(1), end);
  await tester.tap(find.text('적용').hitTestable());
  await _paint(tester);
}

void main() {
  _PaintBinding();
  late _Gallery gallery;
  setUpAll(() async {
    await loadCreationFonts();
    _images = [
      for (final name in [
        'alpine_lake',
        'celebration',
        'city_skyline',
        'quiet_room',
        'forest_trail',
        'ocean_shore',
        'wardrobe',
        'artist_palette',
        'spring_flowers',
        'mountain_light',
        'night_city',
        'desert_walk',
      ])
        await File('assets/frame_preview/$name.jpg').readAsBytes(),
    ];
  });
  setUp(() {
    gallery = _Gallery();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          (call) async {
            if (call.method == 'getAssetCountFromPath')
              return gallery
                  .items((call.arguments as Map)['id'] as String)
                  .length;
            throw StateError('Unexpected call ${call.method}');
          },
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.fluttercandies/photo_manager'),
          null,
        ),
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets(
        'latest gallery, resizing, album covers and selected review $suffix',
        (tester) async {
          _size(tester, size);
          final key = GlobalKey();
          List<AssetEntity>? result;
          await tester.pumpWidget(
            _app(
              gallery,
              dark: dark,
              capture: key,
              onResult: (value) => result = value,
            ),
          );
          await tester.tap(find.text('사진 추가'));
          await _paint(tester);
          expect(find.text('전체 사진'), findsOneWidget);
          expect(find.text('최신순'), findsOneWidget);
          final grid = find.byKey(const ValueKey('gallery-grid-all-false'));
          final height = tester.getSize(grid).height;
          await tester.drag(
            find.byKey(const ValueKey('gallery-resize-handle')),
            Offset(0, size.width < size.height ? -180 : 70),
          );
          await _paint(tester);
          final resized = tester.getSize(grid).height;
          expect((resized - height).abs(), greaterThan(20));
          await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-2')));
          await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-0')));
          await _capture(tester, key, 'gallery-$suffix');
          await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
          await _paint(tester);
          expect(find.text('12장'), findsOneWidget);
          expect(find.byType(Image), findsAtLeastNWidgets(3));
          await _capture(tester, key, 'albums-$suffix');
          await tester.tap(find.byKey(const ValueKey('gallery-album-family')));
          await _paint(tester);
          await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-8')));
          await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
          await _paint(tester);
          expect(
            find.byKey(const ValueKey('gallery-photo-photo-9')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('gallery-photo-photo-2')),
            findsOneWidget,
          );
          await _capture(tester, key, 'selected-$suffix');
          await tester.tap(
            find.byKey(const ValueKey('confirm-gallery-selection')),
          );
          await _paint(tester);
          expect(result!.map((p) => p.id), ['photo-2', 'photo-0', 'photo-8']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'review supports removing photos, clearing all and returning to the album',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(gallery, onResult: (_) {}));
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      for (final id in [0, 2, 4])
        await tester.tap(find.byKey(ValueKey('gallery-photo-photo-$id')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-2')));
      await tester.pump();
      expect(find.byKey(const ValueKey('gallery-photo-photo-2')), findsNothing);
      expect(find.text('2/10'), findsOneWidget);
      await tester.tap(find.byTooltip('모든 선택 해제'));
      await _paint(tester);
      expect(find.text('0/10'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-2')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('confirm-gallery-selection')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopening and pull refresh load new photos without losing selected order',
    (tester) async {
      _size(tester, const Size(390, 844));
      List<AssetEntity>? result;
      await tester.pumpWidget(
        _app(gallery, onResult: (value) => result = value),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-2')));
      gallery.photos = [_photo(100), ...gallery.photos];
      final refreshed = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await _paint(tester);
      await tester.pump(const Duration(seconds: 1));
      await refreshed;
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-100')),
        findsOneWidget,
      );
      expect(find.text('1/10'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-gallery-selection')));
      await _paint(tester);
      expect(result!.single.id, 'photo-2');
      gallery.photos = [_photo(101), ...gallery.photos];
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-101')),
        findsOneWidget,
      );
      expect(gallery.refreshes, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('many albums load covers lazily and can be searched', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    gallery = _Gallery(extraAlbums: 30);
    await tester.pumpWidget(_app(gallery, onResult: (_) {}));
    await tester.tap(find.text('사진 추가'));
    await _paint(tester);
    await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
    await _paint(tester);
    expect(gallery.requests.where((r) => r.size == 1).length, lessThan(20));
    await tester.enterText(
      find.byKey(const ValueKey('gallery-album-search')),
      '사진첩 18',
    );
    await _paint(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('gallery-album-extra-18')),
        matching: find.text('사진첩 18'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('gallery-album-extra-17')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('gallery-album-extra-18')));
    await _paint(tester);
    expect(find.text('사진첩 18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    testWidgets('large text preserves controls and single selection $size', (
      tester,
    ) async {
      _size(tester, size);
      List<AssetEntity>? result;
      await tester.pumpWidget(
        _app(
          gallery,
          dark: true,
          multiple: false,
          textScale: 1.8,
          onResult: (value) => result = value,
        ),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-album-family')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-8')));
      await _paint(tester);
      expect(result!.single.id, 'photo-8');
      expect(
        find.byKey(const ValueKey('confirm-gallery-selection')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text keeps multi-photo confirmation accessible $size', (
      tester,
    ) async {
      _size(tester, size);
      List<AssetEntity>? result;
      await tester.pumpWidget(
        _app(
          gallery,
          dark: true,
          textScale: 1.8,
          onResult: (value) => result = value,
        ),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-gallery-selection')));
      await _paint(tester);
      expect(result!.single.id, 'photo-0');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'selected review and order survive rotation while the sheet is open',
    (tester) async {
      _size(tester, const Size(390, 844));
      List<AssetEntity>? result;
      await tester.pumpWidget(
        _app(gallery, onResult: (value) => result = value),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-2')));
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
      await _paint(tester);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 24,
        bottom: 24,
      );
      tester.view.viewPadding = tester.view.padding;
      await _paint(tester);
      expect(find.text('2/10'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gallery-grid-all-true')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-gallery-selection')));
      await _paint(tester);
      expect(result!.map((p) => p.id), ['photo-2', 'photo-0']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('album search remains visible above the keyboard in landscape', (
    tester,
  ) async {
    _size(tester, const Size(844, 390));
    gallery = _Gallery(extraAlbums: 20);
    await tester.pumpWidget(_app(gallery, onResult: (_) {}));
    await tester.tap(find.text('사진 추가'));
    await _paint(tester);
    await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
    await _paint(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.enterText(
      find.byKey(const ValueKey('gallery-album-search')),
      '사진첩 18',
    );
    await _paint(tester);
    expect(
      tester.getRect(find.byKey(const ValueKey('gallery-album-search'))).bottom,
      lessThan(210),
    );
    await tester.tap(find.byTooltip('사진첩 닫기'));
    await _paint(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-digit selection badges fit with large text', (tester) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(_app(gallery, textScale: 1.8, onResult: (_) {}));
    await tester.tap(find.text('사진 추가'));
    await _paint(tester);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('gallery-grid-all-false')),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 10; i++) {
      final photo = find.byKey(ValueKey('gallery-photo-photo-$i'));
      await tester.scrollUntilVisible(photo, 180, scrollable: scrollable);
      await tester.tap(photo);
      await tester.pump();
    }
    expect(
      find.ancestor(of: find.text('10'), matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(find.text('10')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrolling appends bounded pages without changing the first row',
    (tester) async {
      _size(tester, const Size(390, 844));
      gallery = _Gallery(count: 90);
      await tester.pumpWidget(_app(gallery, onResult: (_) {}));
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('gallery-photo-photo-78')),
        350,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('gallery-grid-all-false')),
          matching: find.byType(Scrollable),
        ),
      );
      await _paint(tester);
      expect(gallery.requests.where((r) => r.size == 40).map((r) => r.page), [
        0,
        1,
        2,
      ]);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('gallery-grid-all-false')),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(0);
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'date search preserves the tray, album switching, refresh and reset',
    (tester) async {
      _size(tester, const Size(390, 844));
      List<AssetEntity>? result;
      await tester.pumpWidget(
        _app(gallery, onResult: (value) => result = value),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      expect(find.text('전체 기간'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-0')));
      await _enterDateRange(tester, '10/01/2026', '10/02/2026');
      expect(find.byKey(const ValueKey('gallery-photo-photo-0')), findsNothing);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-6')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-7')),
        findsOneWidget,
      );
      expect(gallery.dateQueries.last!.min, DateTime(2026, 10, 1));
      expect(
        gallery.dateQueries.last!.max,
        DateTime(2026, 10, 3).subtract(const Duration(milliseconds: 1)),
      );
      await tester.tap(find.byKey(const ValueKey('gallery-photo-photo-7')));
      await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-7')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gallery-date-range')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('gallery-selected-only')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('gallery-album-family')));
      await _paint(tester);
      expect(find.text('선택한 기간에 사진이 없어요'), findsOneWidget);
      expect(gallery.requests.last.id, 'family');
      expect(gallery.dateQueries.last!.min, DateTime(2026, 10, 1));
      final context = tester.element(
        find.byKey(const ValueKey('gallery-date-range')),
      );
      final container = ProviderScope.containerOf(context);
      await container
          .read(galleryProvider.notifier)
          .fetchInitialData(albumId: 'family');
      await _paint(tester);
      expect(gallery.dateQueries.last!.min, DateTime(2026, 10, 1));
      await tester.tap(
        find.byKey(const ValueKey('gallery-empty-clear-date-range')),
      );
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-8')),
        findsOneWidget,
      );
      expect(find.text('전체 기간'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-gallery-selection')));
      await _paint(tester);
      expect(result!.map((photo) => photo.id), ['photo-0', 'photo-7']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelled or invalid dates do not query and end day is inclusive',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(gallery, onResult: (_) {}));
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      final initialCount = gallery.requests.length;
      await tester.tap(find.byKey(const ValueKey('gallery-date-range')));
      await tester.pumpAndSettle();
      final closeLabel = MaterialLocalizations.of(
        tester.element(find.byType(DateRangePickerDialog)),
      ).closeButtonTooltip;
      await tester.tap(find.byTooltip(closeLabel));
      await _paint(tester);
      expect(gallery.requests.length, initialCount);
      await _enterDateRange(tester, '10/09/2026', '10/08/2026');
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(find.text('종료 날짜는 시작 날짜 이후로 선택해주세요.'), findsOneWidget);
      expect(gallery.requests.length, initialCount);
      final fields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '10/08/2026');
      await tester.tap(find.text('적용').hitTestable());
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('gallery-photo-photo-0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gallery-photo-photo-1')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('date toolbar and recovery fit large text at ${size.width}', (
      tester,
    ) async {
      _size(tester, size);
      await tester.pumpWidget(
        _app(gallery, dark: true, textScale: 2.4, onResult: (_) {}),
      );
      await tester.tap(find.text('사진 추가'));
      await _paint(tester);
      final context = tester.element(
        find.byKey(const ValueKey('gallery-date-range')),
      );
      final container = ProviderScope.containerOf(context);
      await _enterDateRange(tester, '01/01/2000', '01/01/2000');
      expect(find.text('선택한 기간에 사진이 없어요'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gallery-clear-date-range')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('gallery-clear-date-range')));
      await _paint(tester);
      expect(container.read(galleryProvider).dateRange, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('date picker uses the editing navigator and scoped modal name', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final root = GlobalKey<NavigatorState>();
    final editor = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [galleryRepositoryProvider.overrideWithValue(gallery)],
        child: MaterialApp(
          navigatorKey: root,
          home: Navigator(
            key: editor,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => showPhotosSelectionSheet(context, ref),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await _paint(tester);
    expect(root.currentState!.canPop(), isFalse);
    await tester.tap(find.byKey(const ValueKey('gallery-date-range')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DateRangePickerDialog));
    expect(Navigator.of(context), same(editor.currentState));
    expect(
      ModalRoute.of(context)!.settings.name,
      editorModalRouteName(context),
    );
    expect(root.currentState!.canPop(), isFalse);
    editor.currentState!.pop();
    await _paint(tester);
    expect(find.byKey(const ValueKey('gallery-date-range')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

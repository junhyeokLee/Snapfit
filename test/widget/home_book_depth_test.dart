import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:book_page_flip/book_page_flip.dart';
import 'package:flutter/material.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_preview_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_frozen_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/album_spine_image.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/album_open_origin.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_shelf.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/album_stage_style.dart';
import 'package:snap_fit/shared/widgets/experience_icon.dart';

import '../helpers/fake_album.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'home_screen_test.dart' show FakeAuthViewModel;
import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _UnavailablePrintOrders extends Mock implements OrderRepository {}

class _ChangingHome extends FakeHomeViewModel {
  _ChangingHome(super.albums);

  void replaceAlbums(List<Album> albums) => state = AsyncData(albums);
}

Album _album(
  double ratio,
  String shape, {
  String? photoAsset,
  int innerPages = 4,
  bool varied = false,
}) {
  final canvas = Size(500, 500 / ratio);
  final pages = List.generate(innerPages + 1, (index) {
    final cover = index == 0;
    final photo = LayerModel(
      id: 'image-$index',
      type: LayerType.image,
      position: Offset(cover ? 14 : 0, 0),
      width: cover ? 486 : 500,
      height: canvas.height,
      imageUrl:
          'asset:${varied && !cover ? ['assets/snapfit_home_square.jpg', 'assets/snapfit_home_landscape.jpg', 'assets/snapfit_home_portrait.jpg'][index % 3] : photoAsset ?? 'assets/snapfit_home_$shape.jpg'}',
    );
    return {
      'index': index,
      'isCover': cover,
      'layers': [
        LayerExportMapper.toJson(photo, canvasSize: canvas, isCover: cover),
      ],
    };
  });
  return fakeAlbum(
    id: 17,
    ratio: '$ratio',
    totalPages: innerPages + 1,
    coverLayersJson: jsonEncode({'pages': pages}),
  ).copyWith(title: '우리의 순간', targetPages: innerPages);
}

Future<GlobalKey> _boot(
  WidgetTester tester,
  Size size,
  bool dark,
  double ratio,
  String shape, {
  List<Album>? catalog,
  bool reduceMotion = false,
  bool accessibleNavigation = false,
  OrderRepository? printOrders,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final album = _album(ratio, shape);
  final albums = catalog ?? [album];
  final repo = MockAlbumRepository();
  when(() => repo.lockAlbum(any())).thenAnswer((_) async {});
  when(() => repo.unlockAlbum(any())).thenAnswer((_) async {});
  when(() => repo.fetchAlbum(any())).thenAnswer((invocation) async {
    final id = int.parse(invocation.positionalArguments.first as String);
    return albums.firstWhere((item) => item.id == id);
  });
  when(() => repo.fetchMyAlbums()).thenAnswer((_) async => albums);
  final key = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  addTearDown(() async {
    if (navigator.currentState?.canPop() == true) {
      navigator.currentState!.popUntil((route) => route.isFirst);
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeUiStateProvider.overrideWith(
          () => HomeUiStateNotifier(initialIndex: 0),
        ),
        albumRepositoryProvider.overrideWithValue(repo),
        if (printOrders != null)
          orderRepositoryProvider.overrideWithValue(printOrders),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        homeViewModelProvider.overrideWith(() => _ChangingHome(albums)),
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            const UserInfo(id: 'qa', name: '스냅핏', provider: 'email'),
          ),
        ),
        notificationUnreadCountProvider.overrideWith((ref) async => 0),
        templateListProvider.overrideWith((ref) async => const []),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              accessibleNavigation: accessibleNavigation,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: const HomeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  return key;
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  Rect? crop,
}) async {
  if (!const bool.fromEnvironment('HOME_BOOK_QA')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    ui.Image capture = image;
    ui.Picture? picture;
    if (crop != null) {
      final area = crop.intersect(
        Offset.zero & Size(image.width / 2, image.height / 2),
      );
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(
          area.left * 2,
          area.top * 2,
          area.width * 2,
          area.height * 2,
        ),
        Rect.fromLTWH(0, 0, area.width * 2, area.height * 2),
        Paint()..filterQuality = FilterQuality.high,
      );
      picture = recorder.endRecording();
      capture = await picture.toImage(
        (area.width * 2).ceil(),
        (area.height * 2).ceil(),
      );
    }
    final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '${const String.fromEnvironment('HOME_BOOK_QA_OUTPUT', defaultValue: 'output/home-book-depth-qa')}/$name.png',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    if (capture != image) capture.dispose();
    picture?.dispose();
    image.dispose();
  });
}

Future<ByteData> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    }))!;

void _expectFrontFacing(AlbumOpenOrigin origin) {
  final corners =
      [
            Offset.zero,
            Offset(origin.size.width, 0),
            Offset(0, origin.size.height),
            Offset(origin.size.width, origin.size.height),
          ]
          .map((point) => MatrixUtils.transformPoint(origin.transform, point))
          .toList();
  for (final edge in [(0, 1), (2, 3)]) {
    final delta = corners[edge.$2] - corners[edge.$1];
    expect((delta.dy / delta.dx).abs(), lessThan(.015));
  }
  for (final edge in [(0, 2), (1, 3)]) {
    final delta = corners[edge.$2] - corners[edge.$1];
    expect((delta.dx / delta.dy).abs(), lessThan(.015));
  }
}

void main() {
  _PaintBinding();
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'reduced motion freezes float and album controls select immediately',
    (tester) async {
      final album = _album(1, 'square');
      await _boot(
        tester,
        const Size(390, 844),
        false,
        1,
        'square',
        catalog: [album, album.copyWith(id: 18), album.copyWith(id: 19)],
        reduceMotion: true,
      );
      final card = tester.widget<HomeAlbumSliderCard>(
        find.byKey(const ValueKey('home_album_17')),
      );
      final before = List<double>.of(
        AlbumOpenOrigin.capture(card.coverOriginKey!)!.transform.storage,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        AlbumOpenOrigin.capture(card.coverOriginKey!)!.transform.storage,
        before,
      );
      await tester.tap(find.byTooltip('다음 앨범'));
      await tester.pump();
      expect(
        tester
            .widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf))
            .selectedIndex,
        1,
      );
      expect(
        tester
            .widget<HomeAlbumSliderCard>(
              find.byKey(const ValueKey('home_album_18')),
            )
            .pagePosition!
            .value,
        1,
      );
      await tester.tap(find.byTooltip('이전 앨범'));
      await tester.pump();
      expect(
        tester
            .widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf))
            .selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'opening skips the moving cover for accessibility: screenReader=$accessible',
      (tester) async {
        await _boot(
          tester,
          const Size(390, 844),
          false,
          1,
          'square',
          reduceMotion: !accessible,
          accessibleNavigation: accessible,
        );
        await tester.tap(find.byKey(const ValueKey('home-bookshelf-open')));
        for (
          var i = 0;
          i < 30 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final reader = tester.widget<AlbumReaderScreen>(
          find.byType(AlbumReaderScreen),
        );
        expect(reader.openingCoverKey, isNull);
        expect(reader.openingCoverVisible, isNull);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'mobile book preparation opens print review directly and cancellation keeps the reader',
    (tester) async {
      final orders = _UnavailablePrintOrders();
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 17),
      ).thenAnswer((_) async => throw StateError('offline review fixture'));
      when(
        () => orders.fetchPrintPreviewSnapshot(albumId: 17),
      ).thenAnswer((_) async => throw StateError('offline review fixture'));
      await _boot(
        tester,
        const Size(390, 844),
        false,
        1,
        'square',
        reduceMotion: true,
        printOrders: orders,
      );
      await tester.tap(find.byKey(const ValueKey('home-bookshelf-open')));
      for (
        var i = 0;
        i < 30 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('앨범 메뉴'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('책으로 만들기'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('책으로 만들기'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('책으로 만들까요?'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      await tester.tap(find.text('취소'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlbumReaderScreen), findsOneWidget);
      verifyNever(() => orders.fetchPrintCheckoutReadiness(albumId: 17));
      await tester.tap(find.byTooltip('앨범 메뉴'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('책으로 만들기'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('책으로 만들기'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('album-completion-confirm')));
      for (
        var i = 0;
        i < 40 && find.byType(PrintOrderPreviewScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.byType(PrintOrderPreviewScreen), findsOneWidget);
      expect(find.byType(AlbumFrozenScreen), findsNothing);
      expect(
        tester
            .widget<PrintOrderPreviewScreen>(
              find.byType(PrintOrderPreviewScreen),
            )
            .albumId,
        17,
      );
      verify(() => orders.fetchPrintCheckoutReadiness(albumId: 17)).called(1);
      Navigator.of(tester.element(find.byType(PrintOrderPreviewScreen))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlbumReaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'spread navigator selects, follows and survives rotation $size dark=$dark',
        (tester) async {
          final album = _album(1, 'square', innerPages: 24, varied: true);
          final key = await _boot(
            tester,
            size,
            dark,
            1,
            'square',
            catalog: [album],
          );
          await tester.tap(find.byKey(const ValueKey('home-bookshelf-open')));
          await tester.pump();
          for (var i = 0; i < 160; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 8)),
            );
            await tester.pump(const Duration(milliseconds: 24));
            if (find.byType(BookFlip).evaluate().isNotEmpty &&
                tester
                    .widget<BookFlip>(find.byType(BookFlip))
                    .controller!
                    .isReady &&
                find.byType(HomeAlbumCoverThumbnail).evaluate().isEmpty)
              break;
          }
          final controller = tester
              .widget<BookFlip>(find.byType(BookFlip))
              .controller!;
          expect(controller.isReady, isTrue);
          final landscape = size.width > size.height;
          final list = find.byKey(
            ValueKey(landscape ? 'reader-spread-rail' : 'reader-spread-strip'),
          );
          final target = find.byKey(
            ValueKey(landscape ? 'reader-rail-spread-12' : 'reader-spread-12'),
          );
          await tester.scrollUntilVisible(
            target,
            200,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
            maxScrolls: 25,
          );
          await tester.ensureVisible(target);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(target);
          for (var i = 0; i < 200; i++) {
            await tester.pump(const Duration(milliseconds: 24));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 2)),
            );
            if (controller.currentSpread == 12 && !controller.isAnimating)
              break;
          }
          await tester.pump(const Duration(milliseconds: 320));
          await tester.pumpAndSettle(const Duration(milliseconds: 40));
          expect(controller.currentSpread, 12);
          expect(target.hitTestable(), findsOneWidget);
          expect(find.text('23-24'), findsWidgets);
          if (!landscape) {
            expect(
              tester
                  .widget<Text>(
                    find.byKey(const ValueKey('reader-page-position')),
                  )
                  .data,
              '23-24 / 24',
            );
          }
          await _save(
            tester,
            key,
            'reader-spread-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          tester.view.physicalSize = Size(size.height, size.width);
          await tester.pump();
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 8)),
            );
            await tester.pump(const Duration(milliseconds: 24));
            if (find.byType(BookFlip).evaluate().isNotEmpty &&
                tester
                    .widget<BookFlip>(find.byType(BookFlip))
                    .controller!
                    .isReady)
              break;
          }
          expect(find.byType(BookFlip), findsOneWidget);
          expect(
            tester
                .widget<BookFlip>(find.byType(BookFlip))
                .controller!
                .currentSpread,
            12,
          );
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  test('cover themes never reference a removed image asset', () {
    for (final theme in CoverTheme.values) {
      final asset = theme.imageAsset;
      if (asset != null)
        expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  testWidgets(
    'closed book keeps soft directional shadows at both render scales',
    (tester) async {
      for (final width in [500.0, 200.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: SnapFitTheme.light(),
            home: Center(
              child: HomeCoverFrame(
                width: width,
                height: width,
                shadowScale: 1,
                showShadow: true,
                showBookDepth: true,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        );
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(HomeCoverFrame),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.boxShadow, hasLength(2));
        final shadow = decoration.boxShadow!.first;
        final scale = width / 500;
        expect(shadow.blurRadius, closeTo(56 * scale, .0001));
        expect(shadow.spreadRadius, closeTo(-8 * scale, .0001));
        expect(shadow.offset, Offset(-4 * scale, 22 * scale));
        expect(shadow.color, Colors.black.withValues(alpha: .13));
        final contact = decoration.boxShadow!.last;
        expect(contact.blurRadius, 14 * scale);
        expect(contact.spreadRadius, -2 * scale);
        expect(contact.offset, Offset(-1, 4) * scale);
        expect(contact.color, Colors.black.withValues(alpha: .115));
      }
    },
  );

  test(
    'B cover has an inset binding groove without a harsh border or glossy seam',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xff7aa0c0), BlendMode.src);
      AlbumCoverFinishPainter().paint(canvas, const Size(500, 600));
      final picture = recorder.endRecording();
      final image = await picture.toImage(500, 600);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int red(int x, int y) => bytes.getUint8((y * 500 + x) * 4);
      // Average scanlines so gradient dithering is not mistaken for a fold.
      final hinge = List.generate(32, (x) {
        var sum = 0;
        for (var y = 280; y < 320; y++) {
          sum += red(x, y);
        }
        return sum / 40;
      });
      final low = hinge.reduce((a, b) => a < b ? a : b);
      final high = hinge.reduce((a, b) => a > b ? a : b);
      // The supplied B crop has about 61 RGB levels between roll and groove.
      expect(high - low, inInclusiveRange(45, 70));
      double band(int start, int end) =>
          hinge.sublist(start, end).reduce((a, b) => a + b) / (end - start);
      expect(band(18, 21), lessThan(band(12, 15) - 30));
      expect(band(18, 21), lessThan(band(27, 32) - 22));
      expect(band(0, 4), greaterThan(90));
      expect(band(12, 15), greaterThan(band(0, 4) + 15));
      expect(band(24, 27), greaterThan(band(18, 21) + 22));
      for (var x = 1; x < hinge.length; x++) {
        expect(
          (hinge[x] - hinge[x - 1]).abs(),
          lessThan(30),
          reason: 'Abrupt light at column $x',
        );
      }
      for (final x in [18, 20, 22]) {
        expect((red(x, 150) - red(x, 450)).abs(), lessThanOrEqualTo(3));
      }
      for (final x in [100, 250, 400]) {
        expect((red(x, 269) - red(x, 270)).abs(), lessThanOrEqualTo(1));
        expect((red(x, 270) - red(x, 271)).abs(), lessThanOrEqualTo(1));
      }
      image.dispose();
      picture.dispose();
    },
  );

  test(
    'B binding has a broad inward highlight and a narrow recessed hinge',
    () {
      final roll = List.generate(
        100,
        (i) => AlbumSpineSurface.spineEnd * i / 99,
      );
      final peak = roll.reduce(
        (a, b) =>
            AlbumSpineSurface.light(a) > AlbumSpineSurface.light(b) ? a : b,
      );
      expect(AlbumSpineSurface.projectedX(peak), inInclusiveRange(.024, .029));
      final hinge = List.generate(
        100,
        (i) =>
            AlbumSpineSurface.spineEnd +
            (AlbumSpineSurface.flatStart - AlbumSpineSurface.spineEnd) * i / 99,
      );
      final trough = hinge.reduce(
        (a, b) =>
            AlbumSpineSurface.light(a) < AlbumSpineSurface.light(b) ? a : b,
      );
      expect(
        AlbumSpineSurface.projectedX(trough),
        inInclusiveRange(.037, .040),
      );
      expect(AlbumSpineSurface.light(peak), greaterThan(.19));
      expect(AlbumSpineSurface.light(trough), lessThan(-.20));
      expect(AlbumSpineSurface.light(.048), greaterThan(-.015));
    },
  );

  test(
    'native binding matches the B reference shoulder, crest and trough colors',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // B's unshaded sky: RGB(122,160,192). Compare width-normalized sample points.
      canvas.drawColor(const Color(0xff7aa0c0), BlendMode.src);
      AlbumCoverFinishPainter().paint(canvas, const Size(1000, 1000));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 1000);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final samples = <(double, List<int>)>[
          (.010, [132, 167, 198]),
          (.018, [129, 166, 198]),
          (.027, [150, 179, 205]),
          (.040, [89, 117, 141]),
          (.046, [116, 150, 181]),
          (.050, [122, 159, 191]),
        ];
        for (final sample in samples) {
          final x = ((sample.$1 - AlbumSpineSurface.referenceSideInset) * 1000)
              .floor();
          final offset = (130 * 1000 + x) * 4;
          for (var channel = 0; channel < 3; channel++) {
            expect(
              bytes.getUint8(offset + channel),
              closeTo(sample.$2[channel], 6),
              reason: 'B reference at ${sample.$1}, channel $channel',
            );
          }
        }
      } finally {
        image.dispose();
        picture.dispose();
      }
    },
  );

  for (final ratio in [.75, 1.0, 4 / 3]) {
    testWidgets(
      'outside spine continues the artwork, not a white cloth rim: $ratio',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        const photo = Color(0xffa03040);
        Widget coverScene(bool artwork) => MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xff131a18),
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateY(-.10)
                    ..rotateX(-.04),
                  child: HomeCoverFrame(
                    width: 200,
                    height: 200 / ratio,
                    shadowScale: 1,
                    showShadow: false,
                    showBookDepth: true,
                    bindingArtwork: artwork
                        ? const ColoredBox(color: photo)
                        : null,
                    child: const ColoredBox(color: photo),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(coverScene(false));
        final bounds = tester.getRect(find.byType(HomeCoverFrame));
        final plain = await _pixels(tester, key);
        await tester.pumpWidget(coverScene(true));
        expect(tester.getRect(find.byType(HomeCoverFrame)), bounds);
        final wrapped = await _pixels(tester, key);
        var tinted = 0;
        var pale = 0;
        for (var y = bounds.top.ceil() + 10; y < bounds.bottom - 10; y++) {
          for (var x = bounds.left.floor() - 8; x <= bounds.left.ceil(); x++) {
            final offset = (y * 400 + x) * 4;
            if (plain.getUint32(offset) == wrapped.getUint32(offset)) continue;
            final r = wrapped.getUint8(offset);
            final g = wrapped.getUint8(offset + 1);
            final b = wrapped.getUint8(offset + 2);
            if (r > 70 && r > g * 2 && r > b * 1.6) tinted++;
            if (r > 200 && g > 200 && b > 200) pale++;
          }
        }
        expect(tinted, greaterThan(bounds.height * .5));
        expect(pale, 0);
        for (var y = bounds.top.ceil() + 10; y < bounds.bottom - 10; y += 13) {
          for (var x = bounds.left.ceil() + 8; x < bounds.right - 8; x += 17) {
            final offset = (y * 400 + x) * 4;
            expect(wrapped.getUint32(offset), plain.getUint32(offset));
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('paper thickness has no dark outer border or ruled lines', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffeff2f1), BlendMode.src);
    AlbumBookDepthPainter(
      worldTransform: () => Matrix4.identity()
        ..setEntry(3, 2, .0008)
        ..rotateX(-.28)
        ..rotateY(.34),
    ).paint(canvas, const Size(300, 400));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 400),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(310, 410);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (x < 300 && y < 400) continue;
        final offset = (y * image.width + x) * 4;
        for (var channel = 0; channel < 3; channel++) {
          expect(bytes!.getUint8(offset + channel), greaterThanOrEqualTo(200));
        }
      }
    }
    image.dispose();
    picture.dispose();
  });

  test(
    'closed cover does not expose a white shelf below the photograph',
    () async {
      const background = Color(0xffeff2f1);
      for (final ratio in [.75, 1.0, 4 / 3]) {
        final size = Size(300, 300 / ratio);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(background, BlendMode.src);
        canvas.translate(20, 20);
        AlbumBookDepthPainter().paint(canvas, size);
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xff407784),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(340, (size.height + 40).ceil());
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var y = (size.height + 22).ceil(); y < size.height + 26; y++) {
          for (var x = 25; x < 315; x++) {
            final offset = (y * image.width + x) * 4;
            expect(bytes.getUint8(offset), 239);
            expect(bytes.getUint8(offset + 1), 242);
            expect(bytes.getUint8(offset + 2), 241);
          }
        }
        image.dispose();
        picture.dispose();
      }
    },
  );

  for (final ratio in [.75, 1.0, 4 / 3]) {
    testWidgets(
      'photo wraps the spine without changing saved artwork: $ratio',
      (tester) async {
        tester.view.physicalSize = const Size(600, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final size = Size(500, 500 / ratio);
        final photo = LayerModel(
          id: 'full-bleed',
          type: LayerType.image,
          position: const Offset(14, 0),
          width: 486,
          height: size.height,
          imageUrl: 'asset:photo.jpg',
          imageOffset: const Offset(72, 24),
          imageZoom: 1.4,
        );
        final stored = LayerExportMapper.toJson(
          photo,
          canvasSize: size,
          isCover: true,
        );
        const photoColor = Color(0xff407784);
        for (final wrap in [false, true]) {
          final key = GlobalKey();
          late LayerModel displayed;
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CoverLayout(
                      aspect: ratio,
                      layers: [photo],
                      isInteracting: false,
                      leftSpine: 14,
                      wrapSpineArtwork: wrap,
                      theme: CoverTheme.classic,
                      onCoverSizeChanged: (_) {},
                      sortedByZ: (layers) => layers,
                      buildText: (_) => const SizedBox(),
                      buildImage: (layer) {
                        displayed = layer;
                        return Positioned(
                          left: layer.position.dx,
                          top: layer.position.dy,
                          width: layer.width,
                          height: layer.height,
                          child: const ColoredBox(color: photoColor),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(displayed.position, Offset(wrap ? 0 : 14, 0));
          expect(displayed.width, wrap ? 500 : 486);
          expect(displayed.height, photo.height);
          expect(displayed.imageZoom, photo.imageZoom);
          expect(
            displayed.imageAlignment,
            photo.imageAlignment,
            reason: 'Crop alignment must not move when extending the binding.',
          );
          final bytes = await _pixels(tester, key);
          final offset = ((size.height ~/ 2) * 500 + 5) * 4;
          final rgb = List.generate(
            3,
            (channel) => bytes.getUint8(offset + channel),
          );
          expect(
            rgb,
            wrap ? equals([64, 119, 132]) : isNot(equals([64, 119, 132])),
          );
          expect(
            LayerExportMapper.toJson(photo, canvasSize: size, isCover: true),
            stored,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  testWidgets(
    'spine wrapping leaves inset, framed and empty photos unchanged',
    (tester) async {
      final background = LayerModel(
        id: 'background',
        type: LayerType.image,
        position: const Offset(14, 0),
        width: 486,
        height: 500,
        imageUrl: 'asset:photo.jpg',
      );
      final layers = [
        background.copyWith(
          id: 'inset',
          position: const Offset(40, 20),
          width: 430,
          height: 450,
        ),
        background.copyWith(id: 'framed', imageBackground: 'polaroid'),
        background.copyWith(id: 'empty', clearImage: true),
        background.copyWith(id: 'rotated', rotation: 2),
        background.copyWith(id: 'scaled', scale: .95),
        background.copyWith(id: 'bleed', position: Offset.zero, width: 500),
        background.copyWith(id: 'sticker', type: LayerType.sticker),
      ];
      final displayed = <LayerModel>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 500,
              height: 500,
              child: CoverLayout(
                aspect: 1,
                layers: layers,
                isInteracting: false,
                leftSpine: 14,
                wrapSpineArtwork: true,
                theme: CoverTheme.classic,
                onCoverSizeChanged: (_) {},
                sortedByZ: (layers) => layers,
                buildText: (_) => const SizedBox(),
                buildImage: (layer) {
                  displayed.add(layer);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(displayed, hasLength(layers.length));
      for (var i = 0; i < layers.length; i++) {
        expect(displayed[i], same(layers[i]));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final ratio in [.75, 1.0, 4 / 3]) {
    testWidgets(
      'front-facing depth survives fitting and reader rescaling: $ratio',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        const background = Color(0xffeff2f1);

        Widget scene(double sourceWidth, double logicalWidth, double scale) {
          return MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: background,
                child: Center(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(scale, scale, scale),
                    child: SizedBox(
                      width: sourceWidth,
                      height: sourceWidth / ratio,
                      child: FittedBox(
                        child: HomeCoverFrame(
                          width: logicalWidth,
                          height: logicalWidth / ratio,
                          shadowScale: 1,
                          showShadow: false,
                          showBookDepth: true,
                          bookDepth: HomeCoverFrame.depthForWidth(sourceWidth),
                          child: const ColoredBox(color: Color(0xff407784)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        Future<(int, double, double)> body() async {
          final bytes = await _pixels(tester, key);
          var count = 0;
          var totalX = 0;
          var totalY = 0;
          final front = Rect.fromCenter(
            center: const Offset(200, 350),
            width: 200,
            height: 200 / ratio,
          ).inflate(.25);
          for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
            final x = (offset ~/ 4) % 400;
            final y = (offset ~/ 4) ~/ 400;
            if (front.contains(Offset(x.toDouble(), y.toDouble()))) continue;
            if (bytes.getUint8(offset) == 239 &&
                bytes.getUint8(offset + 1) == 242 &&
                bytes.getUint8(offset + 2) == 241)
              continue;
            count++;
            totalX += x;
            totalY += y;
          }
          // A thin side remains visible without an exposed white bottom shelf.
          expect(count, greaterThan(200 / ratio * .5));
          return (count, totalX / count, totalY / count);
        }

        await tester.pumpWidget(scene(200, 200, 1));
        final reader = await body();
        for (final configuration in [
          (200.0, 500.0, 1.0),
          (280.0, 500.0, 200 / 280),
        ]) {
          await tester.pumpWidget(
            scene(configuration.$1, configuration.$2, configuration.$3),
          );
          final fitted = await body();
          expect(fitted.$1, closeTo(reader.$1, 35));
          expect(fitted.$2, closeTo(reader.$2, 2));
          expect(fitted.$3, closeTo(reader.$3, 2));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('volume really renders on either side at ratio $ratio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final yaw = ValueNotifier<double>(-.55);
      addTearDown(yaw.dispose);
      final key = GlobalKey();
      Widget scene(bool depth) => MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xffeff2f1),
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: yaw,
                child: HomeCoverFrame(
                  width: 200,
                  height: 200 / ratio,
                  shadowScale: 1,
                  showShadow: false,
                  showMaterial: true,
                  showBookDepth: depth,
                  bookMotion: yaw,
                  child: const ColoredBox(color: Color(0xff407784)),
                ),
                builder: (_, angle, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0008)
                    ..rotateX(-.28)
                    ..rotateY(angle),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      final bare = <ByteData>[];
      await tester.pumpWidget(scene(false));
      bare.add(await _pixels(tester, key));
      yaw.value = .55;
      await tester.pump();
      bare.add(await _pixels(tester, key));
      yaw.value = -.55;
      await tester.pumpWidget(scene(true));
      for (var side = 0; side < 2; side++) {
        if (side == 1) {
          yaw.value = .55;
          await tester.pump();
        }
        final body = await _pixels(tester, key);
        var changed = 0;
        var totalX = 0;
        for (var offset = 0; offset < body.lengthInBytes; offset += 4) {
          if (body.getUint32(offset) == bare[side].getUint32(offset)) continue;
          changed++;
          totalX += (offset ~/ 4) % 400;
        }
        expect(changed, greaterThan(80));
        expect(totalX / changed, side == 0 ? lessThan(200) : greaterThan(200));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'bookshelf selects albums without an old control capsule: $size',
      (tester) async {
        final album = _album(1, 'square');
        await _boot(
          tester,
          size,
          false,
          1,
          'square',
          catalog: [album, album.copyWith(id: 18), album.copyWith(id: 19)],
        );
        expect(find.text('s n a p f i t'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
        expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
        expect(
          find.descendant(
            of: find.byType(HomeAlbumSlider),
            matching: find.byWidgetPredicate(
              (widget) => widget is ExperienceIcon && widget.name == 'BookOpen',
            ),
          ),
          findsOneWidget,
        );
        final wordmark = tester.widget<Text>(
          find.byKey(const ValueKey('home-bookshelf-wordmark')),
        );
        expect(wordmark.style!.fontFamily, 'Poppins');
        expect(wordmark.style!.fontWeight, FontWeight.w700);
        expect(wordmark.style!.fontSize, 18);
        expect(wordmark.style!.letterSpacing, 0);
        for (final name in ['Menu', 'Plus']) {
          final action = find.byWidgetPredicate(
            (widget) => widget is ExperienceIcon && widget.name == name,
          );
          expect(action, findsOneWidget);
          final button = find.ancestor(
            of: action,
            matching: find.byType(IconButton),
          );
          expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));
        }
        final open = tester.widget<GestureDetector>(
          find.byKey(const ValueKey('home-bookshelf-open')),
        );
        expect(open.behavior, HitTestBehavior.opaque);
        expect(open.onTap, isNotNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('home-bookshelf-open')))
              .shortestSide,
          greaterThanOrEqualTo(44),
        );
        for (final id in [18, 19]) {
          final preview = find.byKey(ValueKey('home-shelf-album-$id'));
          expect(
            tester.getSize(preview).shortestSide,
            greaterThanOrEqualTo(44),
          );
          await tester.tap(preview);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          final shelf = tester.widget<HomeAlbumShelf>(
            find.byType(HomeAlbumShelf),
          );
          expect(shelf.albums[shelf.selectedIndex].id, id);
          final line = tester.widget<AnimatedContainer>(
            find.byKey(ValueKey('home-shelf-selection-$id')),
          );
          expect(
            (line.decoration! as BoxDecoration).color,
            SnapFitColors.accent,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final dark in [false, true]) {
      testWidgets('open control stays quiet and legible: $size dark=$dark', (
        tester,
      ) async {
        await _boot(tester, size, dark, 1, 'square');
        final iconFinder = find.descendant(
          of: find.byType(HomeAlbumSlider),
          matching: find.byWidgetPredicate(
            (widget) => widget is ExperienceIcon && widget.name == 'BookOpen',
          ),
        );
        final icon = tester.widget<ExperienceIcon>(iconFinder);
        expect(tester.getSize(iconFinder), const Size(26, 26));
        final context = tester.element(iconFinder);
        final surface = tester.widget<Container>(
          find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
        );
        final decoration = surface.decoration! as BoxDecoration;
        expect(decoration.color, AlbumStageStyle.controlFill(context));
        expect(decoration.boxShadow, isNull);
        expect(decoration.border, isNotNull);
        final inkLuminance = icon.color!.computeLuminance();
        final fillLuminance = decoration.color!.computeLuminance();
        final contrast = dark
            ? (inkLuminance + .05) / (fillLuminance + .05)
            : (fillLuminance + .05) / (inkLuminance + .05);
        expect(contrast, greaterThan(4.5));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('home-bookshelf-open')))
              .shortestSide,
          greaterThanOrEqualTo(44),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('home drag follows the finger, cancels and settles: $size', (
      tester,
    ) async {
      final album = _album(1, 'square');
      await _boot(
        tester,
        size,
        false,
        1,
        'square',
        catalog: [album, album.copyWith(id: 18), album.copyWith(id: 19)],
      );
      HomeAlbumSliderCard card(int index) => tester
          .widgetList<HomeAlbumSliderCard>(find.byType(HomeAlbumSliderCard))
          .singleWhere((card) => card.index == index);
      final before = AlbumOpenOrigin.capture(card(0).coverOriginKey!)!;
      final stationaryCard = card(0);
      final stationaryShelf = tester.widget(find.byType(HomeAlbumShelf));
      final stationaryCover = tester.widget(
        find.descendant(
          of: find.byKey(const ValueKey('home_album_17')),
          matching: find.byType(HomeAlbumCoverThumbnail),
        ),
      );
      double position(int index) =>
          card(index).pagePosition?.value ?? card(index).currentPage;
      final beforeBounds = MatrixUtils.transformRect(
        before.transform,
        Offset.zero & before.size,
      );
      final start = tester.getCenter(
        find.byKey(const ValueKey('home-bookshelf-swipe')),
      );
      final partial = await tester.startGesture(start);
      await partial.moveBy(const Offset(-20, 0));
      await tester.pump();
      await partial.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(position(0), greaterThan(0));
      expect(position(0), lessThan(1));
      expect(card(0), same(stationaryCard));
      expect(tester.widget(find.byType(HomeAlbumShelf)), same(stationaryShelf));
      expect(
        tester.widget(
          find.descendant(
            of: find.byKey(const ValueKey('home_album_17')),
            matching: find.byType(HomeAlbumCoverThumbnail),
          ),
        ),
        same(stationaryCover),
      );
      final dragged = AlbumOpenOrigin.capture(card(0).coverOriginKey!)!;
      final draggedBounds = MatrixUtils.transformRect(
        dragged.transform,
        Offset.zero & dragged.size,
      );
      expect(draggedBounds.center.dx, lessThan(beforeBounds.center.dx));
      await partial.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(position(0), closeTo(0, .0001));

      final full = await tester.startGesture(start);
      await full.moveBy(const Offset(-20, 0));
      await tester.pump();
      await full.moveBy(const Offset(-180, 0));
      await full.moveBy(const Offset(-500, 0));
      await tester.pump();
      expect(position(1), lessThanOrEqualTo(1));
      await tester.pump(const Duration(milliseconds: 400));
      await full.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(position(1), closeTo(1, .0001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('spaced wordmark stays centered and clears header actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    try {
      for (final size in [
        const Size(320, 568),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        for (final scale in [1.0, 1.6, 2.0]) {
          for (final hasDraft in [false, true]) {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: SnapFitTheme.light(),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: HomeAlbumSlider(
                      albums: const [],
                      onOpenAlbumTab: () {},
                      onCreateAlbum: () {},
                      onResumeDraft: hasDraft ? () {} : null,
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final wordmark = find.byKey(
              const ValueKey('home-bookshelf-wordmark'),
            );
            final paragraph = tester.renderObject<RenderBox>(wordmark);
            final bounds = MatrixUtils.transformRect(
              paragraph.getTransformTo(null),
              Offset.zero & paragraph.size,
            );
            expect(bounds.center.dx, closeTo(size.width / 2, .01));
            expect(find.bySemanticsLabel('snapfit'), findsOneWidget);
            for (final name in ['Menu', 'Plus', if (hasDraft) 'History']) {
              final action = find.byWidgetPredicate(
                (widget) => widget is ExperienceIcon && widget.name == name,
              );
              final button = find.ancestor(
                of: action,
                matching: find.byType(IconButton),
              );
              final actionBounds = tester.getRect(button);
              expect(bounds.overlaps(actionBounds), isFalse);
              expect(actionBounds.shortestSide, greaterThanOrEqualTo(44));
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('selected album status follows saved progress and access', (
    tester,
  ) async {
    final working = _album(1, 'square', innerPages: 2).copyWith(targetPages: 8);
    final completed = _album(1, 'square').copyWith(id: 18, title: '두 번째 앨범');
    await _boot(
      tester,
      const Size(390, 844),
      false,
      1,
      'square',
      catalog: [working, completed],
      reduceMotion: true,
    );
    final status = find.byKey(const ValueKey('home-focused-album-status'));
    String label() => tester.widget<Text>(status).data!;
    expect(label(), '3/8 페이지 진행 중');
    await tester.tap(find.byTooltip('다음 앨범'));
    await tester.pump();
    expect(label(), '완성한 앨범');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-focused-album-title')))
          .data,
      '두 번째 앨범',
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeAlbumSlider)),
    );
    final home =
        container.read(homeViewModelProvider.notifier) as _ChangingHome;
    for (final state in [
      (working.copyWith(id: 18, targetPages: 0), '3 페이지 진행 중'),
      (working.copyWith(id: 18, memberRole: 'VIEWER'), '보기 전용 · 3/8 페이지 진행 중'),
      (
        working.copyWith(id: 18, lockedById: 'other', lockedBy: '함께 만드는 사람'),
        '3/8 페이지 진행 중',
      ),
    ]) {
      home.replaceAlbums([working, state.$1]);
      await tester.pumpAndSettle();
      expect(label(), state.$2);
      final shelf = tester.widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf));
      expect(shelf.albums[shelf.selectedIndex].id, 18);
      expect(tester.takeException(), isNull);
    }
    expect(tester.widget<Text>(status).semanticsLabel, '앨범 상태, 3/8 페이지 진행 중');
    home.replaceAlbums(const []);
    await tester.pumpAndSettle();
    expect(status, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('selected album status fits large text and landscape controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final album = _album(
      1,
      'square',
      innerPages: 2,
    ).copyWith(targetPages: 8, title: '긴 이름으로 남긴 우리의 앨범', memberRole: 'VIEWER');
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(
              theme: SnapFitTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: HomeAlbumSlider(
                albums: [album],
                onOpenAlbumTab: () {},
                onCreateAlbum: () {},
                onResumeDraft: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final size in [const Size(320, 568), const Size(648, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final title = find.byKey(const ValueKey('home-focused-album-title'));
        final status = find.byKey(const ValueKey('home-focused-album-status'));
        final statusBounds = tester.getRect(status);
        expect(tester.getRect(title).overlaps(statusBounds), isFalse);
        expect(
          statusBounds.bottom,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('home-bookshelf-stage')))
                .top,
          ),
        );
        for (final tooltip in ['앨범 목록', '새 앨범', '이어 만들기']) {
          expect(
            tester.getRect(find.byTooltip(tooltip)).overlaps(statusBounds),
            isFalse,
          );
        }
        expect(
          tester.getSemantics(status).getSemanticsData().label,
          contains('보기 전용 · 3/8 페이지 진행 중'),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  });

  for (final scene in [
    (const Size(390, 844), false, 'home-collection-390-light'),
    (const Size(390, 844), true, 'home-collection-390-dark'),
    (const Size(844, 390), false, 'home-collection-844-light'),
  ]) {
    testWidgets(
      'bookshelf composition keeps one hero and four real previews: ${scene.$3}',
      (tester) async {
        final albums = [
          _album(1, 'square'),
          _album(4 / 3, 'landscape').copyWith(id: 18),
          _album(.75, 'portrait').copyWith(id: 19),
          _album(
            1,
            'family',
            photoAsset:
                'assets/templates/original_editorial/images/cover_family_supper.png',
          ).copyWith(id: 20),
        ];
        final key = await _boot(
          tester,
          scene.$1,
          scene.$2,
          1,
          'square',
          catalog: albums,
        );
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pump();
        final cards = tester.widgetList<HomeAlbumSliderCard>(
          find.byType(HomeAlbumSliderCard),
        );
        final focused = cards.singleWhere((card) => card.index == 0);
        final origin = AlbumOpenOrigin.capture(focused.coverOriginKey!)!;
        final bounds = MatrixUtils.transformRect(
          origin.transform,
          Offset.zero & origin.size,
        );
        final stage = tester.getRect(
          find.byKey(const ValueKey('home-bookshelf-stage')),
        );
        expect(bounds.center.dx, closeTo(stage.center.dx, 2));
        expect(stage.contains(bounds.topLeft), isTrue);
        expect(stage.contains(bounds.bottomRight), isTrue);
        for (final side in cards.where((card) => card.index != 0)) {
          final neighbour = AlbumOpenOrigin.capture(side.coverOriginKey!)!;
          final offscreen = MatrixUtils.transformRect(
            neighbour.transform,
            Offset.zero & neighbour.size,
          );
          expect(offscreen.overlaps(stage), isFalse);
        }
        for (final album in albums) {
          final preview = find.byKey(ValueKey('home-shelf-album-${album.id}'));
          expect(preview, findsOneWidget);
          final previewBounds = tester.getRect(preview);
          expect(previewBounds.overlaps(bounds), isFalse);
        }
        final coverBounds = [
          for (final album in albums)
            tester.getRect(
              find.byKey(ValueKey('home-shelf-cover-${album.id}')),
            ),
        ];
        for (var i = 0; i < albums.length; i++) {
          expect(
            coverBounds[i].width / coverBounds[i].height,
            closeTo(albums[i].physicalCoverSize.ratio, .0001),
          );
          final baseline = scene.$1.width > scene.$1.height ? (i ~/ 2) * 2 : 0;
          expect(
            coverBounds[i].bottom,
            closeTo(coverBounds[baseline].bottom, .01),
          );
        }
        await _save(tester, key, scene.$3);
        await _save(
          tester,
          key,
          '${scene.$3}-book-detail',
          crop: bounds.inflate(12),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'shelf is lazy, scrolls independently and retains selection on rotation and refresh',
    (tester) async {
      final albums = List.generate(
        60,
        (i) => _album(1, 'square').copyWith(
          id: 17 + i,
          createdAt: DateTime(
            2025,
            1,
            1,
          ).subtract(Duration(days: i)).toIso8601String(),
        ),
      );
      await _boot(
        tester,
        const Size(390, 844),
        false,
        1,
        'square',
        catalog: albums,
      );
      final state = tester.state(find.byType(HomeAlbumSlider));
      expect(
        find.byType(HomeAlbumCoverThumbnail).evaluate().length,
        lessThanOrEqualTo(10),
      );
      final strip = find.byKey(const ValueKey('home-bookshelf-strip'));
      await tester.drag(strip, const Offset(-360, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf))
            .selectedIndex,
        0,
      );
      final list = tester.widget<ListView>(strip);
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pump();
      final selectedId = tester
          .widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf))
          .albums
          .last
          .id;
      await tester.tap(find.byKey(ValueKey('home-shelf-album-$selectedId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      var shelf = tester.widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf));
      expect(shelf.albums[shelf.selectedIndex].id, selectedId);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.state(find.byType(HomeAlbumSlider)), same(state));
      shelf = tester.widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf));
      expect(shelf.albums[shelf.selectedIndex].id, selectedId);
      expect(
        find.byKey(ValueKey('home-shelf-album-$selectedId')),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      (container.read(homeViewModelProvider.notifier) as _ChangingHome)
          .replaceAlbums(
            albums.reversed.map((album) {
              return album.id == selectedId
                  ? album.copyWith(createdAt: '2026-01-01T00:00:00')
                  : album;
            }).toList(),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      shelf = tester.widget<HomeAlbumShelf>(find.byType(HomeAlbumShelf));
      expect(shelf.albums[shelf.selectedIndex].id, selectedId);
      expect(shelf.selectedIndex, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('selected shelf cover opens the matching reader', (tester) async {
    final albums = [
      _album(1, 'square'),
      _album(.75, 'portrait').copyWith(id: 18, title: '두 번째 앨범'),
    ];
    await _boot(
      tester,
      const Size(390, 844),
      false,
      1,
      'square',
      catalog: albums,
    );
    await tester.tap(find.byKey(const ValueKey('home-shelf-album-18')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-focused-album-title')))
          .data,
      '두 번째 앨범',
    );
    await tester.tap(find.byKey(const ValueKey('home-bookshelf-open')));
    await tester.pump();
    for (
      var i = 0;
      i < 60 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(AlbumReaderScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AlbumReaderScreen)),
    );
    expect(
      container.read(albumEditorViewModelProvider.notifier).editingAlbumId,
      18,
    );
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'opening interpolation preserves perspective and both exact endpoints',
    () {
      final start = AlbumOpenOrigin(
        size: const Size(230, 307),
        transform: Matrix4.identity()
          ..translateByDouble(72, 180, 0, 1)
          ..setEntry(3, 2, .0015)
          ..rotateY(-.16)
          ..rotateZ(.02),
      );
      final end = AlbumOpenOrigin(
        size: const Size(171, 228),
        transform: Matrix4.translationValues(109, 240, 0),
      );
      for (final progress in [0.0, .25, .5, .75, 1.0]) {
        final pose = AlbumOpenOrigin.interpolate(start, end, progress);
        expect(pose.transform.storage.every((value) => value.isFinite), isTrue);
        expect(pose.size.width, closeTo(230 + (171 - 230) * progress, .0001));
      }
      expect(
        AlbumOpenOrigin.interpolate(start, end, 0).transform.storage,
        orderedEquals(start.transform.storage),
      );
      expect(
        AlbumOpenOrigin.interpolate(start, end, 1).transform.storage,
        orderedEquals(end.transform.storage),
      );
    },
  );

  testWidgets('rotation during opening lands on the new reader geometry', (
    tester,
  ) async {
    final key = await _boot(tester, const Size(390, 844), false, 1, 'square');
    await tester.tap(find.byType(HomeAlbumSliderCard));
    await tester.pump(const Duration(milliseconds: 210));
    for (
      var i = 0;
      i < 30 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final reader = tester.widget<AlbumReaderScreen>(
      find.byType(AlbumReaderScreen),
    );
    final destination = AlbumOpenOrigin.capture(reader.openingCoverKey!)!;
    final bounds = MatrixUtils.transformRect(
      destination.transform,
      Offset.zero & destination.size,
    );
    final moving = tester.getRect(find.byType(HomeAlbumCoverThumbnail));
    expect((moving.center - bounds.center).distance, lessThan(2));
    expect(moving.width, closeTo(bounds.width, 2));
    await tester.pump(const Duration(milliseconds: 100));
    await _save(tester, key, 'reader-opening-rotation');
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets(
    'back during opening removes the copy and allows another album tap',
    (tester) async {
      await _boot(tester, const Size(390, 844), false, 1, 'square');
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byType(HomeAlbumSliderCard));
        await tester.pump(const Duration(milliseconds: 210));
        for (
          var i = 0;
          i < 30 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(AlbumReaderScreen), findsOneWidget);
        Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(AlbumReaderScreen), findsNothing);
        expect(
          find.descendant(
            of: find.byType(HomeAlbumSliderCard),
            matching: find.byType(HomeAlbumCoverThumbnail),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final shape in {
    'portrait': .75,
    'square': 1.0,
    'landscape': 4 / 3,
  }.entries) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      for (final dark in [false, true]) {
        final name =
            '${shape.key}-${size.width.toInt()}-${dark ? 'dark' : 'light'}';
        testWidgets('book body preserves front dimensions and float: $name', (
          tester,
        ) async {
          final key = await _boot(tester, size, dark, shape.value, shape.key);
          final card = tester.widget<HomeAlbumSliderCard>(
            find.byType(HomeAlbumSliderCard),
          );
          final before = AlbumOpenOrigin.capture(card.coverOriginKey!)!;
          _expectFrontFacing(before);
          expect(
            find.descendant(
              of: find.byType(HomeAlbumSliderCard),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is AlbumBookDepthPainter,
              ),
            ),
            findsOneWidget,
          );
          await _save(tester, key, 'home-$name');
          await tester.pump(const Duration(milliseconds: 700));
          final after = AlbumOpenOrigin.capture(card.coverOriginKey!)!;
          _expectFrontFacing(after);
          expect(after.size, before.size);
          expect(
            after.transform.storage,
            isNot(orderedEquals(before.transform.storage)),
          );
          await _save(tester, key, 'home-float-$name');
          for (var phase = 0; phase < 8; phase++) {
            await tester.pump(const Duration(milliseconds: 475));
            final origin = AlbumOpenOrigin.capture(card.coverOriginKey!)!;
            expect(origin.size, before.size);
            _expectFrontFacing(origin);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });

        if (size.width == 320 || dark) continue;
        testWidgets(
          'moving cover lands on the real reader without a size jump: $name',
          (tester) async {
            final key = await _boot(tester, size, dark, shape.value, shape.key);
            final homeFrame = tester.widget<HomeCoverFrame>(
              find.descendant(
                of: find.byType(HomeAlbumSliderCard),
                matching: find.byType(HomeCoverFrame),
              ),
            );
            final homeBinding = homeFrame.bindingColor;
            expect(homeFrame.bindingArtwork, isNotNull);
            final homeArtwork = tester.widget<CoverLayout>(
              find.descendant(
                of: find.byType(HomeAlbumSliderCard),
                matching: find.byType(CoverLayout),
              ),
            );
            expect(homeArtwork.wrapSpineArtwork, isTrue);
            expect(homeArtwork.buildWrappedImage, isNotNull);
            final homeShadows =
                (tester
                            .widget<DecoratedBox>(
                              find
                                  .descendant(
                                    of: find.byWidget(homeFrame),
                                    matching: find.byType(DecoratedBox),
                                  )
                                  .first,
                            )
                            .decoration
                        as BoxDecoration)
                    .boxShadow!;
            await tester.tap(find.byType(HomeAlbumSliderCard));
            await tester.pump(const Duration(milliseconds: 210));
            for (
              var i = 0;
              i < 30 && find.byType(AlbumReaderScreen).evaluate().isEmpty;
              i++
            ) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(find.byType(AlbumReaderScreen), findsOneWidget);
            await tester.pump();
            await _save(tester, key, 'opening-start-$name');
            await tester.pump(const Duration(milliseconds: 300));
            await _save(tester, key, 'opening-middle-$name');
            await tester.pump(const Duration(milliseconds: 280));
            final reader = tester.widget<AlbumReaderScreen>(
              find.byType(AlbumReaderScreen),
            );
            final destination = AlbumOpenOrigin.capture(
              reader.openingCoverKey!,
            )!;
            final landing = MatrixUtils.transformRect(
              destination.transform,
              Offset.zero & destination.size,
            );
            final moving = tester.getRect(find.byType(HomeAlbumCoverThumbnail));
            expect((moving.center - landing.center).distance, lessThan(2));
            expect(moving.width, closeTo(landing.width, 2));
            expect(moving.height, closeTo(landing.height, 2));
            await _save(tester, key, 'opening-landing-$name');
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.byType(HomeAlbumCoverThumbnail), findsNothing);
            expect(reader.openingCoverVisible!.value, isTrue);
            for (
              var i = 0;
              i < 100 && find.byType(BookFlip).evaluate().isEmpty;
              i++
            ) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await tester.pump(const Duration(milliseconds: 16));
            }
            await _save(tester, key, 'reader-$name');
            final frames = tester.widgetList<HomeCoverFrame>(
              find.descendant(
                of: find.byType(AlbumReaderScreen),
                matching: find.byType(HomeCoverFrame),
              ),
            );
            expect(frames.where((frame) => frame.showBookDepth).length, 1);
            expect(
              frames.singleWhere((frame) => frame.showBookDepth).bindingColor,
              homeBinding,
            );
            final readerFrame = frames.singleWhere(
              (frame) => frame.showBookDepth,
            );
            expect(readerFrame.bindingArtwork, isNotNull);
            final readerArtwork = tester.widget<CoverLayout>(
              find.descendant(
                of: find.byWidget(readerFrame),
                matching: find.byType(CoverLayout),
              ),
            );
            expect(readerArtwork.wrapSpineArtwork, isTrue);
            expect(readerArtwork.buildWrappedImage, isNotNull);
            final readerShadows =
                (tester
                            .widget<DecoratedBox>(
                              find
                                  .descendant(
                                    of: find.byWidget(readerFrame),
                                    matching: find.byType(DecoratedBox),
                                  )
                                  .first,
                            )
                            .decoration
                        as BoxDecoration)
                    .boxShadow!;
            for (var i = 0; i < homeShadows.length; i++) {
              expect(readerShadows[i].color, homeShadows[i].color);
              expect(
                readerShadows[i].blurRadius / readerFrame.width,
                closeTo(homeShadows[i].blurRadius / homeFrame.width, .0001),
              );
              final readerOffset = readerShadows[i].offset / readerFrame.width;
              final homeOffset = homeShadows[i].offset / homeFrame.width;
              expect((readerOffset - homeOffset).distance, lessThan(.000001));
            }
            expect(
              find.descendant(
                of: find.byWidget(readerFrame),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is CustomPaint &&
                      widget.painter is AlbumCoverFinishPainter,
                ),
              ),
              findsOneWidget,
            );
            final edit = find.text('편집');
            final editSurface = tester.widget<AnimatedContainer>(
              find
                  .ancestor(of: edit, matching: find.byType(AnimatedContainer))
                  .first,
            );
            expect(
              (editSurface.decoration! as BoxDecoration).color,
              AlbumStageStyle.controlFill(tester.element(edit)),
            );
            expect(find.byType(BookFlip, skipOffstage: false), findsOneWidget);
            expect(tester.takeException(), isNull);
            Navigator.of(tester.element(find.byType(AlbumReaderScreen))).pop();
            await tester.pump(const Duration(milliseconds: 200));
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(milliseconds: 200));
          },
        );
      }
    }
  }
}

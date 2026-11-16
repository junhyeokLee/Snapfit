import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/widgets/home_news_sheet.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _covers = [
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9471.png',
    ratio: 1,
  ),
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9441.png',
    ratio: 1,
  ),
  HomeNewsCover(
    url: 'asset:assets/catalog_thumbnails/template_-9461.png',
    ratio: 1,
  ),
];

final _items = [
  HomeNewsItem(
    id: 'monthly-design:2026-10',
    kind: HomeNewsKind.monthlyDesign,
    title: '사진을 담고 싶은,\n10월의 디자인',
    subtitle: '이번 달의 순간에 어울리는 앨범을 만나보세요.',
    actionLabel: '이달의 디자인 보기',
    month: DateTime(2026, 10),
    covers: _covers,
  ),
  HomeNewsItem(
    id: 'attendance-benefit:v1',
    kind: HomeNewsKind.attendance,
    title: '오늘의 출석에,\n작은 포인트 선물',
    subtitle: '오늘 출석하면 10P를 받을 수 있어요.',
    actionLabel: '출석체크 하러 가기',
    month: DateTime(2026, 10),
    rewardPoints: 10,
  ),
  HomeNewsItem(
    id: 'referral-benefit:v1',
    kind: HomeNewsKind.referral,
    title: '좋아하는 사람과,\n스냅핏을 나눠요',
    subtitle: '친구가 내 초대 코드를 등록하면 100P를 받아요.',
    actionLabel: '친구 초대 혜택 보기',
    month: DateTime(2026, 10),
    rewardPoints: 100,
    covers: _covers,
  ),
  HomeNewsItem(
    id: 'month-review:2026-10',
    kind: HomeNewsKind.monthReview,
    title: '10월의 순간을,\n나의 한 권으로',
    subtitle: '이번 달 남긴 사진 3장을 앨범으로 모아보세요.',
    actionLabel: '이번 달 앨범 만들기',
    month: DateTime(2026, 10),
    covers: const [
      HomeNewsCover(
        url: 'asset:assets/snapfit_home_square.jpg',
        ratio: 960 / 644,
      ),
      HomeNewsCover(
        url: 'asset:assets/snapfit_home_landscape.jpg',
        ratio: 700 / 428,
      ),
      HomeNewsCover(
        url: 'asset:assets/snapfit_home_portrait.jpg',
        ratio: 960 / 640,
      ),
    ],
  ),
];

const _assets = [
  'assets/catalog_thumbnails/template_-9471.png',
  'assets/catalog_thumbnails/template_-9441.png',
  'assets/catalog_thumbnails/template_-9461.png',
  'assets/snapfit_home_square.jpg',
  'assets/snapfit_home_landscape.jpg',
  'assets/snapfit_home_portrait.jpg',
];

Future<void> _loadFonts() async {
  final fonts =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final font in fonts.where(
    (font) => ['NotoSans', 'Poppins', 'MaterialIcons'].contains(font['family']),
  )) {
    final loader = FontLoader(font['family'] as String);
    for (final file in font['fonts'] as List) {
      loader.addFont(rootBundle.load(file['asset'] as String));
    }
    await loader.load();
  }
}

Future<BuildContext> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool reducedMotion = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext pageContext;
  final native = brightness == Brightness.dark
      ? SnapFitTheme.dark()
      : SnapFitTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: size.width >= 760 ? SnapFitWebTheme.from(native) : native,
      builder: (context, child) => RepaintBoundary(
        key: const ValueKey('home-news-layout-proof'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
      ),
      home: Builder(
        builder: (context) {
          pageContext = context;
          return const _AlbumBackdrop();
        },
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final asset in _assets) {
      await precacheImage(AssetImage(asset), pageContext);
    }
  });
  await tester.pumpAndSettle();
  return pageContext;
}

/// The underlying home chrome and book are the production widgets, with local
/// sample photos. The foreground is always the actual modal route.
class _AlbumBackdrop extends StatelessWidget {
  const _AlbumBackdrop();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                HomeAlbumHeader(
                  collection: false,
                  onToggleView: () {},
                  onCreateAlbum: () {},
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 38),
                        HomeCoverFrame(
                          width: desktop ? 340 : 310,
                          height: desktop ? 340 : 310,
                          shadowScale: 1,
                          showShadow: true,
                          showBookDepth: true,
                          child: Image.asset(
                            'assets/snapfit_home_square.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          '우리의 작은 순간들',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '완성한 앨범 · 20페이지',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.book_outlined),
                    Icon(Icons.explore_outlined),
                    Icon(Icons.storefront_outlined),
                    Icon(Icons.person_outline_rounded),
                  ],
                ),
              ),
            ),
    );
  }
}

void main() {
  testWidgets('home news CTA and close return their explicit result', (
    tester,
  ) async {
    final context = await _mount(tester);
    var result = showHomeNewsSheet(context, _items.first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-news-close'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const ValueKey('home-news-action')));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = showHomeNewsSheet(context, _items[1]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide web uses a bounded dialog and dismissible scrim', (
    tester,
  ) async {
    final context = await _mount(tester, size: const Size(1280, 960));
    final result = showHomeNewsSheet(context, _items.first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getSize(find.byType(HomeNewsSheetContent)).width,
      lessThanOrEqualTo(480),
    );
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile news can be dismissed by a downward swipe', (
    tester,
  ) async {
    final context = await _mount(tester, reducedMotion: false);
    final result = showHomeNewsSheet(context, _items.first);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byType(HomeNewsSheetContent));
    await tester.dragFrom(top + const Offset(150, 8), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (name: 'small', size: const Size(320, 568), scale: 2.0),
    (name: 'large-type', size: const Size(390, 844), scale: 1.8),
    (name: 'landscape', size: const Size(844, 390), scale: 1.8),
  ]) {
    testWidgets('news stays readable and actionable at ${layout.name}', (
      tester,
    ) async {
      final context = await _mount(
        tester,
        size: layout.size,
        scale: layout.scale,
      );
      for (final item in _items) {
        final result = showHomeNewsSheet(context, item);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final action = find.byKey(const ValueKey('home-news-action'));
        final close = find.byKey(const ValueKey('home-news-close'));
        expect(action.hitTestable(), findsOneWidget);
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.getBottomRight(action).dy, lessThan(layout.size.height));
        await tester.drag(
          find.byKey(const ValueKey('home-news-content-scroll')),
          const Offset(0, -550),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(item.subtitle).hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(await result, isFalse);
      }
    });
  }

  testWidgets('export all four production news layouts', (tester) async {
    await _loadFonts();
    final layouts = [
      (
        name: 'mobile-light',
        size: const Size(390, 844),
        brightness: Brightness.light,
        scale: 1.0,
      ),
      (
        name: 'desktop-light',
        size: const Size(1280, 960),
        brightness: Brightness.light,
        scale: 1.0,
      ),
      (
        name: 'mobile-dark',
        size: const Size(390, 844),
        brightness: Brightness.dark,
        scale: 1.0,
      ),
      (
        name: 'small-large-type',
        size: const Size(320, 568),
        brightness: Brightness.light,
        scale: 1.8,
      ),
    ];
    for (final layout in layouts) {
      final context = await _mount(
        tester,
        size: layout.size,
        brightness: layout.brightness,
        scale: layout.scale,
      );
      for (var index = 0; index < _items.length; index++) {
        final item = _items[index];
        final result = showHomeNewsCarousel(
          context,
          _items,
          initialIndex: index,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null),
          isNotEmpty,
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('home-news-layout-proof')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'output/home-news-20261028/${item.kind.name}-${layout.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(
          find.byKey(const ValueKey('home-news-page-controls')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-news-hide-today')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('home-news-close')).hitTestable(),
        );
        await tester.pumpAndSettle();
        final closed = await result;
        expect(closed?.action, isFalse);
        expect(closed?.hideForToday, isFalse);
        expect(closed?.item.id, item.id);
      }
    }
  }, skip: !const bool.fromEnvironment('EXPORT_HOME_NEWS_LAYOUT'));
}

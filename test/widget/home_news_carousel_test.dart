import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/widgets/home_news_sheet.dart';

final _items = [
  for (final kind in HomeNewsKind.values)
    HomeNewsItem(
      id: kind.name,
      kind: kind,
      title: '${kind.name} 소식 제목',
      subtitle: '나의 사진과 앨범을 위한 새로운 소식을 확인해보세요.',
      actionLabel: '${kind.name} 열기',
      month: DateTime(2026, 10),
    ),
];

Future<BuildContext> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  bool reduced = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late BuildContext pageContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          pageContext = context;
          return const Scaffold(body: Text('내 앨범'));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pageContext;
}

Finder _visibleKey(String value) => find.byKey(ValueKey(value)).hitTestable();

void main() {
  setUpAll(() async {
    // Chrome's widget-test engine can leave explicit FontLoader.load pending
    // before the first test frame. Browser checks exercise the interaction
    // flow; native exports load the actual fonts for visual measurements.
    if (kIsWeb) return;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest.where(
      (font) => ['NotoSans', 'MaterialIcons'].contains(font['family']),
    )) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
  });

  testWidgets('swipe and dot selection return only the current story CTA', (
    tester,
  ) async {
    final viewed = <String>[];
    final context = await _mount(tester, reduced: false);
    final result = showHomeNewsCarousel(
      context,
      _items,
      onItemViewed: (item) => viewed.add(item.id),
    );
    await tester.pumpAndSettle();
    expect(viewed, ['monthlyDesign']);
    expect(find.text('1 / 4').hitTestable(), findsOneWidget);
    expect(_visibleKey('home-news-page-0'), findsOneWidget);
    expect(tester.getSize(_visibleKey('home-news-page-0')), const Size(44, 44));
    await tester.drag(
      find.byKey(const ValueKey('home-news-pages')),
      const Offset(-340, 0),
    );
    await tester.pumpAndSettle();
    expect(viewed, ['monthlyDesign', 'attendance']);
    expect(find.text('2 / 4').hitTestable(), findsOneWidget);
    await tester.pump();
    expect(viewed, ['monthlyDesign', 'attendance']);
    await tester.tap(_visibleKey('home-news-page-3'));
    await tester.pumpAndSettle();
    expect(viewed.last, 'monthReview');
    expect(find.text('4 / 4').hitTestable(), findsOneWidget);
    await tester.tap(_visibleKey('home-news-action'));
    await tester.pumpAndSettle();
    final selected = await result;
    expect(selected?.item.id, 'monthReview');
    expect(selected?.action, isTrue);
    expect(find.byKey(const ValueKey('home-news-carousel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop arrows and close return the active story', (
    tester,
  ) async {
    final context = await _mount(tester, size: const Size(1280, 960));
    final viewed = <String>[];
    final result = showHomeNewsCarousel(
      context,
      _items,
      initialIndex: 1,
      onItemViewed: (item) => viewed.add(item.id),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(viewed, ['attendance']);
    await tester.tap(_visibleKey('home-news-next'));
    await tester.pumpAndSettle();
    expect(viewed.last, 'referral');
    await tester.tap(_visibleKey('home-news-previous'));
    await tester.pumpAndSettle();
    expect(viewed, ['attendance', 'referral', 'attendance']);
    await tester.tap(_visibleKey('home-news-close'));
    await tester.pumpAndSettle();
    final selected = await result;
    expect(selected?.item.id, 'attendance');
    expect(selected?.action, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single story has no carousel controls and empty list is inert', (
    tester,
  ) async {
    final context = await _mount(tester);
    expect(await showHomeNewsCarousel(context, const []), isNull);
    expect(find.byType(BottomSheet), findsNothing);
    final viewed = <String>[];
    final result = showHomeNewsCarousel(
      context,
      [_items.first],
      initialIndex: 50,
      onItemViewed: (item) => viewed.add(item.id),
    );
    await tester.pumpAndSettle();
    expect(viewed, ['monthlyDesign']);
    expect(find.byKey(const ValueKey('home-news-page-controls')), findsNothing);
    await tester.tap(_visibleKey('home-news-action'));
    await tester.pumpAndSettle();
    expect((await result)?.item.id, 'monthlyDesign');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion jumps pages and wrapper belongs to modal route', (
    tester,
  ) async {
    final context = await _mount(tester);
    ModalRoute<dynamic>? modal;
    final result = showHomeNewsCarousel(
      context,
      _items,
      contentWrapper: (child) => Builder(
        builder: (context) {
          modal = ModalRoute.of(context);
          return child;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(modal, isA<ModalBottomSheetRoute<dynamic>>());
    await tester.tap(_visibleKey('home-news-page-2'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 4').hitTestable(), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(_visibleKey('home-news-close'));
    await tester.pumpAndSettle();
    expect((await result)?.item.id, 'referral');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty monthly records do not substitute someone else photos', (
    tester,
  ) async {
    final context = await _mount(tester);
    final result = showHomeNewsCarousel(context, _items, initialIndex: 3);
    await tester.pumpAndSettle();
    expect(_visibleKey('home-news-empty-record-artwork'), findsOneWidget);
    await tester.tap(_visibleKey('home-news-close'));
    await tester.pumpAndSettle();
    await result;
    expect(tester.takeException(), isNull);
  });

  for (final layout in [
    (size: const Size(320, 568), scale: 2.0, dark: false),
    (size: const Size(390, 844), scale: 1.8, dark: true),
    (size: const Size(844, 390), scale: 1.8, dark: false),
  ]) {
    testWidgets('all carousel pages fit ${layout.size} ${layout.scale}', (
      tester,
    ) async {
      final context = await _mount(
        tester,
        size: layout.size,
        scale: layout.scale,
        dark: layout.dark,
      );
      final result = showHomeNewsCarousel(context, _items);
      await tester.pumpAndSettle();
      for (var index = 0; index < _items.length; index++) {
        await tester.tap(_visibleKey('home-news-page-$index'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_visibleKey('home-news-action'), findsOneWidget);
        expect(_visibleKey('home-news-close'), findsOneWidget);
        expect(_visibleKey('home-news-page-controls'), findsOneWidget);
        await tester.drag(
          _visibleKey('home-news-content-scroll'),
          const Offset(0, -650),
        );
        await tester.pumpAndSettle();
        expect(find.text(_items[index].subtitle).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(_visibleKey('home-news-close'));
      await tester.pumpAndSettle();
      expect((await result)?.item.id, 'monthReview');
    });
  }
}

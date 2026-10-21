import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/presentation/widgets/web/web_catalog_toolbar.dart';
import 'package:snap_fit/features/store/presentation/widgets/web/web_catalog_footer.dart';
import 'package:snap_fit/features/store/presentation/widgets/web/web_design_detail_layout.dart';
import 'package:snap_fit/shared/web/web_design.dart';

Widget _app(Widget child, {bool dark = false, double textScale = 1}) =>
    MaterialApp(
      theme: SnapFitWebTheme.from(
        ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

void main() {
  testWidgets(
    'catalog filters wrap without overflow at desktop and narrow text scales',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      for (final width in [1440.0, 1024.0, 768.0, 390.0, 320.0]) {
        for (final dark in [false, true]) {
          tester.view.physicalSize = Size(width, 1100);
          await tester.pumpWidget(
            _app(
              SingleChildScrollView(
                child: WebCatalogToolbar(
                  controller: controller,
                  searchHint: '템플릿 이름, 주제, 키워드 검색',
                  onSearchChanged: (_) {},
                  categories: const ['전체', '여행', '반려동물', '가족', '일상'],
                  category: '전체',
                  onCategoryChanged: (_) {},
                  price: '전체',
                  onPriceChanged: (_) {},
                  favoritesOnly: false,
                  onFavoritesChanged: () {},
                  resultLabel: '120개의 템플릿',
                  sort: '추천순',
                  onSortChanged: (_) {},
                  filtersActive: true,
                  onReset: () {},
                ),
              ),
              dark: dark,
              textScale: width <= 390 ? 2 : 1,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width dark=$dark',
          );
          expect(
            find.byKey(const ValueKey('web-catalog-search')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('web-catalog-reset')),
            findsOneWidget,
          );
        }
      }
    },
  );

  testWidgets(
    'visible catalog controls keep query, filter, favorite and reset actions',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String category = '전체', price = '전체', sort = '추천순', query = '';
      bool favorite = false;
      var resets = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: WebCatalogToolbar(
                controller: controller,
                searchHint: '디자인 검색',
                onSearchChanged: (value) => setState(() => query = value),
                categories: const ['전체', '여행'],
                category: category,
                onCategoryChanged: (value) => setState(() => category = value),
                price: price,
                onPriceChanged: (value) => setState(() => price = value),
                favoritesOnly: favorite,
                onFavoritesChanged: () => setState(() => favorite = !favorite),
                resultLabel: '12개의 디자인',
                sort: sort,
                onSortChanged: (value) => setState(() => sort = value),
                filtersActive: true,
                onReset: () => setState(() {
                  controller.clear();
                  query = '';
                  category = '전체';
                  price = '전체';
                  favorite = false;
                  sort = '추천순';
                  resets++;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '제주');
      await tester.pump();
      expect(query, '제주');
      await tester.tap(find.text('여행'));
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(category, '여행');
      expect(favorite, isTrue);
      await tester.tap(find.byKey(const ValueKey('web-catalog-price-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보유').last);
      await tester.pumpAndSettle();
      expect(price, '보유');
      await tester.tap(find.byKey(const ValueKey('web-catalog-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이름순').last);
      await tester.pumpAndSettle();
      expect(sort, '이름순');
      await tester.tap(find.byKey(const ValueKey('web-catalog-reset')));
      await tester.pumpAndSettle();
      expect(
        [controller.text, query, category, price, sort],
        ['', '', '전체', '전체', '추천순'],
      );
      expect(favorite, isFalse);
      expect(resets, 1);
    },
  );

  testWidgets(
    'catalog loading footer wraps at double text size without clipping',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final width in [390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 568);
        for (final loading in [true, false]) {
          await tester.pumpWidget(
            _app(
              SingleChildScrollView(
                child: WebCatalogFooter(
                  loading: loading,
                  visible: 12,
                  total: 120,
                  onMore: () {},
                ),
              ),
              textScale: 2,
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width loading=$loading',
          );
        }
      }
    },
  );

  testWidgets(
    'detail artwork and action stay accessible in wide, narrow and short windows',
    (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      for (final size in [
        const Size(1440, 1000),
        const Size(1024, 800),
        const Size(768, 800),
        const Size(390, 760),
        const Size(320, 568),
        const Size(1440, 320),
      ]) {
        tester.view.physicalSize = size;
        var taps = 0;
        await tester.pumpWidget(
          _app(
            WebDesignDetailLayout(
              preview: const WebSurface(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: .75,
                    child: ColoredBox(color: Colors.teal),
                  ),
                ),
              ),
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('표지와 내지를 확인해 주세요'),
                  FilledButton(
                    key: const ValueKey('use-design'),
                    onPressed: () => taps++,
                    child: const Text('이 디자인으로 시작'),
                  ),
                ],
              ),
              information: Column(
                children: List.generate(
                  30,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('디자인 구성과 적용 범위 $index'),
                  ),
                ),
              ),
            ),
            dark: size.width == 320,
            textScale: size.width <= 390 ? 2 : 1,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              size.width >= 972 && size.height >= 512
                  ? 'web-design-detail-columns'
                  : 'web-design-detail-stacked',
            ),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('use-design')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('use-design')));
        await tester.pump();
        expect(taps, 1, reason: '$size');
        expect(tester.takeException(), isNull, reason: '$size');
      }
    },
  );

  testWidgets('stacked detail keeps its action clickable after long content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    await tester.pumpWidget(
      _app(
        WebDesignDetailLayout(
          preview: const ColoredBox(color: Colors.teal),
          action: const Text('데스크톱 전체 동작'),
          stackedAction: const Text('앨범 모양과 구성 안내'),
          information: Column(
            children: List.generate(
              40,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('스크롤하는 상세 정보 $index'),
              ),
            ),
          ),
          bottomAction: FilledButton(
            key: const ValueKey('fixed-use-design'),
            onPressed: () => starts++,
            child: const Text('이 디자인으로 시작'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final use = find.byKey(const ValueKey('fixed-use-design'));
    expect(use.hitTestable(), findsOneWidget);
    expect(find.text('데스크톱 전체 동작'), findsNothing);
    final originalCenter = tester.getCenter(use);
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('web-design-detail-stacked')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('스크롤하는 상세 정보 39'),
      400,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(use), originalCenter);
    expect(use.hitTestable(), findsOneWidget);
    await tester.tap(use);
    await tester.pump();
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked preview uses its actual available content width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? availableWidth;
    await tester.pumpWidget(
      _app(
        WebDesignDetailLayout(
          stackedPreviewHeightForWidth: (width) {
            availableWidth = width;
            return width / 2 + 88;
          },
          preview: const ColoredBox(color: Colors.teal),
          action: const Text('이용 안내'),
          information: const Text('상세 정보'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(availableWidth, 358);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('web-design-detail-preview')))
          .height,
      267,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop details retain their existing action and columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        WebDesignDetailLayout(
          stackedPreviewHeightForWidth: (_) => throw StateError(
            'Desktop artwork must not use the stacked preview height',
          ),
          preview: const ColoredBox(color: Colors.teal),
          action: const Text('기존 데스크톱 이용 동작'),
          stackedAction: const Text('좁은 화면 구성 안내'),
          bottomAction: const Text('고정 하단 이용 동작'),
          information: const Text('상세 정보'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('web-design-detail-columns')),
      findsOneWidget,
    );
    expect(find.text('기존 데스크톱 이용 동작'), findsOneWidget);
    expect(find.text('좁은 화면 구성 안내'), findsNothing);
    expect(find.text('고정 하단 이용 동작'), findsNothing);
    expect(
      find.byKey(const ValueKey('web-design-detail-bottom-action')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(1440, 320)]) {
    testWidgets('stacked footer is bounded and keyboard aware at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var starts = 0;
      await tester.pumpWidget(
        _app(
          WebDesignDetailLayout(
            stackedPreviewHeightForWidth: (_) => 250,
            preview: const ColoredBox(color: Colors.teal),
            action: const Text('이용 안내'),
            information: const Text('상세 정보'),
            bottomAction: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < 12; index++)
                  Text('큰 글자에서도 읽을 수 있는 이용 조건 $index'),
                FilledButton(
                  key: const ValueKey('large-fixed-use-design'),
                  onPressed: () => starts++,
                  child: const Text('이 디자인으로 시작'),
                ),
              ],
            ),
          ),
          textScale: 2,
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      final footer = find.byKey(
        const ValueKey('web-design-detail-bottom-action'),
      );
      final content = find.byKey(const ValueKey('web-design-detail-stacked'));
      // The host reserves 16px on every side. The footer cap follows those
      // remaining bounds, including when the wide desktop window is short.
      expect(
        tester.getSize(footer).height,
        lessThanOrEqualTo((size.height - 32) * .4),
      );
      expect(
        tester.getSize(content).height,
        greaterThanOrEqualTo((size.height - 32) * .6),
      );
      final use = find.byKey(const ValueKey('large-fixed-use-design'));
      await tester.ensureVisible(use);
      await tester.pumpAndSettle();
      expect(use.hitTestable(), findsOneWidget);
      await tester.tap(use);
      await tester.pump();
      expect(starts, 1);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pumpAndSettle();
      expect(footer, findsNothing);
      expect(content, findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(footer, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

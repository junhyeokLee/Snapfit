import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/catalog_active_filters.dart';
import 'package:snap_fit/shared/widgets/catalog_filter_bar.dart';

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget child, {double scale = 1, bool dark = false}) =>
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );

void main() {
  for (final (width, scale, dark) in [
    (390.0, 1.0, false),
    (320.0, 2.5, true),
    (800.0, 1.0, true),
    (800.0, 2.5, false),
  ]) {
    testWidgets(
      'filter controls remain accessible at $width / $scale / $dark',
      (tester) async {
        _viewport(tester, width);
        final semantics = tester.ensureSemantics();
        try {
          var price = '전체';
          var sort = '추천순';
          var favorite = false;
          var priceChanges = 0;
          var sortChanges = 0;
          await tester.pumpWidget(
            _host(
              StatefulBuilder(
                builder: (context, setState) => CatalogFilterBar(
                  price: price,
                  onPriceChanged: (value) => setState(() {
                    price = value;
                    priceChanges++;
                  }),
                  favoritesOnly: favorite,
                  onFavoritesChanged: () =>
                      setState(() => favorite = !favorite),
                  resultLabel: '24개의 디자인',
                  sort: sort,
                  onSortChanged: (value) => setState(() {
                    sort = value;
                    sortChanges++;
                  }),
                ),
              ),
              scale: scale,
              dark: dark,
            ),
          );
          expect(find.bySemanticsLabel('가격 필터'), findsOneWidget);
          expect(find.bySemanticsLabel('정렬 기준'), findsOneWidget);
          final menu = find.byKey(const ValueKey('catalog-price-filter'));
          if (menu.evaluate().isNotEmpty) {
            expect(find.text('가격 · 전체').hitTestable(), findsOneWidget);
            expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
            await tester.tap(menu);
            await tester.pumpAndSettle();
            await tester.tap(find.text('유료').last);
          } else {
            final segment = find.byType(SegmentedButton<String>);
            expect(tester.getSize(segment).height, greaterThanOrEqualTo(48));
            expect(find.byTooltip('가격: 유료'), findsOneWidget);
            await tester.tap(
              find.descendant(of: segment, matching: find.text('유료')),
            );
          }
          await tester.pumpAndSettle();
          expect(price, '유료');
          expect(priceChanges, 1);
          final sorting = find.byKey(const ValueKey('catalog-sort'));
          expect(tester.getSize(sorting).height, greaterThanOrEqualTo(48));
          await tester.tap(sorting);
          await tester.pumpAndSettle();
          await tester.tap(find.text('이름순').last);
          await tester.pumpAndSettle();
          expect(sort, '이름순');
          expect(sortChanges, 1);
          // Re-selecting the same option must not trigger catalog work again.
          await tester.tap(sorting);
          await tester.pumpAndSettle();
          await tester.tap(find.text('이름순').last);
          await tester.pumpAndSettle();
          expect(sortChanges, 1);
          final bookmark = find.byTooltip('즐겨찾기만 보기');
          final hitArea = tester.getSize(bookmark);
          expect(hitArea.width, greaterThanOrEqualTo(48));
          expect(hitArea.height, greaterThanOrEqualTo(48));
          await tester.tap(bookmark);
          await tester.pumpAndSettle();
          expect(favorite, isTrue);
          expect(find.text('24개의 디자인'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final scale in [1.0, 2.5]) {
    testWidgets(
      'applied filters wrap and retain removal / reset at ${scale}x',
      (tester) async {
        _viewport(tester, 390);
        final semantics = tester.ensureSemantics();
        try {
          var price = true;
          var favorite = true;
          var resets = 0;
          await tester.pumpWidget(
            _host(
              StatefulBuilder(
                builder: (context, setState) => CatalogActiveFilters(
                  filters: [
                    if (price)
                      CatalogActiveFilter(
                        id: 'price',
                        label: '가격 · 유료',
                        onRemove: () => setState(() => price = false),
                      ),
                    if (favorite)
                      CatalogActiveFilter(
                        id: 'favorites',
                        label: '즐겨찾기만',
                        onRemove: () => setState(() => favorite = false),
                      ),
                  ],
                  onReset: () => setState(() {
                    price = favorite = false;
                    resets++;
                  }),
                ),
              ),
              scale: scale,
              dark: scale > 1,
            ),
          );
          expect(find.bySemanticsLabel('적용된 필터'), findsOneWidget);
          expect(find.textContaining('선택한 조건'), findsNothing);
          final reset = find.byKey(const ValueKey('catalog-reset-filters'));
          expect(tester.getSize(reset).height, greaterThanOrEqualTo(48));
          await tester.tap(find.byTooltip('가격 · 유료 조건 해제'));
          await tester.pumpAndSettle();
          expect(price, isFalse);
          expect(favorite, isTrue);
          expect(find.byType(InputChip), findsOneWidget);
          if (scale == 1) {
            expect(
              tester.getRect(reset).center.dy,
              tester.getRect(find.byType(InputChip).first).center.dy,
              reason: 'Reset shares a row with conditions when there is room',
            );
          }
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(resets, 1);
          expect(find.byType(InputChip), findsNothing);
          expect(reset, findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('narrow owned-price menu preserves disabled and owned states', (
    tester,
  ) async {
    _viewport(tester, 320);
    var changes = 0;
    await tester.pumpWidget(
      _host(
        CatalogFilterBar(
          price: '보유',
          showOwned: true,
          enabled: false,
          onPriceChanged: (_) => changes++,
          favoritesOnly: false,
          onFavoritesChanged: () {},
          trailing: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ),
        scale: 2.5,
      ),
    );
    final menu = find.byKey(const ValueKey('catalog-price-filter'));
    expect(tester.widget<DropdownButton<String>>(menu).value, '보유');
    expect(tester.widget<DropdownButton<String>>(menu).onChanged, isNull);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.text('가격 · 보유').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

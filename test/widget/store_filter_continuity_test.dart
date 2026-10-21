import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

class _Fixture {
  final built = <int>{};
  int catalogLoads = 0;
  late final templates = List.generate(
    36,
    (index) => PremiumTemplate(
      id: 1000 + index,
      title: 'Design $index',
      category: index < 18 ? '여행' : '일상',
      isPremium: index % 3 == 2,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      documentBuilder: () {
        built.add(index);
        return jsonEncode({
          'designWidth': 500,
          'designHeight': 500,
          'pages': [
            {
              'layers': [
                {
                  'id': 'title-$index',
                  'type': 'text',
                  'x': .08,
                  'y': .1,
                  'w': .84,
                  'h': .2,
                  'text': 'PHOTO / $index',
                  'style': {
                    'fontFamily': 'NotoSans',
                    'fontSize': 20,
                    'color': '#20352D',
                  },
                },
              ],
            },
          ],
        });
      },
    ),
  );

  Widget host({
    double textScale = 1,
    bool searchMode = false,
    bool editorial = false,
  }) => ProviderScope(
    overrides: [
      templateListProvider.overrideWith((_) async {
        catalogLoads++;
        return templates;
      }),
      templateRepositoryProvider.overrideWith(
        (_) => throw StateError('Use the supplied catalog'),
      ),
      storeCurationsProvider.overrideWith(
        (_) async => {
          'templates': StoreCuration(
            placement: 'templates',
            title: '사진을 모은 컬렉션',
            subtitle: '주제별 앨범',
            productKeys: templates.take(4).map(pointShopTemplateKey).toList(),
          ),
        },
      ),
      pointShopCatalogProvider.overrideWith(
        (_) async => [
          for (final item in templates)
            PointShopProduct(
              productKey: pointShopTemplateKey(item),
              kind: 'template',
              assetId: '${item.id}',
              title: item.title,
              pointPrice: item.isPremium ? 1800 : 0,
              isActive: true,
            ),
        ],
      ),
      publicPointShopCatalogProvider.overrideWith((_) async => []),
      ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      pointShopRepositoryProvider.overrideWith(
        (_) => throw StateError('No repository calls while browsing'),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: SnapFitWebTheme.from(ThemeData(useMaterial3: true)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: StoreScreen(
            embedded: true,
            searchMode: searchMode,
            editorial: editorial,
          ),
        ),
      ),
    ),
  );
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _scrollable() => find
    .descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    )
    .first;
ScrollController _controller(WidgetTester tester) => tester
    .widget<CustomScrollView>(find.byType(CustomScrollView).first)
    .controller!;
int _count(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
            as SliverChildBuilderDelegate)
        .childCount!;
Finder _topic(String value) => kIsWeb
    ? find.widgetWithText(ChoiceChip, value)
    : find.byKey(ValueKey('store-topic-$value'));
Finder _filters() => find.byKey(
  ValueKey(kIsWeb ? 'web-catalog-toolbar' : 'store-topic-filters'),
);

Future<void> _reachFilters(
  WidgetTester tester, {
  bool fromResults = false,
}) async {
  await tester.scrollUntilVisible(
    _topic('여행'),
    fromResults ? -240 : 240,
    scrollable: _scrollable(),
  );
  await tester.ensureVisible(_topic('여행'));
  await tester.pumpAndSettle();
}

Future<void> _tapTopic(WidgetTester tester, String value) async {
  // Move along the horizontal subject strip if necessary. Once revealed, the
  // filter must never need another vertical trip past the collection hero.
  await tester.ensureVisible(_topic(value));
  await tester.pumpAndSettle();
  expect(_topic(value).hitTestable(), findsOneWidget);
  await tester.tap(_topic(value));
  await tester.pumpAndSettle();
  expect(
    _topic(value).hitTestable(),
    findsOneWidget,
    reason: 'The chosen subject stays in the viewport',
  );
}

Future<void> _advanced(WidgetTester tester) async {
  if (!kIsWeb ||
      find
          .byKey(
            const ValueKey('web-catalog-price-filter'),
            skipOffstage: false,
          )
          .evaluate()
          .isNotEmpty)
    return;
  await _tapVisible(tester, find.text('필터·정렬', skipOffstage: false));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
}

Future<void> _price(WidgetTester tester, String value) async {
  if (kIsWeb) {
    await _advanced(tester);
    final field = find.byKey(
      const ValueKey('web-catalog-price-filter'),
      skipOffstage: false,
    );
    await _tapVisible(tester, field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value == '유료' ? '포인트' : value).last);
  } else {
    final segment = find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text(value),
    );
    await _tapVisible(tester, segment);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'subject changes keep controls visible when the collection appears and disappears at ${scale}x',
      (tester) async {
        _viewport(tester, const Size(390, 844));
        final fixture = _Fixture();
        await tester.pumpWidget(fixture.host(textScale: scale));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('store-curation-sliver')),
          findsOneWidget,
        );
        expect(
          fixture.built.length,
          lessThan(12),
          reason: 'The catalog remains lazy before browsing its grid',
        );
        await _reachFilters(tester);
        await _tapTopic(tester, '여행');
        expect(
          find.byKey(const ValueKey('store-curation-sliver')),
          findsNothing,
        );
        expect(_count(tester), 12);
        await _tapTopic(tester, '일상');
        expect(_count(tester), 12);
        await _tapTopic(tester, '전체');
        expect(
          find.byKey(
            const ValueKey('store-curation-sliver'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        final heroBox = find.byKey(
          const ValueKey('store-collection-spotlight'),
          skipOffstage: false,
        );
        expect(
          tester.getRect(heroBox).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byType(CustomScrollView).first).top + 1,
          ),
          reason:
              'The hero remains above the visible controls instead of covering them',
        );
        expect(
          _controller(tester).offset,
          greaterThan(200),
          reason: 'Return to all subjects reveals the controls below the hero',
        );
        expect(_filters().hitTestable(), findsOneWidget);
        expect(
          _count(tester),
          12,
          reason: 'Programmatic reveal cannot trigger another page',
        );
        await _tapTopic(tester, '여행');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'comparison selection survives subject, price, favorite and sort changes',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final fixture = _Fixture();
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.template(1002),
      );
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.template(1020),
      );
      await tester.pumpWidget(fixture.host());
      await tester.pumpAndSettle();
      final compare = find.byKey(const ValueKey('compare-template-1000'));
      await tester.scrollUntilVisible(compare, 240, scrollable: _scrollable());
      await tester.ensureVisible(compare);
      await tester.pumpAndSettle();
      expect(compare.hitTestable(), findsOneWidget);
      await tester.tap(compare);
      await tester.pumpAndSettle();
      final selected = find.byKey(const ValueKey('comparison-selected-1000'));
      expect(selected, findsOneWidget);
      await _reachFilters(tester, fromResults: true);
      await _tapTopic(tester, '일상');
      await _price(tester, '유료');
      expect(_count(tester), 6);
      expect(selected, findsOneWidget);
      final favorite = kIsWeb
          ? find.widgetWithText(FilterChip, '즐겨찾기')
          : find.byTooltip('즐겨찾기만 보기');
      await _tapVisible(tester, favorite);
      await tester.pumpAndSettle();
      expect(_count(tester), 1);
      expect(selected, findsOneWidget);
      final sort = kIsWeb
          ? find.byKey(const ValueKey('web-catalog-sort'))
          : find.byType(DropdownButton<String>);
      await _tapVisible(tester, sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text('이름순').last);
      await tester.pumpAndSettle();
      expect(_topic('일상').hitTestable(), findsOneWidget);
      expect(_count(tester), 1);
      expect(selected, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'paging stays in batches of twelve and changing only the caret does not reset it',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(searchMode: true));
      await tester.pumpAndSettle();
      expect(_count(tester), 12);
      final search = kIsWeb
          ? find.byKey(const ValueKey('web-catalog-search'))
          : find.byType(TextField);
      await tester.enterText(search, ' ');
      await tester.pumpAndSettle();
      final searchController = tester.widget<TextField>(search).controller!;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(_count(tester), 12);
      final controller = _controller(tester);
      // Reach the next page as a person does. Jumping to a sliver's estimated
      // far end can cross a second loading threshold while it corrects itself.
      for (var step = 0; step < 50 && _count(tester) == 12; step++) {
        await tester.drag(_scrollable(), const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      expect(_count(tester), 24);
      final before = controller.offset;
      searchController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();
      expect(_count(tester), 24);
      expect(controller.offset, before);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsOneWidget);
      await tester.enterText(search, 'Design 2');
      await tester.pumpAndSettle();
      expect(_count(tester), 11);
      expect(search.hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(_count(tester), 12);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('explicit refresh returns to the collection top', (tester) async {
    _viewport(tester, const Size(390, 844));
    final fixture = _Fixture();
    await tester.pumpWidget(fixture.host());
    await tester.pumpAndSettle();
    await _reachFilters(tester);
    expect(_controller(tester).offset, greaterThan(100));
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await refresh;
    await tester.pumpAndSettle();
    expect(_controller(tester).offset, 0);
    expect(fixture.catalogLoads, 2);
    expect(find.byKey(const ValueKey('store-curation-sliver')), findsOneWidget);
    expect(_count(tester), 12);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'subject browsing keeps its editorial list while omitting the hero',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(editorial: true));
      await tester.pumpAndSettle();
      expect(
        find.byType(TemplateEditorialList, skipOffstage: false),
        findsOneWidget,
      );
      await _reachFilters(tester);
      await _tapTopic(tester, '여행');
      expect(find.byKey(const ValueKey('store-curation-sliver')), findsNothing);
      expect(
        find.byType(TemplateEditorialList, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'narrow web reset restores discovery without hiding its filters behind the hero',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(textScale: 2));
      await tester.pumpAndSettle();
      await _reachFilters(tester);
      await _price(tester, '유료');
      final reset = find.byKey(const ValueKey('web-catalog-reset'));
      await _tapVisible(tester, reset);
      await tester.pumpAndSettle();
      expect(_topic('전체').hitTestable(), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('store-curation-sliver'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(_controller(tester).offset, greaterThan(200));
      expect(_count(tester), 12);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !kIsWeb,
  );
}

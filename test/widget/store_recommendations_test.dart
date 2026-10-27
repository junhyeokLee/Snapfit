import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/entities/template_summary_page.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_topic_shelf.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../../tool/template_studio/export_price_application.dart';

class _Repository implements TemplateRepository {
  final categories = <String?>[];
  final pending = <Completer<TemplateSummaryPage>>[];
  bool deferResponses = false;
  int fullLoads = 0;

  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
    String? category,
    String? query,
    bool? isPaid,
  }) async {
    categories.add(category);
    if (deferResponses) {
      final response = Completer<TemplateSummaryPage>();
      pending.add(response);
      return response.future;
    }
    return TemplateSummaryPage(
      content: const [],
      page: page,
      size: size,
      totalPages: 100,
      totalElements: 2000,
      hasNext: true,
    );
  }

  @override
  Future<List<PremiumTemplate>> getTemplates() {
    fullLoads++;
    throw StateError('Browsing must not request the full catalog');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository operation: $invocation');
}

class _Fixture {
  final repository = _Repository();
  int localCatalogLoads = 0;
  final built = <int>{};
  late final items = [
    for (final (topicIndex, topic) in storeTemplateTopicOrder.indexed)
      for (var n = 0; n < 4; n++) _item(topicIndex * 4 + n, topic),
    // These must never be advertised as recommendations, even with strong
    // editorial/usage signals. Their product rows are disabled, unpriced or absent.
    for (var n = 40; n < 43; n++) _item(n, '일상'),
  ];
  PremiumTemplate _item(int n, String topic) => PremiumTemplate(
    id: 10000 + n,
    title: 'Design ${n.toString().padLeft(2, '0')}',
    category: topic,
    coverImageUrl: '',
    previewImages: const [],
    pageCount: 24,
    userCount: n >= 40 ? 10000 : 0,
    isPremium: n.isOdd || n >= 40,
    documentBuilder: () {
      built.add(n);
      return jsonEncode({
        'designWidth': 500,
        'designHeight': 500,
        'pages': [
          {'layers': <Object>[]},
        ],
      });
    },
  );

  Widget host({
    bool realFeed = false,
    bool dark = false,
    double textScale = 1,
    bool editorial = false,
    bool hub = false,
  }) => ProviderScope(
    overrides: [
      if (!realFeed)
        mockTemplateList(() {
          localCatalogLoads++;
          return items;
        }),
      templateRepositoryProvider.overrideWithValue(repository),
      storeCurationsProvider.overrideWith(
        (_) async => {
          'templates': realFeed
              ? StoreCuration.templates
              : StoreCuration(
                  placement: 'templates',
                  title: '오래 간직하고 싶은 장면들',
                  subtitle: '사진이 한 권의 이야기가 되는 디자인',
                  productKeys: [
                    ...items.skip(40).map(pointShopTemplateKey),
                    ...items.take(4).map(pointShopTemplateKey),
                  ],
                ),
        },
      ),
      pointShopCatalogProvider.overrideWith(
        (_) async => realFeed
            ? pointShopPriceApplicationRows()
                  .map(PointShopProduct.fromJson)
                  .toList()
            : [
                for (final t in items.take(42))
                  PointShopProduct(
                    productKey: pointShopTemplateKey(t),
                    kind: 'template',
                    assetId: '${t.id}',
                    title: t.title,
                    pointPrice: t.id == 10041
                        ? null
                        : t.isPremium
                        ? 1800
                        : 0,
                    isActive: t.id != 10040,
                  ),
              ],
      ),
      publicPointShopCatalogProvider.overrideWith((_) async => []),
      ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      pointShopRepositoryProvider.overrideWith(
        (_) => throw StateError('No commerce requests while browsing'),
      ),
    ],
    child: MaterialApp(
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: hub
          ? const StoreHubScreen()
          : Scaffold(body: StoreScreen(embedded: true, editorial: editorial)),
    ),
  );
}

void _viewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ScrollController _scroll(WidgetTester tester) => tester
    .widget<CustomScrollView>(find.byType(CustomScrollView).first)
    .controller!;

int _count(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
            as SliverChildBuilderDelegate)
        .childCount!;

Future<void> _topic(WidgetTester tester, String topic) async {
  final chip = find.byKey(ValueKey('store-topic-$topic'));
  if (chip.evaluate().isEmpty) {
    _scroll(tester).jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
  expect(chip.hitTestable(), findsOneWidget);
}

Future<void> _price(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byType(SegmentedButton<String>),
    matching: find.text(label),
  );
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'all and recommendations precede broad-use topics; large hero remains',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host());
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('curation-pager'))).height,
        greaterThan(350),
      );
      expect(
        tester.widget<StoreTopicShelf>(find.byType(StoreTopicShelf)).categories,
        ['전체', '추천', ...storeTemplateTopicOrder],
      );
      await _topic(tester, '추천');
      expect(find.text('지금 둘러보기 좋은 디자인'), findsOneWidget);
      expect(find.text('24개의 디자인'), findsOneWidget);
      expect(_count(tester), 12);
      expect(find.byKey(const ValueKey('curation-pager')), findsNothing);
      expect(
        fixture.built.length,
        lessThan(24),
        reason: 'Recommendation selection must not eagerly author 24 documents',
      );
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_count(tester), 24);
      _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('전체 템플릿 보기'), findsOneWidget);
      expect(find.text('Design 40'), findsNothing);
      expect(find.text('Design 41'), findsNothing);
      expect(find.text('Design 42'), findsNothing);
      expect(fixture.built.intersection({40, 41, 42}), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'recommendations preserve price/favorites filters at large text, dark=$dark',
      (tester) async {
        _viewport(tester);
        final fixture = _Fixture();
        await CatalogFavorites.instance.toggle(
          CatalogFavoriteKeys.template(10003),
        );
        await CatalogFavorites.instance.toggle(
          CatalogFavoriteKeys.template(10008),
        );
        await tester.pumpWidget(fixture.host(dark: dark, textScale: 2));
        await tester.pumpAndSettle();
        await _topic(tester, '추천');
        await _price(tester, '유료');
        expect(find.text('20개의 디자인'), findsOneWidget);
        expect(_count(tester), 12);
        final favorites = find.byTooltip('즐겨찾기만 보기');
        await tester.ensureVisible(favorites);
        await tester.pumpAndSettle();
        await tester.tap(favorites);
        await tester.pumpAndSettle();
        expect(find.text('1개의 디자인'), findsOneWidget);
        expect(_count(tester), 1);
        await _topic(tester, '전체');
        expect(_count(tester), 1);
        await _topic(tester, '추천');
        expect(_count(tester), 1);
        await _price(tester, '무료');
        expect(find.text('1개의 디자인'), findsOneWidget);
        expect(_count(tester), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'real feed shares all/recommended requests and stops paging at 24',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(realFeed: true));
      await tester.pumpAndSettle();
      expect(fixture.repository.categories, hasLength(1));
      await _topic(tester, '추천');
      expect(_count(tester), 12);
      for (var n = 0; n < 4; n++) {
        _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(_count(tester), 24);
      expect(fixture.repository.categories, hasLength(1));
      await _topic(tester, '전체');
      await _topic(tester, '추천');
      expect(fixture.repository.categories, hasLength(1));
      await _topic(tester, '여행');
      expect(fixture.repository.categories, hasLength(2));
      expect(fixture.repository.categories.last, '여행');
      await _topic(tester, '추천');
      expect(fixture.repository.categories, hasLength(3));
      expect(fixture.repository.categories, isNot(contains('추천')));
      expect(fixture.repository.fullLoads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late category and initial responses cannot replace the latest recommended scope',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      fixture.repository.deferResponses = true;
      await tester.pumpWidget(fixture.host(realFeed: true));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(StoreScreen)),
      );
      await _topic(tester, '여행');
      await _topic(tester, '일상');
      await _topic(tester, '추천');
      expect(fixture.repository.pending, hasLength(4));

      void complete(int request, int id, String title) {
        fixture.repository.pending[request].complete(
          TemplateSummaryPage(
            content: [
              PremiumTemplate(
                id: id,
                title: title,
                category: '일상',
                coverImageUrl: '',
                previewImages: const [],
                pageCount: 24,
                userCount: 500,
              ),
            ],
            page: 0,
            size: 20,
            totalPages: 1,
            totalElements: 1,
            hasNext: false,
          ),
        );
      }

      complete(3, 90003, 'Current recommendation');
      await tester.pumpAndSettle();
      for (final oldRequest in [2, 1, 0]) {
        complete(oldRequest, 90000 + oldRequest, 'Obsolete $oldRequest');
        await tester.pumpAndSettle();
      }
      final feed = scope.read(storeTemplateFeedProvider);
      expect(feed.filterCategory, isEmpty);
      expect(feed.isInitialLoading, isFalse);
      expect(feed.items.any((t) => t.id == 90003), isTrue);
      expect(feed.items.any((t) => t.title.startsWith('Obsolete')), isFalse);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('store-topic-추천')))
            .selected,
        isTrue,
      );
      expect(fixture.repository.fullLoads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding and removing actual favorites updates all, recommended and category results',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host());
      await tester.pumpAndSettle();
      await _topic(tester, '추천');
      final favorite = find.byKey(
        ValueKey('favorite-${CatalogFavoriteKeys.template(10000)}'),
      );
      await tester.ensureVisible(favorite);
      await tester.pumpAndSettle();
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(
        CatalogFavorites.instance.contains(CatalogFavoriteKeys.template(10000)),
        isTrue,
      );
      final filter = find.byTooltip('즐겨찾기만 보기');
      if (filter.evaluate().isEmpty) {
        _scroll(tester).jumpTo(0);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(filter);
      await tester.pumpAndSettle();
      await tester.tap(filter);
      await tester.pumpAndSettle();
      for (final topic in ['일상', '전체', '추천']) {
        await _topic(tester, topic);
        expect(find.text('1개의 디자인'), findsOneWidget);
        expect(_count(tester), 1);
      }
      await tester.ensureVisible(favorite);
      await tester.pumpAndSettle();
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 디자인이 없어요'), findsOneWidget);
      expect(find.text('0개의 디자인'), findsOneWidget);
      expect(find.byType(TemplateCatalogTile), findsNothing);
      expect(
        CatalogFavorites.instance.contains(CatalogFavoriteKeys.template(10000)),
        isFalse,
      );
      await _topic(tester, '전체');
      expect(find.text('0개의 디자인'), findsOneWidget);
      expect(find.byType(TemplateCatalogTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final editorial in [false, true]) {
    testWidgets(
      'recommended footer returns to usable all controls, editorial=$editorial',
      (tester) async {
        _viewport(tester);
        final fixture = _Fixture();
        await tester.pumpWidget(fixture.host(editorial: editorial));
        await tester.pumpAndSettle();
        await _topic(tester, '추천');
        for (var n = 0; n < 2; n++) {
          _scroll(tester).jumpTo(_scroll(tester).position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        final all = find.text('전체 템플릿 보기');
        await tester.ensureVisible(all);
        await tester.pumpAndSettle();
        await tester.tap(all);
        await tester.pumpAndSettle();
        final allChip = find.byKey(const ValueKey('store-topic-전체'));
        expect(allChip.hitTestable(), findsOneWidget);
        final shelfRect = tester.getRect(
          find.byKey(const ValueKey('store-topic-filters')),
        );
        final chipRect = tester.getRect(allChip);
        expect(chipRect.left, greaterThanOrEqualTo(shelfRect.left - .5));
        expect(chipRect.right, lessThanOrEqualTo(shelfRect.right + .5));
        expect(find.text('모든 템플릿'), findsOneWidget);
        await _price(tester, '무료');
        expect(find.text('20개의 디자인'), findsOneWidget);
        expect(
          tester
              .widgetList<TemplateCatalogTile>(find.byType(TemplateCatalogTile))
              .every((tile) => !tile.template.isPremium),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'search opened after a category selection searches the full catalog',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(hub: true));
      await tester.pumpAndSettle();
      await _topic(tester, '여행');
      expect(find.text('4개의 디자인'), findsOneWidget);
      final browseContainer = ProviderScope.containerOf(
        tester.element(find.byType(StoreScreen)),
      );
      final browseNotifier = browseContainer.read(
        storeTemplateFeedProvider.notifier,
      );
      final browseItems = browseContainer.read(storeTemplateFeedProvider).items;
      // Model already queued button callbacks without tapping through the
      // first route's newly inserted modal barrier.
      final openSearch = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '스토어 검색',
            ),
          )
          .onPressed!;
      openSearch();
      openSearch();
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen, skipOffstage: false), findsNWidgets(2));
      final searchContainer = ProviderScope.containerOf(
        tester.element(find.byType(StoreScreen)),
      );
      final searchNotifier = searchContainer.read(
        storeTemplateFeedProvider.notifier,
      );
      expect(searchNotifier, isNot(same(browseNotifier)));
      expect(
        searchContainer.read(storeTemplateFeedProvider).filterCategory,
        isEmpty,
      );
      expect(find.text('모든 템플릿'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Design 00');
      await tester.pumpAndSettle();
      // Design 00 belongs to daily life, outside the previous travel scope.
      // The new search screen labels its scope as all templates.
      expect(find.text('1개의 디자인'), findsOneWidget);
      expect(
        browseContainer.read(storeTemplateFeedProvider).filterCategory,
        '여행',
      );
      expect(
        browseContainer.read(storeTemplateFeedProvider).items,
        same(browseItems),
      );
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('4개의 디자인'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('store-topic-여행')))
            .selected,
        isTrue,
      );
      // Each visit starts a fresh search session, sharing the existing local
      // catalog rather than reloading data or leaking the previous query.
      for (var visit = 0; visit < 3; visit++) {
        await tester.tap(find.byTooltip('스토어 검색'));
        await tester.pumpAndSettle();
        final reopened = ProviderScope.containerOf(
          tester.element(find.byType(StoreScreen)),
        );
        expect(
          reopened.read(storeTemplateFeedProvider.notifier),
          isNot(same(searchNotifier)),
        );
        expect(find.text('모든 템플릿'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.enterText(find.byType(TextField), 'Design 00');
        await tester.pumpAndSettle();
        expect(find.text('1개의 디자인'), findsOneWidget);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        expect(
          browseContainer.read(storeTemplateFeedProvider).items,
          same(browseItems),
        );
        expect(find.text('4개의 디자인'), findsOneWidget);
      }
      expect(fixture.localCatalogLoads, 1);
      expect(fixture.repository.fullLoads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fast recommended scroll reversals keep mounted tiles bounded and do not fetch more pages',
    (tester) async {
      _viewport(tester);
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.host(realFeed: true));
      await tester.pumpAndSettle();
      await _topic(tester, '추천');
      for (var n = 0; n < 6; n++) {
        await tester.fling(
          find.byType(CustomScrollView),
          Offset(0, n.isEven ? -1800 : 1800),
          8000,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(TemplateCatalogTile).evaluate().length,
          lessThanOrEqualTo(12),
        );
        expect(_count(tester), lessThanOrEqualTo(storeRecommendationLimit));
        expect(tester.takeException(), isNull);
      }
      expect(fixture.repository.categories, hasLength(1));
      expect(fixture.repository.fullLoads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

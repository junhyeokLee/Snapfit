import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';

import 'ai_album_start_step_test.dart' show wrapCreation;

final _now = DateTime.utc(2026, 11, 11);
final _templates = [
  PremiumTemplate(
    id: 1,
    title: '우리의 시선',
    category: '동아리',
    coverImageUrl: '',
    previewImages: [],
    pageCount: 24,
    userCount: 0,
    isPremium: true,
  ),
  PremiumTemplate(
    id: 2,
    title: '함께한 계절',
    category: '가족·친구',
    coverImageUrl: '',
    previewImages: [],
    pageCount: 24,
    userCount: 0,
    isPremium: false,
  ),
  PremiumTemplate(
    id: 3,
    title: '여행의 기록',
    category: '여행',
    coverImageUrl: '',
    previewImages: [],
    pageCount: 24,
    userCount: 0,
    isPremium: true,
  ),
];
const _products = [
  PointShopProduct(
    productKey: 'template:server-1',
    kind: 'template',
    assetId: 'server-1',
    title: '우리의 시선',
    pointPrice: 0,
    isActive: true,
  ),
  PointShopProduct(
    productKey: 'template:server-2',
    kind: 'template',
    assetId: 'server-2',
    title: '함께한 계절',
    pointPrice: 1800,
    isActive: true,
  ),
  PointShopProduct(
    productKey: 'template:server-3',
    kind: 'template',
    assetId: 'server-3',
    title: '여행의 기록',
    pointPrice: 1200,
    isActive: true,
  ),
];

Future<void> _mount(
  WidgetTester tester, {
  VoidCallback? onManual,
  ValueChanged<PremiumTemplate>? onTemplate,
  Future<List<PointShopProduct>> Function()? loadPrices,
  AsyncValue<Set<String>>? ownedState,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    wrapCreation(
      ProviderScope(
        overrides: [
          if (loadPrices != null)
            pointShopCatalogProvider.overrideWith((ref) => loadPrices()),
          storeDiscoveryProvider.overrideWith(
            (ref) async => {
              'template:server-1': StoreProductDiscovery(
                firstPublishedAt: _now.subtract(const Duration(days: 2)),
                bestRank: 1,
              ),
              'template:server-2': StoreProductDiscovery(
                firstPublishedAt: _now.subtract(const Duration(days: 1)),
                bestRank: 2,
              ),
            },
          ),
          storeDiscoveryClockProvider.overrideWithValue(_now),
          storeCurationsProvider.overrideWith((ref) async => {}),
          if (ownedState != null)
            ownedPointShopKeysProvider.overrideWithValue(ownedState)
          else
            ownedPointShopKeysProvider.overrideWith(
              (ref) async => {'template:server-2'},
            ),
        ],
        child: Builder(
          builder: (context) => Theme(
            data: Theme.of(
              context,
            ).copyWith(splashFactory: NoSplash.splashFactory),
            child: AiAlbumStartStep(
              onManualStart: onManual ?? () {},
              templates: AsyncData(_templates),
              onTemplateSelected: onTemplate,
            ),
          ),
        ),
      ),
      shopProducts: _products,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('creation-open-catalog')));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('account ownership reload never shows previous account purchases', (
    tester,
  ) async {
    // Model Riverpod's dependency reload, including the previous account value.
    // ignore: invalid_use_of_internal_member
    final switching = const AsyncLoading<Set<String>>().copyWithPrevious(
      const AsyncData({'template:server-2'}),
      isRefresh: false,
    );
    expect(switching.hasValue, isTrue);
    expect(switching.asData, isNull);
    await _mount(tester, ownedState: switching);
    await _open(tester);
    await _choose(tester, 'creation-price-유료');
    expect(find.byKey(const ValueKey('creation-template-2')), findsOneWidget);
    expect(find.text('구매 완료'), findsNothing);
  });

  testWidgets(
    'price refresh failure retains the last confirmed classification',
    (tester) async {
      var fail = false;
      await _mount(
        tester,
        loadPrices: () async {
          if (fail) throw StateError('가격 확인 실패');
          return _products;
        },
      );
      await _open(tester);
      await _choose(tester, 'creation-price-무료');
      expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAlbumStartStep)),
      );
      fail = true;
      container.invalidate(pointShopCatalogProvider);
      await tester.pumpAndSettle();
      expect(find.text('가격을 확인하지 못했어요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
    },
  );

  testWidgets('catalogue choices survive a viewport resize across 700 pixels', (
    tester,
  ) async {
    await _mount(tester);
    await _open(tester);
    await _choose(tester, 'creation-price-유료');
    await tester.enterText(find.byKey(const ValueKey('creation-search')), '여행');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('creation-search')))
          .controller!
          .text,
      '여행',
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('creation-category-전체')))
          .properties
          .selected,
      isTrue,
    );
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byKey(const ValueKey('creation-price-유료')),
              matching: find.byType(Semantics),
            ),
          )
          .where((widget) => widget.properties.selected == true),
      hasLength(1),
    );
    // The short landscape viewport initially shows the filter header only.
    final matchingTemplate = find.byKey(const ValueKey('creation-template-3'));
    await tester.scrollUntilVisible(
      matchingTemplate,
      120,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
              as SliverChildBuilderDelegate)
          .childCount,
      1,
    );
    expect(matchingTemplate.hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('creation-template-1')), findsNothing);
    expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'entry gives both routes equal visible actions before catalogue',
    (tester) async {
      var manual = 0;
      await _mount(tester, onManual: () => manual++);
      final direct = find.byKey(const ValueKey('creation-manual-start'));
      final design = find.byKey(const ValueKey('creation-open-catalog'));
      expect(direct, findsOneWidget);
      expect(design, findsOneWidget);
      expect(tester.getSize(direct).height, tester.getSize(design).height);
      expect(tester.getSize(direct).height, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(direct).dy, lessThan(320));
      expect(
        find.byKey(const ValueKey('creation-category-rail')),
        findsNothing,
      );
      await tester.tap(direct);
      expect(manual, 1);
      await _open(tester);
      expect(
        find.byKey(const ValueKey('creation-category-rail')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'catalogue exposes price filters and does not classify paid-owned as free',
    (tester) async {
      await _mount(tester);
      await _open(tester);
      for (final price in ['전체', '무료', '유료']) {
        expect(find.byKey(ValueKey('creation-price-$price')), findsOneWidget);
      }
      await _choose(tester, 'creation-price-무료');
      expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
      await _choose(tester, 'creation-price-유료');
      expect(find.byKey(const ValueKey('creation-template-1')), findsNothing);
      expect(find.byKey(const ValueKey('creation-template-2')), findsOneWidget);
      expect(find.text('구매 완료'), findsOneWidget);
    },
  );

  testWidgets(
    'category changes preserve query and price while replacing the previous category',
    (tester) async {
      await _mount(tester);
      await _open(tester);
      await _choose(tester, 'creation-price-유료');
      await tester.enterText(
        find.byKey(const ValueKey('creation-search')),
        '여행',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await _choose(tester, 'creation-category-인기');
      await _choose(tester, 'creation-category-동아리');
      expect(find.byKey(const ValueKey('creation-template-1')), findsNothing);
      await _choose(tester, 'creation-category-전체');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('creation-search')))
            .controller!
            .text,
        '여행',
      );
      expect(find.byKey(const ValueKey('creation-template-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-1')), findsNothing);
    },
  );

  testWidgets('preview callback does not buy or clear the catalogue state', (
    tester,
  ) async {
    PremiumTemplate? selected;
    await _mount(tester, onTemplate: (value) => selected = value);
    await _open(tester);
    await _choose(tester, 'creation-price-무료');
    await _choose(tester, 'creation-template-1');
    expect(selected?.id, 1);
    expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
    expect(
      find.byKey(const ValueKey('creation-category-rail')),
      findsOneWidget,
    );
  });
}

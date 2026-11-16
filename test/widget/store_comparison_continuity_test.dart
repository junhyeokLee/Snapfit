import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_design_comparison.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../support/catalog_preview_loading.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

final _designs = publishedCreationTemplates.take(4).toList();

Future<GlobalKey<NavigatorState>> _mount(
  WidgetTester tester, {
  Widget screen = const StoreHubScreen(),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final navigator = GlobalKey<NavigatorState>();
  final products = [
    for (final design in _designs)
      PointShopProduct(
        productKey: pointShopTemplateKey(design),
        kind: 'template',
        assetId: '${design.id}',
        title: design.title,
        pointPrice: 0,
        isActive: true,
      ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        mockTemplateList(() => _designs),
        templateRepositoryProvider.overrideWith(
          (_) => throw StateError('Use the supplied public catalog'),
        ),
        pointShopRepositoryProvider.overrideWith(
          (_) => throw StateError('Comparison must not read private data'),
        ),
        pointShopCatalogProvider.overrideWith((_) async => products),
        publicPointShopCatalogProvider.overrideWith((_) async => products),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        storeCurationsProvider.overrideWith(
          (_) async => <String, StoreCuration>{},
        ),
        storeDiscoveryProvider.overrideWith(
          (_) async => <String, StoreProductDiscovery>{},
        ),
        storeDiscoveryClockProvider.overrideWithValue(
          DateTime.utc(2026, 11, 16),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (final design in _designs) {
    await loadCatalogPreview(tester, design);
  }
  await tester.pumpAndSettle();
  return navigator;
}

List<int> _selected(WidgetTester tester) => tester
    .widget<TemplateDesignComparisonTray>(
      find.byType(TemplateDesignComparisonTray),
    )
    .designs
    .map((design) => design.id)
    .toList();

Future<void> _searchFor(WidgetTester tester, PremiumTemplate design) async {
  // 긴 결과를 본 뒤에는 lazy sliver의 검색창을 먼저 다시 마운트한다.
  tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!
      .jumpTo(0);
  await tester.pumpAndSettle();
  final search = find.byType(TextField);
  await tester.ensureVisible(search);
  await tester.pumpAndSettle();
  await tester.enterText(search, design.title);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _compare(WidgetTester tester, PremiumTemplate design) async {
  final button = find.byKey(ValueKey('compare-template-${design.id}'));
  final scroll = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(button, 200, scrollable: scroll);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.byTooltip('스토어 검색'));
  await tester.pumpAndSettle();
  expect(
    tester.widget<StoreScreen>(find.byType(StoreScreen)).searchMode,
    isTrue,
  );
}

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(StoreScreen))).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'BookMyungjo',
    )..addFont(rootBundle.load('assets/fonts/BookkMyungjo_Bold.ttf'))).load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets('header search keeps the same comparison and independent query', (
    tester,
  ) async {
    await _mount(tester);
    final first = _designs[0], second = _designs[1];
    await _searchFor(tester, first);
    await _compare(tester, first);
    final mainQuery = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    final mainScroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final mainOffset = mainScroll.offset;
    expect(_selected(tester), [first.id]);

    await _openSearch(tester);
    expect(_selected(tester), [first.id]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await _searchFor(tester, second);
    await _compare(tester, second);
    expect(_selected(tester), [first.id, second.id]);
    await _back(tester);

    expect(_selected(tester), [first.id, second.id]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller,
      same(mainQuery),
    );
    expect(mainQuery.text, first.title);
    expect(mainScroll.offset, closeTo(mainOffset, .5));
    // 검색을 새로 열어도 비교 후보만 이어지고 이전 검색어는 섞이지 않는다.
    await _openSearch(tester);
    expect(_selected(tester), [first.id, second.id]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await _back(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing and clearing in search updates the main comparison', (
    tester,
  ) async {
    await _mount(tester);
    final first = _designs[0], second = _designs[1];
    await _compare(tester, first);
    await _compare(tester, second);
    await _openSearch(tester);
    expect(_selected(tester), [first.id, second.id]);
    await tester.tap(
      find.byKey(ValueKey('comparison-selected-remove-${first.id}')),
    );
    await tester.pumpAndSettle();
    expect(_selected(tester), [second.id]);
    await _back(tester);
    expect(_selected(tester), [second.id]);

    await _openSearch(tester);
    await tester.tap(find.byKey(const ValueKey('template-comparison-clear')));
    await tester.pumpAndSettle();
    expect(_selected(tester), isEmpty);
    await _back(tester);
    expect(_selected(tester), isEmpty);
    expect(
      find.byKey(const ValueKey('template-comparison-tray')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared comparison preserves the three design limit and toggles',
    (tester) async {
      await _mount(tester);
      await _compare(tester, _designs[0]);
      await _openSearch(tester);
      for (final design in _designs.skip(1).take(2)) {
        await _searchFor(tester, design);
        await _compare(tester, design);
      }
      expect(
        _selected(tester),
        _designs.take(3).map((design) => design.id).toList(),
      );
      // 메인에서 이미 고른 카드를 검색에서 다시 누르면 중복 추가하지 않고 해제한다.
      await _searchFor(tester, _designs[0]);
      await _compare(tester, _designs[0]);
      expect(_selected(tester), [_designs[1].id, _designs[2].id]);
      await _compare(tester, _designs[0]);
      final full = [_designs[1].id, _designs[2].id, _designs[0].id];
      expect(_selected(tester), full);
      await _searchFor(tester, _designs[3]);
      await _compare(tester, _designs[3]);
      expect(_selected(tester), full);
      expect(
        find.text(TemplateDesignComparisonSelection.limitMessage),
        findsOneWidget,
      );
      await _back(tester);
      expect(_selected(tester), full);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('separate hubs and standalone catalogs do not share comparison', (
    tester,
  ) async {
    final navigator = await _mount(tester);
    await _compare(tester, _designs[0]);
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const StoreHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(_selected(tester), isEmpty);
    await _compare(tester, _designs[1]);
    expect(_selected(tester), [_designs[1].id]);
    await _back(tester);
    expect(_selected(tester), [_designs[0].id]);

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const StoreScreen(searchMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_selected(tester), isEmpty);
    await _searchFor(tester, _designs[2]);
    await _compare(tester, _designs[2]);
    expect(_selected(tester), [_designs[2].id]);
    await _back(tester);
    expect(_selected(tester), [_designs[0].id]);

    // 종료된 두 번째 허브의 선택은 다음 허브에 남지 않는다.
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const StoreHubScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(_selected(tester), isEmpty);
    await _back(tester);
    expect(_selected(tester), [_designs[0].id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing a controller detaches listeners without taking ownership',
    (tester) async {
      final first = TemplateDesignComparisonController()..add(_designs[0]);
      final second = TemplateDesignComparisonController()..add(_designs[1]);
      final current = ValueNotifier(first);
      addTearDown(() {
        current.dispose();
        first.dispose();
        second.dispose();
      });
      await _mount(
        tester,
        screen: ValueListenableBuilder<TemplateDesignComparisonController>(
          valueListenable: current,
          builder: (_, controller, __) =>
              StoreScreen(comparisonController: controller),
        ),
      );
      expect(_selected(tester), [_designs[0].id]);
      current.value = second;
      await tester.pumpAndSettle();
      expect(_selected(tester), [_designs[1].id]);
      first.clear();
      second.add(_designs[2]);
      await tester.pumpAndSettle();
      expect(_selected(tester), [_designs[1].id, _designs[2].id]);

      // 화면을 닫아도 외부 소유 controller는 계속 사용할 수 있어야 한다.
      await tester.pumpWidget(const SizedBox.shrink());
      first.add(_designs[0]);
      second.clear();
      await tester.pump();
      expect(first.selection.ids, [_designs[0].id]);
      expect(second.selection.ids, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

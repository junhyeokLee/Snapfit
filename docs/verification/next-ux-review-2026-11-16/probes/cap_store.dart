// 실제 스토어의 메인 → 검색 → 복귀에서 비교 선택이 이어지는지 캡처한다.
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
import 'package:snap_fit/features/store/presentation/widgets/template_design_comparison.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/catalog_preview_loading.dart';
import 'audit_support.dart';

Future<void> _compare(WidgetTester tester, PremiumTemplate template) async {
  final button = find.byKey(ValueKey('compare-template-${template.id}'));
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

List<int> _selected(WidgetTester tester) => tester
    .widget<TemplateDesignComparisonTray>(
      find.byType(TemplateDesignComparisonTray),
    )
    .designs
    .map((template) => template.id)
    .toList();

void main() {
  setUpAll(() async {
    await auditFonts();
    await (FontLoader(
      'BookMyungjo',
    )..addFont(rootBundle.load('assets/fonts/BookkMyungjo_Bold.ttf'))).load();
  });

  testWidgets(
    'store header search splits comparison selection from main catalog',
    (tester) async {
      auditViewport(tester);
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      // 최소 두 개의 실제 공개 템플릿을 사용하며 구매·계정 요청은 대역으로 막는다.
      final fixtures = publishedCreationTemplates.take(2).toList();
      final first = fixtures[0], second = fixtures[1];
      final products = [
        for (final template in fixtures)
          PointShopProduct(
            productKey: pointShopTemplateKey(template),
            kind: 'template',
            assetId: '${template.id}',
            title: template.title,
            pointPrice: 0,
            isActive: true,
          ),
      ];
      await tester.pumpWidget(
        auditFrame(
          ProviderScope(
            retry: (_, __) => null,
            overrides: [
              mockTemplateList(() => fixtures),
              pointShopCatalogProvider.overrideWith((_) async => products),
              publicPointShopCatalogProvider.overrideWith(
                (_) async => products,
              ),
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
                debugShowCheckedModeBanner: false,
                theme: SnapFitTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: const StoreHubScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final template in fixtures) {
        await loadCatalogPreview(tester, template);
      }
      await tester.pumpAndSettle();

      await _compare(tester, first);
      final mainScreen = tester.widget<StoreScreen>(find.byType(StoreScreen));
      expect(mainScreen.searchMode, isFalse);
      expect(_selected(tester), [first.id]);
      expect(find.text('비교할 디자인 1/3'), findsOneWidget);
      await auditCapture(tester, '04-store-main-comparison-selected');

      await tester.tap(find.byTooltip('스토어 검색'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<StoreScreen>(find.byType(StoreScreen)).searchMode,
        isTrue,
      );
      // 검색 화면에는 메인에서 선택한 첫 디자인의 트레이가 없다.
      expect(_selected(tester), isEmpty);
      final search = find.byType(TextField);
      await tester.enterText(search, second.title);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _compare(tester, second);
      expect(_selected(tester), [second.id]);
      expect(
        find.byKey(ValueKey('comparison-selected-${first.id}')),
        findsNothing,
      );
      final searchController = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(searchController.text, second.title);
      await auditCapture(tester, '05-store-search-comparison-isolated');

      Navigator.of(tester.element(find.byType(StoreScreen))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<StoreScreen>(find.byType(StoreScreen)),
        same(mainScreen),
      );
      expect(_selected(tester), [first.id]);
      expect(
        find.byKey(ValueKey('comparison-selected-${second.id}')),
        findsNothing,
      );
      expect(find.text('비교할 디자인 1/3'), findsOneWidget);
      await auditCapture(tester, '06-store-main-search-selection-discarded');
      // ignore: avoid_print
      print(
        'STORE_COMPARISON: main=${first.id}; search=${second.id}; returned-main=${_selected(tester)}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'package:flutter/material.dart';
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
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_design_comparison.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

void main() {
  testWidgets('store refresh updates the cached public comparison price too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    addTearDown(() => CatalogFavorites.instance.dispose());

    final designs = [
      bundledCreationTemplates.first,
      publishedPremiumTemplates.first,
    ];
    var paidPrice = 600;
    var signedCatalogReads = 0;
    var publicCatalogReads = 0;
    List<PointShopProduct> products() => [
      for (final design in designs)
        PointShopProduct(
          productKey: pointShopTemplateKey(design),
          kind: 'template',
          assetId: '${design.id}',
          title: design.title,
          pointPrice: design.isPremium ? paidPrice : 0,
          isActive: true,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((_) async => designs),
          storeCurationsProvider.overrideWith((_) async => {}),
          pointShopCatalogProvider.overrideWith((_) async {
            signedCatalogReads++;
            return products();
          }),
          publicPointShopCatalogProvider.overrideWith((_) async {
            publicCatalogReads++;
            return products();
          }),
          ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const Scaffold(body: StoreScreen(embedded: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final design in designs) {
      final compare = find.byKey(ValueKey('compare-template-${design.id}'));
      await tester.scrollUntilVisible(
        compare,
        160,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(compare);
      await tester.pumpAndSettle();
      await tester.tap(compare);
      await tester.pumpAndSettle();
    }

    Future<void> openComparison() async {
      final open = find.byKey(const ValueKey('template-comparison-open'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDesignComparisonView), findsOneWidget);
    }

    await openComparison();
    expect(find.text('600P'), findsOneWidget);
    expect(signedCatalogReads, 1);
    expect(publicCatalogReads, 1);
    await tester.tap(find.byTooltip('비교 닫기'));
    await tester.pumpAndSettle();

    paidPrice = 700;
    final refreshed = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refreshed;
    await tester.pumpAndSettle();
    expect(signedCatalogReads, 2);
    // Refresh returns the catalog to its start. The narrower web layout has
    // one column, so revisit the paid card before inspecting its fresh price.
    final paidCard = find.byKey(ValueKey('store-template-${designs.last.id}'));
    await tester.scrollUntilVisible(
      paidCard,
      160,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('700P'));
    await tester.pumpAndSettle();
    expect(find.text('700P'), findsOneWidget);

    await openComparison();
    expect(publicCatalogReads, 2);
    expect(find.text('700P'), findsOneWidget);
    expect(find.text('600P'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/material_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../../tool/template_studio/export_price_application.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  testWidgets(
    'new materials lead the real catalog and remain searchable across free and paid frames',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      await tester.pumpWidget(
        wrapCreation(
          ProviderScope(
            overrides: [
              mockMaterialList(() => bundledMaterials),
              storeDiscoveryProvider.overrideWith(
                (_) async => bundledStoreDiscovery,
              ),
              storeDiscoveryClockProvider.overrideWithValue(
                DateTime.utc(2026, 11, 3),
              ),
            ],
            child: const MaterialCatalogScreen(searchMode: true),
          ),
          shopProducts: pointShopPriceApplicationRows()
              .map(PointShopProduct.fromJson)
              .toList(),
        ),
      );
      await tester.pumpAndSettle();
      final sorting = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('catalog-sort')),
      );
      expect(sorting.value, '최신순');
      expect(sorting.items!.map((item) => item.value), ['최신순', '인기순']);
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final firstNew = find.byKey(
        const ValueKey('material-item-sticker:story-coffee-notebook-paper'),
      );
      await tester.scrollUntilVisible(firstNew, 200, scrollable: scroll);
      expect(firstNew, findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('store-badge-sticker:story-coffee-notebook-paper-NEW'),
        ),
        findsOneWidget,
      );
      for (final (title, key, price) in [
        ('카페 제본 매트', 'frame:cafeLedgerMat', '무료'),
        ('듀플렉스 아카이브', 'frame:nocturneDuplex', '400P'),
      ]) {
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, title);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final item = find.byKey(ValueKey('material-item-$key'));
        await tester.scrollUntilVisible(item, 200, scrollable: scroll);
        expect(item, findsOneWidget);
        expect(find.byKey(ValueKey('store-badge-$key-NEW')), findsOneWidget);
        expect(find.text(price), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

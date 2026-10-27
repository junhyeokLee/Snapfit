import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/snapfit_shimmer.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'store header paints before catalog reads; slow prices do not block entry',
    (tester) async {
      var catalogReads = 0;
      final prices = Completer<List<PointShopProduct>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockTemplateList(() {
              catalogReads++;
              return <PremiumTemplate>[];
            }),
            pointShopCatalogProvider.overrideWith((_) => prices.future),
            notificationUnreadCountProvider.overrideWith((_) async => 0),
          ],
          child: const MaterialApp(home: StoreHubScreen()),
        ),
      );
      expect(find.byTooltip('스토어 검색'), findsOneWidget);
      expect(find.byType(SnapFitShimmerTemplateTileGrid), findsOneWidget);
      expect(find.byType(StoreScreen), findsNothing);
      expect(catalogReads, 0);
      await tester.pump();
      expect(find.byType(StoreScreen), findsOneWidget);
      expect(find.byTooltip('스토어 검색'), findsOneWidget);
      expect(catalogReads, 1);
      expect(prices.isCompleted, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

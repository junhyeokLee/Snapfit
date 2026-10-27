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
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets(
    'a recreated storefront keeps its chip aligned with the retained feed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var localLoads = 0;
      final items = [
        for (final (group, category) in storeTemplateTopicOrder.indexed)
          for (var i = 0; i < 3; i++)
            PremiumTemplate(
              id: 80000 + group * 3 + i,
              title: 'Review $category $i',
              category: category,
              coverImageUrl: '',
              previewImages: const [],
              pageCount: 12,
              userCount: 0,
            ),
      ];
      final container = ProviderContainer(
        overrides: [
          mockTemplateList(() {
            localLoads++;
            return items;
          }),
          pointShopCatalogProvider.overrideWith(
            (_) async => [
              for (final template in items)
                PointShopProduct(
                  productKey: pointShopTemplateKey(template),
                  kind: 'template',
                  assetId: '${template.id}',
                  title: template.title,
                  pointPrice: 0,
                  isActive: true,
                ),
            ],
          ),
          storeCurationsProvider.overrideWith(
            (_) async => <String, StoreCuration>{},
          ),
        ],
      );
      addTearDown(container.dispose);
      var visible = true;
      var incarnation = 0;
      late StateSetter change;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  change = setState;
                  return visible
                      ? StoreScreen(key: ValueKey(incarnation), embedded: true)
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final category in ['여행', '동아리', '일상']) {
        final chip = find.byKey(ValueKey('store-topic-$category'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final oldState = tester.state(find.byType(StoreScreen));
        final controller = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        final rows = container.read(storeTemplateFeedProvider).items;
        expect(
          container.read(storeTemplateFeedProvider).filterCategory,
          category,
        );
        expect(rows.every((t) => t.category == category), isTrue);
        change(() => visible = false);
        await tester.pumpAndSettle();
        expect(controller.hasClients, isFalse);
        change(() {
          visible = true;
          incarnation++;
        });
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(StoreScreen)), isNot(same(oldState)));
        expect(container.read(storeTemplateFeedProvider).items, same(rows));
        expect(
          tester.widget<ChoiceChip>(chip).selected,
          isTrue,
          reason: 'Visible controls must match the retained server category',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const ValueKey('store-topic-전체')))
              .selected,
          isFalse,
        );
      }
      expect(localLoads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

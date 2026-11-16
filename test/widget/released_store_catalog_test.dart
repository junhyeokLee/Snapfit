import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../../tool/template_studio/export_price_application.dart';
import '../support/catalog_preview_loading.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    CatalogPreviews.clearCache();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogPreviews.clearCache();
  });

  testWidgets(
    'released store exposes all books, free/paid filters and latest artwork',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final products = pointShopPriceApplicationRows()
          .map(PointShopProduct.fromJson)
          .toList();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockTemplateList(() => publishedCreationTemplates),
            storeDiscoveryClockProvider.overrideWithValue(
              DateTime.utc(2026, 11, 3),
            ),
            storeDiscoveryProvider.overrideWith(
              (_) async => bundledStoreDiscovery,
            ),
          ],
          child: wrapCreation(
            const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: StoreScreen(searchMode: true),
            ),
            shopProducts: products,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('135개의 디자인'), findsOneWidget);
      final context = tester.element(find.byType(StoreScreen));
      final scope = ProviderScope.containerOf(context);
      expect(scope.read(storeTemplateFeedProvider).items, hasLength(135));
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .cacheExtent,
        inInclusiveRange(200, 400),
      );

      Future<void> price(String value) async {
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final segment = find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text(value),
        );
        await tester.ensureVisible(segment);
        await tester.tap(segment);
        await tester.pumpAndSettle();
      }

      await price('무료');
      expect(find.text('48개의 디자인'), findsOneWidget);
      await price('유료');
      expect(find.text('87개의 디자인'), findsOneWidget);
      await price('전체');

      // New categories and the free/paid club kits must all be searchable in
      // the actual store, rather than merely present in a design-review gallery.
      for (final edition in [
        ...sensoryStoryEditions,
        exclusiveStoryEditions.first,
        exclusiveStoryEditions.last,
        clubStoryEditions.first,
        clubStoryEditions.last,
        ...activityStoryEditions,
      ]) {
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, edition.title);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.text('1개의 디자인'), findsOneWidget);
        final card = find.byKey(
          ValueKey('store-template-${edition.catalogId}'),
        );
        await tester.scrollUntilVisible(
          card,
          240,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await loadCatalogPreview(
          tester,
          publishedCreationTemplates.singleWhere(
            (t) => t.id == edition.catalogId,
          ),
        );
        expect(card, findsOneWidget);
        if (edition.catalogId == -9761 || edition.catalogId == -9762) {
          expect(
            find.byKey(ValueKey('store-badge-${edition.productKey}-NEW')),
            findsOneWidget,
          );
        }
        expect(find.text('판매 준비 중'), findsNothing);
        expect(find.text(edition.isPremium ? '1800P' : '무료'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

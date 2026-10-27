import 'dart:collection';

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
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

// Real product badges stop at matching template rows near the front. Trailing
// material rows reveal a full price-table rebuild without timing assertions.
class _ObservedCatalog extends ListBase<PointShopProduct> {
  _ObservedCatalog(this.items);
  final List<PointShopProduct> items;
  int fullTraversals = 0;
  Iterable<PointShopProduct> _traverse() sync* {
    yield* items;
    fullTraversals++;
  }

  @override
  Iterator<PointShopProduct> get iterator => _traverse().iterator;
  @override
  int get length => items.length;
  @override
  set length(int value) => throw UnsupportedError('Immutable catalog');
  @override
  PointShopProduct operator [](int index) => items[index];
  @override
  void operator []=(int index, PointShopProduct value) =>
      throw UnsupportedError('Immutable catalog');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets('pagination reuses prices and curation; updates replace both', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final templates = List.generate(
      30,
      (i) => PremiumTemplate(
        id: i + 1,
        title: 'Design $i',
        category: '여행',
        coverImageUrl: '',
        previewImages: const [],
        pageCount: 24,
        userCount: 0,
        isPremium: true,
      ),
    );
    _ObservedCatalog prices({bool deactivateFirst = false}) =>
        _ObservedCatalog([
          for (final template in templates)
            PointShopProduct(
              productKey: pointShopTemplateKey(template),
              kind: 'template',
              assetId: '${template.id}',
              title: template.title,
              pointPrice: 1800,
              isActive: !deactivateFirst || template.id != 1,
            ),
          for (var i = 0; i < 500; i++)
            PointShopProduct(
              productKey: 'frame:$i',
              kind: 'frame',
              assetId: '$i',
              title: 'Frame',
            ),
        ]);
    var current = prices();
    final initial = current;
    final curation = StoreCuration(
      placement: 'templates',
      title: '추천',
      subtitle: '크게 보는 디자인',
      productKeys: templates.take(3).map(pointShopTemplateKey).toList(),
    );
    var visible = true;
    late StateSetter changeVisibility;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockTemplateList(() => templates),
          pointShopCatalogProvider.overrideWith((_) async => current),
          publicPointShopCatalogProvider.overrideWith((_) async => []),
          ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
          storeCurationsProvider.overrideWith(
            (_) async => {'templates': curation},
          ),
          pointShopRepositoryProvider.overrideWith(
            (_) => throw StateError('No commerce requests'),
          ),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                changeVisibility = setState;
                return TickerMode(
                  enabled: visible,
                  child: const StoreScreen(embedded: true),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    int count() =>
        (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
                as SliverChildBuilderDelegate)
            .childCount!;
    final firstCuration = tester.widget<TemplateCuration>(
      find.byType(TemplateCuration),
    );
    expect(firstCuration.templates.map((t) => t.id), contains(1));
    expect(initial.fullTraversals, 1);
    expect(count(), 12);
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(count(), 24);
    expect(
      initial.fullTraversals,
      1,
      reason: 'Paging must not rebuild the price table',
    );
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TemplateCuration>(find.byType(TemplateCuration)),
      same(firstCuration),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StoreScreen)),
    );
    current = prices(deactivateFirst: true);
    container.invalidate(pointShopCatalogProvider);
    await tester.pumpAndSettle();
    final updated = tester.widget<TemplateCuration>(
      find.byType(TemplateCuration),
    );
    expect(updated, isNot(same(firstCuration)));
    expect(updated.templates.map((t) => t.id), isNot(contains(1)));
    expect(updated.templates.map((t) => t.id), contains(2));
    expect(current.fullTraversals, 1);
    expect(initial.fullTraversals, 1);
    changeVisibility(() => visible = false);
    await tester.pumpAndSettle();
    current = prices();
    container.invalidate(pointShopCatalogProvider);
    await tester.pumpAndSettle();
    expect(
      current.fullTraversals,
      0,
      reason: 'A hidden store must defer indexing',
    );
    changeVisibility(() => visible = true);
    await tester.pumpAndSettle();
    expect(current.fullTraversals, 1);
    expect(
      tester
          .widget<TemplateCuration>(find.byType(TemplateCuration))
          .templates
          .map((t) => t.id),
      contains(1),
      reason: 'The latest catalog must be applied on resume',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

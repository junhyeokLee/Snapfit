import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  testWidgets('catalog artwork decodes small without reducing editor quality', (
    tester,
  ) async {
    final spec = studioDecorations.firstWhere((item) => item.assetPath != null);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: StudioDecoration(spec: spec, imageDecodeWidth: 384),
        ),
      ),
    );
    final thumbnail = tester.widget<Image>(find.byType(Image));
    expect(thumbnail.image, isA<ResizeImage>());
    expect((thumbnail.image as ResizeImage).width, 384);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: StudioDecoration(spec: spec),
        ),
      ),
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
  });
  testWidgets('paid filter uses sale price even for owned materials', (
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
    final paid = studioDecorations.first;
    final inactive = studioDecorations[1];
    final paidKey = 'sticker:${paid.id}';
    await tester.pumpWidget(
      wrapCreation(
        ProviderScope(
          overrides: [
            ownedPointShopKeysProvider.overrideWith((ref) async => {paidKey}),
            pointShopCatalogProvider.overrideWith(
              (ref) async => [
                PointShopProduct(
                  productKey: paidKey,
                  kind: 'sticker',
                  assetId: paid.id,
                  title: paid.label,
                  pointPrice: 100,
                  isActive: true,
                ),
                PointShopProduct(
                  productKey: 'sticker:${inactive.id}',
                  kind: 'sticker',
                  assetId: inactive.id,
                  title: inactive.label,
                  pointPrice: 100,
                  isActive: false,
                ),
              ],
            ),
          ],
          child: const MaterialCatalogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final segment = find.byType(SegmentedButton<String>);
    await tester.ensureVisible(segment);
    await tester.tap(find.descendant(of: segment, matching: find.text('유료')));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<String>>(segment).selected, {'유료'});
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final delegate =
        tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
            as SliverChildBuilderDelegate;
    expect(delegate.childCount, 1);
    expect(find.byKey(ValueKey('material-item-$paidKey')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byTooltip('즐겨찾기만 보기')).dx,
      greaterThanOrEqualTo(tester.getTopRight(segment).dx),
    );
    await tester.ensureVisible(segment);
    await tester.tap(find.descendant(of: segment, matching: find.text('무료')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('material-item-$paidKey')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets(
      'materials $size: lazy batches, tab reset, favorites empty state',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        CatalogFavorites.instance = CatalogFavorites();
        await CatalogFavorites.instance.load();
        addTearDown(() => CatalogFavorites.instance.dispose());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ownedPointShopKeysProvider.overrideWith(
                (ref) async => <String>{},
              ),
              pointShopCatalogProvider.overrideWith((ref) async => []),
            ],
            child: wrapCreation(const MaterialCatalogScreen()),
          ),
        );
        await tester.pumpAndSettle();
        int count() =>
            (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
                    as SliverChildBuilderDelegate)
                .childCount!;
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        scroll.jumpTo(650);
        await tester.pumpAndSettle();
        final initial = count();
        expect(initial, anyOf(12, 24));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(count(), initial + 12);
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final frameFilter = find.descendant(
          of: find.byKey(const ValueKey('material-topic-filters')),
          matching: find.text('프레임'),
        );
        await tester.ensureVisible(frameFilter);
        await tester.tap(frameFilter);
        await tester.pumpAndSettle();
        scroll.jumpTo(250);
        await tester.pumpAndSettle();
        expect(count(), anyOf(12, 24));
        await tester.ensureVisible(find.byTooltip('즐겨찾기만 보기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('즐겨찾기만 보기'));
        await tester.pumpAndSettle();
        expect(find.byType(SliverGrid), findsNothing);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(find.text('즐겨찾는 항목이 없어요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_material_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('STORE_MAIN_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/store-main-qa/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _PaintBinding();
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

  test(
    'editorial pagination never duplicates, skips or widens a pending pair',
    () {
      for (var count = 0; count < 100; count++) {
        final rows = storeEditorialRows(count);
        expect(rows.expand((row) => row), List.generate(count, (i) => i));
        expect(rows.every((row) => row.length <= 2), isTrue);
        for (final row in rows.where((row) => row.first % 5 == 0)) {
          expect(row.length, 1);
        }
      }
      expect(storeEditorialRows(12).last, [11]);
      expect(storeEditorialRows(6, columns: 4), [
        [0],
        [1, 2, 3, 4],
        [5],
      ]);
      expect(storeEditorialRows(24).firstWhere((row) => row.first == 11), [
        11,
        12,
      ]);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('editorial scenes, mixed materials and list work dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final prices = [
        for (final e in pointShopLaunchPrices.entries)
          PointShopProduct(
            productKey: e.key,
            kind: e.key.split(':').first,
            assetId: e.key.split(':').last,
            title: e.key,
            pointPrice: e.value.points,
            isActive: true,
          ),
      ];
      await tester.pumpWidget(
        wrapCreation(
          ProviderScope(
            overrides: [
              templateListProvider.overrideWith(
                (_) async => publishedCreationTemplates,
              ),
              storeCurationsProvider.overrideWith(
                (_) async => {
                  'templates': StoreCuration.templates,
                  'materials': StoreCuration.materials,
                },
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: const StoreHubScreen(),
                  bottomNavigationBar: HomeBottomNavigationBar(
                    currentIndex: 2,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          ),
          dark: dark,
          shopProducts: prices,
          showShell: false,
        ),
      );
      await _paint(tester);
      final stage = tester.getRect(
        find.byKey(const ValueKey('curation-pager')),
      );
      final departments = tester.getRect(
        find.byKey(const ValueKey('store-departments')),
      );
      expect(stage.top, lessThanOrEqualTo(64));
      expect(stage.height, greaterThan(350));
      expect(departments.bottom, lessThanOrEqualTo(stage.top));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final details = tester.getRect(
        find.byKey(const ValueKey('curation-details')),
      );
      final suffix = dark ? 'dark' : 'light';
      await tester.tap(find.byTooltip('다음 컬렉션'));
      await _paint(tester);
      expect(find.byKey(const ValueKey('curation-scene-1')), findsWidgets);
      expect(
        tester.getRect(find.byKey(const ValueKey('curation-details'))),
        details,
      );
      await _capture(tester, boundary, 'collection-wedding-390-$suffix');
      await tester.tap(find.byTooltip('다음 컬렉션'));
      await _paint(tester);
      await tester.tap(find.byTooltip('다음 컬렉션'));
      await _paint(tester);
      expect(find.byKey(const ValueKey('curation-scene-2')), findsWidgets);
      expect(
        tester.getRect(find.byKey(const ValueKey('curation-details'))),
        details,
      );
      await _capture(tester, boundary, 'collection-daily-390-$suffix');
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byTooltip('꾸밈소재 모두 보기'),
        180,
        scrollable: scrollable,
      );
      await tester.ensureVisible(find.byTooltip('꾸밈소재 모두 보기'));
      await _paint(tester);
      await _capture(tester, boundary, 'mixed-materials-390-$suffix');
      expect(find.byType(StoreMaterialDiscovery), findsOneWidget);
      await tester.tap(find.byTooltip('꾸밈소재 모두 보기'));
      await _paint(tester);
      expect(find.byType(MaterialCatalogScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('store-department-0')));
      await _paint(tester);
      final featured = find.byKey(
        ValueKey('editorial-edition-${publishedCreationTemplates.first.id}'),
      );
      await tester.scrollUntilVisible(featured, 180, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(featured), alignment: .05);
      await _paint(tester);
      await _capture(tester, boundary, 'editorial-list-390-$suffix');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'discovery uses canonical favorites and respects a hidden selection',
    (tester) async {
      var enabled = true;
      late StateSetter change;
      const key = 'sticker:studioBlueFibre';
      await tester.pumpWidget(
        wrapCreation(
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return ProviderScope(
                key: ValueKey(enabled),
                overrides: [
                  storeCurationsProvider.overrideWith(
                    (_) async => {
                      'materials': StoreCuration(
                        placement: 'materials',
                        title: '종이 컬렉션',
                        subtitle: '',
                        productKeys: const [key],
                        enabled: enabled,
                      ),
                    },
                  ),
                ],
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: StoreMaterialDiscovery(onBrowse: () {}),
                  ),
                ),
              );
            },
          ),
          shopProducts: const [
            PointShopProduct(
              productKey: key,
              kind: 'sticker',
              assetId: 'studioBlueFibre',
              title: '종이',
              pointPrice: 200,
              isActive: true,
            ),
          ],
          showShell: false,
        ),
      );
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('discovery-material-$key')));
      await _paint(tester);
      final detail = tester.widget<MaterialDetailScreen>(
        find.byType(MaterialDetailScreen),
      );
      expect(detail.favoriteKey, 'decoration:studioBlueFibre');
      expect(detail.type, '종이');
      Navigator.of(tester.element(find.byType(MaterialDetailScreen))).pop();
      await _paint(tester);
      change(() => enabled = false);
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('discovery-material-$key')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'header searches the current department without losing discovery position',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateListProvider.overrideWith(
              (_) async => publishedCreationTemplates,
            ),
            storeCurationsProvider.overrideWith(
              (_) async => {
                'templates': StoreCuration.templates,
                'materials': StoreCuration.materials,
              },
            ),
          ],
          child: wrapCreation(
            const MediaQuery(
              data: MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: StoreHubScreen(),
            ),
            showShell: false,
          ),
        ),
      );
      await _paint(tester);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).first)
          .controller!;
      scroll.jumpTo(200);
      await _paint(tester);
      await tester.tap(find.byTooltip('스토어 검색'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        tester
            .widget<StoreScreen>(
              find.byWidgetPredicate((w) => w is StoreScreen && w.searchMode),
            )
            .searchMode,
        isTrue,
      );
      await tester.enterText(find.byType(TextField).hitTestable(), '디자인없음999');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 디자인이 없어요'), findsOneWidget);
      expect(find.byType(StoreMaterialDiscovery), findsNothing);
      tester.view.viewInsets = const FakeViewPadding();
      Navigator.of(
        tester.element(
          find.byWidgetPredicate((w) => w is StoreScreen && w.searchMode),
        ),
      ).pop();
      await _paint(tester);
      expect(scroll.offset, 200);
      await tester.tap(find.byKey(const ValueKey('store-department-1')));
      await _paint(tester);
      await tester.tap(find.byTooltip('스토어 검색'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        tester
            .widget<MaterialCatalogScreen>(
              find.byWidgetPredicate(
                (w) => w is MaterialCatalogScreen && w.searchMode,
              ),
            )
            .searchMode,
        isTrue,
      );
      await tester.enterText(find.byType(TextField).hitTestable(), '소재없음999');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 소재가 없어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

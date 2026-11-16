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
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_material_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';
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

void _expectFeaturedPosition(WidgetTester tester, int current, int total) {
  final counter = tester.widget<Text>(
    find.byKey(const ValueKey('store-featured-position')),
  );
  final text = counter.data ?? counter.textSpan?.toPlainText() ?? '';
  final values = RegExp(
    r'\d+',
  ).allMatches(text).map((match) => int.parse(match.group(0)!)).toList();
  expect(values, [current, total]);
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
    testWidgets('featured products, mixed materials and list work dark=$dark', (
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
              mockTemplateList(() => publishedCreationTemplates),
              storeDiscoveryProvider.overrideWith((_) async => const {}),
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
      final departments = tester.getRect(
        find.byKey(const ValueKey('store-departments')),
      );
      final badgeRules = tester.getRect(
        find.byKey(const ValueKey('store-badge-rules')),
      );
      expect(departments.bottom, lessThanOrEqualTo(64));
      expect(badgeRules.top, greaterThanOrEqualTo(departments.bottom));
      final discovery = tester.getRect(
        find.byKey(const ValueKey('store-design-discovery')),
      );
      expect(discovery.top, greaterThanOrEqualTo(departments.bottom));
      expect(badgeRules.top, greaterThanOrEqualTo(discovery.bottom));
      final shelf = find.byKey(const ValueKey('store-featured-templates'));
      final selected = StoreCuration.templates
          .resolve(publishedCreationTemplates, pointShopTemplateKey)
          .take(6)
          .toList();
      expect(selected, hasLength(6));
      expect(shelf, findsOneWidget);
      expect(
        find.byKey(ValueKey('store-featured-template-${selected[1].id}')),
        findsNothing,
        reason: 'Only the selected book occupies the hero stage',
      );
      final shelfBounds = tester.getRect(shelf);
      expect(shelfBounds.top, greaterThanOrEqualTo(discovery.top));
      expect(shelfBounds.bottom, lessThanOrEqualTo(discovery.bottom));
      final firstProduct = find.byKey(
        ValueKey('store-featured-template-${selected.first.id}'),
      );
      expect(firstProduct, findsOneWidget);
      expect(
        find
            .byKey(ValueKey('store-featured-open-${selected.first.id}'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                ValueKey('store-featured-template-title-${selected.first.id}'),
              ),
            )
            .semanticsLabel,
        selected.first.title,
      );
      expect(
        find.byKey(
          ValueKey('store-featured-template-price-${selected.first.id}'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TemplateCuration), findsNothing);
      expect(find.byKey(const ValueKey('curation-pager')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final suffix = dark ? 'dark' : 'light';
      _expectFeaturedPosition(tester, 1, selected.length);
      await _capture(tester, boundary, 'featured-first-390-$suffix');
      expect(
        find.byKey(ValueKey('store-featured-open-${selected.first.id}')),
        findsOneWidget,
      );
      for (var index = 1; index < selected.length; index++) {
        final next = find.byKey(const ValueKey('store-featured-next'));
        await tester.ensureVisible(next);
        await _paint(tester);
        await tester.tap(next);
        await _paint(tester);
        _expectFeaturedPosition(tester, index + 1, selected.length);
        expect(
          tester
              .widget<Text>(
                find.byKey(
                  ValueKey(
                    'store-featured-template-title-${selected[index].id}',
                  ),
                ),
              )
              .semanticsLabel,
          selected[index].title,
        );
        expect(
          find.byKey(
            ValueKey('store-featured-template-price-${selected[index].id}'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('store-featured-open-${selected[index].id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey('store-featured-template-${selected[index - 1].id}'),
          ),
          findsNothing,
        );
      }
      final previous = find.byKey(const ValueKey('store-featured-previous'));
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await _paint(tester);
      _expectFeaturedPosition(tester, selected.length - 1, selected.length);
      expect(
        find.byKey(
          ValueKey('store-featured-open-${selected[selected.length - 2].id}'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('store-featured-next')));
      await _paint(tester);
      expect(
        find.byKey(ValueKey('store-featured-open-${selected.last.id}')),
        findsOneWidget,
      );
      _expectFeaturedPosition(tester, selected.length, selected.length);
      await _capture(tester, boundary, 'featured-last-390-$suffix');
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byType(TemplateCatalogTile).first,
        180,
        scrollable: scrollable,
      );
      await _paint(tester);
      final catalog = tester.widget<TemplateEditorialList>(
        find.byType(TemplateEditorialList),
      );
      expect(catalog.interlude, isA<StoreMaterialDiscovery>());
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
      // The compact first row remains the entry into actual products.
      final firstListed = tester
          .widget<TemplateEditorialList>(find.byType(TemplateEditorialList))
          .templates
          .first;
      final featured = find.byKey(ValueKey('store-template-${firstListed.id}'));
      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).first)
          .controller!
          .jumpTo(0);
      await _paint(tester);
      await tester.scrollUntilVisible(
        featured,
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(tester.element(featured), alignment: .05);
      await _paint(tester);
      await _capture(tester, boundary, 'editorial-list-390-$suffix');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'discovery can browse and open all twelve curated materials lazily',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrapCreation(
          ProviderScope(
            overrides: [
              storeCurationsProvider.overrideWith(
                (_) async => {'materials': StoreCuration.materials},
              ),
            ],
            child: Scaffold(
              body: SingleChildScrollView(
                child: StoreMaterialDiscovery(onBrowse: () {}),
              ),
            ),
          ),
          shopProducts: [
            for (final key in StoreCuration.materials.productKeys)
              PointShopProduct(
                productKey: key,
                kind: key.split(':').first,
                assetId: key.split(':').last,
                title: key,
                pointPrice: pointShopLaunchPrices[key]!.points,
                isActive: true,
              ),
          ],
          showShell: false,
        ),
      );
      await tester.pumpAndSettle();
      final shelf = find.byKey(
        const ValueKey('store-material-discovery-shelf'),
      );
      final lastKey = StoreCuration.materials.productKeys.last;
      final last = find.byKey(ValueKey('discovery-material-$lastKey'));
      expect(shelf, findsOneWidget);
      expect(last, findsNothing);
      await tester.scrollUntilVisible(
        last,
        500,
        scrollable: find.descendant(
          of: shelf,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MaterialDetailScreen>(find.byType(MaterialDetailScreen))
            .productKey,
        lastKey,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
            mockTemplateList(() async => publishedCreationTemplates),
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
      // Search and mood controls can fill the keyboard-reduced viewport.
      // Reach the result sliver through the active search route's scroll view.
      await tester.scrollUntilVisible(
        find.text('조건에 맞는 디자인이 없어요'),
        180,
        scrollable: find
            .descendant(
              of: find.byWidgetPredicate(
                (widget) => widget is StoreScreen && widget.searchMode,
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
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

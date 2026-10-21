import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_catalog_tile.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import '../support/store_catalog_navigation.dart';

Future<void> captureHub(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  if (!const bool.fromEnvironment('STORE_HUB_QA')) return;
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(widget.image, boundary.currentContext!);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('output/store-hub-qa').createSync(recursive: true);
    File(
      'output/store-hub-qa/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'BookMyungjo',
    )..addFont(rootBundle.load('assets/fonts/BookkMyungjo_Bold.ttf'))).load();
  });
  testWidgets(
    'material tiles distinguish declared free from missing paid prices',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrapCreation(
          ProviderScope(
            overrides: [
              pointShopCatalogProvider.overrideWith((ref) async => []),
              ownedPointShopKeysProvider.overrideWith(
                (ref) async => <String>{},
              ),
            ],
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 300,
                  child: Row(
                    children: [
                      for (final key in [
                        'frame:studioOval',
                        'frame:storyVowGate',
                      ])
                        Expanded(
                          child: MaterialCatalogTile(
                            productKey: key,
                            title: key,
                            type: '프레임',
                            preview: const SizedBox(),
                            onOpen: () {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('무료'), findsOneWidget);
      expect(find.text('판매 준비 중'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(320, 568), 1.8),
    (const Size(648, 320), 1.8),
  ]) {
    testWidgets(
      'store hub $size text=$scale preserves each catalog and loads materials on demand',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        CatalogFavorites.instance = CatalogFavorites();
        await CatalogFavorites.instance.load();
        addTearDown(() => CatalogFavorites.instance.dispose());
        final boundary = GlobalKey();
        await tester.pumpWidget(
          wrapCreation(
            ProviderScope(
              overrides: [
                templateListProvider.overrideWith(
                  (ref) async => publishedCreationTemplates,
                ),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: const StoreHubScreen(),
                ),
              ),
            ),
            textScale: scale,
            shopProducts: [
              for (final entry in pointShopLaunchPrices.entries)
                PointShopProduct(
                  productKey: entry.key,
                  kind: entry.key.split(':').first,
                  assetId: entry.key.split(':').last,
                  title: entry.key,
                  pointPrice: entry.value.points,
                  isActive: true,
                ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final suffix = '${size.width.toInt()}${scale > 1 ? '-large' : ''}';
        await captureHub(tester, boundary, 'templates-$suffix');
        expect(find.byType(ExperienceHeader), findsOneWidget);
        expect(
          find.byType(MaterialCatalogScreen, skipOffstage: false),
          findsNothing,
        );
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!;
        scroll.jumpTo(320);
        await tester.pumpAndSettle();
        final position = scroll.offset;
        await selectStoreCatalog(tester, 1);
        expect(find.byType(ExperienceHeader), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.byTooltip('스토어 검색'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MaterialCatalogScreen>(find.byType(MaterialCatalogScreen))
              .searchMode,
          isTrue,
        );
        expect(find.text('소재 검색'), findsOneWidget);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byType(TextField)),
          ).scale(14),
          closeTo(14 * scale, .01),
        );
        await tester.enterText(find.byType(TextField), '프레임');
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '프레임',
        );
        final searchList = tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('material-catalog-scroll')),
            )
            .controller!;
        searchList.jumpTo(
          260.0.clamp(0.0, searchList.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        final searchResults = tester
            .widgetList<MaterialCatalogTile>(find.byType(MaterialCatalogTile))
            .toList();
        expect(searchResults, isNotEmpty);
        expect(
          searchResults.every(
            (tile) => tile.type.contains('프레임') || tile.title.contains('프레임'),
          ),
          isTrue,
        );
        searchList.jumpTo(0);
        await tester.pumpAndSettle();
        final frameCategory = find.byKey(const ValueKey('material-type-프레임'));
        await tester.ensureVisible(frameCategory);
        await tester.tap(frameCategory);
        await tester.pumpAndSettle();
        searchList.jumpTo(
          260.0.clamp(0.0, searchList.position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
        final frameResults = tester
            .widgetList<MaterialCatalogTile>(find.byType(MaterialCatalogTile))
            .toList();
        expect(frameResults, isNotEmpty);
        expect(frameResults.every((tile) => tile.type == '프레임'), isTrue);
        await tester.tap(find.byTooltip('뒤로가기'));
        await tester.pumpAndSettle();
        final mainMaterials = tester.widget<MaterialCatalogScreen>(
          find.byType(MaterialCatalogScreen),
        );
        expect(mainMaterials.searchMode, isFalse);
        expect(mainMaterials.embedded, isTrue);
        expect(find.byType(TextField), findsNothing);
        await tester.ensureVisible(find.byType(SegmentedButton<String>));
        final freeFilter = find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('무료'),
        );
        await Scrollable.ensureVisible(
          tester.element(freeFilter),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(freeFilter);
        await tester.pumpAndSettle();
        await selectStoreCatalog(tester, 0);
        expect(scroll.offset, position);
        await selectStoreCatalog(tester, 1);
        expect(
          tester
              .widget<SegmentedButton<String>>(
                find.byType(SegmentedButton<String>),
              )
              .selected,
          {'무료'},
        );
        // Catalog additions can move any named material beyond the first
        // lazy batch. Returning from search must reveal the main free results.
        if (find.byType(MaterialCatalogTile).evaluate().isEmpty) {
          final list = tester
              .widget<CustomScrollView>(
                find.byKey(const ValueKey('material-catalog-scroll')),
              )
              .controller!;
          list.jumpTo(260.0.clamp(0.0, list.position.maxScrollExtent));
          await tester.pumpAndSettle();
        }
        final freeResults = tester
            .widgetList<MaterialCatalogTile>(find.byType(MaterialCatalogTile))
            .toList();
        expect(freeResults, isNotEmpty);
        expect(
          freeResults.every(
            (tile) =>
                (pointShopLaunchPrices[tile.productKey]?.points ?? 0) == 0,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('STORE_HUB_QA')) {
          final materialScroll = tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .controller!;
          materialScroll.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(SegmentedButton<String>),
              matching: find.text('전체'),
            ),
          );
          await tester.pumpAndSettle();
          await captureHub(tester, boundary, 'materials-$suffix');
          final paperFilter = find.byKey(const ValueKey('material-type-종이'));
          await tester.ensureVisible(paperFilter);
          await tester.tap(paperFilter);
          await tester.pumpAndSettle();
          await captureHub(tester, boundary, 'papers-$suffix');
        }
      },
    );
  }
}

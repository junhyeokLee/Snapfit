import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

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
  setUpAll(loadCreationFonts);
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets(
      'store hub $size preserves each catalog and loads materials on demand',
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
                pointShopCatalogProvider.overrideWith(
                  (ref) async => [
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
                ownedPointShopKeysProvider.overrideWith(
                  (ref) async => <String>{},
                ),
              ],
              child: MediaQuery(
                data: MediaQueryData(size: size, disableAnimations: true),
                child: RepaintBoundary(
                  key: boundary,
                  child: const StoreHubScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await captureHub(tester, boundary, 'templates-${size.width.toInt()}');
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
        await tester.tap(find.text('꾸밈소재'));
        await tester.pumpAndSettle();
        expect(find.byType(ExperienceHeader), findsOneWidget);
        await tester.tap(find.text('검색'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '프레임');
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.ensureVisible(find.byType(SegmentedButton<String>));
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<String>),
            matching: find.text('무료'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('템플릿').first);
        await tester.pumpAndSettle();
        expect(scroll.offset, position);
        await tester.tap(find.text('꾸밈소재'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '프레임',
        );
        expect(
          tester
              .widget<SegmentedButton<String>>(
                find.byType(SegmentedButton<String>),
              )
              .selected,
          {'무료'},
        );
        await tester.tap(find.text('검색 접기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('검색 지우기'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byType(TextField, skipOffstage: false).last,
              )
              .controller!
              .text,
          '',
        );
        expect(
          find.byKey(
            const ValueKey('material-item-sticker:materialBlindEmboss'),
          ),
          findsOneWidget,
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
          await captureHub(tester, boundary, 'materials-${size.width.toInt()}');
          await tester.ensureVisible(find.text('종이'));
          await tester.tap(find.text('종이'));
          await tester.pumpAndSettle();
          await captureHub(tester, boundary, 'papers-${size.width.toInt()}');
        }
      },
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/domain/store_template_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_design_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_featured_template_shelf.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

const _captureDirectory = String.fromEnvironment('STORE_DISCOVERY_QA_DIR');

PremiumTemplate _book(int id, String topic, List<String> tags) =>
    PremiumTemplate(
      id: id,
      title: '이름을 몰라도 $id',
      category: topic,
      tags: tags,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      templateJson: '{"pages":[]}',
    );

int _resultCount(WidgetTester tester) =>
    (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
            as SliverChildBuilderDelegate)
        .childCount!;

Widget _app(
  Widget child, {
  required List<PremiumTemplate> books,
  bool dark = false,
  double scale = 1,
  bool curated = false,
}) => ProviderScope(
  overrides: [
    mockTemplateList(() => books),
    storeCurationsProvider.overrideWith(
      (_) async => curated ? {'templates': StoreCuration.templates} : {},
    ),
    storeDiscoveryProvider.overrideWith((_) async => bundledStoreDiscovery),
  ],
  child: wrapCreation(
    child,
    dark: dark,
    textScale: scale,
    showShell: false,
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

void main() {
  setUpAll(() async {
    await loadCreationFonts();
    await (FontLoader(
      'BookMyungjo',
    )..addFont(rootBundle.load('assets/fonts/BookkMyungjo_Bold.ttf'))).load();
    if (_captureDirectory.isNotEmpty) {
      // Widget tests do not register the document fonts that native builds
      // load automatically. Captures must show the actual cover lettering.
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in manifest) {
        final loader = FontLoader(font['family'] as String);
        for (final face in font['fonts'] as List) {
          loader.addFont(rootBundle.load(face['asset'] as String));
        }
        await loader.load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets('visible search combines topic, mood and active filter reset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final books = [
      _book(1, '여행', ['필름']),
      _book(2, '일상', ['미니멀']),
      _book(3, '여행', ['미니멀']),
    ];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const StoreScreen(searchMode: true),
          ),
        ),
        books: books,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StoreDesignDiscovery), findsOneWidget);
    expect(_resultCount(tester), 3);
    final field = find.byKey(const ValueKey('store-discovery-search'));
    await tester.enterText(field, '여행 빈티지');
    await tester.pumpAndSettle();
    expect(_resultCount(tester), 1);
    final styles = find.byKey(const ValueKey('store-style-filters'));
    final film = find.byKey(const ValueKey('store-style-film'));
    await Scrollable.ensureVisible(tester.element(film));
    await tester.pumpAndSettle();
    await tester.tap(film);
    await tester.pumpAndSettle();
    expect(_resultCount(tester), 1);
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(_resultCount(tester), 1);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('store-style-semantics-film')),
          )
          .properties
          .selected,
      isTrue,
    );
    final all = find.byKey(const ValueKey('store-style-all'));
    await tester.drag(styles, const Offset(350, 0));
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(_resultCount(tester), 3);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale, dark) in [
    (390.0, 1.0, false),
    (390.0, 1.0, true),
    (320.0, 2.0, false),
  ]) {
    testWidgets('discovery layout width=$width scale=$scale dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final originalShadows = debugDisableShadows;
      if (_captureDirectory.isNotEmpty) {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = originalShadows);
      }
      await tester.pumpWidget(
        _app(
          RepaintBoundary(
            key: boundary,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const StoreHubScreen(),
              ),
            ),
          ),
          books: publishedCreationTemplates,
          dark: dark,
          scale: scale,
          curated: true,
        ),
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('분위기로 골라보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (_captureDirectory.isNotEmpty) {
        // Native preview workers and image IO use real time; the frame clock
        // then prepares one visible cover/spread at a time, as in the app.
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '$_captureDirectory/store-discovery-${width.toInt()}-${dark ? 'dark' : 'light'}-${scale.toInt()}x.png',
          );
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      debugDisableShadows = originalShadows;
      if (width == 390 && scale == 1 && !dark) {
        final shelf = find.byKey(const ValueKey('store-featured-templates'));
        expect(shelf, findsOneWidget);
        final featured = tester.widget<StoreFeaturedTemplateShelf>(
          find.byType(StoreFeaturedTemplateShelf),
        );
        final first = featured.selection!
            .resolve(featured.templates, pointShopTemplateKey)
            .first;
        final price = find.byKey(
          ValueKey('store-featured-template-price-${first.id}'),
        );
        expect(price, findsOneWidget);
        expect(tester.getRect(price).bottom, lessThan(650));
        expect(
          tester.getRect(find.byKey(const ValueKey('store-style-filters'))).top,
          greaterThan(tester.getRect(shelf).bottom),
        );
        final film = find.byKey(const ValueKey('store-style-film'));
        await Scrollable.ensureVisible(tester.element(film));
        await tester.pumpAndSettle();
        await tester.tap(film);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('store-featured-templates')),
          findsNothing,
        );
        final results = tester
            .widgetList<TemplateCatalogTile>(find.byType(TemplateCatalogTile))
            .map((tile) => tile.template)
            .toList();
        expect(results, isNotEmpty);
        expect(
          results.every((item) => matchesStoreTemplateStyle(item, 'film')),
          isTrue,
        );
        final all = find.byKey(const ValueKey('store-style-all'));
        await Scrollable.ensureVisible(tester.element(all));
        await tester.pumpAndSettle();
        await tester.tap(all);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('store-featured-templates')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}

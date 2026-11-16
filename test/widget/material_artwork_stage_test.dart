import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_artwork.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_catalog_tile.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_original_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_material_discovery.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_icon.dart';
import 'package:snap_fit/shared/web/web_design.dart' show WebPalette;

import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;

const _paperKey = 'sticker:materialVellumBand';
const _shelfKey = 'sticker:studioBlueFibre';
const _favoriteKey = 'decoration:materialVellumBand';

PointShopProduct _product(String key) => PointShopProduct(
  productKey: key,
  kind: key.split(':').first,
  assetId: key.split(':').last,
  title: '밝은 종이',
  pointPrice: 100,
  isActive: true,
);

Widget _app(
  Widget child, {
  bool dark = false,
  double scale = 1,
  String productKey = _paperKey,
}) => ProviderScope(
  key: ValueKey(productKey),
  overrides: [
    pointShopCatalogProvider.overrideWith((_) async => [_product(productKey)]),
    ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
    storeCurationsProvider.overrideWith(
      (_) async => {
        'materials': const StoreCuration(
          placement: 'materials',
          title: '한 끗을 더하는 소재',
          subtitle: '',
          productKeys: [_shelfKey],
        ),
      },
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
        extensions: [dark ? WebPalette.dark : WebPalette.light],
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

Color _stageColor(WidgetTester tester, String key) =>
    (tester
                .widget<DecoratedBox>(
                  find.byKey(ValueKey('material-artwork-stage-$key')),
                )
                .decoration
            as BoxDecoration)
        .color!;

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Future<({Color ink, double contrast})> _postalMarkInk() async {
  final source = await rootBundle.load(
    'assets/catalog_thumbnails/sticker_studioPostalMark.png',
  );
  final codec = await ui.instantiateImageCodec(
    source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  final rgba = (await frame.image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  final pixels = rgba.buffer.asUint8List();
  final originalBackground = MaterialOriginalPreview.backgroundFor(
    'sticker:studioPostalMark',
  );
  Color? strongestInk;
  var originalContrast = 1.0;
  for (var offset = 0; offset < pixels.length; offset += 4) {
    if (pixels[offset + 3] < 128) continue;
    final ink = Color.fromARGB(
      pixels[offset + 3],
      pixels[offset],
      pixels[offset + 1],
      pixels[offset + 2],
    );
    final contrast = _contrast(
      originalBackground,
      Color.alphaBlend(ink, originalBackground),
    );
    if (contrast > originalContrast) {
      originalContrast = contrast;
      strongestInk = ink;
    }
  }
  frame.image.dispose();
  codec.dispose();
  expect(strongestInk, isNotNull, reason: 'use actual visible source ink');
  return (ink: strongestInk!, contrast: originalContrast);
}

void main() {
  late CatalogFavorites previousFavorites;
  setUpAll(() async {
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });
  setUp(() async {
    previousFavorites = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previousFavorites;
  });

  for (final dark in [false, true]) {
    testWidgets('material source stays large and legible: dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final entry in {
        _paperKey: '종이',
        'frame:materialLinenOval': '프레임',
        'phrase:collage-atelier-ribbon': '문구',
      }.entries) {
        await tester.pumpWidget(
          _app(
            Center(
              child: SizedBox(
                width: 148,
                height: MaterialCatalogTile.extent(148, TextScaler.linear(1.8)),
                child: MaterialCatalogTile(
                  productKey: entry.key,
                  title: '오래 간직할 밝은 소재',
                  type: entry.value,
                  favoriteKey: _favoriteKey,
                  preview: const ColoredBox(
                    key: ValueKey('material-source'),
                    color: Colors.white,
                  ),
                  onOpen: () {},
                ),
              ),
            ),
            dark: dark,
            scale: 1.8,
            productKey: entry.key,
          ),
        );
        await tester.pumpAndSettle();
        final source = tester.getRect(
          find.byKey(const ValueKey('material-source')),
        );
        final stage = tester.getRect(
          find.byKey(ValueKey('material-artwork-stage-${entry.key}')),
        );
        expect(source.width, greaterThanOrEqualTo(132));
        expect(stage.contains(source.topLeft), isTrue);
        expect(
          stage.contains(source.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        final typeLabel = tester.getRect(find.text(entry.value));
        expect(typeLabel.bottom, lessThanOrEqualTo(source.top + .1));
        expect(find.text('100P'), findsOneWidget);
        final background = _stageColor(tester, entry.key);
        expect(background.computeLuminance(), greaterThan(.70));
        final label = tester.widget<Text>(find.text(entry.value));
        expect(_contrast(background, label.style!.color!), greaterThan(4.5));
        final bookmark = tester.widget<ExperienceIcon>(
          find.descendant(
            of: find.byType(CatalogFavoriteButton),
            matching: find.byType(ExperienceIcon),
          ),
        );
        expect(_contrast(background, bookmark.color!), greaterThan(4.5));
        final bookmarkContext = tester.element(
          find.byType(CatalogFavoriteButton),
        );
        expect(
          _contrast(background, WebPalette.of(bookmarkContext).ink),
          greaterThan(4.5),
        );
        if (entry.key == _paperKey) {
          expect(background.computeLuminance(), lessThan(.88));
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('larger art keeps the 44px favorite target and server price', (
    tester,
  ) async {
    var opens = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 164,
              height: MaterialCatalogTile.extent(164, TextScaler.noScaling),
              child: MaterialCatalogTile(
                productKey: _paperKey,
                title: '밝은 종이',
                type: '종이',
                favoriteKey: _favoriteKey,
                preview: const ColoredBox(
                  key: ValueKey('favorite-test-source'),
                  color: Colors.white,
                ),
                onOpen: () => opens++,
              ),
            ),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      final favorite = find.byKey(const ValueKey('favorite-$_favoriteKey'));
      final favoriteSize = tester.getSize(favorite);
      expect(favoriteSize.width, greaterThanOrEqualTo(44));
      expect(favoriteSize.height, greaterThanOrEqualTo(44));
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(CatalogFavorites.instance.contains(_favoriteKey), isTrue);
      expect(find.text('100P'), findsOneWidget);
      final bookmark = tester.widget<ExperienceIcon>(
        find.descendant(of: favorite, matching: find.byType(ExperienceIcon)),
      );
      expect(
        _contrast(_stageColor(tester, _paperKey), bookmark.color!),
        greaterThan(3),
      );
      await tester.tap(find.byKey(const ValueKey('favorite-test-source')));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(
        find.bySemanticsLabel(RegExp('밝은 종이 종이')),
        findsAtLeastNWidgets(1),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('dark artboard preserves actual transparent postal-mark ink', (
    tester,
  ) async {
    const key = 'sticker:studioPostalMark';
    final source = (await tester.runAsync(_postalMarkInk))!;
    Color? lightBoard;
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _app(
          const SizedBox.square(
            dimension: 164,
            child: MaterialArtworkStage(
              productKey: key,
              child: SizedBox.expand(),
            ),
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final board = _stageColor(tester, key);
      final actualContrast = _contrast(
        board,
        Color.alphaBlend(source.ink, board),
      );
      expect(board.computeLuminance(), greaterThan(.70));
      expect(actualContrast, greaterThan(2));
      expect(actualContrast, greaterThanOrEqualTo(source.contrast - .01));
      if (dark) {
        expect(board, lightBoard, reason: 'theme must not reduce original ink');
        final context = tester.element(find.byType(Scaffold));
        expect(Theme.of(context).brightness, Brightness.dark);
        expect(
          Theme.of(context).scaffoldBackgroundColor.computeLuminance(),
          lessThan(.08),
        );
      } else {
        lightBoard = board;
      }
    }
  });

  for (final scenario in [
    (size: const Size(320, 568), dark: true, scale: 1.8),
    (size: const Size(844, 390), dark: false, scale: 1.0),
    (size: const Size(390, 844), dark: false, scale: 2.0),
  ]) {
    testWidgets('discovery original artwork fits ${scenario.size}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var browse = 0;
      await tester.pumpWidget(
        _app(
          StoreMaterialDiscovery(onBrowse: () => browse++),
          productKey: _shelfKey,
          dark: scenario.dark,
          scale: scenario.scale,
        ),
      );
      await tester.pumpAndSettle();
      final stage = find.byKey(
        const ValueKey('material-artwork-stage-$_shelfKey'),
      );
      expect(tester.getSize(stage), const Size(164, 164));
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 320);
      expect(find.text('종이'), findsOneWidget);
      expect(find.byType(PointShopArtwork), findsNothing);
      expect(find.byType(TemplatePageRenderer), findsNothing);
      expect(find.byType(MaterialApplicationPreview), findsNothing);
      await tester.tap(find.byTooltip('꾸밈소재 모두 보기'));
      await tester.pumpAndSettle();
      expect(browse, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('discovery releases artwork while its retained tab is hidden', (
    tester,
  ) async {
    var visible = true;
    late StateSetter change;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return TickerMode(
              enabled: visible,
              child: StoreMaterialDiscovery(onBrowse: () {}),
            );
          },
        ),
        productKey: _shelfKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final color = _stageColor(tester, _shelfKey);
    change(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(_stageColor(tester, _shelfKey), color);
    change(() => visible = true);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(TemplatePageRenderer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/store_catalog_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_tab_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/reader_page_gallery.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_curation.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/core/templates/catalog_editorial_assets.g.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_artwork.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final templates = publishedCreationTemplates;
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    Size size,
    bool dark, {
    double scale = 1.2,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 30, right: 32, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((_) async => templates),
          storeCurationsProvider.overrideWith(
            (_) async => {
              'templates': StoreCuration.templates,
              'materials': StoreCuration.materials,
            },
          ),
          pointShopCatalogProvider.overrideWith(
            (_) async => [
              for (final t in templates)
                PointShopProduct(
                  productKey: pointShopTemplateKey(t),
                  kind: 'template',
                  assetId: pointShopTemplateKey(t).substring(9),
                  title: t.title,
                  pointPrice: t.isPremium ? 1800 : 0,
                  isActive: true,
                ),
              for (final entry in {
                'frame:materialLinenOval': 300,
                'sticker:atelierColorSlips': 0,
                'sticker:atelierRibbonPlate': 100,
                'phrase:collage-atelier-ribbon': 300,
              }.entries)
                PointShopProduct(
                  productKey: entry.key,
                  kind: entry.key.split(':').first,
                  assetId: entry.key.split(':').last,
                  title: entry.key,
                  pointPrice: entry.value,
                  isActive: true,
                ),
            ],
          ),
          ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('DISCOVERY_QA')) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder =
          name.startsWith('curation-') ||
              name.startsWith('materials-') ||
              name.startsWith('store-')
          ? 'curation-editorial-qa'
          : 'discovery-refinement-qa';
      final file = File('output/$folder/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('curation follows the editorial order and includes a free edition', () {
    final selected = curateTemplates(templates);
    expect(selected.length, lessThanOrEqualTo(4));
    expect(selected.map((t) => t.id).toSet().length, selected.length);
    expect(selected.any((t) => !t.isPremium), isTrue);
    expect(selected.any((t) => t.isPremium), isTrue);
    expect(selected.first.title, '해변에서 보낸 날');
    expect(curateTemplates([]), isEmpty);
  });

  test(
    'every published edition has an authentic editorial spread; custom documents never borrow one',
    () {
      expect(
        catalogEditorialAssets.keys.toSet(),
        templates.map((t) => t.id).toSet(),
      );
      for (final template in templates) {
        expect(File(catalogEditorialSpread(template)!).existsSync(), isTrue);
      }
      final altered = templates.first.copyWith(templateJson: '{"pages":[]}');
      expect(catalogEditorialSpread(altered), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('complete editorial store and lists $size dark=$dark', (
        tester,
      ) async {
        await mount(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const StoreHubScreen(),
            ),
          ),
          size,
          dark,
        );
        await tester.pumpAndSettle();
        await capture(
          tester,
          'store-top-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        final scroll = tester
            .widget<CustomScrollView>(find.byType(CustomScrollView).first)
            .controller!;
        scroll.jumpTo(540);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump();
        await capture(
          tester,
          'store-grid-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
        await selectStoreCatalog(tester, 1);
        final materialScroll = tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('material-catalog-scroll')),
            )
            .controller!;
        materialScroll.jumpTo(360);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump();
        await capture(
          tester,
          'store-material-grid-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390),
    const Size(648, 320),
  ]) {
    for (final dark in [false, true]) {
      final name = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('collection and editorial stay usable $name', (tester) async {
        final albums = [
          for (var i = 0; i < 9; i++)
            Album(
              id: i + 1,
              title: ['여행의 결', '우리가 함께한 계절', '작은 순간의 기록'][i % 3],
              userId: 'qa',
              ratio: '${[.75, 1.0, 4 / 3][i % 3]}',
              targetPages: 24,
              totalPages: 6,
              coverLayersJson: jsonEncode({
                'layers': [
                  LayerExportMapper.toJson(
                    LayerModel(
                      id: 'photo-$i',
                      type: LayerType.image,
                      position: Offset.zero,
                      width: 500,
                      height: 500 / [.75, 1.0, 4 / 3][i % 3],
                      imageUrl:
                          'asset:assets/snapfit_home_${['portrait', 'square', 'landscape'][i % 3]}.jpg',
                    ),
                    canvasSize: Size(500, 500 / [.75, 1.0, 4 / 3][i % 3]),
                    isCover: true,
                  ),
                ],
              }),
              createdAt: '2026-10-${15 - i}T10:00:00',
            ),
        ];
        var tab = 0;
        final favorites = <int>{};
        await mount(
          tester,
          Scaffold(
            body: SafeArea(
              child: StatefulBuilder(
                builder: (context, update) => HomeAlbumTabScreen(
                  allAlbums: albums,
                  currentUserId: 'qa',
                  albumTabIndex: tab,
                  favoriteAlbumIds: favorites,
                  onAlbumTabChanged: (value) => update(() => tab = value),
                  onToggleFavorite: (id) => update(() {
                    favorites.contains(id)
                        ? favorites.remove(id)
                        : favorites.add(id);
                  }),
                  onRefresh: () async {},
                ),
              ),
            ),
          ),
          size,
          dark,
        );
        await capture(tester, 'albums-$name');
        expect(
          find.byKey(const ValueKey('home-collection-album-1')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byTooltip('즐겨찾기').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('즐겨찾기').first);
        await tester.pump();
        expect(favorites, isNotEmpty);
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller
            ?.jumpTo(0);
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('home-album-collection')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scrollable.position.jumpTo(0);
        await tester.pump();
        await tester.ensureVisible(find.text('즐겨찾기'));
        await tester.tap(find.text('즐겨찾기'));
        await tester.pumpAndSettle();
        expect(tab, 3);
        expect(tester.takeException(), isNull);

        await mount(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TemplateCuration(templates: templates, onOpen: (_) {}),
              ),
            ),
          ),
          size,
          dark,
        );
        await capture(tester, 'curation-$name');
        final selection = curateTemplates(templates);
        final choose = find.byTooltip('다음 컬렉션');
        await tester.ensureVisible(choose);
        await tester.pumpAndSettle();
        await tester.tap(choose);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('curation-edition-${selection[1].id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('compact material selection $size dark=$dark', (
        tester,
      ) async {
        var opened = '';
        await mount(
          tester,
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: MaterialCuration(
                  selection: StoreCuration.materials,
                  items: [
                    for (final key in StoreCuration.materials.productKeys)
                      MaterialCurationItem(
                        key: key,
                        title: {
                          'frame:materialLinenOval': '리넨 타원 프레임',
                          'sticker:atelierColorSlips': '오려 붙인 컬러 종이',
                          'sticker:atelierRibbonPlate': '접은 실크 라벨',
                          'phrase:collage-atelier-ribbon': '아틀리에 리본 문구',
                        }[key]!,
                        type: key.startsWith('frame:') ? '프레임' : '소재',
                        preview: PointShopArtwork(productKey: key),
                        onOpen: () => opened = key,
                      ),
                  ],
                ),
              ),
            ),
          ),
          size,
          dark,
        );
        await capture(
          tester,
          'materials-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.tap(
          find.byKey(
            ValueKey(
              'material-curation-${StoreCuration.materials.productKeys.first}',
            ),
          ),
        );
        expect(opened, StoreCuration.materials.productKeys.first);
        await tester.drag(
          find.byKey(const ValueKey('material-curation-shelf')),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey(
              'material-curation-${StoreCuration.materials.productKeys.last}',
            ),
          ),
        );
        expect(opened, StoreCuration.materials.productKeys.last);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final ratio in [.75, 1.0, 4 / 3]) {
    testWidgets(
      'page focus keeps page, geometry and zoom through rotation $ratio',
      (tester) async {
        final controller = PageController(initialPage: 2);
        addTearDown(controller.dispose);
        var current = 2;
        final edits = <int>[];
        Widget gallery() => StatefulBuilder(
          builder: (context, update) => ReaderPageGallery(
            title: '우리의 기록',
            controller: controller,
            currentPage: current,
            pageCount: 8,
            onPageChanged: (value) => update(() => current = value),
            onMore: () {},
            onEdit: () => edits.add(current),
            pageBuilder: (_, i) => AspectRatio(
              aspectRatio: ratio,
              child: ColoredBox(
                color: Colors.white,
                child: Image.asset(
                  'assets/snapfit_home_${['portrait', 'square', 'landscape'][i % 3]}.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
        await mount(tester, gallery(), const Size(390, 844), false);
        await capture(tester, 'focus-${ratio.toStringAsFixed(2)}-portrait');
        expect(find.text('3 / 8'), findsOneWidget);
        final viewer = find.byType(InteractiveViewer).first;
        final p = tester.getCenter(viewer);
        await tester.tapAt(p);
        await tester.pump(const Duration(milliseconds: 90));
        await tester.tapAt(p);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 130));
        final transform = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!;
        expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
        expect(transform.value.getMaxScaleOnAxis(), lessThan(2));
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), closeTo(2, .001));
        await tester.tap(find.byTooltip('페이지 맞춤'));
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), closeTo(1, .001));
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pumpAndSettle();
        expect(current, 3);
        expect(find.text('4 / 8'), findsOneWidget);
        await tester.tap(find.byTooltip('현재 페이지 편집'));
        expect(edits, [3]);
        await tester.tap(find.byTooltip('페이지 확대'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(844, 390);
        tester.view.padding = const FakeViewPadding(
          left: 32,
          right: 36,
          bottom: 24,
        );
        await tester.pumpAndSettle();
        expect(current, 3);
        expect(controller.page, closeTo(3, .01));
        final rotated = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
            .transformationController!;
        expect(rotated.value.getMaxScaleOnAxis(), closeTo(2, .001));
        await tester.drag(
          find.byType(InteractiveViewer).first,
          const Offset(-80, 30),
        );
        await tester.pumpAndSettle();
        expect(
          current,
          3,
          reason: 'A zoomed page pans instead of changing pages',
        );
        await tester.tap(find.byTooltip('페이지 맞춤'));
        await tester.pumpAndSettle();
        await capture(tester, 'focus-${ratio.toStringAsFixed(2)}-landscape');
        await tester.tap(find.byTooltip('이전 페이지'));
        await tester.pumpAndSettle();
        expect(current, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

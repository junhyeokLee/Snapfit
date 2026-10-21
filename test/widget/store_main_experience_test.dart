import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_catalog_tile.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_curation.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_icon.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'home_screen_test.dart' show FakeAuthViewModel;
import '../support/store_catalog_navigation.dart';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _CountingAlbums extends HomeViewModel {
  _CountingAlbums(this.onLoad);
  final VoidCallback onLoad;
  @override
  List<Album> build() {
    onLoad();
    return [];
  }
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STORE_MAIN_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/store-main-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
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

  for (final (width, scale, proofVisible) in [
    (172.0, 1.0, true),
    (137.0, 1.0, false),
    (172.0, 1.8, false),
  ]) {
    testWidgets('catalog price remains legible width=$width scale=$scale', (
      tester,
    ) async {
      final template = publishedCreationTemplates.firstWhere(
        (template) => catalogEditorialSpread(template) != null,
      );
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final scaler = TextScaler.linear(scale);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pointShopCatalogProvider.overrideWith(
              (_) async => [
                PointShopProduct(
                  productKey: pointShopTemplateKey(template),
                  kind: 'template',
                  assetId: '${template.id}',
                  title: template.title,
                  pointPrice: 2500,
                  isActive: true,
                ),
              ],
            ),
            ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
          ],
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: scaler, disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: TemplateCatalogTile.extent(width, .92, scaler),
                  child: TemplateCatalogTile(
                    template: template,
                    onOpen: () {},
                    heroTag: 'price-proof',
                    scrollController: controller,
                    previewRatio: .92,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _paint(tester);
      expect(
        tester
            .widget<CreationCatalogCover>(find.byType(CreationCatalogCover))
            .showBookMaterial,
        isFalse,
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('2500P'),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        find.byType(CatalogSpreadPreview),
        proofVisible ? findsOneWidget : findsNothing,
      );
      if (proofVisible) {
        final cover = tester.getRect(
          find.byKey(ValueKey('template-cover-stage-${template.id}')),
        );
        final proof = tester.getRect(find.byType(CatalogSpreadPreview));
        expect(proof.top, greaterThan(cover.bottom));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (price, owned, active, label) in [
    (2500, false, true, '2500P'),
    (0, false, true, '무료'),
    (2500, true, true, '구매 완료'),
    (2500, false, false, '판매 준비 중'),
  ]) {
    testWidgets('custom price contrast preserves product state $label', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pointShopCatalogProvider.overrideWith(
              (_) async => [
                PointShopProduct(
                  productKey: 'template:poster-qa',
                  kind: 'template',
                  assetId: 'poster-qa',
                  title: '포스터 가격 확인',
                  pointPrice: price,
                  isActive: active,
                ),
              ],
            ),
            ownedPointShopKeysProvider.overrideWith(
              (_) async => owned ? {'template:poster-qa'} : <String>{},
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const PointShopProductBadge(
                productKey: 'template:poster-qa',
                compact: false,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(label)).style!.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, scale) in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(648, 320), 1.0),
    (const Size(844, 390), 1.0),
    (const Size(320, 568), 1.8),
    (const Size(648, 320), 1.8),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'albums open first, then store stays lazy and safe $size scale=$scale dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = size.width > size.height
              ? const FakeViewPadding(left: 32, right: 24, bottom: 24)
              : const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetPadding);
          var albumRequests = 0;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                homeViewModelProvider.overrideWith(
                  () => _CountingAlbums(() => albumRequests++),
                ),
                authViewModelProvider.overrideWith(
                  () => FakeAuthViewModel(
                    const UserInfo(
                      id: 'store-qa',
                      name: '디자인 확인',
                      provider: 'email',
                    ),
                  ),
                ),
                notificationUnreadCountProvider.overrideWith((_) async => 0),
                templateListProvider.overrideWith(
                  (_) async => publishedCreationTemplates,
                ),
                storeCurationsProvider.overrideWith(
                  (_) async => {
                    'templates': StoreCuration.templates,
                    'materials': StoreCuration.materials,
                  },
                ),
                pointShopCatalogProvider.overrideWith(
                  (_) async => [
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
                  (_) async => <String>{},
                ),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, __) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: RepaintBoundary(key: boundary, child: child!),
                  ),
                  home: const HomeScreen(),
                ),
              ),
            ),
          );
          await _paint(tester);
          expect(find.byType(StoreHubScreen), findsNothing);
          expect(find.byType(HomeEmptyState), findsOneWidget);
          expect(albumRequests, 1);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(HomeScreen)),
          );
          expect(container.read(homeUiStateProvider).bottomNavIndex, 0);
          final navigation = find.byType(HomeBottomNavigationBar);
          expect(
            find.descendant(
              of: navigation,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == '내 앨범' &&
                    widget.properties.selected == true,
              ),
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.descendant(of: navigation, matching: find.text('스토어')),
          );
          await _paint(tester);
          expect(find.byType(StoreHubScreen), findsOneWidget);
          expect(find.text('snapfit'), findsNothing);
          expect(find.byType(TabBar), findsNothing);
          expect(container.read(homeUiStateProvider).bottomNavIndex, 2);
          expect(
            find.byKey(const ValueKey('store-collection-spotlight')),
            findsOneWidget,
          );
          final icons = tester.widgetList<ExperienceIcon>(
            find.descendant(
              of: navigation,
              matching: find.byType(ExperienceIcon),
            ),
          );
          expect(icons.map((icon) => icon.name), [
            'BookOpen',
            'Layers2',
            'Bookmark',
            'UserRound',
          ]);
          expect(
            find.descendant(
              of: navigation,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == '스토어' &&
                    widget.properties.selected == true,
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final suffix =
              '${size.width.toInt()}-${dark ? 'dark' : 'light'}${scale > 1 ? '-large' : ''}';
          await _capture(tester, boundary, 'store-$suffix');
          final scroll = tester
              .widget<CustomScrollView>(find.byType(CustomScrollView).first)
              .controller!;
          scroll.jumpTo(0);
          await _paint(tester);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('store-topic-여행')),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('store-topic-여행')),
          );
          await _paint(tester);
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const ValueKey('store-topic-여행'))),
            alignment: .5,
          );
          await _paint(tester);
          await tester.tap(find.byKey(const ValueKey('store-topic-여행')));
          await _paint(tester);
          // The current shelf stays within the selected subject. Verify its
          // inputs and then mount actual result cards, rather than accepting an
          // empty lazy grid as a passing filter assertion.
          final curated = tester.widget<TemplateCuration>(
            find.byType(TemplateCuration),
          );
          expect(curated.templates, isNotEmpty);
          expect(
            curated.templates.every((template) => template.category == '여행'),
            isTrue,
          );
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('store-topic-여행')),
            180,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            tester
                .widget<ChoiceChip>(
                  find.byKey(const ValueKey('store-topic-여행')),
                )
                .selected,
            isTrue,
          );
          for (
            var attempt = 0;
            find.byType(TemplateCatalogTile).evaluate().isEmpty && attempt < 20;
            attempt++
          ) {
            await tester.drag(
              find
                  .descendant(
                    of: find.byType(CustomScrollView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
              const Offset(0, -180),
            );
            await _paint(tester);
          }
          await _paint(tester);
          expect(find.byType(TemplateCatalogTile), findsWidgets);
          expect(
            tester
                .widgetList<TemplateCatalogTile>(
                  find.byType(TemplateCatalogTile),
                )
                .every((tile) => tile.template.category == '여행'),
            isTrue,
          );
          await _capture(tester, boundary, 'browse-$suffix');
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.descendant(of: navigation, matching: find.text('내 앨범')),
          );
          await _paint(tester);
          expect(albumRequests, 1);
          expect(find.byType(HomeEmptyState), findsOneWidget);
          await tester.binding.handlePopRoute();
          await _paint(tester);
          expect(container.read(homeUiStateProvider).bottomNavIndex, 2);
          expect(find.byType(StoreScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('curation preserves admin order without commerce controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final editions = curateTemplates(
      publishedCreationTemplates,
    ).take(3).toList().reversed.toList();
    expect(editions.length, 3);
    var keys = editions.map(pointShopTemplateKey).toList();
    var enabled = true;
    int? opened;
    late StateSetter change;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pointShopCatalogProvider.overrideWith(
            (_) async => <PointShopProduct>[],
          ),
          ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  change = setState;
                  return TemplateCuration(
                    templates: publishedCreationTemplates,
                    selection: StoreCuration(
                      placement: 'templates',
                      title: '앨범 컬렉션',
                      subtitle: '',
                      productKeys: keys,
                      enabled: enabled,
                    ),
                    onOpen: (template) => opened = template.id,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await _paint(tester);
    final first = find.byKey(ValueKey('curation-edition-${editions.first.id}'));
    expect(find.byType(CatalogFavoriteButton), findsNothing);
    expect(find.byType(PointShopProductBadge), findsNothing);
    await tester.tap(first);
    expect(opened, editions.first.id);
    await tester.drag(
      find.byKey(const ValueKey('curation-pager')),
      const Offset(-390, 0),
    );
    await _paint(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('curation-position'))).data,
      '02 / 03',
    );
    await tester.tap(
      find.byKey(ValueKey('curation-edition-${editions[1].id}')),
    );
    expect(opened, editions[1].id);
    change(() => keys = [pointShopTemplateKey(editions.last)]);
    await _paint(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('curation-position'))).data,
      '01 / 01',
    );
    expect(
      find.byKey(ValueKey('curation-edition-${editions.last.id}')),
      findsOneWidget,
    );
    change(() => enabled = false);
    await _paint(tester);
    expect(find.byKey(const ValueKey('curation-pager')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('material storefront renders and filters $size dark=$dark', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              templateListProvider.overrideWith(
                (_) async => publishedCreationTemplates,
              ),
              storeCurationsProvider.overrideWith(
                (_) async => {
                  'materials': StoreCuration.materials,
                  'templates': StoreCuration.templates,
                },
              ),
              ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
              pointShopCatalogProvider.overrideWith(
                (_) async => [
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
            ],
            child: MaterialApp(
              theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
              home: const StoreHubScreen(),
            ),
          ),
        );
        await _paint(tester);
        await selectStoreCatalog(tester, 1);
        await _paint(tester);
        expect(
          find.byKey(const ValueKey('material-curation-shelf')),
          findsOneWidget,
        );
        expect(find.text('소재 컬렉션'), findsOneWidget);
        final curated = find.byType(MaterialCuration);
        expect(
          find.descendant(
            of: curated,
            matching: find.byType(CatalogFavoriteButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: curated,
            matching: find.byType(PointShopProductBadge),
          ),
          findsNothing,
        );
        await _capture(
          tester,
          boundary,
          'materials-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.drag(
          find.byKey(const ValueKey('material-catalog-scroll')),
          const Offset(0, -360),
        );
        await _paint(tester);
        expect(find.byType(MaterialCatalogTile), findsWidgets);
        await _capture(
          tester,
          boundary,
          'material-list-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

import '../support/store_detail_loading.dart';
// Chrome's test reporter drops framework details; retain explicit diagnostics.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import '../support/store_catalog_navigation.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_material_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_curation.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_editorial_list.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

class _MemoryFavorites implements CatalogFavoritesStorage {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async => _value = value;
}

class _LocalAuth extends AuthViewModel {
  @override
  UserInfo? build() => const UserInfo(
    id: 'catalog-layout-fixture',
    name: '디자인 확인',
    email: 'catalog@example.test',
    provider: 'email',
  );
}

class _EmptyHome extends HomeViewModel {
  @override
  Future<List<Album>> build() async => const [];
}

// Keep real bundled product identities and local thumbnails. Shape-only pages
// isolate layout from photo downloads, authentication and production services.
final _templates = [
  for (final template in bundledCreationTemplates.take(2))
    template.copyWith(
      templateJson: jsonEncode({
        'designWidth': 500,
        'designHeight': 500,
        'pages': [
          for (var page = 0; page < 3; page++) {'layers': <Object>[]},
        ],
        'variants': {
          for (final aspect in ['square', 'landscape'])
            aspect: {
              'designWidth': aspect == 'square' ? 500 : 650,
              'designHeight': 500,
              'pages': [
                for (var page = 0; page < 3; page++) {'layers': <Object>[]},
              ],
            },
        },
      }),
    ),
];

Widget _app(
  Widget screen, {
  bool dark = false,
  double scale = 1,
  bool curated = false,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    homeViewModelProvider.overrideWith(_EmptyHome.new),
    albumCreationDraftProvider.overrideWith((ref) async => null),
    authViewModelProvider.overrideWith(_LocalAuth.new),
    authUserIdProvider.overrideWith((ref) async => 'catalog-layout-fixture'),
    storeDiscoveryProvider.overrideWith((_) async => const {}),
    mockTemplateList(
      () async => curated ? publishedCreationTemplates : _templates,
    ),
    storeCurationsProvider.overrideWith(
      (ref) async => curated
          ? {
              'templates': StoreCuration.templates,
              'materials': StoreCuration.materials,
            }
          : <String, StoreCuration>{},
    ),
    pointShopCatalogProvider.overrideWith(
      (ref) async => [
        if (curated)
          for (final entry in pointShopLaunchPrices.entries)
            PointShopProduct(
              productKey: entry.key,
              kind: entry.key.split(':').first,
              assetId: entry.key.split(':').last,
              title: entry.key,
              pointPrice: entry.value.points,
              isActive: true,
            )
        else
          for (var index = 0; index < _templates.length; index++)
            PointShopProduct(
              productKey: pointShopTemplateKey(_templates[index]),
              kind: 'template',
              assetId: '${_templates[index].id}',
              title: _templates[index].title,
              pointPrice: index == 0 ? 0 : 2400,
              isActive: true,
            ),
        const PointShopProduct(
          productKey: 'sticker:fixture',
          kind: 'sticker',
          assetId: 'fixture',
          title: '테스트 소재',
          pointPrice: 600,
          isActive: true,
        ),
      ],
    ),
    ownedPointShopKeysProvider.overrideWith(
      (ref) async => {pointShopTemplateKey(_templates.first)},
    ),
    pointShopAccessGateProvider.overrideWithValue(
      (context, ref, {required productKey, required title}) async =>
          throw StateError(
            'Layout tests must never request access or spend points',
          ),
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, child) => MaterialApp(
      theme: SnapFitWebTheme.from(
        ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: screen,
    ),
  ),
);

Future<void> _mount(
  WidgetTester tester,
  Widget screen,
  Size size, {
  bool dark = false,
  double scale = 1,
  bool curated = false,
}) async {
  _diagnosticStage =
      'mount $size ${screen.runtimeType} dark=$dark scale=$scale';
  print('[web store layout] $_diagnosticStage');
  if (!_bodyErrorHandlerInstalled) {
    _bodyErrorHandlerInstalled = true;
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      print(
        '[web store body framework] $_diagnosticStage: ${details.exceptionAsString()}',
      );
      print(
        '[web store body context] ${details.context}\n${details.informationCollector?.call().join('\n')}',
      );
      previousHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousHandler);
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    _app(screen, dark: dark, scale: scale, curated: curated),
  );
  await settleStoreDetail(tester);
}

String _diagnosticStage = '';
bool _bodyErrorHandlerInstalled = false;

void _expectNoLayoutError(WidgetTester tester, String stage) {
  final error = tester.takeException();
  if (error != null) {
    // Chrome's Flutter test reporter otherwise drops the framework details.
    print('[web store layout] $stage: $error');
  }
  print('[web store error check] $stage error=$error');
  expect(error, isNull, reason: stage);
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
  setUp(() async {
    _bodyErrorHandlerInstalled = false;
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      print(
        '[web store framework] $_diagnosticStage: ${details.exceptionAsString()}',
      );
      if (details.context != null)
        print('[web store framework context] ${details.context}');
      previousHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousHandler);
    CatalogFavorites.instance = CatalogFavorites(storage: _MemoryFavorites());
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets(
    'real curated artwork remains usable across browser sizes and themes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(1440, 1000),
        const Size(844, 390),
        const Size(390, 844),
        const Size(320, 568),
      ]) {
        for (final dark in [false, true]) {
          await _mount(
            tester,
            const StoreHubScreen(),
            size,
            dark: dark,
            scale: size.width == 320 ? 1.8 : 1,
            curated: true,
          );
          final shelf = find.byKey(const ValueKey('store-featured-templates'));
          expect(shelf, findsOneWidget);
          expect(find.byType(TemplateCuration), findsNothing);
          final selected = StoreCuration.templates
              .resolve(publishedCreationTemplates, pointShopTemplateKey)
              .take(6)
              .toList();
          expect(selected, hasLength(6));
          expect(
            find.byKey(ValueKey('store-featured-template-${selected[1].id}')),
            findsNothing,
            reason: 'Only the selected book occupies the hero stage',
          );
          final firstProduct = find.byKey(
            ValueKey('store-featured-template-${selected.first.id}'),
          );
          expect(firstProduct, findsOneWidget);
          expect(
            tester
                .widget<Text>(
                  find.byKey(
                    ValueKey(
                      'store-featured-template-title-${selected.first.id}',
                    ),
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
          final firstAction = find.byKey(
            ValueKey('store-featured-open-${selected.first.id}'),
          );
          await tester.ensureVisible(firstAction);
          await settleStoreDetail(tester);
          expect(firstAction.hitTestable(), findsOneWidget);
          expect(
            find.byKey(ValueKey('store-featured-open-${selected.first.id}')),
            findsOneWidget,
          );
          _expectFeaturedPosition(tester, 1, selected.length);
          for (var index = 1; index < selected.length; index++) {
            final next = find.byKey(const ValueKey('store-featured-next'));
            await tester.ensureVisible(next);
            await settleStoreDetail(tester);
            await tester.tap(next);
            await settleStoreDetail(tester);
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
          }
          final previous = find.byKey(
            const ValueKey('store-featured-previous'),
          );
          await tester.ensureVisible(previous);
          await tester.tap(previous);
          await settleStoreDetail(tester);
          _expectFeaturedPosition(tester, selected.length - 1, selected.length);
          expect(
            find.byKey(
              ValueKey(
                'store-featured-open-${selected[selected.length - 2].id}',
              ),
            ),
            findsOneWidget,
          );
          final catalogScroll = find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first;
          for (
            var attempt = 0;
            find.byType(TemplateCatalogTile).evaluate().isEmpty && attempt < 40;
            attempt++
          ) {
            await tester.drag(catalogScroll, const Offset(0, -180));
            await settleStoreDetail(tester);
          }
          expect(find.byType(TemplateCatalogTile), findsWidgets);
          await tester.ensureVisible(find.byType(TemplateCatalogTile).first);
          await settleStoreDetail(tester);
          final catalog = tester.widget<TemplateEditorialList>(
            find.byType(TemplateEditorialList),
          );
          expect(catalog.compactStart, isTrue);
          expect(catalog.templates, isNotEmpty);
          expect(catalog.interlude, isA<StoreMaterialDiscovery>());
          final materials = find.byKey(
            const ValueKey('store-material-discovery'),
          );
          await tester.scrollUntilVisible(
            materials,
            220,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
            maxScrolls: 40,
          );
          expect(materials, findsOneWidget);
          expect(find.byKey(const ValueKey('curation-pager')), findsNothing);
          await tester.ensureVisible(find.byTooltip('꾸밈소재 모두 보기'));
          await settleStoreDetail(tester);
          await tester.tap(find.byTooltip('꾸밈소재 모두 보기'));
          await settleStoreDetail(tester);
          expect(find.byType(MaterialCatalogScreen), findsOneWidget);
          _expectNoLayoutError(
            tester,
            'featured products and materials $size dark=$dark',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
    skip: !kIsWeb,
  );

  storeDetailTestWidgets('web root opens the personal album workspace', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, const HomeScreen(), const Size(1440, 1000));
    expect(find.byType(WebAlbumLibraryScreen), findsOneWidget);
    expect(find.text('새 앨범 만들기'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('web-library-search')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  storeDetailTestWidgets(
    'production store hub searches, resets and switches catalogs without losing query',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalogLocation = WebAppRouteController(
        WebAppLocation.designs,
        pages: const {WebAppPage.designs, WebAppPage.materials},
      );
      addTearDown(catalogLocation.dispose);
      await _mount(
        tester,
        ValueListenableBuilder<WebAppLocation>(
          valueListenable: catalogLocation,
          builder: (_, location, _) => StoreHubScreen(
            initialMaterials: location == WebAppLocation.materials,
            onDepartmentChanged: (materials) => catalogLocation.update(
              materials ? WebAppLocation.materials : WebAppLocation.designs,
            ),
          ),
        ),
        const Size(1440, 1000),
      );
      final templateSearch = find
          .byKey(const ValueKey('web-catalog-search'))
          .hitTestable();
      await tester.enterText(templateSearch, '존재하지않는디자인999');
      await settleStoreDetail(tester);
      expect(find.text('조건에 맞는 디자인이 없어요'), findsOneWidget);
      await tester.tap(find.text('검색·필터 초기화'));
      await settleStoreDetail(tester);
      expect(
        tester.widget<TextField>(templateSearch).controller!.text,
        isEmpty,
      );
      await tester.tap(
        find.byKey(const ValueKey('web-catalog-price-filter')).hitTestable(),
      );
      await settleStoreDetail(tester);
      await tester.tap(find.text('보유').last);
      await settleStoreDetail(tester);
      expect(find.text('1개의 템플릿'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('web-catalog-reset')).hitTestable(),
      );
      await settleStoreDetail(tester);
      await tester.enterText(templateSearch, _templates.first.title);
      await settleStoreDetail(tester);
      await selectStoreCatalog(tester, 1);
      expect(catalogLocation.value, WebAppLocation.materials);
      await tester.enterText(
        find.byKey(const ValueKey('web-catalog-search')).hitTestable(),
        '소재없음999',
      );
      await settleStoreDetail(tester);
      expect(find.text('조건에 맞는 소재가 없어요.'), findsOneWidget);
      await tester.tap(find.text('필터 초기화'));
      await settleStoreDetail(tester);
      // A browser Back request updates the mounted hub rather than remounting it.
      catalogLocation.update(WebAppLocation.designs);
      await settleStoreDetail(tester);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('web-catalog-search')).hitTestable(),
            )
            .controller!
            .text,
        _templates.first.title,
      );
      catalogLocation.update(WebAppLocation.materials);
      await settleStoreDetail(tester);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('web-catalog-search')).hitTestable(),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  storeDetailTestWidgets(
    'production template and material details retain accessible use controls at all viewport sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(1440, 1000),
        const Size(1024, 800),
        const Size(768, 800),
        const Size(390, 760),
        const Size(320, 568),
        const Size(1440, 420),
      ]) {
        for (final material in [false, true]) {
          try {
            final screen = material
                ? MaterialDetailScreen(
                    productKey: 'sticker:fixture',
                    favoriteKey: 'sticker:fixture',
                    title: '테스트 소재',
                    type: '스티커',
                    preview: (_) => const Icon(Icons.favorite, size: 72),
                  )
                : TemplateDetailScreen(template: _templates.first);
            await _mount(
              tester,
              screen,
              size,
              dark: size.width == 320,
              scale: size.width <= 390 ? 2 : 1,
            );
            _expectNoLayoutError(
              tester,
              '$size material=$material initial layout',
            );
            final action = find.byKey(
              ValueKey(material ? 'material-access' : 'template-detail-use'),
            );
            if (action.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                action,
                200,
                scrollable: find
                    .descendant(
                      of: find.byKey(
                        const ValueKey('web-design-detail-stacked'),
                      ),
                      matching: find.byType(Scrollable),
                    )
                    .first,
                maxScrolls: 30,
              );
            }
            await tester.ensureVisible(action);
            await settleStoreDetail(tester);
            print(
              '[web store action] $size material=$material found=${action.evaluate().length} hit=${action.hitTestable().evaluate().length} rect=${tester.getRect(action)}',
            );
            expect(
              action.hitTestable(),
              findsOneWidget,
              reason: '$size material=$material action',
            );
            expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
            _expectNoLayoutError(
              tester,
              '$size material=$material scrolled layout',
            );
          } catch (error, stack) {
            print(
              '[web store detail failure] $size material=$material: $error\n$stack',
            );
            rethrow;
          }
        }
      }
    },
    skip: !kIsWeb,
  );

  storeDetailTestWidgets(
    'production catalog remains scrollable on narrow and short windows',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(1024, 720),
        const Size(768, 800),
        const Size(390, 760),
        const Size(320, 568),
        const Size(1440, 420),
      ]) {
        await _mount(
          tester,
          const StoreHubScreen(),
          size,
          dark: size.width == 320,
          scale: size.width <= 390 ? 2 : 1,
        );
        _expectNoLayoutError(tester, '$size templates');
        await selectStoreCatalog(tester, 1);
        _expectNoLayoutError(tester, '$size materials');
        final scroll = tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('material-catalog-scroll')),
            )
            .controller!;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await settleStoreDetail(tester);
        _expectNoLayoutError(tester, '$size materials scrolled');
      }
    },
    skip: !kIsWeb,
  );
}

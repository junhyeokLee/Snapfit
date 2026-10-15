import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_artwork.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_purchase_sheet.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_album_picker.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Shop extends Mock implements PointShopRepository {}

void main() {
  _PaintBinding();
  const material = 'frame:materialLinenOval', materialTitle = '리넨 자수 타원';
  final template = publishedCreationTemplates.firstWhere(
    (t) =>
        t.isPremium &&
        templateVisualMaterialKeys(
          jsonDecode(t.templateJson!),
        ).any((key) => key.startsWith('frame:')),
  );
  final boundary = GlobalKey();
  late List<AlbumPage> pages;
  late List<Album> albums;
  final prices = [
    for (final entry in pointShopLaunchPrices.entries)
      PointShopProduct(
        productKey: entry.key,
        kind: entry.key.split(':').first,
        assetId: entry.key.split(':').last,
        title: entry.key,
        pointPrice: entry.value.points,
        isActive: true,
      ),
  ];
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    final document = jsonDecode(template.templateJson!) as Map<String, dynamic>;
    pages = [
      for (final (index, page) in templateDocumentPages(
        document,
      ).take(25).indexed)
        AlbumPage(
          id: 'qa-page-$index',
          pageIndex: index,
          isCover: index == 0,
          backgroundColor: 0xFFE9EFEA,
          layers: DataTemplateEngine.buildLayersFromJson({
            'strictLayout': true,
            'designWidth': 500,
            'designHeight': 500,
            'layers': page['layers'],
          }, const Size(500, 500)),
        ),
    ];
    albums = [
      for (final (index, ratio) in [.75, 1.0, 4 / 3].indexed)
        Album(
          id: index + 1,
          userId: 'alice',
          title: '${template.title} ${index + 1}',
          ratio: '$ratio',
          targetPages: 24,
          totalPages: 24,
          coverLayersJson: jsonEncode({
            'pages': [
              for (final page in pages)
                {
                  'index': page.pageIndex,
                  'isCover': page.isCover,
                  'backgroundColor': page.backgroundColor,
                  'layers': [
                    for (final layer in page.layers)
                      LayerExportMapper.toJson(
                        layer,
                        canvasSize: const Size(500, 500),
                        isCover: page.isCover,
                      ),
                  ],
                },
            ],
          }),
        ),
    ];
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());
  Finder key(String id) => find.byKey(ValueKey(id));
  void size(WidgetTester tester, Size extent, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = extent;
    tester.view.padding = extent.width > extent.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard == 0 ? 24 : 0)
        : FakeViewPadding(top: 24, bottom: keyboard == 0 ? 34 : 0);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> paint(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
    double scale = 1.3,
    PointShopAccessGate? gate,
    Set<String> owned = const {},
    Completer<PointShopAccess>? pendingQuote,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final repo = MockAlbumRepository(), templates = MockTemplateRepository();
    stubGetTemplates(templates, publishedCreationTemplates);
    final shop = _Shop();
    when(() => shop.currentUserId).thenReturn('alice');
    when(() => shop.getAccess(any())).thenAnswer((invocation) async {
      if (pendingQuote != null) return pendingQuote.future;
      final productKey = invocation.positionalArguments.first as String;
      return PointShopAccess(
        productKey: productKey,
        available: true,
        isFree: false,
        owned: true,
        remainingBalance: 2000,
      );
    });
    for (final album in albums) {
      when(() => repo.fetchAlbum('${album.id}')).thenAnswer((_) async => album);
      when(() => repo.lockAlbum(album.id)).thenAnswer((_) async {});
      when(() => repo.unlockAlbum(album.id)).thenAnswer((_) async {});
    }
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          templateRepositoryProvider.overrideWithValue(templates),
          templateListProvider.overrideWith(
            (ref) async => publishedCreationTemplates,
          ),
          albumCreationCatalogProvider.overrideWith(
            (ref) => Stream.value(publishedCreationTemplates),
          ),
          pointShopCatalogProvider.overrideWith((ref) async => prices),
          ownedPointShopKeysProvider.overrideWith((ref) async => owned),
          if (pendingQuote == null)
            pointShopAccessGateProvider.overrideWithValue(
              gate ??
                  (context, ref, {required productKey, required title}) async =>
                      true,
            ),
          pointShopRepositoryProvider.overrideWithValue(shop),
          albumRepositoryProvider.overrideWithValue(repo),
          homeViewModelProvider.overrideWith(() => FakeHomeViewModel(albums)),
          albumPersistenceServiceProvider.overrideWithValue(
            FakeAlbumPersistenceService(),
          ),
          storageServiceProvider.overrideWithValue(FakeStorageService()),
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(id: 'alice', name: '시안 확인', provider: 'kakao'),
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, body) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(key: boundary, child: body!),
            ),
            home: child,
          ),
        ),
      ),
    );
    await paint(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await paint(tester);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await paint(tester);
    await tester.tap(finder);
    await paint(tester);
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    Size extent,
    bool dark,
  ) async {
    await paint(tester);
    expect(tester.takeException(), isNull, reason: id);
    if (!const bool.fromEnvironment('STORE_WORKSHOP_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/$id-${extent.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget detail() => MaterialDetailScreen(
    productKey: material,
    favoriteKey: material,
    title: materialTitle,
    type: '프레임',
    preview: (_) => const PointShopArtwork(productKey: material),
  );
  Future<void> purchase(
    WidgetTester tester,
    String productKey,
    String title,
    Size extent,
    bool dark,
    String id, {
    bool receipt = false,
    bool insufficient = false,
    double scale = 1.3,
    bool record = true,
  }) async {
    await mount(tester, const Scaffold(), dark: dark, scale: scale);
    final context = tester.element(find.byType(Scaffold));
    final price = pointShopLaunchPrices[productKey]!.points;
    const balance = 6000;
    final access = PointShopAccess(
      productKey: productKey,
      title: title,
      available: true,
      isFree: false,
      owned: false,
      pointPrice: price,
      remainingBalance: insufficient ? 20 : balance,
    );
    final result = receipt
        ? showPointShopPurchaseReceipt(
            context,
            access: access,
            title: title,
            purchase: PointShopPurchase(
              productKey: productKey,
              owned: true,
              isFree: false,
              chargedPoints: price,
              remainingBalance: balance - price,
              alreadyOwned: false,
            ),
          )
        : showPointShopPurchaseSheet(context, access: access, title: title);
    if (record) {
      await capture(tester, id, extent, dark);
    } else {
      await paint(tester);
      expect(tester.takeException(), isNull);
    }
    final rect = tester.getRect(key('shop-purchase-action'));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        extent.height - (extent.width > extent.height ? 24 : 34),
      ),
    );
    await tap(tester, key('shop-purchase-action'));
    expect(
      await result,
      receipt
          ? true
          : insufficient
          ? PointShopPurchaseAction.topUp
          : PointShopPurchaseAction.buy,
    );
  }

  for (final extent in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'complete shop artwork purchase and use journey $extent dark=$dark',
        (tester) async {
          reset(tester);
          size(tester, extent);
          await mount(tester, const StoreHubScreen(), dark: dark);
          await capture(tester, 'shop-atelier-templates', extent, dark);
          await tap(tester, find.text('꾸밈소재'));
          await capture(tester, 'shop-atelier-materials', extent, dark);
          await tap(tester, find.text('템플릿').first);
          await tap(tester, find.text('검색'));
          await tester.enterText(find.byType(TextField), '바다');
          final keyboard = extent.width > extent.height ? 140.0 : 260.0;
          size(tester, extent, keyboard: keyboard);
          await capture(tester, 'shop-atelier-search', extent, dark);
          size(tester, extent);
          await mount(
            tester,
            TemplateDetailScreen(template: template),
            dark: dark,
          );
          await capture(tester, 'shop-atelier-template-cover', extent, dark);
          await tap(tester, find.byTooltip('다음 펼침면'));
          expect(key('template-book-spread-1'), findsWidgets);
          await capture(tester, 'shop-atelier-template-spread', extent, dark);
          await tester.ensureVisible(key('template-purchase-overview'));
          await paint(tester);
          await capture(tester, 'shop-atelier-template-usage', extent, dark);
          await tap(tester, key('template-reuse-details'));
          await capture(
            tester,
            'shop-atelier-included-materials',
            extent,
            dark,
          );
          await mount(
            tester,
            TemplateDetailScreen(template: template),
            dark: dark,
          );
          await tap(tester, key('template-detail-use'));
          if (key('template-edition-sheet').evaluate().isNotEmpty) {
            await capture(tester, 'shop-atelier-edition', extent, dark);
            await tap(tester, key('template-edition-continue'));
          }
          expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
          await capture(tester, 'shop-atelier-creation', extent, dark);
          await purchase(
            tester,
            pointShopTemplateKey(template),
            template.title,
            extent,
            dark,
            'shop-atelier-template-purchase',
          );
          await purchase(
            tester,
            pointShopTemplateKey(template),
            template.title,
            extent,
            dark,
            'shop-atelier-template-receipt',
            receipt: true,
          );
          await mount(tester, detail(), dark: dark);
          await capture(tester, 'shop-atelier-material-original', extent, dark);
          await tap(tester, find.text('앨범 적용 예시'));
          expect(find.byType(MaterialApplicationPreview), findsOneWidget);
          await capture(
            tester,
            'shop-atelier-material-application',
            extent,
            dark,
          );
          await tap(tester, key('material-access'));
          expect(find.byType(MaterialAlbumPicker), findsOneWidget);
          await capture(tester, 'shop-atelier-album-picker', extent, dark);
          await tap(tester, find.byTooltip('닫기').last);
          await mount(tester, const Scaffold(), dark: dark);
          final context = tester.element(find.byType(Scaffold));
          final page = showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            constraints: const BoxConstraints(maxWidth: 760),
            builder: (_) => MaterialPagePicker(
              title: materialTitle,
              productKey: material,
              pages: pages,
              ratio: 1,
              albumTitle: template.title,
            ),
          );
          await capture(tester, 'shop-atelier-page-picker', extent, dark);
          await tap(tester, key('material-page-1'));
          expect(await page, 1);
          await purchase(
            tester,
            material,
            materialTitle,
            extent,
            dark,
            'shop-atelier-material-purchase',
          );
          await purchase(
            tester,
            material,
            materialTitle,
            extent,
            dark,
            'shop-atelier-material-receipt',
            receipt: true,
          );
          await purchase(
            tester,
            material,
            materialTitle,
            extent,
            dark,
            'shop-atelier-insufficient',
            insufficient: true,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final extent in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large type, focused search and chosen spread survive rotation $extent',
      (tester) async {
        reset(tester);
        size(tester, extent);
        await mount(tester, const StoreHubScreen(), scale: 1.8, dark: true);
        await tap(tester, find.text('검색'));
        await tester.enterText(find.byType(TextField), '웨딩');
        await paint(tester);
        final input = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(input.widget.focusNode.hasFocus, true);
        final rotated = extent.width > extent.height
            ? const Size(390, 844)
            : const Size(648, 320);
        size(
          tester,
          rotated,
          keyboard: rotated.width > rotated.height ? 140 : 260,
        );
        await paint(tester);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(input),
        );
        expect(input.widget.controller.text, '웨딩');
        expect(input.widget.focusNode.hasFocus, true);
        await tester.ensureVisible(find.byType(TextField));
        await paint(tester);
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(
            rotated.height - (rotated.width > rotated.height ? 140 : 260),
          ),
        );
        expect(key('store-collection-spotlight'), findsNothing);
        expect(tester.takeException(), isNull);
        size(tester, extent);
        await mount(
          tester,
          TemplateDetailScreen(template: template),
          scale: 1.8,
          dark: true,
        );
        await tap(tester, find.byTooltip('다음 펼침면'));
        size(tester, rotated);
        await paint(tester);
        expect(key('template-book-spread-1'), findsWidgets);
        expect(tester.takeException(), isNull);
        size(tester, extent);
        await mount(tester, detail(), scale: 1.8, dark: true);
        await tap(tester, find.text('앨범 적용 예시'));
        size(tester, rotated);
        await paint(tester);
        expect(find.byType(MaterialApplicationPreview), findsOneWidget);
        expect(tester.takeException(), isNull);
        size(tester, extent);
        await purchase(
          tester,
          pointShopTemplateKey(template),
          template.title,
          extent,
          true,
          'large-type-quote',
          scale: 1.8,
          record: false,
        );
      },
    );
  }
  testWidgets(
    'a hidden material detail rejects late ownership and double use',
    (tester) async {
      reset(tester);
      size(tester, const Size(390, 844));
      final granted = Completer<bool>();
      var requests = 0;
      await mount(
        tester,
        detail(),
        gate: (context, ref, {required productKey, required title}) {
          requests++;
          return granted.future;
        },
      );
      await tap(tester, key('material-access'));
      await tap(tester, key('material-access'));
      expect(requests, 1);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final overlay = navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('다른 화면'))),
      );
      await paint(tester);
      granted.complete(true);
      await paint(tester);
      expect(find.byType(MaterialAlbumPicker), findsNothing);
      navigator.pop();
      await overlay;
      await paint(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a hidden template detail never opens creation after late access',
    (tester) async {
      reset(tester);
      size(tester, const Size(648, 320));
      final granted = Completer<bool>();
      await mount(
        tester,
        TemplateDetailScreen(template: template),
        gate: (context, ref, {required productKey, required title}) =>
            granted.future,
      );
      await tap(tester, key('template-detail-use'));
      if (key('template-edition-continue').evaluate().isNotEmpty) {
        await tap(tester, key('template-edition-continue'));
      }
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final overlay = navigator.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('다른 화면'))),
      );
      await paint(tester);
      granted.complete(true);
      await paint(tester);
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      navigator.pop();
      await overlay;
      await paint(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('real purchase gate rejects a late quote on another route', (
    tester,
  ) async {
    reset(tester);
    size(tester, const Size(390, 844));
    final quote = Completer<PointShopAccess>();
    await mount(tester, detail(), pendingQuote: quote);
    await tap(tester, key('material-access'));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final other = navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('다른 화면'))),
    );
    await paint(tester);
    quote.complete(
      const PointShopAccess(
        productKey: material,
        title: materialTitle,
        available: true,
        isFree: false,
        owned: false,
        pointPrice: 300,
        remainingBalance: 6000,
      ),
    );
    await paint(tester);
    expect(find.byType(PointShopPurchaseSheet), findsNothing);
    expect(find.byType(MaterialAlbumPicker), findsNothing);
    expect(find.text('다른 화면'), findsOneWidget);
    navigator.pop();
    await other;
    await paint(tester);
    expect(tester.takeException(), isNull);
  });
}

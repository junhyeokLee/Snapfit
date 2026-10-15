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
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/order_album_artwork.dart';
import 'package:snap_fit/features/profile/presentation/widgets/personal_collection_shelf.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Orders extends Mock implements OrderRepository {}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final templates = [
    for (final category in ['여행', '웨딩', '성장·육아'])
      publishedCreationTemplates.firstWhere(
        (t) => t.category == category && t.isPremium,
      ),
  ];
  final ownedKeys = {
    for (final template in templates) pointShopTemplateKey(template),
    'frame:materialLinenOval',
    'sticker:studioRoseSilk',
    'sticker:studioBlueFibre',
    'phrase:collage-atelier-ribbon',
  };
  late List<Album> albums;
  late List<OrderHistoryItem> orders;
  late _Orders repository;
  final queries = <List<String>>[];
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List)
        loader.addFont(rootBundle.load(file['asset'] as String));
      await loader.load();
    }
    albums = [
      for (var i = 0; i < 6; i++)
        (() {
          final template = templates[i % 3];
          final doc =
              jsonDecode(template.templateJson!) as Map<String, dynamic>;
          const canvas = Size(500, 500);
          final pages = templateDocumentPages(doc).take(3).toList();
          final layers = [
            for (final page in pages)
              DataTemplateEngine.buildLayersFromJson({
                'strictLayout': true,
                'designWidth': 500,
                'designHeight': 500,
                'layers': page['layers'],
              }, canvas),
          ];
          return Album(
            id: i + 1,
            userId: i == 5 ? 'friend' : 'qa',
            title: template.title,
            ratio: '${[.75, 1.0, 4 / 3][i % 3]}',
            targetPages: 24,
            totalPages: i >= 3 ? 24 : 2,
            createdAt:
                '2026-10-${(15 - i).toString().padLeft(2, '0')}T10:00:00',
            coverLayersJson: jsonEncode({
              'pages': [
                for (var p = 0; p < pages.length; p++)
                  {
                    'index': p,
                    'isCover': p == 0,
                    'backgroundColor': 0xFFF4F3ED,
                    'layers': [
                      for (final layer in layers[p])
                        LayerExportMapper.toJson(
                          layer,
                          canvasSize: canvas,
                          isCover: p == 0,
                        ),
                    ],
                  },
              ],
            }),
          );
        })(),
    ];
    orders = [
      for (var i = 0; i < 3; i++)
        OrderHistoryItem(
          orderId: 'SNAPFIT-LOCAL-REVIEW-$i',
          albumId: i + 1,
          title: albums[i].title,
          amount: 59900,
          pageCount: 24,
          status: ['SHIPPING', 'IN_PRODUCTION', 'DELIVERED'][i],
          statusLabel: ['배송중', '제작중', '배송완료'][i],
          progress: [.75, .5, 1.0][i],
          orderedAt: DateTime(2026, 10, 14 - i),
          recipientName: '검토용 수령인',
          recipientPhone: '010-0000-0000',
          zipCode: '00000',
          addressLine1: '검토용 주소 · 실제 배송 정보가 아닙니다',
          paymentMethod: '테스트 결제',
          courier: i == 0 ? 'CJ대한통운' : null,
          trackingNumber: i == 0 ? '000000000000' : null,
          paymentConfirmedAt: DateTime(2026, 10, 14 - i, 10),
          printAcceptedAt: DateTime(2026, 10, 14 - i, 11),
          shippedAt: i == 0 ? DateTime(2026, 10, 15, 10) : null,
          printProductSnapshot: PrintProduct.forId(
            'REDP_250X200_SOFT',
          )!.toJson(),
          pricingVersion: 'PRINT_REDP_MULTISIZE_V2',
        ),
    ];
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'album_favorite_ids_v1': ['1'],
    });
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    await CatalogFavorites.instance.toggle(
      CatalogFavoriteKeys.template(templates.first.id),
    );
  });
  tearDown(() => CatalogFavorites.instance.dispose());
  Finder key(String name) => find.byKey(ValueKey(name));
  void viewport(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard == 0 ? 24 : 0)
        : FakeViewPadding(top: 24, bottom: keyboard == 0 ? 34 : 0);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> paint(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
    double scale = 1.3,
    Set<String>? owned,
    Future<Set<String>> Function()? loadOwned,
    bool emptyOrders = false,
    bool failOrders = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    repository = _Orders();
    queries.clear();
    when(
      () => repository.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((invocation) async {
      if (failOrders) throw StateError('local QA failure');
      final statuses = invocation.namedArguments[#statuses] as List<String>;
      queries.add(List.of(statuses));
      final items = emptyOrders
          ? <OrderHistoryItem>[]
          : orders
                .where((o) => statuses.isEmpty || statuses.contains(o.status))
                .toList();
      return OrderPageResult(
        items: items,
        page: 0,
        size: 20,
        totalPages: 1,
        totalElements: items.length,
        hasNext: false,
      );
    });
    when(() => repository.fetchMyOrders()).thenAnswer((_) async => orders);
    when(() => repository.fetchMyPrintOrderProgress(any())).thenAnswer(
      (invocation) async => PrintOrderProgress(
        orderId: invocation.positionalArguments.first as String,
        customerStage: 'SHIPPING',
        preflightPassed: true,
        requiresAction: false,
        filesReadyAt: DateTime(2026, 10, 14),
        fileCheckedAt: DateTime(2026, 10, 14, 11),
        productionStartedAt: DateTime(2026, 10, 14, 12),
      ),
    );
    final albumsRepo = MockAlbumRepository();
    when(() => albumsRepo.fetchMyAlbums()).thenAnswer((_) async => albums);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              const UserInfo(
                id: 'qa',
                name: '스냅핏',
                email: 'snapfit@example.com',
                provider: 'EMAIL',
              ),
            ),
          ),
          homeViewModelProvider.overrideWith(() => FakeHomeViewModel(albums)),
          albumRepositoryProvider.overrideWithValue(albumsRepo),
          ownedPointShopKeysProvider.overrideWith(
            (ref) => loadOwned?.call() ?? Future.value(owned ?? ownedKeys),
          ),
          pointShopCatalogProvider.overrideWith(
            (ref) async => [
              for (final k in ownedKeys)
                PointShopProduct(
                  productKey: k,
                  kind: k.split(':').first,
                  assetId: k.split(':').last,
                  title: k,
                  pointPrice: 300,
                  isActive: true,
                ),
            ],
          ),
          templateListProvider.overrideWith(
            (ref) async => publishedCreationTemplates,
          ),
          myPointBalanceProvider.overrideWith((ref) async => 2400),
          myStorageQuotaProvider.overrideWith(
            (ref) async => StorageQuotaStatus.fromJson({}),
          ),
          myOrderSummaryProvider.overrideWith(
            (ref) async => OrderSummaryResult.fromJson({}),
          ),
          myOrderStatusBadgesProvider.overrideWith(
            (ref) async => const OrderStatusBadges.zero(),
          ),
          pointShopAdminAccessProvider.overrideWithValue(false),
          orderRepositoryProvider.overrideWithValue(repository),
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
            home: page,
          ),
        ),
      ),
    );
    await paint(tester);
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final candidates =
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .evaluate()
              .where((element) {
                final state =
                    (element as StatefulElement).state as ScrollableState;
                return state.position.hasContentDimensions &&
                    state.position.maxScrollExtent > 0;
              })
              .toList()
            ..sort(
              (a, b) => ((a as StatefulElement).state as ScrollableState)
                  .position
                  .maxScrollExtent
                  .compareTo(
                    ((b as StatefulElement).state as ScrollableState)
                        .position
                        .maxScrollExtent,
                  ),
            );
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byWidget(candidates.last.widget),
        maxScrolls: 50,
      );
    }
    await tester.ensureVisible(finder);
    await paint(tester);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await paint(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await paint(tester);
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    Size size,
    bool dark,
  ) async {
    await paint(tester);
    expect(tester.takeException(), isNull, reason: id);
    if (!const bool.fromEnvironment('PERSONAL_WORKSHOP_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/$id-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  AlbumCategoryScreen albumPage() => AlbumCategoryScreen(
    category: AlbumCategory.recent,
    initialAlbums: albums,
    currentUserId: 'qa',
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'personal collection, reuse and order journey $size dark=$dark',
        (tester) async {
          reset(tester);
          viewport(tester, size);
          await mount(tester, const MyPageScreen(), dark: dark);
          await capture(tester, 'personal-atelier-profile', size, dark);
          await reveal(tester, key('profile-design-collection'));
          await paint(tester);
          await capture(tester, 'personal-atelier-profile-designs', size, dark);
          await tap(tester, find.byTooltip('내 보관함 모두 보기'));
          expect(find.byType(MaterialCatalogScreen), findsOneWidget);
          await capture(tester, 'personal-atelier-library', size, dark);
          await tap(tester, key('library-type-템플릿'));
          await capture(tester, 'personal-atelier-templates', size, dark);
          await tap(
            tester,
            key('material-item-${pointShopTemplateKey(templates.first)}'),
          );
          expect(find.byType(TemplateDetailScreen), findsOneWidget);
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.pop();
          await paint(tester);
          expect(find.byType(MaterialCatalogScreen), findsOneWidget);
          await tap(tester, key('library-type-프레임'));
          await capture(tester, 'personal-atelier-materials', size, dark);
          await tap(tester, key('library-type-전체'));
          await tap(tester, find.text('즐겨찾기'));
          await capture(tester, 'personal-atelier-favorites', size, dark);
          expect(
            key('material-item-${pointShopTemplateKey(templates.first)}'),
            findsOneWidget,
          );
          await tap(tester, find.text('검색'));
          final search = find.byType(TextField);
          await tester.enterText(search, '없는 기록');
          await tap(tester, search);
          viewport(
            tester,
            size,
            keyboard: size.width > size.height ? 140 : 260,
          );
          await paint(tester);
          await tester.ensureVisible(search);
          await paint(tester);
          await capture(tester, 'personal-atelier-library-search', size, dark);
          FocusManager.instance.primaryFocus?.unfocus();
          viewport(tester, size);
          await mount(tester, albumPage(), dark: dark);
          await capture(tester, 'personal-atelier-albums', size, dark);
          await tap(tester, find.text('완료'));
          await capture(
            tester,
            'personal-atelier-albums-completed',
            size,
            dark,
          );
          await tap(tester, find.text('즐겨찾기'));
          await capture(
            tester,
            'personal-atelier-albums-favorites',
            size,
            dark,
          );
          await tap(tester, find.byTooltip('앨범 검색'));
          await tester.enterText(find.byType(TextField), '찾을 수 없는 기록');
          viewport(
            tester,
            size,
            keyboard: size.width > size.height ? 140 : 260,
          );
          await paint(tester);
          await tester.ensureVisible(find.byType(TextField));
          await capture(tester, 'personal-atelier-albums-search', size, dark);
          FocusManager.instance.primaryFocus?.unfocus();
          viewport(tester, size);
          await mount(tester, const OrderHistoryScreen(), dark: dark);
          await capture(tester, 'personal-atelier-orders', size, dark);
          await tap(tester, key('personal-order-${orders.first.orderId}'));
          await capture(tester, 'personal-atelier-order-detail', size, dark);
          expect(find.textContaining('주문 당시 인쇄본과 다를 수 있어요'), findsOneWidget);
          await reveal(tester, find.text('배송 조회'));
          await paint(tester);
          await capture(tester, 'personal-atelier-order-tracking', size, dark);
          await tap(tester, find.byTooltip('닫기'));
          await mount(
            tester,
            const MaterialCatalogScreen(library: true),
            dark: dark,
            owned: {},
          );
          await capture(tester, 'personal-atelier-library-empty', size, dark);
          await mount(
            tester,
            const MaterialCatalogScreen(library: true),
            dark: dark,
            loadOwned: () =>
                Future.error(StateError('local ownership failure')),
          );
          await capture(tester, 'personal-atelier-library-error', size, dark);
          await mount(
            tester,
            const OrderHistoryScreen(),
            dark: dark,
            emptyOrders: true,
          );
          await capture(tester, 'personal-atelier-orders-empty', size, dark);
          await mount(
            tester,
            const OrderHistoryScreen(),
            dark: dark,
            failOrders: true,
          );
          await capture(tester, 'personal-atelier-orders-error', size, dark);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'collection focus, filters and large type survive rotation $size',
      (tester) async {
        reset(tester);
        viewport(tester, size);
        await mount(
          tester,
          const MaterialCatalogScreen(library: true),
          scale: 1.8,
        );
        await tap(tester, key('library-type-프레임'));
        await tap(tester, find.text('검색'));
        await tester.enterText(find.byType(TextField), '리넨');
        await tap(tester, find.byType(TextField));
        viewport(tester, size, keyboard: size.width > size.height ? 140 : 260);
        await paint(tester);
        final input = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final other = size.width > size.height
            ? const Size(390, 844)
            : const Size(648, 320);
        viewport(
          tester,
          other,
          keyboard: other.width > other.height ? 140 : 260,
        );
        await paint(tester);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(input),
        );
        expect(input.widget.focusNode.hasFocus, isTrue);
        expect(input.widget.controller.text, '리넨');
        expect(find.text('1개 항목'), findsOneWidget);
        expect(tester.takeException(), isNull);
        FocusManager.instance.primaryFocus?.unfocus();
        viewport(tester, size);
        await mount(tester, albumPage(), scale: 1.8);
        await tap(tester, find.text('완료'));
        viewport(tester, other);
        await paint(tester);
        expect(key('personal-record-4'), findsOneWidget);
        expect(key('personal-record-1'), findsNothing);
        await mount(tester, const OrderHistoryScreen(), scale: 1.8);
        await tap(tester, key('personal-order-${orders.first.orderId}'));
        final info = find
            .descendant(
              of: find.byType(OrderDetailWorkspace),
              matching: find.byType(Scrollable),
            )
            .first;
        final scrollState = tester.state<ScrollableState>(info);
        await reveal(tester, find.text('배송 조회'));
        await paint(tester);
        viewport(tester, size);
        await paint(tester);
        final rotated = find
            .descendant(
              of: find.byType(OrderDetailWorkspace),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(tester.state<ScrollableState>(rotated), same(scrollState));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'profile only previews confirmed purchases and opens their type',
    (tester) async {
      reset(tester);
      viewport(tester, const Size(390, 844));
      await mount(
        tester,
        const MyPageScreen(),
        owned: {'frame:materialLinenOval'},
      );
      await reveal(tester, key('profile-design-collection'));
      expect(key('personal-design-frame:materialLinenOval'), findsOneWidget);
      expect(
        key('personal-design-${pointShopTemplateKey(templates.first)}'),
        findsNothing,
      );
      await tap(tester, key('personal-design-frame:materialLinenOval'));
      expect(
        tester
            .widget<MaterialCatalogScreen>(find.byType(MaterialCatalogScreen))
            .initialType,
        '프레임',
      );
      expect(find.text('1개 항목'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unconfirmed ownership never looks like an empty collection', (
    tester,
  ) async {
    reset(tester);
    viewport(tester, const Size(390, 844));
    final pending = Completer<Set<String>>();
    await mount(
      tester,
      Scaffold(body: OwnedDesignShelf(onOpen: (_) {})),
      loadOwned: () => pending.future,
    );
    expect(find.text('구매한 디자인을 확인하고 있어요'), findsOneWidget);
    expect(find.text('구매한 템플릿과 소재가 여기에 모여요.'), findsNothing);
    pending.completeError(StateError('local failure'));
    await paint(tester);
    expect(find.text('구매한 디자인을 확인하지 못했어요'), findsOneWidget);
    expect(find.text('템플릿 0종 · 소재 0종'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing album is not presented as a print snapshot', (
    tester,
  ) async {
    reset(tester);
    viewport(tester, const Size(648, 320));
    await mount(
      tester,
      const Scaffold(
        body: OrderDetailWorkspace(albumId: 999, children: [Text('주문 확인')]),
      ),
    );
    expect(find.textContaining('앨범 표지를 확인할 수 없어요.'), findsOneWidget);
    expect(find.textContaining('현재 저장된 표지 미리보기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'order filter and loaded page survive rotation without refetching',
    (tester) async {
      reset(tester);
      viewport(tester, const Size(390, 844));
      await mount(tester, const OrderHistoryScreen());
      await tap(
        tester,
        find.descendant(of: find.byType(TabBar), matching: find.text('배송중')),
      );
      final calls = queries.length;
      viewport(tester, const Size(648, 320));
      await paint(tester);
      expect(queries.length, calls);
      expect(key('personal-order-${orders.first.orderId}'), findsOneWidget);
      expect(key('personal-order-${orders[1].orderId}'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('large type order retry and album favorites remain usable', (
    tester,
  ) async {
    reset(tester);
    viewport(tester, const Size(648, 320));
    await mount(
      tester,
      const OrderHistoryScreen(),
      scale: 1.8,
      failOrders: true,
    );
    await reveal(tester, find.text('다시 시도'));
    expect(
      tester.getBottomRight(find.text('다시 시도')).dy,
      lessThanOrEqualTo(296),
    );
    await tap(tester, find.text('다시 시도'));
    expect(find.text('주문 내역을 불러오지 못했습니다.'), findsOneWidget);
    await mount(tester, albumPage(), scale: 1.8);
    await tap(tester, find.byTooltip('즐겨찾기 해제'));
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await paint(tester);
    await tap(tester, find.text('즐겨찾기'));
    expect(key('personal-record-1'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'album_favorite_ids_v1',
      ),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

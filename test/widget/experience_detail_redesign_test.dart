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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/store_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/shared/widgets/catalog_artwork_hero.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;

Widget reviewApp(
  Widget child, {
  Set<String> owned = const {},
  PointShopAccessGate? gate,
  Future<List<PointShopProduct>> Function()? catalog,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    pointShopCatalogProvider.overrideWith(
      (ref) async => catalog == null ? [] : await catalog(),
    ),
    ownedPointShopKeysProvider.overrideWith((ref) async => owned),
    templateListProvider.overrideWith(
      (ref) async => publishedCreationTemplates,
    ),
    pointShopAccessGateProvider.overrideWithValue(
      gate ??
          (context, ref, {required productKey, required title}) async => false,
    ),
    authViewModelProvider.overrideWith(
      () => FakeAuthViewModel(
        const UserInfo(
          id: 'qa',
          name: '스냅핏',
          email: 'snapfit@example.com',
          provider: 'kakao',
        ),
      ),
    ),
    homeViewModelProvider.overrideWith(() => FakeHomeViewModel([])),
    myPointBalanceProvider.overrideWith((ref) async => 2400),
    myStorageQuotaProvider.overrideWith(
      (ref) async => StorageQuotaStatus.fromJson({}),
    ),
    myOrderSummaryProvider.overrideWith(
      (ref) async => OrderSummaryResult.fromJson({}),
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      home: child,
    ),
  ),
);

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EXPERIENCE_QA')) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('output/experience-detail-qa').createSync(recursive: true);
    File(
      'output/experience-detail-qa/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('detail and library layouts $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final spec = studioDecorations.first;
      final key = GlobalKey();
      await tester.pumpWidget(
        reviewApp(
          RepaintBoundary(
            key: key,
            child: MaterialDetailScreen(
              productKey: 'sticker:${spec.id}',
              favoriteKey: CatalogFavoriteKeys.decoration(spec.insertionValue),
              title: spec.label,
              type: '스티커',
              preview: (_) => StudioDecoration(spec: spec),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('material-access')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'material-${size.width.toInt()}');
      await tester.ensureVisible(find.text('앨범 적용 예시'));
      await tester.tap(find.text('앨범 적용 예시'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialApplicationPreview), findsOneWidget);
      final photoBefore = tester
          .widget<MaterialApplicationPreview>(
            find.byType(MaterialApplicationPreview),
          )
          .photoIndex;
      await tester.ensureVisible(find.byTooltip('다른 사진으로 보기'));
      await tester.tap(find.byTooltip('다른 사진으로 보기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MaterialApplicationPreview>(
              find.byType(MaterialApplicationPreview),
            )
            .photoIndex,
        photoBefore + 1,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'material-applied-${size.width.toInt()}');
      await tester.ensureVisible(find.byTooltip('소재 크게 보기'));
      await tester.tap(find.byTooltip('소재 크게 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      final favorite = studioDecorations[1];
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.decoration(favorite.insertionValue),
      );
      await tester.pumpWidget(
        reviewApp(
          RepaintBoundary(
            key: key,
            child: const MaterialCatalogScreen(library: true),
          ),
          owned: {'sticker:${spec.id}'},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('material-item-sticker:${spec.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('material-item-sticker:${favorite.id}')),
        findsNothing,
      );
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('material-item-sticker:${favorite.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('material-item-sticker:${spec.id}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'library-${size.width.toInt()}');

      await tester.pumpWidget(
        reviewApp(
          RepaintBoundary(
            key: key,
            child: TemplateDetailScreen(
              template: publishedCreationTemplates.first,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, 'template-${size.width.toInt()}');
      expect(find.text('무료 템플릿 안내'), findsOneWidget);
      expect(find.text('템플릿 구매 안내'), findsNothing);
      expect(find.textContaining('프레임·스티커·문구를 별도로 구매할 필요 없이'), findsOneWidget);
      expect(find.text('한 권의 흐름'), findsNothing);
      await tester.ensureVisible(find.byTooltip('다음 펼침면'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 펼침면'));
      await tester.pumpAndSettle();
      expect(find.text('1–2쪽'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-size-selector')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('template-size-selector')),
          matching: find.text('가로형'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1–2쪽'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('전체 미리보기'));
      await tester.tap(find.byTooltip('전체 미리보기'));
      await tester.pumpAndSettle();
      final fullScreen = tester.widget<TemplateFullScreenView>(
        find.byType(TemplateFullScreenView),
      );
      expect(fullScreen.initialIndex, 1);
      expect(fullScreen.preserveTypography, isTrue);
      expect(
        fullScreen.designCanvasSize.width,
        greaterThan(fullScreen.designCanvasSize.height),
      );
      Navigator.of(tester.element(find.byType(TemplateFullScreenView))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-spread-thumb-2')),
      );
      await tester.tap(find.byKey(const ValueKey('template-spread-thumb-2')));
      await tester.pumpAndSettle();
      expect(find.text('3–4쪽'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('template-spread-pager')),
      );
      await tester.drag(
        find.byKey(const ValueKey('template-spread-pager')),
        const Offset(280, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('1–2쪽'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('이전 펼침면'));
      await tester.tap(find.byTooltip('이전 펼침면'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '이전 펼침면',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        reviewApp(RepaintBoundary(key: key, child: const MyPageScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('2,400 P'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-album-collection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-design-collection')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'my-${size.width.toInt()}');
    });
  }

  final supportedMaterial = studioDecorations.first;
  final supportedMaterialKey = 'sticker:${supportedMaterial.id}';
  MaterialDetailScreen materialDetail() => MaterialDetailScreen(
    productKey: supportedMaterialKey,
    favoriteKey: 'qa',
    title: '테스트 소재',
    type: '스티커',
    preview: (_) => const SizedBox(),
  );

  for (final state in [
    (price: 0, active: true, owned: false, label: '무료로 이용하기', enabled: true),
    (price: 250, active: true, owned: false, label: '250P로 구매', enabled: true),
    (price: 250, active: true, owned: true, label: '사용할 앨범 선택', enabled: true),
    (price: 250, active: false, owned: false, label: '판매 준비 중', enabled: false),
  ]) {
    testWidgets('material action matches ${state.label}', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        reviewApp(
          materialDetail(),
          owned: state.owned ? {supportedMaterialKey} : {},
          catalog: () async => [
            PointShopProduct(
              productKey: supportedMaterialKey,
              kind: 'sticker',
              assetId: supportedMaterial.id,
              title: '테스트 소재',
              pointPrice: state.price,
              isActive: state.active,
            ),
          ],
          gate: (context, ref, {required productKey, required title}) async {
            calls++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('material-access'));
      expect(
        find.descendant(of: action, matching: find.text(state.label)),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(action).onPressed != null,
        state.enabled,
      );
      expect(calls, 0);
      if (state.enabled) {
        await tester.tap(action);
        // The detail action stays busy until the album picker closes.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(calls, 1);
        expect(find.text('사용할 앨범'), findsOneWidget);
        expect(find.text('사용할 앨범이 아직 없어요.'), findsOneWidget);
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('material price errors can retry without requesting access', (
    tester,
  ) async {
    var requests = 0;
    var accessCalls = 0;
    await tester.pumpWidget(
      reviewApp(
        materialDetail(),
        catalog: () async {
          if (++requests == 1) throw StateError('offline');
          return [];
        },
        gate: (context, ref, {required productKey, required title}) async {
          accessCalls++;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('가격 다시 확인'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('material-access')));
    await tester.pumpAndSettle();
    expect(find.text('무료로 이용하기'), findsOneWidget);
    expect(accessCalls, 0);
    expect(requests, 2);
  });

  testWidgets('material navigation shares artwork and returns to the library', (
    tester,
  ) async {
    final spec = studioDecorations.first;
    await tester.pumpWidget(
      reviewApp(
        const MaterialCatalogScreen(library: true),
        owned: {'sticker:${spec.id}'},
      ),
    );
    await tester.pumpAndSettle();
    final tag = tester.widget<Hero>(find.byType(Hero)).tag;
    await tester.tap(find.byKey(ValueKey('material-item-sticker:${spec.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialDetailScreen), findsOneWidget);
    expect(tester.widget<Hero>(find.byType(Hero)).tag, tag);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialCatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion disables artwork flight', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: CatalogArtworkHero(tag: 'qa', child: SizedBox()),
        ),
      ),
    );
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('floating store cover can fly to its detail and back', (
    tester,
  ) async {
    await tester.pumpWidget(reviewApp(const StoreScreen(embedded: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final tile = find
        .byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.key.toString().contains('store-template-'),
        )
        .first;
    await tester.ensureVisible(tile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('material action waits for an initial price response', (
    tester,
  ) async {
    final catalog = Completer<List<PointShopProduct>>();
    await tester.pumpWidget(
      reviewApp(materialDetail(), catalog: () => catalog.future),
    );
    await tester.pump();
    final action = find.byKey(const ValueKey('material-access'));
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    catalog.complete([]);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
  });

  testWidgets('material access is explicit and blocked while pending', (
    tester,
  ) async {
    final decision = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      reviewApp(
        MaterialDetailScreen(
          productKey: 'sticker:qa',
          favoriteKey: 'qa',
          title: '테스트 소재',
          type: '스티커',
          preview: (_) => const SizedBox(),
        ),
        gate: (context, ref, {required productKey, required title}) {
          calls++;
          return decision.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.byKey(const ValueKey('material-access')));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('material-access')))
          .onPressed,
      isNull,
    );
    decision.complete(false);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('material-access')))
          .onPressed,
      isNotNull,
    );
    expect(find.text('사용 가능한 소재입니다. 앨범 편집의 꾸미기에서 선택해 주세요.'), findsNothing);
  });
}

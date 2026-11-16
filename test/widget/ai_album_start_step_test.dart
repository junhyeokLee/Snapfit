import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/data/store_curation_provider.dart';
import 'package:snap_fit/features/store/data/store_discovery_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';

// Artwork and layout tests use a controlled free catalog, never a live shop.
Widget wrapCreation(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  PointShopAccessGate? pointShopGate,
  List<PointShopProduct> shopProducts = const [],
  bool showShell = true,
}) => ProviderScope(
  overrides: [
    pointShopCatalogProvider.overrideWith((ref) async => shopProducts),
    ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
    storeDiscoveryProvider.overrideWith(
      (ref) async => const <String, StoreProductDiscovery>{},
    ),
    storeDiscoveryClockProvider.overrideWithValue(DateTime.utc(2026, 11, 11)),
    storeCurationsProvider.overrideWith(
      (ref) async => const <String, StoreCuration>{},
    ),
    pointShopAccessGateProvider.overrideWithValue(
      pointShopGate ??
          (context, ref, {required productKey, required title}) async => true,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: showShell
          ? Scaffold(
              appBar: AppBar(title: const Text('앨범 만들기')),
              body: child,
            )
          : child,
    ),
  ),
);

Future<void> loadCreationFonts() async {
  await (FontLoader('Poppins')
        ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.otf'))
        ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.otf')))
      .load();
  await (FontLoader('Pretendard')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf')))
      .load();
  await (FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await (FontLoader('NotoSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf')))
      .load();
}

Future<List<PremiumTemplate>> creationFixtures() async =>
    List<PremiumTemplate>.unmodifiable(publishedCreationTemplates);

// Allow native image decoding to finish without waiting on an image forever.
Future<void> _settleArtwork(WidgetTester tester) async {
  var stableFrames = 0;
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    final ready =
        find.byType(CatalogCoverSkeleton).evaluate().isEmpty &&
        PaintingBinding.instance.imageCache.pendingImageCount == 0 &&
        !tester.binding.hasScheduledFrame;
    stableFrames = ready && frame >= 12 ? stableFrames + 1 : 0;
    if (stableFrames == 4) return;
  }
  fail('Creation artwork did not settle within 160 bounded frames.');
}

void main() {
  test(
    'creation fixtures use the current published catalog without handoffs',
    () async {
      final templates = await creationFixtures();
      expect(templates, isNotEmpty);
      expect(templates, hasLength(publishedCreationTemplates.length));
      expect(
        templates.map((template) => template.id).toSet(),
        hasLength(templates.length),
      );
      expect(
        templates.map((template) => template.id),
        publishedCreationTemplates.map((template) => template.id),
      );
      for (var i = 0; i < templates.length; i++) {
        expect(templates[i], same(publishedCreationTemplates[i]));
      }
    },
  );

  testWidgets(
    'manual, free and point previews use server pricing without buying',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var manual = 0, purchaseChecks = 0;
      PremiumTemplate? selected;
      final templates = [
        PremiumTemplate(
          id: 1,
          title: '여행 일기',
          coverImageUrl: '',
          previewImages: [],
          pageCount: 8,
          userCount: 0,
          isPremium: true,
        ),
        PremiumTemplate(
          id: 2,
          title: '웨딩 화보',
          coverImageUrl: '',
          previewImages: [],
          pageCount: 12,
          userCount: 0,
          isPremium: false,
        ),
      ];
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            onManualStart: () => manual++,
            templates: AsyncData(templates),
            onTemplateSelected: (value) => selected = value,
          ),
          shopProducts: const [
            PointShopProduct(
              productKey: 'template:server-1',
              kind: 'template',
              assetId: 'server-1',
              title: '여행 일기',
              pointPrice: 0,
              isActive: true,
            ),
            PointShopProduct(
              productKey: 'template:server-2',
              kind: 'template',
              assetId: 'server-2',
              title: '웨딩 화보',
              pointPrice: 120,
              isActive: true,
            ),
          ],
          pointShopGate:
              (context, ref, {required productKey, required title}) async {
                purchaseChecks++;
                return false;
              },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creation-manual-start')));
      expect(manual, 1);
      expect(find.text('첫 템플릿 무료'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('creation-open-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creation-price-유료')));
      await tester.pumpAndSettle();
      expect(find.text('여행 일기'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('creation-template-2')),
      );
      await tester.tap(find.byKey(const ValueKey('creation-template-2')));
      expect(selected?.id, 2);
      expect(purchaseChecks, 0);
      final freeFilter = find.byKey(const ValueKey('creation-price-무료'));
      await tester.ensureVisible(freeFilter);
      await tester.tap(freeFilter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('creation-template-2')), findsNothing);
      final search = find.byKey(const ValueKey('creation-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, '없는검색');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없어요'), findsOneWidget);
    },
  );

  testWidgets('an unlisted paid template is never advertised as free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapCreation(
        AiAlbumStartStep(
          onManualStart: () {},
          templates: AsyncData([
            PremiumTemplate(
              id: 9,
              title: '판매 대기 디자인',
              coverImageUrl: '',
              previewImages: [],
              pageCount: 24,
              userCount: 0,
              isPremium: true,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creation-open-catalog')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('creation-price-무료')));
    await tester.tap(find.byKey(const ValueKey('creation-price-무료')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creation-template-9')), findsNothing);
    expect(find.text('검색 결과가 없어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creation-price-유료')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creation-template-9')),
    );
    expect(find.text('판매 준비 중'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('current catalog layout, search and selection $size', (
      tester,
    ) async {
      // Native font registration needs real async time outside the fake clock.
      await tester.runAsync(loadCreationFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final templates = (await tester.runAsync(creationFixtures))!;
      var manual = 0;
      PremiumTemplate? selected;
      await tester.pumpWidget(
        wrapCreation(
          AiAlbumStartStep(
            onManualStart: () => manual++,
            onTemplateSelected: (value) => selected = value,
            templates: AsyncData(templates),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _settleArtwork(tester);
      await tester.pumpAndSettle();
      final manualStart = find.byKey(const ValueKey('creation-manual-start'));
      await tester.ensureVisible(manualStart);
      await tester.tap(manualStart);
      expect(manual, 1);
      // Enter the catalog through the same action used on short displays.
      final openCatalog = find.byKey(const ValueKey('creation-open-catalog'));
      await tester.ensureVisible(openCatalog);
      await tester.tap(openCatalog);
      await tester.pumpAndSettle();
      expect(
        (tester
                    .widget<SliverGrid>(
                      find.byType(SliverGrid, skipOffstage: false),
                    )
                    .delegate
                as SliverChildBuilderDelegate)
            .childCount,
        templates.length,
      );
      final search = find.byKey(const ValueKey('creation-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, templates.last.title);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        (tester
                    .widget<SliverGrid>(
                      find.byType(SliverGrid, skipOffstage: false),
                    )
                    .delegate
                as SliverChildBuilderDelegate)
            .childCount,
        1,
      );
      final card = find.byKey(
        ValueKey('creation-template-${templates.last.id}'),
      );
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(selected, same(templates.last));
      expect(tester.takeException(), isNull);
    });
  }
}

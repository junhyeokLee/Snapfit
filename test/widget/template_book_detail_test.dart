import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/cover/album_spine_image.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_purchase_overview.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

List<PointShopProduct> _catalog() => [
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

Widget _app(
  Widget page, {
  bool dark = false,
  double scale = 1,
  GlobalKey? captureKey,
  List<PointShopProduct>? catalog,
  Set<String> owned = const {},
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    pointShopCatalogProvider.overrideWith((ref) async => catalog ?? _catalog()),
    ownedPointShopKeysProvider.overrideWith((ref) async => owned),
    pointShopAccessGateProvider.overrideWithValue(
      (context, ref, {required productKey, required title}) async => false,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: page,
    ),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
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
  if (!const bool.fromEnvironment('TEMPLATE_BOOK_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/template-book-detail-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _PaintBinding();
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

  const paidKey = 'sticker:materialLace';
  final paid = PointShopProduct(
    productKey: paidKey,
    kind: 'sticker',
    assetId: 'materialLace',
    title: '레이스',
    pointPrice: 300,
    isActive: true,
  );
  test('inclusion alone never grants paid material reuse', () {
    expect(
      templateMaterialReuse(paidKey, AsyncData([paid]), const AsyncData({})),
      (reusable: false, label: '다른 앨범 사용 · 300P'),
    );
    expect(
      templateMaterialReuse(
        paidKey,
        AsyncData([paid]),
        const AsyncData({paidKey}),
      ).reusable,
      isTrue,
    );
    expect(
      templateMaterialReuse(
        paidKey,
        const AsyncData([]),
        const AsyncData({}),
      ).reusable,
      isFalse,
    );
    expect(
      templateMaterialReuse(
        paidKey,
        AsyncData([paid]),
        const AsyncLoading(),
      ).label,
      '보유 권한 확인 중',
    );
    expect(
      templateMaterialReuse(
        paidKey,
        AsyncData([paid]),
        AsyncError(StateError('offline'), StackTrace.current),
      ).label,
      '보유 권한 확인 필요',
    );
    expect(
      templateMaterialReuse(
        freeTemplateMaterialProductKeys.first,
        const AsyncData([]),
        const AsyncData({}),
      ).reusable,
      isTrue,
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native book detail, actual spreads and rights $size dark=$dark',
        (tester) async {
          _size(tester, size);
          final template = publishedCreationTemplates.firstWhere(
            (item) => item.id == -9501,
          );
          final original = template.templateJson;
          final key = GlobalKey();
          final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
          await tester.pumpWidget(
            _app(
              TemplateDetailScreen(template: template),
              dark: dark,
              captureKey: key,
            ),
          );
          await _paint(tester);
          final stage = find.byKey(const ValueKey('template-detail-stage'));
          final frame = tester.widget<HomeCoverFrame>(
            find
                .descendant(of: stage, matching: find.byType(HomeCoverFrame))
                .first,
          );
          expect(frame.showBookDepth, isTrue);
          expect(frame.bindingArtwork, isNotNull);
          expect(
            find.descendant(of: stage, matching: find.byType(AlbumSpineImage)),
            findsWidgets,
          );
          expect(frame.width / frame.height, closeTo(1, .0001));
          expect(tester.takeException(), isNull);
          await _capture(tester, key, 'cover-$suffix');

          await tester.ensureVisible(find.byTooltip('다음 펼침면'));
          await tester.tap(find.byTooltip('다음 펼침면'));
          await _paint(tester);
          expect(find.text('1–2쪽'), findsOneWidget);
          final spread = find.descendant(
            of: stage,
            matching: find.byKey(const ValueKey('template-book-spread-1')),
          );
          expect(spread, findsOneWidget);
          final pages = tester
              .widgetList<TemplatePageRenderer>(
                find.descendant(
                  of: spread,
                  matching: find.byType(TemplatePageRenderer),
                ),
              )
              .toList();
          expect(pages, hasLength(2));
          expect(pages.every((page) => !page.wrapSpineArtwork), isTrue);
          expect(tester.getSize(spread).aspectRatio, closeTo(2, .0001));
          await tester.ensureVisible(stage);
          await _capture(tester, key, 'spread-$suffix');
          await tester.tapAt(
            tester.getRect(spread).centerRight - const Offset(25, 0),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TemplateFullScreenView>(
                  find.byType(TemplateFullScreenView),
                )
                .initialIndex,
            2,
          );
          Navigator.of(
            tester.element(find.byType(TemplateFullScreenView)),
          ).pop();
          await tester.pumpAndSettle();

          final selector = find.byKey(const ValueKey('template-size-selector'));
          await tester.ensureVisible(selector);
          await tester.tap(
            find.descendant(of: selector, matching: find.text('세로형')),
          );
          await _paint(tester);
          final portraitCanvas = tester
              .widget<TemplatePageRenderer>(
                find
                    .descendant(
                      of: spread,
                      matching: find.byType(TemplatePageRenderer),
                    )
                    .first,
              )
              .designCanvasSize!;
          expect(
            tester.getSize(spread).aspectRatio,
            closeTo(portraitCanvas.aspectRatio * 2, .0001),
          );
          await tester.ensureVisible(stage);
          await _capture(tester, key, 'portrait-spread-$suffix');
          await tester.ensureVisible(selector);
          await tester.tap(
            find.descendant(of: selector, matching: find.text('가로형')),
          );
          await _paint(tester);
          expect(tester.getSize(spread).aspectRatio, greaterThan(2));
          expect(find.text('1–2쪽'), findsOneWidget);

          await tester.ensureVisible(
            find.byKey(const ValueKey('template-purchase-overview')),
          );
          final lastMaterial = tester
              .widget<TemplatePurchaseOverview>(
                find.byType(TemplatePurchaseOverview),
              )
              .materialKeys
              .last;
          await _capture(tester, key, 'usage-$suffix');
          expect(find.textContaining('개별 소재 이용권이 지급되지는'), findsOneWidget);
          expect(find.text('다른 앨범에서 개별 재사용'), findsOneWidget);
          await tester.ensureVisible(
            find.byKey(const ValueKey('template-reuse-details')),
          );
          await tester.tap(
            find.byKey(const ValueKey('template-reuse-details')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('template-material-list')),
            findsOneWidget,
          );
          expect(find.byType(TemplateMaterialReuseLabel), findsWidgets);
          await _capture(tester, key, 'materials-$suffix');
          final lastRow = find.byKey(
            ValueKey('template-material-row-$lastMaterial'),
          );
          await tester.scrollUntilVisible(
            lastRow,
            160,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('template-material-list')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(lastRow.hitTestable(), findsOneWidget);
          await tester.tap(lastRow);
          await _paint(tester);
          expect(
            tester
                .widget<MaterialDetailScreen>(find.byType(MaterialDetailScreen))
                .productKey,
            lastMaterial,
          );
          expect(template.templateJson, original);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('zero-point premium promotion is displayed as free', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        TemplateDetailScreen(
          template: publishedCreationTemplates.firstWhere(
            (item) => item.id == -9501,
          ),
        ),
        catalog: const [
          PointShopProduct(
            productKey: 'template:vow-keepsake',
            kind: 'template',
            assetId: 'vow-keepsake',
            title: '무료 공개',
            pointPrice: 0,
            isActive: true,
          ),
        ],
      ),
    );
    await _paint(tester);
    expect(find.text('판매 준비 중'), findsNothing);
    expect(find.text('무료'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown paid template is never labelled free; large type fits', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    final template = publishedCreationTemplates.firstWhere(
      (item) => item.id == -9501,
    );
    await tester.pumpWidget(
      _app(TemplateDetailScreen(template: template), catalog: [], scale: 1.6),
    );
    await _paint(tester);
    expect(find.text('무료'), findsNothing);
    expect(find.text('판매 준비 중'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const ValueKey('template-purchase-overview')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('free template uses the same book without claiming a purchase', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        TemplateDetailScreen(template: publishedCreationTemplates.first),
        captureKey: key,
      ),
    );
    await _paint(tester);
    expect(find.text('무료 템플릿 안내'), findsOneWidget);
    expect(find.text('템플릿 구매 안내'), findsNothing);
    await _capture(tester, key, 'free-cover-390-light');
    await tester.ensureVisible(
      find.byKey(const ValueKey('template-purchase-overview')),
    );
    await _capture(tester, key, 'free-usage-390-light');
    expect(tester.takeException(), isNull);
  });
}

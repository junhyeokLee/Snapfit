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
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_artwork.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_purchase_sheet.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_album_picker.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;
import 'my_page_screen_test.dart' show FakeAuthViewModel;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Shop extends Mock implements PointShopRepository {}

const _material = 'frame:materialLinenOval';
const _title = '리넨 자수 타원';

final _template = publishedCreationTemplates.firstWhere(
  (template) =>
      template.isPremium &&
      templateVisualMaterialKeys(
        jsonDecode(template.templateJson!),
      ).any((key) => key.startsWith('frame:')),
);

final _albumTemplates = [
  _template,
  ...publishedCreationTemplates
      .where((item) => item.isPremium && item.id != _template.id)
      .take(2),
];

List<AlbumPage> _pages(double ratio, {PremiumTemplate? template}) {
  final document =
      jsonDecode((template ?? _template).templateJson!) as Map<String, dynamic>;
  final canvas = Size(500, 500 / ratio);
  final source = templateDocumentPages(document).take(12).toList();
  return [
    for (int index = 0; index < source.length; index++)
      AlbumPage(
        id: 'page-$index',
        pageIndex: index,
        isCover: index == 0,
        backgroundColor: 0xFFE9EFEA,
        layers: DataTemplateEngine.buildLayersFromJson({
          'strictLayout': true,
          'designWidth': document['designWidth'] ?? 500,
          'designHeight': document['designHeight'] ?? 500,
          'layers': source[index]['layers'] ?? [],
        }, canvas),
      ),
  ];
}

List<Album> _albums() => [
  for (final (index, ratio) in [.75, 1.0, 4 / 3].indexed)
    Album(
      id: index + 1,
      userId: 'alice',
      title: _albumTemplates[index].title,
      ratio: '$ratio',
      totalPages: 24,
      targetPages: 24,
      coverLayersJson: jsonEncode({
        'pages': [
          for (final page in _pages(ratio, template: _albumTemplates[index]))
            {
              'index': page.pageIndex,
              'isCover': page.isCover,
              'backgroundColor': page.backgroundColor,
              'layers': [
                for (final layer in page.layers)
                  LayerExportMapper.toJson(
                    layer,
                    canvasSize: Size(500, 500 / ratio),
                    isCover: page.isCover,
                  ),
              ],
            },
        ],
      }),
    ),
];

Widget _app(
  Widget child, {
  required bool dark,
  GlobalKey? captureKey,
  List<Album>? albums,
  MockAlbumRepository? repository,
  double textScale = 1,
}) {
  final fixtures = albums ?? _albums();
  final repo = repository ?? MockAlbumRepository();
  final shop = _Shop();
  when(() => shop.currentUserId).thenReturn('alice');
  for (final album in fixtures) {
    when(() => repo.fetchAlbum('${album.id}')).thenAnswer((_) async => album);
    when(() => repo.lockAlbum(album.id)).thenAnswer((_) async {});
    when(() => repo.unlockAlbum(album.id)).thenAnswer((_) async {});
  }
  when(() => repo.fetchMyAlbums()).thenAnswer((_) async => fixtures);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      albumRepositoryProvider.overrideWithValue(repo),
      pointShopRepositoryProvider.overrideWithValue(shop),
      homeViewModelProvider.overrideWith(() => FakeHomeViewModel(fixtures)),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      templateListProvider.overrideWith(
        (ref) async => publishedCreationTemplates,
      ),
      ownedPointShopKeysProvider.overrideWith((ref) async => {_material}),
      pointShopCatalogProvider.overrideWith(
        (ref) async => [
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
      pointShopAccessGateProvider.overrideWithValue(
        (context, ref, {required productKey, required title}) async => true,
      ),
      authViewModelProvider.overrideWith(
        () => FakeAuthViewModel(
          const UserInfo(id: 'alice', name: '스냅핏', provider: 'kakao'),
        ),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SnapFitTheme.light(),
        darkTheme: SnapFitTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, body) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: captureKey, child: body!),
        ),
        home: child,
      ),
    ),
  );
}

Widget _detail() => MaterialDetailScreen(
  productKey: _material,
  favoriteKey: 'frame:materialLinenOval',
  title: _title,
  type: '프레임',
  preview: (_) => const PointShopArtwork(productKey: _material),
);

Future<void> _paint(WidgetTester tester) async {
  // The detail CTA stays busy while its selection sheet is open.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STORE_SELECTION_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/store-selection-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

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

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('real album and page sheets retain safe areas $suffix', (
        tester,
      ) async {
        _size(tester, size);
        final key = GlobalKey(), repository = MockAlbumRepository();
        await tester.pumpWidget(
          _app(_detail(), dark: dark, captureKey: key, repository: repository),
        );
        await _paint(tester);
        await tester.tap(find.text('사용할 앨범 선택'));
        await _paint(tester);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.byTooltip('닫기').hitTestable(), findsOneWidget);
        final list = tester.getRect(
          find.descendant(
            of: find.byType(MaterialAlbumPicker),
            matching: find.byType(ListView),
          ),
        );
        expect(list.bottom, lessThanOrEqualTo(size.height - 24));
        await _capture(tester, key, 'albums-$suffix');
        await tester.tap(find.text(_albumTemplates.first.title));
        await _paint(tester);
        expect(find.text('2 / 2'), findsOneWidget);
        expect(
          find.textContaining('${_albumTemplates.first.title} · 표지'),
          findsOneWidget,
        );
        final cover = tester.getSize(
          find.byKey(const ValueKey('material-page-art-0')),
        );
        expect(cover.aspectRatio, closeTo(.75, .0001));
        final page = tester.getSize(
          find.byKey(const ValueKey('material-page-art-1')),
        );
        expect(page.aspectRatio, closeTo(.75, .0001));
        expect(
          tester
              .widget<TemplatePageRenderer>(
                find.byType(TemplatePageRenderer).first,
              )
              .showCanvasChrome,
          isFalse,
        );
        await _capture(tester, key, 'pages-$suffix');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('material-page-11')),
          160,
          scrollable: find
              .descendant(
                of: find.byType(MaterialPagePicker),
                matching: find.byType(Scrollable),
              )
              .last,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('material-page-11'))),
          alignment: .5,
        );
        await _paint(tester);
        expect(
          find.byKey(const ValueKey('material-page-11')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        verify(() => repository.unlockAlbum(1)).called(1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('purchase, receipt and recharge stay reachable $suffix', (
        tester,
      ) async {
        _size(tester, size);
        for (final state in ['purchase', 'receipt', 'insufficient']) {
          final key = GlobalKey();
          final access = PointShopAccess(
            productKey: _material,
            title: _title,
            pointPrice: 300,
            available: true,
            isFree: false,
            owned: false,
            remainingBalance: state == 'insufficient' ? 100 : 800,
          );
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: FilledButton(
                      onPressed: () => state == 'receipt'
                          ? showPointShopPurchaseReceipt(
                              context,
                              access: access,
                              title: _title,
                              purchase: const PointShopPurchase(
                                productKey: _material,
                                owned: true,
                                isFree: false,
                                chargedPoints: 300,
                                remainingBalance: 500,
                                alreadyOwned: false,
                              ),
                            )
                          : showPointShopPurchaseSheet(
                              context,
                              access: access,
                              title: _title,
                            ),
                      child: const Text('구매 확인'),
                    ),
                  ),
                ),
              ),
              dark: dark,
              captureKey: key,
            ),
          );
          await tester.tap(find.text('구매 확인'));
          await _paint(tester);
          final label = state == 'receipt'
              ? '소재 사용하기'
              : state == 'insufficient'
              ? '포인트 충전'
              : '300P로 구매';
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(
            tester.getRect(find.text(label)).bottom,
            lessThan(size.height - 24),
          );
          expect(find.text('사용 범위'), findsOneWidget);
          await _capture(tester, key, '$state-$suffix');
          await tester.tap(find.byTooltip('닫기'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets(
        'template materials include real frames, papers and lazy list $suffix',
        (tester) async {
          _size(tester, size);
          final key = GlobalKey();
          await tester.pumpWidget(
            _app(
              TemplateDetailScreen(template: _template),
              dark: dark,
              captureKey: key,
            ),
          );
          await _paint(tester);
          final frame = find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith(
                  'template-material-preview-frame:',
                ),
          );
          await tester.ensureVisible(frame);
          await tester.pumpAndSettle();
          expect(frame, findsOneWidget);
          await _capture(tester, key, 'included-$suffix');
          await tester.tap(frame);
          await _paint(tester);
          expect(find.text('사용한 꾸밈 소재'), findsOneWidget);
          final keys = templateVisualMaterialKeys(
            jsonDecode(_template.templateJson!),
          );
          final list = tester.widget<ListView>(
            find.byKey(const ValueKey('template-material-list')),
          );
          expect(
            (list.childrenDelegate as SliverChildBuilderDelegate).childCount,
            keys.length + 1,
          );
          await _capture(tester, key, 'inventory-$suffix');
          await tester.scrollUntilVisible(
            find.byKey(ValueKey('template-material-row-${keys.last}')),
            180,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('template-material-list')),
              matching: find.byType(Scrollable),
            ),
          );
          // Price/ownership labels can relayout the last lazily built row.
          await tester.pumpAndSettle();
          expect(
            find
                .byKey(ValueKey('template-material-row-${keys.last}'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'page artwork preserves square, portrait, landscape and original backgrounds',
    (tester) async {
      _size(tester, const Size(390, 844));
      for (final ratio in [.75, 1.0, 4 / 3]) {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: MaterialPagePicker(
                title: _title,
                productKey: _material,
                pages: _pages(ratio),
                ratio: ratio,
              ),
            ),
            dark: true,
          ),
        );
        await _paint(tester);
        for (final index in [0, 1]) {
          final art = find.byKey(ValueKey('material-page-art-$index'));
          expect(tester.getSize(art).aspectRatio, closeTo(ratio, .0001));
          final background = tester.widget<ColoredBox>(
            find.descendant(of: art, matching: find.byType(ColoredBox)).first,
          );
          expect(background.color, const Color(0xFFE9EFEA));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('large text, empty album list and long titles remain usable', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: MaterialAlbumPicker(productKey: _material, title: _title),
        ),
        dark: true,
        albums: [],
      ),
    );
    await _paint(tester);
    expect(find.text('사용할 앨범이 아직 없어요.'), findsOneWidget);
    for (final child in [
      MaterialPagePicker(
        title: '매우 긴 이름의 리넨 자수 타원 프레임과 꾸밈 소재',
        productKey: _material,
        albumTitle: '오래도록 간직하고 싶은 우리의 아주 소중한 여행 기록',
        pages: _pages(1),
        ratio: 1,
      ),
      const PointShopPurchaseSheet(
        title: '매우 긴 이름의 리넨 자수 타원 프레임과 꾸밈 소재',
        access: PointShopAccess(
          productKey: _material,
          pointPrice: 300,
          available: true,
          isFree: false,
          owned: false,
          remainingBalance: 100,
        ),
      ),
    ]) {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
          dark: true,
          textScale: 1.7,
        ),
      );
      await _paint(tester);
      expect(find.byTooltip('닫기').hitTestable(), findsOneWidget);
      if (child is PointShopPurchaseSheet)
        expect(find.text('포인트 충전').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

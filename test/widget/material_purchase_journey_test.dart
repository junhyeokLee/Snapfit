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
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/store_material_insertion.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_purchase_sheet.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_album_picker.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'auth_gate_test.dart' show FakeHomeViewModel;

class _Shop extends Mock implements PointShopRepository {}

class _Photo extends Mock implements AssetEntity {}

class _EditorService extends AlbumEditorService {
  const _EditorService();
  @override
  Future<LayerModel> createImageLayer({
    required AssetEntity asset,
    required Size canvasSize,
    String? templateKey,
    bool isCover = false,
  }) async => LayerModel(
    id: asset.id,
    type: LayerType.image,
    position: const Offset(30, 40),
    width: 180,
    height: 180,
    asset: asset,
  );
}

class _Harness extends ConsumerWidget {
  const _Harness();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => pickAlbumForMaterial(
          context,
          ref,
          productKey: 'sticker:studioCotton',
          title: '코튼 페이퍼',
        ),
        child: const Text('소재 넣기'),
      ),
    ),
  );
}

const _album = Album(
  id: 7,
  userId: 'alice',
  title: '우리의 기록',
  ratio: '1:1',
  targetPages: 4,
  coverLayersJson:
      '{"pages":[{"index":0,"isCover":true,"layers":[]},{"index":1,"layers":[]},{"index":2,"layers":[]},{"index":3,"layers":[]}]}',
);

Future<ProviderContainer> _container(
  MockAlbumRepository repository,
  _Shop shop,
) async {
  final result = ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(repository),
      pointShopRepositoryProvider.overrideWithValue(shop),
      homeViewModelProvider.overrideWith(() => FakeHomeViewModel([_album])),
      albumEditorServiceProvider.overrideWithValue(const _EditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(result.dispose);
  await result.read(albumEditorViewModelProvider.future);
  return result;
}

Widget _app(ProviderContainer container, Widget child, {bool dark = false}) =>
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: SnapFitTheme.light(),
          darkTheme: SnapFitTheme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: child,
        ),
      ),
    );

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('COMMERCE_QA')) return;
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
    final file = File('output/commerce-journey-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<ProviderContainer> mountJourney(
    WidgetTester tester, {
    Album album = _album,
    required MockAlbumRepository repository,
    required _Shop shop,
  }) async {
    when(() => repository.fetchAlbum('7')).thenAnswer((_) async => album);
    when(() => repository.lockAlbum(7)).thenAnswer((_) async {});
    when(() => repository.unlockAlbum(7)).thenAnswer((_) async {});
    when(() => repository.fetchMyAlbums()).thenAnswer((_) async => [_album]);
    when(() => shop.currentUserId).thenReturn('alice');
    when(() => shop.getAccess('sticker:studioCotton')).thenAnswer(
      (_) async => const PointShopAccess(
        productKey: 'sticker:studioCotton',
        available: true,
        isFree: false,
        owned: true,
        remainingBalance: 100,
      ),
    );
    final container = await _container(repository, shop);
    await tester.pumpWidget(_app(container, const _Harness()));
    await tester.tap(find.text('소재 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('우리의 기록'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'chosen material opens the exact page, once, and remains undoable',
    (tester) async {
      final repository = MockAlbumRepository(), shop = _Shop();
      final container = await mountJourney(
        tester,
        repository: repository,
        shop: shop,
      );
      expect(find.text('적용할 페이지'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('material-page-2')));
      await tester.pumpAndSettle();
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(vm.currentPageIndex, 2);
      expect(vm.pages[1].layers, isEmpty);
      expect(vm.pages[2].layers.single.imageBackground, 'studioCotton');
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(vm.pages[2].layers, hasLength(1));
      vm.undo();
      expect(vm.pages[2].layers, isEmpty);
      Navigator.of(tester.element(find.byType(PageEditorScreen))).pop();
      await tester.pumpAndSettle();
      verify(() => repository.unlockAlbum(7)).called(1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('cancel page selection releases lock without inserting', (
    tester,
  ) async {
    final repository = MockAlbumRepository(), shop = _Shop();
    final container = await mountJourney(
      tester,
      repository: repository,
      shop: shop,
    );
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(
      container
          .read(albumEditorViewModelProvider.notifier)
          .pages
          .every((p) => p.layers.isEmpty),
      isTrue,
    );
    verify(() => repository.unlockAlbum(7)).called(1);
    verifyNever(() => shop.getAccess(any()));
  });

  testWidgets('cover selection inserts on the cover only', (tester) async {
    final repository = MockAlbumRepository(), shop = _Shop();
    final container = await mountJourney(
      tester,
      repository: repository,
      shop: shop,
    );
    await tester.tap(find.byKey(const ValueKey('material-page-0')));
    await tester.pumpAndSettle();
    final vm = container.read(albumEditorViewModelProvider.notifier);
    expect(vm.currentPageIndex, 0);
    expect(vm.pages[0].layers.single.imageBackground, 'studioCotton');
    expect(vm.pages.skip(1).every((page) => page.layers.isEmpty), isTrue);
    Navigator.of(tester.element(find.byType(PageEditorScreen))).pop();
    await tester.pumpAndSettle();
    verify(() => repository.unlockAlbum(7)).called(1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('revoked access is rechecked before entering the editor', (
    tester,
  ) async {
    final repository = MockAlbumRepository(), shop = _Shop();
    await mountJourney(tester, repository: repository, shop: shop);
    when(() => shop.getAccess('sticker:studioCotton')).thenAnswer(
      (_) async => const PointShopAccess(
        productKey: 'sticker:studioCotton',
        available: false,
        isFree: false,
        owned: false,
        remainingBalance: 100,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('material-page-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PageEditorScreen), findsNothing);
    verify(() => repository.unlockAlbum(7)).called(1);
  });

  testWidgets('another member lock prevents editing', (tester) async {
    final repository = MockAlbumRepository(), shop = _Shop();
    await mountJourney(
      tester,
      album: _album.copyWith(lockedById: 'bob'),
      repository: repository,
      shop: shop,
    );
    expect(find.text('다른 멤버가 편집 중이에요. 잠시 후 다시 선택해 주세요.'), findsOneWidget);
    verifyNever(() => repository.lockAlbum(any()));
    expect(find.byType(MaterialPagePicker), findsNothing);
  });

  testWidgets('read-only album never acquires an edit lock', (tester) async {
    final repository = MockAlbumRepository(), shop = _Shop();
    await mountJourney(
      tester,
      album: _album.copyWith(userId: 'bob'),
      repository: repository,
      shop: shop,
    );
    expect(find.text('이 앨범은 읽기 전용이에요. 직접 만든 앨범을 선택해 주세요.'), findsOneWidget);
    verifyNever(() => repository.lockAlbum(any()));
    expect(find.byType(MaterialPagePicker), findsNothing);
  });

  testWidgets(
    'account switch during page choice never inserts or opens editor',
    (tester) async {
      final repository = MockAlbumRepository(), shop = _Shop();
      await mountJourney(tester, repository: repository, shop: shop);
      when(() => shop.currentUserId).thenReturn('bob');
      await tester.tap(find.byKey(const ValueKey('material-page-1')));
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsNothing);
      verifyNever(() => shop.getAccess(any()));
      verify(() => repository.unlockAlbum(7)).called(1);
    },
  );

  testWidgets(
    'photo frame is one undo step; cancel and unknown materials do nothing',
    (tester) async {
      final container = await _container(MockAlbumRepository(), _Shop());
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.resetForCreate();
      vm.goToPage(1);
      expect(await insertStoreMaterial(vm, 'frame:materialLinenOval'), isFalse);
      expect(await insertStoreMaterial(vm, 'sticker:unknown'), isFalse);
      expect(vm.currentPage!.layers, isEmpty);
      final photo = _Photo();
      when(() => photo.id).thenReturn('test-photo');
      expect(
        await insertStoreMaterial(vm, 'frame:materialLinenOval', photo: photo),
        isTrue,
      );
      expect(
        vm.currentPage!.layers.single.imageBackground,
        'materialLinenOval',
      );
      vm.undo();
      expect(vm.currentPage!.layers, isEmpty);
      vm.redo();
      expect(
        vm.currentPage!.layers.single.imageBackground,
        'materialLinenOval',
      );
    },
  );

  for (final key in [
    'sticker:studioCotton',
    'sticker:studioCottonRag',
    'phrase:travel-map',
    studioWordArts.first.productKey,
  ]) {
    testWidgets('insertion and grouped undo preserve existing layers: $key', (
      tester,
    ) async {
      final container = await _container(MockAlbumRepository(), _Shop());
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.resetForCreate(initialCover: coverSizes.first);
      vm.goToPage(1);
      expect(await insertStoreMaterial(vm, key), isTrue);
      expect(vm.currentPage!.layers, isNotEmpty);
      expect(vm.pages[0].layers, isEmpty);
      vm.undo();
      expect(vm.currentPage!.layers, isEmpty);
      vm.redo();
      expect(vm.currentPage!.layers, isNotEmpty);
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('confirmation and receipt remain accessible $size dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final container = await _container(MockAlbumRepository(), _Shop());
        const access = PointShopAccess(
          productKey: 'frame:materialLinenOval',
          title: '리넨 자수 타원',
          pointPrice: 300,
          available: true,
          isFree: false,
          owned: false,
          remainingBalance: 800,
        );
        for (final complete in [false, true]) {
          final key = GlobalKey();
          await tester.pumpWidget(
            _app(
              container,
              RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: PointShopPurchaseSheet(
                      access: access,
                      title: '리넨 자수 타원',
                      purchase: complete
                          ? const PointShopPurchase(
                              productKey: 'frame:materialLinenOval',
                              owned: true,
                              isFree: false,
                              chargedPoints: 300,
                              remainingBalance: 500,
                              alreadyOwned: false,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(complete ? '소재 사용하기' : '300P로 구매').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            key,
            '${complete ? 'receipt' : 'purchase'}-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
        }
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final document =
            jsonDecode(publishedCreationTemplates.first.templateJson!)
                as Map<String, dynamic>;
        final previewPages = templateDocumentPages(document)
            .take(5)
            .map(
              (page) => DataTemplateEngine.buildLayersFromJson({
                'strictLayout': true,
                'designWidth': 500,
                'designHeight': 500,
                'layers': page['layers'] ?? [],
              }, const Size(500, 500)),
            )
            .toList();
        vm.startLocalTemplateAlbum(
          albumTitle: '페이지 선택',
          pages: previewPages,
          initialCover: coverSizes.firstWhere((size) => size.ratio == 1),
          templateCanvasSize: const Size(500, 500),
        );
        final pageKey = GlobalKey();
        await tester.pumpWidget(
          _app(
            container,
            RepaintBoundary(
              key: pageKey,
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: MaterialPagePicker(
                    title: '코튼 페이퍼',
                    productKey: 'sticker:studioCotton',
                    pages: vm.pages,
                    ratio: 1,
                  ),
                ),
              ),
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('material-page-0')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          pageKey,
          'pages-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
      });
    }
  }
}

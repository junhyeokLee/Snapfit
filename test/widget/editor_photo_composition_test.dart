import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/photo_frame_editor.dart';
import 'package:snap_fit/features/album/presentation/controllers/toolbar_action_handler.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_action_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/photo_crop_viewport.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/shared/widgets/image_template_picker.dart';
import '../helpers/mock_repositories.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

LayerModel _photo() => LayerModel(
  id: 'saved-photo',
  type: LayerType.image,
  position: const Offset(60, 70),
  width: 320,
  height: 400,
  rotation: .08,
  previewUrl: 'asset:assets/snapfit_home_square.jpg',
  originalUrl: 'asset:assets/snapfit_home_square.jpg',
  imageBackground: 'archSoft',
  imageTemplate: '4:3',
  opacity: .9,
  zIndex: 2,
);

class _ReplacementPhoto extends Mock implements AssetEntity {}

late Uint8List _replacementBytes;
AssetEntity _replacementPhoto() {
  final photo = _ReplacementPhoto();
  when(() => photo.id).thenReturn('replacement-photo');
  when(() => photo.type).thenReturn(AssetType.image);
  when(() => photo.mimeType).thenReturn(null);
  when(() => photo.title).thenReturn('replacement.jpg');
  when(() => photo.width).thenReturn(1200);
  when(() => photo.height).thenReturn(800);
  when(() => photo.orientation).thenReturn(0);
  when(() => photo.createDateTime).thenReturn(DateTime(2026, 10, 8));
  when(
    () => photo.loadFile(isOrigin: true),
  ).thenAnswer((_) async => File('assets/frame_preview/alpine_lake.jpg'));
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => _replacementBytes);
  return photo;
}

class _ReplacementGallery implements GalleryRepository {
  _ReplacementGallery({this.permission});
  final Completer<bool>? permission;
  final photo = _replacementPhoto();
  int refreshes = 0;
  @override
  Future<bool> requestPermission() async =>
      permission == null ? true : await permission!.future;
  @override
  Future<List<AssetPathEntity>> loadAlbums() async {
    refreshes++;
    return [AssetPathEntity(id: 'all', name: 'Recent', isAll: true)];
  }

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async =>
      AssetPathEntity(id: 'all', name: 'Recent', isAll: true);
  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) async => page == 0 ? [photo] : [];
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  // File decoding needs both real I/O and fake-async image callbacks to advance.
  for (var attempt = 0; attempt < 100; attempt++) {
    final loading = find.byType(Image).evaluate().where((element) {
      final pixels = find
          .descendant(
            of: find.byWidget(element.widget),
            matching: find.byType(RawImage),
          )
          .evaluate();
      return pixels.isEmpty ||
          pixels.any((pixel) => (pixel.widget as RawImage).image == null);
    }).toList();
    if (loading.isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Editor photos did not finish decoding');
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EDITOR_FLOW_QA')) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await loadCreationFonts();
    _replacementBytes = await File(
      'assets/frame_preview/alpine_lake.jpg',
    ).readAsBytes();
  });
  late CatalogFavorites previousFavorites;
  setUp(() async {
    previousFavorites = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previousFavorites;
  });

  Future<({AlbumEditorViewModel vm, GlobalKey capture})> boot(
    WidgetTester tester,
    Size size,
    bool dark,
    int pageIndex, {
    LayerModel? photo,
    PointShopAccessGate? frameAccess,
    GalleryRepository? gallery,
    EdgeInsets safeArea = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        if (gallery != null)
          galleryRepositoryProvider.overrideWithValue(gallery),
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
        ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
        pointShopAccessGateProvider.overrideWithValue(
          frameAccess ??
              (context, ref, {required productKey, required title}) async =>
                  true,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    vm.resetForCreate();
    vm.goToPage(pageIndex);
    vm.updatePageLayers([photo ?? _photo()], recordHistory: false);
    final capture = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: safeArea, viewPadding: safeArea),
              child: RepaintBoundary(key: capture, child: child!),
            ),
            home: PageEditorScreen(initialPageIndex: pageIndex),
          ),
        ),
      ),
    );
    await _paint(tester);
    final interaction = pageIndex == 0
        ? tester.widget<EditCover>(find.byType(EditCover)).interaction!
        : tester
              .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
              .interaction;
    interaction.setSelectedLayer('saved-photo');
    await _paint(tester);
    return (vm: vm, capture: capture);
  }

  Future<void> openFrames(WidgetTester tester) async {
    final decorate = find.descendant(
      of: find.byType(LayerActionPanel).last,
      matching: find.byTooltip('꾸미기'),
    );
    await tester.ensureVisible(decorate);
    await tester.tap(decorate);
    await _paint(tester);
    expect(find.byType(ImageFrameStylePicker), findsOneWidget);
  }

  Future<void> openReplacementGallery(WidgetTester tester) async {
    final change = find.descendant(
      of: find.byType(LayerActionPanel).last,
      matching: find.byTooltip('사진변경'),
    );
    await tester.ensureVisible(change);
    await tester.tap(change);
    await _paint(tester);
    expect(
      find.byKey(const ValueKey('gallery-photo-replacement-photo')),
      findsOneWidget,
    );
  }

  Future<void> pickReplacement(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('gallery-photo-replacement-photo')),
    );
    await waitForCropPhoto(tester);
    await _paint(tester);
  }

  for (final pageIndex in [0, 1]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          'photo replacement previews before atomic apply page=$pageIndex $size dark=$dark',
          (tester) async {
            final gallery = _ReplacementGallery();
            final original = _photo().copyWith(
              imageZoom: 2.2,
              imageOffset: const Offset(40, -30),
            );
            final session = await boot(
              tester,
              size,
              dark,
              pageIndex,
              gallery: gallery,
              photo: original,
              safeArea: size.width > size.height
                  ? const EdgeInsets.only(left: 44, right: 24, bottom: 24)
                  : const EdgeInsets.only(top: 24, bottom: 24),
            );
            await openReplacementGallery(tester);
            await pickReplacement(tester);
            final sheet = tester.widget<PhotoCropSheet>(
              find.byType(PhotoCropSheet),
            );
            expect(sheet.title, '사진 바꾸기');
            expect(sheet.frameBuilder, isNotNull);
            expect(sheet.layer.asset, same(gallery.photo));
            expect(sheet.layer.imageBackground, original.imageBackground);
            expect(sheet.layer.imageZoom, 1);
            expect(sheet.layer.imageOffset, isNull);
            expect(sheet.layer.previewUrl, isNull);
            expect(session.vm.layers.single, same(original));
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('photo-crop-apply')))
                  .bottom,
              lessThanOrEqualTo(size.height - 24),
            );
            await tester.tap(find.text('취소'));
            await _paint(tester);
            expect(session.vm.layers.single, same(original));

            await openReplacementGallery(tester);
            await pickReplacement(tester);
            await tester.tap(find.byTooltip('사진 확대'));
            await tester.drag(
              find.byKey(const ValueKey('photo-crop-preview')),
              const Offset(20, -10),
            );
            await _paint(tester);
            if (pageIndex == 1)
              await _capture(
                tester,
                session.capture,
                'editor-photo-replace-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
              );
            await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
            await _paint(tester);
            final applied = session.vm.layers.single;
            expect(applied.asset, same(gallery.photo));
            expect(applied.imageZoom, closeTo(1.1, .001));
            expect(applied.imageOffset, isNot(Offset.zero));
            expect(applied.imageBackground, original.imageBackground);
            expect(applied.imageTemplate, original.imageTemplate);
            expect(applied.width, original.width);
            expect(applied.height, original.height);
            expect(applied.position, original.position);
            expect(applied.rotation, original.rotation);
            expect(applied.opacity, original.opacity);
            expect(applied.previewUrl, isNull);
            expect(applied.imageUrl, isNull);
            expect(applied.originalUrl, isNull);
            expect(gallery.refreshes, 2);
            session.vm.undo();
            await _paint(tester);
            expect(session.vm.layers.single.asset, isNull);
            expect(session.vm.layers.single.previewUrl, original.previewUrl);
            expect(session.vm.layers.single.imageZoom, 2.2);
            expect(session.vm.layers.single.imageOffset, original.imageOffset);
            session.vm.redo();
            await _paint(tester);
            expect(session.vm.layers.single.asset, same(gallery.photo));
            expect(session.vm.layers.single.imageZoom, closeTo(1.1, .001));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'replacement gallery opens immediately while permission is pending',
    (tester) async {
      final permission = Completer<bool>();
      final gallery = _ReplacementGallery(permission: permission);
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        1,
        gallery: gallery,
      );
      final original = session.vm.layers.single;
      await tester.tap(find.byTooltip('사진변경'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('사진 선택 닫기'), findsOneWidget);
      expect(gallery.refreshes, 0);
      permission.complete(false);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('사진 선택 닫기'));
      await _paint(tester);
      expect(session.vm.layers.single, same(original));
      session.vm.undo();
      expect(session.vm.layers.single, same(original));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filling an empty slot confirms the photo inside its existing frame',
    (tester) async {
      final gallery = _ReplacementGallery();
      final empty = _photo().copyWith(clearImage: true);
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        1,
        gallery: gallery,
        photo: empty,
      );
      await openReplacementGallery(tester);
      await pickReplacement(tester);
      expect(
        tester.widget<PhotoCropSheet>(find.byType(PhotoCropSheet)).title,
        '사진 넣기',
      );
      expect(session.vm.layers.single, same(empty));
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await _paint(tester);
      expect(session.vm.layers.single.asset, same(gallery.photo));
      expect(session.vm.layers.single.imageBackground, empty.imageBackground);
      session.vm.undo();
      await _paint(tester);
      expect(session.vm.layers.single.asset, isNull);
      expect(session.vm.layers.single.previewUrl, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phase in ['gallery', 'crop']) {
    for (final changePage in [false, true]) {
      testWidgets(
        'stale replacement is rejected during $phase changePage=$changePage',
        (tester) async {
          final session = await boot(
            tester,
            const Size(844, 390),
            false,
            1,
            gallery: _ReplacementGallery(),
          );
          final original = session.vm.layers.single;
          await openReplacementGallery(tester);
          if (phase == 'crop') await pickReplacement(tester);
          if (changePage) session.vm.goToPage(2);
          final newer = original.copyWith(imageZoom: 3);
          session.vm.updatePageLayers([newer], recordHistory: false);
          await tester.pump();
          await tester.tap(
            phase == 'crop'
                ? find.byKey(const ValueKey('photo-crop-apply'))
                : find.byKey(const ValueKey('gallery-photo-replacement-photo')),
          );
          await _paint(tester);
          expect(find.byType(PhotoCropSheet), findsNothing);
          expect(session.vm.layers.single, same(newer));
          if (changePage)
            expect(session.vm.pages[1].layers.single, same(original));
          expect(find.text('페이지가 변경됐어요. 사진을 다시 선택해주세요.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final cancelSizePicker in [true, false]) {
    testWidgets(
      'photo addition honors size-picker cancellation and page changes cancel=$cancelSizePicker',
      (tester) async {
        final session = await boot(
          tester,
          const Size(390, 844),
          false,
          1,
          gallery: _ReplacementGallery(),
        );
        final original = session.vm.layers.single;
        final state = tester.state<ConsumerState<PageEditorScreen>>(
          find.byType(PageEditorScreen),
        );
        final task = ToolbarActionHandler(
          state.context,
          state.ref,
        ).addPhoto(const Size(500, 500));
        await _paint(tester);
        await tester.tap(
          find.byKey(const ValueKey('gallery-photo-replacement-photo')),
        );
        await _paint(tester);
        expect(find.byType(ImageTemplatePicker), findsOneWidget);
        if (cancelSizePicker) {
          await tester.tap(find.byTooltip('닫기'));
        } else {
          session.vm.goToPage(2);
          await tester.pump();
          await tester.tap(find.text('원본'));
        }
        await _paint(tester);
        await task;
        expect(session.vm.pages[1].layers.single, same(original));
        if (cancelSizePicker) {
          session.vm.undo();
          expect(session.vm.layers.single, same(original));
        } else {
          expect(session.vm.layers, isEmpty);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> searchFrame(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('소재 검색'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('editor-material-search')),
      label,
    );
    await _paint(tester);
  }

  testWidgets('frame apply is one undo step and retains the photo crop', (
    tester,
  ) async {
    final photo = _photo().copyWith(
      imageZoom: 2,
      imageOffset: const Offset(40, -30),
    );
    final session = await boot(
      tester,
      const Size(390, 844),
      false,
      1,
      photo: photo,
    );
    await openFrames(tester);
    await searchFrame(tester, '자수 코너 매트');
    await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
    await _paint(tester);
    final applied = session.vm.layers.single;
    expect(applied.imageBackground, 'materialLaceMount');
    expect(applied.imageZoom, photo.imageZoom);
    expect(applied.imageOffset, photo.imageOffset);
    expect(applied.position, photo.position);
    expect(applied.width, photo.width);
    expect(applied.height, photo.height);
    expect(applied.previewUrl, photo.previewUrl);
    session.vm.undo();
    await _paint(tester);
    expect(session.vm.layers.single.imageBackground, photo.imageBackground);
    expect(session.vm.layers.single.imageZoom, 2);
    session.vm.redo();
    await _paint(tester);
    expect(session.vm.layers.single.imageBackground, 'materialLaceMount');
    expect(tester.takeException(), isNull);
  });

  testWidgets('same frame selection does not add an undo entry', (
    tester,
  ) async {
    final photo = _photo().copyWith(imageBackground: 'materialLaceMount');
    final session = await boot(
      tester,
      const Size(390, 844),
      false,
      1,
      photo: photo,
    );
    await openFrames(tester);
    await searchFrame(tester, '자수 코너 매트');
    await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
    await _paint(tester);
    expect(session.vm.layers.single, same(photo));
    session.vm.undo();
    expect(session.vm.layers.single, same(photo));
  });

  testWidgets(
    'unapproved paid frame leaves the picker and document unchanged',
    (tester) async {
      final requests = <String>[];
      final session = await boot(
        tester,
        const Size(390, 844),
        true,
        1,
        frameAccess:
            (context, ref, {required productKey, required title}) async {
              requests.add(productKey);
              return false;
            },
      );
      final original = session.vm.layers.single;
      await openFrames(tester);
      await searchFrame(tester, '자수 코너 매트');
      expect(find.text('300P'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
      await _paint(tester);
      expect(requests, ['frame:materialLaceMount']);
      expect(find.byType(ImageFrameStylePicker), findsOneWidget);
      expect(session.vm.layers.single, same(original));
      await tester.tap(find.byTooltip('닫기'));
      await _paint(tester);
    },
  );

  for (final changePage in [false, true]) {
    testWidgets(
      'stale frame selection cannot overwrite an edit changePage=$changePage',
      (tester) async {
        final session = await boot(tester, const Size(844, 390), false, 1);
        final original = session.vm.layers.single;
        await openFrames(tester);
        await searchFrame(tester, '자수 코너 매트');
        if (changePage) session.vm.goToPage(2);
        session.vm.updatePageLayers([original.copyWith(imageZoom: 2.5)]);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
        await _paint(tester);
        expect(session.vm.layers.single.imageZoom, 2.5);
        expect(
          session.vm.layers.single.imageBackground,
          original.imageBackground,
        );
        if (changePage)
          expect(session.vm.pages[1].layers.single, same(original));
        expect(find.text('페이지가 변경됐어요. 사진을 다시 선택해주세요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty photo slot never substitutes a catalog sample', (
    tester,
  ) async {
    final empty = _photo().copyWith(clearImage: true);
    final session = await boot(
      tester,
      const Size(390, 844),
      true,
      1,
      photo: empty,
    );
    await openFrames(tester);
    final previews = find.byType(EditorPhotoFramePreview);
    expect(previews, findsWidgets);
    expect(
      find.descendant(of: previews, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: previews,
        matching: find.byIcon(Icons.add_photo_alternate_outlined),
      ),
      findsWidgets,
    );
    expect(session.vm.layers.single, same(empty));
    await tester.tap(find.byTooltip('닫기'));
    await _paint(tester);
  });

  testWidgets(
    'legacy frame preview uses the same size and crop alignment as apply',
    (tester) async {
      final photo = _photo().copyWith(
        imageZoom: 2,
        imageOffset: const Offset(50, -20),
      );
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        1,
        photo: photo,
      );
      await openFrames(tester);
      await searchFrame(tester, '폴라로이드');
      final preview = find.descendant(
        of: find.byKey(const ValueKey('frame-polaroidWide')),
        matching: find.byType(PhotoCropViewport),
      );
      final expectedPage = AlbumPage(
        id: 'expected',
        layers: [photo],
        pageIndex: 1,
      );
      const AlbumEditorService().updateImageFrame(
        page: expectedPage,
        id: photo.id,
        frameKey: 'polaroidWide',
      );
      final expected = expectedPage.layers.single;
      final crop = tester.widget<PhotoCropViewport>(preview);
      expect(crop.layer.width, expected.width);
      expect(crop.layer.height, expected.height);
      expect(crop.layer.imageAlignment, expected.imageAlignment);
      expect(session.vm.layers.single, same(photo));
      await tester.tap(find.byKey(const ValueKey('frame-polaroidWide')));
      await _paint(tester);
      expect(session.vm.layers.single.width, expected.width);
      expect(session.vm.layers.single.imageOffset, photo.imageOffset);
      expect(session.vm.layers.single.imageZoom, photo.imageZoom);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'frame preview source priority preserves local, saved and original images',
    (tester) async {
      await boot(tester, const Size(390, 844), false, 1);
      final canvas = tester.widget<PageEditorCanvas>(
        find.byType(PageEditorCanvas),
      );
      final context = tester.element(find.byType(PageEditorCanvas));
      Widget sourceWithin(Widget widget) {
        if (widget is Image || widget is SnapfitImage) return widget;
        if (widget is Builder) return sourceWithin(widget.builder(context));
        if (widget is DefaultTextStyle) return sourceWithin(widget.child);
        if (widget is PhotoCropViewport) return sourceWithin(widget.child);
        if (widget is SingleChildRenderObjectWidget && widget.child != null) {
          return sourceWithin(widget.child!);
        }
        throw StateError('Unexpected frame wrapper: ${widget.runtimeType}');
      }

      Widget photoContent(LayerModel photo) {
        return sourceWithin(
          EditorPhotoFramePreview(
            layer: photo,
            frameKey: '',
            layerBuilder: canvas.layerBuilder,
          ).build(context),
        );
      }

      final local = AssetEntity(
        id: 'local-photo',
        typeInt: 1,
        width: 1200,
        height: 1800,
      );
      final localImage = photoContent(_photo().copyWith(asset: local)) as Image;
      final localProvider =
          (localImage.image as ResizeImage).imageProvider
              as AssetEntityImageProvider;
      expect(localProvider.entity, same(local));
      expect(localProvider.isOriginal, isTrue);
      for (final source in ['preview', 'image', 'original']) {
        final photo = _photo()
            .copyWith(clearImage: true)
            .copyWith(
              previewUrl: source == 'preview'
                  ? 'https://example.test/preview.jpg'
                  : '',
              imageUrl: source != 'original'
                  ? 'https://example.test/image.jpg'
                  : '',
              originalUrl: 'https://example.test/original.jpg',
            );
        final image = photoContent(photo) as SnapfitImage;
        expect(image.urlOrGs, 'https://example.test/$source.jpg');
        expect(image.memCacheWidth, 640);
        expect(image.alignment, photo.imageAlignment);
      }
      final originalOnly = _photo()
          .copyWith(clearImage: true)
          .copyWith(originalUrl: 'asset:assets/snapfit_home_square.jpg');
      final bundled = photoContent(originalOnly) as Image;
      expect(
        ((bundled.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/snapfit_home_square.jpg',
      );
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('creation cover frame picker uses the real photo $size', (
      tester,
    ) async {
      final gallery = _ReplacementGallery();
      final session = await boot(tester, size, false, 0, gallery: gallery);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PageEditorScreen)),
      );
      final photo = _photo().copyWith(
        imageZoom: 1.6,
        imageOffset: const Offset(40, -20),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(
              theme: SnapFitTheme.light(),
              home: AddCoverScreen(
                isFromCreateFlow: true,
                initialCoverSize: session.vm.selectedCover,
                initialTemplateCoverLayers: [photo],
                initialTemplateCanvasSize: const Size(500, 500),
                debugInitialSelectedLayerId: photo.id,
              ),
            ),
          ),
        ),
      );
      await _paint(tester);
      final original = session.vm.layers.single;
      await openFrames(tester);
      for (final preview in tester.widgetList<EditorPhotoFramePreview>(
        find.byType(EditorPhotoFramePreview),
      )) {
        expect(preview.layer, same(original));
        expect(preview.layer.imageZoom, 1.6);
      }
      await searchFrame(tester, '자수 코너 매트');
      await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
      await _paint(tester);
      expect(session.vm.layers.single.imageBackground, 'materialLaceMount');
      expect(session.vm.layers.single.imageZoom, 1.6);
      expect(session.vm.layers.single.imageOffset, original.imageOffset);
      final beforeReplacement = session.vm.layers.single;
      await openReplacementGallery(tester);
      await pickReplacement(tester);
      expect(session.vm.layers.single, same(beforeReplacement));
      await tester.tap(find.byTooltip('사진 확대'));
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await _paint(tester);
      expect(session.vm.layers.single.asset, same(gallery.photo));
      expect(session.vm.layers.single.imageZoom, closeTo(1.1, .001));
      expect(session.vm.layers.single.imageBackground, 'materialLaceMount');
      expect(session.vm.layers.single.originalUrl, isNull);
      session.vm.undo();
      await _paint(tester);
      expect(session.vm.layers.single.previewUrl, beforeReplacement.previewUrl);
      expect(session.vm.layers.single.imageZoom, beforeReplacement.imageZoom);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'empty saved preview URL falls back to the original in canvas and picker',
    (tester) async {
      final photo = _photo().copyWith(previewUrl: '', imageUrl: '');
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        1,
        photo: photo,
      );
      final canvas = find.byType(PageEditorCanvas);
      final image = tester.widget<Image>(
        find.descendant(of: canvas, matching: find.byType(Image)).first,
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/snapfit_home_square.jpg',
      );
      await openFrames(tester);
      final pickerImages = tester.widgetList<Image>(
        find.descendant(
          of: find.byType(EditorPhotoFramePreview),
          matching: find.byType(Image),
        ),
      );
      expect(pickerImages, isNotEmpty);
      for (final preview in pickerImages) {
        expect(
          ((preview.image as ResizeImage).imageProvider as AssetImage)
              .assetName,
          'assets/snapfit_home_square.jpg',
        );
      }
      expect(session.vm.layers.single, same(photo));
      await tester.tap(find.byTooltip('닫기'));
      await _paint(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final pageIndex in [0, 1]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          'frame previews match selected cropped photo on page $pageIndex $size dark=$dark',
          (tester) async {
            final photo = _photo().copyWith(
              imageZoom: 1.8,
              imageOffset: const Offset(40, -30),
            );
            final session = await boot(
              tester,
              size,
              dark,
              pageIndex,
              photo: photo,
            );
            await openFrames(tester);
            final previews = tester.widgetList<EditorPhotoFramePreview>(
              find.byType(EditorPhotoFramePreview),
            );
            expect(previews, isNotEmpty);
            for (final preview in previews) {
              expect(preview.layer, same(photo));
              final crop = tester.widget<PhotoCropViewport>(
                find.descendant(
                  of: find.byWidget(preview),
                  matching: find.byType(PhotoCropViewport),
                ),
              );
              expect(crop.layer.imageZoom, 1.8);
              expect(crop.layer.imageOffset, photo.imageOffset);
              expect(crop.layer.previewUrl, photo.previewUrl);
              final image = tester.widget<Image>(
                find
                    .descendant(
                      of: find.byWidget(preview),
                      matching: find.byType(Image),
                    )
                    .first,
              );
              expect(image.alignment, crop.layer.imageAlignment);
              final provider = image.image as ResizeImage;
              expect(
                (provider.imageProvider as AssetImage).assetName,
                'assets/snapfit_home_square.jpg',
              );
              expect(provider.policy, ResizeImagePolicy.fit);
              expect(provider.width, 960);
            }
            expect(session.vm.layers.single, same(photo));
            if (pageIndex == 1)
              await _capture(
                tester,
                session.capture,
                'editor-frame-preview-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
              );
            await tester.tap(find.byTooltip('닫기'));
            await _paint(tester);
            expect(session.vm.layers.single, same(photo));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final pageIndex in [0, 1]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      for (final dark in [false, true]) {
        testWidgets(
          'saved photo crop is atomic on page $pageIndex $size dark=$dark',
          (tester) async {
            final session = await boot(tester, size, dark, pageIndex);
            final original = session.vm.layers.single;
            expect(find.byTooltip('사진 구도'), findsOneWidget);
            expect(
              tester.getSize(find.byTooltip('사진 구도')).height,
              greaterThanOrEqualTo(44),
            );
            final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
            if (pageIndex == 1)
              await _capture(
                tester,
                session.capture,
                'editor-photo-actions-$suffix',
              );
            await tester.tap(find.byTooltip('사진 구도'));
            await waitForCropPhoto(tester);
            await tester.tap(find.byTooltip('사진 확대'));
            await tester.drag(
              find.byKey(const ValueKey('photo-crop-preview')),
              const Offset(30, -20),
            );
            await _paint(tester);
            expect(session.vm.layers.single, same(original));
            if (pageIndex == 1)
              await _capture(
                tester,
                session.capture,
                'editor-photo-crop-$suffix',
              );
            await tester.tap(find.text('취소'));
            await _paint(tester);
            expect(session.vm.layers.single, same(original));

            await tester.tap(find.byTooltip('사진 구도'));
            await waitForCropPhoto(tester);
            await tester.tap(find.byTooltip('사진 확대'));
            await tester.drag(
              find.byKey(const ValueKey('photo-crop-preview')),
              const Offset(30, -20),
            );
            await _paint(tester);
            await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
            await _paint(tester);
            final cropped = session.vm.layers.single;
            expect(cropped.imageZoom, closeTo(1.1, .001));
            expect(cropped.imageOffset, isNot(Offset.zero));
            expect(cropped.imageBackground, original.imageBackground);
            expect(cropped.imageTemplate, original.imageTemplate);
            expect(cropped.position, original.position);
            expect(cropped.rotation, original.rotation);
            expect(cropped.width, original.width);
            expect(cropped.height, original.height);
            expect(cropped.previewUrl, original.previewUrl);
            expect(cropped.opacity, original.opacity);
            session.vm.undo();
            await _paint(tester);
            expect(session.vm.layers.single.imageZoom, original.imageZoom);
            expect(session.vm.layers.single.imageOffset, original.imageOffset);
            session.vm.redo();
            await _paint(tester);
            expect(session.vm.layers.single.imageZoom, cropped.imageZoom);
            expect(session.vm.layers.single.imageOffset, cropped.imageOffset);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('unchanged crop creates no undo entry', (tester) async {
    final session = await boot(tester, const Size(390, 844), false, 1);
    final original = session.vm.layers.single;
    await tester.tap(find.byTooltip('사진 구도'));
    await waitForCropPhoto(tester);
    await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
    await _paint(tester);
    expect(session.vm.layers.single, same(original));
    session.vm.undo();
    expect(session.vm.layers.single, same(original));
  });

  testWidgets(
    'stale crop cannot overwrite a different page or a newer photo edit',
    (tester) async {
      final session = await boot(tester, const Size(844, 390), false, 1);
      final original = session.vm.layers.single;
      await tester.tap(find.byTooltip('사진 구도'));
      await waitForCropPhoto(tester);
      await tester.tap(find.byTooltip('사진 확대'));
      session.vm.goToPage(2);
      session.vm.updatePageLayers([original.copyWith(imageZoom: 2)]);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await _paint(tester);
      expect(session.vm.layers.single.imageZoom, 2);
      expect(session.vm.pages[1].layers.single.imageZoom, 1);
      expect(find.text('페이지가 변경됐어요. 사진을 다시 선택해주세요.'), findsOneWidget);

      session.vm.goToPage(1);
      await _paint(tester);
      tester
          .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
          .interaction
          .setSelectedLayer('saved-photo');
      await _paint(tester);
      final panel = tester.widget<LayerActionPanel>(
        find.byType(LayerActionPanel),
      );
      panel.onOpenPhotoCrop!(original);
      await waitForCropPhoto(tester);
      await tester.tap(find.byTooltip('사진 확대'));
      session.vm.updateLayer(original.copyWith(imageZoom: 2.5));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await _paint(tester);
      expect(session.vm.layers.single.imageZoom, 2.5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('creation cover exposes the same photo composition tool', (
    tester,
  ) async {
    final gallery = _ReplacementGallery();
    final session = await boot(
      tester,
      const Size(844, 390),
      false,
      0,
      gallery: gallery,
    );
    final context = tester.element(find.byType(PageEditorScreen));
    final scope = ProviderScope.containerOf(context);
    LayerInteractionManager? interaction;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => StatefulBuilder(
                  builder: (_, setState) {
                    interaction ??= LayerInteractionManager(
                      ref: ref,
                      coverKey: GlobalKey(),
                      setState: setState,
                      getCoverSize: () => const Size(500, 666.67),
                      onEditText: (_) {},
                    );
                    return EditCover(
                      initialCoverSize: session.vm.selectedCover,
                      isFromCreateFlow: true,
                      interaction: interaction,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _paint(tester);
    interaction!.setSelectedLayer('saved-photo');
    await _paint(tester);
    expect(find.byType(LayerActionPanel), findsOneWidget);
    final actionRect = tester.getRect(find.byType(LayerActionPanel));
    final photoButton = tester.getRect(find.byIcon(Icons.photo_outlined));
    expect(actionRect.bottom, lessThanOrEqualTo(photoButton.top));
    await tester.tap(find.byTooltip('사진 구도'));
    await waitForCropPhoto(tester);
    await tester.tap(find.byTooltip('사진 확대'));
    await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
    await _paint(tester);
    expect(session.vm.layers.single.imageZoom, closeTo(1.1, .001));
    final photo = session.vm.layers.single;
    await openFrames(tester);
    for (final preview in tester.widgetList<EditorPhotoFramePreview>(
      find.byType(EditorPhotoFramePreview),
    )) {
      expect(preview.layer, same(photo));
      expect(preview.layer.imageZoom, closeTo(1.1, .001));
    }
    await searchFrame(tester, '자수 코너 매트');
    await tester.tap(find.byKey(const ValueKey('frame-materialLaceMount')));
    await _paint(tester);
    expect(session.vm.layers.single.imageBackground, 'materialLaceMount');
    expect(session.vm.layers.single.imageZoom, photo.imageZoom);
    final original = session.vm.layers.single;
    await openReplacementGallery(tester);
    await pickReplacement(tester);
    expect(session.vm.layers.single, same(original));
    await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
    await _paint(tester);
    expect(session.vm.layers.single.asset, same(gallery.photo));
    expect(session.vm.layers.single.imageBackground, original.imageBackground);
    expect(session.vm.layers.single.imageZoom, 1);
    session.vm.undo();
    await _paint(tester);
    expect(session.vm.layers.single.previewUrl, original.previewUrl);
    expect(session.vm.layers.single.imageZoom, original.imageZoom);
    expect(tester.takeException(), isNull);
  });
}

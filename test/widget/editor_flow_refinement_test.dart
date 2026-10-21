import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/text_editor_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_action_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/template_selection_panel.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'package:snap_fit/shared/widgets/gallery_thumb_tile.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../fixtures/ai_template_design_fixture.dart';
import '../unit/catalog_favorites_test.dart' show MemoryFavoritesStorage;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Photo extends Mock implements AssetEntity {}

class _Album extends Mock implements AssetPathEntity {}

class _Gallery extends Mock implements GalleryRepository {}

class _Editor extends AlbumEditorViewModel {
  final applied = <String>[];
  String pageId = 'page-original';
  final original = LayerModel(
    id: 'original',
    type: LayerType.image,
    position: const Offset(30, 40),
    width: 250,
    height: 200,
  );
  @override
  AlbumEditorState build() => AlbumEditorState(layers: [original]);
  @override
  AlbumPage? get currentPage =>
      AlbumPage(id: pageId, layers: [original], pageIndex: 1);
  @override
  void applyTemplateToCurrentPage(PageTemplate template, Size size) =>
      applied.add(template.id);
}

late Uint8List _photoBytes;
AssetEntity _photo(String id) {
  final asset = _Photo();
  when(() => asset.id).thenReturn(id);
  when(() => asset.width).thenReturn(0);
  when(() => asset.height).thenReturn(0);
  when(() => asset.orientation).thenReturn(0);
  when(
    () => asset.file,
  ).thenAnswer((_) async => File('assets/snapfit_home_square.jpg'));
  when(
    () => asset.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => _photoBytes);
  return asset;
}

Widget _app(
  Widget child, {
  required bool dark,
  GlobalKey? capture,
  _Editor? editor,
  GalleryRepository? gallery,
  double textScale = 1,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    albumEditorViewModelProvider.overrideWith(() => editor ?? _Editor()),
    if (gallery != null) galleryRepositoryProvider.overrideWithValue(gallery),
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
    ownedPointShopKeysProvider.overrideWith(
      (ref) async => {'frame:materialLaceMount'},
    ),
    pointShopAccessGateProvider.overrideWithValue(
      (context, ref, {required productKey, required title}) async => true,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, body) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: capture, child: body!),
      ),
      home: Scaffold(body: child),
    ),
  ),
);

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  var decoded = false;
  Object? decodeError;
  StackTrace? decodeStack;
  // A resized file image may have begun decoding in FakeAsync before this call.
  await tester.runAsync(() async {
    Future.wait<void>([
      for (final element in find.byType(Image).evaluate())
        precacheImage((element.widget as Image).image, element),
    ]).then(
      (_) => decoded = true,
      onError: (Object error, StackTrace stack) {
        decodeError = error;
        decodeStack = stack;
        decoded = true;
      },
    );
  });
  for (var attempt = 0; !decoded && attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(decoded, isTrue, reason: 'Photo preview decoding did not complete.');
  if (decodeError != null)
    Error.throwWithStackTrace(decodeError!, decodeStack!);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EDITOR_FLOW_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'output/editor-flow-qa/$name'
      '${const String.fromEnvironment('DESIGN_SYSTEM_REVISION')}.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
}

void main() {
  _PaintBinding();
  late CatalogFavorites previous;
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    _photoBytes = await File('assets/snapfit_home_square.jpg').readAsBytes();
  });
  setUp(() async {
    previous = CatalogFavorites.instance;
    CatalogFavorites.instance = CatalogFavorites(
      storage: MemoryFavoritesStorage(),
    );
    await CatalogFavorites.instance.load();
  });
  tearDown(() {
    CatalogFavorites.instance.dispose();
    CatalogFavorites.instance = previous;
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('photo selection and manual batch placement $suffix', (
        tester,
      ) async {
        _size(tester, size);
        final key = GlobalKey();
        final first = _Album(), second = _Album();
        when(() => first.id).thenReturn('first');
        when(() => first.name).thenReturn('Recent');
        when(() => first.isAll).thenReturn(true);
        when(() => second.id).thenReturn('second');
        when(() => second.name).thenReturn('가족과 여행의 소중한 추억 사진첩');
        when(() => second.isAll).thenReturn(false);
        final photos = List.generate(12, (i) => _photo('$i'));
        final gallery = _Gallery();
        when(() => gallery.requestPermission()).thenAnswer((_) async => true);
        when(
          () => gallery.loadAlbums(),
        ).thenAnswer((_) async => [first, second]);
        when(
          () => gallery.loadImagesPaged(first, 0, 40),
        ).thenAnswer((_) async => photos.take(6).toList());
        when(
          () => gallery.loadImagesPaged(second, 0, 40),
        ).thenAnswer((_) async => photos.skip(6).toList());
        List<AssetEntity>? selection;
        await tester.pumpWidget(
          _app(
            Consumer(
              builder: (context, ref, _) => Center(
                child: FilledButton(
                  onPressed: () async =>
                      selection = await showPhotosSelectionSheet(
                        context,
                        ref,
                        maxSelection: 4,
                      ),
                  child: const Text('사진 추가'),
                ),
              ),
            ),
            dark: dark,
            capture: key,
            gallery: gallery,
          ),
        );
        await tester.tap(find.text('사진 추가'));
        await _paint(tester);
        for (final id in ['0', '1', '2']) {
          await tester.tap(find.byKey(ValueKey('gallery-photo-$id')));
          await tester.pump();
        }
        await _capture(tester, key, 'gallery-$suffix');
        await tester.tap(find.byKey(const ValueKey('gallery-album-switch')));
        await _paint(tester);
        await tester.tap(find.byKey(const ValueKey('gallery-album-second')));
        await _paint(tester);
        expect(find.byKey(const ValueKey('gallery-photo-0')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('gallery-photo-6')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('gallery-photo-7')));
        await tester.pump();
        expect(find.text('한 번에 최대 4장까지 선택할 수 있어요.'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('confirm-gallery-selection')),
        );
        await _paint(tester);
        expect(selection!.map((p) => p.id), ['0', '1', '2', '6']);

        final design = templateDesignDraft().design!;
        var pages = design.buildLayers(
          targetSize: coverCanvasBaseSize(design.coverSize),
        );
        final original = pages[0].firstWhere(
          (layer) => layer.type == LayerType.image,
        );
        var changes = 0;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) => TemplatePhotoFillStep(
                pages: pages,
                cover: design.coverSize,
                onChanged: (value) => setState(() {
                  pages = value;
                  changes++;
                }),
                onContinue: () {},
                pickPhotos: () async => selection,
              ),
            ),
            dark: dark,
            capture: key,
          ),
        );
        final renderer = find.byType(TemplatePhotoFillStep);
        final fill = tester.widget<TemplatePhotoFillStep>(renderer);
        final view = tester.widget<TemplatePageRenderer>(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is TemplatePageRenderer && widget.onLayerTap != null,
              )
              .first,
        );
        await tester.runAsync(() async {
          final image = FileImage(File('assets/snapfit_home_square.jpg'));
          for (final width in {192, view.imageDecodeWidth!}) {
            await precacheImage(
              ResizeImage(image, width: width),
              tester.element(renderer),
            );
          }
        });
        await tester.tap(find.text('사진 추가'));
        await _paint(tester);
        expect(changes, 0);
        expect(pages.expand((p) => p).where((l) => l.asset != null), isEmpty);
        await _capture(tester, key, 'photo-tray-$suffix');
        await tester.tap(find.byKey(const ValueKey('tray-photo-1')));
        await tester.pump();
        view.onLayerTap!(original.id);
        await _paint(tester);
        expect(changes, 1);
        final placed = pages[0].firstWhere(
          (layer) => layer.type == LayerType.image,
        );
        expect(placed.asset?.id, '1');
        expect(placed.position, original.position);
        expect(placed.width, original.width);
        expect(placed.height, original.height);
        expect(fill.cover, design.coverSize);
        await _capture(tester, key, 'photo-filled-$suffix');
        await tester.tap(find.byTooltip('사진 구도 조정'));
        await waitForCropPhoto(tester);
        await _paint(tester);
        expect(find.byType(PhotoCropSheet), findsOneWidget);
        await tester.tap(find.byTooltip('사진 확대'));
        await tester.drag(
          find.byKey(const ValueKey('photo-crop-preview')),
          const Offset(-30, 15),
        );
        await _paint(tester);
        expect(changes, 1);
        await _capture(tester, key, 'photo-crop-$suffix');
        await tester.tap(find.text('취소'));
        await _paint(tester);
        expect(changes, 1);
        expect(pages[0].firstWhere((l) => l.id == original.id).imageZoom, 1);
        await tester.tap(find.byTooltip('사진 구도 조정'));
        await waitForCropPhoto(tester);
        await _paint(tester);
        await tester.tap(find.byTooltip('사진 확대'));
        await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await _paint(tester);
        expect(changes, 2);
        final cropped = pages[0].firstWhere((l) => l.id == original.id);
        expect(cropped.imageZoom, closeTo(1.1, .001));
        expect(cropped.position, original.position);
        expect(cropped.width, original.width);
        expect(cropped.imageBackground, original.imageBackground);
        await tester.tap(find.byKey(const ValueKey('fill-next-empty')));
        await _paint(tester);
        expect(changes, 2);
        final mainView = tester.widget<TemplatePageRenderer>(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is TemplatePageRenderer && widget.onLayerTap != null,
              )
              .first,
        );
        expect(mainView.selectedLayerId, isNotNull);
        expect(
          mainView.layers.any(
            (l) => l.id == mainView.selectedLayerId && l.asset == null,
          ),
          isTrue,
        );
        await _capture(tester, key, 'photo-next-empty-$suffix');
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('photo-fill-page-rail')),
            )
            .controller!
            .jumpTo(0);
        await _paint(tester);
        await tester.tap(find.byKey(const ValueKey('fill-page-0')));
        await _paint(tester);
        tester
            .widget<TemplatePageRenderer>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is TemplatePageRenderer &&
                        widget.onLayerTap != null,
                  )
                  .first,
            )
            .onLayerTap!(original.id);
        await _paint(tester);
        expect(
          changes,
          2,
        ); // Selecting a filled slot never silently replaces it.
        await tester.tap(find.byTooltip('사진 교체'));
        await _paint(tester);
        expect(changes, 3);
        await tester.tap(find.byTooltip('사진 제거'));
        await _paint(tester);
        expect(changes, 4);
        final removed = pages[0].firstWhere((l) => l.id == original.id);
        expect(removed.asset, isNull);
        expect(removed.imageZoom, 1);
        expect(removed.imageBackground, original.imageBackground);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'layout preview cancels without editing and applies explicitly $suffix',
        (tester) async {
          final semantics = tester.ensureSemantics();
          _size(tester, size);
          final key = GlobalKey(), editor = _Editor();
          await tester.pumpWidget(
            _app(
              const TemplateSelectionPanel(closeOnApply: false),
              dark: dark,
              capture: key,
              editor: editor,
            ),
          );
          await _paint(tester);
          final layoutCard = find.byWidgetPredicate(
            (widget) =>
                widget is SnapFitPressable &&
                widget.semanticLabel == '${pageTemplates.first.name} 레이아웃 미리보기',
          );
          expect(
            tester
                .getSemantics(layoutCard)
                .hasFlag(ui.SemanticsFlag.hasSelectedState),
            isTrue,
          );
          expect(
            tester
                .getSemantics(layoutCard)
                .hasFlag(ui.SemanticsFlag.isSelected),
            isFalse,
          );
          await tester.tap(find.text(pageTemplates.first.name));
          await _paint(tester);
          expect(editor.applied, isEmpty);
          expect(find.text('현재 쪽의 사진과 문구가 교체됩니다.'), findsOneWidget);
          await _capture(tester, key, 'layout-preview-$suffix');
          final button = tester.getRect(
            find.byKey(const ValueKey('confirm-template-apply')),
          );
          expect(button.bottom, lessThanOrEqualTo(size.height - 24));
          await tester.tap(find.byTooltip('미리보기 닫기'));
          await _paint(tester);
          expect(editor.applied, isEmpty);
          await tester.tap(find.text(pageTemplates.first.name));
          await _paint(tester);
          await tester.tap(
            find.byKey(const ValueKey('confirm-template-apply')),
          );
          await _paint(tester);
          expect(editor.applied, [pageTemplates.first.id]);
          expect(
            tester
                .getSemantics(layoutCard)
                .hasFlag(ui.SemanticsFlag.isSelected),
            isTrue,
          );
          expect(find.byType(TemplateSelectionPanel), findsOneWidget);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );

      testWidgets(
        'frame price, search and owned filters preserve application $suffix',
        (tester) async {
          _size(tester, size);
          final key = GlobalKey();
          var applied = '';
          await tester.pumpWidget(
            _app(
              ImageFrameStylePicker(
                selectedKey: null,
                onSelect: (value) => applied = value,
              ),
              dark: dark,
              capture: key,
            ),
          );
          await _paint(tester);
          await _capture(tester, key, 'frames-$suffix');
          final priceMenu = find.byType(DropdownButton<String>);
          if (priceMenu.evaluate().isNotEmpty) {
            await tester.ensureVisible(priceMenu);
            await tester.pumpAndSettle();
            await tester.tap(priceMenu);
            await tester.pumpAndSettle();
            await tester.tap(find.text('보유').last);
          } else {
            expect(
              find.widgetWithText(SegmentedButton<String>, '보유'),
              findsOneWidget,
            );
            await tester.ensureVisible(find.text('보유'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('보유'));
          }
          await _paint(tester);
          expect(find.text('자수 코너 매트'), findsOneWidget);
          expect(find.byType(CatalogFavoriteButton), findsOneWidget);
          await tester.tap(find.byTooltip('소재 검색'));
          await _paint(tester);
          await tester.enterText(
            find.byKey(const ValueKey('editor-material-search')),
            '자수',
          );
          await _paint(tester);
          await _capture(tester, key, 'frame-search-$suffix');
          expect(applied, '');
          await tester.tap(find.text('자수 코너 매트'));
          await _paint(tester);
          expect(applied, 'materialLaceMount');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('layer actions are legible with 44px targets $suffix', (
        tester,
      ) async {
        _size(tester, size);
        final key = GlobalKey();
        LayerInteractionManager? interaction;
        await tester.pumpWidget(
          _app(
            Consumer(
              builder: (context, ref, _) => StatefulBuilder(
                builder: (context, setState) {
                  interaction ??= LayerInteractionManager(
                    ref: ref,
                    coverKey: GlobalKey(),
                    setState: setState,
                    getCoverSize: () => const Size(500, 500),
                    onEditText: (_) {},
                  );
                  final layer = LayerModel(
                    id: 'photo',
                    type: LayerType.image,
                    position: Offset.zero,
                    width: 200,
                    height: 200,
                  );
                  return SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayerActionPanel(
                          layers: [layer],
                          interaction: interaction!,
                          textEditor: TextEditorManager(
                            context,
                            ref.read(albumEditorViewModelProvider.notifier),
                          ),
                          onRefresh: () => setState(() {}),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            dark: dark,
            capture: key,
          ),
        );
        interaction!.setSelectedLayer('photo');
        await _paint(tester);
        final icon = tester.widget<Icon>(find.byIcon(Icons.image_outlined));
        final context = tester.element(find.byType(LayerActionPanel));
        expect(icon.color, ExperienceFormStyle.ink(context));
        for (final label in ['사진변경', '사진위치', '불투명도', '꾸미기', '삭제']) {
          final target = tester.getSize(find.byTooltip(label));
          expect(target.width, greaterThanOrEqualTo(44));
          expect(target.height, greaterThanOrEqualTo(44));
        }
        await _capture(tester, key, 'tools-$suffix');
        await tester.tap(find.byTooltip('불투명도'));
        await _paint(tester);
        expect(find.byType(Slider), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'changing the current page while previewing prevents applying to another page',
    (tester) async {
      _size(tester, const Size(390, 844));
      final editor = _Editor();
      await tester.pumpWidget(
        _app(
          const TemplateSelectionPanel(closeOnApply: false),
          dark: false,
          editor: editor,
        ),
      );
      await _paint(tester);
      await tester.tap(find.text(pageTemplates.first.name));
      await _paint(tester);
      editor.pageId = 'another-page';
      await tester.tap(find.byKey(const ValueKey('confirm-template-apply')));
      await _paint(tester);
      expect(editor.applied, isEmpty);
    },
  );

  testWidgets('batch photo selection and the current spread survive rotation', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final photos = [_photo('batch-first'), _photo('batch-second')];
    final design = templateDesignDraft().design!;
    var pages = design.buildLayers(
      targetSize: coverCanvasBaseSize(design.coverSize),
    );
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => TemplatePhotoFillStep(
            pages: pages,
            cover: design.coverSize,
            onChanged: (value) => setState(() => pages = value),
            onContinue: () {},
            pickPhotos: () async => photos,
          ),
        ),
        dark: true,
      ),
    );
    await tester.tap(find.text('사진 추가'));
    await _paint(tester);
    await tester.tap(find.byKey(const ValueKey('tray-photo-batch-second')));
    await tester.tap(find.byKey(const ValueKey('fill-page-3')));
    await _paint(tester);
    tester.view.physicalSize = const Size(844, 390);
    await _paint(tester);
    expect(
      find.byKey(const ValueKey('tray-photo-batch-second')),
      findsOneWidget,
    );
    expect(find.textContaining('3–4쪽'), findsOneWidget);
    final preview = tester.widget<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer).first,
    );
    await tester.runAsync(() async {
      final image = FileImage(File('assets/snapfit_home_square.jpg'));
      for (final width in [192, preview.imageDecodeWidth!])
        await precacheImage(
          ResizeImage(image, width: width),
          tester.element(find.byType(TemplatePhotoFillStep)),
        );
    });
    preview.onLayerTap!(
      pages[3].firstWhere((layer) => layer.type == LayerType.image).id,
    );
    await _paint(tester);
    expect(
      pages[3].firstWhere((layer) => layer.type == LayerType.image).asset,
      photos[1],
    );
    expect(pages[0].where((layer) => layer.asset != null), isEmpty);
    expect(
      find.byKey(const ValueKey('tray-photo-batch-first')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('선택한 사진 제외'));
    await _paint(tester);
    expect(find.byKey(const ValueKey('photo-fill-tray')), findsNothing);
    expect(
      pages[3].firstWhere((layer) => layer.type == LayerType.image).asset,
      photos[1],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed thumbnail becomes a placeholder, not an endless loading indicator',
    (tester) async {
      final photo = _photo('unavailable');
      when(
        () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
      ).thenThrow(StateError('deleted'));
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: GalleryThumbTile(
                asset: photo,
                isSelected: false,
                simpleMode: true,
              ),
            ),
          ),
          dark: true,
        ),
      );
      await _paint(tester);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .state<GalleryThumbTileState>(find.byType(GalleryThumbTile))
            .wantKeepAlive,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

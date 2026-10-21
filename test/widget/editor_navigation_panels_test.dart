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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_inner_detail_screen.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/reader_page_gallery.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_list_selector.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'album_creation_draft_flow_test.dart' show MemoryCreationDraftStore;
import 'home_screen_test.dart' show FakeAuthViewModel;

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Photo extends Mock implements AssetEntity {}

class _Interaction extends Mock implements LayerInteractionManager {
  String? selected;
  List<LayerModel>? reordered;
  @override
  String? get selectedLayerId => selected;
  @override
  void setSelectedLayer(String id) => selected = id;
  @override
  void syncZOrder(List<LayerModel> layers) => reordered = layers;
}

List<LayerModel> _layers(int page) {
  final flower = studioDecorationById('studioPressedCosmos')!;
  return [
    LayerModel(
      id: 'paper-$page',
      type: LayerType.decoration,
      position: Offset.zero,
      width: 500,
      height: 500,
      imageBackground: 'studioCottonRag',
    ),
    LayerModel(
      id: 'photo-$page',
      type: LayerType.image,
      position: const Offset(50, 50),
      width: 400,
      height: 290,
      imageUrl: page.isEven
          ? 'asset:assets/snapfit_home_landscape.jpg'
          : 'asset:assets/snapfit_home_square.jpg',
      zIndex: 1,
    ),
    LayerModel(
      id: 'caption-$page',
      type: LayerType.text,
      position: const Offset(54, 370),
      width: 390,
      height: 60,
      text: '서로의 계절',
      textStyle: const TextStyle(fontSize: 28, color: Color(0xFF253B36)),
      zIndex: 2,
    ),
    LayerModel(
      id: 'flower-$page',
      type: flower.assetPath == null ? LayerType.decoration : LayerType.sticker,
      position: const Offset(356, 342),
      width: 80,
      height: 100,
      imageBackground: flower.assetPath == null ? flower.id : null,
      imageUrl: flower.assetPath == null ? null : 'asset:${flower.assetPath}',
      zIndex: 3,
    ),
  ];
}

Future<ProviderContainer> _container({
  int inner = 24,
  CoverSize cover = defaultCoverSize,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      albumCreationDraftStoreProvider.overrideWithValue(
        MemoryCreationDraftStore(),
      ),
      authViewModelProvider.overrideWith(
        () => FakeAuthViewModel(
          const UserInfo(id: 'panels', name: '테스트', provider: 'email'),
        ),
      ),
    ],
  );
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  container
      .read(albumEditorViewModelProvider.notifier)
      .startLocalTemplateAlbum(
        albumTitle: '서로의 계절',
        initialCover: cover,
        templateCanvasSize: Size(500, 500 / cover.ratio),
        pages: [for (var page = 0; page <= inner; page++) _layers(page)],
      );
  // Existing albums retain legacy ratios even though new albums use print products.
  container.read(albumEditorViewModelProvider.notifier).selectCover(cover);
  return container;
}

Widget _app(
  ProviderContainer container,
  Widget child, {
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
}) => UncontrolledProviderScope(
  container: container,
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: child,
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
  if (!const bool.fromEnvironment('EDITOR_PANELS_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _Binding();
  setUpAll(() async {
    await loadCreationFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'real editor page rail and layer selection $size dark=$dark',
        (tester) async {
          _size(tester, size);
          final container = await _container();
          addTearDown(container.dispose);
          final vm = container.read(albumEditorViewModelProvider.notifier);
          final key = GlobalKey();
          final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
          await tester.pumpWidget(
            _app(
              container,
              const PageEditorScreen(initialPageIndex: 17),
              dark: dark,
              capture: key,
            ),
          );
          await _paint(tester);
          expect(
            find.byKey(const ValueKey('editor-page-17')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('addInnerPagesButton')).hitTestable(),
            findsOneWidget,
          );
          final delete = tester.getRect(
            find.byKey(const ValueKey('deleteCurrentInnerPageButton')),
          );
          expect(delete.width, greaterThanOrEqualTo(44));
          expect(delete.height, greaterThanOrEqualTo(44));
          await _capture(tester, key, 'editor-pages-$suffix');
          await tester.ensureVisible(find.byTooltip('레이어'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('레이어'));
          await _paint(tester);
          final panel = find.byType(LayerManagerPanel);
          expect(panel, findsOneWidget);
          await _capture(tester, key, 'editor-layers-$suffix');
          final caption = find.descendant(
            of: panel,
            matching: find.byKey(const ValueKey('caption-17')),
          );
          await tester.ensureVisible(caption);
          await tester.pumpAndSettle();
          await tester.tap(caption);
          await tester.pumpAndSettle();
          expect(find.byType(PageEditorScreen), findsOneWidget);
          if (size.width > size.height) {
            expect(panel, findsOneWidget);
            expect(
              tester.widget<Semantics>(caption).properties.selected,
              isTrue,
            );
          } else {
            expect(panel, findsNothing);
          }
          expect(vm.currentPageIndex, 17);
          expect(
            vm.currentPage!.layers
                .firstWhere((layer) => layer.id == 'caption-17')
                .text,
            '서로의 계절',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('actual page inspection edits the viewed page at $size', (
      tester,
    ) async {
      _size(tester, size);
      final container = await _container();
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final capture = GlobalKey();
      await tester.pumpWidget(
        _app(
          container,
          Consumer(
            builder: (context, ref, _) {
              const base = Size(500, 500);
              final preview = LayerInteractionManager.preview(ref, () => base);
              return AlbumReaderInnerDetailScreen(
                innerPages: vm.pages.skip(1).toList(),
                initialPageIndex: 2,
                singlePageW: 500,
                singlePageH: 500,
                interaction: preview,
                layerBuilder: LayerBuilder(preview, () => base),
              );
            },
          ),
          dark: size.width > size.height,
          capture: capture,
        ),
      );
      await _paint(tester);
      expect(find.text('3 / 24'), findsOneWidget);
      await _capture(tester, capture, 'page-inspection-${size.width.toInt()}');
      await tester.tap(find.byTooltip('다음 페이지'));
      await _paint(tester);
      expect(find.text('4 / 24'), findsOneWidget);
      await tester.tap(find.byTooltip('현재 페이지 편집'));
      await _paint(tester);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(vm.currentPageIndex, 4);
      Navigator.of(tester.element(find.byType(PageEditorScreen))).pop(false);
      await _paint(tester);
      expect(find.byType(ReaderPageGallery), findsOneWidget);
      expect(find.text('4 / 24'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final cover in [...legacyCoverSizes, coverSizes[2]]) {
    testWidgets(
      'editor spread, history and rotation keep ${cover.ratio} artwork',
      (tester) async {
        _size(tester, const Size(390, 844));
        final container = await _container(cover: cover);
        addTearDown(container.dispose);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final capture = GlobalKey();
        await tester.pumpWidget(
          _app(
            container,
            const PageEditorScreen(initialPageIndex: 3),
            capture: capture,
          ),
        );
        await _paint(tester);
        final original = vm.currentPage!.layers[1];
        final canvas = find.byType(PageEditorCanvas);
        var rect = tester.getRect(canvas);
        expect(rect.width / rect.height, closeTo(cover.ratio, .001));
        expect(find.byTooltip('되돌리기'), findsOneWidget);
        expect(find.byTooltip('다시하기'), findsOneWidget);
        vm.updatePageBackgroundColor(0xFFE5EDE9);
        await _paint(tester);
        await tester.tap(find.byTooltip('되돌리기'));
        await _paint(tester);
        expect(vm.currentPage!.backgroundColor, isNull);
        await tester.tap(find.byTooltip('다시하기'));
        await _paint(tester);
        expect(vm.currentPage!.backgroundColor, 0xFFE5EDE9);
        tester.view.physicalSize = const Size(844, 390);
        tester.view.padding = const FakeViewPadding(
          left: 44,
          right: 24,
          bottom: 24,
        );
        await _paint(tester);
        expect(vm.currentPageIndex, 3);
        rect = tester.getRect(canvas);
        expect(rect.width / rect.height, closeTo(cover.ratio, .001));
        final spread = tester.getRect(
          find.byKey(const ValueKey('editor-open-spread')),
        );
        expect(spread.width, closeTo(rect.width * 2, .01));
        expect(spread.left, greaterThanOrEqualTo(124));
        expect(spread.right, lessThanOrEqualTo(748));
        expect(spread.bottom, lessThanOrEqualTo(366));
        final photo = vm.currentPage!.layers[1];
        expect(photo.position, original.position);
        expect(photo.width, original.width);
        expect(photo.height, original.height);
        final facing = find.byKey(const ValueKey('editor-facing-page-4'));
        expect(facing.hitTestable(), findsOneWidget);
        await tester.tap(facing);
        await _paint(tester);
        expect(vm.currentPageIndex, 4);
        await _capture(
          tester,
          capture,
          'editor-spread-${cover.ratio.toStringAsFixed(2)}-844-light',
        );
        await tester.tap(find.byKey(const ValueKey('editor-facing-page-3')));
        await _paint(tester);
        expect(vm.currentPageIndex, 3);
        expect(vm.currentPage!.backgroundColor, 0xFFE5EDE9);
        await tester.tap(find.byTooltip('되돌리기'));
        await _paint(tester);
        expect(vm.currentPage!.backgroundColor, isNull);
        expect(
          find.byKey(const ValueKey('editor-save-album')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'editor panels stay usable with large text and system insets $size',
      (tester) async {
        _size(tester, size);
        final container = await _container();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _app(
            container,
            const PageEditorScreen(initialPageIndex: 12),
            scale: 1.5,
          ),
        );
        await _paint(tester);
        expect(
          find.byKey(const ValueKey('editor-page-12')).hitTestable(),
          findsOneWidget,
        );
        final addRect = tester.getRect(
          find.byKey(const Key('addInnerPagesButton')),
        );
        expect(addRect.width, greaterThanOrEqualTo(44));
        expect(addRect.bottom, lessThanOrEqualTo(size.height - 24));
        await tester.ensureVisible(find.byTooltip('레이어'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('레이어'));
        await _paint(tester);
        final panel = find.byType(LayerManagerPanel);
        expect(panel, findsOneWidget);
        final caption = find.descendant(
          of: panel,
          matching: find.byKey(const ValueKey('caption-12')),
        );
        await tester.scrollUntilVisible(
          caption,
          64,
          scrollable: find
              .descendant(of: panel, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(caption);
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(
          container
              .read(albumEditorViewModelProvider.notifier)
              .currentPageIndex,
          12,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'layer panel sees in-place list replacement and keeps an empty state',
    (tester) async {
      _size(tester, const Size(390, 844));
      final container = await _container();
      addTearDown(container.dispose);
      final interaction = _Interaction();
      final layers = [
        LayerModel(
          id: 'copy',
          type: LayerType.text,
          position: Offset.zero,
          text: '이전 문구',
        ),
      ];
      Widget panel() => _app(
        container,
        Scaffold(
          body: LayerManagerPanel(
            layers: layers,
            interaction: interaction,
            showHandle: false,
          ),
        ),
      );
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      layers[0] = layers[0].copyWith(text: '새로운 문구');
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(find.text('새로운 문구'), findsOneWidget);
      expect(find.text('이전 문구'), findsNothing);
      layers.clear();
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(find.text('아직 추가한 요소가 없어요'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '80-page editor rail follows distant changes and rotation without eager construction',
    (tester) async {
      _size(tester, const Size(390, 844));
      final container = await _container(inner: 80);
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.goToPage(78);
      await tester.pumpWidget(
        _app(
          container,
          Consumer(
            builder: (context, ref, _) {
              ref.watch(albumEditorViewModelProvider);
              return Scaffold(
                body: SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width:
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape
                          ? 78
                          : double.infinity,
                      child: PageListSelector(
                        pages: vm.pages,
                        currentPageIndex: vm.currentPageIndex,
                        onPageSelected: vm.goToPage,
                        onAddPage: null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await _paint(tester);
      expect(
        find.byKey(const ValueKey('editor-page-78')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('editor-page-0')), findsNothing);
      expect(find.byKey(const ValueKey('editor-page-1')), findsNothing);
      final initialRect = tester.getRect(
        find.byKey(const ValueKey('editor-page-frame-78')),
      );
      await tester.tap(find.byKey(const ValueKey('editor-page-77')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('editor-page-frame-78'))).size,
        initialRect.size,
      );
      vm.goToPage(2);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('editor-page-2')).hitTestable(),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(vm.currentPageIndex, 2);
      expect(
        find.byKey(const ValueKey('editor-page-2')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('layer reorder still records undo and syncs canvas order', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final container = await _container();
    addTearDown(container.dispose);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    vm.goToPage(1);
    final original = vm.currentPage!.layers.map((layer) => layer.id).toList();
    final interaction = _Interaction();
    await tester.pumpWidget(
      _app(
        container,
        Consumer(
          builder: (context, ref, _) {
            final layers = ref
                .watch(albumEditorViewModelProvider)
                .requireValue
                .layers;
            return Scaffold(
              body: LayerManagerPanel(
                layers: layers,
                interaction: interaction,
                showHandle: false,
              ),
            );
          },
        ),
      ),
    );
    await _paint(tester);
    await tester.drag(
      find.byType(ReorderableDragStartListener).first,
      const Offset(0, 156),
    );
    await tester.pumpAndSettle();
    expect(
      vm.currentPage!.layers.map((layer) => layer.id),
      isNot(orderedEquals(original)),
    );
    expect(
      interaction.reordered!.map((layer) => layer.id),
      orderedEquals(vm.currentPage!.layers.map((layer) => layer.id)),
    );
    vm.undo();
    await tester.pumpAndSettle();
    expect(
      vm.currentPage!.layers.map((layer) => layer.id),
      orderedEquals(original),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same layer id refreshes replaced photo and edited wording without repeated thumbnail requests',
    (tester) async {
      _size(tester, const Size(390, 844));
      final container = await _container();
      addTearDown(container.dispose);
      final first = _Photo(), second = _Photo();
      final firstBytes = (await tester.runAsync(
        () => File('assets/snapfit_home_square.jpg').readAsBytes(),
      ))!;
      final secondBytes = (await tester.runAsync(
        () => File('assets/snapfit_home_portrait.jpg').readAsBytes(),
      ))!;
      when(() => first.id).thenReturn('first');
      when(() => second.id).thenReturn('second');
      when(
        () => first.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).thenAnswer((_) async => firstBytes);
      when(
        () => second.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).thenAnswer((_) async => secondBytes);
      final interaction = _Interaction();
      Widget panel(AssetEntity photo, String text) => _app(
        container,
        Scaffold(
          body: LayerManagerPanel(
            showHandle: false,
            interaction: interaction,
            layers: [
              LayerModel(
                id: 'photo',
                type: LayerType.image,
                position: Offset.zero,
                asset: photo,
              ),
              LayerModel(
                id: 'copy',
                type: LayerType.text,
                position: Offset.zero,
                text: text,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(panel(first, '이전 문구'));
      await _paint(tester);
      await tester.pumpWidget(panel(second, '새로운 문구'));
      await _paint(tester);
      expect(find.text('새로운 문구'), findsOneWidget);
      expect(find.text('이전 문구'), findsNothing);
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect((provider.imageProvider as MemoryImage).bytes, same(secondBytes));
      await tester.tap(find.byKey(const ValueKey('photo')));
      await _paint(tester);
      expect(interaction.selected, 'photo');
      verify(
        () => first.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).called(1);
      verify(
        () => second.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );
}

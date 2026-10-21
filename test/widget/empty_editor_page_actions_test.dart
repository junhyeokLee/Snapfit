import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/toolbar_action_handler.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/cover_view_model.dart';
import 'package:snap_fit/features/album/presentation/utils/open_print_photo_editor.dart';
import 'package:snap_fit/features/album/presentation/utils/print_photo_issue.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/design_template_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/shared/widgets/album_bottom_sheet.dart';
import 'package:snap_fit/shared/widgets/editor_modal_scope.dart';

import '../helpers/mock_repositories.dart';
import '../helpers/fake_album.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _Photo extends Mock implements AssetEntity {}

class _Gallery extends Mock implements GalleryRepository {}

class _Interaction extends Mock implements LayerInteractionManager {}

// Layer pixels are irrelevant to guide/focus behavior; no photo decoding or
// preview files are needed for these structural checks.
class _LayerBuilder extends LayerBuilder {
  _LayerBuilder(LayerInteractionManager interaction)
    : super(interaction, () => const Size(500, 500));
  @override
  Widget buildImage(
    LayerModel layer, {
    bool isCover = false,
    bool wrapSpine = false,
  }) => SizedBox(key: ValueKey('drawn-${layer.id}'));
  @override
  Widget buildText(LayerModel layer, {bool isCover = false}) =>
      SizedBox(key: ValueKey('drawn-${layer.id}'));
}

_Interaction _interaction({bool preview = false}) {
  final interaction = _Interaction();
  when(() => interaction.enableWebTransforms).thenReturn(false);
  when(() => interaction.isPreviewMode).thenReturn(preview);
  when(() => interaction.isInteractingNow).thenReturn(false);
  when(
    () => interaction.sortByZ(any()),
  ).thenAnswer((call) => call.positionalArguments.first as List<LayerModel>);
  return interaction;
}

Widget _canvas({
  required _Interaction interaction,
  Size size = const Size(300, 320),
  List<LayerModel> layers = const [],
  VoidCallback? photo,
  VoidCallback? design,
  bool enabled = true,
}) => PageEditorCanvas(
  canvasKey: GlobalKey(),
  canvasW: size.width,
  canvasH: size.height,
  layers: layers,
  interaction: interaction,
  layerBuilder: _LayerBuilder(interaction),
  onCanvasSizeChanged: (_) {},
  onAddPhoto: photo,
  onChooseDesign: design,
  emptyPageActionsEnabled: enabled,
);

Widget _app(Widget child, {double scale = 1, ProviderContainer? container}) {
  final body = ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      theme: SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child is PageEditorScreen || child is PrintPhotoCorrectionEditor
          ? child
          : Scaffold(body: Center(child: child)),
    ),
  );
  return container == null
      ? body
      : UncontrolledProviderScope(container: container, child: body);
}

Future<ProviderContainer> _container({
  List<List<LayerModel>>? pages,
  String? Function()? visibleOwner,
  GalleryRepository? gallery,
}) async {
  final container = ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      pointShopCatalogProvider.overrideWith((ref) async => []),
      ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
      designTemplateCatalogProvider.overrideWith((ref) async => []),
      if (visibleOwner != null)
        visibleOrderOwnerProvider.overrideWith((ref) => visibleOwner()),
      if (gallery != null) galleryRepositoryProvider.overrideWithValue(gallery),
    ],
  );
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  vm.startLocalTemplateAlbum(
    albumTitle: '빈 페이지 안내 검사',
    initialCover: defaultCoverSize,
    pages: pages ?? [[], []],
  );
  vm.goToPage(1);
  return container;
}

Album _correctionAlbum() => fakeAlbum(
  id: 81,
  ratio: '1',
  totalPages: 2,
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': []},
      {'index': 1, 'isCover': false, 'layers': []},
      {
        'index': 2,
        'isCover': false,
        'layers': [
          LayerExportMapper.toJson(
            LayerModel(
              id: 'correction-photo',
              type: LayerType.image,
              position: const Offset(40, 40),
              width: 160,
              height: 120,
            ),
            canvasSize: const Size(500, 500),
          ),
        ],
      },
    ],
  }),
).copyWith(title: '사진 수정 앨범', userId: 'owner', memberRole: 'OWNER');

const _correctionTarget = PrintPhotoEditTarget(
  pageIndex: 2,
  layerId: 'correction-photo',
  reviewedRevision: 'reviewed-fixture',
);

Future<void> _tapEmptyEditorAction(
  WidgetTester tester, {
  required bool photo,
}) async {
  final direct = find.byKey(
    ValueKey(photo ? 'empty-page-add-photo' : 'empty-page-choose-design'),
  );
  if (direct.evaluate().isNotEmpty) {
    await tester.ensureVisible(direct);
    await tester.pumpAndSettle();
    expect(direct.hitTestable(), findsOneWidget);
    await tester.tap(direct);
  } else {
    // Selecting a photo can leave the web inspector open after changing pages.
    // Its smaller canvas exposes the same first actions through an add menu.
    final menu = find.byKey(const ValueKey('empty-page-actions-menu'));
    expect(menu, findsOneWidget);
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    expect(menu.hitTestable(), findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final choice = find.text(photo ? '사진 넣기' : '디자인 고르기');
    expect(choice.hitTestable(), findsOneWidget);
    await tester.tap(choice);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    registerFallbackValue(<LayerModel>[]);
    if (!kIsWeb) await loadCreationFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<
    ({
      ProviderContainer parent,
      ProviderContainer child,
      String parentDocument,
      CoverState parentCover,
    })
  >
  mountCorrection(WidgetTester tester, String? Function() owner) async {
    viewport(tester);
    final gallery = _Gallery();
    when(() => gallery.requestPermission()).thenAnswer((_) async => false);
    final parent = await _container(visibleOwner: owner, gallery: gallery);
    addTearDown(parent.dispose);
    await parent.read(coverViewModelProvider.future);
    final parentVm = parent.read(albumEditorViewModelProvider.notifier);
    parentVm.selectCover(coverSizes[1]);
    parentVm.updatePageLayers([
      LayerModel(
        id: 'parent-note',
        type: LayerType.text,
        position: const Offset(20, 30),
        width: 200,
        height: 40,
        text: '배경 앨범의 문구',
      ),
    ]);
    parent
        .read(coverViewModelProvider.notifier)
        .updateTheme(CoverTheme.classic2);
    final document = parentVm.exportFullAlbumLayersJson(null);
    final cover = parent.read(coverViewModelProvider).asData!.value;
    await tester.pumpWidget(
      _app(
        PrintPhotoCorrectionEditor(
          album: _correctionAlbum(),
          target: _correctionTarget,
          expectedOwner: 'owner',
        ),
        container: parent,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PageEditorScreen), findsOneWidget);
    final child = ProviderScope.containerOf(
      tester.element(find.byType(PageEditorScreen)),
      listen: false,
    );
    return (
      parent: parent,
      child: child,
      parentDocument: document,
      parentCover: cover,
    );
  }

  testWidgets(
    'print correction isolates parent editor and cover while focusing its photo',
    (tester) async {
      final fixture = await mountCorrection(tester, () => 'owner');
      final parentVm = fixture.parent.read(
        albumEditorViewModelProvider.notifier,
      );
      final childVm = fixture.child.read(albumEditorViewModelProvider.notifier);
      expect(identical(childVm, parentVm), isFalse);
      expect(childVm.editingAlbumId, 81);
      expect(childVm.currentPageIndex, 2);
      expect(
        tester
            .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
            .interaction
            .selectedLayerId,
        'correction-photo',
      );
      expect(parentVm.exportFullAlbumLayersJson(null), fixture.parentDocument);
      expect(parentVm.currentPageIndex, 1);
      expect(parentVm.editingAlbumId, isNull);
      expect(
        fixture.parent.read(coverViewModelProvider).asData!.value,
        fixture.parentCover,
      );
      expect(
        identical(
          fixture.child.read(coverViewModelProvider.notifier),
          fixture.parent.read(coverViewModelProvider.notifier),
        ),
        isFalse,
      );
      expect(
        fixture.child
            .read(coverViewModelProvider)
            .asData!
            .value
            .selectedCover
            .ratio,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change removes correction editor and its open tool popup',
    (tester) async {
      String? owner = 'owner';
      final fixture = await mountCorrection(tester, () => owner);
      fixture.child.read(albumEditorViewModelProvider.notifier).goToPage(1);
      await tester.pumpAndSettle();
      await _tapEmptyEditorAction(tester, photo: false);
      await tester.pumpAndSettle();
      expect(find.byType(DesignTemplatePanel), findsOneWidget);
      owner = 'other-owner';
      fixture.parent.invalidate(visibleOrderOwnerProvider);
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsNothing);
      expect(find.byType(DesignTemplatePanel), findsNothing);
      expect(find.text('로그인 상태가 바뀌었어요. 다시 앨범을 열어 주세요.'), findsOneWidget);
      expect(
        fixture.parent
            .read(albumEditorViewModelProvider.notifier)
            .exportFullAlbumLayersJson(null),
        fixture.parentDocument,
      );
      expect(
        fixture.parent.read(coverViewModelProvider).asData!.value,
        fixture.parentCover,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'correction design photo and cover popups retain the child editor scope',
    (tester) async {
      final fixture = await mountCorrection(tester, () => 'owner');
      final childVm = fixture.child.read(albumEditorViewModelProvider.notifier);
      childVm.goToPage(1);
      await tester.pumpAndSettle();
      final editorElement = tester.element(find.byType(PageEditorScreen));
      final routeName = editorModalRouteName(editorElement);
      void checkPopup(Finder finder) {
        expect(finder, findsOneWidget);
        final element = tester.element(finder);
        final scope = ProviderScope.containerOf(element, listen: false);
        expect(
          identical(scope.read(albumEditorViewModelProvider.notifier), childVm),
          isTrue,
        );
        expect(
          scope.read(albumEditorViewModelProvider.notifier).editingAlbumId,
          81,
        );
        expect(
          identical(
            scope.read(coverViewModelProvider.notifier),
            fixture.child.read(coverViewModelProvider.notifier),
          ),
          isTrue,
        );
        expect(ModalRoute.of(element)!.settings.name, routeName);
      }

      await _tapEmptyEditorAction(tester, photo: false);
      await tester.pumpAndSettle();
      checkPopup(find.byType(DesignTemplatePanel));
      Navigator.of(tester.element(find.byType(DesignTemplatePanel))).pop();
      await tester.pumpAndSettle();
      // Native photo selection owns a Consumer sheet; browser selection instead
      // delegates to the platform file chooser and has no editor-model Consumer.
      if (!kIsWeb) {
        await _tapEmptyEditorAction(tester, photo: true);
        await tester.pumpAndSettle();
        checkPopup(find.byType(GalleryEmptyOrErrorPanel));
        Navigator.of(
          tester.element(find.byType(GalleryEmptyOrErrorPanel)),
        ).pop();
        await tester.pumpAndSettle();
      }
      final theme = ToolbarActionHandler(
        editorElement,
        editorElement as WidgetRef,
      ).openCoverTheme();
      await tester.pumpAndSettle();
      checkPopup(find.byType(EditCoverTheme));
      Navigator.of(tester.element(find.byType(EditCoverTheme))).pop();
      await tester.pumpAndSettle();
      await theme;
      expect(
        fixture.parent
            .read(albumEditorViewModelProvider.notifier)
            .exportFullAlbumLayersJson(null),
        fixture.parentDocument,
      );
      expect(
        fixture.parent.read(coverViewModelProvider).asData!.value,
        fixture.parentCover,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final systemBack in [false, true]) {
    testWidgets(
      'cancel correction returns to print review without changing parent: system=$systemBack',
      (tester) async {
        viewport(tester);
        final parent = await _container(visibleOwner: () => 'owner');
        addTearDown(parent.dispose);
        final parentVm = parent.read(albumEditorViewModelProvider.notifier);
        final before = parentVm.exportFullAlbumLayersJson(null);
        var completed = false;
        bool? result;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PrintPhotoCorrectionEditor(
                        album: _correctionAlbum(),
                        target: _correctionTarget,
                        expectedOwner: 'owner',
                      ),
                    ),
                  );
                  completed = true;
                },
                child: const Text('인쇄 검토에서 사진 수정'),
              ),
            ),
            container: parent,
          ),
        );
        await tester.tap(find.text('인쇄 검토에서 사진 수정'));
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip(kIsWeb ? '편집 나가기' : '편집 마치기'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsNothing);
        expect(find.text('인쇄 검토에서 사진 수정'), findsOneWidget);
        expect(completed, isTrue);
        expect(result, isFalse);
        expect(parentVm.exportFullAlbumLayersJson(null), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty page actions are keyboard reachable and disabled while saving',
    (tester) async {
      viewport(tester);
      var photos = 0, designs = 0;
      final interaction = _interaction();
      await tester.pumpWidget(
        _app(
          _canvas(
            interaction: interaction,
            photo: () => photos++,
            design: () => designs++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(photos, 1);
      expect(designs, 1);
      await tester.pumpWidget(
        _app(
          _canvas(
            interaction: interaction,
            photo: () => photos++,
            design: () => designs++,
            enabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('empty-page-add-photo')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('empty-page-choose-design')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('사진 넣기'));
      await tester.tap(find.text('디자인 고르기'));
      expect(photos, 1);
      expect(designs, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only previews never offer editing even with callbacks', (
    tester,
  ) async {
    viewport(tester);
    final semantics = tester.ensureSemantics();
    try {
      var actions = 0;
      await tester.pumpWidget(
        _app(
          _canvas(
            interaction: _interaction(preview: true),
            photo: () => actions++,
            design: () => actions++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty-page-guide')), findsNothing);
      expect(
        find.byKey(const ValueKey('empty-page-actions-menu')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('빈 페이지'), findsOneWidget);
      expect(actions, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final size in [
    const Size(96, 80),
    const Size(180, 160),
    const Size(300, 240),
  ]) {
    testWidgets('empty page actions fit $size at 240 percent text', (
      tester,
    ) async {
      viewport(tester);
      var photos = 0, designs = 0;
      await tester.pumpWidget(
        _app(
          _canvas(
            interaction: _interaction(),
            size: size,
            photo: () => photos++,
            design: () => designs++,
          ),
          scale: 2.4,
        ),
      );
      await tester.pumpAndSettle();
      final compact = find.byKey(const ValueKey('empty-page-actions-menu'));
      for (final label in ['사진 넣기', '디자인 고르기']) {
        if (compact.evaluate().isNotEmpty) {
          await tester.tap(compact);
          await tester.pumpAndSettle();
        } else {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
        }
        expect(find.text(label).hitTestable(), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(photos, 1);
      expect(designs, 1);
    });
  }

  testWidgets(
    'photo insertion removes guide without saving chrome in the document',
    (tester) async {
      viewport(tester);
      final container = await _container();
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.exportFullAlbumLayersJson(null);
      final asset = _Photo();
      when(() => asset.id).thenReturn('inserted-photo');
      when(() => asset.width).thenReturn(1800);
      when(() => asset.height).thenReturn(1400);
      when(() => asset.orientation).thenReturn(0);
      final interaction = _interaction();
      await tester.pumpWidget(
        _app(
          Consumer(
            builder: (context, ref, _) {
              final layers =
                  ref.watch(albumEditorViewModelProvider).value?.layers ??
                  const <LayerModel>[];
              return _canvas(
                interaction: interaction,
                layers: layers,
                photo: () => ToolbarActionHandler(
                  context,
                  ref,
                  selectPhoto: (_, _) async => asset,
                  selectTemplate: (_) async => 'free',
                ).addPhoto(),
                design: () {},
              );
            },
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty-page-guide')), findsOneWidget);
      expect(vm.exportFullAlbumLayersJson(null), before);
      await tester.tap(find.text('사진 넣기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('empty-page-guide')), findsNothing);
      expect(vm.currentPage!.layers.single.id, 'inserted-photo');
      final exported = vm.exportFullAlbumLayersJson(null);
      final document = PrintAlbumDocument.fromSnapshot({
        'album': {
          'id': 1,
          'title': 'test',
          'ratio': '1',
          'cover_layers_json': jsonDecode(exported),
        },
        'pages': const [],
      });
      expect(document.interiors.first.layers.single.id, 'inserted-photo');
      expect(exported, isNot(contains('빈 페이지를 채워보세요')));
      expect(exported, isNot(contains('디자인 고르기')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty editor design action opens existing guarded template panel',
    (tester) async {
      viewport(tester);
      final container = await _container();
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.exportFullAlbumLayersJson(null);
      await tester.pumpWidget(
        _app(const PageEditorScreen(initialPageIndex: 1), container: container),
      );
      await tester.pumpAndSettle();
      await _tapEmptyEditorAction(tester, photo: false);
      await tester.pumpAndSettle();
      expect(find.byType(DesignTemplatePanel), findsOneWidget);
      expect(vm.exportFullAlbumLayersJson(null), before);
      expect(tester.takeException(), isNull);
    },
  );

  final photo = LayerModel(
    id: 'target-photo',
    type: LayerType.image,
    position: const Offset(40, 40),
    width: 160,
    height: 120,
  );
  final text = LayerModel(
    id: 'target-text',
    type: LayerType.text,
    position: const Offset(40, 190),
    width: 160,
    height: 40,
    text: '문구',
  );
  for (final target in ['target-photo', 'missing-photo', 'target-text']) {
    testWidgets('initial photo focus is page-scoped and one-time: $target', (
      tester,
    ) async {
      viewport(tester);
      final container = await _container(
        pages: [
          [],
          [],
          [photo, text],
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.exportFullAlbumLayersJson(null);
      await tester.pumpWidget(
        _app(
          PageEditorScreen(initialPageIndex: 2, initialSelectedLayerId: target),
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      final interaction = tester
          .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
          .interaction;
      expect(vm.currentPageIndex, 2);
      expect(
        interaction.selectedLayerId,
        target == 'target-photo' ? target : null,
      );
      expect(vm.exportFullAlbumLayersJson(null), before);
      vm.goToPage(1);
      await tester.pumpAndSettle();
      vm.goToPage(2);
      await tester.pumpAndSettle();
      expect(interaction.selectedLayerId, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}

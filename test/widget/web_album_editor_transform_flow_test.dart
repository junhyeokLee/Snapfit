import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/design_templates.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/edit_cover.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_keyboard_shortcuts.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/selection_frame.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/template_selection_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/design_template_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/decorate_color_tab.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_editor_tool_dialog.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_layer_transform_inspector.dart';
import 'package:snap_fit/features/album/presentation/widgets/web/web_album_workspace.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

/// Exercises the production route with a local album; no auth, payment, storage
/// or printing requests are needed to verify document editing.
class _EditorBoot extends ConsumerStatefulWidget {
  const _EditorBoot({required this.page});
  final int page;

  @override
  ConsumerState<_EditorBoot> createState() => _EditorBootState();
}

class _EditorBootState extends ConsumerState<_EditorBoot> {
  var ready = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(albumEditorViewModelProvider.future);
      if (!mounted) return;
      ref
          .read(albumEditorViewModelProvider.notifier)
          .startLocalTemplateAlbum(
            albumTitle: '웹 편집 동작 검증',
            initialCover: coverSizes.first,
            pages: [
              [
                LayerModel(
                  id: 'cover-text',
                  type: LayerType.text,
                  text: '스냅핏',
                  position: const Offset(140, 150),
                  width: 160,
                  height: 60,
                  textStyle: const TextStyle(fontSize: 24),
                ),
              ],
              [
                LayerModel(
                  id: 'web-photo',
                  type: LayerType.image,
                  position: const Offset(90, 100),
                  width: 120,
                  height: 100,
                  imageZoom: 1.4,
                  imageOffset: const Offset(5, 6),
                ),
                LayerModel(
                  id: 'web-text',
                  type: LayerType.text,
                  text: '우리의 기록',
                  position: const Offset(160, 290),
                  width: 160,
                  height: 60,
                  textStyle: const TextStyle(fontSize: 22),
                ),
              ],
            ],
          );
      setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => ready
      ? PageEditorScreen(initialPageIndex: widget.page)
      : const SizedBox();
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  int page = 1,
  Size size = const Size(1440, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        designTemplateCatalogProvider.overrideWith(
          (_) async => [
            DesignTemplate(
              id: 'web-editor-fixture',
              name: '테스트 디자인',
              category: '테스트',
              buildLayers: (_) => [
                LayerModel(
                  id: 'fixture-design-shape',
                  type: LayerType.decoration,
                  position: const Offset(100, 100),
                  width: 100,
                  height: 100,
                  decorationFillColor: '#55BBAA',
                ),
              ],
            ),
          ],
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(home: _EditorBoot(page: page)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(PageEditorScreen)),
  );
}

Future<void> _edit(WidgetTester tester, String field, String value) async {
  final input = find.byKey(ValueKey('web-layer-$field'));
  if (input.evaluate().isEmpty) {
    final disclosure = find.byKey(const ValueKey('web-layer-advanced-toggle'));
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(input);
  await tester.enterText(input, value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  test('uses the requested editor runtime', () {
    expect(kIsWeb, const bool.fromEnvironment('SNAPFIT_EXPECT_WEB'));
  });

  testWidgets(
    'all five web tools use a large selector and leave precision sidebar clear',
    (tester) async {
      await _mount(tester);
      for (final tool in <(String, Type)>[
        ('레이어', LayerManagerPanel),
        ('레이아웃', TemplateSelectionPanel),
        ('템플릿', DesignTemplatePanel),
        ('꾸미기', DecoratePanel),
        ('배경', DecoratePanel),
      ]) {
        expect(find.byType(tool.$2), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, tool.$1));
        await tester.pumpAndSettle();
        expect(find.byType(WebEditorToolDialog), findsOneWidget);
        final frame = tester.getRect(
          find.byKey(const ValueKey('web-editor-tool-dialog-frame')),
        );
        expect(frame.width, greaterThan(1000));
        expect(frame.height, greaterThan(750));
        final panel = find.descendant(
          of: find.byType(WebEditorToolDialog),
          matching: find.byType(tool.$2),
        );
        expect(panel, findsOneWidget);
        expect(tester.getSize(panel).height, greaterThan(600));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('web-editor-tool-close')));
        await tester.pumpAndSettle();
        expect(find.byType(WebEditorToolDialog), findsNothing);
        expect(find.byType(PageEditorScreen), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'layer selection and background choice close only the large tool',
    (tester) async {
      final container = await _mount(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      await tester.tap(find.widgetWithText(TextButton, '레이어'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(LayerManagerPanel),
          matching: find.text('우리의 기록'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WebEditorToolDialog), findsNothing);
      expect(find.byType(WebLayerTransformInspector), findsOneWidget);
      expect(find.byType(PageEditorScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '배경'));
      await tester.pumpAndSettle();
      final colorGrid = tester.widget<GridView>(
        find.descendant(
          of: find.byType(DecorateColorTab),
          matching: find.byType(GridView),
        ),
      );
      expect(
        colorGrid.gridDelegate,
        isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
      );
      await tester.tap(find.byKey(const ValueKey('editor-background-color-1')));
      await tester.pumpAndSettle();
      expect(vm.currentPage!.backgroundColor, 0xFFFFFFFF);
      expect(find.byType(WebEditorToolDialog), findsNothing);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'layout preview cancel keeps selector and apply returns to canvas',
    (tester) async {
      final container = await _mount(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.currentPage!.layers.map((layer) => layer.id).toList();
      await tester.tap(find.widgetWithText(TextButton, '레이아웃'));
      await tester.pumpAndSettle();
      final cards = find.descendant(
        of: find.byType(TemplateSelectionPanel),
        matching: find.byType(GridView),
      );
      final firstCard = find
          .descendant(of: cards, matching: find.byType(GestureDetector))
          .first;
      await tester.tap(firstCard);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('confirm-template-apply')),
        findsOneWidget,
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(WebEditorToolDialog), findsOneWidget);
      expect(vm.currentPage!.layers.map((layer) => layer.id).toList(), before);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-template-apply')));
      await tester.pumpAndSettle();
      expect(find.byType(WebEditorToolDialog), findsNothing);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(
        vm.currentPage!.layers.map((layer) => layer.id).toList(),
        isNot(before),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'web route wires numeric transforms, undo and separate view zoom',
    (tester) async {
      final container = await _mount(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final interaction = tester
          .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
          .interaction;
      expect(interaction.enableWebTransforms, isTrue);
      interaction.setSelectedLayer('web-photo');
      await tester.pumpAndSettle();
      expect(find.byType(WebLayerTransformInspector), findsOneWidget);
      expect(find.byKey(const ValueKey('web-layer-x')), findsNothing);
      expect(find.text('사진 교체'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('web-layer-quick-actions')))
            .dy,
        lessThan(tester.getTopLeft(find.byType(WebLayerTransformInspector)).dy),
      );
      final original = vm.currentPage!.layers.first;
      final base = interaction.baseSizeFor(original);
      await _edit(tester, 'rotation', '45');
      expect(vm.currentPage!.layers.first.rotation, closeTo(45, .001));
      await _edit(tester, 'width', '${base.width * 1.5}');
      final resized = vm.currentPage!.layers.first;
      expect(resized.scale, closeTo(1.5, .001));
      expect(resized.imageZoom, original.imageZoom);
      expect(resized.imageOffset, original.imageOffset);
      final handle = find.byKey(
        const ValueKey('web-layer-resize-web-photo-bottomRight'),
      );
      final handleSize = tester.getRect(handle).size;

      // Clicking view controls must leave document geometry and crop untouched.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.byTooltip('화면 확대'));
      await tester.pumpAndSettle();
      final afterZoom = vm.currentPage!.layers.first;
      expect(afterZoom.scale, resized.scale);
      expect(afterZoom.rotation, resized.rotation);
      expect(afterZoom.position, resized.position);
      expect(tester.getRect(handle).width, closeTo(handleSize.width, .01));
      expect(tester.getRect(handle).height, closeTo(handleSize.height, .01));

      await tester.tap(find.byTooltip('실행 취소 (Ctrl/⌘ Z)'));
      await tester.pumpAndSettle();
      expect(vm.currentPage!.layers.first.scale, original.scale);
      expect(vm.currentPage!.layers.first.rotation, 45);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'cover uses the same transform controls without changing previews',
    (tester) async {
      try {
        final container = await _mount(tester, page: 0);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        final interaction = tester
            .widget<EditCover>(find.byType(EditCover))
            .interaction!;
        expect(interaction.enableWebTransforms, isTrue);
        interaction.setSelectedLayer('cover-text');
        await tester.pumpAndSettle();
        expect(find.byType(WebLayerTransformInspector), findsOneWidget);
        await _edit(tester, 'rotation', '-30');
        expect(vm.currentPage!.layers.single.rotation, closeTo(-30, .001));
        final beforeTextSize = interaction.baseSizeFor(
          vm.currentPage!.layers.single,
        );
        vm.updateLayer(
          vm.currentPage!.layers.single.copyWith(
            text: '스냅핏\n우리의 기록\n함께한 순간',
            textStyle: const TextStyle(fontSize: 42),
            textBackground: 'bubble',
          ),
        );
        await tester.pumpAndSettle();
        final currentTextSize = interaction.baseSizeFor(
          vm.currentPage!.layers.single,
        );
        expect(currentTextSize, isNot(beforeTextSize));
        final frame = tester.widget<WebSelectionFrame>(
          find.byKey(const ValueKey('web-selection-cover-text')),
        );
        expect(frame.geometry.baseSize, currentTextSize);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } catch (error) {
        // Browser framework diagnostics can be emitted only to its console.
        // Keep the assertion detail visible to the command-line reporter too.
        debugPrint('Cover transform regression: $error');
        rethrow;
      }
    },
    skip: !kIsWeb,
  );

  testWidgets('save shortcut waits for the active web transform to commit', (
    tester,
  ) async {
    final container = await _mount(tester);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    final interaction = tester
        .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
        .interaction;
    interaction.setSelectedLayer('web-photo');
    await tester.pumpAndSettle();
    final before = vm.currentPage!.layers.first.scale;
    final start = tester.getCenter(
      find.byKey(const ValueKey('web-layer-resize-web-photo-bottomRight')),
    );
    final drag = await tester.startGesture(start);
    await drag.moveBy(const Offset(30, 30));
    await tester.pump();
    expect(interaction.isInteractingNow, isTrue);
    tester
        .widget<EditorKeyboardShortcuts>(find.byType(EditorKeyboardShortcuts))
        .onSave!();
    await tester.pump();
    expect(
      tester
          .widget<WebAlbumEditorWorkspace>(find.byType(WebAlbumEditorWorkspace))
          .isSaving,
      isFalse,
    );
    expect(vm.currentPage!.layers.first.scale, before);
    await drag.moveBy(const Offset(30, 30));
    await drag.up();
    await tester.pumpAndSettle();
    expect(vm.currentPage!.layers.first.scale, greaterThan(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: !kIsWeb);

  testWidgets('native page retains the original controls and layout', (
    tester,
  ) async {
    await _mount(tester, size: const Size(390, 844));
    final interaction = tester
        .widget<PageEditorCanvas>(find.byType(PageEditorCanvas))
        .interaction;
    expect(interaction.enableWebTransforms, isFalse);
    interaction.setSelectedLayer('web-text');
    await tester.pumpAndSettle();
    expect(find.byType(WebLayerTransformInspector), findsNothing);
    expect(find.byType(EditorBottomMenu), findsOneWidget);
    expect(
      find.byKey(const ValueKey('page-editor-desktop-workspace')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: kIsWeb);
}

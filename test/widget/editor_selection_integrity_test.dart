import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_overlap_picker.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

const _canvasSize = Size(500, 500);
const _background = 'selection-background';
const _firstPhoto = 'selection-first-photo';
const _secondPhoto = 'selection-second-photo';
const _title = 'selection-title';

List<LayerModel> _artwork() => [
  // A background remains under the content even with a higher saved zIndex.
  LayerModel(
    id: _background,
    type: LayerType.decoration,
    position: Offset.zero,
    width: 500,
    height: 500,
    decorationFillColor: '#F0E9DA',
    zIndex: 900,
  ),
  LayerModel(
    id: _firstPhoto,
    type: LayerType.image,
    position: const Offset(60, 100),
    width: 220,
    height: 220,
    imageZoom: 1.5,
    zIndex: 30,
  ),
  // Equal-z photographs retain their authored array order.
  LayerModel(
    id: _secondPhoto,
    type: LayerType.image,
    position: const Offset(330, 100),
    width: 110,
    height: 170,
    imageZoom: 1.4,
    zIndex: 30,
  ),
  LayerModel(
    id: _title,
    type: LayerType.text,
    text: 'KEEP THIS TITLE',
    position: const Offset(100, 150),
    width: 160,
    height: 70,
    textStyle: const TextStyle(fontSize: 18, color: Colors.white),
    zIndex: 40,
  ),
];

class _Canvas extends ConsumerStatefulWidget {
  const _Canvas({
    super.key,
    required this.webTransforms,
    this.overlapSelection = false,
  });
  final bool webTransforms;
  final bool overlapSelection;

  @override
  ConsumerState<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends ConsumerState<_Canvas> {
  int textEdits = 0;
  final canvasKey = GlobalKey();
  late final LayerInteractionManager manager;

  @override
  void initState() {
    super.initState();
    manager = LayerInteractionManager(
      ref: ref,
      coverKey: canvasKey,
      setState: setState,
      getCoverSize: () => _canvasSize,
      onEditText: (_) => textEdits++,
      showSelectionControls: widget.overlapSelection,
      enableWebTransforms: widget.webTransforms,
      enableOverlapSelection: widget.overlapSelection,
    );
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  void undo() {
    ref.read(albumEditorViewModelProvider.notifier).undo();
    manager.resetForPageChange();
  }

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(albumEditorViewModelProvider).value!.layers;
    return Scaffold(
      bottomNavigationBar: widget.overlapSelection
          ? EditorOverlapPicker(layers: layers, interaction: manager)
          : null,
      body: Align(
        alignment: Alignment.topLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: manager.clearSelection,
              child: SizedBox(
                key: canvasKey,
                width: 500,
                height: 500,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Stack(
                      key: const ValueKey('selection-artwork'),
                      children: [
                        for (final layer in manager.sortByZ(layers))
                          manager.buildInteractiveLayer(
                            layer: layer,
                            baseWidth: layer.width,
                            baseHeight: layer.height,
                            child: ColoredBox(
                              key: ValueKey('paint-${layer.id}'),
                              color: switch (layer.id) {
                                _background => const Color(0xFFF0E9DA),
                                _title => const Color(0xFF263C39),
                                _firstPhoto => const Color(0xFF487B72),
                                _ => const Color(0xFF8B7056),
                              },
                              child: layer.type == LayerType.text
                                  ? Center(child: Text(layer.text!))
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    if (widget.overlapSelection)
                      manager.buildSelectionOverlay(layers),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 300,
              height: 500,
              child: LayerManagerPanel(
                layers: layers,
                interaction: manager,
                showHandle: false,
              ),
            ),
            GestureDetector(
              key: const ValueKey('selection-empty-workspace'),
              behavior: HitTestBehavior.opaque,
              onTap: manager.clearSelection,
              child: SizedBox(
                width: 80,
                height: 500,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: TextButton(
                    key: const ValueKey('selection-clear'),
                    onPressed: manager.clearSelection,
                    child: const Text('Clear'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<({AlbumEditorViewModel vm, _CanvasState host})> _mount(
  WidgetTester tester, {
  required bool webTransforms,
  bool overlapSelection = false,
}) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  vm.resetForCreate();
  vm.updatePageLayers(_artwork(), recordHistory: false);
  final host = GlobalKey<_CanvasState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: _Canvas(
          key: host,
          webTransforms: webTransforms,
          overlapSelection: overlapSelection,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(vm.hasUnsavedChanges, isFalse);
  expect(container.read(albumEditorViewModelProvider).value!.canUndo, isFalse);
  return (vm: vm, host: host.currentState!);
}

List<String> _order(AlbumEditorViewModel vm) => [
  for (final layer in vm.layers) layer.id,
];

List<String> _paintOrder(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find.byKey(const ValueKey('selection-artwork')),
  );
  return [
    for (final child in stack.children)
      tester
          .widget<MouseRegion>(
            find.descendant(
              of: find.byWidget(child),
              matching: find.byType(MouseRegion),
            ),
          )
          .key
          .toString(),
  ];
}

Future<void> _tap(
  WidgetTester tester,
  Offset location,
  PointerDeviceKind kind,
) async {
  final pointer = await tester.startGesture(location, kind: kind);
  await tester.pump(const Duration(milliseconds: 150));
  await pointer.up();
  await pointer.removePointer();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> _drag(
  WidgetTester tester,
  Offset location,
  PointerDeviceKind kind, {
  bool hold = false,
}) async {
  final pointer = await tester.startGesture(location, kind: kind);
  if (hold) await tester.pump(const Duration(milliseconds: 500));
  await pointer.moveBy(const Offset(24, 25));
  await tester.pump();
  await pointer.moveBy(const Offset(35, 20));
  await tester.pump();
  await pointer.up();
  await pointer.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'an old chooser cannot target a reused id on another page before view reset',
    (tester) async {
      final s = await _mount(
        tester,
        webTransforms: false,
        overlapSelection: true,
      );
      await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
      await tester.tap(find.byTooltip('겹친 요소 선택'));
      await tester.pumpAndSettle();
      s.vm.goToPage(1);
      final replacement = _artwork()[1].copyWith(
        position: const Offset(200, 200),
      );
      s.vm.updatePageLayers([replacement], recordHistory: false);
      // No reset/pump between changing the document and receiving the old menu's
      // result: the source page identity must be checked by the command itself.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem && w.value == _firstPhoto,
        ),
      );
      await tester.pumpAndSettle();
      expect(s.host.manager.selectedLayerId, isNot(_firstPhoto));
      expect(s.vm.layers.single, same(replacement));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('touch selection overlay preserves double tap text editing', (
    tester,
  ) async {
    final s = await _mount(
      tester,
      webTransforms: false,
      overlapSelection: true,
    );
    await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
    await tester.tapAt(const Offset(160, 180));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(160, 180));
    await tester.pumpAndSettle();
    expect(s.host.textEdits, 1);
    expect(s.vm.hasUnsavedChanges, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlap quick forward is explicit and undoable', (tester) async {
    final s = await _mount(
      tester,
      webTransforms: false,
      overlapSelection: true,
    );
    await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
    s.host.manager.selectOverlappingLayer(_firstPhoto);
    await tester.pump();
    await tester.tap(find.byTooltip('겹친 요소 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('앞으로'));
    await tester.pumpAndSettle();
    expect(_order(s.vm), [_background, _secondPhoto, _firstPhoto, _title]);
    s.host.undo();
    await tester.pumpAndSettle();
    expect(_order(s.vm), [_background, _firstPhoto, _secondPhoto, _title]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'overlap chooser selects covered content without changing history and rejects a stale menu',
    (tester) async {
      final s = await _mount(
        tester,
        webTransforms: false,
        overlapSelection: true,
      );
      await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
      final order = _order(s.vm);
      await tester.tap(find.byTooltip('겹친 요소 선택'));
      await tester.pumpAndSettle();
      final item = find.byWidgetPredicate(
        (w) => w is PopupMenuItem && w.value == _firstPhoto,
      );
      expect(
        find.descendant(of: item, matching: find.byType(Image)),
        findsNothing,
      );
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(s.host.manager.selectedLayerId, _firstPhoto);
      expect(_order(s.vm), order);
      expect(s.vm.hasUnsavedChanges, isFalse);
      await tester.tap(find.byTooltip('겹친 요소 선택'));
      await tester.pumpAndSettle();
      s.host.manager.resetForPageChange();
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuItem && w.value == _title),
      );
      await tester.pumpAndSettle();
      expect(s.host.manager.selectedLayerId, isNull);
      expect(_order(s.vm), order);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'covered photo can be selected and dragged without reordering artwork',
    (tester) async {
      final session = await _mount(
        tester,
        webTransforms: false,
        overlapSelection: true,
      );
      final manager = session.host.manager;
      final before = List<LayerModel>.of(session.vm.layers);
      final order = _order(session.vm);
      await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
      expect(manager.overlapLayerIds, [_title, _firstPhoto]);
      manager.selectOverlappingLayer(_firstPhoto);
      await tester.pump();
      expect(manager.selectedLayerId, _firstPhoto);
      expect(
        find.byKey(const ValueKey('touch-selection-selection-first-photo')),
        findsOneWidget,
      );
      expect(session.vm.hasUnsavedChanges, isFalse);
      expect(_order(session.vm), order);
      for (var i = 0; i < before.length; i++)
        expect(session.vm.layers[i], same(before[i]));
      await _drag(tester, const Offset(160, 180), PointerDeviceKind.touch);
      expect(
        session.vm.findLayerById(_firstPhoto)!.position,
        isNot(before[1].position),
      );
      expect(session.vm.findLayerById(_title), same(before.last));
      expect(_order(session.vm), order);
      session.host.undo();
      await tester.pumpAndSettle();
      expect(
        session.vm.findLayerById(_firstPhoto)!.position,
        before[1].position,
      );
      expect(manager.overlapLayerIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rotated candidate hits use actual transformed rectangles', (
    tester,
  ) async {
    final session = await _mount(
      tester,
      webTransforms: false,
      overlapSelection: true,
    );
    session.vm.updateLayer(
      session.vm.findLayerById(_secondPhoto)!.copyWith(rotation: 45),
    );
    await tester.pumpAndSettle();
    expect(
      session.host.manager.layersAt(const Offset(385, 185)).map((l) => l.id),
      contains(_secondPhoto),
    );
    expect(
      session.host.manager.layersAt(const Offset(290, 90)).map((l) => l.id),
      isNot(contains(_secondPhoto)),
    );
    await _tap(tester, const Offset(160, 180), PointerDeviceKind.touch);
    final revision = session.host.manager.overlapRevision;
    session.host.manager.resetForPageChange();
    session.host.manager.selectOverlappingLayer(_firstPhoto);
    expect(session.host.manager.selectedLayerId, isNull);
    expect(session.host.manager.overlapLayerIds, isEmpty);
    expect(session.host.manager.overlapRevision, greaterThan(revision));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit forward order survives undo redo and interaction cache resets',
    (tester) async {
      final session = await _mount(
        tester,
        webTransforms: false,
        overlapSelection: true,
      );
      final original = _order(session.vm);
      session.host.manager.setSelectedLayer(_firstPhoto);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('앞으로'));
      await tester.pumpAndSettle();
      final expected = [_background, _secondPhoto, _firstPhoto, _title];
      expect(_order(session.vm), expected);
      expect(session.vm.layers.map((l) => l.zIndex), [0, 1, 2, 3]);
      session.host.undo();
      await tester.pumpAndSettle();
      expect(_order(session.vm), original);
      session.vm.redo();
      session.host.manager.resetForPageChange();
      await tester.pumpAndSettle();
      expect(
        session.host.manager.sortByZ(session.vm.layers).map((l) => l.id),
        expected,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final webTransforms in [false, true]) {
    final mode = webTransforms ? 'web controls' : 'native controls';
    for (final kind in [
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
    ]) {
      testWidgets(
        '$mode ${kind.name} selection preserves artwork and history',
        (tester) async {
          final session = await _mount(tester, webTransforms: webTransforms);
          final before = List<LayerModel>.of(session.vm.layers);
          final order = _order(session.vm);
          final paintOrder = _paintOrder(tester);
          final z = {
            for (final layer in before)
              layer.id: session.host.manager.getZIndex(layer.id),
          };
          // The overlapping title must still receive the pointer above photo A.
          for (final target in [
            (_title, const Offset(160, 180)),
            (_firstPhoto, const Offset(100, 280)),
            (_secondPhoto, const Offset(380, 180)),
          ]) {
            await _tap(tester, target.$2, kind);
            expect(session.host.manager.selectedLayerId, target.$1);
            expect(_order(session.vm), order);
            expect(_paintOrder(tester), paintOrder);
            for (var index = 0; index < before.length; index++) {
              expect(session.vm.layers[index], same(before[index]));
              expect(
                session.host.manager.getZIndex(before[index].id),
                z[before[index].id],
              );
            }
            expect(session.vm.hasUnsavedChanges, isFalse);
          }
          session.host.undo();
          await tester.pump();
          expect(_order(session.vm), order);
          expect(session.vm.hasUnsavedChanges, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets('$mode ${kind.name} dragging changes only target geometry', (
        tester,
      ) async {
        final session = await _mount(tester, webTransforms: webTransforms);
        final before = List<LayerModel>.of(session.vm.layers);
        final order = _order(session.vm);
        final paintOrder = _paintOrder(tester);
        final original = session.vm.findLayerById(_secondPhoto)!;
        await _drag(tester, const Offset(380, 180), kind);
        final moved = session.vm.findLayerById(_secondPhoto)!;
        expect(moved.position, isNot(original.position));
        expect(moved.scale, original.scale);
        expect(moved.rotation, original.rotation);
        expect(moved.imageOffset, original.imageOffset);
        expect(moved.imageZoom, original.imageZoom);
        expect(moved.zIndex, original.zIndex);
        expect(_order(session.vm), order);
        expect(_paintOrder(tester), paintOrder);
        for (final other in before.where((layer) => layer.id != _secondPhoto)) {
          expect(session.vm.findLayerById(other.id), same(other));
        }
        session.host.undo();
        await tester.pumpAndSettle();
        expect(
          session.vm.findLayerById(_secondPhoto)!.position,
          original.position,
        );
        expect(_order(session.vm), order);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('$mode same-photo press and drag retains photo-pan mode', (
      tester,
    ) async {
      final session = await _mount(tester, webTransforms: webTransforms);
      await _tap(tester, const Offset(100, 280), PointerDeviceKind.touch);
      session.host.manager.toggleImagePanMode();
      await tester.pump();
      final original = session.vm.findLayerById(_firstPhoto)!;
      await _drag(
        tester,
        const Offset(100, 280),
        PointerDeviceKind.touch,
        hold: true,
      );
      final cropped = session.vm.findLayerById(_firstPhoto)!;
      expect(session.host.manager.selectedLayerId, _firstPhoto);
      expect(session.host.manager.isImagePanMode, isTrue);
      expect(cropped.position, original.position);
      expect(cropped.scale, original.scale);
      expect(cropped.imageOffset, isNot(original.imageOffset));
      await _tap(tester, const Offset(380, 180), PointerDeviceKind.touch);
      expect(session.host.manager.selectedLayerId, _secondPhoto);
      expect(session.host.manager.isImagePanMode, isFalse);
      session.host.manager.toggleImagePanMode();
      await tester.pump();
      await _tap(tester, const Offset(840, 440), PointerDeviceKind.touch);
      expect(session.host.manager.selectedLayerId, isNull);
      expect(session.host.manager.isImagePanMode, isFalse);
      session.host.manager.setSelectedLayer(_secondPhoto);
      session.host.manager.toggleImagePanMode();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('selection-clear')));
      await tester.pumpAndSettle();
      expect(session.host.manager.selectedLayerId, isNull);
      expect(session.host.manager.isImagePanMode, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$mode gesture selection resets another photo pan mode', (
      tester,
    ) async {
      final session = await _mount(tester, webTransforms: webTransforms);
      session.host.manager.setSelectedLayer(_firstPhoto);
      session.host.manager.toggleImagePanMode();
      await tester.pump();
      final original = session.vm.findLayerById(_secondPhoto)!;
      // Move immediately, before the tap-down timeout, to exercise scale start.
      await _drag(tester, const Offset(380, 180), PointerDeviceKind.stylus);
      final moved = session.vm.findLayerById(_secondPhoto)!;
      expect(session.host.manager.selectedLayerId, _secondPhoto);
      expect(session.host.manager.isImagePanMode, isFalse);
      expect(moved.position, isNot(original.position));
      expect(moved.imageOffset, original.imageOffset);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$mode explicit layer-list reorder remains undoable', (
      tester,
    ) async {
      final session = await _mount(tester, webTransforms: webTransforms);
      final before = List<LayerModel>.of(session.vm.layers);
      final order = _order(session.vm);
      final item = find.byKey(const ValueKey(_firstPhoto));
      final handle = find.descendant(
        of: item,
        matching: find.byType(ReorderableDragStartListener),
      );
      final start = tester.getCenter(handle);
      final panel = tester.getRect(find.byType(LayerManagerPanel));
      final pointer = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      final end = Offset(start.dx, panel.top + 4);
      // ReorderableList updates its insertion gap per pointer movement. A
      // single jump above the first row can skip that row's insertion region;
      // traverse the rows while their gap animations and layout advance.
      for (var step = 1; step <= 12; step++) {
        await pointer.moveTo(Offset.lerp(start, end, step / 12)!);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await pointer.up();
      await pointer.removePointer();
      await tester.pumpAndSettle();
      expect(_order(session.vm), [
        _background,
        _secondPhoto,
        _title,
        _firstPhoto,
      ]);
      expect(
        session.host.manager
            .sortByZ(session.vm.layers)
            .map((layer) => layer.id),
        [_background, _secondPhoto, _title, _firstPhoto],
      );
      expect(session.vm.hasUnsavedChanges, isTrue);
      for (final original in before) {
        final updated = session.vm.findLayerById(original.id)!;
        expect(
          LayerExportMapper.toJson(updated, canvasSize: _canvasSize)
            ..remove('zIndex'),
          LayerExportMapper.toJson(original, canvasSize: _canvasSize)
            ..remove('zIndex'),
        );
      }
      session.host.undo();
      await tester.pumpAndSettle();
      expect(_order(session.vm), order);
      expect(
        session.host.manager
            .sortByZ(session.vm.layers)
            .map((layer) => layer.id),
        order,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

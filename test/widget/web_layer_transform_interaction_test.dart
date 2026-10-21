import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_transform_geometry.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';

LayerModel _layer() => LayerModel(
  id: 'shape',
  type: LayerType.decoration,
  position: const Offset(150, 160),
  width: 100,
  height: 80,
  scale: 1.2,
  rotation: 30,
);

class _Editor extends AlbumEditorViewModel {
  _Editor(this.layers);
  @override
  List<LayerModel> layers;
  final history = <List<LayerModel>>[];
  var updates = 0;
  @override
  AlbumEditorState build() => AlbumEditorState(layers: layers);
  @override
  void updateLayer(LayerModel next) {
    updates++;
    history.add(List.of(layers));
    layers = [
      for (final old in layers)
        if (old.id == next.id) next else old,
    ];
    state = AsyncData(AlbumEditorState(layers: layers));
  }

  @override
  void removeLayerById(String id) {
    layers = layers.where((layer) => layer.id != id).toList();
    state = AsyncData(AlbumEditorState(layers: layers));
  }

  @override
  void undo() {
    layers = history.removeLast();
    state = AsyncData(AlbumEditorState(layers: layers));
  }

  void replace(LayerModel next) {
    layers = [next];
    state = AsyncData(AlbumEditorState(layers: layers));
  }
}

void main() {
  Future<({LayerInteractionManager manager, _Editor editor, GlobalKey canvas})>
  mount(
    WidgetTester tester, {
    bool enableWebTransforms = true,
    double viewportScale = .75,
    Size? renderedBase,
    List<LayerModel>? initialLayers,
  }) async {
    final editor = _Editor(initialLayers ?? [_layer()]);
    final canvas = GlobalKey();
    LayerInteractionManager? manager;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumEditorViewModelProvider.overrideWith(() => editor)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => StatefulBuilder(
                builder: (context, setState) {
                  manager ??= LayerInteractionManager(
                    ref: ref,
                    coverKey: canvas,
                    setState: setState,
                    getCoverSize: () => const Size(500, 500),
                    onEditText: (_) {},
                    enableWebTransforms: enableWebTransforms,
                  );
                  final layers =
                      ref.watch(albumEditorViewModelProvider).value?.layers ??
                      [];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Transform.scale(
                      scale: viewportScale,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        key: canvas,
                        width: 500,
                        height: 500,
                        child: Stack(
                          children: [
                            for (final layer in layers)
                              manager!.buildInteractiveLayer(
                                layer: layer,
                                baseWidth: renderedBase?.width ?? layer.width,
                                baseHeight:
                                    renderedBase?.height ?? layer.height,
                                child: const ColoredBox(color: Colors.teal),
                              ),
                            manager!.buildSelectionOverlay(layers),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    manager!.setSelectedLayer('shape');
    await tester.pump();
    await tester.pump();
    addTearDown(manager!.dispose);
    return (manager: manager!, editor: editor, canvas: canvas);
  }

  for (final corner in ResizeHandlePosition.values) {
    testWidgets(
      '${corner.name} resizes cumulatively at zoom with one final commit',
      (tester) async {
        final session = await mount(tester);
        final initial = session.editor.layers.single;
        final finder = find.byKey(
          ValueKey('web-layer-resize-shape-${corner.name}'),
        );
        expect(tester.getRect(finder).width, closeTo(30, .001));
        final start = tester.getCenter(finder);
        final direction = LayerTransformGeometry.cornerDirection(corner);
        final delta =
            LayerTransformGeometry.rotate(
              Offset(direction.dx * 25, direction.dy * 20),
              math.pi / 6,
            ) *
            .75;
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await pointer.addPointer(location: start);
        await pointer.down(start);
        await pointer.moveTo(start + delta);
        await tester.pump();
        final first = session.manager.currentTransformFor(initial).scale;
        expect(first, greaterThan(initial.scale));
        expect(session.manager.isInteractingNow, isTrue);
        expect(session.editor.updates, 0);
        await pointer.moveTo(start + delta * 2);
        await tester.pump();
        expect(
          session.manager.currentTransformFor(initial).scale,
          greaterThan(first),
        );
        expect(session.editor.updates, 0);
        await pointer.up();
        await tester.pump();
        expect(session.editor.updates, 1);
        expect(session.editor.layers.single.scale, closeTo(1.7, .00001));
        expect(session.manager.isInteractingNow, isFalse);
        session.editor.undo();
        expect(
          session.manager
              .currentTransformFor(session.editor.layers.single)
              .scale,
          closeTo(1.2, .00001),
        );
        await pointer.removePointer();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'drag guides target the rendered edge of a scaled rotated neighbour',
    (tester) async {
      final other = LayerModel(
        id: 'neighbour',
        type: LayerType.decoration,
        position: const Offset(250, 200),
        width: 80,
        height: 40,
        scale: 2,
        rotation: 45,
      );
      final session = await mount(tester, initialLayers: [_layer(), other]);
      final canvas =
          tester.renderObject(find.byKey(session.canvas)) as RenderBox;
      final start = canvas.localToGlobal(const Offset(200, 200));
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: start);
      await pointer.down(start);
      await pointer.moveTo(start + const Offset(40, 20) * .75);
      await tester.pump();
      expect(session.manager.selectedLayerId, 'shape');
      final current = session.manager.currentTransformFor(
        session.editor.layers.first,
      );
      final actualEdge = 290 + 120 / math.sqrt(2);
      final currentCenter = current.position + const Offset(50, 40);
      final delta = Offset(actualEdge + 1, 330) - currentCenter;
      await pointer.moveBy(delta * .75);
      await tester.pump();
      expect(
        session.manager.activeVerticalGuides,
        contains(closeTo(actualEdge, .00001)),
      );
      await pointer.up();
      await pointer.removePointer();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'rotation handle is hittable outside the layer and Shift snaps without resize',
    (tester) async {
      final session = await mount(tester);
      final initial = session.editor.layers.single;
      final center =
          (tester.renderObject(find.byKey(session.canvas)) as RenderBox)
              .localToGlobal(const Offset(200, 200));
      final start = tester.getCenter(
        find.byKey(const ValueKey('web-layer-rotate-shape')),
      );
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: start);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await pointer.down(start);
      await pointer.moveTo(
        center +
            LayerTransformGeometry.rotate(start - center, 20 * math.pi / 180),
      );
      await tester.pump();
      await pointer.moveTo(
        center +
            LayerTransformGeometry.rotate(start - center, 43 * math.pi / 180),
      );
      await tester.pump();
      expect(session.editor.updates, 0);
      expect(session.manager.isInteractingNow, isTrue);
      await pointer.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final current = session.editor.layers.single;
      expect(current.rotation, closeTo(75, .00001));
      expect(current.position, initial.position);
      expect(current.scale, initial.scale);
      expect(session.editor.updates, 1);
      await pointer.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'inspector retains centre, uses rendered base and refuses invalid/no-op/stale input',
    (tester) async {
      final session = await mount(tester, renderedBase: const Size(150, 90));
      final stale = session.editor.layers.single;
      final latest = stale.copyWith(
        position: const Offset(70, 110),
        rotation: 51,
        scale: 1.4,
        decorationFillColor: '#123456',
      );
      session.editor.replace(latest);
      session.manager.updateTransform(stale, width: 300);
      final current = session.editor.layers.single;
      expect(current.scale, 2);
      expect(current.position, latest.position);
      expect(current.rotation, latest.rotation);
      expect(current.decorationFillColor, '#123456');
      expect(session.manager.baseSizeFor(current), const Size(150, 90));
      session.manager.updateTransform(stale, width: 300);
      session.manager.updateTransform(stale, x: double.nan);
      session.manager.updateTransform(stale, height: double.infinity);
      session.manager.updateTransform(stale, width: -1);
      expect(session.editor.updates, 1);
      session.manager.updateTransform(stale, height: 9000);
      expect(session.editor.layers.single.scale, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('page change cancels a resize and ignores its later pointer-up', (
    tester,
  ) async {
    final session = await mount(tester);
    final start = tester.getCenter(
      find.byKey(const ValueKey('web-layer-resize-shape-bottomRight')),
    );
    final pointer = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await pointer.moveBy(const Offset(50, 40));
    await tester.pump();
    expect(session.manager.isInteractingNow, isTrue);
    session.manager.updateTransform(session.editor.layers.single, x: 999);
    expect(session.editor.updates, 0);
    session.manager.resetForPageChange();
    await tester.pump();
    await pointer.up();
    await tester.pump();
    expect(session.manager.isInteractingNow, isFalse);
    expect(session.editor.updates, 0);
    expect(session.editor.layers.single.scale, 1.2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('native default and print previews do not create web controls', (
    tester,
  ) async {
    final session = await mount(tester, enableWebTransforms: false);
    expect(find.byKey(const ValueKey('web-layer-rotate-shape')), findsNothing);
    expect(
      find.byKey(const ValueKey('web-layer-resize-shape-topLeft')),
      findsNothing,
    );
    session.manager.updateTransform(session.editor.layers.single, width: 300);
    expect(session.editor.updates, 0);
    final print = LayerInteractionManager.printPreview(
      () => const Size(500, 500),
    );
    expect(print.enableWebTransforms, isFalse);
    print.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}

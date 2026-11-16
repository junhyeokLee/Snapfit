import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_context_dock.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_manager_panel.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

class _Photo extends Mock implements AssetEntity {}

class _Harness extends ConsumerStatefulWidget {
  const _Harness({super.key, this.inlineOrder = false});
  final bool inlineOrder;
  @override
  ConsumerState<_Harness> createState() => _HarnessState();
}

class _HarnessState extends ConsumerState<_Harness> {
  late final LayerInteractionManager interaction;
  final modes = <EditorMode>[];
  int photoAdds = 0;

  void rebuild() => setState(() {});
  @override
  void initState() {
    super.initState();
    interaction = LayerInteractionManager(
      ref: ref,
      coverKey: GlobalKey(),
      setState: setState,
      getCoverSize: () => const Size(500, 500),
      onEditText: (_) {},
      enableOverlapSelection: true,
    );
  }

  @override
  void dispose() {
    interaction.dispose();
    super.dispose();
  }

  Future<void> openOrder() {
    final scope = ProviderScope.containerOf(context, listen: false);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: scope,
        child: Consumer(
          builder: (context, ref, _) => LayerManagerPanel(
            layers: ref.watch(albumEditorViewModelProvider).requireValue.layers,
            interaction: interaction,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(albumEditorViewModelProvider).requireValue;
    return Scaffold(
      body: Row(
        children: [
          const Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox.expand(key: ValueKey('review-canvas')),
            ),
          ),
          if (widget.inlineOrder)
            SizedBox(
              width: 300,
              child: LayerManagerPanel(
                layers: state.layers,
                interaction: interaction,
                showHandle: false,
              ),
            ),
        ],
      ),
      bottomNavigationBar: EditorContextDock(
        layers: state.layers,
        interaction: interaction,
        onModeChanged: modes.add,
        onAddPhoto: () => photoAdds++,
        onRefresh: () => setState(() {}),
        onOpenGallery: (_) async {},
        onOpenCrop: (_) async {},
        onOpenDecorate: (_) {},
      ),
    );
  }
}

Future<({AlbumEditorViewModel vm, _HarnessState host})> _mount(
  WidgetTester tester, {
  bool inlineOrder = false,
}) async {
  tester.view.physicalSize = inlineOrder
      ? const Size(900, 700)
      : const Size(390, 844);
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
  final vm = container.read(albumEditorViewModelProvider.notifier)
    ..resetForCreate();
  vm.updatePageLayers([
    LayerModel(
      id: 'photo',
      type: LayerType.image,
      position: Offset.zero,
      width: 200,
      height: 200,
      zIndex: 0,
    ),
    LayerModel(
      id: 'title',
      type: LayerType.text,
      position: Offset.zero,
      width: 200,
      height: 40,
      text: '우리의 기록',
      zIndex: 1,
    ),
  ], recordHistory: false);
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        home: _Harness(key: key, inlineOrder: inlineOrder),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (vm: vm, host: key.currentState!);
}

void main() {
  testWidgets(
    'review: a second More tap during dismissal must not overlap or discard the chosen tool',
    (tester) async {
      final s = await _mount(tester);
      final morePoint = tester.getCenter(find.byTooltip('더보기'));
      await tester.tapAt(morePoint);
      await tester.pumpAndSettle();
      await tester.tap(find.text('레이아웃'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ModalRoute.of(s.host.context)!.isCurrent, isTrue);
      await tester.tapAt(morePoint);
      await tester.pump(const Duration(milliseconds: 16));
      final overlappingSheets = find
          .byKey(const ValueKey('editor-more-sheet'))
          .evaluate()
          .length;
      await tester.pumpAndSettle();
      final dispatched = List<EditorMode>.of(s.host.modes);
      while (find
          .byKey(const ValueKey('editor-more-sheet'))
          .evaluate()
          .isNotEmpty) {
        Navigator.of(s.host.context).pop();
        await tester.pumpAndSettle();
      }
      expect(
        overlappingSheets,
        lessThanOrEqualTo(1),
        reason: 'The selected tool must run once; dispatched=$dispatched',
      );
      expect(dispatched, [EditorMode.layout]);
    },
  );

  testWidgets(
    'More handoff survives rebuilds and blocks old callbacks and other dock tools',
    (tester) async {
      final s = await _mount(tester);
      final more = find.byTooltip('더보기');
      final oldTap = tester
          .widget<InkWell>(
            find.descendant(of: more, matching: find.byType(InkWell)),
          )
          .onTap!;
      final addPhotoPoint = tester.getCenter(find.byTooltip('사진 추가'));
      oldTap();
      oldTap();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsOneWidget);
      await tester.tap(find.text('레이아웃'));
      await tester.pump(const Duration(milliseconds: 16));
      s.host.rebuild();
      oldTap();
      await tester.tapAt(addPhotoPoint);
      await tester.pumpAndSettle();
      expect(s.host.modes, [EditorMode.layout]);
      expect(s.host.photoAdds, 0);
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsNothing);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsOneWidget);
      await tester.tap(find.byTooltip('편집 도구 닫기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('More cancellation releases the gate only after removal', (
    tester,
  ) async {
    final s = await _mount(tester);
    final morePoint = tester.getCenter(find.byTooltip('더보기'));
    for (var visit = 0; visit < 3; visit++) {
      await tester.tapAt(morePoint);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsOneWidget);
      Navigator.of(s.host.context).pop();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(morePoint);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsNothing);
    }
    expect(s.host.modes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'review: a reorder before the next frame must not restore a photo edit that was just undone',
    (tester) async {
      final s = await _mount(tester, inlineOrder: true);
      s.vm.updateLayer(s.vm.findLayerById('photo')!.copyWith(width: 240));
      await tester.pumpAndSettle();
      final reorder = tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorder!;
      s.vm.undo();
      s.host.interaction.resetForPageChange();
      expect(s.vm.findLayerById('photo')!.width, 200);
      // Keyboard/async model updates and pointer-up events can arrive before the
      // next rebuild. The same page/session ID is still valid in this interval.
      reorder(0, 2);
      await tester.pumpAndSettle();
      expect(
        s.vm.findLayerById('photo')!.width,
        200,
        reason:
            'Reordering must use current layer records or reject a stale order snapshot.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['delete', 'add', 'external order']) {
    testWidgets(
      'a stale reorder cannot overwrite $change or add undo history',
      (tester) async {
        final s = await _mount(tester, inlineOrder: true);
        final original = s.vm.layers.map((l) => (l.id, l.zIndex)).toList();
        final reorder = tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorder!;
        switch (change) {
          case 'delete':
            s.vm.removeLayerById('photo');
          case 'add':
            s.vm.updatePageLayers([
              ...s.vm.layers,
              LayerModel(
                id: 'new',
                type: LayerType.text,
                position: Offset.zero,
                zIndex: 2,
              ),
            ]);
          case 'external order':
            s.vm.updatePageLayers(
              s.vm.layers.reversed.indexed
                  .map((entry) => entry.$2.copyWith(zIndex: entry.$1))
                  .toList(),
            );
        }
        final changed = s.vm.layers.map((l) => (l.id, l.zIndex)).toList();
        reorder(0, 2);
        expect(s.vm.layers.map((l) => (l.id, l.zIndex)), changed);
        s.vm.undo();
        s.host.interaction.resetForPageChange();
        await tester.pumpAndSettle();
        expect(s.vm.layers.map((l) => (l.id, l.zIndex)), original);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'review: pending thumbnail requests must coalesce during a fast return scroll',
    (tester) async {
      final s = await _mount(tester);
      final requests = <String, int>{};
      final pending = <Completer<Uint8List?>>[];
      final assets = List.generate(72, (i) {
        final asset = _Photo();
        when(() => asset.id).thenReturn('asset-$i');
        when(
          () => asset.thumbnailDataWithSize(const ThumbnailSize.square(120)),
        ).thenAnswer((_) {
          requests.update('asset-$i', (n) => n + 1, ifAbsent: () => 1);
          final result = Completer<Uint8List?>();
          pending.add(result);
          return result.future;
        });
        return asset;
      });
      s.vm.updatePageLayers([
        for (final (i, asset) in assets.indexed)
          LayerModel(
            id: 'photo-$i',
            type: LayerType.image,
            position: Offset.zero,
            width: 100,
            height: 100,
            zIndex: i,
            asset: asset,
          ),
      ], recordHistory: false);
      s.host.openOrder();
      await tester.pumpAndSettle();
      final list = find.byType(ReorderableListView);
      final controller = tester
          .widget<ReorderableListView>(list)
          .scrollController!;
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      for (final index in [60, 48, 36, 24, 12, 0]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('photo-$index')),
          500,
          scrollable: scrollable,
          maxScrolls: 40,
        );
        await tester.pumpAndSettle();
      }
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final topRequests = requests['asset-71'];
      final pendingBeforeClose = pending.length;
      await tester.tap(find.byTooltip('겹침 순서 닫기'));
      await tester.pumpAndSettle();
      for (final result in pending) {
        result.complete(null);
      }
      await tester.pumpAndSettle();
      expect(controller.hasClients, isFalse);
      expect(tester.takeException(), isNull);
      expect(
        topRequests,
        1,
        reason:
            'The original request is still pending; $pendingBeforeClose pending requests were started.',
      );
      expect(pendingBeforeClose, 2);
      expect(
        pending,
        hasLength(2),
        reason: 'Closing must discard all queued rows.',
      );
    },
  );

  testWidgets(
    'review: an actual drag finishing after undo must retain the undone photo geometry',
    (tester) async {
      final s = await _mount(tester, inlineOrder: true);
      s.vm.updateLayer(s.vm.findLayerById('photo')!.copyWith(width: 240));
      await tester.pumpAndSettle();
      final before = s.vm.layers.map((l) => l.id).toList();
      final drag = await tester.startGesture(
        tester.getCenter(find.byType(ReorderableDragStartListener).first),
      );
      await drag.moveBy(const Offset(0, 156));
      // Advance the pickup animation while holding the pointer. tester.drag
      // without a frame drops immediately and undo would undo that completed
      // reorder, rather than exercising a still-finishing drop after undo.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await drag.up();
      s.vm.undo();
      s.host.interaction.resetForPageChange();
      expect(s.vm.findLayerById('photo')!.width, 200);
      // The drop animation's final tick precedes this frame's widget rebuild.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        s.vm.layers.map((l) => l.id),
        isNot(orderedEquals(before)),
        reason: 'The actual drag must have reached another list position.',
      );
      expect(s.vm.findLayerById('photo')!.width, 200);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a replaced photo ignores the old thumbnail completing late', (
    tester,
  ) async {
    final s = await _mount(tester, inlineOrder: true);
    final bytes = (await tester.runAsync(
      () => File('assets/snapfit_home_square.jpg').readAsBytes(),
    ))!;
    final first = _Photo(), second = _Photo();
    final oldResult = Completer<Uint8List?>(),
        newResult = Completer<Uint8List?>();
    when(() => first.id).thenReturn('old-photo');
    when(() => second.id).thenReturn('new-photo');
    when(
      () => first.thumbnailDataWithSize(const ThumbnailSize.square(120)),
    ).thenAnswer((_) => oldResult.future);
    when(
      () => second.thumbnailDataWithSize(const ThumbnailSize.square(120)),
    ).thenAnswer((_) => newResult.future);
    s.vm.updateLayer(s.vm.findLayerById('photo')!.copyWith(asset: first));
    await tester.pumpAndSettle();
    s.vm.updateLayer(s.vm.findLayerById('photo')!.copyWith(asset: second));
    await tester.pumpAndSettle();
    oldResult.complete(bytes);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    final latestBytes = Uint8List.fromList(bytes);
    newResult.complete(latestBytes);
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect((image.imageProvider as MemoryImage).bytes, same(latestBytes));
    s.host.rebuild();
    await tester.pumpAndSettle();
    verify(
      () => first.thumbnailDataWithSize(const ThumbnailSize.square(120)),
    ).called(1);
    verify(
      () => second.thumbnailDataWithSize(const ThumbnailSize.square(120)),
    ).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'review: repeated arrangement visits detach controllers and photo listeners',
    (tester) async {
      final s = await _mount(tester);
      final source = (await tester.runAsync(
        () => File('assets/snapfit_home_square.jpg').readAsBytes(),
      ))!;
      final asset = _Photo();
      when(() => asset.id).thenReturn('cycle-photo');
      when(
        () => asset.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).thenAnswer((_) async => Uint8List.fromList(source));
      s.vm.updatePageLayers([
        LayerModel(
          id: 'cycle',
          type: LayerType.image,
          position: Offset.zero,
          width: 100,
          height: 100,
          asset: asset,
        ),
      ], recordHistory: false);
      final cache = PaintingBinding.instance.imageCache;
      final oldBudget = cache.maximumSizeBytes;
      cache.maximumSizeBytes = 2 * 1024 * 1024;
      addTearDown(() {
        cache.clear();
        cache.maximumSizeBytes = oldBudget;
      });
      for (var visit = 0; visit < 8; visit++) {
        s.host.openOrder();
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pumpAndSettle();
        final controller = tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .scrollController!;
        await tester.tap(find.byTooltip('겹침 순서 닫기'));
        await tester.pumpAndSettle();
        expect(controller.hasClients, isFalse);
        expect(find.byType(ReorderableListView), findsNothing);
        expect(cache.liveImageCount, 0);
        expect(cache.pendingImageCount, 0);
        expect(cache.currentSizeBytes, lessThanOrEqualTo(2 * 1024 * 1024));
        expect(tester.takeException(), isNull);
      }
    },
  );
}

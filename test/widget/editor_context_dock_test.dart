import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

class _ThumbnailAsset extends Mock implements AssetEntity {}

class _Host extends ConsumerStatefulWidget {
  const _Host({super.key});
  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  late final LayerInteractionManager manager;
  final modes = <EditorMode>[];
  final modeRouteCurrent = <bool>[];
  EditorMode mode = EditorMode.none;
  bool launchModeSheet = false;
  var photos = 0, replacements = 0, crops = 0, decorations = 0, canvasTaps = 0;
  @override
  void initState() {
    super.initState();
    manager = LayerInteractionManager(
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
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(albumEditorViewModelProvider).value!;
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => canvasTaps++,
        child: const SizedBox.expand(key: ValueKey('stable-editor-body')),
      ),
      bottomNavigationBar: EditorContextDock(
        currentMode: mode,
        layers: state.layers,
        interaction: manager,
        onModeChanged: (value) {
          modes.add(value);
          modeRouteCurrent.add(ModalRoute.of(context)?.isCurrent ?? false);
          if (launchModeSheet) {
            showModalBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(
                height: 200,
                child: Center(child: Text('새 페이지 도구')),
              ),
            );
          }
        },
        onAddPhoto: () => photos++,
        onRefresh: () => setState(() {}),
        onOpenGallery: (_) async {
          replacements++;
        },
        onOpenCrop: (_) async {
          crops++;
        },
        onOpenDecorate: (_) {
          decorations++;
        },
        canUndo: state.canUndo,
        canRedo: state.canRedo,
        onUndo: () {
          ref.read(albumEditorViewModelProvider.notifier).undo();
          manager.resetForPageChange();
        },
        onRedo: () {
          ref.read(albumEditorViewModelProvider.notifier).redo();
          manager.resetForPageChange();
        },
      ),
    );
  }

  void changeMode(EditorMode value) => setState(() => mode = value);

  bool get canUndo =>
      ref.read(albumEditorViewModelProvider).requireValue.canUndo;

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
            interaction: manager,
          ),
        ),
      ),
    );
  }
}

Future<({AlbumEditorViewModel vm, _HostState host})> _mount(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
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
  vm.updatePageLayers([
    LayerModel(
      id: 'photo',
      type: LayerType.image,
      position: const Offset(40, 40),
      width: 200,
      height: 200,
      imageUrl: 'asset:assets/snapfit_home_square.jpg',
    ),
    LayerModel(
      id: 'text',
      type: LayerType.text,
      position: const Offset(50, 50),
      width: 200,
      height: 50,
      text: '우리의 여행',
    ),
  ], recordHistory: false);
  final host = GlobalKey<_HostState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('editor-tools-proof'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: _Host(key: host),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (vm: vm, host: host.currentState!);
}

void main() {
  testWidgets('native editor tool design proofs', (tester) async {
    await tester.runAsync(() async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font in (entry['fonts'] as List).cast<Map>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
    });
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('editor-tools-proof')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          final dir = Directory('output/editor-tools-refresh')
            ..createSync(recursive: true);
          File(
            '${dir.path}/$name.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    for (final dark in [false, true]) {
      final s = await _mount(tester, dark: dark);
      final suffix = dark ? '-dark' : '';
      s.host.manager.setSelectedLayer('photo');
      await tester.pumpAndSettle();
      await capture('dock$suffix');
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      await capture('more$suffix');
      await tester.tap(find.byTooltip('편집 도구 닫기'));
      await tester.pumpAndSettle();
      s.host.openOrder();
      await tester.pumpAndSettle();
      await capture('rearrange$suffix');
      await tester.tap(find.byTooltip('재배치 닫기'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
  }, skip: !const bool.fromEnvironment('EXPORT_EDITOR_TOOLS'));

  testWidgets(
    'long rearrange lists build lazily, reuse nearby thumbnails and evict distant ones',
    (tester) async {
      final s = await _mount(tester);
      final assets = List.generate(72, (_) => _ThumbnailAsset());
      for (final (i, asset) in assets.indexed) {
        when(() => asset.id).thenReturn('asset-$i');
        when(
          () => asset.thumbnailDataWithSize(const ThumbnailSize.square(120)),
        ).thenAnswer((_) async => null);
      }
      s.vm.updatePageLayers([
        for (final (i, asset) in assets.indexed)
          LayerModel(
            id: 'thumb-$i',
            type: LayerType.image,
            position: Offset.zero,
            asset: asset,
            width: 120,
            height: 120,
            zIndex: i,
          ),
      ], recordHistory: false);
      s.host.openOrder();
      await tester.pumpAndSettle();
      expect(
        find.byType(ReorderableDragStartListener).evaluate().length,
        lessThan(30),
      );
      await tester.tap(find.byKey(const ValueKey('thumb-71')));
      await tester.pumpAndSettle();
      verify(
        () =>
            assets.last.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).called(1);
      final list = find.byType(ReorderableListView);
      final controller = tester
          .widget<ReorderableListView>(list)
          .scrollController!;
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      for (final index in [60, 48, 36, 24, 12, 0]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('thumb-$index')),
          500,
          scrollable: scrollable,
          maxScrolls: 40,
        );
        await tester.pumpAndSettle();
      }
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      verify(
        () =>
            assets.last.thumbnailDataWithSize(const ThumbnailSize.square(120)),
      ).called(1);
      await tester.tap(find.byTooltip('재배치 닫기'));
      await tester.pumpAndSettle();
      expect(controller.hasClients, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late reorder cannot change a new draft with reused page ids', (
    tester,
  ) async {
    final s = await _mount(tester);
    final session = s.vm.editSessionIdentity;
    s.host.openOrder();
    await tester.pumpAndSettle();
    final reorder = tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder!;
    s.vm.resetForCreate();
    s.vm.updatePageLayers([
      LayerModel(id: 'new-a', type: LayerType.text, position: Offset.zero),
      LayerModel(id: 'new-b', type: LayerType.text, position: Offset.zero),
    ], recordHistory: false);
    expect(identical(s.vm.editSessionIdentity, session), isFalse);
    reorder(0, 2);
    await tester.pumpAndSettle();
    expect(s.vm.layers.map((l) => l.id), ['new-a', 'new-b']);
    expect(s.host.canUndo, isFalse);
    await tester.tap(find.byTooltip('재배치 닫기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rearrange highlight reflects the open mode only', (
    tester,
  ) async {
    final s = await _mount(tester);
    Color? color() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byTooltip('재배치'),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    for (final selected in [null, 'photo', 'text']) {
      if (selected == null) {
        s.host.manager.clearSelection();
      } else {
        s.host.manager.setSelectedLayer(selected);
      }
      await tester.pumpAndSettle();
      expect(color(), Colors.transparent);
    }
    s.host.changeMode(EditorMode.layer);
    await tester.pumpAndSettle();
    expect(color(), isNot(Colors.transparent));
    s.host.changeMode(EditorMode.none);
    await tester.pumpAndSettle();
    expect(color(), Colors.transparent);
  });

  testWidgets(
    'more removes duplicated primary tools and releases canvas for photo positioning',
    (tester) async {
      final s = await _mount(tester);
      s.host.manager.setSelectedLayer('photo');
      await tester.pumpAndSettle();
      final original = s.vm.layers.map((l) => (l.id, l.zIndex)).toList();
      final barriers = find.byType(ModalBarrier).evaluate().length;
      for (final expected in [true, false, true]) {
        await tester.tap(find.text('더보기'));
        await tester.pumpAndSettle();
        final sheet = find.byKey(const ValueKey('editor-more-sheet'));
        for (final label in ['사진 바꾸기', '자르기·구도', '사진 꾸미기']) {
          expect(
            find.descendant(of: sheet, matching: find.text(label)),
            findsNothing,
          );
        }
        await tester.tap(find.text('사진 위치 조정'));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(s.host.manager.isImagePanMode, expected);
        expect(find.byType(ModalBarrier).evaluate().length, barriers);
        final taps = s.host.canvasTaps;
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('stable-editor-body'))),
        );
        expect(s.host.canvasTaps, taps + 1);
        expect(s.vm.layers.map((l) => (l.id, l.zIndex)), original);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'more fully dismisses before another tool opens; rapid repeats run once',
    (tester) async {
      final s = await _mount(tester);
      s.host.launchModeSheet = true;
      final barriers = find.byType(ModalBarrier).evaluate().length;
      s.host.manager.setSelectedLayer('photo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      final action = tester.widget<ListTile>(
        find.ancestor(of: find.text('레이아웃'), matching: find.byType(ListTile)),
      );
      action.onTap!();
      action.onTap!();
      await tester.pumpAndSettle();
      expect(s.host.modes, [EditorMode.layout]);
      expect(s.host.modeRouteCurrent, [true]);
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsNothing);
      expect(find.text('새 페이지 도구').hitTestable(), findsOneWidget);
      Navigator.pop(tester.element(find.text('새 페이지 도구')));
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier).evaluate().length, barriers);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('stable-editor-body'))),
      );
      expect(s.host.canvasTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a page change during dismissal discards the pending tool action',
    (tester) async {
      final s = await _mount(tester);
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('레이아웃'));
      s.vm.resetForCreate();
      await tester.pumpAndSettle();
      expect(s.host.modes, isEmpty);
      expect(find.byKey(const ValueKey('editor-more-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opacity uses the latest layer and ignores a stale page', (
    tester,
  ) async {
    final s = await _mount(tester);
    s.host.manager.setSelectedLayer('photo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    final change = tester.widget<Slider>(find.byType(Slider)).onChanged!;
    s.vm.updateLayer(s.vm.findLayerById('photo')!.copyWith(width: 240));
    change(.35);
    await tester.pumpAndSettle();
    expect(s.vm.findLayerById('photo')!.width, 240);
    expect(s.vm.findLayerById('photo')!.opacity, .35);
    s.vm.resetForCreate();
    change(.8);
    await tester.pumpAndSettle();
    expect(s.vm.layers, isEmpty);
    await tester.tap(find.byTooltip('편집 도구 닫기'));
    await tester.pumpAndSettle();
    change(.8);
    expect(s.vm.layers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rearrange selection stays open without changing order; explicit edit returns',
    (tester) async {
      final s = await _mount(tester);
      final original = s.vm.layers.map((l) => (l.id, l.zIndex)).toList();
      s.host.openOrder();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo')));
      await tester.pumpAndSettle();
      expect(find.byType(LayerManagerPanel), findsOneWidget);
      expect(s.host.manager.selectedLayerId, 'photo');
      expect(s.vm.layers.map((l) => (l.id, l.zIndex)), original);
      expect(s.host.canUndo, isFalse);
      await tester.tap(find.byTooltip('앞으로'));
      await tester.pumpAndSettle();
      expect(s.vm.layers.last.id, 'photo');
      expect(s.host.canUndo, isTrue);
      s.vm.undo();
      await tester.pumpAndSettle();
      expect(s.vm.layers.map((l) => (l.id, l.zIndex)), original);
      await tester.tap(
        find.byKey(const ValueKey('editor-layer-edit-selected')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LayerManagerPanel), findsNothing);
      expect(s.host.manager.selectedLayerId, 'photo');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no-op reordering does not add history', (tester) async {
    final s = await _mount(tester);
    s.host.openOrder();
    await tester.pumpAndSettle();
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorder!(0, 1);
    await tester.pumpAndSettle();
    expect(s.host.canUndo, isFalse);
    await tester.tap(find.byTooltip('재배치 닫기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('more supports large type and rotation dark=$dark', (
      tester,
    ) async {
      final s = await _mount(tester, width: 320, scale: 2, dark: dark);
      s.host.manager.setSelectedLayer('photo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('배경'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('배경'));
      await tester.pumpAndSettle();
      expect(s.host.modes, [EditorMode.backgroundColor]);
      expect(s.host.modeRouteCurrent, [true]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0])
    for (final dark in [false, true]) {
      testWidgets(
        'dock keeps canvas stable and order reachable at $width dark=$dark with large text',
        (tester) async {
          final s = await _mount(tester, width: width, dark: dark, scale: 1.6);
          final canvas = tester.getRect(
            find.byKey(const ValueKey('stable-editor-body')),
          );
          final dock = tester.getSize(
            find.byKey(const ValueKey('editor-context-dock')),
          );
          for (final id in ['photo', 'text']) {
            s.host.manager.setSelectedLayer(id);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(const ValueKey('stable-editor-body'))),
              canvas,
            );
            expect(
              tester.getSize(find.byKey(const ValueKey('editor-context-dock'))),
              dock,
            );
            expect(find.text('재배치').hitTestable(), findsOneWidget);
            await tester.tap(find.text('재배치'));
            await tester.pump();
            expect(s.host.modes.last, EditorMode.layer);
          }
          s.host.manager.clearSelection();
          await tester.pumpAndSettle();
          expect(find.text('재배치').hitTestable(), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const ValueKey('editor-context-dock'))),
            dock,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

  testWidgets(
    'context actions and details preserve crop replacement opacity and history',
    (tester) async {
      final s = await _mount(tester);
      await tester.tap(find.text('사진 추가'));
      expect(s.host.photos, 1);
      await tester.tap(find.byKey(const ValueKey('editor-more-tools')));
      await tester.pumpAndSettle();
      for (final label in ['꾸미기', '레이아웃', '배경'])
        expect(find.text(label), findsOneWidget);
      await tester.tap(find.text('레이아웃'));
      await tester.pumpAndSettle();
      expect(s.host.modes.last, EditorMode.layout);
      s.host.manager.setSelectedLayer('photo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 바꾸기'));
      await tester.tap(find.text('자르기·구도'));
      await tester.tap(find.text('사진 꾸미기'));
      expect(s.host.replacements, 1);
      expect(s.host.crops, 1);
      expect(s.host.decorations, 1);
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      for (final label in ['사진 위치 조정', '진하기', '삭제'])
        expect(find.text(label), findsOneWidget);
      await tester.tap(find.text('진하기'));
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(.4);
      await tester.pumpAndSettle();
      expect(s.vm.findLayerById('photo')!.opacity, .4);
      await tester.tap(find.byTooltip('편집 도구 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('되돌리기'));
      await tester.pumpAndSettle();
      expect(s.vm.findLayerById('photo')!.opacity, 1);
      await tester.tap(find.byTooltip('다시하기'));
      await tester.pumpAndSettle();
      expect(s.vm.findLayerById('photo')!.opacity, .4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deletion closes element details and restores add tools', (
    tester,
  ) async {
    final s = await _mount(tester);
    s.host.manager.setSelectedLayer('photo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(s.vm.findLayerById('photo'), isNull);
    expect(find.text('사진 추가').hitTestable(), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byTooltip('편집 도구 닫기'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_canvas.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

class _Boot extends ConsumerStatefulWidget {
  const _Boot();
  @override
  ConsumerState<_Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<_Boot> {
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
            albumTitle: 'PC 편집 검증',
            initialCover: coverSizes.first,
            pages: [
              const [],
              [
                LayerModel(
                  id: 'desktop-shape',
                  type: LayerType.decoration,
                  position: const Offset(150, 150),
                  width: 80,
                  height: 70,
                  rotation: 30,
                  decorationFillColor: '#44AABB',
                ),
              ],
            ],
          );
      setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      ready ? const PageEditorScreen(initialPageIndex: 1) : const SizedBox();
}

void main() {
  Future<ProviderContainer> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
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
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: _Boot()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PageEditorScreen)),
    );
  }

  testWidgets(
    'PC workspace keeps pages canvas and tool panels in separate columns',
    (tester) async {
      await mount(tester);
      final pages = tester.getRect(
        find.byKey(const ValueKey('page-editor-desktop-pages')),
      );
      final canvas = tester.getRect(
        find.byKey(const ValueKey('page-editor-desktop-canvas')),
      );
      final tools = tester.getRect(
        find.byKey(const ValueKey('page-editor-desktop-tools')),
      );
      expect(pages.right, lessThanOrEqualTo(canvas.left));
      expect(canvas.right, lessThanOrEqualTo(tools.left));
      expect(find.text('사진 추가'), findsOneWidget);
      expect(find.text('앨범 저장'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mouse selects drags rotated layer then delete undo and redo affect same page',
    (tester) async {
      final container = await mount(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final canvas = tester.widget<PageEditorCanvas>(
        find.byType(PageEditorCanvas),
      );
      // Template import remaps source coordinates to the album's canvas. Use
      // the actual transformed layer centre, rather than assuming that the
      // original fixture coordinates survive remapping or workspace resizing.
      final hitTarget = find.byKey(
        const ValueKey('editor-layer-desktop-shape'),
      );
      expect(hitTarget, findsOneWidget);
      final center = tester.getCenter(hitTarget);
      expect(
        tester.getRect(find.byType(PageEditorCanvas)).contains(center),
        isTrue,
      );
      Future<void> click(int id) async {
        final contact = await tester.createGesture(
          pointer: id,
          kind: PointerDeviceKind.mouse,
        );
        await contact.addPointer(location: center);
        await contact.down(center);
        await tester.pump(const Duration(milliseconds: 350));
        await contact.up();
        await contact.removePointer();
        // A contact's arena can be held briefly by the double-tap recognizer.
        // Real engines issue a fresh pointer ID for the next button contact.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
      }

      await click(101);
      expect(canvas.interaction.selectedLayerId, 'desktop-shape');
      // Clicking a selected image/shape keeps the PC selection active.
      await click(102);
      expect(canvas.interaction.selectedLayerId, 'desktop-shape');
      final before = vm.currentPage!.layers.single.position;
      final pointer = await tester.createGesture(
        pointer: 103,
        kind: PointerDeviceKind.mouse,
      );
      await pointer.addPointer(location: center);
      await pointer.down(center);
      await tester.pump(const Duration(milliseconds: 20));
      await pointer.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await pointer.moveBy(const Offset(90, 50));
      await tester.pump(const Duration(milliseconds: 20));
      await pointer.up();
      await tester.pumpAndSettle();
      final delta = vm.currentPage!.layers.single.position - before;
      // A rotated/scaled layer follows screen axes rather than its own rotation,
      // and a fast pointer event must not be truncated to the touch speed cap.
      expect(delta.dx, greaterThan(40));
      expect(delta.dy, greaterThan(10));
      expect(delta.dx / delta.dy, inInclusiveRange(1.3, 3.0));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(vm.currentPage!.layers, isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(vm.currentPage!.layers.single.id, 'desktop-shape');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(vm.currentPage!.layers, isEmpty);
      expect(tester.takeException(), isNull);
      await pointer.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );
}

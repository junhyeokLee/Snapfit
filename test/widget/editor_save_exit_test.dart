import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/page_editor_overlays.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'album_creation_draft_flow_test.dart' show MemoryCreationDraftStore;
import '../unit/album_creation_draft_test.dart' show creationDraftFixture;
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'home_screen_test.dart' show FakeAuthViewModel;

LayerModel _text(String text) => LayerModel(
  id: 'saved-copy',
  type: LayerType.text,
  position: const Offset(40, 50),
  text: text,
  width: 250,
  height: 50,
  textStyle: const TextStyle(fontSize: 24),
);

void main() {
  setUpAll(() async {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
    await loadCreationFonts();
  });

  Future<
    ({
      ProviderContainer container,
      AlbumEditorViewModel vm,
      MockAlbumRepository repo,
      GlobalKey<NavigatorState> nav,
      GlobalKey capture,
    })
  >
  boot(
    WidgetTester tester,
    Size size,
    bool dark, {
    MemoryCreationDraftStore? draftStore,
    String draftAccount = 'user',
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = MockAlbumRepository();
    if (draftStore?.draft != null &&
        draftStore!.draft!.createdAlbumId == null) {
      draftStore.draft = AlbumCreationDraft.fromJson(
        draftStore.draft!.toJson()..['createdAlbumId'] = 7,
      );
    }
    final album = fakeAlbum(
      id: 7,
      coverLayersJson: '{"layers":[]}',
    ).copyWith(targetPages: 20);
    when(() => repo.fetchAlbum('7')).thenAnswer((_) async => album);
    when(() => repo.fetchMyAlbums()).thenAnswer((_) async => [album]);
    when(() => repo.updateAlbum(7, any())).thenAnswer((_) async => album);
    final container = ProviderContainer(
      overrides: [
        if (draftStore != null)
          albumCreationDraftStoreProvider.overrideWithValue(draftStore),
        if (draftStore != null)
          authViewModelProvider.overrideWith(
            () => FakeAuthViewModel(
              UserInfo(id: draftAccount, name: '테스트', provider: 'email'),
            ),
          ),
        albumRepositoryProvider.overrideWithValue(repo),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);
    if (draftStore != null) await container.read(authViewModelProvider.future);
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    await vm.prepareAlbumForEdit(album);
    vm.loadPendingEditAlbumIfNeeded(const Size(500, 666.67));
    vm.goToPage(1);
    vm.updatePageLayers([_text('원래 문구')]);
    await vm.saveFullAlbum();
    final nav = GlobalKey<NavigatorState>(), capture = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            navigatorKey: nav,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: RepaintBoundary(key: capture, child: child!),
            ),
            home: const Scaffold(body: Center(child: Text('리더로 돌아옴'))),
          ),
        ),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<bool>(
        builder: (_) => PageEditorScreen(
          initialPageIndex: 1,
          returnToPreviousOnSave: true,
          creationDraftId: draftStore == null ? null : 'draft-a',
          creationDraftOwner: draftStore == null ? null : 'user',
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      container: container,
      vm: vm,
      repo: repo,
      nav: nav,
      capture: capture,
    );
  }

  Future<void> back(WidgetTester tester) async {
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    (bar.leading! as IconButton).onPressed!();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'full album save removes its linked creation draft only after success',
    (tester) async {
      final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      session.vm.updatePageLayers([_text('완성한 앨범')]);
      when(
        () => session.repo.updateAlbum(7, any()),
      ).thenThrow(StateError('retry'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.draft, isNotNull);
      when(
        () => session.repo.updateAlbum(7, any()),
      ).thenAnswer((_) async => fakeAlbum(id: 7));
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.draft, isNull);
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft cleanup failure does not turn a successful album save into a failed save',
    (tester) async {
      final store = MemoryCreationDraftStore()
        ..draft = creationDraftFixture()
        ..failRemove = true;
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      session.vm.updatePageLayers([_text('완성한 앨범')]);
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(store.draft, isNotNull);
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      expect(find.text('앨범은 저장했지만 임시 저장은 정리하지 못했어요.'), findsOneWidget);
      expect(session.vm.hasUnsavedChanges, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual checkpoint retains changes without uploading, and failure is retryable',
    (tester) async {
      final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      session.vm.updatePageLayers([_text('새로 꾸민 문구')]);
      session.vm.updatePageBackgroundColor(0xFFDAE8E3);
      session.vm.goToPage(3);
      await tester.pumpAndSettle();
      clearInteractions(session.repo);
      store.failSave = true;
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pumpAndSettle();
      expect(store.draft!.editorCheckpoint, isNull);
      expect(find.textContaining('임시 저장하지 못했어요'), findsOneWidget);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(session.vm.pages[1].layers.single.text, '새로 꾸민 문구');
      store.failSave = false;
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pumpAndSettle();
      final saved = store.draft!.editorCheckpoint!;
      expect(saved.pageIndex, 3);
      expect(saved.pages[1].backgroundColor, 0xFFDAE8E3);
      expect(saved.pages[1].layers.single.text, '새로 꾸민 문구');
      expect(saved.pages.length, 21);
      expect(session.vm.hasUnsavedChanges, isTrue);
      verifyNever(() => session.repo.updateAlbum(any(), any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inactivity checkpoints queue the newest work, even during an earlier write',
    (tester) async {
      final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      final gate = Completer<void>();
      store.saving = gate;
      session.vm.updatePageLayers([_text('첫 변경')]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      session.vm.updatePageLayers([_text('최신 변경')]);
      session.vm.goToPage(4);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        store.draft!.editorCheckpoint!.pages[1].layers.single.text,
        '최신 변경',
      );
      expect(store.draft!.editorCheckpoint!.pageIndex, 4);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an old editor cannot replace a newer draft', (tester) async {
    final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
    final session = await boot(
      tester,
      const Size(390, 844),
      false,
      draftStore: store,
    );
    session.vm.updatePageLayers([_text('수정')]);
    store.draft = creationDraftFixture(id: 'newer');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
    await tester.pumpAndSettle();
    expect(store.draft!.id, 'newer');
    expect(store.draft!.editorCheckpoint, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mismatched account cannot write the linked draft', (
    tester,
  ) async {
    final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
    final session = await boot(
      tester,
      const Size(390, 844),
      false,
      draftStore: store,
      draftAccount: 'other',
    );
    session.vm.updatePageLayers([_text('수정')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
    await tester.pumpAndSettle();
    expect(store.draft!.editorCheckpoint, isNull);
    expect(find.textContaining('로그인한 계정을 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discard replaces a background checkpoint with entry content, with safe failure',
    (tester) async {
      final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      session.vm.updatePageLayers([_text('버릴 문구')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pumpAndSettle();
      expect(
        store.draft!.editorCheckpoint!.pages[1].layers.single.text,
        '버릴 문구',
      );
      store.failSave = true;
      await back(tester);
      await tester.tap(find.text('저장 안함'));
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(session.vm.pages[1].layers.single.text, '버릴 문구');
      store.failSave = false;
      await back(tester);
      await tester.tap(find.text('저장 안함'));
      await tester.pumpAndSettle();
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      expect(
        store.draft!.editorCheckpoint!.pages[1].layers.single.text,
        '원래 문구',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full save waits for pending checkpoints and never leaves a resurrected draft',
    (tester) async {
      final store = MemoryCreationDraftStore()..draft = creationDraftFixture();
      final session = await boot(
        tester,
        const Size(390, 844),
        false,
        draftStore: store,
      );
      session.vm.updatePageLayers([_text('최종 수정')]);
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      store.saving = gate;
      await tester.tap(find.byKey(const ValueKey('editor-save-draft')));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PageEditorSaveOverlay), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(store.draft, isNull);
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(store.draft, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'creation editor draft exit fits and keeps work $size dark=$dark',
        (tester) async {
          final store = MemoryCreationDraftStore()
            ..draft = creationDraftFixture();
          final session = await boot(tester, size, dark, draftStore: store);
          session.vm.updatePageLayers([
            LayerModel(
              id: 'qa-photo',
              type: LayerType.image,
              position: const Offset(24, 32),
              width: 250,
              height: 300,
              imageUrl: 'asset:assets/frame_preview/alpine_lake.jpg',
            ),
            _text('새로 꾸민 여행').copyWith(position: const Offset(24, 348)),
          ]);
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('EDITOR_FLOW_QA')) {
            await _captureEditor(
              tester,
              session.capture,
              'editor-draft-workspace',
              size,
              dark,
            );
          }
          await back(tester);
          expect(find.text('임시 저장 후 나가기'), findsOneWidget);
          if (const bool.fromEnvironment('EDITOR_FLOW_QA')) {
            await _captureEditor(
              tester,
              session.capture,
              'editor-draft-exit',
              size,
              dark,
            );
          }
          store.failSave = true;
          await tester.tap(find.text('임시 저장 후 나가기'));
          await tester.pumpAndSettle();
          expect(find.byType(PageEditorScreen), findsOneWidget);
          store.failSave = false;
          await back(tester);
          await tester.tap(find.text('임시 저장 후 나가기'));
          await tester.pumpAndSettle();
          expect(find.text('리더로 돌아옴'), findsOneWidget);
          expect(
            store.draft!.editorCheckpoint!.pages[1].layers.last.text,
            '새로 꾸민 여행',
          );
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets('exit dismissal and discard safety $size dark=$dark', (
        tester,
      ) async {
        final session = await boot(tester, size, dark);
        session.vm.updatePageLayers([_text('수정한 문구')]);
        session.vm.goToPage(2);
        await tester.pumpAndSettle();
        await back(tester);
        expect(find.text('변경 내용을 저장할까요?'), findsOneWidget);
        if (const bool.fromEnvironment('EDITOR_FLOW_QA')) {
          await tester.runAsync(() async {
            final image =
                await (session.capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'output/editor-flow-qa/save-exit-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        session.nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(session.vm.pages[1].layers.single.text, '수정한 문구');
        await back(tester);
        await tester.tap(find.text('저장 안함'));
        await tester.pumpAndSettle();
        expect(find.text('리더로 돌아옴'), findsOneWidget);
        expect(session.vm.pages[1].layers.single.text, '원래 문구');
        expect(session.vm.hasUnsavedChanges, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'creation editor exit remains usable with large text at $size',
      (tester) async {
        final store = MemoryCreationDraftStore()
          ..draft = creationDraftFixture();
        final session = await boot(
          tester,
          size,
          false,
          draftStore: store,
          textScale: 1.6,
        );
        expect(tester.takeException(), isNull, reason: 'initial editor layout');
        session.vm.updatePageLayers([_text('확대해서 보는 문구')]);
        await tester.pumpAndSettle();
        await back(tester);
        expect(tester.takeException(), isNull, reason: 'exit dialog layout');
        final action = find.text('임시 저장 후 나가기');
        expect(action, findsOneWidget);
        expect(tester.getRect(action).overlaps(Offset.zero & size), isTrue);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('리더로 돌아옴'), findsOneWidget);
        expect(
          store.draft!.editorCheckpoint!.pages[1].layers.single.text,
          '확대해서 보는 문구',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saving blocks back and double submit, then returns to reader without library wait',
    (tester) async {
      final session = await boot(tester, const Size(844, 390), false);
      final gate = Completer<void>(), refresh = Completer<void>();
      when(() => session.repo.updateAlbum(7, any())).thenAnswer((_) async {
        await gate.future;
        return fakeAlbum(id: 7);
      });
      when(() => session.repo.fetchMyAlbums()).thenAnswer((_) async {
        await refresh.future;
        return [];
      });
      session.vm.updatePageLayers([_text('저장한 문구')]);
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PageEditorSaveOverlay), findsOneWidget);
      expect(find.text('페이지와 편집 내용을 저장하고 있어요'), findsOneWidget);
      expect(await session.nav.currentState!.maybePop(), isTrue);
      await tester.pump();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      expect(session.vm.hasUnsavedChanges, isFalse);
      refresh.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps content and route, with friendly retry message',
    (tester) async {
      final session = await boot(tester, const Size(390, 844), false);
      session.vm.updatePageLayers([_text('잃으면 안 되는 문구')]);
      when(
        () => session.repo.updateAlbum(7, any()),
      ).thenThrow(StateError('internal-secret'));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(find.byType(PageEditorSaveOverlay), findsNothing);
      expect(session.vm.layers.single.text, '잃으면 안 되는 문구');
      expect(find.textContaining('편집 내용은 유지'), findsOneWidget);
      expect(find.textContaining('internal-secret'), findsNothing);
      expect(session.vm.hasUnsavedChanges, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _captureEditor(
  WidgetTester tester,
  GlobalKey capture,
  String screen,
  Size size,
  bool dark,
) async {
  await tester.runAsync(() async {
    final image =
        await (capture.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'output/editor-flow-qa/$screen-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

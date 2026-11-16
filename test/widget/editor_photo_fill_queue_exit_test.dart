import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_photo_fill_screen.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_creation_draft_test.dart' show creationDraftFixture;
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'album_creation_draft_flow_test.dart' show MemoryCreationDraftStore;
import 'home_screen_test.dart' show FakeAuthViewModel;

const _owner = 'user';
const _canvas = Size(500, 375);
const _sourceProduct = 'template:-9531';
const _backgrounds = [0xFFFFF5E8, 0xFFE9F5EE, 0xFFEDF1FA];

class _Photo extends Mock implements AssetEntity {}

AssetEntity _photo() {
  final photo = _Photo();
  when(() => photo.id).thenReturn('queue-only-photo');
  when(() => photo.width).thenReturn(800);
  when(() => photo.height).thenReturn(600);
  when(() => photo.orientation).thenReturn(0);
  when(() => photo.file).thenAnswer((_) async => null);
  when(
    () => photo.thumbnailDataWithSize(const ThumbnailSize.square(150)),
  ).thenAnswer((_) async => null);
  return photo;
}

List<List<LayerModel>> _pages() => [
  for (var page = 0; page < 3; page++)
    [
      LayerModel(
        id: 'photo-$page',
        type: LayerType.image,
        position: const Offset(24, 24),
        width: 210,
        height: 240,
      ),
      LayerModel(
        id: 'caption-$page',
        type: LayerType.text,
        position: const Offset(250, 48),
        width: 210,
        height: 60,
        text: '원래 기록 $page',
        textStyle: const TextStyle(fontSize: 14),
      ),
    ],
];

String _document(List<List<LayerModel>> pages) => jsonEncode({
  'printProduct': {
    'id': 'REDP_200X150_HARD',
    'trimWidthMm': 200,
    'trimHeightMm': 150,
  },
  'sourceTemplate': {'productKey': _sourceProduct},
  'pages': [
    for (var page = 0; page < pages.length; page++)
      {
        'index': page,
        'isCover': page == 0,
        'backgroundColor': _backgrounds[page],
        'layers': [
          for (final layer in pages[page])
            LayerExportMapper.toJson(
              layer,
              canvasSize: _canvas,
              isCover: page == 0,
            ),
        ],
      },
  ],
});

Future<({AlbumEditorViewModel vm, MockAlbumRepository repo})> _boot(
  WidgetTester tester,
  MemoryCreationDraftStore store,
) async {
  const surface = Size(390, 844);
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final pages = _pages();
  final draft = creationDraftFixture(
    pages: pages,
    sourceTemplateProductKey: _sourceProduct,
  );
  store.draft = AlbumCreationDraft.fromJson(
    draft.toJson()
      ..['createdAlbumId'] = 7
      ..['pendingPhotos'] = []
      ..['selectedPhotoId'] = null
      ..['selectedSlot'] = null,
  );
  final album = Album(
    id: 7,
    userId: _owner,
    memberRole: 'OWNER',
    title: '사진 큐 보존',
    ratio: '${4 / 3}',
    targetPages: 2,
    updatedAt: '2026-11-11T00:00:00Z',
    coverLayersJson: _document(pages),
  );
  final repo = MockAlbumRepository();
  when(() => repo.fetchAlbum('7')).thenAnswer((_) async => album);
  when(() => repo.fetchMyAlbums()).thenAnswer((_) async => [album]);
  when(
    () => repo.updateAlbum(
      7,
      any(),
      expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
      requestId: any(named: 'requestId'),
      expectedUserId: any(named: 'expectedUserId'),
    ),
  ).thenAnswer((_) async => album);
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumCreationDraftStoreProvider.overrideWithValue(store),
      authViewModelProvider.overrideWith(
        () => FakeAuthViewModel(
          const UserInfo(id: _owner, name: '테스트', provider: 'email'),
        ),
      ),
      albumRepositoryProvider.overrideWithValue(repo),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  await vm.prepareAlbumForEdit(album);
  vm.loadPendingEditAlbumIfNeeded(_canvas);
  vm.goToPage(1);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: surface,
        builder: (_, __) => MaterialApp(
          navigatorKey: navigator,
          theme: SnapFitTheme.light(),
          home: const Scaffold(body: Center(child: Text('리더로 돌아옴'))),
        ),
      ),
    ),
  );
  unawaited(
    navigator.currentState!.push<bool>(
      MaterialPageRoute(
        builder: (_) => PageEditorScreen(
          initialPageIndex: 1,
          returnToPreviousOnSave: true,
          creationDraftId: draft.id,
          creationDraftOwner: _owner,
          initialPhotoFillSession: TemplatePhotoFillSession()..page = 1,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(vm.hasUnsavedChanges, isFalse);
  expect(vm.pages, hasLength(3));
  expect(vm.pages.map((page) => page.backgroundColor), _backgrounds);
  return (vm: vm, repo: repo);
}

Future<TemplatePhotoFillStep> _openPhotoFill(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('editor-more-tools')));
  await tester.pumpAndSettle();
  final entry = find.descendant(
    of: find.byKey(const ValueKey('editor-more-sheet')),
    matching: find.text('사진 여러 장 넣기'),
  );
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.byType(EditorPhotoFillScreen), findsOneWidget);
  return tester.widget<TemplatePhotoFillStep>(
    find.byType(TemplatePhotoFillStep),
  );
}

Future<void> _dismissFailureMessages(WidgetTester tester) async {
  // 현재 메시지와 뒤에 대기한 메시지를 실제로 닫은 뒤 도크를 누른다.
  ScaffoldMessenger.of(
    tester.element(find.byType(PageEditorScreen)),
  ).clearSnackBars();
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);
}

Future<void> _applyQueueOnly(
  WidgetTester tester, {
  bool pendingWrite = false,
}) async {
  final step = await _openPhotoFill(tester);
  final photo = _photo();
  step.session!.pendingPhotos.add(photo);
  step.session!.selectedPhoto = photo;
  // Use the actual workspace completion handler without placing a photograph.
  step.onContinue();
  if (pendingWrite) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  expect(find.byType(EditorPhotoFillScreen), findsNothing);
}

Future<void> _back(WidgetTester tester, {bool pendingWrite = false}) async {
  await tester.tap(find.byTooltip('편집 마치기'));
  if (pendingWrite) {
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

void _expectNoAlbumWrite(MockAlbumRepository repo) => verifyNever(
  () => repo.updateAlbum(
    any(),
    any(),
    expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
    requestId: any(named: 'requestId'),
    expectedUserId: any(named: 'expectedUserId'),
  ),
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

  testWidgets('pending queue persistence blocks exit before failure is known', (
    tester,
  ) async {
    final store = MemoryCreationDraftStore();
    final fixture = await _boot(tester, store);
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    final gate = Completer<void>();
    store.saving = gate;
    store.failSave = true;
    await _applyQueueOnly(tester, pendingWrite: true);
    expect(fixture.vm.hasUnsavedChanges, isFalse);
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);

    await _back(tester, pendingWrite: true);
    expect(find.byType(PageEditorScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.writes, 0);

    gate.complete();
    store.saving = null;
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.byType(PageEditorScreen), findsOneWidget);
    expect(find.text('임시 저장 후 나가기'), findsOneWidget);
    expect(find.text('저장 안함'), findsOneWidget);
    await tester.tap(find.text('계속 편집'));
    await tester.pumpAndSettle();
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    _expectNoAlbumWrite(fixture.repo);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a failed queue-only draft save retains choices and retries on exit',
    (tester) async {
      final store = MemoryCreationDraftStore();
      final fixture = await _boot(tester, store);
      final before = fixture.vm.exportFullAlbumLayersJson(null);
      store.failSave = true;
      await _applyQueueOnly(tester);
      expect(fixture.vm.hasUnsavedChanges, isFalse);
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
      await _back(tester);
      expect(find.text('임시 저장 후 나가기'), findsOneWidget);
      await tester.tap(find.text('임시 저장 후 나가기'));
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(store.draft!.pendingPhotos, isEmpty);

      await _dismissFailureMessages(tester);
      final resumed = await _openPhotoFill(tester);
      expect(resumed.session!.pendingPhotos.map((photo) => photo.id), [
        'queue-only-photo',
      ]);
      expect(resumed.session!.selectedPhoto!.id, 'queue-only-photo');
      await tester.tap(find.byKey(const ValueKey('editor-photo-fill-cancel')));
      await tester.pumpAndSettle();
      store.failSave = false;
      await _back(tester);
      await tester.tap(find.text('임시 저장 후 나가기'));
      await tester.pumpAndSettle();

      expect(find.byType(PageEditorScreen), findsNothing);
      expect(find.text('리더로 돌아옴'), findsOneWidget);
      expect(store.draft!.pendingPhotos.map((photo) => photo.id), [
        'queue-only-photo',
      ]);
      expect(store.draft!.selectedPhotoId, 'queue-only-photo');
      expect(store.draft!.selectedSlot, isNull);
      expect(
        store.draft!.editorCheckpoint!.sourceTemplateProductKey,
        _sourceProduct,
      );
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
      _expectNoAlbumWrite(fixture.repo);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discarding a failed queue-only change saves the entry queue', (
    tester,
  ) async {
    final store = MemoryCreationDraftStore();
    final fixture = await _boot(tester, store);
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    store.failSave = true;
    await _applyQueueOnly(tester);
    expect(fixture.vm.hasUnsavedChanges, isFalse);
    expect(store.writes, 0);
    store.failSave = false;

    await _back(tester);
    expect(find.text('저장 안함'), findsOneWidget);
    await tester.tap(find.text('저장 안함'));
    await tester.pumpAndSettle();

    expect(find.text('리더로 돌아옴'), findsOneWidget);
    expect(find.byType(PageEditorScreen), findsNothing);
    expect(store.writes, 1);
    expect(store.draft!.pendingPhotos, isEmpty);
    expect(store.draft!.selectedPhotoId, isNull);
    expect(store.draft!.currentPage, 1);
    expect(store.draft!.editorCheckpoint!.pages, hasLength(3));
    expect(
      store.draft!.editorCheckpoint!.sourceTemplateProductKey,
      _sourceProduct,
    );
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    expect(fixture.vm.hasUnsavedChanges, isFalse);
    _expectNoAlbumWrite(fixture.repo);
    expect(tester.takeException(), isNull);
  });

  testWidgets('album save cannot bypass a failed queue-only draft write', (
    tester,
  ) async {
    final store = MemoryCreationDraftStore();
    final fixture = await _boot(tester, store);
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    store.failSave = true;
    await _applyQueueOnly(tester);
    expect(fixture.vm.hasUnsavedChanges, isFalse);

    await _back(tester);
    expect(find.text('앨범 저장'), findsOneWidget);
    await tester.tap(find.text('앨범 저장'));
    await tester.pumpAndSettle();

    expect(find.byType(PageEditorScreen), findsOneWidget);
    expect(store.draft, isNotNull);
    expect(store.draft!.pendingPhotos, isEmpty);
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    _expectNoAlbumWrite(fixture.repo);

    // A failed prerequisite must leave the queue available for another attempt.
    await _dismissFailureMessages(tester);
    final resumed = await _openPhotoFill(tester);
    expect(resumed.session!.pendingPhotos.map((photo) => photo.id), [
      'queue-only-photo',
    ]);
    expect(resumed.session!.selectedPhoto!.id, 'queue-only-photo');
    await tester.tap(find.byKey(const ValueKey('editor-photo-fill-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(PageEditorScreen), findsOneWidget);
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    _expectNoAlbumWrite(fixture.repo);
    expect(tester.takeException(), isNull);
  });
}

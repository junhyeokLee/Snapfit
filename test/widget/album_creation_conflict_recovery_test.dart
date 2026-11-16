import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/album_edit_failure.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';

import '../helpers/creation_draft_fixtures.dart'
    show FakeAuthViewModel, MemoryCreationDraftStore;
import '../unit/album_editor_view_model_test.dart' show FakeStorageService;
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

const _owner = '11111111-1111-4111-8111-111111111111';
const _old = '2026-10-29T00:00:00.123456Z';
const _latest = '2026-10-29T00:00:01.123456Z';
LayerModel _text(String label) => LayerModel(
  id: label,
  type: LayerType.text,
  position: const Offset(20, 20),
  width: 200,
  height: 60,
  text: label,
  textStyle: const TextStyle(fontSize: 18),
);

class _Albums extends Mock implements AlbumRepository {
  bool conflict = true;
  bool loseFirstCreateResponse = false;
  Future<void>? createResponse, updateResponse;
  int creates = 0, updates = 0, reads = 0;
  final revisions = <String?>[];
  final createRequestIds = <String?>[], updateRequestIds = <String?>[];
  final createRequests = <CreateAlbumRequest>[];
  final updateRequests = <CreateAlbumRequest>[];
  @override
  Future<Album> createAlbum(
    CreateAlbumRequest request, {
    String? requestId,
    String? expectedUserId,
  }) async {
    creates++;
    createRequestIds.add(requestId);
    createRequests.add(request);
    // 서버가 첫 명령을 수락했지만 응답을 받지 못한 상황을 재현한다.
    if (loseFirstCreateResponse && creates == 1) {
      throw StateError('The first creation response was lost');
    }
    await createResponse;
    return Album(
      id: 71,
      userId: _owner,
      ratio: request.ratio,
      title: request.title,
      updatedAt: _old,
      memberRole: 'OWNER',
      coverLayersJson: request.coverLayersJson,
    );
  }

  @override
  Future<Album> updateAlbum(
    int id,
    CreateAlbumRequest request, {
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
  }) async {
    updates++;
    revisions.add(expectedUpdatedAt);
    updateRequestIds.add(requestId);
    updateRequests.add(request);
    await updateResponse;
    if (!conflict) {
      return Album(
        id: id,
        userId: _owner,
        ratio: request.ratio,
        title: request.title,
        coverLayersJson: request.coverLayersJson,
        updatedAt: _latest,
        memberRole: 'OWNER',
      );
    }
    throw const AlbumRevisionConflict();
  }

  @override
  Future<Album> fetchAlbum(String id) async {
    reads++;
    return Album(
      id: 71,
      userId: _owner,
      ratio: defaultCoverSize.ratio.toString(),
      updatedAt: _latest,
      memberRole: 'OWNER',
      title: '저장된 앨범',
      targetPages: 20,
      coverLayersJson:
          '{"pages":[{"index":0,"isCover":true,"layers":[]},{"index":1,"isCover":false,"layers":[]}]}',
    );
  }
}

class _FailLinkedStore extends MemoryCreationDraftStore {
  bool failLinked = true;
  @override
  Future<void> save(String owner, AlbumCreationDraft draft) async {
    if (failLinked && draft.createdAlbumId != null) {
      throw StateError('Local linked checkpoint quota/CAS/IO failure');
    }
    await super.save(owner, draft);
  }
}

Future<
  ({
    ProviderContainer container,
    _Albums albums,
    MemoryCreationDraftStore store,
  })
>
_mount(
  WidgetTester tester, {
  bool failLinked = false,
  bool conflict = true,
  bool pushed = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final draft = AlbumCreationDraft(
    id: 'draft-recovery',
    updatedAt: DateTime.utc(2026, 10, 29),
    title: '내 기기의 앨범',
    cover: defaultCoverSize,
    pageCount: 20,
    step: 1,
    showPhotoFill: false,
    hasSelectedMode: true,
    sourceLabel: '직접 만들기',
    usesPhysicalCanvas: true,
    preserveTypography: true,
    pages: [
      [_text('내가 편집한 표지')],
      [_text('잃으면 안 되는 내지')],
    ],
  );
  final store = (failLinked ? _FailLinkedStore() : MemoryCreationDraftStore())
    ..draft = draft;
  final albums = _Albums()..conflict = conflict;
  final storage = FakeStorageService();
  final container = ProviderContainer(
    overrides: [
      albumCreationDraftStoreProvider.overrideWithValue(store),
      albumRepositoryProvider.overrideWithValue(albums),
      albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumCreationCatalogProvider.overrideWith((_) => Stream.value([])),
      storageServiceProvider.overrideWithValue(storage),
      albumPersistenceServiceProvider.overrideWithValue(
        AlbumPersistenceService(storage, albums),
      ),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      authViewModelProvider.overrideWith(
        () => FakeAuthViewModel(
          const UserInfo(id: _owner, name: '나', provider: 'email'),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authViewModelProvider.future);
  await container.read(albumEditorViewModelProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: wrapCreation(
        pushed
            ? Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AlbumCreateFlowScreen(initialDraft: draft),
                    ),
                  ),
                  child: const Text('앨범 만들기 시작'),
                ),
              )
            : AlbumCreateFlowScreen(initialDraft: draft),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (pushed) {
    await tester.tap(find.text('앨범 만들기 시작'));
    await tester.pumpAndSettle();
  }
  return (container: container, albums: albums, store: store);
}

void main() {
  final exceptionReporter = reportTestException;
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
    reportTestException = (details, description) {
      // Browser formatting otherwise omits the failing layout/assertion.
      // ignore: avoid_print
      print('Creation recovery failure: ${details.exceptionAsString()}');
      if (details.stack != null) {
        // ignore: avoid_print
        print(details.stack.toString().split('\n').take(12).join('\n'));
      }
      exceptionReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  for (final conflict in [false, true]) {
    testWidgets(
      'linked checkpoint failure blocks page editing and retries only local persistence, conflict=$conflict',
      (tester) async {
        final fixture = await _mount(
          tester,
          failLinked: true,
          conflict: conflict,
        );
        final settings = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        final settingsState = tester.state(find.byType(AlbumCreateStep1));
        settings.onNext();
        await tester.pumpAndSettle();
        if (conflict) {
          await tester.tap(
            find.byKey(const ValueKey('creation-conflict-review')),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byType(PageEditorScreen), findsNothing);
        expect(find.text('작업 저장하고 계속하기'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          identical(
            settingsState,
            tester.state(
              find.byType(AlbumCreateStep1, skipOffstage: false),
            ),
          ),
          isTrue,
        );
        expect(
          find.text('앨범은 만들어졌어요. 현재 작업을 기기에 저장하지 못해 이동을 멈췄어요.'),
          findsOneWidget,
        );
        expect(fixture.store.draft!.createdAlbumId, isNull);
        expect(fixture.store.draft!.creationAttempt, isNotNull);
        expect(fixture.store.writes, 1);
        final vm = fixture.container.read(
          albumEditorViewModelProvider.notifier,
        );
        expect(vm.editingAlbumId, 71);
        expect(
          vm.pages.expand((page) => page.layers).map((layer) => layer.text),
          contains('잃으면 안 되는 내지'),
        );
        final originalRevision = vm.album!.updatedAt;
        final editorSession = vm.editSessionIdentity;
        final localDocument = vm.exportFullAlbumLayersJson(null);
        expect(fixture.albums.creates, 1);
        expect(fixture.albums.updates, 1);
        (fixture.store as _FailLinkedStore).failLinked = false;
        final retry = tester.widget<FilledButton>(
          find.byKey(const ValueKey('creation-checkpoint-retry')),
        ).onPressed!;
        // 재빌드 전 같은 콜백을 연속 호출해 중복 재시도 방어를 검증한다.
        retry();
        retry();
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(identical(editorSession, vm.editSessionIdentity), isTrue);
        expect(vm.exportFullAlbumLayersJson(null), localDocument);
        expect(fixture.store.draft!.createdAlbumId, 71);
        expect(
          fixture.store.draft!.editorCheckpoint!.sourceUpdatedAt,
          originalRevision,
        );
        expect(
          fixture.store.draft!.editorCheckpoint!.pages
              .expand((page) => page.layers)
              .map((layer) => layer.text),
          contains('잃으면 안 되는 내지'),
        );
        expect(fixture.albums.creates, 1);
        expect(fixture.albums.updates, 1);
        expect(fixture.store.writes, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'lost creation response retries the same durable command without resetting local work',
    (tester) async {
      final fixture = await _mount(tester, conflict: false);
      fixture.albums.loseFirstCreateResponse = true;
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pumpAndSettle();
      final vm = fixture.container.read(albumEditorViewModelProvider.notifier);
      final editorSession = vm.editSessionIdentity;
      final localDocument = vm.exportFullAlbumLayersJson(null);
      final attempt = fixture.store.draft!.creationAttempt!;
      expect(find.byType(PageEditorScreen), findsNothing);
      expect(vm.editingAlbumId, isNull);
      expect(fixture.albums.creates, 1);
      expect(fixture.albums.updates, 0);
      expect(fixture.store.draft!.createdAlbumId, isNull);
      expect(fixture.albums.createRequestIds.single, attempt.requestId);
      expect(
        fixture.store.draft!.pages!
            .expand((page) => page)
            .map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      final leaving = tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('앨범 만들기를 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속 만들기'));
      await tester.pumpAndSettle();
      await leaving;
      expect(
        find.byKey(const ValueKey('creation-entry-retry')),
        findsOneWidget,
      );
      expect(fixture.store.draft!.creationAttempt, attempt);

      final response = Completer<void>();
      fixture.albums.createResponse = response.future;
      final retry = tester.widget<FilledButton>(
        find.byKey(const ValueKey('creation-entry-retry')),
      ).onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(fixture.albums.creates, 2);
      expect(fixture.albums.createRequestIds, [
        attempt.requestId,
        attempt.requestId,
      ]);
      expect(
        fixture.albums.createRequests[1],
        fixture.albums.createRequests.first,
      );
      expect(fixture.store.draft!.creationAttempt, attempt);
      expect(identical(editorSession, vm.editSessionIdentity), isTrue);
      expect(vm.exportFullAlbumLayersJson(null), localDocument);
      response.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(fixture.albums.creates, 2);
      expect(fixture.albums.updates, 1);
      expect(fixture.store.draft!.createdAlbumId, 71);
      expect(
        fixture.store.draft!.editorCheckpoint!.pages
            .expand((page) => page.layers)
            .map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'leaving after an uncertain creation response saves the immutable recovery command',
    (tester) async {
      final fixture = await _mount(tester, conflict: false, pushed: true);
      fixture.albums.loseFirstCreateResponse = true;
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pumpAndSettle();
      final attempt = fixture.store.draft!.creationAttempt!;
      final localPages = fixture.store.draft!.toJson()['pages'];
      expect(fixture.albums.createRequestIds.single, attempt.requestId);
      final leaving = tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('앨범 만들기를 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('임시 저장 후 나가기'));
      await tester.pumpAndSettle();
      await leaving;
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      expect(fixture.albums.creates, 1);
      expect(fixture.albums.updates, 0);
      expect(fixture.store.writes, 2);
      expect(fixture.store.draft!.creationAttempt!.requestId, attempt.requestId);
      expect(fixture.store.draft!.creationAttempt!.seed, attempt.seed);
      expect(fixture.store.draft!.createdAlbumId, isNull);
      expect(fixture.store.draft!.toJson()['pages'], localPages);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'known creation conflict keeps its session and pending command when entry retry succeeds',
    (tester) async {
      final fixture = await _mount(tester);
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pumpAndSettle();
      expect(find.text('이미 만들어진 앨범이 있어요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('creation-conflict-keep')));
      await tester.pumpAndSettle();
      final vm = fixture.container.read(albumEditorViewModelProvider.notifier);
      final editorSession = vm.editSessionIdentity;
      final localDocument = vm.exportFullAlbumLayersJson(null);
      final attempt = fixture.store.draft!.creationAttempt!;
      expect(find.byType(PageEditorScreen), findsNothing);
      expect(fixture.albums.creates, 1);
      expect(fixture.albums.revisions, [_old]);
      expect(fixture.albums.reads, 0);
      expect(vm.editingAlbumId, 71);
      expect(vm.album!.updatedAt, _old);
      expect(vm.layers.single.text, '내가 편집한 표지');

      final response = Completer<void>();
      fixture.albums
        ..conflict = false
        ..updateResponse = response.future;
      final retry = tester.widget<FilledButton>(
        find.byKey(const ValueKey('creation-entry-retry')),
      ).onPressed!;
      retry();
      retry();
      await tester.pump();
      expect(fixture.albums.creates, 1);
      expect(fixture.albums.updates, 2);
      expect(
        fixture.albums.updateRequestIds[1],
        fixture.albums.updateRequestIds.first,
      );
      expect(
        fixture.albums.updateRequests[1],
        fixture.albums.updateRequests.first,
      );
      expect(fixture.albums.revisions, [_old, _old]);
      expect(fixture.store.draft!.creationAttempt, attempt);
      expect(identical(editorSession, vm.editSessionIdentity), isTrue);
      expect(vm.exportFullAlbumLayersJson(null), localDocument);
      response.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(fixture.albums.creates, 1);
      // 편집기 진입 시 원격 상태를 한 번 확인해도 로컬 문서를 덮어쓰지 않는다.
      expect(fixture.albums.reads, 1);
      expect(fixture.albums.revisions.take(2), [_old, _old]);
      expect(vm.album!.updatedAt, _latest);
      expect(vm.album!.title, '내 기기의 앨범');
      expect(vm.layers.single.text, '내가 편집한 표지');
      expect(
        vm.pages.expand((page) => page.layers).map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      expect(fixture.store.draft!.createdAlbumId, 71);
      expect(fixture.store.draft!.editorCheckpoint!.sourceUpdatedAt, _latest);
      expect(
        fixture.store.draft!.editorCheckpoint!.pages.first.layers.single.text,
        '내가 편집한 표지',
      );
      expect(
        fixture.store.draft!.editorCheckpoint!.pages
            .expand((page) => page.layers)
            .map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'known creation conflict reaches existing explicit reload UI with full local checkpoint and original revision',
    (tester) async {
      final fixture = await _mount(tester);
      tester.widget<AlbumCreateStep1>(find.byType(AlbumCreateStep1)).onNext();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creation-conflict-review')));
      await tester.pumpAndSettle();
      final vm = fixture.container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(find.text('최신 내용 확인'), findsOneWidget);
      expect(vm.album!.updatedAt, _old);
      expect(
        vm.pages.expand((page) => page.layers).map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      expect(fixture.store.draft!.createdAlbumId, 71);
      expect(fixture.store.draft!.editorCheckpoint!.sourceUpdatedAt, _old);
      expect(
        fixture.store.draft!.editorCheckpoint!.pages
            .expand((page) => page.layers)
            .map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      await tester.tap(find.text('최신 내용 확인'));
      await tester.pumpAndSettle();
      expect(find.text('버리고 불러오기'), findsOneWidget);
      await tester.tap(find.text('편집 유지'));
      await tester.pumpAndSettle();
      expect(vm.album!.updatedAt, _old);
      expect(
        vm.pages.expand((page) => page.layers).map((layer) => layer.text),
        contains('잃으면 안 되는 내지'),
      );
      await tester.tap(find.text('최신 내용 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('버리고 불러오기'));
      await tester.pumpAndSettle();
      expect(vm.album!.updatedAt, _latest);
      expect(fixture.albums.creates, 1);
      expect(fixture.albums.updates, 1);
      expect(fixture.albums.revisions, [_old]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

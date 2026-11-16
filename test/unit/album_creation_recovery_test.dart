import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store_io.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_attempt.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/album_edit_failure.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';

import 'album_editor_view_model_test.dart' show FakeStorageService;

const _owner = '11111111-1111-4111-8111-111111111111';
const _initialRevision = '2026-10-29T00:00:00.123456Z';

LayerModel _text(String text) => LayerModel(
  id: 'my-title',
  type: LayerType.text,
  position: const Offset(10, 10),
  width: 200,
  height: 50,
  text: text,
  textStyle: const TextStyle(fontSize: 20),
);

AlbumCreationDraft _draft(
  AlbumCreationAttempt attempt, {
  String title = '계속 만든 앨범',
}) => AlbumCreationDraft(
  id: attempt.draftId,
  updatedAt: DateTime.utc(2026, 10, 29),
  title: title,
  cover: defaultCoverSize,
  pageCount: 20,
  step: 1,
  showPhotoFill: false,
  hasSelectedMode: true,
  sourceLabel: '직접 만들기',
  usesPhysicalCanvas: true,
  preserveTypography: true,
  creationAttempt: attempt,
  pages: [
    [_text(title)],
  ],
);

class _Albums extends Mock implements AlbumRepository {
  final creates = <({CreateAlbumRequest seed, String key, String owner})>[];
  final updates = <({CreateAlbumRequest request, String revision})>[];
  final original = <String, Album>{};
  final revisions = <int, String>{};
  bool loseNextResponse = false;
  bool failNextUpdateBeforeCommit = false, loseNextUpdateResponse = false;
  Completer<void>? response;
  void Function(CreateAlbumRequest, String)? beforeCreate;

  @override
  Future<Album> createAlbum(
    CreateAlbumRequest request, {
    String? requestId,
    String? expectedUserId,
  }) async {
    if (requestId == null || expectedUserId == null)
      throw StateError('Missing durable identity');
    beforeCreate?.call(request, requestId);
    creates.add((seed: request, key: requestId, owner: expectedUserId));
    final album = original.putIfAbsent(requestId, () {
      final value = Album(
        id: 100 + original.length,
        userId: expectedUserId,
        title: request.title,
        ratio: request.ratio,
        updatedAt: _initialRevision,
        coverLayersJson: request.coverLayersJson,
        memberRole: 'OWNER',
      );
      revisions[value.id] = value.updatedAt;
      return value;
    });
    if (response != null) await response!.future;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const SocketException('Response lost after the server committed');
    }
    return album;
  }

  @override
  Future<Album> updateAlbum(
    int albumId,
    CreateAlbumRequest request, {
    String? expectedUpdatedAt,
    String? requestId,
    String? expectedUserId,
  }) async {
    updates.add((request: request, revision: expectedUpdatedAt!));
    if (failNextUpdateBeforeCommit) {
      failNextUpdateBeforeCommit = false;
      throw const SocketException('Stopped after receiving the created ID');
    }
    if (revisions[albumId] != expectedUpdatedAt)
      throw const AlbumRevisionConflict();
    final updated = '${updates.length}';
    revisions[albumId] = updated;
    if (loseNextUpdateResponse) {
      loseNextUpdateResponse = false;
      throw const SocketException('Cover save committed but response was lost');
    }
    return Album(
      id: albumId,
      userId: expectedUserId!,
      title: request.title,
      ratio: request.ratio,
      coverLayersJson: request.coverLayersJson,
      updatedAt: updated,
      memberRole: 'OWNER',
    );
  }
}

Future<ProviderContainer> _container(
  _Albums albums, {
  String? Function()? owner,
  Stream<String?>? changes,
}) async {
  final storage = FakeStorageService();
  final result = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(owner ?? () => _owner),
      albumEditorOwnerChangesProvider.overrideWith(
        (_) => changes ?? const Stream.empty(),
      ),
      albumRepositoryProvider.overrideWithValue(albums),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      storageServiceProvider.overrideWithValue(storage),
      albumPersistenceServiceProvider.overrideWithValue(
        AlbumPersistenceService(storage, albums),
      ),
    ],
  );
  await result.read(albumEditorViewModelProvider.future);
  return result;
}

void _bind(
  AlbumEditorViewModel vm, {
  String id = 'draft-one',
  AlbumCreationAttempt? attempt,
  required Future<void> Function(AlbumCreationAttempt) persist,
}) {
  vm.resetForCreate();
  vm.bindCreationDraft(
    ownerId: _owner,
    draftId: id,
    attempt: attempt,
    persist: persist,
  );
  vm.updatePageLayers([_text('처음의 표지')]);
}

void main() {
  for (final committedCover in [false, true]) {
    test(
      'restart before local acknowledgement preserves one ID, cover committed=$committedCover',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'snapfit-create-ack-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final store = LocalAlbumCreationDraftStore(
          directory: () async => directory,
        );
        await store.beginDraftWriteSession(_owner, 'draft-one');
        final albums = _Albums()
          ..failNextUpdateBeforeCommit = !committedCover
          ..loseNextUpdateResponse = committedCover;
        final first = await _container(albums);
        _bind(
          first.read(albumEditorViewModelProvider.notifier),
          persist: (attempt) => store.save(_owner, _draft(attempt)),
        );
        await expectLater(
          first
              .read(albumEditorViewModelProvider.notifier)
              .saveAlbumToBackend(const Size(500, 500)),
          throwsA(isA<SocketException>()),
        );
        first.dispose();
        // Neither createdAlbumId nor a final local success acknowledgement was
        // written. The original command must still resolve the server book.
        final reopened = LocalAlbumCreationDraftStore(
          directory: () async => directory,
        );
        final restored = (await reopened.load(_owner))!;
        expect(restored.createdAlbumId, isNull);
        await reopened.beginDraftWriteSession(
          _owner,
          restored.id,
          restoring: restored,
        );
        final second = await _container(albums);
        addTearDown(second.dispose);
        final resumed = second.read(albumEditorViewModelProvider.notifier);
        _bind(
          resumed,
          attempt: restored.creationAttempt,
          persist: (attempt) => reopened.save(_owner, _draft(attempt)),
        );
        resumed.updatePageLayers([_text('내 기기의 변경 내용')]);
        if (committedCover) {
          await expectLater(
            resumed.saveAlbumToBackend(const Size(500, 500)),
            throwsA(isA<AlbumRevisionConflict>()),
          );
          expect(resumed.layers.single.text, '내 기기의 변경 내용');
          expect(resumed.editingAlbumId, 100);
        } else {
          expect(await resumed.saveAlbumToBackend(const Size(500, 500)), 100);
        }
        expect(albums.original, hasLength(1));
        expect(albums.creates.first.key, albums.creates.last.key);
        expect(albums.updates.last.revision, _initialRevision);
      },
    );
  }

  test(
    'a failed durable write and an unbound editor never send create',
    () async {
      final albums = _Albums();
      final container = await _container(albums);
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      vm.resetForCreate();
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500)),
        throwsA(isA<AlbumCreationRecoveryRequired>()),
      );
      _bind(
        vm,
        persist: (_) async => throw const FileSystemException('disk full'),
      );
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500)),
        throwsA(isA<FileSystemException>()),
      );
      expect(albums.creates, isEmpty);
    },
  );

  test(
    'lost commit retries one immutable seed, then applies current cover with original CAS',
    () async {
      final albums = _Albums()..loseNextResponse = true;
      final container = await _container(albums);
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      AlbumCreationAttempt? saved;
      _bind(vm, persist: (value) async => saved = value);
      albums.beforeCreate = (seed, key) {
        expect(saved!.requestId, key);
        expect(saved!.seed, seed);
      };
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500), title: '원래 제목'),
        throwsA(isA<SocketException>()),
      );
      vm.updatePageLayers([_text('응답이 없어서 더 편집한 표지')]);
      final id = await vm.saveAlbumToBackend(
        const Size(500, 500),
        title: '바꾼 제목',
      );
      expect(id, 100);
      expect(albums.original, hasLength(1));
      expect(albums.creates.map((call) => call.key).toSet(), hasLength(1));
      expect(albums.creates.first.seed, albums.creates.last.seed);
      expect(albums.creates.last.seed.title, '원래 제목');
      expect(albums.updates.single.revision, _initialRevision);
      expect(albums.updates.single.request.title, '바꾼 제목');
      expect(
        albums.updates.single.request.coverLayersJson,
        contains('응답이 없어서 더 편집한 표지'),
      );
    },
  );

  test(
    'restart restores the exact on-disk command and original album instead of another book',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'snapfit-create-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = LocalAlbumCreationDraftStore(
        directory: () async => directory,
      );
      await store.beginDraftWriteSession(_owner, 'draft-one');
      final albums = _Albums()..loseNextResponse = true;
      final first = await _container(albums);
      final vm = first.read(albumEditorViewModelProvider.notifier);
      _bind(vm, persist: (attempt) => store.save(_owner, _draft(attempt)));
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500), title: '원래 제목'),
        throwsA(isA<SocketException>()),
      );
      first.dispose();
      final reopened = LocalAlbumCreationDraftStore(
        directory: () async => directory,
      );
      final restored = (await reopened.load(_owner))!;
      await reopened.beginDraftWriteSession(
        _owner,
        restored.id,
        restoring: restored,
      );
      final second = await _container(albums);
      addTearDown(second.dispose);
      final resumed = second.read(albumEditorViewModelProvider.notifier);
      _bind(
        resumed,
        attempt: restored.creationAttempt,
        persist: (attempt) => reopened.save(_owner, _draft(attempt)),
      );
      resumed.updatePageLayers([_text('다시 연 뒤의 내용')]);
      expect(
        await resumed.saveAlbumToBackend(
          const Size(500, 500),
          title: '다시 연 제목',
        ),
        100,
      );
      expect(albums.original, hasLength(1));
      expect(albums.creates.first.key, albums.creates.last.key);
      expect(
        albums.creates.first.seed.toJson(),
        albums.creates.last.seed.toJson(),
      );
      expect(albums.updates.single.revision, _initialRevision);
    },
  );

  test(
    'replayed old revision cannot overwrite a different tab document',
    () async {
      final albums = _Albums()..loseNextResponse = true;
      final container = await _container(albums);
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      _bind(vm, persist: (_) async {});
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500)),
        throwsA(isA<SocketException>()),
      );
      albums.revisions[100] = 'newer-other-tab-revision';
      vm.updatePageLayers([_text('내가 계속 만든 내용')]);
      await expectLater(
        vm.saveAlbumToBackend(const Size(500, 500)),
        throwsA(isA<AlbumRevisionConflict>()),
      );
      expect(albums.original, hasLength(1));
      expect(albums.revisions[100], 'newer-other-tab-revision');
      expect(albums.updates.single.revision, _initialRevision);
      expect(vm.editingAlbumId, 100);
      expect(vm.layers.single.text, '내가 계속 만든 내용');
    },
  );

  test(
    'A to B to A fences a late creation response and cannot start background save',
    () async {
      final changes = StreamController<String?>.broadcast(sync: true);
      addTearDown(changes.close);
      String? owner = _owner;
      final albums = _Albums()..response = Completer<void>();
      final container = await _container(
        albums,
        owner: () => owner,
        changes: changes.stream,
      );
      addTearDown(container.dispose);
      final watching = container.listen(
        albumEditorViewModelProvider,
        (_, __) {},
      );
      addTearDown(watching.close);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      _bind(vm, persist: (_) async {});
      final saving = vm.saveAlbumToBackend(const Size(500, 500));
      final failure = expectLater(
        saving,
        throwsA(isA<AlbumEditSessionChanged>()),
      );
      while (albums.creates.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      owner = 'other-owner';
      changes.add(owner);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(albumEditorOwnerChangesProvider).value,
        'other-owner',
      );
      owner = _owner;
      changes.add(owner);
      await Future<void>.delayed(Duration.zero);
      albums.response!.complete();
      await failure;
      expect(vm.editingAlbumId, isNull);
      expect(albums.updates, isEmpty);
    },
  );

  test(
    'starting an explicit new draft uses a different durable request',
    () async {
      final albums = _Albums();
      final container = await _container(albums);
      addTearDown(container.dispose);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final commands = <AlbumCreationAttempt>[];
      _bind(vm, persist: (attempt) async => commands.add(attempt));
      expect(await vm.saveAlbumToBackend(const Size(500, 500)), 100);
      _bind(
        vm,
        id: 'draft-two',
        persist: (attempt) async => commands.add(attempt),
      );
      expect(await vm.saveAlbumToBackend(const Size(500, 500)), 101);
      expect(commands.map((value) => value.requestId).toSet(), hasLength(2));
      expect(commands.map((value) => value.draftId), [
        'draft-one',
        'draft-two',
      ]);
      expect(
        jsonEncode(commands.first.toJson()),
        isNot(jsonEncode(commands.last.toJson())),
      );
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_edit_failure.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

const _rawRevision = '2026-10-25T01:02:03.123456Z';
Album _book({int id = 7, String revision = _rawRevision}) => Album(
  id: id,
  userId: 'owner',
  memberRole: 'EDITOR',
  updatedAt: revision,
  ratio: '1',
  title: 'Shared book',
  coverTheme: 'classic',
  coverLayersJson: jsonEncode({
    'pages': [
      {'index': 0, 'isCover': true, 'layers': <dynamic>[]},
      {'index': 1, 'isCover': false, 'layers': <dynamic>[]},
    ],
  }),
);
LayerModel _text(String value) => LayerModel(
  id: 'text',
  type: LayerType.text,
  position: const Offset(20, 30),
  width: 120,
  height: 40,
  text: value,
  textStyle: const TextStyle(fontSize: 16),
);

class _Asset extends Mock implements AssetEntity {}

class _Storage extends FakeStorageService {
  int calls = 0;
  Completer<UploadedUrls>? pending;
  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
    int? albumId,
  }) async {
    calls++;
    return pending?.future ??
        Future.value(
          const UploadedUrls(
            previewGsPath:
                'supabase://album-assets/owner/albums/7/images/p.jpg',
            originalGsPath:
                'supabase://album-assets/owner/albums/7/images/o.jpg',
          ),
        );
  }
}

class _Session {
  _Session(this.container, this.repo, this.storage);
  final ProviderContainer container;
  late final AlbumEditorViewModel vm;
  final MockAlbumRepository repo;
  final _Storage storage;
  final requests =
      <
        ({
          CreateAlbumRequest body,
          String? revision,
          String? key,
          String? actor,
        })
      >[];
  String? actor = 'owner';
  Album remote = _book();
  Future<Album> Function(CreateAlbumRequest)? onSave;
  Future<Album> save(CreateAlbumRequest body) async {
    if (onSave != null) return onSave!(body);
    remote = remote.copyWith(
      coverLayersJson: body.coverLayersJson,
      updatedAt: '${remote.updatedAt}1',
      title: body.title,
      coverTheme: body.coverTheme,
      ratio: body.ratio,
    );
    return remote;
  }
}

Future<_Session> _boot() async {
  final repo = MockAlbumRepository(), storage = _Storage();
  late _Session session;
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => session.actor),
      albumRepositoryProvider.overrideWithValue(repo),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(storage),
    ],
  );
  // The reader is evaluated during build, so initialise the holder first.
  session = _Session(container, repo, storage);
  session.vm = container.read(albumEditorViewModelProvider.notifier);
  when(() => repo.fetchAlbum(any())).thenAnswer((_) async => session.remote);
  when(
    () => repo.updateAlbum(
      any(),
      any(),
      expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
      requestId: any(named: 'requestId'),
      expectedUserId: any(named: 'expectedUserId'),
    ),
  ).thenAnswer((call) async {
    final body = call.positionalArguments[1] as CreateAlbumRequest;
    session.requests.add((
      body: body,
      revision: call.namedArguments[#expectedUpdatedAt] as String?,
      key: call.namedArguments[#requestId] as String?,
      actor: call.namedArguments[#expectedUserId] as String?,
    ));
    return session.save(body);
  });
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  await session.vm.prepareAlbumForEdit(session.remote);
  session.vm.loadPendingEditAlbumIfNeeded(const Size(500, 500));
  session.vm.setCoverCanvasSize(const Size(500, 500));
  session.vm.goToPage(1);
  return session;
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 30 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
    registerFallbackValue(_Asset());
  });
  test(
    'whole book save carries the original microsecond revision and actor',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('my edit')]);
      expect(await s.vm.saveFullAlbum(), isTrue);
      expect(s.requests.single.revision, _rawRevision);
      expect(s.requests.single.actor, 'owner');
      expect(s.requests.single.key, isNotEmpty);
      expect(
        (jsonDecode(s.requests.single.body.coverLayersJson)['pages'] as List)
            .length,
        s.vm.pages.length,
      );
      expect(s.vm.hasUnsavedChanges, isFalse);
    },
  );
  test(
    'conflict retains local pages, dirty state and original revision',
    () async {
      final s = await _boot();
      s.onSave = (_) async => throw const AlbumRevisionConflict();
      s.vm.updatePageLayers([_text('do not overwrite')]);
      final before = s.vm.exportFullAlbumLayersJson(null);
      expect(await s.vm.saveFullAlbum(), isFalse);
      expect(s.vm.lastSaveError, isA<AlbumRevisionConflict>());
      expect(s.vm.exportFullAlbumLayersJson(null), before);
      expect(s.vm.hasUnsavedChanges, isTrue);
      expect(s.vm.album!.updatedAt, _rawRevision);
      expect(s.vm.hasRemoteChanges, isTrue);
      expect(s.requests.length, 1);
    },
  );
  test(
    'lost response retries identical key and payload before creating a new save',
    () async {
      final s = await _boot();
      var calls = 0;
      Album? committed;
      s.onSave = (body) async {
        if (++calls == 1) {
          committed = s.remote.copyWith(
            updatedAt: 'committed-revision',
            coverLayersJson: body.coverLayersJson,
          );
          throw const SocketException('response lost');
        }
        return committed!;
      };
      s.vm.updatePageLayers([_text('committed once')]);
      expect(await s.vm.saveFullAlbum(), isFalse);
      expect(await s.vm.saveFullAlbum(), isTrue);
      expect(s.requests.length, 2);
      expect(s.requests[1].key, s.requests[0].key);
      expect(s.requests[1].body, s.requests[0].body);
      expect(s.vm.album!.updatedAt, 'committed-revision');
      expect(s.vm.hasUnsavedChanges, isFalse);
    },
  );
  test(
    'edits made during a pending save remain dirty and use a new key next time',
    () async {
      final s = await _boot();
      final gate = Completer<Album>();
      s.onSave = (_) => gate.future;
      s.vm.updatePageLayers([_text('first')]);
      final save = s.vm.saveFullAlbum();
      await _until(() => s.requests.isNotEmpty);
      s.vm.updatePageLayers([_text('second')]);
      gate.complete(
        s.remote.copyWith(
          updatedAt: 'next-revision',
          coverLayersJson: s.requests.first.body.coverLayersJson,
        ),
      );
      expect(await save, isTrue);
      expect(s.vm.layers.single.text, 'second');
      expect(s.vm.hasUnsavedChanges, isTrue);
      s.onSave = null;
      expect(await s.vm.saveFullAlbum(), isTrue);
      expect(s.requests[1].revision, 'next-revision');
      expect(s.requests[1].key, isNot(s.requests[0].key));
    },
  );
  test(
    'late photo upload retains newer geometry without changing the frozen save',
    () async {
      final s = await _boot();
      final asset = _Asset();
      final photo = LayerModel(
        id: 'photo',
        type: LayerType.image,
        position: const Offset(10, 20),
        asset: asset,
        width: 100,
        height: 100,
      );
      s.storage.pending = Completer<UploadedUrls>();
      s.vm.updatePageLayers([photo]);
      final save = s.vm.saveFullAlbum();
      await _until(() => s.storage.calls == 1);
      s.vm.updatePageLayers([photo.copyWith(position: const Offset(90, 80))]);
      s.storage.pending!.complete(
        const UploadedUrls(
          previewUrl: 'https://test/p.jpg',
          originalUrl: 'https://test/o.jpg',
        ),
      );
      expect(await save, isTrue);
      expect(s.vm.layers.single.position, const Offset(90, 80));
      expect(s.vm.layers.single.previewUrl, 'https://test/p.jpg');
      expect(s.vm.hasUnsavedChanges, isTrue);
    },
  );
  test('a deleted photo is not resurrected by its late upload', () async {
    final s = await _boot();
    s.storage.pending = Completer<UploadedUrls>();
    s.vm.updatePageLayers([
      LayerModel(
        id: 'photo',
        type: LayerType.image,
        position: Offset.zero,
        asset: _Asset(),
      ),
    ]);
    final save = s.vm.saveFullAlbum();
    await _until(() => s.storage.calls == 1);
    s.vm.updatePageLayers([]);
    s.storage.pending!.complete(
      const UploadedUrls(
        previewUrl: 'https://test/p.jpg',
        originalUrl: 'https://test/o.jpg',
      ),
    );
    expect(await save, isTrue);
    expect(s.vm.layers, isEmpty);
    expect(s.vm.hasUnsavedChanges, isTrue);
  });
  test(
    'changing albums while uploading stops the old RPC and leaves the new album alone',
    () async {
      final s = await _boot();
      s.storage.pending = Completer<UploadedUrls>();
      s.vm.updatePageLayers([
        LayerModel(
          id: 'photo',
          type: LayerType.image,
          position: Offset.zero,
          asset: _Asset(),
        ),
      ]);
      final save = s.vm.saveFullAlbum();
      await _until(() => s.storage.calls == 1);
      await s.vm.prepareAlbumForEdit(_book(id: 8));
      s.vm.loadPendingEditAlbumIfNeeded(const Size(500, 500));
      s.vm.goToPage(1);
      s.vm.updatePageLayers([_text('new album')]);
      s.storage.pending!.complete(
        const UploadedUrls(
          previewUrl: 'https://test/p.jpg',
          originalUrl: 'https://test/o.jpg',
        ),
      );
      expect(await save, isFalse);
      expect(s.requests, isEmpty);
      expect(s.vm.album!.id, 8);
      expect(s.vm.layers.single.text, 'new album');
      expect(s.vm.lastSaveError, isNull);
    },
  );
  test(
    'account change during RPC cannot accept an old-account result',
    () async {
      final s = await _boot();
      final gate = Completer<Album>();
      s.onSave = (_) => gate.future;
      s.vm.updatePageLayers([_text('private')]);
      final save = s.vm.saveFullAlbum();
      await _until(() => s.requests.isNotEmpty);
      s.actor = 'different-account';
      s.vm.resetForCreate();
      gate.complete(s.remote.copyWith(updatedAt: 'old-result'));
      expect(await save, isFalse);
      expect(s.vm.album, isNull);
      expect(s.vm.pages.every((p) => p.layers.isEmpty), isTrue);
      expect(s.vm.lastSaveError, isNull);
    },
  );
  test(
    'revocation during save retains edits in readonly state even after checkpoint restore',
    () async {
      final s = await _boot();
      final checkpoint = s.vm.captureEditCheckpoint();
      s.vm.updatePageLayers([_text('keep local')]);
      s.onSave = (_) async => throw const AlbumEditAccessRevoked();
      expect(await s.vm.saveFullAlbum(), isFalse);
      expect(s.vm.layers.single.text, 'keep local');
      expect(s.vm.hasUnsavedChanges, isTrue);
      expect(s.vm.editingAllowed, isFalse);
      s.vm.restoreEditCheckpoint(checkpoint);
      expect(s.vm.editingAllowed, isFalse);
      expect(await s.vm.saveFullAlbum(), isFalse);
      expect(s.requests.length, 1);
    },
  );
  test(
    'foreground remote check warns without rebasing local document or raw revision',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('local')]);
      s.remote = s.remote.copyWith(
        updatedAt: 'remote-revision',
        coverLayersJson: _book(id: 9).coverLayersJson,
      );
      await s.vm.checkRemoteAlbum();
      expect(s.vm.hasRemoteChanges, isTrue);
      expect(s.vm.layers.single.text, 'local');
      expect(s.vm.album!.updatedAt, _rawRevision);
    },
  );
  test(
    'offline check preserves local content and can recover without auto reload',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('offline local')]);
      when(
        () => s.repo.fetchAlbum('7'),
      ).thenThrow(const SocketException('offline'));
      await s.vm.checkRemoteAlbum();
      expect(s.vm.syncKind, AlbumEditSyncKind.offline);
      expect(s.vm.layers.single.text, 'offline local');
      when(() => s.repo.fetchAlbum('7')).thenAnswer((_) async => s.remote);
      await s.vm.checkRemoteAlbum();
      expect(s.vm.syncKind, AlbumEditSyncKind.current);
      expect(s.vm.layers.single.text, 'offline local');
      expect(s.vm.hasUnsavedChanges, isTrue);
    },
  );
  test(
    'explicit reload is the only action that discards local edits for the fresh revision',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('local')]);
      s.remote = s.remote.copyWith(updatedAt: 'fresh-revision');
      expect(await s.vm.reloadAlbumDiscardingLocalChanges(), isTrue);
      expect(s.vm.album!.updatedAt, 'fresh-revision');
      expect(s.vm.layers, isEmpty);
      expect(s.vm.hasUnsavedChanges, isFalse);
    },
  );
  test(
    'old checkpoint cannot restore private edits into a reopened shared album',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('old actor local')]);
      final checkpoint = s.vm.captureEditCheckpoint();
      s.actor = 'new-actor';
      await s.vm.prepareAlbumForEdit(_book());
      s.vm.loadPendingEditAlbumIfNeeded(const Size(500, 500));
      s.vm.goToPage(1);
      s.vm.updatePageLayers([_text('new actor local')]);
      s.vm.restoreEditCheckpoint(checkpoint);
      expect(s.vm.layers.single.text, 'new actor local');
      expect(s.vm.hasUnsavedChanges, isTrue);
    },
  );
  test(
    'definitive conflict resumes remote permission checks without discarding local edits',
    () async {
      final s = await _boot();
      s.vm.updatePageLayers([_text('conflicted local')]);
      s.onSave = (_) async => throw const AlbumRevisionConflict();
      expect(await s.vm.saveFullAlbum(), isFalse);
      s.remote = s.remote.copyWith(
        memberRole: 'VIEWER',
        updatedAt: 'remote-saved',
      );
      await s.vm.checkRemoteAlbum();
      expect(s.vm.editingAllowed, isFalse);
      expect(s.vm.syncKind, AlbumEditSyncKind.accessRevoked);
      expect(s.vm.layers.single.text, 'conflicted local');
      expect(s.vm.hasUnsavedChanges, isTrue);
      expect(s.vm.album!.updatedAt, _rawRevision);
    },
  );
}

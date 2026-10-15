import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album_save_progress.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import '../fixtures/ai_template_design_fixture.dart';
import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeStorageService, FakeAlbumPersistenceService;

class _Photo extends Mock implements AssetEntity {}

class _Storage extends FakeStorageService {
  int calls = 0, active = 0, maxActive = 0;
  String? failId;
  final gate = Completer<void>();
  bool hold = false;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (hold) await gate.future;
      if (asset.id == failId) throw const SocketException('upload failed');
      return UploadedUrls(previewUrl: 'https://photo.test/${asset.id}.jpg');
    } finally {
      active--;
    }
  }
}

LayerModel _text(String value) => LayerModel(
  id: 'text',
  type: LayerType.text,
  position: const Offset(40, 50),
  text: value,
  textStyle: const TextStyle(fontSize: 24),
);

void main() {
  setUpAll(
    () => registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    ),
  );

  Future<
    ({
      ProviderContainer container,
      AlbumEditorViewModel vm,
      MockAlbumRepository repo,
    })
  >
  boot({_Storage? storage}) async {
    final repo = MockAlbumRepository();
    final album = fakeAlbum(
      id: 7,
      coverLayersJson: '{"layers":[]}',
    ).copyWith(targetPages: 20);
    when(() => repo.fetchAlbum('7')).thenAnswer((_) async => album);
    when(() => repo.updateAlbum(7, any())).thenAnswer((_) async => album);
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(repo),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(storage ?? _Storage()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    await vm.prepareAlbumForEdit(album);
    vm.setCoverCanvasSize(const Size(500, 500));
    return (container: container, vm: vm, repo: repo);
  }

  test(
    'dirty state follows all pages, not just current undo availability',
    () async {
      final session = await boot();
      session.vm.goToPage(1);
      session.vm.updatePageLayers([_text('changed')]);
      session.vm.goToPage(2);
      expect(
        session.container.read(albumEditorViewModelProvider).value!.canUndo,
        isFalse,
      );
      expect(session.vm.hasUnsavedChanges, isTrue);
      expect(await session.vm.saveFullAlbum(), isTrue);
      expect(session.vm.hasUnsavedChanges, isFalse);
      session.vm.goToPage(1);
      expect(
        session.container.read(albumEditorViewModelProvider).value!.canUndo,
        isTrue,
      );
      session.vm.undo();
      expect(session.vm.hasUnsavedChanges, isTrue);
    },
  );

  test(
    'discard checkpoint restores content, page count, background and history',
    () async {
      final session = await boot();
      session.vm.goToPage(1);
      session.vm.updatePageLayers([_text('before')]);
      session.vm.updatePageLayers([_text('checkpoint')]);
      await session.vm.saveFullAlbum();
      final checkpoint = session.vm.captureEditCheckpoint();
      final count = session.vm.pages.length;
      session.vm.updatePageLayers([_text('after')]);
      session.vm.updatePageBackgroundColor(0xFF002255);
      session.vm.addPage();
      session.vm.restoreEditCheckpoint(checkpoint);
      expect(session.vm.currentPageIndex, 1);
      expect(session.vm.pages.length, count);
      expect(session.vm.layers.single.text, 'checkpoint');
      expect(
        session.vm.currentPage!.backgroundColor,
        checkpoint.pages[1].backgroundColor,
      );
      expect(session.vm.hasUnsavedChanges, isFalse);
      session.vm.undo();
      expect(session.vm.layers.single.text, 'before');
    },
  );

  test(
    'server failure does not clear dirty state or hide the editor',
    () async {
      final session = await boot();
      session.vm.updatePageLayers([_text('keep me')]);
      when(
        () => session.repo.updateAlbum(7, any()),
      ).thenThrow(StateError('server detail'));
      expect(await session.vm.saveFullAlbum(), isFalse);
      expect(session.vm.lastSaveError, isA<StateError>());
      expect(session.vm.hasUnsavedChanges, isTrue);
      expect(
        session.container
            .read(albumEditorViewModelProvider)
            .value!
            .layers
            .single
            .text,
        'keep me',
      );
      when(
        () => session.repo.updateAlbum(7, any()),
      ).thenAnswer((_) async => fakeAlbum(id: 7));
      expect(await session.vm.saveFullAlbum(), isTrue);
      expect(session.vm.lastSaveError, isNull);
      expect(session.vm.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'upload progress measures completed photos, bounds concurrency and prevents duplicate saves',
    () async {
      final storage = _Storage()..hold = true;
      final session = await boot(storage: storage);
      final photos = List.generate(9, (i) {
        final photo = _Photo();
        when(() => photo.id).thenReturn('$i');
        return LayerModel(
          id: '$i',
          type: LayerType.image,
          position: Offset.zero,
          asset: photo,
        );
      });
      session.vm.updatePageLayers(photos);
      final progress = <AlbumSaveProgress>[];
      final saving = session.vm.saveFullAlbum(onProgress: progress.add);
      await Future<void>.delayed(Duration.zero);
      expect(storage.maxActive, 4);
      expect(progress.single.completed, 0);
      expect(progress.single.total, 9);
      expect(
        session.container
            .read(albumEditorViewModelProvider)
            .value!
            .layers
            .length,
        9,
      );
      expect(await session.vm.saveFullAlbum(), isFalse);
      storage.gate.complete();
      expect(await saving, isTrue);
      expect(storage.calls, 9);
      expect(storage.maxActive, 4);
      expect(
        progress
            .where((p) => p.phase == AlbumSavePhase.uploading)
            .map((p) => p.completed),
        List.generate(10, (i) => i),
      );
      expect(progress[progress.length - 2].phase, AlbumSavePhase.saving);
      expect(progress.last.phase, AlbumSavePhase.complete);
    },
  );

  test('successful uploads are retained across failed save retry', () async {
    final storage = _Storage()..failId = 'bad';
    final session = await boot(storage: storage);
    session.vm.updatePageLayers(
      ['good', 'bad'].map((id) {
        final photo = _Photo();
        when(() => photo.id).thenReturn(id);
        return LayerModel(
          id: id,
          type: LayerType.image,
          position: Offset.zero,
          asset: photo,
        );
      }).toList(),
    );
    expect(await session.vm.saveFullAlbum(), isFalse);
    expect(session.vm.layers.first.previewUrl, contains('good'));
    expect(session.vm.hasUnsavedChanges, isTrue);
    storage.failId = null;
    expect(await session.vm.saveFullAlbum(), isTrue);
    expect(storage.calls, 3);
  });

  test(
    'an unregistered local album cannot report a successful server save',
    () async {
      final session = await boot();
      final design = templateDesignDraft().design!;
      session.vm.startLocalTemplateAlbum(
        albumTitle: 'Local',
        pages: design.buildLayers(targetSize: const Size(500, 500)),
      );
      expect(await session.vm.saveFullAlbum(), isFalse);
      expect(session.vm.lastSaveError, isA<StateError>());
    },
  );
}

import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';

class FakeStorageService implements StorageService {
  @override
  Future<String?> uploadProfileImage(File file, String userId) async => null;

  @override
  Future<String?> uploadFile(File file, String path) async => null;

  @override
  Future<UploadedUrls> uploadImageVariants(AssetEntity asset,
          {int previewMaxDimension = 1600}) async =>
      const UploadedUrls();

  @override
  Future<UploadedUrls> uploadCoverVariants(Uint8List pngBytes,
          {int originalMaxDimension = 4096, int previewMaxDimension = 1024}) async =>
      const UploadedUrls();
}

class FakeAlbumPersistenceService implements AlbumPersistenceService {
  @override
  Future<void> performBackgroundUpload({
    required int albumId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    void Function(int completed, int total)? onProgress,
  }) async {}

  @override
  Future<bool> pollAlbumCreation(int albumId) async => false;
}

void main() {
  test('resetForCreate initializes cover and pages', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
        albumPersistenceServiceProvider
            .overrideWithValue(FakeAlbumPersistenceService()),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(albumEditorViewModelProvider.future);

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    final cover = coverSizes.first;
    notifier.resetForCreate(initialCover: cover, targetPages: 3);

    final state = container.read(albumEditorViewModelProvider).value;
    expect(state, isNotNull);
    expect(state!.selectedCover, cover);
    expect(notifier.pages.length, 4);
    expect(notifier.currentPageIndex, 0);
  });

  test('addPage and removeLastPage update page count', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
        albumPersistenceServiceProvider
            .overrideWithValue(FakeAlbumPersistenceService()),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(albumEditorViewModelProvider.future);

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    final initialCount = notifier.pages.length;

    notifier.addPage();
    expect(notifier.pages.length, initialCount + 1);

    notifier.removeLastPage();
    expect(notifier.pages.length, initialCount);
  });

  test('updatePageBackgroundColor and clearPageBackgroundColor work', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
        albumPersistenceServiceProvider
            .overrideWithValue(FakeAlbumPersistenceService()),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(albumEditorViewModelProvider.future);

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    notifier.updatePageBackgroundColor(0xFF000000);
    expect(notifier.currentPage?.backgroundColor, 0xFF000000);

    notifier.clearPageBackgroundColor();
    expect(notifier.currentPage?.backgroundColor, isNull);
  });

  test('undo and redo restore layer changes', () async {
    final mockRepo = MockAlbumRepository();
    final container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(mockRepo),
        albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
        albumPersistenceServiceProvider
            .overrideWithValue(FakeAlbumPersistenceService()),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(albumEditorViewModelProvider.future);

    final notifier = container.read(albumEditorViewModelProvider.notifier);
    final initialLayers = notifier.layers;

    final newLayer = LayerModel(
      id: 'layer-1',
      type: LayerType.text,
      position: const Offset(10, 10),
      width: 100,
      height: 40,
      text: 'hello',
      textStyle: const TextStyle(fontSize: 12),
      textStyleType: TextStyleType.none,
    );

    notifier.updatePageLayers([newLayer]);
    expect(notifier.layers.length, 1);

    notifier.undo();
    expect(notifier.layers.length, initialLayers.length);

    notifier.redo();
    expect(notifier.layers.length, 1);
    expect(notifier.layers.first.id, 'layer-1');
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';

import '../helpers/fake_album.dart';
import '../helpers/mock_repositories.dart';

class MockAssetEntity extends Mock implements AssetEntity {}

class FakeStorageService implements StorageService {
  @override
  Future<String?> uploadProfileImage(File file, String userId) async => null;

  @override
  Future<String?> uploadFile(File file, String path) async => null;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async => const UploadedUrls(
    previewGsPath: 'supabase://album-assets/ai/preview.jpg',
    originalGsPath: 'supabase://album-assets/ai/original.jpg',
  );

  @override
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
  }) async {
    return const UploadedUrls(
      previewUrl: 'https://example.com/preview.jpg',
      originalUrl: 'https://example.com/original.jpg',
      previewGsPath: 'gs://bucket/preview.jpg',
      originalGsPath: 'gs://bucket/original.jpg',
    );
  }

  @override
  Future<List<AiAlbumPreviewUpload>> uploadAiAlbumPreviews({
    required String draftId,
    required List<AssetEntity> assets,
    int maxDimension = 512,
  }) async => const [];

  @override
  Future<void> deleteAiAlbumPreviews(Iterable<String> paths) async {}
}

class QuotaFailStorageService implements StorageService {
  @override
  Future<String?> uploadProfileImage(File file, String userId) async => null;

  @override
  Future<String?> uploadFile(File file, String path) async => null;

  @override
  Future<UploadedUrls> uploadImageVariants(
    AssetEntity asset, {
    int previewMaxDimension = 1600,
  }) async => throw const StorageQuotaExceededException(
    hardLimitBytes: 1024,
    usedBytes: 1024,
    incomingBytes: 10,
    projectedBytes: 1034,
    reason: 'HARD_LIMIT_EXCEEDED',
  );

  @override
  Future<UploadedUrls> uploadCoverVariants(
    Uint8List pngBytes, {
    int originalMaxDimension = 4096,
    int previewMaxDimension = 1024,
  }) async => throw const StorageQuotaExceededException(
    hardLimitBytes: 1024,
    usedBytes: 1024,
    incomingBytes: 10,
    projectedBytes: 1034,
    reason: 'HARD_LIMIT_EXCEEDED',
  );

  @override
  Future<List<AiAlbumPreviewUpload>> uploadAiAlbumPreviews({
    required String draftId,
    required List<AssetEntity> assets,
    int maxDimension = 512,
  }) async => const [];

  @override
  Future<void> deleteAiAlbumPreviews(Iterable<String> paths) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1:1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
  });

  test('performBackgroundUpload updates album with cover urls', () async {
    final mockRepo = MockAlbumRepository();
    when(
      () => mockRepo.updateAlbum(any(), any()),
    ).thenAnswer((_) async => fakeAlbum(id: 1));

    final service = AlbumPersistenceService(FakeStorageService(), mockRepo);

    await service.performBackgroundUpload(
      albumId: 1,
      canvasSize: const Size(300, 400),
      currentLayers: const <LayerModel>[],
      coverImageBytes: Uint8List.fromList([0, 1, 2]),
      themeLabel: 'classic',
      title: 'title',
      coverRatio: 1.0,
      targetPages: 24,
    );

    final captured = verify(
      () => mockRepo.updateAlbum(1, captureAny()),
    ).captured.single;
    expect(captured.coverPreviewUrl, 'gs://bucket/preview.jpg');
    expect(captured.coverOriginalUrl, 'gs://bucket/original.jpg');
  });

  test(
    'uploads AI draft local asset image layers before persisting cover JSON',
    () async {
      final mockRepo = MockAlbumRepository();
      when(
        () => mockRepo.updateAlbum(any(), any()),
      ).thenAnswer((_) async => fakeAlbum(id: 1));
      final service = AlbumPersistenceService(FakeStorageService(), mockRepo);

      await service.performBackgroundUpload(
        albumId: 1,
        canvasSize: const Size(300, 400),
        currentLayers: [
          LayerModel(
            id: 'ai-image-1',
            type: LayerType.image,
            position: Offset.zero,
            width: 120,
            height: 90,
            asset: MockAssetEntity(),
          ),
        ],
        coverImageBytes: null,
        themeLabel: 'ai',
        title: 'AI 앨범',
        coverRatio: 1.0,
        targetPages: 10,
      );

      final captured =
          verify(() => mockRepo.updateAlbum(1, captureAny())).captured.single
              as CreateAlbumRequest;
      expect(
        captured.coverLayersJson,
        contains('supabase://album-assets/ai/preview.jpg'),
      );
      expect(
        captured.coverLayersJson,
        contains('supabase://album-assets/ai/original.jpg'),
      );
      expect(captured.coverImageUrl, 'supabase://album-assets/ai/preview.jpg');
      expect(
        captured.coverThumbnailUrl,
        'supabase://album-assets/ai/preview.jpg',
      );
    },
  );

  test(
    'performBackgroundUpload rethrows quota exceeded even when swallowErrors=true',
    () async {
      final mockRepo = MockAlbumRepository();
      final service = AlbumPersistenceService(
        QuotaFailStorageService(),
        mockRepo,
      );

      expect(
        () => service.performBackgroundUpload(
          albumId: 1,
          canvasSize: const Size(300, 400),
          currentLayers: const <LayerModel>[],
          coverImageBytes: Uint8List.fromList([0, 1, 2]),
          themeLabel: 'classic',
          title: 'title',
          coverRatio: 1.0,
          targetPages: 24,
        ),
        throwsA(isA<StorageQuotaExceededException>()),
      );
    },
  );
}

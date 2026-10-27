import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/layer_export_mapper.dart';
import '../domain/entities/album.dart';
import '../domain/entities/album_source_template.dart';
import '../domain/entities/album_edit_failure.dart';
import '../domain/repositories/album_repository.dart';
import '../data/api/storage_service.dart';
import '../data/gallery/browser_photo_asset.dart';
import '../data/dto/request/create_album_request.dart';

class AlbumPersistenceService {
  final StorageService _storage;
  final AlbumRepository _albumRepository;

  AlbumPersistenceService(this._storage, this._albumRepository);

  static const int _maxConcurrentImageUploads = 4;
  static const int _maxUploadRetries = 2;

  Future<LayerModel> _uploadSingleLayerWithRetry(
    LayerModel layer, {
    required int albumId,
    bool Function()? canContinue,
    void Function(UploadedUrls uploaded)? onUploaded,
  }) async {
    final browserPhoto = layer.asset is BrowserPhotoAsset;
    if (layer.type != LayerType.image ||
        (!browserPhoto &&
            (layer.previewUrl != null ||
                layer.imageUrl != null ||
                layer.originalUrl != null)) ||
        (browserPhoto &&
            (layer.previewUrl?.isNotEmpty ?? false) &&
            (layer.originalUrl?.isNotEmpty ?? false)) ||
        layer.asset == null) {
      return layer;
    }

    int attempt = 0;
    while (attempt <= _maxUploadRetries) {
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
      try {
        final uploaded = await _storage.uploadImageVariants(
          layer.asset!,
          albumId: albumId,
        );
        onUploaded?.call(uploaded);
        if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
        final preview = uploaded.previewGsPath ?? uploaded.previewUrl;
        final original = uploaded.originalGsPath ?? uploaded.originalUrl;
        if (preview?.trim().isNotEmpty != true ||
            original?.trim().isNotEmpty != true) {
          throw StateError('album_photo_upload_incomplete');
        }
        if (preview != null || original != null) {
          return layer.copyWith(
            previewUrl: preview,
            originalUrl: original,
            imageUrl: preview,
          );
        }
        throw StateError('album_photo_upload_incomplete');
      } catch (e) {
        if (e is StorageQuotaExceededException ||
            e is AlbumEditSessionChanged) {
          rethrow;
        }
        attempt++;
        if (attempt > _maxUploadRetries) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return layer;
  }

  Future<List<LayerModel>> _uploadLayersWithConcurrency(
    List<LayerModel> layers, {
    required int albumId,
    bool Function()? canContinue,
    void Function(LayerModel before, LayerModel after)? onLayerUploaded,
    void Function(UploadedUrls uploaded)? onUploaded,
    void Function(int completed, int total)? onProgress,
  }) async {
    final updated = <LayerModel>[];
    final total = layers.length;
    int completed = 0;

    // 레이어를 일정 크기(chunk)로 잘라서 동시 N개씩만 업로드
    for (var i = 0; i < layers.length; i += _maxConcurrentImageUploads) {
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
      final chunk = layers.sublist(
        i,
        (i + _maxConcurrentImageUploads).clamp(0, layers.length),
      );
      final chunkResults = await Future.wait(
        chunk.map((layer) async {
          final uploaded = await _uploadSingleLayerWithRetry(
            layer,
            albumId: albumId,
            canContinue: canContinue,
            onUploaded: onUploaded,
          );
          if (canContinue?.call() == false)
            throw const AlbumEditSessionChanged();
          onLayerUploaded?.call(layer, uploaded);
          return uploaded;
        }),
      );
      updated.addAll(chunkResults);

      completed = updated.length;
      if (onProgress != null) {
        onProgress(completed, total);
      }
    }

    return updated;
  }

  /// 백그라운드에서 실행될 실제 업로드 로직
  Future<Album> performBackgroundUpload({
    required int albumId,
    required String expectedUpdatedAt,
    required String expectedUserId,
    required String requestId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    required int targetPages,
    Map<String, dynamic>? printProduct,
    String? sourceTemplateProductKey,
    bool swallowErrors = true,
    bool Function()? canContinue,
    void Function(CreateAlbumRequest request)? onPrepared,
    void Function(LayerModel before, LayerModel after)? onLayerUploaded,
    void Function(UploadedUrls uploaded)? onUploaded,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
      debugPrint('[Background] Upload Started for Album $albumId');

      // 1. 레이어 업로드 Future (이미지 레이어 중 업로드 안 된 것만, 동시 N개 제한)
      final layersFuture = _uploadLayersWithConcurrency(
        currentLayers,
        albumId: albumId,
        canContinue: canContinue,
        onLayerUploaded: onLayerUploaded,
        onUploaded: onUploaded,
        onProgress: onProgress,
      );

      // 2. 커버 이미지 업로드 Future (있다면)
      Future<UploadedUrls?> coverFuture = Future.value(null);
      if (coverImageBytes != null) {
        coverFuture = _storage
            .uploadCoverVariants(coverImageBytes, albumId: albumId)
            .then((uploaded) {
              onUploaded?.call(uploaded);
              return uploaded;
            });
      }

      // 3. 병렬 실행 및 대기 (레이어 업로드 + 커버 업로드)
      final results = await Future.wait([layersFuture, coverFuture]);
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();

      final updatedLayers = results[0] as List<LayerModel>;
      final coverUploaded = results[1] as UploadedUrls?;

      // 4. 최종 JSON 생성 (실제 서버 URL 포함)
      final json = jsonEncode({
        ...albumSourceTemplateMetadata(sourceTemplateProductKey),
        if (printProduct != null) 'printProduct': printProduct,
        'layers': updatedLayers
            .map(
              (l) => LayerExportMapper.toJson(
                l,
                canvasSize: canvasSize,
                isCover: true,
              ),
            )
            .toList(),
      });

      // 5. URL 결정
      String? coverPreviewUrl;
      String? coverOriginalUrl;
      if (coverUploaded != null) {
        coverPreviewUrl =
            coverUploaded.previewGsPath ?? coverUploaded.previewUrl;
        coverOriginalUrl =
            coverUploaded.originalGsPath ?? coverUploaded.originalUrl;
      }

      // 커버 업로드 URL이 없고, 레이어도 있을 때만 첫 이미지 레이어를 폴백으로 사용
      if (coverPreviewUrl == null && updatedLayers.isNotEmpty) {
        try {
          final imageLayer = updatedLayers.firstWhere(
            (l) =>
                l.type == LayerType.image &&
                (l.previewUrl ?? l.imageUrl) != null,
          );
          coverPreviewUrl = imageLayer.previewUrl ?? imageLayer.imageUrl;
          coverOriginalUrl ??= imageLayer.originalUrl;
        } catch (_) {
          // 이미지 레이어가 없으면 coverPreviewUrl은 null 유지
        }
      }

      // 6. 앨범 정보 업데이트 (Repository 직접 호출)
      final request = CreateAlbumRequest(
        ratio: coverRatio.toString(),
        title: title,
        targetPages: targetPages,
        coverLayersJson: json,
        coverImageUrl: coverPreviewUrl ?? '',
        coverThumbnailUrl: coverPreviewUrl ?? '',
        coverPreviewUrl: coverPreviewUrl,
        coverOriginalUrl: coverOriginalUrl,
        coverTheme: themeLabel,
      );
      onPrepared?.call(request);
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
      final saved = await _albumRepository.updateAlbum(
        albumId,
        request,
        expectedUpdatedAt: expectedUpdatedAt,
        requestId: requestId,
        expectedUserId: expectedUserId,
      );
      if (canContinue?.call() == false) throw const AlbumEditSessionChanged();
      debugPrint('[Background] Upload Completed for Album $albumId');
      return saved;
    } catch (e) {
      debugPrint('[Background] Upload Failed: $e');
      // A failed or unconfirmed document write must never look like success.
      rethrow;
    }
  }

  /// 백그라운드에서 앨범 생성 완료를 폴링
  Future<bool> pollAlbumCreation(int albumId) async {
    int retries = 0;
    const maxRetries = 30; // 최대 30초 대기

    while (retries < maxRetries) {
      try {
        final album = await _albumRepository.fetchAlbum(albumId.toString());

        if (album.id > 0) {
          bool isReady = false;

          if (album.coverLayersJson.isNotEmpty &&
              album.coverLayersJson != '{"layers":[]}') {
            try {
              final json =
                  jsonDecode(album.coverLayersJson) as Map<String, dynamic>;
              final layers = json['layers'] as List<dynamic>?;

              if (layers != null && layers.isNotEmpty) {
                bool allImagesHaveUrls = true;
                bool hasImageLayers = false;

                for (final layerJson in layers) {
                  final type = layerJson['type'] as String?;
                  if (type == 'IMAGE') {
                    hasImageLayers = true;
                    final payload =
                        layerJson['payload'] as Map<String, dynamic>?;
                    String? previewUrl;
                    if (payload != null) {
                      previewUrl = payload['previewUrl'] as String?;
                    }
                    if (previewUrl == null || previewUrl.isEmpty) {
                      allImagesHaveUrls = false;
                      break;
                    }
                  }
                }
                if (hasImageLayers && allImagesHaveUrls)
                  isReady = true;
                else if (!hasImageLayers)
                  isReady = true;
              } else {
                isReady = true;
              }
            } catch (e) {
              isReady = false;
            }
          } else if ((album.coverImageUrl?.isNotEmpty ?? false) ||
              (album.coverTheme?.isNotEmpty ?? false)) {
            isReady = true;
          }

          if (isReady) {
            debugPrint('🎉 Album ready! ID: ${album.id}');
            return true;
          }
        }
      } catch (e) {
        debugPrint('❌ Album not ready yet, retrying... ($retries/$maxRetries)');
      }

      await Future.delayed(const Duration(seconds: 1));
      retries++;
    }
    return false;
  }
}

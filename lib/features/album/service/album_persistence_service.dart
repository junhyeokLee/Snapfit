import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/layer_export_mapper.dart';
import '../domain/repositories/album_repository.dart';
import '../data/api/storage_service.dart';
import '../data/dto/request/create_album_request.dart';

class AlbumPersistenceService {
  final StorageService _storage;
  final AlbumRepository _albumRepository;

  AlbumPersistenceService(this._storage, this._albumRepository);

  static const int _maxConcurrentImageUploads = 4;
  static const int _maxUploadRetries = 2;

  Future<LayerModel> _uploadSingleLayerWithRetry(LayerModel layer) async {
    if (layer.type != LayerType.image ||
        (layer.previewUrl != null || layer.imageUrl != null || layer.originalUrl != null) ||
        layer.asset == null) {
      return layer;
    }

    int attempt = 0;
    while (attempt <= _maxUploadRetries) {
      try {
        final uploaded = await _storage.uploadImageVariants(layer.asset!);
        final preview = uploaded.previewGsPath ?? uploaded.previewUrl;
        final original = uploaded.originalGsPath ?? uploaded.originalUrl;
        if (preview != null || original != null) {
          return layer.copyWith(
            previewUrl: preview,
            originalUrl: original,
            imageUrl: preview,
          );
        }
        // 업로드는 성공했는데 URL이 없는 경우: 굳이 재시도하지 않고 원본 레이어 반환
        return layer;
      } catch (e) {
        attempt++;
        if (attempt > _maxUploadRetries) {
          debugPrint('[Background] Image upload failed for layer ${layer.id}: $e');
          return layer; // 실패한 레이어는 나중에 재시도할 수 있도록 그대로 둔다
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    return layer;
  }

  Future<List<LayerModel>> _uploadLayersWithConcurrency(
    List<LayerModel> layers, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final updated = <LayerModel>[];
    final total = layers.length;
    int completed = 0;

    // 레이어를 일정 크기(chunk)로 잘라서 동시 N개씩만 업로드
    for (var i = 0; i < layers.length; i += _maxConcurrentImageUploads) {
      final chunk = layers.sublist(
        i,
        (i + _maxConcurrentImageUploads).clamp(0, layers.length),
      );
      final chunkResults = await Future.wait(chunk.map(_uploadSingleLayerWithRetry));
      updated.addAll(chunkResults);

      completed = updated.length;
      if (onProgress != null) {
        onProgress(completed, total);
      }
    }

    return updated;
  }

  /// 백그라운드에서 실행될 실제 업로드 로직
  Future<void> performBackgroundUpload({
    required int albumId,
    required Size canvasSize,
    required List<LayerModel> currentLayers,
    required Uint8List? coverImageBytes,
    required String themeLabel,
    required String title,
    required double coverRatio,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      debugPrint('[Background] Upload Started for Album $albumId');

      // 1. 레이어 업로드 Future (이미지 레이어 중 업로드 안 된 것만, 동시 N개 제한)
      final layersFuture = _uploadLayersWithConcurrency(
        currentLayers,
        onProgress: onProgress,
      );

      // 2. 커버 이미지 업로드 Future (있다면)
      Future<UploadedUrls?> coverFuture = Future.value(null);
      if (coverImageBytes != null) {
        coverFuture = _storage.uploadCoverVariants(coverImageBytes);
      }

      // 3. 병렬 실행 및 대기 (레이어 업로드 + 커버 업로드)
      final results = await Future.wait([layersFuture, coverFuture]);

      final updatedLayers = results[0] as List<LayerModel>;
      final coverUploaded = results[1] as UploadedUrls?;

      // 4. 최종 JSON 생성 (실제 서버 URL 포함)
      final json = jsonEncode({
        'layers': updatedLayers.map((l) => LayerExportMapper.toJson(l, canvasSize: canvasSize, isCover: true)).toList()
      });

      // 5. URL 결정
      String? coverPreviewUrl;
      String? coverOriginalUrl;
      if (coverUploaded != null) {
        coverPreviewUrl = coverUploaded.previewGsPath ?? coverUploaded.previewUrl;
        coverOriginalUrl = coverUploaded.originalGsPath ?? coverUploaded.originalUrl;
      }

      // 커버 업로드 URL이 없고, 레이어도 있을 때만 첫 이미지 레이어를 폴백으로 사용
      if (coverPreviewUrl == null && updatedLayers.isNotEmpty) {
        try {
          final imageLayer = updatedLayers.firstWhere(
            (l) => l.type == LayerType.image && (l.previewUrl ?? l.imageUrl) != null,
          );
          coverPreviewUrl = imageLayer.previewUrl ?? imageLayer.imageUrl;
        } catch (_) {
          // 이미지 레이어가 없으면 coverPreviewUrl은 null 유지
        }
      }

      // 6. 앨범 정보 업데이트 (Repository 직접 호출)
      await _albumRepository.updateAlbum(
        albumId,
        CreateAlbumRequest(
          ratio: coverRatio.toString(),
          title: title,
          targetPages: 0, // 백그라운드 업데이트 시엔 0 혹은 기존 값 유지
          coverLayersJson: json,
          coverImageUrl: coverPreviewUrl ?? '',
          coverThumbnailUrl: coverPreviewUrl ?? '',
          coverPreviewUrl: coverPreviewUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverTheme: themeLabel,
        ),
      );
      
      debugPrint('[Background] Upload Completed for Album $albumId');

    } catch (e) {
      debugPrint('[Background] Upload Failed: $e');
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
          
          if (album.coverLayersJson.isNotEmpty && album.coverLayersJson != '{"layers":[]}') {
            try {
              final json = jsonDecode(album.coverLayersJson) as Map<String, dynamic>;
              final layers = json['layers'] as List<dynamic>?;
              
              if (layers != null && layers.isNotEmpty) {
                bool allImagesHaveUrls = true;
                bool hasImageLayers = false;
                
                for (final layerJson in layers) {
                  final type = layerJson['type'] as String?;
                  if (type == 'IMAGE') {
                    hasImageLayers = true;
                    final payload = layerJson['payload'] as Map<String, dynamic>?;
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
                if (hasImageLayers && allImagesHaveUrls) isReady = true;
                else if (!hasImageLayers) isReady = true;
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

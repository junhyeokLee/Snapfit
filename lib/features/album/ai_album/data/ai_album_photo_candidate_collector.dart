import 'package:photo_manager/photo_manager.dart';

import '../../domain/repositories/gallery_repository.dart';
import '../domain/ai_album_draft_generation_service.dart';
import '../domain/ai_album_models.dart';

class AiAlbumPhotoCandidateCollector {
  const AiAlbumPhotoCandidateCollector({
    required GalleryRepository repository,
    DateTime? now,
    int pageSize = 120,
    int maxPages = 8,
  }) : _repository = repository,
       _now = now,
       _pageSize = pageSize,
       _maxPages = maxPages;

  final GalleryRepository _repository;
  final DateTime? _now;
  final int _pageSize;
  final int _maxPages;

  Future<List<PhotoCandidate>> collect({
    required AiPhotoRange range,
    AssetPathEntity? album,
  }) async {
    final permitted = await _repository.requestPermission();
    if (!permitted) {
      throw const AiPhotoCandidateCollectionException(
        AiPhotoCandidateCollectionFailure.permissionDenied,
      );
    }

    final albums = album != null ? [album] : await _albumsForAiRange(range);
    final candidatesById = <String, PhotoCandidate>{};
    for (final currentAlbum in albums) {
      for (var page = 0; page < _maxPages; page += 1) {
        final assets = await _repository.loadImagesPaged(
          currentAlbum,
          page,
          _pageSize,
        );
        if (assets.isEmpty) break;
        for (final asset in assets) {
          if (!_isWithinRange(asset, range)) continue;
          candidatesById.putIfAbsent(
            asset.id,
            () => _candidateFromAsset(asset, currentAlbum.name),
          );
        }
        if (assets.length < _pageSize) break;
        if (_pageIsOlderThanRange(assets, range)) break;
      }
    }

    final candidates = candidatesById.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidates;
  }

  Future<List<AssetPathEntity>> _albumsForAiRange(AiPhotoRange range) async {
    final allPhotosAlbum = await _repository.loadAllPhotosAlbum();
    if (allPhotosAlbum != null) return [allPhotosAlbum];
    return _repository.loadAlbums();
  }

  bool _pageIsOlderThanRange(List<AssetEntity> assets, AiPhotoRange range) {
    if (range != AiPhotoRange.recent30Days) return false;
    final threshold = (_now ?? DateTime.now()).subtract(
      const Duration(days: 30),
    );
    return assets.every((asset) => asset.createDateTime.isBefore(threshold));
  }

  bool _isWithinRange(AssetEntity asset, AiPhotoRange range) {
    if (range != AiPhotoRange.recent30Days) return true;
    final now = _now ?? DateTime.now();
    final threshold = now.subtract(const Duration(days: 30));
    return !asset.createDateTime.isBefore(threshold) &&
        !asset.createDateTime.isAfter(now);
  }

  PhotoCandidate _candidateFromAsset(AssetEntity asset, String? albumName) {
    return PhotoCandidate(
      assetId: asset.id,
      createdAt: asset.createDateTime,
      width: asset.width,
      height: asset.height,
      orientation: _orientationFor(asset.width, asset.height),
      albumName: albumName,
      isScreenshot: _looksLikeScreenshot(asset),
      asset: asset,
    );
  }

  PhotoOrientation _orientationFor(int width, int height) {
    if (width == height) return PhotoOrientation.square;
    return width > height
        ? PhotoOrientation.landscape
        : PhotoOrientation.portrait;
  }

  bool _looksLikeScreenshot(AssetEntity asset) {
    final title = asset.title?.toLowerCase() ?? '';
    if (title.contains('screenshot') || title.contains('스크린샷')) return true;

    final ratio = asset.height == 0 ? 0 : asset.width / asset.height;
    final tallPhoneCapture =
        ratio > 0.42 && ratio < 0.52 && asset.height >= 2000;
    return tallPhoneCapture && asset.width <= 1440;
  }
}

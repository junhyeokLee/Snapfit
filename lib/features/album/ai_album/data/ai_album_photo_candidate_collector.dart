import 'package:photo_manager/photo_manager.dart';

import '../../domain/repositories/gallery_repository.dart';
import '../domain/ai_album_models.dart';

class AiAlbumPhotoCandidateCollector {
  const AiAlbumPhotoCandidateCollector({
    required GalleryRepository repository,
    DateTime? now,
    int pageSize = 120,
  }) : _repository = repository,
       _now = now,
       _pageSize = pageSize;

  final GalleryRepository _repository;
  final DateTime? _now;
  final int _pageSize;

  Future<List<PhotoCandidate>> collect({
    required AiPhotoRange range,
    AssetPathEntity? album,
  }) async {
    final permitted = await _repository.requestPermission();
    if (!permitted) return const [];

    final albums = album != null ? [album] : await _repository.loadAlbums();
    final candidates = <PhotoCandidate>[];
    for (final currentAlbum in albums) {
      final assets = await _repository.loadImagesPaged(
        currentAlbum,
        0,
        _pageSize,
      );
      candidates.addAll(
        assets
            .where((asset) => _isWithinRange(asset, range))
            .map((asset) => _candidateFromAsset(asset, currentAlbum.name)),
      );
    }

    candidates.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return candidates;
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

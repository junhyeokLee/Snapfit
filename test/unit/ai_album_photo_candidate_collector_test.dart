import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/data/ai_album_photo_candidate_collector.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';

void main() {
  test(
    'collects recent photo assets and converts them into PhotoCandidate values',
    () async {
      final firstRecentAsset = _asset(
        'recent-landscape',
        DateTime(2026, 8, 20),
        4000,
        3000,
      );
      final repository = _FakeGalleryRepository(
        albums: [AssetPathEntity(id: 'camera', name: 'Camera')],
        pages: {
          'camera': [
            _asset('old', DateTime(2026, 1, 1), 4000, 3000),
            firstRecentAsset,
            _asset('recent-portrait', DateTime(2026, 8, 21), 3000, 4000),
            _asset(
              'recent-screenshot',
              DateTime(2026, 8, 22),
              1170,
              2532,
              title: 'Screenshot_01.png',
            ),
          ],
        },
      );

      final candidates = await AiAlbumPhotoCandidateCollector(
        repository: repository,
        now: DateTime(2026, 8, 30),
      ).collect(range: AiPhotoRange.recent30Days);

      expect(candidates.map((candidate) => candidate.assetId), [
        'recent-landscape',
        'recent-portrait',
        'recent-screenshot',
      ]);
      expect(candidates.first.albumName, 'Camera');
      expect(candidates.first.asset, same(firstRecentAsset));
      expect(candidates.first.orientation, PhotoOrientation.landscape);
      expect(candidates[1].orientation, PhotoOrientation.portrait);
      expect(candidates[2].isScreenshot, isTrue);
    },
  );
}

AssetEntity _asset(
  String id,
  DateTime createdAt,
  int width,
  int height, {
  String? title,
}) {
  return AssetEntity(
    id: id,
    typeInt: AssetType.image.index,
    width: width,
    height: height,
    title: title,
    createDateSecond: createdAt.millisecondsSinceEpoch ~/ 1000,
  );
}

class _FakeGalleryRepository implements GalleryRepository {
  _FakeGalleryRepository({required this.albums, required this.pages});

  final List<AssetPathEntity> albums;
  final Map<String, List<AssetEntity>> pages;

  @override
  Future<List<AssetPathEntity>> loadAlbums() async => albums;

  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) async {
    if (page > 0) return const [];
    return pages[album.id] ?? const [];
  }

  @override
  Future<bool> requestPermission() async => true;
}

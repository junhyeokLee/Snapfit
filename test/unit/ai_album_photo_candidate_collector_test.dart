import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/data/ai_album_photo_candidate_collector.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
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
        'recent-screenshot',
        'recent-portrait',
        'recent-landscape',
      ]);
      expect(candidates.last.albumName, 'Camera');
      expect(candidates.last.asset, same(firstRecentAsset));
      expect(candidates.last.orientation, PhotoOrientation.landscape);
      expect(candidates[1].orientation, PhotoOrientation.portrait);
      expect(candidates.first.isScreenshot, isTrue);
    },
  );

  test(
    'uses the all-photos album and paginates so recent 30 days is not limited to stale folders',
    () async {
      final repository = _FakeGalleryRepository(
        albums: [AssetPathEntity(id: 'old-folder', name: 'Old Folder')],
        allPhotosAlbum: AssetPathEntity(id: 'all', name: 'Recents'),
        pages: {
          'old-folder': [
            _asset('stale-folder-photo', DateTime(2025, 1, 1), 4000, 3000),
          ],
          'all': [
            _asset('older-page-lead', DateTime(2026, 7, 1), 4000, 3000),
            _asset('recent-page-zero', DateTime(2026, 8, 15), 4000, 3000),
            _asset('recent-page-one', DateTime(2026, 8, 29), 3000, 4000),
          ],
        },
        pageSizeOverride: 2,
      );

      final candidates = await AiAlbumPhotoCandidateCollector(
        repository: repository,
        now: DateTime(2026, 8, 30),
        pageSize: 2,
      ).collect(range: AiPhotoRange.recent30Days);

      expect(candidates.map((candidate) => candidate.assetId), [
        'recent-page-one',
        'recent-page-zero',
      ]);
      expect(repository.loadedAlbumIds, ['all', 'all']);
    },
  );

  test(
    'deduplicates assets collected through multiple albums and keeps newest first',
    () async {
      final duplicate = _asset('same-photo', DateTime(2026, 8, 29), 4000, 3000);
      final repository = _FakeGalleryRepository(
        albums: [
          AssetPathEntity(id: 'camera', name: 'Camera'),
          AssetPathEntity(id: 'favorites', name: 'Favorites'),
        ],
        pages: {
          'camera': [
            duplicate,
            _asset('older-photo', DateTime(2026, 8, 1), 4000, 3000),
          ],
          'favorites': [
            duplicate,
            _asset('newest-photo', DateTime(2026, 8, 30), 3000, 4000),
          ],
        },
      );

      final candidates = await AiAlbumPhotoCandidateCollector(
        repository: repository,
        now: DateTime(2026, 8, 30),
      ).collect(range: AiPhotoRange.limitedLibrary);

      expect(candidates.map((candidate) => candidate.assetId), [
        'newest-photo',
        'same-photo',
        'older-photo',
      ]);
    },
  );

  test('throws a typed permission error when photo access is denied', () async {
    final repository = _FakeGalleryRepository(
      albums: [AssetPathEntity(id: 'camera', name: 'Camera')],
      pages: const {},
      permitted: false,
    );

    final collector = AiAlbumPhotoCandidateCollector(repository: repository);

    expect(
      () => collector.collect(range: AiPhotoRange.recent30Days),
      throwsA(
        isA<AiPhotoCandidateCollectionException>().having(
          (error) => error.failure,
          'failure',
          AiPhotoCandidateCollectionFailure.permissionDenied,
        ),
      ),
    );
  });
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
  _FakeGalleryRepository({
    required this.albums,
    required this.pages,
    this.permitted = true,
    this.allPhotosAlbum,
    this.pageSizeOverride,
  });

  final List<AssetPathEntity> albums;
  final Map<String, List<AssetEntity>> pages;
  final bool permitted;
  final AssetPathEntity? allPhotosAlbum;
  final int? pageSizeOverride;
  final List<String> loadedAlbumIds = [];

  @override
  Future<List<AssetPathEntity>> loadAlbums() async => albums;

  @override
  Future<AssetPathEntity?> loadAllPhotosAlbum() async => allPhotosAlbum;

  @override
  Future<List<AssetEntity>> loadImagesPaged(
    AssetPathEntity album,
    int page,
    int size,
  ) async {
    loadedAlbumIds.add(album.id);
    final source = pages[album.id] ?? const [];
    final effectiveSize = pageSizeOverride ?? size;
    final start = page * effectiveSize;
    if (start >= source.length) return const [];
    return source.skip(start).take(effectiveSize).toList(growable: false);
  }

  @override
  Future<bool> requestPermission() async => permitted;
}

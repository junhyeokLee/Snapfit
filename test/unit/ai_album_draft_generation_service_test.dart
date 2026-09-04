import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_curation_engine.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

void main() {
  test(
    'generates a reviewable draft and marks points chargeable only after success',
    () async {
      final service = AiAlbumDraftGenerationService(
        collectCandidates: (_) async => [
          _candidate(
            'travel-1',
            DateTime(2026, 8, 20, 9),
            PhotoOrientation.landscape,
          ),
          _candidate(
            'travel-2',
            DateTime(2026, 8, 20, 13),
            PhotoOrientation.landscape,
          ),
          _candidate(
            'travel-3',
            DateTime(2026, 8, 21, 10),
            PhotoOrientation.portrait,
          ),
        ],
        engine: const AiAlbumCurationEngine(),
        minimumPhotoCount: 3,
      );

      final result = await service.generate(
        theme: AlbumTheme.travel,
        range: AiPhotoRange.recent30Days,
      );

      expect(result.status, AiAlbumDraftGenerationStatus.success);
      expect(result.shouldChargePoints, isTrue);
      expect(result.draft, isNotNull);
      expect(result.draft!.recommendedPhotos, hasLength(3));
      expect(result.failureMessage, isNull);
    },
  );

  test(
    'does not charge points when photo candidates are insufficient',
    () async {
      final service = AiAlbumDraftGenerationService(
        collectCandidates: (_) async => [
          _candidate('one', DateTime(2026, 8, 20), PhotoOrientation.square),
        ],
        engine: const AiAlbumCurationEngine(),
        minimumPhotoCount: 3,
      );

      final result = await service.generate(
        theme: AlbumTheme.daily,
        range: AiPhotoRange.recent30Days,
      );

      expect(result.status, AiAlbumDraftGenerationStatus.insufficientPhotos);
      expect(result.shouldChargePoints, isFalse);
      expect(result.draft, isNull);
      expect(result.failureMessage, contains('사진'));
    },
  );

  test('does not charge points when candidate collection fails', () async {
    final service = AiAlbumDraftGenerationService(
      collectCandidates: (_) async => throw Exception('permission denied'),
      engine: const AiAlbumCurationEngine(),
      minimumPhotoCount: 3,
    );

    final result = await service.generate(
      theme: AlbumTheme.family,
      range: AiPhotoRange.album,
    );

    expect(result.status, AiAlbumDraftGenerationStatus.failed);
    expect(result.shouldChargePoints, isFalse);
    expect(result.draft, isNull);
  });

  test('explains denied photo permission without charging points', () async {
    final service = AiAlbumDraftGenerationService(
      collectCandidates: (_) async =>
          throw const AiPhotoCandidateCollectionException(
            AiPhotoCandidateCollectionFailure.permissionDenied,
          ),
      engine: const AiAlbumCurationEngine(),
      minimumPhotoCount: 3,
    );

    final result = await service.generate(
      theme: AlbumTheme.family,
      range: AiPhotoRange.recent30Days,
    );

    expect(result.status, AiAlbumDraftGenerationStatus.permissionDenied);
    expect(result.shouldChargePoints, isFalse);
    expect(result.draft, isNull);
    expect(result.failureMessage, contains('사진 접근 권한'));
    expect(result.failureMessage, contains('포인트는 차감되지 않았어요'));
  });

  test('explains limited library needs a few more photos', () async {
    final service = AiAlbumDraftGenerationService(
      collectCandidates: (_) async => [
        _candidate('one', DateTime(2026, 8, 20), PhotoOrientation.square),
      ],
      engine: const AiAlbumCurationEngine(),
      minimumPhotoCount: 3,
    );

    final result = await service.generate(
      theme: AlbumTheme.daily,
      range: AiPhotoRange.limitedLibrary,
    );

    expect(result.status, AiAlbumDraftGenerationStatus.insufficientPhotos);
    expect(result.shouldChargePoints, isFalse);
    expect(result.failureMessage, contains('선택한 사진이 조금 더 필요해요'));
    expect(result.failureMessage, contains('기기 안에서만'));
  });
}

PhotoCandidate _candidate(
  String id,
  DateTime createdAt,
  PhotoOrientation orientation,
) {
  final isLandscape = orientation == PhotoOrientation.landscape;
  final isPortrait = orientation == PhotoOrientation.portrait;
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: isPortrait ? 3000 : 4000,
    height: isLandscape ? 3000 : 4000,
    orientation: orientation,
  );
}

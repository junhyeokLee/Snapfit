import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_curation_engine.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

void main() {
  group('AiAlbumCurationEngine', () {
    test(
      'curates travel photos into date-based story sections with cover and exclusions',
      () {
        final engine = AiAlbumCurationEngine();
        final photos = <PhotoCandidate>[
          PhotoCandidate(
            assetId: 'arrival-landscape',
            createdAt: DateTime(2026, 7, 12, 10),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'arrival-duplicate',
            createdAt: DateTime(2026, 7, 12, 10, 1),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'dinner-detail',
            createdAt: DateTime(2026, 7, 12, 19),
            width: 3024,
            height: 4032,
            orientation: PhotoOrientation.portrait,
          ),
          PhotoCandidate(
            assetId: 'second-day',
            createdAt: DateTime(2026, 7, 13, 14),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'tiny-screenshot',
            createdAt: DateTime(2026, 7, 13, 15),
            width: 700,
            height: 500,
            isScreenshot: true,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'final-scene',
            createdAt: DateTime(2026, 7, 15, 18),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
        ];

        final draft = engine.curate(
          theme: AlbumTheme.travel,
          candidates: photos,
        );

        expect(draft.theme, AlbumTheme.travel);
        expect(draft.title, isNotEmpty);
        expect(draft.pageCount, greaterThanOrEqualTo(10));
        expect(
          draft.recommendedPhotos.map((p) => p.assetId),
          contains('arrival-landscape'),
        );
        expect(
          draft.recommendedPhotos.map((p) => p.assetId),
          contains('final-scene'),
        );
        expect(
          draft.recommendedPhotos.map((p) => p.assetId),
          isNot(contains('tiny-screenshot')),
        );
        expect(
          draft.excludedPhotos.map((p) => p.assetId),
          contains('tiny-screenshot'),
        );
        expect(draft.storySections.length, greaterThanOrEqualTo(2));
        expect(draft.storySections.first.title, contains('첫 장면'));
        expect(draft.summary, contains('날짜 흐름'));
        expect(draft.summary, contains('대표'));
      },
    );

    test(
      'keeps the user in control by returning an editable draft instead of creating an album',
      () {
        final draft = AiAlbumCurationEngine().curate(
          theme: AlbumTheme.couple,
          candidates: [
            PhotoCandidate(
              assetId: 'date-1',
              createdAt: DateTime(2026, 2, 14, 13),
              width: 3000,
              height: 4000,
              orientation: PhotoOrientation.portrait,
            ),
            PhotoCandidate(
              assetId: 'date-2',
              createdAt: DateTime(2026, 2, 14, 20),
              width: 4000,
              height: 3000,
              orientation: PhotoOrientation.landscape,
            ),
          ],
        );

        expect(draft.requiresUserReview, isTrue);
        expect(draft.reviewCtaLabel, '이 구성으로 시작하기');
        expect(draft.alreadyCreatedAlbum, isFalse);
        expect(draft.templateTone, contains('여백'));
      },
    );

    test('explains metadata-first curation choices for user review', () {
      final draft = AiAlbumCurationEngine().curate(
        theme: AlbumTheme.travel,
        candidates: [
          PhotoCandidate(
            assetId: 'jeju-folder-landscape',
            createdAt: DateTime(2026, 8, 1, 10),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
            albumName: '제주 여행',
          ),
          PhotoCandidate(
            assetId: 'burst-1',
            createdAt: DateTime(2026, 8, 1, 10, 1),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'screenshot',
            createdAt: DateTime(2026, 8, 2, 12),
            width: 1170,
            height: 2532,
            orientation: PhotoOrientation.portrait,
            isScreenshot: true,
          ),
          PhotoCandidate(
            assetId: 'last-day',
            createdAt: DateTime(2026, 8, 3, 12),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
        ],
      );

      expect(draft.curationNotes, isNotEmpty);
      expect(draft.curationNotes.join(' '), contains('날짜'));
      expect(draft.curationNotes.join(' '), contains('스크린샷'));
      expect(draft.curationNotes.join(' '), contains('연속 촬영'));
      expect(draft.curationNotes.join(' '), contains('앨범/폴더'));
    });

    test('keeps only representative photos from close time clusters', () {
      final draft = AiAlbumCurationEngine().curate(
        theme: AlbumTheme.travel,
        candidates: [
          PhotoCandidate(
            assetId: 'burst-wide',
            createdAt: DateTime(2026, 8, 1, 10),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'burst-small',
            createdAt: DateTime(2026, 8, 1, 10, 1),
            width: 1000,
            height: 800,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'burst-portrait',
            createdAt: DateTime(2026, 8, 1, 10, 2),
            width: 3024,
            height: 4032,
            orientation: PhotoOrientation.portrait,
          ),
          PhotoCandidate(
            assetId: 'later-wide',
            createdAt: DateTime(2026, 8, 1, 12),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
        ],
      );

      expect(
        draft.recommendedPhotos.map((photo) => photo.assetId),
        contains('burst-wide'),
      );
      expect(
        draft.recommendedPhotos
            .firstWhere((photo) => photo.assetId == 'burst-wide')
            .reasons
            .map((reason) => reason.type),
        contains(AiCurationReasonType.timeClusterRepresentative),
      );
      expect(
        draft.excludedPhotos.map((photo) => photo.assetId),
        contains('burst-small'),
      );
      expect(
        draft.excludedPhotos
            .firstWhere((photo) => photo.assetId == 'burst-small')
            .reasons
            .map((reason) => reason.type),
        contains(AiCurationReasonType.duplicateTimeExcluded),
      );
    });

    test('explains screenshot low resolution and daily limit exclusions', () {
      final candidates = <PhotoCandidate>[
        for (var i = 0; i < 8; i++)
          PhotoCandidate(
            assetId: 'day-photo-$i',
            createdAt: DateTime(2026, 8, 1, 9 + i),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
        PhotoCandidate(
          assetId: 'tiny-memory',
          createdAt: DateTime(2026, 8, 1, 18),
          width: 780,
          height: 640,
          orientation: PhotoOrientation.landscape,
        ),
        PhotoCandidate(
          assetId: 'screen-capture',
          createdAt: DateTime(2026, 8, 2, 10),
          width: 1170,
          height: 2532,
          orientation: PhotoOrientation.portrait,
          isScreenshot: true,
        ),
      ];

      final draft = AiAlbumCurationEngine().curate(
        theme: AlbumTheme.travel,
        candidates: candidates,
      );

      final reasonsByAsset = {
        for (final photo in draft.excludedPhotos)
          photo.assetId: photo.reasons.map((reason) => reason.type).toSet(),
      };

      expect(
        reasonsByAsset['tiny-memory'],
        contains(AiCurationReasonType.lowResolutionExcluded),
      );
      expect(
        reasonsByAsset['screen-capture'],
        contains(AiCurationReasonType.screenshotExcluded),
      );
      expect(
        reasonsByAsset.values.any(
          (types) => types.contains(AiCurationReasonType.dailyLimitExcluded),
        ),
        isTrue,
      );
      expect(draft.summary, contains('기기 안에서만'));
      expect(draft.summary, contains('다시 추가'));
    });

    test('uses time-of-day story sections for one-day albums', () {
      final draft = AiAlbumCurationEngine().curate(
        theme: AlbumTheme.birthday,
        candidates: [
          PhotoCandidate(
            assetId: 'morning-prep',
            createdAt: DateTime(2026, 8, 1, 9),
            width: 3024,
            height: 4032,
            orientation: PhotoOrientation.portrait,
          ),
          PhotoCandidate(
            assetId: 'afternoon-party',
            createdAt: DateTime(2026, 8, 1, 15),
            width: 4032,
            height: 3024,
            orientation: PhotoOrientation.landscape,
          ),
          PhotoCandidate(
            assetId: 'evening-cake',
            createdAt: DateTime(2026, 8, 1, 20),
            width: 3024,
            height: 4032,
            orientation: PhotoOrientation.portrait,
          ),
        ],
      );

      expect(
        draft.storySections.map((section) => section.title),
        contains('오전의 준비'),
      );
      expect(
        draft.storySections.map((section) => section.title),
        contains('오후의 하이라이트'),
      );
      expect(
        draft.storySections.map((section) => section.title),
        contains('저녁의 마무리'),
      );
    });
  });
}

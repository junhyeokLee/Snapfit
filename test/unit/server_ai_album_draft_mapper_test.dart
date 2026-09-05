import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/server_ai_album_draft_mapper.dart';

void main() {
  test('maps validated server JSON into a user-reviewable album draft', () {
    final candidates = [
      _candidate(
        'photo-1',
        DateTime(2026, 8, 20, 9),
        PhotoOrientation.landscape,
      ),
      _candidate(
        'photo-2',
        DateTime(2026, 8, 20, 11),
        PhotoOrientation.portrait,
      ),
      _candidate('photo-3', DateTime(2026, 8, 21, 15), PhotoOrientation.square),
    ];

    final draft = const ServerAiAlbumDraftMapper().map(
      theme: AlbumTheme.travel,
      candidates: candidates,
      json: {
        'draftId': 'server-draft-1',
        'title': '제주 여름 기록',
        'pageCount': 12,
        'templateTone': 'warm-travel',
        'summary': '여행 흐름을 날짜별로 정리했어요.',
        'recommendedPhotos': [
          {
            'assetId': 'photo-1',
            'score': 0.94,
            'reasons': [
              {'type': 'coverCandidate', 'message': '표지로 쓰기 좋은 장면이에요'},
            ],
          },
          {
            'assetId': 'photo-2',
            'score': 0.82,
            'reasons': [
              {'type': 'dateFlow', 'message': '여행 흐름을 이어줘요'},
            ],
          },
        ],
        'excludedPhotos': [
          {
            'assetId': 'photo-3',
            'reasons': [
              {'type': 'duplicateTimeExcluded', 'message': '비슷한 시간대라 잠시 빼뒀어요'},
            ],
          },
        ],
        'storySections': [
          {
            'title': '첫날의 빛',
            'description': '도착과 산책 장면',
            'photoAssetIds': ['photo-1', 'photo-2'],
          },
        ],
        'curationNotes': ['서버 추천도 편집 전 검토가 필요해요'],
        'requiresUserReview': false,
        'alreadyCreatedAlbum': true,
      },
    );

    expect(draft.draftId, 'server-draft-1');
    expect(draft.theme, AlbumTheme.travel);
    expect(draft.title, '제주 여름 기록');
    expect(draft.pageCount, 12);
    expect(draft.templateTone, 'warm-travel');
    expect(draft.recommendedPhotos.map((photo) => photo.assetId), [
      'photo-1',
      'photo-2',
    ]);
    expect(draft.recommendedPhotos.first.candidate, same(candidates.first));
    expect(
      draft.recommendedPhotos.first.reasons.single.type,
      AiCurationReasonType.coverCandidate,
    );
    expect(draft.excludedPhotos.single.assetId, 'photo-3');
    expect(draft.storySections.single.photoAssetIds, ['photo-1', 'photo-2']);
    expect(draft.curationNotes.single, contains('검토'));
    expect(draft.requiresUserReview, isTrue);
    expect(draft.alreadyCreatedAlbum, isFalse);
  });

  test(
    'rejects server recommended asset ids that are not local candidates',
    () {
      expect(
        () => const ServerAiAlbumDraftMapper().map(
          theme: AlbumTheme.daily,
          candidates: [
            _candidate(
              'photo-1',
              DateTime(2026, 8, 20),
              PhotoOrientation.square,
            ),
          ],
          json: {
            'title': '깨진 초안',
            'pageCount': 10,
            'recommendedPhotos': [
              {'assetId': 'unknown-photo'},
            ],
          },
        ),
        throwsA(
          isA<ServerAiAlbumDraftMappingException>().having(
            (error) => error.failure,
            'failure',
            ServerAiAlbumDraftMappingFailure.unknownAsset,
          ),
        ),
      );
    },
  );

  test('rejects unsafe server page counts before editor handoff', () {
    expect(
      () => const ServerAiAlbumDraftMapper(maxPageCount: 50).map(
        theme: AlbumTheme.daily,
        candidates: [
          _candidate('photo-1', DateTime(2026, 8, 20), PhotoOrientation.square),
        ],
        json: {
          'title': '너무 큰 초안',
          'pageCount': 120,
          'recommendedPhotos': [
            {'assetId': 'photo-1'},
          ],
        },
      ),
      throwsA(
        isA<ServerAiAlbumDraftMappingException>().having(
          (error) => error.failure,
          'failure',
          ServerAiAlbumDraftMappingFailure.invalidPageCount,
        ),
      ),
    );
  });
}

PhotoCandidate _candidate(
  String id,
  DateTime createdAt,
  PhotoOrientation orientation,
) {
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: orientation == PhotoOrientation.portrait ? 3000 : 4000,
    height: orientation == PhotoOrientation.landscape ? 3000 : 4000,
    orientation: orientation,
  );
}

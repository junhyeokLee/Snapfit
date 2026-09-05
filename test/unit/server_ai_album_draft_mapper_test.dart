import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
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
    'server provider sends theme range and candidate metadata to requester',
    () async {
      final candidates = [
        _candidate(
          'photo-1',
          DateTime(2026, 8, 20, 9),
          PhotoOrientation.landscape,
        ),
        _candidate(
          'photo-2',
          DateTime(2026, 8, 21, 10),
          PhotoOrientation.portrait,
        ),
        _candidate(
          'photo-3',
          DateTime(2026, 8, 22, 11),
          PhotoOrientation.square,
        ),
      ];
      late ServerAiAlbumDraftRequest received;
      final provider = ServerAiAlbumDraftProvider(
        requestDraft: (request) async {
          received = request;
          return {
            'title': '서버 요청 계약 초안',
            'pageCount': 8,
            'recommendedPhotos': [
              {'assetId': 'photo-1'},
              {'assetId': 'photo-2'},
            ],
            'storySections': [
              {
                'title': '첫 흐름',
                'description': '사진 순서 확인',
                'photoAssetIds': ['photo-1', 'photo-2'],
              },
            ],
          };
        },
      );

      final draft = await provider.createDraft(
        theme: AlbumTheme.travel,
        range: AiPhotoRange.limitedLibrary,
        candidates: candidates,
      );

      expect(received.theme, AlbumTheme.travel);
      expect(received.range, AiPhotoRange.limitedLibrary);
      expect(received.candidates, same(candidates));
      expect(received.toJson(), {
        'theme': 'travel',
        'range': 'limitedLibrary',
        'candidates': [
          {
            'assetId': 'photo-1',
            'createdAt': '2026-08-20T09:00:00.000',
            'width': 4000,
            'height': 3000,
            'orientation': 'landscape',
            'albumName': null,
            'isScreenshot': false,
          },
          {
            'assetId': 'photo-2',
            'createdAt': '2026-08-21T10:00:00.000',
            'width': 3000,
            'height': 4000,
            'orientation': 'portrait',
            'albumName': null,
            'isScreenshot': false,
          },
          {
            'assetId': 'photo-3',
            'createdAt': '2026-08-22T11:00:00.000',
            'width': 4000,
            'height': 4000,
            'orientation': 'square',
            'albumName': null,
            'isScreenshot': false,
          },
        ],
      });
      expect(draft.title, '서버 요청 계약 초안');
      expect(draft.requiresUserReview, isTrue);
    },
  );

  test(
    'draft service treats invalid server provider response as no-charge failure',
    () async {
      final service = AiAlbumDraftGenerationService(
        collectCandidates: (_) async => [
          _candidate('photo-1', DateTime(2026, 8, 20), PhotoOrientation.square),
          _candidate('photo-2', DateTime(2026, 8, 21), PhotoOrientation.square),
          _candidate('photo-3', DateTime(2026, 8, 22), PhotoOrientation.square),
        ],
        draftProvider: ServerAiAlbumDraftProvider(
          requestDraft: (_) async => {
            'title': '깨진 서버 초안',
            'pageCount': 8,
            'recommendedPhotos': [
              {'assetId': 'not-in-local-candidates'},
            ],
          },
        ),
        minimumPhotoCount: 3,
      );

      final result = await service.generate(
        theme: AlbumTheme.daily,
        range: AiPhotoRange.recent30Days,
      );

      expect(result.status, AiAlbumDraftGenerationStatus.failed);
      expect(result.shouldChargePoints, isFalse);
      expect(result.draft, isNull);
      expect(result.failureMessage, contains('포인트는 차감되지 않았어요'));
    },
  );

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

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

  test(
    'rejects duplicate server recommended asset ids before editor handoff',
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
            _candidate(
              'photo-2',
              DateTime(2026, 8, 21),
              PhotoOrientation.square,
            ),
            _candidate(
              'photo-3',
              DateTime(2026, 8, 22),
              PhotoOrientation.square,
            ),
          ],
          json: {
            'title': '중복 추천 초안',
            'pageCount': 8,
            'recommendedPhotos': [
              {'assetId': 'photo-1'},
              {'assetId': 'photo-1'},
            ],
          },
        ),
        throwsA(
          isA<ServerAiAlbumDraftMappingException>().having(
            (error) => error.failure,
            'failure',
            ServerAiAlbumDraftMappingFailure.duplicateAsset,
          ),
        ),
      );
    },
  );

  test(
    'rejects story sections that reference photos outside server recommendations',
    () {
      expect(
        () => const ServerAiAlbumDraftMapper().map(
          theme: AlbumTheme.travel,
          candidates: [
            _candidate(
              'photo-1',
              DateTime(2026, 8, 20),
              PhotoOrientation.square,
            ),
            _candidate(
              'photo-2',
              DateTime(2026, 8, 21),
              PhotoOrientation.square,
            ),
            _candidate(
              'photo-3',
              DateTime(2026, 8, 22),
              PhotoOrientation.square,
            ),
          ],
          json: {
            'title': '깨진 흐름 초안',
            'pageCount': 8,
            'recommendedPhotos': [
              {'assetId': 'photo-1'},
            ],
            'storySections': [
              {
                'title': '깨진 흐름',
                'description': '추천되지 않은 사진이 섞이면 안 돼요',
                'photoAssetIds': ['photo-2'],
              },
            ],
          },
        ),
        throwsA(
          isA<ServerAiAlbumDraftMappingException>().having(
            (error) => error.failure,
            'failure',
            ServerAiAlbumDraftMappingFailure.storySectionAssetNotRecommended,
          ),
        ),
      );
    },
  );

  test(
    'maps server AI template slots without requiring AI-selected photos',
    () {
      final draft = const ServerAiAlbumDraftMapper().map(
        theme: AlbumTheme.travel,
        candidates: [
          _candidate('photo-1', DateTime(2026, 8, 20), PhotoOrientation.square),
          _candidate('photo-2', DateTime(2026, 8, 21), PhotoOrientation.square),
          _candidate('photo-3', DateTime(2026, 8, 22), PhotoOrientation.square),
        ],
        json: {
          'draftId': 'template-draft-1',
          'title': '제주의 느린 오후',
          'pageCount': 4,
          'templateTone': 'warm-film',
          'summary': '사진은 직접 고르고, AI는 앨범 틀만 제안했어요.',
          'recommendedPhotos': [],
          'excludedPhotos': [],
          'storySections': [
            {
              'title': '표지',
              'description': '대표 사진을 넣는 첫 장',
              'photoAssetIds': [],
            },
          ],
          'templateSlots': [
            {
              'slotId': 'cover-main',
              'pageIndex': 0,
              'role': 'cover',
              'hint': '여행을 대표하는 사진을 직접 넣어주세요',
              'left': 0.08,
              'top': 0.1,
              'width': 0.84,
              'height': 0.52,
              'rotation': -1.5,
              'imageTemplate': '4:3',
              'imageBackground': 'mat',
              'caption': 'cover',
              'emphasis': 1.7,
            },
            {
              'slotId': 'p1-landscape',
              'pageIndex': 1,
              'role': 'landscape',
              'hint': '장소감이 보이는 풍경 사진',
            },
          ],
          'curationNotes': ['사진첩에서 사진을 자동으로 고르지 않았어요.'],
          'reviewCtaLabel': '이 템플릿으로 시작하기',
        },
      );

      expect(draft.recommendedPhotos, isEmpty);
      expect(draft.templateSlots.map((slot) => slot.slotId), [
        'cover-main',
        'p1-landscape',
      ]);
      expect(draft.templateSlots.first.pageIndex, 0);
      expect(draft.templateSlots.first.hint, contains('직접'));
      expect(draft.templateSlots.first.left, 0.08);
      expect(draft.templateSlots.first.imageTemplate, '4:3');
      expect(draft.templateSlots.first.caption, 'cover');
      expect(draft.templateSlots.first.emphasis, 1.7);
      expect(draft.reviewCtaLabel, '이 템플릿으로 시작하기');
    },
  );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/data/supabase_ai_album_draft_provider.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

void main() {
  test(
    'invokes ai-album-draft function and maps validated draft response',
    () async {
      late String functionName;
      late Map<String, Object?> requestBody;
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (name, body) async {
          functionName = name;
          requestBody = body;
          return {
            'title': '서버 연결 초안',
            'pageCount': 8,
            'recommendedPhotos': [
              {'assetId': 'photo-1'},
              {'assetId': 'photo-2'},
            ],
            'storySections': [
              {
                'title': '서버 흐름',
                'description': 'Edge Function 응답',
                'photoAssetIds': ['photo-1', 'photo-2'],
              },
            ],
          };
        },
      );
      final candidates = [
        _candidate(
          'photo-1',
          DateTime(2026, 8, 20),
          PhotoOrientation.landscape,
        ),
        _candidate('photo-2', DateTime(2026, 8, 21), PhotoOrientation.portrait),
        _candidate('photo-3', DateTime(2026, 8, 22), PhotoOrientation.square),
      ];

      final draft = await provider.createDraft(
        theme: AlbumTheme.travel,
        range: AiPhotoRange.limitedLibrary,
        candidates: candidates,
      );

      expect(functionName, 'ai-album-draft');
      expect(requestBody['theme'], 'travel');
      expect(requestBody['range'], 'limitedLibrary');
      expect(requestBody['candidates'], isA<List<Object?>>());
      expect(draft.title, '서버 연결 초안');
      expect(draft.recommendedPhotos.map((photo) => photo.assetId), [
        'photo-1',
        'photo-2',
      ]);
      expect(draft.requiresUserReview, isTrue);
    },
  );

  test(
    'throws no secret-leaking exception when function returns an error body',
    () async {
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, _) async => {
          'error': 'insufficient_candidates',
          'message': 'AI 앨범 초안 요청 형식을 확인해 주세요.',
        },
      );

      await expectLater(
        provider.createDraft(
          theme: AlbumTheme.daily,
          range: AiPhotoRange.recent30Days,
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
        ),
        throwsA(
          isA<SupabaseAiAlbumDraftProviderException>()
              .having((error) => error.code, 'code', 'insufficient_candidates')
              .having(
                (error) => error.toString(),
                'message',
                isNot(contains('Bearer')),
              ),
        ),
      );
    },
  );

  test('forwards advanced preview storage references when present', () async {
    late Map<String, Object?> requestBody;
    final provider = SupabaseAiAlbumDraftProvider(
      invokeFunction: (_, body) async {
        requestBody = body;
        return {
          'title': '서버 연결 초안',
          'pageCount': 8,
          'recommendedPhotos': [
            {'assetId': 'photo-1'},
          ],
          'storySections': [
            {
              'title': '서버 흐름',
              'description': 'Edge Function 응답',
              'photoAssetIds': ['photo-1'],
            },
          ],
        };
      },
    );

    await provider.createDraft(
      theme: AlbumTheme.travel,
      range: AiPhotoRange.limitedLibrary,
      candidates: [
        _candidate(
          'photo-1',
          DateTime(2026, 8, 20),
          PhotoOrientation.landscape,
          previewStorageUri:
              'supabase://ai-album-previews/user/draft/photo-1.jpg',
        ),
        _candidate('photo-2', DateTime(2026, 8, 21), PhotoOrientation.portrait),
        _candidate('photo-3', DateTime(2026, 8, 22), PhotoOrientation.square),
      ],
    );

    final candidatesJson = requestBody['candidates'] as List<Object?>;
    expect(
      candidatesJson.first,
      containsPair(
        'previewStorageUri',
        'supabase://ai-album-previews/user/draft/photo-1.jpg',
      ),
    );
    expect(
      candidatesJson[1] as Map<String, Object?>,
      isNot(contains('previewStorageUri')),
    );
  });
}

PhotoCandidate _candidate(
  String id,
  DateTime createdAt,
  PhotoOrientation orientation, {
  String? previewStorageUri,
}) {
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: orientation == PhotoOrientation.portrait ? 3000 : 4000,
    height: orientation == PhotoOrientation.landscape ? 3000 : 4000,
    orientation: orientation,
    previewStorageUri: previewStorageUri,
  );
}

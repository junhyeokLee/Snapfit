import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_template_builder.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  test('builds cover and story pages from AI recommendation draft', () {
    final draft = AlbumRecommendationDraft(
      theme: AlbumTheme.travel,
      title: '여행의 장면들',
      pageCount: 10,
      templateTone: '날짜 흐름이 보이는 따뜻한 여행 기록 템플릿',
      recommendedPhotos: [
        RecommendedPhoto(
          candidate: _candidate('photo-1', DateTime(2026, 8, 20)),
          score: 0.9,
          reasons: const ['여행 앨범에 어울리는 장소감'],
        ),
        RecommendedPhoto(
          candidate: _candidate('photo-2', DateTime(2026, 8, 20)),
          score: 0.8,
          reasons: const ['날짜 흐름을 이어주는 장면'],
        ),
      ],
      excludedPhotos: const [],
      storySections: const [
        StorySection(
          title: '여행의 시작',
          description: '앨범의 첫 인상이 되는 대표 장면이에요.',
          photoAssetIds: ['photo-1', 'photo-2'],
        ),
      ],
      summary: '날짜별 흐름을 살려 1개 묶음으로 나누었어요.',
    );

    final pages = const AiAlbumDraftTemplateBuilder().build(draft);

    expect(pages.length, 11);
    expect(
      pages.first.any((l) => l.type == LayerType.text && l.text == '여행의 장면들'),
      isTrue,
    );
    expect(pages[1].where((l) => l.type == LayerType.image), hasLength(2));
    expect(pages[1].any((l) => l.id.contains('photo-1')), isTrue);
    expect(
      pages[1].any((l) => l.type == LayerType.text && l.text == '여행의 시작'),
      isTrue,
    );
  });
}

PhotoCandidate _candidate(String id, DateTime createdAt) {
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: 4000,
    height: 3000,
    orientation: PhotoOrientation.landscape,
  );
}

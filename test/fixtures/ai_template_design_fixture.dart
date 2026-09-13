import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';

Map<String, Object?> templateDesignJson({
  int pageCount = 8,
  AiTemplateAspect aspect = AiTemplateAspect.square,
}) => {
  'version': 1,
  'concept': '제주의 느린 오후',
  'rationale': '풍경과 작은 장면 사이에 넓은 여백을 두고 짙은 초록으로 리듬을 만들었어요.',
  'aspect': aspect.name,
  'pages': List.generate(
    pageCount + 1,
    (i) => {
      'background': '#FFFFFF',
      'purpose': i == 0 ? '표지' : '장면 $i',
      'elements': [
        {
          'id': 'photo-$i',
          'kind': 'photo',
          'x': .08,
          'y': .08,
          'width': .84 - (i % 3) * .1,
          'height': .56,
          'color': '#D4DEDC',
        },
        {
          'id': 'text-$i',
          'kind': 'text',
          'x': .08,
          'y': .76,
          'width': .84,
          'height': .18,
          'color': '#203D35',
          'text': i == 0 ? '제주의 느린 오후' : '머무른 장면',
          'fontSize': 22,
          'weight': 600,
          'align': 'left',
        },
      ],
    },
  ),
};

AlbumRecommendationDraft templateDesignDraft({
  AiTemplateBrief brief = const AiTemplateBrief(prompt: '제주'),
}) {
  final design = AiTemplateDesign.fromJson(
    templateDesignJson(pageCount: brief.pageCount, aspect: brief.aspect),
    brief.pageCount,
  );
  return AlbumRecommendationDraft(
    draftId: 'slot-draft-1',
    theme: AlbumTheme.custom,
    title: design.concept,
    pageCount: brief.pageCount,
    templateTone: design.concept,
    recommendedPhotos: const [],
    excludedPhotos: const [],
    storySections: const [],
    summary: design.rationale,
    design: design,
    templateSlots: List.generate(
      brief.pageCount + 1,
      (i) => AiTemplateSlot(
        slotId: 'photo-$i',
        pageIndex: i,
        role: i == 0 ? 'cover' : 'photo',
        hint: '장면',
      ),
    ),
    reviewCtaLabel: '이 디자인 사용',
  );
}

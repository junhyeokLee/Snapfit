import 'entities/premium_template.dart';

/// Discovery uses catalog metadata only. Never materialize a template document
/// to search, filter a mood, or explain a related design.
class StoreTemplateStyle {
  const StoreTemplateStyle(this.id, this.label, this.terms);
  final String id, label;
  final List<String> terms;
}

const storeTemplateStyles = <StoreTemplateStyle>[
  StoreTemplateStyle('minimal', '미니멀', [
    '미니멀',
    'minimal',
    '심플',
    'simple',
    '여백',
    '정갈',
    '담백',
    '간결',
    '절제',
    '단정',
    '모노톤',
  ]),
  StoreTemplateStyle('film', '필름·빈티지', [
    '필름',
    '빈티지',
    '레트로',
    '아날로그',
    '폴라로이드',
    'film',
    'vintage',
  ]),
  StoreTemplateStyle('scrapbook', '스크랩북', [
    '스크랩',
    '콜라주',
    '오려',
    '티켓',
    '수집',
    '우표',
    'scrapbook',
    'collage',
  ]),
  StoreTemplateStyle('natural', '내추럴', [
    '내추럴',
    '보태니컬',
    '식물',
    '자연',
    '정원',
    '숲',
    '꽃',
    '나무',
    '목공',
    '허브',
    'natural',
  ]),
  StoreTemplateStyle('colorful', '컬러풀', [
    '컬러풀',
    '컬러',
    '발랄',
    '원색',
    '무지개',
    'colorful',
  ]),
  StoreTemplateStyle('romantic', '로맨틱', [
    '로맨틱',
    '레이스',
    '실크',
    '리본',
    '장미',
    '러브레터',
    'romantic',
  ]),
  StoreTemplateStyle('editorial', '에디토리얼', [
    '에디토리얼',
    '매거진',
    '잡지',
    '타이포',
    '레터링',
    '아카이브',
    '저널',
    'editorial',
  ]),
];

String _metadata(PremiumTemplate template) => [
  template.title,
  template.category ?? '',
  template.subTitle ?? '',
  template.description ?? '',
  ...?template.tags,
].join(' ').toLowerCase();

Set<String> storeTemplateStyleIds(PremiumTemplate template) {
  final text = _metadata(template);
  return {
    for (final style in storeTemplateStyles)
      if (style.terms.any(text.contains)) style.id,
  };
}

bool matchesStoreTemplateStyle(PremiumTemplate template, String? styleId) =>
    styleId == null || storeTemplateStyleIds(template).contains(styleId);

const _searchAliases = <List<String>>[
  ['강아지', '반려견', '멍멍이', 'dog'],
  ['고양이', '반려묘', '냥이', 'cat'],
  ['반려동물', '반려견', '반려묘', '강아지', '고양이', '펫'],
  ['아기', '육아', '성장', '베이비'],
  ['첫돌', '돌잔치', '돌사진', '첫생일'],
  ['웨딩', '결혼', 'wedding'],
  ['커플', '연인', '데이트'],
  ['여행', '트래블', 'travel'],
  ['독서', '책방', '북클럽', '독서모임'],
  ['졸업', '새출발', '새 출발'],
];

/// Every word must match, but words may match different metadata fields. Alias
/// groups preserve specific intent (a dog query must not match cat-only books).
bool matchesStoreTemplateQuery(PremiumTemplate template, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'[\s,·/|]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return true;
  final text = _metadata(template);
  Set<String>? styles;
  return words.every((word) {
    if (text.contains(word)) return true;
    for (final style in storeTemplateStyles) {
      if (style.terms.contains(word) || style.label.toLowerCase() == word) {
        styles ??= storeTemplateStyleIds(template);
        if (styles!.contains(style.id)) return true;
      }
    }
    // The broad pet group only expands when the user's word is broad.
    final group = _searchAliases.where((group) {
      if (group.first == '반려동물') return word == '반려동물' || word == '펫';
      return group.contains(word);
    }).firstOrNull;
    return group?.any(text.contains) ?? false;
  });
}

class RelatedStoreTemplate {
  const RelatedStoreTemplate({required this.template, required this.reason});
  final PremiumTemplate template;
  final String reason;
}

const _genericTags = {
  'snapfit original',
  '직접 디자인',
  '스토리 에디션',
  '프리미엄',
  '프리미엄 컬렉션',
  '스튜디오 에디션',
  '아틀리에 에디션',
  '컨셉 에디션',
};

Set<String> _specificTags(PremiumTemplate template) => {
  for (final tag in template.tags ?? const <String>[])
    if (tag.trim().isNotEmpty &&
        !_genericTags.contains(tag.toLowerCase().trim()) &&
        tag != template.category &&
        tag != template.title &&
        !RegExp(r'\d|소재|페이지|쪽').hasMatch(tag))
      tag.toLowerCase().trim(),
};

/// Candidates must already be publicly eligible. No price/sales guess, no
/// account state, no global cache, and no unrelated fallback products.
List<RelatedStoreTemplate> recommendRelatedStoreTemplates(
  PremiumTemplate current,
  Iterable<PremiumTemplate> candidates, {
  int limit = 6,
}) {
  if (limit <= 0) return const [];
  final styles = storeTemplateStyleIds(current);
  final tags = _specificTags(current);
  final seen = {current.id};
  final ranked = <({PremiumTemplate template, int score, String reason})>[];
  for (final candidate in candidates) {
    if (!seen.add(candidate.id)) continue;
    final sameTopic =
        current.category?.trim().isNotEmpty == true &&
        current.category == candidate.category;
    final sharedStyles = styles.intersection(storeTemplateStyleIds(candidate));
    final sharedTags = tags.intersection(_specificTags(candidate));
    if (!sameTopic && sharedStyles.isEmpty && sharedTags.isEmpty) continue;
    final styleLabel = storeTemplateStyles
        .where((style) => sharedStyles.contains(style.id))
        .firstOrNull
        ?.label;
    final reason = sameTopic && styleLabel != null
        ? '${current.category} · $styleLabel'
        : styleLabel != null
        ? '$styleLabel 분위기가 닮았어요'
        : sharedTags.isNotEmpty
        ? '${(sharedTags.toList()..sort()).first} 취향이 닮았어요'
        : '같은 ${current.category} 이야기';
    ranked.add((
      template: candidate,
      score:
          (sameTopic ? 12 : 0) +
          sharedStyles.length * 9 +
          sharedTags.length * 4,
      reason: reason,
    ));
  }
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.template.id.compareTo(b.template.id);
  });
  return [
    for (final item in ranked.take(limit))
      RelatedStoreTemplate(template: item.template, reason: item.reason),
  ];
}

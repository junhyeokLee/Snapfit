import 'dart:collection';

import 'entities/premium_template.dart';
import 'store_template_editorial_selection.dart';

// Store discovery order, deliberately independent of the stable authoring order
// used by template layouts. This is a broad-use editorial order, not an asserted
// ranking of category views or sales.
const storeTemplateTopicOrder = [
  '일상',
  '여행',
  '스포츠·도전',
  '반려동물',
  '커플·기념일',
  '동아리',
  '웨딩',
  '졸업·새출발',
  '성장·육아',
  '가족·친구',
  '취미·기록',
];
const storeRecommendedCategory = '추천';
const storeRecommendationLimit = 24;

List<String> storeTemplateCategories(Iterable<String> topics) {
  final available =
      topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet()
        ..removeAll(['전체', storeRecommendedCategory]);
  final extra = available.difference(storeTemplateTopicOrder.toSet()).toList()
    ..sort();
  return [
    '전체',
    storeRecommendedCategory,
    ...storeTemplateTopicOrder.where(available.contains),
    ...extra,
  ];
}

/// Only eligible metadata enters this function. Never reads templateJson,
/// requests a document, or keeps images/global recommendation state alive.
List<PremiumTemplate> recommendStoreTemplates(
  Iterable<PremiumTemplate> candidates, {
  required bool Function(PremiumTemplate) isPaid,
  Set<int> featuredIds = const {},
  Set<int> favoriteIds = const {},
  int limit = storeRecommendationLimit,
}) {
  if (limit <= 0) return [];
  final seen = <int>{};
  final ranked = <_Candidate>[];
  for (final (index, template) in candidates.indexed) {
    if (!seen.add(template.id)) continue;
    ranked.add(
      _Candidate(
        template,
        index,
        isPaid(template),
        featuredIds.contains(template.id),
        favoriteIds.contains(template.id),
        reviewedStoreTemplateIds.contains(template.id),
      ),
    );
  }
  ranked.sort(_compare);
  final pools = <String, _TopicPool>{};
  for (final candidate in ranked) {
    final topic = candidate.template.category?.trim();
    final pool = pools.putIfAbsent(
      topic == null || topic.isEmpty ? '기타' : topic,
      _TopicPool.new,
    );
    (candidate.paid ? pool.paid : pool.free).add(candidate);
  }
  final topics = storeTemplateCategories(pools.keys)
      .where((topic) => topic != '전체' && topic != storeRecommendedCategory)
      .toList();
  final selected = <PremiumTemplate>[];
  for (var round = 0; selected.length < limit; round++) {
    var added = false;
    for (final topic in topics) {
      final candidate = pools[topic]!.take(round);
      if (candidate == null) continue;
      selected.add(candidate.template);
      added = true;
      if (selected.length == limit) break;
    }
    if (!added) break;
  }
  return selected;
}

class _Candidate {
  const _Candidate(
    this.template,
    this.index,
    this.paid,
    this.featured,
    this.favorite,
    this.reviewed,
  );
  final PremiumTemplate template;
  final int index;
  final bool paid, featured, favorite, reviewed;
}

int _compare(_Candidate a, _Candidate b) {
  int flag(bool left, bool right) => (right ? 1 : 0).compareTo(left ? 1 : 0);
  var order = flag(a.favorite, b.favorite);
  if (order != 0) return order;
  order = flag(a.featured, b.featured);
  if (order != 0) return order;
  order = flag(a.reviewed, b.reviewed);
  if (order != 0) return order;
  order = b.template.weeklyScore.compareTo(a.template.weeklyScore);
  if (order != 0) return order;
  order = b.template.userCount.compareTo(a.template.userCount);
  if (order != 0) return order;
  order = flag(a.template.isBest, b.template.isBest);
  if (order != 0) return order;
  order = flag(a.template.isNew, b.template.isNew);
  return order != 0 ? order : a.index.compareTo(b.index);
}

class _TopicPool {
  final free = Queue<_Candidate>();
  final paid = Queue<_Candidate>();
  bool? _firstWasPaid;
  _Candidate? take(int round) {
    if (free.isEmpty && paid.isEmpty) return null;
    final Queue<_Candidate> queue;
    if (round == 1 && _firstWasPaid == true && free.isNotEmpty) {
      queue = free;
    } else if (round == 1 && _firstWasPaid == false && paid.isNotEmpty) {
      queue = paid;
    } else if (free.isEmpty) {
      queue = paid;
    } else if (paid.isEmpty || _compare(free.first, paid.first) <= 0) {
      queue = free;
    } else {
      queue = paid;
    }
    final next = queue.removeFirst();
    _firstWasPaid ??= next.paid;
    return next;
  }
}

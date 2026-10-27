import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';

PremiumTemplate _item(
  int id,
  String topic, {
  bool paid = false,
  int score = 0,
  int uses = 0,
}) => PremiumTemplate(
  id: id,
  title: 'Design $id',
  category: topic,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: uses,
  weeklyScore: score,
  isPremium: paid,
  documentBuilder: () =>
      throw StateError('Recommendation must not author artwork'),
);

void main() {
  test(
    'store navigation is broad-use first, with all and recommendations pinned',
    () {
      expect(storeTemplateCategories(templateTopicOrder.reversed), [
        '전체',
        '추천',
        '일상',
        '여행',
        '가족·친구',
        '커플·기념일',
        '성장·육아',
        '반려동물',
        '동아리',
        '스포츠·도전',
        '졸업·새출발',
        '웨딩',
      ]);
      expect(
        templateTopicOrder.first,
        '웨딩',
        reason: 'Authoring indices must not change',
      );
      expect(
        storeTemplateCategories(['', '여행', '일상', '여행', '추천', '기타', '전체']),
        ['전체', '추천', '일상', '여행', '기타'],
      );
    },
  );

  test(
    'bounded recommendations diversify topics and both price tiers without decoding artwork',
    () {
      final items = <PremiumTemplate>[
        for (final (topicIndex, topic) in templateTopicOrder.indexed)
          for (var n = 0; n < 10; n++)
            _item(topicIndex * 10 + n, topic, paid: n.isOdd),
      ];
      final result = recommendStoreTemplates(items, isPaid: (t) => t.isPremium);
      expect(result, hasLength(24));
      expect(result.map((t) => t.id).toSet(), hasLength(24));
      expect(result.take(10).map((t) => t.category), storeTemplateTopicOrder);
      for (final topic in templateTopicOrder) {
        final selected = result.where((t) => t.category == topic).toList();
        expect(selected.length, inInclusiveRange(2, 3));
        expect(selected.take(2).map((t) => t.isPremium).toSet(), {false, true});
      }
      expect(
        recommendStoreTemplates(
          items,
          isPaid: (t) => t.isPremium,
        ).map((t) => t.id),
        result.map((t) => t.id),
        reason: 'No random shuffling while browsing',
      );
    },
  );

  test('favorites, editorial picks and actual usage rank within a topic', () {
    final items = [
      _item(1, '일상'),
      _item(2, '일상', score: 300),
      _item(3, '일상', uses: 100),
      _item(4, '일상'),
      _item(5, '일상'),
    ];
    final result = recommendStoreTemplates(
      items,
      isPaid: (_) => false,
      featuredIds: {4},
      favoriteIds: {5},
    );
    expect(result.map((t) => t.id), [5, 4, 2, 3, 1]);
  });

  test(
    'sparse, paid-only and duplicate catalogs do not invent designs or starve topics',
    () {
      final item = _item(1, '새 주제', paid: true);
      final result = recommendStoreTemplates([
        item,
        item,
        _item(2, '여행', paid: true),
      ], isPaid: (_) => true);
      expect(result.map((t) => t.id), [2, 1]);
      expect(recommendStoreTemplates([], isPaid: (_) => false), isEmpty);
      expect(
        recommendStoreTemplates([item], isPaid: (_) => true, limit: 0),
        isEmpty,
      );
    },
  );

  test('price classification happens only once per unique candidate', () {
    var checks = 0;
    final items = [
      for (var n = 0; n < 3000; n++)
        _item(n, storeTemplateTopicOrder[n % 10], paid: n.isOdd),
    ];
    expect(
      recommendStoreTemplates(
        [...items, ...items],
        isPaid: (t) {
          checks++;
          return t.isPremium;
        },
      ),
      hasLength(24),
    );
    expect(checks, items.length);
  });
}

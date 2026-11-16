import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/public_discovery_ordering.dart';
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';

PremiumTemplate _design(int id, String? topic, {bool premium = false}) =>
    PremiumTemplate(
      id: id,
      title: '디자인 $id',
      category: topic,
      isPremium: premium,
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 24,
      userCount: 0,
      documentBuilder: () =>
          throw StateError('Ordering must not parse artwork'),
    );

List<PremiumTemplate> _ordered(Iterable<PremiumTemplate> items) =>
    orderPublicDiscoveryTemplates(items, now: DateTime.utc(2027, 1, 1));

void main() {
  test(
    'the first twelve published designs include all published subjects and both tiers',
    () {
      final first = _ordered(publishedCreationTemplates).take(12).toList();
      expect(
        first.map((item) => item.category).toSet(),
        templateTopicOrder.toSet(),
      );
      expect(first.map((item) => item.isPremium).toSet(), {false, true});
      expect(
        first.take(templateTopicOrder.length).map((item) => item.category),
        storeTemplateTopicOrder,
      );
    },
  );

  test(
    'all catalog identities and original objects survive in stable order',
    () {
      final before = publishedCreationTemplates.map((item) => item.id).toList();
      final ordered = _ordered(publishedCreationTemplates);
      expect(ordered, hasLength(publishedCreationTemplates.length));
      expect(ordered.map((item) => item.id).toSet(), before.toSet());
      expect(
        ordered.map((item) => item.id).toSet(),
        hasLength(publishedCreationTemplates.length),
      );
      for (final item in ordered) {
        expect(
          item,
          same(
            publishedCreationTemplates.singleWhere(
              (original) => original.id == item.id,
            ),
          ),
        );
      }
      expect(_ordered(publishedCreationTemplates), ordered);
      expect(publishedCreationTemplates.map((item) => item.id), before);
      expect(() => ordered.clear(), throwsUnsupportedError);
    },
  );

  test('each subject and tier retains its original catalog order', () {
    final ordered = _ordered(publishedCreationTemplates);
    for (final topic in templateTopicOrder) {
      for (final premium in [false, true]) {
        Iterable<int> ids(Iterable<PremiumTemplate> items) => items
            .where(
              (item) => item.category == topic && item.isPremium == premium,
            )
            .map((item) => item.id);
        expect(
          ids(ordered),
          ids(publishedCreationTemplates),
          reason: '$topic / $premium',
        );
      }
    }
  });

  test(
    'sparse tiers, unknown subjects and duplicate IDs cannot hide a design',
    () {
      final first = _design(1, '여행', premium: true);
      final source = [
        first,
        _design(1, '가족·친구'),
        _design(2, '여행', premium: true),
        _design(3, '새로운 주제'),
        _design(4, null),
        _design(5, ''),
      ];
      final ordered = _ordered(source);
      expect(ordered.map((item) => item.id), [1, 3, 4, 2, 5]);
      expect(ordered.first, same(first));
      expect(source, hasLength(6));
      expect(_ordered([]), isEmpty);
      expect(_ordered([first]), [first]);
    },
  );

  test('search and subject result sets are unchanged by discovery ordering', () {
    final ordered = _ordered(publishedCreationTemplates);
    for (final query in ['', '사진', '여행', '성장', '없는디자인']) {
      for (final topic in ['전체', ...templateTopicOrder]) {
        Set<int> results(Iterable<PremiumTemplate> items) => items
            .where(
              (item) =>
                  (topic == '전체' || item.category == topic) &&
                  '${item.title} ${item.description ?? ''} ${item.tags?.join(' ') ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .map((item) => item.id)
            .toSet();
        expect(
          results(ordered),
          results(publishedCreationTemplates),
          reason: '$topic / $query',
        );
      }
    }
  });

  test(
    'ordering uses metadata without reading artwork or popularity signals',
    () {
      final source = [
        _design(1, '여행'),
        _design(2, '여행', premium: true),
        _design(3, '일상'),
        _design(4, '일상', premium: true),
      ];
      final embellished = [
        for (final item in source)
          item.copyWith(
            likeCount: 90000 - item.id,
            userCount: item.id * 1000,
            weeklyScore: item.id * 500,
            isBest: true,
            isNew: true,
          ),
      ];
      expect(
        _ordered(embellished).map((item) => item.id),
        _ordered(source).map((item) => item.id),
      );
    },
  );
}

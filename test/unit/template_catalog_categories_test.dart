import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/template_catalog_categories.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';

void main() {
  test('eleven populated topics preserve the original authoring indices', () {
    expect(templateTopicOrder, [
      '웨딩',
      '여행',
      '일상',
      '성장·육아',
      '가족·친구',
      '커플·기념일',
      '반려동물',
      '스포츠·도전',
      '졸업·새출발',
      '동아리',
      '취미·기록',
    ]);
    expect(
      orderedTemplateTopics(
        authoredCollections.reversed.map((c) => c.category),
      ),
      templateTopicOrder.take(7).toList(),
    );
    const freeCounts = {
      '동아리': 5,
      '웨딩': 6,
      '여행': 6,
      '일상': 7,
      '성장·육아': 6,
      '가족·친구': 6,
      '커플·기념일': 6,
      '반려동물': 6,
      '취미·기록': 4,
      '졸업·새출발': 2,
    };
    const totalCounts = {
      '동아리': 19,
      '웨딩': 19,
      '여행': 20,
      '일상': 19,
      '성장·육아': 19,
      '가족·친구': 19,
      '커플·기념일': 18,
      '반려동물': 19,
      '스포츠·도전': 14,
      '졸업·새출발': 14,
      '취미·기록': 14,
    };
    for (final topic in templateTopicOrder) {
      expect(
        bundledCreationTemplates.where((t) => t.category == topic).length,
        freeCounts[topic] ?? 0,
      );
      expect(
        publishedDesignTemplates.where((t) => t.category == topic).length,
        totalCounts[topic],
      );
      expect(
        totalCounts[topic],
        greaterThanOrEqualTo(10),
        reason: '$topic must offer at least ten independently authored books',
      );
    }
    expect(orderedTemplateTopics(['', '기타', '여행', '여행']), ['여행', '기타']);
  });

  test(
    'topics and moods are separate; discovery tags reach store and editor',
    () {
      expect(
        collectionStyleTags.keys.toSet(),
        authoredCollections.map((c) => c.id).toSet(),
      );
      for (final c in authoredCollections) {
        expect(c.styleTags, isNotEmpty);
        final store = bundledCreationTemplates.singleWhere(
          (t) => t.id == c.bundledId,
        );
        final editor = publishedDesignTemplates.singleWhere(
          (t) => t.id == c.id,
        );
        expect(store.tags, containsAll(c.styleTags));
        expect(editor.tags, containsAll(c.styleTags));
        expect(store.category, c.category);
        expect(store.isPremium, false);
      }
      for (final query in ['첫돌', '우정', '데이트', '강아지', '고양이', '필름', '스크랩북']) {
        expect(
          bundledCreationTemplates.any((t) => t.tags!.contains(query)),
          true,
          reason: query,
        );
      }
    },
  );

  test(
    'new books have stable independent IDs and complete editable documents',
    () {
      final fresh = authoredCollections.skip(15).take(20).toList();
      expect(fresh.length, 20);
      expect(fresh.map((c) => c.bundledId).toSet().length, 20);
      for (final c in fresh) {
        for (final aspect in CollectionAspect.printable) {
          final doc = c.document(aspect);
          expect(doc['source'], 'snapfit-authored-free');
          expect(doc['accessTier'], 'free');
          expect((doc['pages'] as List).length, 24);
          expect((doc['chapters'] as List).last['to'], 24);
          expect((doc['layoutSafety'] as Map)['printVerified'], false);
        }
      }
    },
  );
}

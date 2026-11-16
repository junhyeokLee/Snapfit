import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/story_edition_catalog.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_template_discovery.dart';

PremiumTemplate _template(
  int id, {
  String? title,
  String? category,
  String? subtitle,
  String? description,
  List<String>? tags,
  String Function()? documentBuilder,
}) => PremiumTemplate(
  id: id,
  title: title ?? '디자인 $id',
  category: category,
  subTitle: subtitle,
  description: description,
  tags: tags,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: 0,
  documentBuilder:
      documentBuilder ??
      () => throw StateError('Discovery must not build template documents'),
);

List<int> _relatedIds(
  PremiumTemplate current,
  Iterable<PremiumTemplate> candidates, {
  int limit = 6,
}) => recommendRelatedStoreTemplates(
  current,
  candidates,
  limit: limit,
).map((result) => result.template.id).toList();

void main() {
  group('metadata search', () {
    test('each query word can match a different metadata field', () {
      final design = _template(
        1,
        title: '느리게 걷는 오후',
        category: '여행',
        subtitle: '오래 머문 골목',
        description: '소중한 티켓을 모아요',
        tags: ['필름', '바다'],
      );

      expect(matchesStoreTemplateQuery(design, '여행 오후 바다'), isTrue);
      expect(matchesStoreTemplateQuery(design, '골목 티켓'), isTrue);
      expect(matchesStoreTemplateQuery(design, '여행·필름'), isTrue);
      expect(matchesStoreTemplateQuery(design, '여행, 필름'), isTrue);
      expect(matchesStoreTemplateQuery(design, '  여행   바다  '), isTrue);
      expect(matchesStoreTemplateQuery(design, '여행 바다 졸업'), isFalse);
    });

    test('specific pet aliases do not widen into another animal', () {
      final dog = _template(1, category: '반려동물', tags: ['반려견', '산책']);
      final cat = _template(2, category: '반려동물', tags: ['반려묘', '낮잠']);

      for (final query in ['강아지', '멍멍이', 'DOG']) {
        expect(matchesStoreTemplateQuery(dog, query), isTrue, reason: query);
        expect(matchesStoreTemplateQuery(cat, query), isFalse, reason: query);
      }
      for (final query in ['고양이', '냥이', 'cat']) {
        expect(matchesStoreTemplateQuery(cat, query), isTrue, reason: query);
        expect(matchesStoreTemplateQuery(dog, query), isFalse, reason: query);
      }
      expect(matchesStoreTemplateQuery(dog, '반려동물'), isTrue);
      expect(matchesStoreTemplateQuery(cat, '펫'), isTrue);
      expect(matchesStoreTemplateQuery(dog, '강아지 산책'), isTrue);
      expect(matchesStoreTemplateQuery(cat, '강아지 산책'), isFalse);
    });

    test('style aliases compose with a topic and normalize English case', () {
      final filmTrip = _template(1, category: '여행', tags: ['필름']);
      final minimalTrip = _template(2, category: '여행', tags: ['미니멀']);

      expect(matchesStoreTemplateQuery(filmTrip, '여행 빈티지'), isTrue);
      expect(matchesStoreTemplateQuery(filmTrip, 'TRAVEL VINTAGE'), isTrue);
      expect(matchesStoreTemplateQuery(minimalTrip, '여행 빈티지'), isFalse);
      expect(matchesStoreTemplateStyle(filmTrip, 'film'), isTrue);
      expect(matchesStoreTemplateStyle(filmTrip, 'minimal'), isFalse);
      expect(matchesStoreTemplateStyle(filmTrip, null), isTrue);
      expect(matchesStoreTemplateQuery(minimalTrip, '심플 여행'), isTrue);
    });

    test('empty search retains metadata-poor templates without guessing', () {
      final unknown = _template(1);

      expect(matchesStoreTemplateQuery(unknown, ''), isTrue);
      expect(matchesStoreTemplateQuery(unknown, ' \n\t '), isTrue);
      expect(matchesStoreTemplateQuery(unknown, '웨딩'), isFalse);
      expect(storeTemplateStyleIds(unknown), isEmpty);
      expect(matchesStoreTemplateStyle(unknown, 'unknown-style'), isFalse);
    });

    test('all seven visible moods have real published catalog results', () {
      expect(storeTemplateStyles, hasLength(7));
      expect(
        storeTemplateStyles.map((style) => style.id).toSet(),
        hasLength(storeTemplateStyles.length),
      );
      for (final style in storeTemplateStyles) {
        expect(
          publishedCreationTemplates.where(
            (template) => matchesStoreTemplateStyle(template, style.id),
          ),
          isNotEmpty,
          reason: '${style.label} must not promise an empty catalog',
        );
      }
    });

    test(
      'authored jacket metadata reaches discovery without document reads',
      () {
        final published = {
          for (final template in publishedCreationTemplates)
            template.id: template,
        };
        for (final edition in storyEditions) {
          expect(
            edition.styleTags,
            isNotEmpty,
            reason: '${edition.id} must index its authored jacket style',
          );
          expect(
            published[edition.catalogId]!.tags,
            containsAll(edition.styleTags),
          );
        }
        expect(matchesStoreTemplateStyle(published[-9802]!, 'minimal'), isTrue);
        expect(
          matchesStoreTemplateStyle(published[-9803]!, 'scrapbook'),
          isTrue,
        );
        expect(
          matchesStoreTemplateStyle(published[-9771]!, 'editorial'),
          isTrue,
        );
        // The two cover families deliberately reuse numeric layout identifiers.
        final original = originalStoryEditions.firstWhere(
          (e) => e.coverStyle == 3,
        );
        final quartet = premiumQuartetEditions.firstWhere(
          (e) => e.coverStyle == 3,
        );
        expect(original.styleTags, ['로맨틱']);
        expect(quartet.styleTags, ['미니멀', '에디토리얼']);
      },
    );

    test('suggested searches resolve to real published designs', () {
      for (final query in ['여행 필름', '여행 빈티지', '강아지 산책', '첫돌']) {
        expect(
          publishedCreationTemplates.where(
            (template) => matchesStoreTemplateQuery(template, query),
          ),
          isNotEmpty,
          reason: 'The suggested query "$query" must find a design',
        );
      }
    });
  });

  group('related designs', () {
    test(
      'excludes the current design, duplicate identities and unrelated ones',
      () {
        final current = _template(1, category: '여행', tags: ['필름']);
        final related = _template(2, category: '여행', tags: ['필름']);
        final unrelated = _template(3, category: '육아', tags: ['로맨틱']);

        final result = recommendRelatedStoreTemplates(current, [
          current,
          current.copyWith(title: '현재 상품의 복제 행'),
          related,
          related,
          unrelated,
        ]);

        expect(result.map((item) => item.template.id), [2]);
        expect(result.single.template, same(related));
        expect(result.single.reason, contains('여행'));
        expect(result.single.reason, contains('필름'));
      },
    );

    test('shared topic and style rank before topic alone', () {
      final current = _template(1, category: '여행', tags: ['필름']);
      final topicOnly = _template(2, category: '여행');
      final topicAndStyle = _template(20, category: '여행', tags: ['빈티지']);

      expect(_relatedIds(current, [topicOnly, topicAndStyle]), [20, 2]);
    });

    test('equal relevance has a fixed order regardless of candidate order', () {
      final current = _template(100, category: '여행');
      final candidates = [
        _template(9, category: '여행'),
        _template(4, category: '여행'),
        _template(7, category: '여행'),
      ];

      expect(_relatedIds(current, candidates), [4, 7, 9]);
      expect(_relatedIds(current, candidates.reversed), [4, 7, 9]);
      expect(candidates.map((item) => item.id), [9, 4, 7]);
    });

    test(
      'generic marketing, page count and kit tags do not create similarity',
      () {
        const genericTags = [
          'SnapFit Original',
          '직접 디자인',
          '스토리 에디션',
          '프리미엄',
          '프리미엄 컬렉션',
          '스튜디오 에디션',
          '아틀리에 에디션',
          '컨셉 에디션',
          '32쪽',
          '24페이지',
          '전용 소재 8종',
        ];
        final current = _template(1, tags: genericTags);
        final onlyMarketing = _template(2, tags: genericTags);

        expect(_relatedIds(current, [onlyMarketing]), isEmpty);
      },
    );

    test('specific shared tags can connect different topics with a reason', () {
      final current = _template(1, category: '취미·기록', tags: ['독서']);
      final related = _template(2, category: '동아리', tags: ['독서']);

      final result = recommendRelatedStoreTemplates(current, [related]);
      expect(result.single.template, same(related));
      expect(result.single.reason, contains('독서'));
    });

    test(
      'limits stay bounded and empty or unknown metadata has no fallback',
      () {
        final current = _template(100, category: '여행');
        final candidates = [
          for (var id = 0; id < 10; id++) _template(id, category: '여행'),
        ];

        expect(_relatedIds(current, candidates), hasLength(6));
        expect(_relatedIds(current, candidates, limit: 2), [0, 1]);
        expect(_relatedIds(current, candidates, limit: 0), isEmpty);
        expect(_relatedIds(current, candidates, limit: -1), isEmpty);
        expect(_relatedIds(current, const []), isEmpty);
        expect(_relatedIds(_template(30), [_template(31)]), isEmpty);
      },
    );
  });

  test(
    'search, mood filters and related recommendations never read documents',
    () {
      var documentReads = 0;
      String document() {
        documentReads++;
        throw StateError('Document work is forbidden during discovery');
      }

      final current = _template(
        1,
        category: '여행',
        tags: ['필름'],
        documentBuilder: document,
      );
      final related = _template(
        2,
        category: '여행',
        tags: ['빈티지'],
        documentBuilder: document,
      );

      expect(matchesStoreTemplateQuery(current, '여행 빈티지'), isTrue);
      expect(matchesStoreTemplateStyle(current, 'film'), isTrue);
      expect(storeTemplateStyleIds(current), contains('film'));
      expect(_relatedIds(current, [related]), [2]);
      expect(documentReads, 0);
    },
  );
}

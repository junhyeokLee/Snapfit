import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/public_discovery_ordering.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';
import 'package:snap_fit/features/store/domain/store_template_recommendations.dart';

void main() {
  final published = DateTime.utc(2026, 11, 2, 18, 1, 39);
  final now = published.add(const Duration(hours: 1));

  test(
    'NEW has a strict first-release window; unknown and future dates do not qualify',
    () {
      final item = StoreProductDiscovery(firstPublishedAt: published);
      expect(item.isNewAt(published), isTrue);
      expect(
        item.isNewAt(published.subtract(const Duration(microseconds: 1))),
        isFalse,
      );
      expect(item.isNewAt(published.add(const Duration(days: 14))), isFalse);
      expect(
        item.isNewAt(
          published
              .add(const Duration(days: 14))
              .subtract(const Duration(microseconds: 1)),
        ),
        isTrue,
      );
      expect(const StoreProductDiscovery().isNewAt(now), isFalse);
      expect(
        StoreProductDiscovery.fromJson({
          'is_new': true,
          'created_at': now.toIso8601String(),
        }).isNewAt(now),
        isFalse,
      );
    },
  );

  test(
    'verified public releases lead discovery while all catalog identities remain',
    () {
      final result = orderPublicDiscoveryTemplates(
        publishedCreationTemplates,
        now: now,
      );
      expect(result.take(2).map((t) => t.id).toSet(), {-9761, -9762});
      expect(
        result.map((t) => t.id).toSet(),
        publishedCreationTemplates.map((t) => t.id).toSet(),
      );
      expect(result.length, publishedCreationTemplates.length);
      expect(
        publishedCreationTemplates.every((t) => !t.isNew && !t.isBest),
        isTrue,
      );
      final expired = orderPublicDiscoveryTemplates(
        publishedCreationTemplates,
        now: published.add(const Duration(days: 14)),
      );
      expect(expired.first.id, isNot(-9761));
    },
  );

  test(
    'verified releases respect their own dates and fallback cannot invent a BEST',
    () {
      expect(bundledStoreDiscovery, hasLength(488));
      expect(
        bundledStoreDiscovery.values.where((m) => m.isNewAt(now)),
        hasLength(18),
      );
      expect(bundledStoreDiscovery.values.any((m) => m.isBest), isFalse);
      for (final rank in [-1, 0, 6, 99]) {
        expect(StoreProductDiscovery(bestRank: rank).isBest, isFalse);
      }
      expect(const StoreProductDiscovery(bestRank: 5).isBest, isTrue);
      expect(StoreProductDiscovery.fromJson({'is_best': true}).isBest, isFalse);
    },
  );

  test(
    'new priority is stable, metadata-only, and expires back to the source order',
    () {
      final source = ['old', 'new', 'older', 'newer'];
      final metadata = {
        'new': StoreProductDiscovery(firstPublishedAt: published),
        'newer': StoreProductDiscovery(
          firstPublishedAt: published.add(const Duration(minutes: 10)),
        ),
      };
      expect(
        prioritizeNewStoreProducts(
          source,
          productKey: (s) => s,
          discovery: metadata,
          now: now,
        ),
        ['newer', 'new', 'old', 'older'],
      );
      expect(
        prioritizeNewStoreProducts(
          source,
          productKey: (s) => s,
          discovery: metadata,
          now: published.add(const Duration(days: 15)),
        ),
        source,
      );
      expect(source, ['old', 'new', 'older', 'newer']);
    },
  );

  test(
    'latest keeps verified publication order after NEW expires without using names',
    () {
      final source = [
        'unknown-z',
        'old-a',
        'future',
        'new-z',
        'same-a',
        'unknown-a',
      ];
      final metadata = {
        'old-a': StoreProductDiscovery(firstPublishedAt: published),
        'new-z': StoreProductDiscovery(
          firstPublishedAt: published.add(const Duration(days: 1)),
        ),
        'same-a': StoreProductDiscovery(
          firstPublishedAt: published.add(const Duration(days: 1)),
        ),
        'future': StoreProductDiscovery(
          firstPublishedAt: published.add(const Duration(days: 100)),
        ),
      };
      expect(
        sortStoreProducts(
          source,
          productKey: (s) => s,
          discovery: metadata,
          now: published.add(const Duration(days: 30)),
        ),
        ['new-z', 'same-a', 'old-a', 'unknown-z', 'future', 'unknown-a'],
      );
      expect(source.first, 'unknown-z');
    },
  );

  test(
    'popular uses qualifying server ranks and otherwise falls back to latest',
    () {
      final source = ['latest', 'rank-2', 'invalid-rank', 'rank-1', 'unknown'];
      final metadata = {
        'latest': StoreProductDiscovery(
          firstPublishedAt: published.add(const Duration(minutes: 20)),
        ),
        'rank-2': StoreProductDiscovery(
          firstPublishedAt: published,
          bestRank: 2,
        ),
        'invalid-rank': StoreProductDiscovery(
          firstPublishedAt: published,
          bestRank: 0,
        ),
        'rank-1': const StoreProductDiscovery(bestRank: 1),
      };
      expect(
        sortStoreProducts(
          source,
          productKey: (s) => s,
          discovery: metadata,
          now: now,
          popularityFirst: true,
        ),
        ['rank-1', 'rank-2', 'latest', 'invalid-rank', 'unknown'],
      );
      final offline = {
        for (final entry in metadata.entries)
          entry.key: StoreProductDiscovery(
            firstPublishedAt: entry.value.firstPublishedAt,
          ),
      };
      expect(
        sortStoreProducts(
          source,
          productKey: (s) => s,
          discovery: offline,
          now: now,
          popularityFirst: true,
        ),
        sortStoreProducts(
          source,
          productKey: (s) => s,
          discovery: offline,
          now: now,
        ),
      );
    },
  );

  test(
    'requested topics come first, duplicates collapse, and omitted topics remain available',
    () {
      final topics = storeTemplateCategories([
        '가족·친구',
        '성장·육아',
        '여행',
        '일상',
        '여행',
        '스포츠·도전',
        '반려동물',
        '웨딩',
        '커플·기념일',
        '동아리',
        '졸업·새출발',
      ]);
      expect(topics, [
        '전체',
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
        '추천',
      ]);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/creation_catalog_selection.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_product_discovery.dart';

PremiumTemplate _template(
  int id, {
  String? title,
  String category = '일상',
  List<String> tags = const [],
  bool premium = false,
  bool best = false,
  int uses = 0,
  int score = 0,
}) => PremiumTemplate(
  id: id,
  title: title ?? 'Design $id',
  category: category,
  tags: tags,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: uses,
  weeklyScore: score,
  isPremium: premium,
  isBest: best,
  documentBuilder: () =>
      throw StateError('Catalog selection must not build a document'),
);

String _key(int id) => 'template:server-$id';

PointShopProduct _product(int id, int? price, {bool active = true}) =>
    PointShopProduct(
      productKey: _key(id),
      kind: 'template',
      assetId: '$id',
      title: 'Design $id',
      pointPrice: price,
      isActive: active,
    );

void main() {
  final now = DateTime.utc(2026, 11, 11);

  List<int> select(
    Iterable<PremiumTemplate> templates, {
    String category = '전체',
    String price = '전체',
    String query = '',
    bool favoritesOnly = false,
    Set<int> favoriteIds = const {},
    Map<String, PointShopProduct> products = const {},
    Map<String, StoreProductDiscovery> discovery = const {},
    Set<int> featuredIds = const {},
  }) => selectCreationCatalog(
    templates: templates,
    category: category,
    price: price,
    query: query,
    favoritesOnly: favoritesOnly,
    favoriteIds: favoriteIds,
    products: products,
    discovery: discovery,
    now: now,
    featuredIds: featuredIds,
  ).map((template) => template.id).toList();

  test('active server prices override contradictory premium metadata', () {
    final templates = [
      _template(1, premium: true),
      _template(2),
      _template(3, premium: true),
    ];
    final products = {
      _key(1): _product(1, 0),
      _key(2): _product(2, 1800),
      _key(3): _product(3, 2500),
    };

    expect(select(templates, price: '무료', products: products), [1]);
    expect(select(templates, price: '유료', products: products), [2, 3]);
  });

  test(
    'unavailable prices remain readable without entering confirmed price filters',
    () {
      final templates = [
        _template(1),
        _template(2, premium: true),
        _template(3),
        _template(4, premium: true),
        _template(5),
        _template(6, premium: true),
      ];
      final products = {
        _key(1): _product(1, 0, active: false),
        _key(2): _product(2, 1800, active: false),
        _key(3): _product(3, null),
        _key(4): _product(4, null),
      };

      expect(select(templates, products: products), [1, 2, 3, 4, 5, 6]);
      expect(select(templates, price: '무료', products: products), [5]);
      // Missing premium products stay in paid discovery, never in free results.
      expect(select(templates, price: '유료', products: products), [6]);
    },
  );

  test('topic, server price, query and favorite membership combine', () {
    final templates = [
      _template(11, title: 'Travel Film', category: ' 여행 '),
      _template(12, title: 'Travel Film', category: '여행', premium: true),
      _template(13, title: 'Travel Film', category: '일상'),
      _template(14, title: 'Other', category: '여행'),
      _template(15, title: 'Travel Film', category: '여행'),
    ];
    final products = {
      _key(11): _product(11, 1800),
      _key(12): _product(12, 0),
      _key(13): _product(13, 1800),
      _key(14): _product(14, 1800),
      _key(15): _product(15, 1800),
    };

    expect(
      select(
        templates,
        category: '여행',
        price: '유료',
        query: '  FILM  ',
        favoritesOnly: true,
        favoriteIds: {11, 12, 13, 14},
        products: products,
      ),
      [11],
    );
    expect(select(templates, category: '여'), isEmpty);
  });

  test('category changes replace the previous discovery mode and topic', () {
    final templates = [
      _template(21),
      _template(22, category: '여행'),
      _template(23, category: '여행'),
    ];
    final discovery = {
      _key(21): StoreProductDiscovery(
        bestRank: 1,
        firstPublishedAt: now.subtract(const Duration(days: 30)),
      ),
      _key(22): StoreProductDiscovery(
        bestRank: 2,
        firstPublishedAt: now.subtract(const Duration(days: 20)),
      ),
      _key(23): StoreProductDiscovery(
        firstPublishedAt: now.subtract(const Duration(days: 15)),
      ),
    };

    expect(select(templates, category: '인기', discovery: discovery), [
      21,
      22,
      23,
    ]);
    expect(select(templates, category: '여행', discovery: discovery), [23, 22]);
    expect(select(templates, category: '추천', discovery: discovery), [
      21,
      22,
      23,
    ]);
    expect(select(templates, category: '전체', discovery: discovery), [
      23,
      22,
      21,
    ]);
  });

  test(
    'popularity uses qualifying server ranks rather than template claims',
    () {
      final templates = [
        _template(31, best: true, uses: 999999, score: 999999),
        _template(32),
        _template(33),
        _template(34, best: true),
      ];
      final discovery = {
        _key(31): StoreProductDiscovery(firstPublishedAt: now),
        _key(32): StoreProductDiscovery(
          bestRank: 2,
          firstPublishedAt: now.subtract(const Duration(days: 20)),
        ),
        _key(33): const StoreProductDiscovery(bestRank: 1),
        _key(34): const StoreProductDiscovery(bestRank: 0),
      };

      expect(select(templates, category: '인기', discovery: discovery), [
        33,
        32,
        31,
        34,
      ]);
    },
  );

  test(
    'favorites filter popularity without promoting lower ranked favorites',
    () {
      final templates = [_template(41), _template(42), _template(43)];
      final discovery = {
        _key(41): const StoreProductDiscovery(bestRank: 1),
        _key(42): const StoreProductDiscovery(bestRank: 2),
        _key(43): const StoreProductDiscovery(bestRank: 3),
      };

      expect(
        select(
          templates,
          category: '인기',
          favoriteIds: {43},
          discovery: discovery,
        ),
        [41, 42, 43],
      );
      expect(
        select(
          templates,
          category: '인기',
          favoritesOnly: true,
          favoriteIds: {41, 43},
          discovery: discovery,
        ),
        [41, 43],
      );
    },
  );

  test('recommendations exclude unavailable and unlisted premium products', () {
    final templates = [
      _template(51),
      _template(52, premium: true),
      _template(53, category: '여행'),
      _template(54, category: '동아리', premium: true),
      _template(55, category: '여행', premium: true),
      _template(56, category: '동아리'),
    ];
    final products = {
      _key(53): _product(53, 0, active: false),
      _key(54): _product(54, null),
      _key(55): _product(55, 0),
      _key(56): _product(56, 1800),
    };

    expect(
      select(
        templates,
        category: '추천',
        products: products,
        favoriteIds: {52, 53, 54},
        featuredIds: {52, 53, 54},
      ),
      [51, 55, 56],
    );
  });

  test(
    'recommendations retain curation, favorites and server price diversity',
    () {
      final templates = [
        _template(61, premium: true),
        _template(62),
        _template(63),
        _template(64, category: '여행'),
      ];
      final products = {
        _key(61): _product(61, 0),
        _key(62): _product(62, 1800),
        _key(63): _product(63, 0),
      };

      expect(
        select(
          templates,
          category: '추천',
          products: products,
          favoriteIds: {62},
          featuredIds: {63},
        ),
        [62, 64, 63, 61],
      );
    },
  );

  test('common filters run before the bounded recommendation selection', () {
    final templates = [
      for (var id = 70; id < 100; id++)
        _template(id, title: id < 97 ? 'Other' : 'Keep $id'),
    ];

    expect(
      select(
        templates,
        category: '추천',
        price: '무료',
        query: 'keep',
        favoritesOnly: true,
        favoriteIds: {97, 98, 99},
      ),
      [97, 98, 99],
    );
  });

  test(
    'latest order stays stable for ties, future dates and unknown releases',
    () {
      final templates = [
        _template(101),
        _template(102),
        _template(103),
        _template(104),
        _template(105),
        _template(106),
      ];
      final discovery = {
        _key(102): StoreProductDiscovery(
          firstPublishedAt: now.subtract(const Duration(days: 60)),
        ),
        _key(103): StoreProductDiscovery(
          firstPublishedAt: now.add(const Duration(days: 1)),
        ),
        _key(104): StoreProductDiscovery(
          firstPublishedAt: now.subtract(const Duration(days: 30)),
        ),
        _key(105): StoreProductDiscovery(
          firstPublishedAt: now.subtract(const Duration(days: 30)),
        ),
      };

      expect(select(templates, discovery: discovery, favoriteIds: {106}), [
        104,
        105,
        102,
        101,
        103,
        106,
      ]);
      expect(select(templates, category: '인기', discovery: discovery), [
        104,
        105,
        102,
        101,
        103,
        106,
      ]);
      expect(templates.map((template) => template.id), [
        101,
        102,
        103,
        104,
        105,
        106,
      ]);
    },
  );

  test(
    'trimmed case-insensitive search includes title, topic and tags only',
    () {
      final templates = [
        _template(111, title: 'Film Diary'),
        _template(112, category: ' FILM '),
        _template(113, tags: [' Film ']),
        _template(114, title: 'Other'),
      ];

      expect(select(templates, query: '  fIlM  '), [111, 112, 113]);
      expect(select(templates, query: '   '), [111, 112, 113, 114]);
      expect(select(templates, query: 'absent'), isEmpty);
      expect(select([], query: 'film'), isEmpty);
    },
  );
}

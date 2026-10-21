import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/public_template_information.dart';

final _template = PremiumTemplate(
  id: -777777,
  title: '공개 문서 예시',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 99,
  userCount: 0,
  templateJson: jsonEncode({
    'designWidth': 500,
    'designHeight': 500,
    'cover': {
      'layers': [
        {'id': 'cover'},
      ],
    },
    'pages': [
      {
        'layers': [
          {'id': 'inner-1'},
        ],
      },
      {
        'layers': [
          {'id': 'inner-2'},
        ],
      },
    ],
    'variants': {
      'portrait': {
        'designWidth': 375,
        'designHeight': 500,
        'pages': [
          {'layers': []},
        ],
      },
      'landscape': {
        'designWidth': 500,
        'designHeight': 375,
        'pages': [
          {'layers': []},
        ],
      },
    },
  }),
);

PointShopProduct _product({int? price = 1800, bool active = true}) =>
    PointShopProduct(
      productKey: pointShopTemplateKey(_template),
      kind: 'template',
      assetId: 'fixture',
      title: '공개 가격 fixture',
      pointPrice: price,
      isActive: active,
    );

class _PublicCatalogRepository implements PointShopRepository {
  _PublicCatalogRepository(this.load);
  final Future<List<PointShopProduct>> Function(int attempt) load;
  int reads = 0;

  @override
  Future<List<PointShopProduct>> loadCatalog() => load(++reads);
  Never _private() => throw StateError('Public information read private data');
  @override
  String? get currentUserId => _private();
  @override
  Stream<String?> get authChanges => _private();
  @override
  Future<Set<String>> loadOwnedKeys() async => _private();
  @override
  Future<PointShopAccess> getAccess(String key) async => _private();
  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) async =>
      _private();
  @override
  Future<void> saveProduct(PointShopProduct product) async => _private();
}

Widget _app(
  _PublicCatalogRepository repository, {
  double scale = 1,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    pointShopRepositoryProvider.overrideWithValue(repository),
    ownedPointShopKeysProvider.overrideWith(
      (_) => throw StateError('No guest ownership subscription'),
    ),
    pointShopSessionProvider.overrideWith(
      (_) => throw StateError('No guest session subscription'),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: PublicTemplateInformation(template: _template),
      ),
    ),
  ),
);

void main() {
  test('public facts use actual document pages and matching print ratios', () {
    final facts = PublicTemplateFacts.fromTemplate(_template);
    expect(facts.innerPageCount, 2);
    expect(facts.pageLabel, '내지 2쪽');
    expect(facts.designShapes, ['정사각형', '세로형', '가로형']);
    expect(facts.printSizes.map((size) => size.productId), [
      'REDP_200_SOFT',
      'REDP_200X150_SOFT',
      'REDP_250_SOFT',
      'REDP_300_SOFT',
    ]);
    expect(facts.printSizes.any((size) => size.ratio < 1), isFalse);
    expect(PublicTemplateFacts.fromTemplate(_template), same(facts));
  });

  test('unreadable public documents keep unknown facts unconfirmed', () {
    final facts = PublicTemplateFacts.fromTemplate(
      _template.copyWith(templateJson: 'not json', pageCount: 99),
    );
    expect(facts.innerPageCount, isNull);
    expect(facts.pageLabel, '쪽수 확인 필요');
    expect(facts.designShapes, isEmpty);
    expect(facts.printSizes, isEmpty);
  });

  test('public prices follow exact catalog entries, never bundled flags', () {
    final key = pointShopTemplateKey(_template);
    expect(publicCatalogPrice(key, AsyncData([_product()])).label, '1,800P');
    expect(
      publicCatalogPrice(key, AsyncData([_product(price: 0)])).label,
      '무료 (0P)',
    );
    expect(publicCatalogPrice(key, const AsyncData([])).label, '가격 준비 중');
    for (final product in [
      _product(active: false),
      _product(price: null),
      _product(price: -1),
    ]) {
      expect(publicCatalogPrice(key, AsyncData([product])).label, '판매 준비 중');
    }
    expect(
      publicCatalogPrice(
        key,
        AsyncData([_product(), _product(price: 0)]),
      ).label,
      '가격 준비 중',
    );
    expect(publicCatalogPrice(key, const AsyncLoading()).label, '가격 확인 중');
    expect(
      publicCatalogPrice(
        key,
        AsyncError(StateError('offline'), StackTrace.empty),
      ).retry,
      isTrue,
    );
  });

  testWidgets(
    'public information reads only the shared catalog and explains scope',
    (tester) async {
      final repository = _PublicCatalogRepository((_) async => [_product()]);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(repository.reads, 1);
      expect(find.text('1,800P'), findsOneWidget);
      expect(find.text('내지 2쪽 · 표지 별도'), findsOneWidget);
      expect(find.textContaining('다른 앨범에 개별 추가할 권한'), findsOneWidget);
      expect(find.textContaining('인쇄·배송 비용은 별도'), findsOneWidget);
      expect(find.textContaining('세로형은 화면용'), findsOneWidget);
      expect(find.text('구매 완료'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed public prices can be retried without reading an account',
    (tester) async {
      final repository = _PublicCatalogRepository((attempt) async {
        if (attempt == 1) throw Exception('offline');
        return [_product()];
      });
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text('가격을 확인하지 못했어요'), findsOneWidget);
      expect(find.text('무료 (0P)'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repository.reads, 1);
      expect(find.text('가격을 확인하지 못했어요'), findsOneWidget);
      expect(find.text('가격 확인 중'), findsNothing);
      await tester.tap(
        find.byKey(
          ValueKey('public-price-retry-${pointShopTemplateKey(_template)}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
      expect(find.text('1,800P'), findsOneWidget);
      expect(find.text('가격 다시 확인'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public catalog timeout has a recovery action', (tester) async {
    final pending = Completer<List<PointShopProduct>>();
    final repository = _PublicCatalogRepository(
      (attempt) =>
          attempt == 1 ? pending.future : Future.value([_product(price: 0)]),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pump();
    expect(find.text('가격 확인 중'), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    expect(find.text('가격을 확인하지 못했어요'), findsOneWidget);
    await tester.tap(find.text('가격 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('무료 (0P)'), findsOneWidget);
    pending.complete([_product(price: 9999)]);
    await tester.pumpAndSettle();
    expect(find.text('9,999P'), findsNothing);
    expect(find.text('무료 (0P)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    testWidgets('public facts and retry fit large text at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PublicCatalogRepository(
        (_) async => throw StateError('offline'),
      );
      await tester.pumpWidget(_app(repository, scale: 2.4, dark: true));
      await tester.pumpAndSettle();
      final retry = find.text('가격 다시 확인');
      await tester.ensureVisible(retry);
      expect(retry.hitTestable(), findsOneWidget);
      final scope = find.textContaining('인쇄·배송 비용은 별도');
      await tester.ensureVisible(scope);
      await tester.pumpAndSettle();
      expect(scope, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

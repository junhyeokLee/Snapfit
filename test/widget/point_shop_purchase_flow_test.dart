import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';

class _Shop extends PointShopRepository {
  String? user = 'alice';
  int balance = 300, price = 100, charges = 0, reads = 0;
  bool owned = false, free = false, available = true;
  Object? readFailure, purchaseFailure;
  Completer<void>? waitForRead;
  final pricesSent = <int>[];

  @override
  String? get currentUserId => user;
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<List<PointShopProduct>> loadCatalog() async => [];
  @override
  Future<Set<String>> loadOwnedKeys() async =>
      owned ? {'sticker:studioCottonRag'} : {};
  @override
  Future<void> saveProduct(PointShopProduct product) async {}

  @override
  Future<PointShopAccess> getAccess(String key) async {
    reads++;
    await waitForRead?.future;
    if (readFailure != null) throw readFailure!;
    return PointShopAccess(
      productKey: key,
      title: '수제지 조각',
      pointPrice: price,
      available: available,
      isFree: free,
      owned: owned,
      remainingBalance: balance,
    );
  }

  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) async {
    pricesSent.add(expectedPrice);
    if (purchaseFailure != null) throw purchaseFailure!;
    final alreadyOwned = owned;
    if (!alreadyOwned) {
      charges++;
      balance -= price;
      owned = true;
    }
    return PointShopPurchase(
      productKey: key,
      owned: true,
      isFree: false,
      chargedPoints: alreadyOwned ? 0 : price,
      remainingBalance: balance,
      alreadyOwned: alreadyOwned,
    );
  }
}

class _Harness extends ConsumerWidget {
  const _Harness(this.results);
  final List<bool> results;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          results.add(
            await ensurePointShopAccess(
              context,
              ref,
              productKey: 'sticker:studioCottonRag',
              title: '수제지 조각',
            ),
          );
        },
        child: const Text('선택'),
      ),
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  _Shop shop,
  List<bool> results, {
  PointShopTopUp? topUp,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pointShopRepositoryProvider.overrideWithValue(shop),
        if (topUp != null) pointShopTopUpProvider.overrideWithValue(topUp),
      ],
      child: MaterialApp(home: _Harness(results)),
    ),
  );
  await tester.tap(find.text('선택'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('free guest and previously owned content apply without a debit', (
    tester,
  ) async {
    final results = <bool>[];
    final shop = _Shop()
      ..user = null
      ..free = true;
    await _mount(tester, shop, results);
    expect(results, [true]);
    expect(shop.charges, 0);
    shop.user = 'alice';
    shop.free = false;
    shop.owned = true;
    shop.available = false;
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(results, [true, true]);
    expect(shop.pricesSent, isEmpty);
  });

  testWidgets(
    'purchase requires confirmation and reusing ownership never charges again',
    (tester) async {
      final shop = _Shop(), results = <bool>[];
      await _mount(tester, shop, results);
      expect(find.text('구매 가격 100P'), findsOneWidget);
      expect(shop.charges, 0);
      await tester.tap(find.text('100P로 구매'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(shop.charges, 1);
      expect(shop.balance, 200);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      expect(results, [true, true]);
      expect(shop.charges, 1);
    },
  );

  testWidgets('cancel leaves points and selected asset unchanged', (
    tester,
  ) async {
    final shop = _Shop(), results = <bool>[];
    await _mount(tester, shop, results);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(shop.balance, 300);
    expect(shop.charges, 0);
  });

  testWidgets(
    'recharge return reloads both balance and price and asks again before debit',
    (tester) async {
      final shop = _Shop()..balance = 20, results = <bool>[];
      await _mount(
        tester,
        shop,
        results,
        topUp: (_) async {
          shop.balance = 300;
          shop.price = 120;
        },
      );
      expect(find.text('포인트가 부족해요'), findsOneWidget);
      await tester.tap(find.text('포인트 충전'));
      await tester.pumpAndSettle();
      expect(shop.reads, 2);
      expect(shop.charges, 0);
      expect(find.text('구매 가격 120P'), findsOneWidget);
      await tester.tap(find.text('120P로 구매'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(shop.pricesSent, [120]);
      expect(shop.balance, 180);
    },
  );

  testWidgets('changed price does not silently authorize a different charge', (
    tester,
  ) async {
    final shop = _Shop()
      ..purchaseFailure = const PointShopException('point_shop_price_changed');
    final results = <bool>[];
    await _mount(tester, shop, results);
    await tester.tap(find.text('100P로 구매'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(shop.charges, 0);
    expect(find.text('가격이 변경됐어요. 새 가격을 확인해 주세요.'), findsOneWidget);
  });

  testWidgets(
    'account change while confirming cannot charge the next account',
    (tester) async {
      final shop = _Shop(), results = <bool>[];
      await _mount(tester, shop, results);
      shop.user = 'bob';
      await tester.tap(find.text('100P로 구매'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(shop.pricesSent, isEmpty);
    },
  );

  testWidgets('offline and unpriced declared products never unlock', (
    tester,
  ) async {
    final shop = _Shop()..readFailure = Exception('offline'),
        results = <bool>[];
    await _mount(tester, shop, results);
    expect(results, [false]);
    expect(shop.charges, 0);
    shop.readFailure = null;
    shop.available = false;
    await tester.tap(find.text('선택'));
    await tester.pumpAndSettle();
    expect(results, [false, false]);
    expect(shop.pricesSent, isEmpty);
  });

  testWidgets(
    'repeated selection during lookup opens only one purchase request',
    (tester) async {
      final shop = _Shop()..waitForRead = Completer<void>(), results = <bool>[];
      await _mount(tester, shop, results);
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      expect(shop.reads, 1);
      expect(results, [false]);
      shop.waitForRead!.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('100P로 구매'));
      await tester.pumpAndSettle();
      expect(shop.charges, 1);
      expect(results, [false, true]);
    },
  );
}

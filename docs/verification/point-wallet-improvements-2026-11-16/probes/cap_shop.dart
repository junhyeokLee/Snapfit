import 'dart:async';

import 'file:///tmp/snapfit-point-improvements-20261116/audit_support.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_purchase_fakes.dart'
    as native;

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
  final store = native.FakeStore();
  addTearDown(store.controller.close);
  final service = native.fakePointPurchaseService(store: store);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pointShopRepositoryProvider.overrideWithValue(shop),
        myPointBalanceProvider.overrideWith((_) async => shop.balance),
        pointPurchaseServiceProvider.overrideWith((ref) {
          ref.onDispose(service.dispose);
          return service;
        }),
        if (topUp != null) pointShopTopUpProvider.overrideWithValue(topUp),
      ],
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        builder: (_, child) => auditFrame(child!),
        home: _Harness(results),
      ),
    ),
  );
  await tester.tap(find.text('선택'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(auditFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'capture improved price refresh preserves the original purchase and asks for the new price',
    (tester) async {
      auditViewport(tester);
      final shop = _Shop()
        ..purchaseFailure = const PointShopException(
          'point_shop_price_changed',
        );
      final results = <bool>[];
      await _mount(tester, shop, results);
      await tester.tap(find.text('100P로 구매'));
      await tester.pumpAndSettle();
      expect(shop.charges, 0);
      expect(results, isEmpty);
      final refresh = find.widgetWithText(SnackBarAction, '새 가격 확인');
      expect(refresh, findsOneWidget);
      await auditCapture(tester, '12-point-price-refresh-action-390-light');
      shop.price = 120;
      shop.purchaseFailure = null;
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(find.text('120P로 구매'), findsOneWidget);
      expect(shop.charges, 0);
      expect(results, isEmpty);
      await auditCapture(tester, '13-point-new-price-confirm-390-light');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

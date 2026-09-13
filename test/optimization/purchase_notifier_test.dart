import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_purchase_notifier.dart';

class Shop extends PointShopRepository {
  String? user = 'alice';
  int reads = 0, charges = 0, balance = 0;
  Completer<PointShopAccess>? pending;
  Completer<PointShopPurchase>? pendingPurchase;
  String? responseKey;
  @override
  String? get currentUserId => user;
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<List<PointShopProduct>> loadCatalog() async => [];
  @override
  Future<Set<String>> loadOwnedKeys() async => {};
  @override
  Future<void> saveProduct(PointShopProduct product) async {}
  @override
  Future<PointShopAccess> getAccess(String key) async {
    reads++;
    if (pending != null) return pending!.future;
    return PointShopAccess(
      productKey: responseKey ?? key,
      pointPrice: 100,
      available: true,
      isFree: false,
      owned: false,
      remainingBalance: balance,
    );
  }

  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) async {
    expect(expectedPrice, 100);
    charges++;
    if (pendingPurchase != null) return pendingPurchase!.future;
    return PointShopPurchase(
      productKey: key,
      owned: true,
      isFree: false,
      chargedPoints: 100,
      remainingBalance: 0,
      alreadyOwned: false,
    );
  }
}

void main() {
  test(
    'purchase timeout and recharge error release lock; invalid key fails closed',
    () async {
      final shop = Shop()..balance = 100;
      final c = ProviderContainer(
        overrides: [
          pointShopRepositoryProvider.overrideWithValue(shop),
          pointShopTimeoutsProvider.overrideWithValue((
            access: const Duration(seconds: 12),
            purchase: Duration.zero,
          )),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(pointShopPurchaseProvider.notifier);
      Future<PurchaseOutcome> buy() => vm.request(
        productKey: 'a',
        isActive: () => true,
        confirm: (_) async => PurchaseAction.buy,
        topUp: () async {},
      );
      shop.responseKey = 'other';
      await expectLater(buy(), throwsA(isA<PointShopException>()));
      expect(shop.charges, 0);
      shop.responseKey = null;
      shop.pendingPurchase = Completer<PointShopPurchase>();
      await expectLater(buy(), throwsA(isA<TimeoutException>()));
      expect(c.read(pointShopPurchaseProvider), false);
      await expectLater(
        vm.request(
          productKey: 'a',
          isActive: () => true,
          confirm: (_) async => PurchaseAction.topUp,
          topUp: () async {
            throw StateError('route failed');
          },
        ),
        throwsStateError,
      );
      expect(c.read(pointShopPurchaseProvider), false);
      final reads = shop.reads;
      final cancelled = await vm.request(
        productKey: 'a',
        isActive: () => false,
        confirm: (_) async => PurchaseAction.buy,
        topUp: () async {},
      );
      expect(cancelled.granted, false);
      expect(shop.reads, reads);
    },
  );
  test(
    'notifier rechecks after topup, rejects duplicate taps and honors cancellation',
    () async {
      final shop = Shop();
      final c = ProviderContainer(
        overrides: [pointShopRepositoryProvider.overrideWithValue(shop)],
      );
      addTearDown(c.dispose);
      final vm = c.read(pointShopPurchaseProvider.notifier);
      var prompts = 0;
      final result = await vm.request(
        productKey: 'a',
        isActive: () => true,
        confirm: (access) async {
          prompts++;
          expect(
            (await vm.request(
              productKey: 'b',
              isActive: () => true,
              confirm: (_) async => null,
              topUp: () async {},
            )).granted,
            false,
          );
          return access.remainingBalance == 0
              ? PurchaseAction.topUp
              : PurchaseAction.buy;
        },
        topUp: () async {
          shop.balance = 100;
        },
      );
      expect(result.granted, true);
      expect(shop.reads, 2);
      expect(shop.charges, 1);
      expect(prompts, 2);
      expect(c.read(pointShopPurchaseProvider), false);
      final cancel = await vm.request(
        productKey: 'a',
        isActive: () => true,
        confirm: (_) async => null,
        topUp: () async {},
      );
      expect(cancel.granted, false);
      expect(shop.charges, 1);
    },
  );
  test(
    'account change during confirmation never purchases; timeout releases busy',
    () async {
      final shop = Shop()..balance = 100;
      final c = ProviderContainer(
        overrides: [
          pointShopRepositoryProvider.overrideWithValue(shop),
          pointShopTimeoutsProvider.overrideWithValue((
            access: Duration.zero,
            purchase: Duration.zero,
          )),
        ],
      );
      addTearDown(c.dispose);
      final vm = c.read(pointShopPurchaseProvider.notifier);
      await expectLater(
        vm.request(
          productKey: 'a',
          isActive: () => true,
          confirm: (_) async {
            shop.user = 'bob';
            return PurchaseAction.buy;
          },
          topUp: () async {},
        ),
        throwsA(isA<PointShopException>()),
      );
      expect(shop.charges, 0);
      expect(c.read(pointShopPurchaseProvider), false);
      shop.pending = Completer<PointShopAccess>();
      await expectLater(
        vm.request(
          productKey: 'a',
          isActive: () => true,
          confirm: (_) async => PurchaseAction.buy,
          topUp: () async {},
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(c.read(pointShopPurchaseProvider), false);
    },
  );
}

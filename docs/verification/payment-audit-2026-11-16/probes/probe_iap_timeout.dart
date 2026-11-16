// Audit-only reproduction: fake store calls, no provider SDK or network.
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/support/point_purchase_fakes.dart';

class _RefreshFailureStore extends FakeStore {
  bool failRefresh = false;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) {
    if (failRefresh) throw StateError('store_product_query_failed');
    return super.products(ids);
  }
}

void main() {
  test('audit: pending store approval unlocks another native buy after watchdog', () {
    fakeAsync((clock) {
      final start = DateTime.utc(2026, 11, 16);
      final store = FakeStore();
      var verifies = 0;
      final service = PointPurchaseService(
        store: store,
        storage: MemoryReceipts(),
        currentUserId: () => 'owner',
        ensureServerAvailable: () async {},
        now: () => start.add(clock.elapsed),
        verify: (record) async {
          verifies++;
          return StorePointPurchaseResult(productId: record.productId, grantedPoints: 2500, remainingBalance: 2500);
        },
        onBalanceChanged: () {},
      )..start();
      clock.flushMicrotasks();
      unawaited(service.buy(product));
      clock.flushMicrotasks();
      expect(store.buyCalls, 1);
      store.controller.add([purchase(status: PurchaseStatus.pending, nativeOwner: 'owner', transactionTime: start.millisecondsSinceEpoch)]);
      clock.flushMicrotasks();
      expect(service.busy, isTrue);
      clock.elapse(const Duration(minutes: 2));
      clock.flushMicrotasks();
      expect(service.busy, isFalse);
      expect(service.message, contains('스토어 승인을 기다리고'));
      // No terminal store event or receipt verification arrived, yet a second
      // store buy is invoked rather than a status-recovery-only action.
      unawaited(service.buy(product));
      clock.flushMicrotasks();
      expect(store.buyCalls, 2);
      expect(verifies, 0);
      service.dispose();
      unawaited(store.controller.close());
      clock.flushMicrotasks();
    });
  });

  test('audit: unresolved native buy future allows another buy after thirty seconds', () {
    fakeAsync((clock) {
      final start = DateTime.utc(2026, 11, 16);
      final store = FakeStore();
      final firstNativeResult = Completer<bool>();
      store.buyResponse = (_, _) => store.buyCalls == 1 ? firstNativeResult.future : Future.value(true);
      final service = PointPurchaseService(
        store: store,
        storage: MemoryReceipts(),
        currentUserId: () => 'owner',
        ensureServerAvailable: () async {},
        now: () => start.add(clock.elapsed),
        verify: (record) async => StorePointPurchaseResult(productId: record.productId, grantedPoints: 2500, remainingBalance: 2500),
        onBalanceChanged: () {},
      )..start();
      clock.flushMicrotasks();
      unawaited(service.buy(product));
      clock.flushMicrotasks();
      expect(store.buyCalls, 1);
      expect(firstNativeResult.isCompleted, isFalse);
      clock.elapse(const Duration(seconds: 31));
      clock.flushMicrotasks();
      expect(service.busy, isFalse);
      expect(service.message, contains('시작하지 못했어요'));
      expect(firstNativeResult.isCompleted, isFalse);
      unawaited(service.buy(product));
      clock.flushMicrotasks();
      expect(store.buyCalls, 2);
      firstNativeResult.complete(true);
      clock.flushMicrotasks();
      service.dispose();
      unawaited(store.controller.close());
      clock.flushMicrotasks();
    });
  });
  test('audit: failed catalog refresh preserves old enabled product and allows buy', () {
    fakeAsync((clock) {
      final store = _RefreshFailureStore();
      final service = PointPurchaseService(
        store: store,
        storage: MemoryReceipts(),
        currentUserId: () => 'owner',
        ensureServerAvailable: () async {},
        verify: (record) async => StorePointPurchaseResult(productId: record.productId, grantedPoints: 2500, remainingBalance: 2500),
        onBalanceChanged: () {},
      )..start();
      clock.flushMicrotasks();
      expect(service.products.single, same(product));
      store.failRefresh = true;
      unawaited(service.loadProducts());
      clock.flushMicrotasks();
      expect(service.loadingProducts, isFalse);
      expect(service.available, isTrue);
      expect(service.message, contains('충전 상품을 준비'));
      expect(service.products.single, same(product));
      unawaited(service.buy(product));
      clock.flushMicrotasks();
      expect(store.buyCalls, 1);
      service.dispose();
      unawaited(store.controller.close());
      clock.flushMicrotasks();
    });
  });

}

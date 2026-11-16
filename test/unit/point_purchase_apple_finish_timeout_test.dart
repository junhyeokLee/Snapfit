import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';

import '../support/point_purchase_fakes.dart';

class _DelayedAppleFinish extends FakeStore {
  final finishing = Completer<void>();
  int appleFinishCalls = 0, appleFinishReturns = 0;

  @override
  Future<void> finish(
    PendingPointPurchase record,
    PurchaseDetails? native,
  ) async {
    if (native is AppStorePurchaseDetails &&
        (native.status == PurchaseStatus.canceled ||
            native.status == PurchaseStatus.error)) {
      appleFinishCalls++;
      await finishing.future;
      appleFinishReturns++;
      return;
    }
    await super.finish(record, native);
  }
}

AppStorePurchaseDetails _failedApple(
  PurchaseStatus status,
  DateTime transactionDate,
) => AppStorePurchaseDetails(
  productID: sku,
  purchaseID: 'failed-sk1-transaction',
  transactionDate: '${transactionDate.millisecondsSinceEpoch}',
  status: status,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'app_store',
  ),
  skPaymentTransaction: SKPaymentTransactionWrapper(
    payment: const SKPaymentWrapper(productIdentifier: sku, quantity: 1),
    transactionState: SKPaymentTransactionStateWrapper.failed,
    transactionIdentifier: 'failed-sk1-transaction',
  ),
);

void main() {
  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    test(
      'SK1 $status finish timeout releases processing and late completion cannot end a new checkout',
      () {
        fakeAsync((clock) {
          final start = DateTime.utc(2026, 10, 29, 12);
          final store = _DelayedAppleFinish();
          final storage = MemoryReceipts();
          var verifies = 0;
          final service = PointPurchaseService(
            store: store,
            storage: storage,
            currentUserId: () => 'owner',
            ensureServerAvailable: () async {},
            now: () => start.add(clock.elapsed),
            verify: (receipt) async {
              verifies++;
              return StorePointPurchaseResult(
                productId: receipt.productId,
                grantedPoints: 2500,
                remainingBalance: 2500,
              );
            },
            onBalanceChanged: () {},
          )..start();
          clock.flushMicrotasks();
          final failed = _failedApple(status, start);
          expect(
            failed.pendingCompletePurchase,
            isTrue,
            reason:
                'Pinned StoreKit 1 requires completing failed/canceled transactions.',
          );
          store.controller.add([failed]);
          clock.flushMicrotasks();
          expect(store.appleFinishCalls, 1);
          expect(service.busy, isTrue);
          clock.elapse(const Duration(seconds: 30));
          clock.flushMicrotasks();
          expect(service.busy, isFalse);
          expect(verifies, 0);
          expect(storage.records, isEmpty);
          unawaited(service.buy(product));
          clock.flushMicrotasks();
          expect(service.busy, isTrue);
          final pendingMessage = service.message;
          store.finishing.complete();
          clock.flushMicrotasks();
          expect(store.appleFinishReturns, 1);
          expect(service.busy, isTrue);
          expect(service.message, pendingMessage);
          store.controller.add([
            purchase(
              token: 'new-checkout',
              nativeOwner: 'owner',
              transactionTime: start.add(clock.elapsed).millisecondsSinceEpoch,
            ),
          ]);
          clock.flushMicrotasks();
          expect(service.busy, isFalse);
          expect(verifies, 1);
          expect(store.finished, ['google_play:new-checkout']);
          service.dispose();
          unawaited(store.controller.close());
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'old SK1 $status timeout keeps a delayed newer checkout fenced until confirmation',
      () {
        fakeAsync((clock) {
          final start = DateTime.utc(2026, 10, 29, 12);
          final store = _DelayedAppleFinish();
          var verifies = 0;
          final service = PointPurchaseService(
            store: store,
            storage: MemoryReceipts(),
            currentUserId: () => 'owner',
            ensureServerAvailable: () async {},
            now: () => start.add(clock.elapsed),
            verify: (receipt) async {
              verifies++;
              return StorePointPurchaseResult(
                productId: receipt.productId,
                grantedPoints: 2500,
                remainingBalance: 2500,
              );
            },
            onBalanceChanged: () {},
          )..start();
          clock.flushMicrotasks();
          unawaited(service.buy(product));
          clock.flushMicrotasks();
          store.controller.add([
            _failedApple(status, start.subtract(const Duration(days: 1))),
          ]);
          clock.flushMicrotasks();
          clock.elapse(const Duration(seconds: 30));
          clock.flushMicrotasks();
          expect(service.busy, isTrue);
          unawaited(service.buy(product));
          clock.flushMicrotasks();
          expect(store.buyCalls, 1);
          store.finishing.complete();
          clock.flushMicrotasks();
          expect(service.busy, isTrue);
          expect(verifies, 0);
          clock.elapse(const Duration(seconds: 90));
          clock.flushMicrotasks();
          expect(
            service.busy,
            isFalse,
            reason:
                'The old SDK finish must no longer keep receipt processing busy; the delayed checkout still fences a new charge.',
          );
          unawaited(service.buy(product));
          clock.flushMicrotasks();
          expect(store.buyCalls, 1);
          expect(service.verificationDelayed, isTrue);
          expect(service.canStartPurchase, isFalse);
          store.controller.add([
            purchase(
              token: 'confirmed-after-watchdog',
              nativeOwner: 'owner',
              transactionTime: start.add(clock.elapsed).millisecondsSinceEpoch,
            ),
          ]);
          clock.flushMicrotasks();
          expect(service.verificationDelayed, isFalse);
          expect(service.canStartPurchase, isTrue);
          service.dispose();
          unawaited(store.controller.close());
          clock.flushMicrotasks();
        });
      },
    );
  }
}

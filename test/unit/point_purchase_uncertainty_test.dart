import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_checkout.dart';

import '../support/point_purchase_fakes.dart';

class _CatalogStore extends FakeStore {
  bool failCatalog = false;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    if (failCatalog) throw StateError('store_product_query_failed');
    return super.products(ids);
  }
}

class _GatedReceipts extends MemoryReceipts {
  final gate = Completer<List<PendingPointCheckout>>();
  @override
  Future<List<PendingPointCheckout>> readCheckouts() => gate.future;
}

class _RemovalFailingReceipts extends MemoryReceipts {
  bool failRemoval = true;
  @override
  Future<void> writeCheckouts(List<PendingPointCheckout> value) async {
    if (value.isEmpty && failRemoval)
      throw StateError('checkout_remove_failed');
    await super.writeCheckouts(value);
  }
}

class _Fixture {
  _Fixture(this.clock, {MemoryReceipts? receipts})
    : storage = receipts ?? MemoryReceipts() {
    restart();
  }
  final FakeAsync clock;
  final start = DateTime.utc(2026, 11, 16);
  final store = _CatalogStore();
  final MemoryReceipts storage;
  final credited = <String>{};
  final services = <PointPurchaseService>[];
  late PointPurchaseService service;
  String owner = 'owner';
  bool failVerify = false, rejectForeignReceipt = false;
  String rejectionCode = 'purchase_account_mismatch';

  void restart() {
    if (services.isNotEmpty) service.dispose();
    service = PointPurchaseService(
      store: store,
      storage: storage,
      currentUserId: () => owner,
      ensureServerAvailable: () async {},
      now: () => start.add(clock.elapsed),
      verify: (record) async {
        if (failVerify) throw StateError('network unavailable');
        if (rejectForeignReceipt &&
            record.serverData == 'foreign-replay' &&
            owner != 'foreign-owner') {
          throw PointPurchaseVerificationException(
            rejectionCode,
            retryable: false,
          );
        }
        final alreadyGranted = !credited.add(record.key);
        return StorePointPurchaseResult(
          productId: record.productId,
          grantedPoints: alreadyGranted ? 0 : 2500,
          remainingBalance: credited.length * 2500,
          alreadyGranted: alreadyGranted,
        );
      },
      onBalanceChanged: () {},
    )..start();
    services.add(service);
    clock.flushMicrotasks();
  }

  void buy() {
    unawaited(service.buy(product));
    clock.flushMicrotasks();
  }

  void emit({
    PurchaseStatus status = PurchaseStatus.purchased,
    String token = 'current',
  }) {
    store.controller.add([
      purchase(
        status: status,
        token: token,
        nativeOwner: owner,
        transactionTime: start.add(clock.elapsed).millisecondsSinceEpoch,
      ),
    ]);
    clock.flushMicrotasks();
  }

  void close() {
    service.dispose();
    unawaited(store.controller.close());
    clock.flushMicrotasks();
  }
}

void main() {
  test(
    'a native start timeout blocks a second request until its late result is known',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        final first = Completer<bool>();
        f.store.buyResponse = (_, _) => first.future;
        f.buy();
        clock.elapse(const Duration(seconds: 31));
        clock.flushMicrotasks();
        expect(f.service.busy, isFalse);
        f.buy();
        expect(f.store.buyCalls, 1);
        expect(f.service.message, contains('결제 상태'));
        // A definitive failure to open the native window is safe to release.
        first.complete(false);
        clock.flushMicrotasks();
        f.store.buyResponse = (_, _) async => true;
        f.buy();
        expect(f.store.buyCalls, 2);
        f.close();
      });
    },
  );

  test(
    'pending approval watchdog and an empty restore never authorize another charge',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        f.emit(status: PurchaseStatus.pending);
        clock.elapse(const Duration(minutes: 2));
        clock.flushMicrotasks();
        expect(f.service.busy, isFalse);
        unawaited(f.service.recover());
        clock.flushMicrotasks();
        f.buy();
        expect(f.store.buyCalls, 1);
        expect(f.service.message, contains('결제 상태'));
        f.emit(status: PurchaseStatus.canceled);
        f.buy();
        expect(f.store.buyCalls, 2);
        f.close();
      });
    },
  );

  test(
    'restart preserves a receiptless unresolved checkout until a matching terminal event',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        clock.elapse(const Duration(minutes: 2));
        clock.flushMicrotasks();
        f.restart();
        f.buy();
        expect(f.store.buyCalls, 1);
        unawaited(f.service.recover());
        clock.flushMicrotasks();
        f.buy();
        expect(f.store.buyCalls, 1);
        f.emit();
        f.buy();
        expect(f.store.buyCalls, 2);
        f.close();
      });
    },
  );

  test(
    'verification failure retains the checkout fence and recovery unlocks only its own receipt',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        f.failVerify = true;
        f.emit();
        expect(f.storage.records, hasLength(1));
        expect(f.service.busy, isFalse);
        f.buy();
        expect(f.store.buyCalls, 1);
        f.failVerify = false;
        unawaited(f.service.recover());
        clock.flushMicrotasks();
        expect(f.storage.records, isEmpty);
        f.buy();
        expect(f.store.buyCalls, 2);
        f.close();
      });
    },
  );

  test(
    'a credited receipt with failed store finish stays fenced across restart and clears on replay',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        f.store.failFinish = true;
        f.emit();
        expect(f.credited, hasLength(1));
        f.restart();
        f.buy();
        expect(f.store.buyCalls, 1);
        f.store.failFinish = false;
        unawaited(f.service.recover());
        clock.flushMicrotasks();
        expect(f.credited, hasLength(1));
        expect(f.storage.records, isEmpty);
        f.buy();
        expect(f.store.buyCalls, 2);
        f.close();
      });
    },
  );

  test(
    'a previous account checkout never fences another account or erases its own marker',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        clock.elapse(const Duration(minutes: 2));
        clock.flushMicrotasks();
        f.owner = 'another-owner';
        f.buy();
        expect(f.store.buyCalls, 2);
        f.emit(status: PurchaseStatus.canceled, token: 'other-cancel');
        f.owner = 'owner';
        f.buy();
        expect(f.store.buyCalls, 2);
        f.emit(status: PurchaseStatus.canceled);
        f.buy();
        expect(f.store.buyCalls, 3);
        f.close();
      });
    },
  );

  test(
    'a failed catalog refresh blocks cached product checkout until a fresh query succeeds',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.store.failCatalog = true;
        unawaited(f.service.loadProducts());
        clock.flushMicrotasks();
        f.buy();
        expect(f.store.buyCalls, 0);
        f.store.failCatalog = false;
        unawaited(f.service.loadProducts());
        clock.flushMicrotasks();
        f.buy();
        expect(f.store.buyCalls, 1);
        f.close();
      });
    },
  );
  test(
    'checkout marker persistence failure prevents crossing into the store SDK',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.storage.failWriteCheckouts = true;
        f.buy();
        expect(f.store.buyCalls, 0);
        expect(f.storage.checkouts, isEmpty);
        f.storage.failWriteCheckouts = false;
        f.buy();
        expect(f.store.buyCalls, 1);
        f.close();
      });
    },
  );

  test(
    'startup waits for existing checkout markers before permitting a new charge',
    () {
      fakeAsync((clock) {
        final receipts = _GatedReceipts();
        final f = _Fixture(clock, receipts: receipts);
        f.buy();
        expect(f.store.buyCalls, 0);
        receipts.gate.complete([
          PendingPointCheckout(
            ownerId: 'owner',
            productId: sku,
            startedAt: f.start,
          ),
        ]);
        clock.flushMicrotasks();
        expect(f.service.verificationDelayed, isTrue);
        f.buy();
        expect(f.store.buyCalls, 0);
        f.emit(status: PurchaseStatus.canceled);
        f.buy();
        expect(f.store.buyCalls, 1);
        f.close();
      });
    },
  );

  test('checkout marker read failure fails closed and a retry can recover', () {
    fakeAsync((clock) {
      final receipts = MemoryReceipts()..failReadCheckouts = true;
      final f = _Fixture(clock, receipts: receipts);
      expect(f.service.canStartPurchase, isFalse);
      f.buy();
      expect(f.store.buyCalls, 0);
      receipts.failReadCheckouts = false;
      unawaited(f.service.loadProducts());
      clock.flushMicrotasks();
      f.buy();
      expect(f.store.buyCalls, 1);
      f.close();
    });
  });

  test(
    'a paid receipt remains recoverable when deleting its checkout marker fails',
    () {
      fakeAsync((clock) {
        final receipts = _RemovalFailingReceipts();
        final f = _Fixture(clock, receipts: receipts);
        f.buy();
        f.emit();
        expect(f.credited, hasLength(1));
        expect(f.storage.records, hasLength(1));
        expect(f.storage.checkouts, hasLength(1));
        expect(f.service.verificationDelayed, isTrue);
        f.restart();
        f.buy();
        expect(f.store.buyCalls, 1);
        receipts.failRemoval = false;
        unawaited(f.service.recover());
        clock.flushMicrotasks();
        expect(f.credited, hasLength(1));
        expect(f.storage.records, isEmpty);
        expect(f.storage.checkouts, isEmpty);
        expect(f.service.canStartPurchase, isTrue);
        f.close();
      });
    },
  );

  test(
    'a late previous account native false result cannot remove a newer account marker',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        final first = Completer<bool>();
        f.store.buyResponse = (_, _) =>
            f.store.buyCalls == 1 ? first.future : Future.value(true);
        f.buy();
        clock.elapse(const Duration(seconds: 31));
        clock.flushMicrotasks();
        f.owner = 'another-owner';
        f.buy();
        expect(f.store.buyCalls, 2);
        first.complete(false);
        clock.flushMicrotasks();
        expect(f.storage.checkouts.map((row) => row.ownerId), [
          'another-owner',
        ]);
        expect(f.service.busy, isTrue);
        f.buy();
        expect(f.store.buyCalls, 2);
        f.emit(status: PurchaseStatus.canceled);
        expect(f.service.canStartPurchase, isTrue);
        f.close();
      });
    },
  );

  test(
    'checkout markers round trip without turning a legacy receipt into a checkout',
    () {
      final original = PendingPointCheckout(
        ownerId: 'owner',
        productId: sku,
        startedAt: DateTime.utc(2026, 11, 16),
        existingReceiptKeys: {'old-receipt'},
        receiptKey: 'current-receipt',
        receiptVerified: true,
      );
      final copy = PendingPointCheckout.fromJson(original.toJson());
      expect(copy.ownerId, 'owner');
      expect(copy.productId, sku);
      expect(copy.startedAt, original.startedAt);
      expect(copy.existingReceiptKeys, {'old-receipt'});
      expect(copy.receiptKey, 'current-receipt');
      expect(copy.receiptVerified, isTrue);
      final legacy = original.toJson()..remove('receiptVerified');
      expect(PendingPointCheckout.fromJson(legacy).receiptVerified, isFalse);
      expect(
        () => PendingPointCheckout.fromJson({'ownerId': 'owner'}),
        throwsFormatException,
      );
    },
  );

  for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
    for (final secondCheckout in [false, true]) {
      test(
        'an explicit previous owner $status clears only its marker secondCheckout=$secondCheckout',
        () {
          fakeAsync((clock) {
            final f = _Fixture(clock);
            f.buy();
            clock.elapse(const Duration(minutes: 2));
            clock.flushMicrotasks();
            f.owner = 'another-owner';
            if (secondCheckout) f.buy();
            final calls = f.store.buyCalls;
            final message = f.service.message;
            f.store.controller.add([
              purchase(
                status: status,
                token: 'previous-owner-terminal',
                nativeOwner: 'owner',
                transactionTime: f.start
                    .add(clock.elapsed)
                    .millisecondsSinceEpoch,
              ),
            ]);
            clock.flushMicrotasks();
            expect(f.store.buyCalls, calls);
            expect(
              f.storage.checkouts.map((row) => row.ownerId),
              secondCheckout ? ['another-owner'] : isEmpty,
            );
            expect(f.service.message, message);
            if (secondCheckout) {
              expect(f.service.busy, isTrue);
              f.emit(
                status: PurchaseStatus.canceled,
                token: 'second-owner-terminal',
              );
            }
            f.owner = 'owner';
            f.buy();
            expect(f.store.buyCalls, calls + 1);
            f.close();
          });
        },
      );
    }
  }
  for (final code in [
    'purchase_account_mismatch',
    'purchase_ownership_invalid',
  ]) {
    for (final canceled in [false, true]) {
      test(
        'server rejected provisional ownership $code cannot pin the real checkout canceled=$canceled',
        () {
          fakeAsync((clock) {
            final f = _Fixture(clock)
              ..rejectForeignReceipt = true
              ..rejectionCode = code;
            f.buy();
            f.store.controller.add([
              purchase(
                token: 'foreign-replay',
                transactionTime: f.start.millisecondsSinceEpoch,
              ),
            ]);
            clock.flushMicrotasks();
            expect(f.storage.records.single.ownerId, isEmpty);
            expect(f.storage.checkouts.single.receiptKey, isNull);
            expect(
              f.storage.checkouts.single.existingReceiptKeys,
              contains('google_play:foreign-replay'),
            );
            expect(f.service.busy, isTrue);
            f.buy();
            expect(f.store.buyCalls, 1);
            f.emit(
              status: canceled
                  ? PurchaseStatus.canceled
                  : PurchaseStatus.purchased,
              token: 'actual-current',
            );
            expect(f.storage.checkouts, isEmpty);
            expect(f.service.canStartPurchase, isTrue);
            expect(f.storage.records.single.serverData, 'foreign-replay');
            expect(
              f.store.finished,
              canceled ? isEmpty : ['google_play:actual-current'],
            );
            f.owner = 'foreign-owner';
            unawaited(f.service.recover());
            clock.flushMicrotasks();
            expect(f.storage.records, isEmpty);
            expect(f.store.finished, contains('google_play:foreign-replay'));
            f.close();
          });
        },
      );
    }
  }
}

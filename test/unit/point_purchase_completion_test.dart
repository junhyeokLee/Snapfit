import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';

import '../support/point_purchase_fakes.dart';

class _CompletionStore extends FakeStore {
  Completer<void>? finishGate;
  bool failCatalog = false;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    if (failCatalog) throw StateError('store_product_query_failed');
    return super.products(ids);
  }

  @override
  Future<void> finish(
    PendingPointPurchase record,
    PurchaseDetails? native,
  ) async {
    await finishGate?.future;
    await super.finish(record, native);
  }
}

class _CleanupReceipts extends MemoryReceipts {
  bool failCleanup = false;
  @override
  Future<void> write(List<PendingPointPurchase> value) async {
    if (failCleanup && value.isEmpty)
      throw StateError('receipt_cleanup_failed');
    await super.write(value);
  }
}

class _Fixture {
  _Fixture(this.clock) {
    service = PointPurchaseService(
      store: store,
      storage: receipts,
      currentUserId: () => owner,
      ensureServerAvailable: () async {},
      now: () => start.add(clock.elapsed),
      verify: (record) async {
        if (failVerification) throw StateError('verification_failed');
        if (verifyGate != null) return verifyGate!.future;
        final duplicate = !credited.add(record.key);
        return StorePointPurchaseResult(
          productId: record.productId,
          grantedPoints: duplicate ? 0 : 2500,
          remainingBalance: credited.length * 2500,
          alreadyGranted: duplicate,
        );
      },
      onBalanceChanged: () {},
    )..start();
    clock.flushMicrotasks();
  }
  final FakeAsync clock;
  final start = DateTime.utc(2026, 11, 16);
  final store = _CompletionStore();
  final receipts = _CleanupReceipts();
  final credited = <String>{};
  late PointPurchaseService service;
  String owner = 'owner';
  bool failVerification = false;
  Completer<StorePointPurchaseResult>? verifyGate;

  void buy() {
    unawaited(service.buy(product));
    clock.flushMicrotasks();
  }

  void emit(String token) {
    store.controller.add([
      purchase(
        token: token,
        nativeOwner: owner,
        transactionTime: start.add(clock.elapsed).millisecondsSinceEpoch,
      ),
    ]);
    clock.flushMicrotasks();
  }

  void recover() {
    unawaited(service.recover());
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
    'completion publishes the verified product grant and balance only after fulfillment',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        expect(f.service.completion, isNull);
        f.emit('new-purchase');
        final result = f.service.completion!;
        expect(result.ownerId, 'owner');
        expect(result.productId, sku);
        expect(result.grantedPoints, 2500);
        expect(result.remainingBalance, 2500);
        expect(result.alreadyGranted, isFalse);
        expect(f.receipts.records, isEmpty);
        expect(f.receipts.checkouts, isEmpty);
        f.close();
      });
    },
  );

  test(
    'verification and store completion must both finish before completion appears',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.verifyGate = Completer<StorePointPurchaseResult>();
        f.store.finishGate = Completer<void>();
        f.buy();
        f.emit('await-verification');
        expect(f.service.completion, isNull);
        f.verifyGate!.complete(
          StorePointPurchaseResult(
            productId: sku,
            grantedPoints: 2500,
            remainingBalance: 4800,
          ),
        );
        clock.flushMicrotasks();
        expect(f.service.completion, isNull);
        f.store.finishGate!.complete();
        clock.flushMicrotasks();
        expect(f.service.completion!.remainingBalance, 4800);
        f.close();
      });
    },
  );

  for (final failAt in ['verify', 'finish', 'cleanup']) {
    test(
      'a $failAt failure never announces completion and successful recovery can',
      () {
        fakeAsync((clock) {
          final f = _Fixture(clock);
          f.failVerification = failAt == 'verify';
          f.store.failFinish = failAt == 'finish';
          f.receipts.failCleanup = failAt == 'cleanup';
          f.buy();
          f.emit('retry-$failAt');
          expect(f.service.completion, isNull);
          f.failVerification = false;
          f.store.failFinish = false;
          f.receipts.failCleanup = false;
          f.recover();
          expect(f.service.completion, isNotNull);
          expect(f.service.completion!.alreadyGranted, failAt != 'verify');
          f.close();
        });
      },
    );
  }

  test('an already granted restore is distinguished from a new grant', () {
    fakeAsync((clock) {
      final f = _Fixture(clock);
      f.credited.add('google_play:credited-earlier');
      f.emit('credited-earlier');
      expect(f.service.completion!.alreadyGranted, isTrue);
      expect(f.service.completion!.grantedPoints, 0);
      f.close();
    });
  });

  test(
    'a credited replay cannot announce completion while another checkout is open',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.credited.add('google_play:old-replay');
        f.buy();
        f.emit('old-replay');
        expect(f.service.busy, isTrue);
        expect(f.service.completion, isNull);
        f.emit('current-checkout');
        expect(f.service.completion!.alreadyGranted, isFalse);
        f.close();
      });
    },
  );

  test(
    'completion belongs to the current owner and can be dismissed explicitly',
    () {
      fakeAsync((clock) {
        final f = _Fixture(clock);
        f.buy();
        f.emit('owner-only');
        final completed = f.service.completion;
        expect(completed, isNotNull);
        f.owner = 'another-owner';
        expect(f.service.completion, isNull);
        expect(f.service.messageIsCompletion, isTrue);
        f.owner = 'owner';
        expect(f.service.completion, same(completed));
        var notifications = 0;
        f.service.addListener(() => notifications++);
        f.service.dismissCompletion();
        expect(f.service.completion, isNull);
        expect(f.service.message, isNull);
        expect(f.service.messageIsCompletion, isFalse);
        expect(notifications, 1);
        f.close();
      });
    },
  );

  test('a late previous owner fulfillment cannot publish a new completion', () {
    fakeAsync((clock) {
      final f = _Fixture(clock);
      f.verifyGate = Completer<StorePointPurchaseResult>();
      f.buy();
      f.emit('late-owner');
      f.owner = 'another-owner';
      f.verifyGate!.complete(
        StorePointPurchaseResult(
          productId: sku,
          grantedPoints: 2500,
          remainingBalance: 2500,
        ),
      );
      clock.flushMicrotasks();
      expect(f.service.completion, isNull);
      f.owner = 'owner';
      expect(f.service.completion, isNull);
      f.close();
    });
  });

  test('a new accepted checkout clears the previous completion', () {
    fakeAsync((clock) {
      final f = _Fixture(clock);
      f.buy();
      f.emit('first');
      expect(f.service.completion, isNotNull);
      f.buy();
      expect(f.store.buyCalls, 2);
      expect(f.service.completion, isNull);
      f.close();
    });
  });
  test('dismissing completion keeps a later catalog failure visible', () {
    fakeAsync((clock) {
      final f = _Fixture(clock);
      f.buy();
      f.emit('complete-before-error');
      expect(f.service.completion, isNotNull);
      final success = f.service.message;
      f.store.failCatalog = true;
      unawaited(f.service.loadProducts());
      clock.flushMicrotasks();
      final failure = f.service.message;
      expect(failure, isNotNull);
      expect(failure, isNot(success));
      expect(f.service.catalogFresh, isFalse);
      expect(f.service.messageIsCompletion, isFalse);
      f.service.dismissCompletion();
      expect(f.service.completion, isNull);
      expect(f.service.message, failure);
      f.close();
    });
  });
}

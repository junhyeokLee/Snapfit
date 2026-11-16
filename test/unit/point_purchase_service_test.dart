import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';

import '../support/point_purchase_fakes.dart';

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late FakeStore store;
  late MemoryReceipts storage;
  late PointPurchaseService service;
  String? userId;
  var failVerify = false;
  var verifies = 0;
  var refreshes = 0;
  var serverReady = true;
  var switchAccountDuringPreflight = false;
  Completer<void>? preflight;
  Completer<StorePointPurchaseResult>? verification;
  final credited = <String>{};

  PointPurchaseService makeService() => PointPurchaseService(
    store: store,
    storage: storage,
    currentUserId: () => userId,
    ensureServerAvailable: () async {
      await preflight?.future;
      if (!serverReady) throw StateError('point_purchase_not_configured');
      if (switchAccountDuringPreflight) userId = 'other';
    },
    verify: (record) async {
      verifies++;
      store.actions.add('verify');
      expect(
        storage.records.any((r) => r.key == record.key),
        isTrue,
        reason: 'Receipt must be durable before grant or consume.',
      );
      if (failVerify) throw StateError('network unavailable');
      if (verification != null) return verification!.future;
      final alreadyGranted = !credited.add(record.key);
      return StorePointPurchaseResult(
        productId: record.productId,
        grantedPoints: alreadyGranted ? 0 : 2500,
        remainingBalance: credited.length * 2500,
        alreadyGranted: alreadyGranted,
      );
    },
    onBalanceChanged: () => refreshes++,
  );

  setUp(() async {
    userId = 'owner';
    failVerify = false;
    verifies = 0;
    refreshes = 0;
    serverReady = true;
    switchAccountDuringPreflight = false;
    preflight = null;
    verification = null;
    credited.clear();
    store = FakeStore();
    storage = MemoryReceipts();
    service = makeService();
    service.start();
    await flush();
  });
  tearDown(() async {
    service.dispose();
    await store.controller.close();
  });

  test(
    'loads only point products and binds purchases to signed-in account',
    () async {
      expect(
        store.requestedIds.every((id) => id.startsWith('snapfit_points_')),
        isTrue,
      );
      expect(store.requestedIds, isNot(contains('snapfit_pro_monthly')));
      await service.buy(product);
      expect(store.accountId, 'owner');
    },
  );

  test('empty restore releases controls and refreshes wallet', () async {
    await service.recover();
    expect(service.busy, isFalse);
    expect(service.message, contains('미완료 구매가 없습니다'));
    expect(refreshes, 1);
  });

  test(
    'unconfigured server prevents native charge and releases controls',
    () async {
      serverReady = false;
      await service.buy(product);
      expect(store.accountId, isNull);
      expect(service.busy, isFalse);
      expect(service.message, contains('결제는 시작되지 않았습니다'));
      expect(verifies, 0);
    },
  );

  test(
    'account switch during preflight prevents charging previous account',
    () async {
      switchAccountDuringPreflight = true;
      await service.buy(product);
      expect(store.accountId, isNull);
      expect(service.busy, isFalse);
    },
  );

  test('unidentified stream error cannot unlock an active checkout', () async {
    await service.buy(product);
    expect(service.busy, isTrue);
    store.controller.addError(StateError('network unavailable'));
    await flush();
    expect(service.busy, isTrue);
    await service.buy(product);
    expect(store.buyCalls, 1);
    store.controller.add([purchase()]);
    await flush();
    expect(service.busy, isFalse);
  });

  test(
    'verification finishes before store consumption and receipt removal',
    () async {
      store.controller.add([purchase()]);
      await flush();
      expect(store.actions, ['verify', 'finish']);
      expect(store.finished, hasLength(1));
      expect(storage.records, isEmpty);
      expect(refreshes, 1);
    },
  );

  test('duplicate deliveries are serialized and not completed twice', () async {
    store.controller.add([purchase()]);
    store.controller.add([purchase()]);
    await flush();
    expect(verifies, 1);
    expect(store.finished, hasLength(1));
  });

  test('a completed duplicate cannot unlock a newer checkout', () async {
    store.controller.add([purchase(token: 'completed')]);
    await flush();
    expect(store.finished, hasLength(1));
    await service.buy(product);
    expect(service.busy, isTrue);
    store.controller.add([purchase(token: 'completed')]);
    await flush();
    expect(service.busy, isTrue);
    await service.buy(product);
    expect(store.buyCalls, 1);
    store.controller.add([purchase(token: 'current')]);
    await flush();
    expect(store.finished, hasLength(2));
    expect(verifies, 2);
    expect(service.busy, isFalse);
  });

  test(
    'after restart a server-credited replay cannot complete a new checkout even if store finish fails',
    () async {
      // Only the server knows this earlier credit; this process has no _finished entry.
      credited.add('google_play:server-completed');
      await service.buy(product);
      store.failFinish = true;
      store.controller.add([
        purchase(token: 'server-completed', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isTrue);
      expect(storage.records, hasLength(1));
      await service.buy(product);
      expect(store.buyCalls, 1);
      store.failFinish = false;
      store.controller.add([
        purchase(token: 'server-completed', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isTrue);
      expect(storage.records, isEmpty);
      // A replay now also enters the process-local fast path without ending the window.
      store.controller.add([
        purchase(token: 'server-completed', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isTrue);
      store.controller.add([
        purchase(token: 'new-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(store.finished, hasLength(2));
      expect(credited, hasLength(2));
    },
  );

  test(
    'a first-time grant of an older or different-product receipt cannot finish the active checkout',
    () async {
      await service.buy(product);
      store.controller.add([
        purchase(
          token: 'old-uncredited',
          nativeOwner: 'owner',
          transactionTime: 123,
        ),
        purchase(
          token: 'different-product',
          productId: 'snapfit_points_8000',
          nativeOwner: 'owner',
        ),
      ]);
      await flush();
      expect(verifies, 2);
      expect(store.finished, hasLength(2));
      expect(service.busy, isTrue);
      await service.buy(product);
      expect(store.buyCalls, 1);
      store.controller.add([
        purchase(token: 'new-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(store.finished, hasLength(3));
    },
  );

  test(
    'another owners replay stays durable without unlocking the current owners checkout',
    () async {
      await service.buy(product);
      store.controller.add([
        purchase(token: 'other-owner', nativeOwner: 'other'),
      ]);
      await flush();
      expect(verifies, 0);
      expect(store.finished, isEmpty);
      expect(service.busy, isTrue);
      expect(storage.records.single.ownerId, 'other');
      store.controller.add([
        purchase(token: 'new-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
      userId = 'other';
      await service.recover();
      expect(storage.records, isEmpty);
      expect(store.finished, hasLength(2));
    },
  );

  test(
    'an unknown-owner receipt durable before this checkout cannot complete it even with a fresh timestamp',
    () async {
      final earlier = purchase(
        token: 'durable-earlier',
        transactionTime: DateTime.now()
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      );
      storage.records = [PendingPointPurchase.fromPurchase(earlier, '')];
      // This receipt predates startup; a known-owner pending receipt now correctly
      // blocks a new checkout, while an unowned old replay must not bind one.
      service.dispose();
      service = makeService();
      service.start();
      await flush();
      await service.buy(product);
      store.controller.add([earlier]);
      await flush();
      expect(service.busy, isTrue);
      expect(storage.records, isEmpty);
      expect(store.finished, hasLength(1));
      store.controller.add([
        purchase(token: 'new-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
    },
  );

  test(
    'unrelated cancellation and error events cannot end a new checkout',
    () async {
      await service.buy(product);
      store.controller.add([
        purchase(
          token: 'old-cancel',
          status: PurchaseStatus.canceled,
          nativeOwner: 'owner',
          transactionTime: 123,
        ),
        purchase(
          token: 'foreign-error',
          status: PurchaseStatus.error,
          nativeOwner: 'other',
        ),
        purchase(
          token: 'other-product-cancel',
          productId: 'snapfit_points_8000',
          status: PurchaseStatus.canceled,
          nativeOwner: 'owner',
        ),
      ]);
      await flush();
      expect(service.busy, isTrue);
      expect(verifies, 0);
      await service.buy(product);
      expect(store.buyCalls, 1);
      store.controller.add([
        purchase(
          token: 'current-cancel',
          status: PurchaseStatus.canceled,
          nativeOwner: 'owner',
        ),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(service.message, contains('취소'));
      await service.buy(product);
      store.controller.add([
        purchase(
          token: 'current-error',
          status: PurchaseStatus.error,
          nativeOwner: 'owner',
        ),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(store.buyCalls, 2);
    },
  );

  test(
    'actual Play empty-identity cancellation or error never unlocks a checkout and explains recovery',
    () async {
      PurchaseDetails empty(PurchaseStatus status) =>
          PurchaseDetails(
              purchaseID: '',
              productID: '',
              transactionDate: null,
              status: status,
              verificationData: PurchaseVerificationData(
                source: 'google_play',
                localVerificationData: '',
                serverVerificationData: '',
              ),
            )
            ..error = IAPError(
              source: 'google_play',
              code: 'purchase_error',
              message: status == PurchaseStatus.canceled
                  ? 'BillingResponse.userCanceled'
                  : 'BillingResponse.error',
            );
      store.controller.add([empty(PurchaseStatus.canceled)]);
      await flush();
      expect(service.busy, isFalse);
      await service.buy(product);
      for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
        store.controller.add([empty(status)]);
        await flush();
        expect(service.busy, isTrue);
        expect(service.message, contains('구매 복원'));
        expect(service.message, contains('새 결제'));
        await service.buy(product);
        expect(store.buyCalls, 1);
        expect(verifies, 0);
        expect(storage.records, isEmpty);
      }
      store.controller.add([
        purchase(token: 'current-after-empty-error', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(verifies, 1);
      expect(store.finished, hasLength(1));
    },
  );

  test(
    'late native buy result from a completed operation cannot release the next checkout',
    () async {
      final firstResponse = Completer<bool>();
      store.buyResponse = (_, _) => firstResponse.future;
      final first = service.buy(product);
      await flush();
      store.controller.add([
        purchase(token: 'first-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
      store.buyResponse = (_, _) async => true;
      await service.buy(product);
      expect(service.busy, isTrue);
      firstResponse.complete(false);
      await first;
      expect(service.busy, isTrue);
      await service.buy(product);
      expect(store.buyCalls, 2);
      store.controller.add([
        purchase(token: 'second-checkout', nativeOwner: 'owner'),
      ]);
      await flush();
      expect(service.busy, isFalse);
    },
  );

  test(
    'repeated taps during preflight start only one store checkout',
    () async {
      preflight = Completer<void>();
      final first = service.buy(product);
      final second = service.buy(product);
      await flush();
      expect(service.busy, isTrue);
      expect(store.buyCalls, 0);
      preflight!.complete();
      await Future.wait([first, second]);
      expect(store.buyCalls, 1);
    },
  );

  test(
    'automatic receipt delivery locks new checkout until verification finishes',
    () async {
      verification = Completer<StorePointPurchaseResult>();
      store.controller.add([purchase()]);
      await flush();
      expect(service.busy, isTrue);
      await service.buy(product);
      await service.recover();
      expect(store.buyCalls, 0);
      expect(verifies, 1);
      verification!.complete(
        const StorePointPurchaseResult(
          productId: sku,
          grantedPoints: 2500,
          remainingBalance: 2500,
        ),
      );
      await flush();
      expect(service.busy, isFalse);
      expect(store.finished, hasLength(1));
      expect(storage.records, isEmpty);
    },
  );

  test(
    'restart after store completion and failed local cleanup retries the same receipt',
    () async {
      storage.failOnWrites.add(3);
      store.controller.add([purchase()]);
      await flush();
      expect(verifies, 1);
      expect(store.finished, hasLength(1));
      expect(storage.records, hasLength(1));
      final original = storage.records.single.toJson();
      service.dispose();
      service = makeService();
      service.start();
      await service.recover();
      expect(verifies, 2);
      expect(store.finished, hasLength(2));
      expect(storage.records, isEmpty);
      expect(service.message, contains('이미 반영된 구매'));
      expect(original['serverData'], 'test-token');
    },
  );

  test('failed verification retains receipt and never consumes', () async {
    failVerify = true;
    store.controller.add([purchase()]);
    await flush();
    expect(storage.records, hasLength(1));
    expect(store.finished, isEmpty);
    expect(service.busy, isFalse);
  });

  test(
    'restart retries durable receipt without a repeated store event',
    () async {
      failVerify = true;
      store.controller.add([purchase()]);
      await flush();
      service.dispose();
      failVerify = false;
      service = makeService();
      service.start();
      await service.recover();
      expect(store.finished, hasLength(1));
      expect(storage.records, isEmpty);
    },
  );

  test(
    'different app account cannot recover the saved owner purchase',
    () async {
      await service.buy(product);
      failVerify = true;
      store.controller.add([purchase(nativeOwner: 'owner')]);
      await flush();
      userId = 'other';
      failVerify = false;
      await service.recover();
      expect(verifies, 1);
      expect(storage.records, hasLength(1));
      expect(store.finished, isEmpty);
      userId = 'owner';
      await service.recover();
      expect(store.finished, hasLength(1));
    },
  );

  test(
    'StoreKit uppercase account UUID belongs to the same signed-in user',
    () async {
      userId = 'aabbccdd-1234-4123-8123-aabbccddeeff';
      final apple = SK2PurchaseDetails(
        productID: sku,
        purchaseID: '123456',
        transactionDate: '123',
        appAccountToken: userId!.toUpperCase(),
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'apple-json',
          serverVerificationData: 'apple-signed-data',
          source: 'app_store',
        ),
      );
      final record = PendingPointPurchase.fromPurchase(apple, 'other');
      expect(record.ownerId, userId);
      final persisted = PendingPointPurchase.fromJson({
        ...record.toJson(),
        'ownerId': ' ${userId!.toUpperCase()} ',
      });
      expect(persisted.ownerId, userId);
      store.controller.add([apple]);
      await flush();
      expect(verifies, 1);
      expect(store.finished, ['app_store:123456']);
      expect(storage.records, isEmpty);
    },
  );

  test('store completion failure keeps durable receipt for retry', () async {
    store.failFinish = true;
    store.controller.add([purchase()]);
    await flush();
    expect(storage.records, hasLength(1));
    store.failFinish = false;
    await service.recover();
    expect(store.finished, hasLength(1));
    expect(storage.records, isEmpty);
  });

  test(
    'historical point product is recovered but not offered for new sale',
    () async {
      store.controller.add([purchase(productId: 'snapfit_points_1500')]);
      await flush();
      expect(verifies, 1);
      expect(store.finished, hasLength(1));
      expect(
        service.products.any((p) => p.id == 'snapfit_points_1500'),
        isFalse,
      );
    },
  );

  test(
    'unknown restored owner is not pinned to the first restoring account',
    () async {
      userId = 'other';
      failVerify = true;
      store.controller.add([purchase()]);
      await flush();
      expect(storage.records.single.ownerId, isEmpty);
      expect(service.busy, isFalse);
      userId = 'owner';
      failVerify = false;
      await service.recover();
      expect(store.finished, hasLength(1));
      expect(storage.records, isEmpty);
    },
  );

  test(
    'metadata-free replay during another checkout stays recoverable by its owner',
    () async {
      userId = 'other';
      await service.buy(product);
      failVerify = true;
      store.controller.add([purchase()]);
      await flush();
      expect(storage.records.single.ownerId, isEmpty);
      expect(service.busy, isFalse);
      expect(service.verificationDelayed, isTrue);
      expect(service.canStartPurchase, isFalse);
      store.controller.add([
        purchase(
          token: 'current-cancel',
          status: PurchaseStatus.canceled,
          nativeOwner: 'other',
        ),
      ]);
      await flush();
      expect(service.busy, isFalse);
      expect(service.verificationDelayed, isFalse);
      expect(service.canStartPurchase, isTrue);
      userId = 'owner';
      failVerify = false;
      await service.recover();
      expect(store.finished, hasLength(1));
      expect(storage.records, isEmpty);
    },
  );

  test(
    'receipt storage failure prevents verification and consumption',
    () async {
      storage.failWrite = true;
      store.controller.add([purchase()]);
      await flush();
      expect(verifies, 0);
      expect(store.finished, isEmpty);
    },
  );

  test('pending and canceled purchase cannot grant points', () async {
    store.controller.add([
      purchase(status: PurchaseStatus.pending),
      purchase(status: PurchaseStatus.canceled),
    ]);
    await flush();
    expect(verifies, 0);
    expect(service.busy, isFalse);
  });
}

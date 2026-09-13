import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/point_purchase_service.dart';

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

  PointPurchaseService makeService() => PointPurchaseService(
    store: store,
    storage: storage,
    currentUserId: () => userId,
    ensureServerAvailable: () async {
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
      return StorePointPurchaseResult(
        productId: record.productId,
        grantedPoints: 2500,
        remainingBalance: 2500,
        alreadyGranted: verifies > 1,
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

  test('stream error releases purchase controls', () async {
    await service.buy(product);
    expect(service.busy, isTrue);
    store.controller.addError(StateError('network unavailable'));
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
      store.controller.add([purchase()]);
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

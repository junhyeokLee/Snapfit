import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_repository.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';

class _Billing extends Mock implements BillingRepository {}

class _Orders extends Mock implements OrderRepository {}

class _Shop extends Mock implements PointShopRepository {}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => _user('owner-a');
  void become(String? owner) =>
      state = AsyncData(owner == null ? null : _user(owner));
}

UserInfo _user(String owner) =>
    UserInfo(id: owner, name: 'Private account', provider: 'EMAIL');

OrderSummaryResult _summary(int count) => OrderSummaryResult(
  paymentPending: 0,
  paymentCompleted: 0,
  inProduction: 0,
  shipping: count,
  delivered: 0,
  canceled: 0,
  latestUpdatedAt: null,
);

/// The providers under test remain real; only network repositories and the
/// observed SDK owner are controlled, as in the production auth observer.
class _Harness {
  final auth = _Auth();
  final billing = _Billing();
  final orders = _Orders();
  final shop = _Shop();
  String? sdkOwner = 'owner-a';
  late final ProviderContainer container;
  final balances = <Completer<int>>[];
  final ledgers = <Completer<List<PointLedgerEntry>>>[];
  final summaries = <Completer<OrderSummaryResult>>[];
  final owned = <Completer<Set<String>>>[];
  final balanceOwners = <String?>[];
  final ledgerOwners = <String?>[];
  final summaryOwners = <String?>[];
  final ownedOwners = <String?>[];

  Future<void> init({String? observedOwner = 'owner-a'}) async {
    when(() => billing.getMyPointBalance()).thenAnswer((_) {
      balanceOwners.add(container.read(visibleOrderOwnerProvider));
      final pending = Completer<int>();
      balances.add(pending);
      return pending.future;
    });
    when(() => billing.getMyPointLedger()).thenAnswer((_) {
      ledgerOwners.add(container.read(visibleOrderOwnerProvider));
      final pending = Completer<List<PointLedgerEntry>>();
      ledgers.add(pending);
      return pending.future;
    });
    when(() => orders.fetchMyOrderSummary()).thenAnswer((_) {
      summaryOwners.add(container.read(visibleOrderOwnerProvider));
      final pending = Completer<OrderSummaryResult>();
      summaries.add(pending);
      return pending.future;
    });
    when(() => shop.currentUserId).thenAnswer((_) => sdkOwner);
    when(() => shop.loadOwnedKeys()).thenAnswer((_) {
      ownedOwners.add(container.read(visibleOrderOwnerProvider));
      final pending = Completer<Set<String>>();
      owned.add(pending);
      return pending.future;
    });
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        billingRepositoryProvider.overrideWithValue(billing),
        orderRepositoryProvider.overrideWithValue(orders),
        pointShopRepositoryProvider.overrideWithValue(shop),
        // The observed owner still changes through the real owner provider.
        // Suppress unrelated stream scheduling to isolate each request epoch.
        pointShopSessionProvider.overrideWith(
          (_) => const Stream<String?>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authViewModelProvider.future);
    container.read(orderSessionOwnerProvider.notifier).observe(observedOwner);
  }

  void watchAll() {
    container.listen(myPointBalanceProvider, (_, _) {});
    container.listen(myPointLedgerProvider, (_, _) {});
    container.listen(myOrderSummaryProvider, (_, _) {});
    container.listen(ownedPointShopKeysProvider, (_, _) {});
  }

  Future<void> become(String? owner) async {
    sdkOwner = owner;
    auth.become(owner);
    container.read(orderSessionOwnerProvider.notifier).observe(owner);
    await container.pump();
  }

  void complete(int request, int marker) {
    balances[request].complete(marker);
    ledgers[request].complete([
      PointLedgerEntry(
        id: marker,
        createdAt: null,
        amountDelta: marker,
        reason: 'ATTENDANCE',
      ),
    ]);
    summaries[request].complete(_summary(marker));
    owned[request].complete({'sticker:private-$marker'});
  }

  Future<void> readAll() async {
    await Future.wait([
      container.read(myPointBalanceProvider.future),
      container.read(myPointLedgerProvider.future),
      container.read(myOrderSummaryProvider.future),
      container.read(ownedPointShopKeysProvider.future),
    ]);
  }

  void expectMarker(int marker) {
    expect(container.read(myPointBalanceProvider).requireValue, marker);
    expect(
      container.read(myPointLedgerProvider).requireValue.single.id,
      marker,
    );
    expect(
      container.read(myOrderSummaryProvider).requireValue.shipping,
      marker,
    );
    expect(container.read(ownedPointShopKeysProvider).requireValue, {
      'sticker:private-$marker',
    });
  }

  void expectRequests(List<String?> owners) {
    expect(balanceOwners, owners);
    expect(ledgerOwners, owners);
    expect(summaryOwners, owners);
    expect(ownedOwners, owners);
  }

  void expectEmpty() {
    expect(container.read(myPointBalanceProvider).requireValue, 0);
    expect(container.read(myPointLedgerProvider).requireValue, isEmpty);
    expect(container.read(myOrderSummaryProvider).requireValue.shipping, 0);
    expect(container.read(ownedPointShopKeysProvider).requireValue, isEmpty);
  }
}

T? _rendered<T>(AsyncValue<T> state) => state.when(
  skipLoadingOnReload: false,
  skipLoadingOnRefresh: false,
  data: (value) => value,
  error: (_, _) => null,
  loading: () => null,
);

void main() {
  test(
    'wallet ledger orders and owned keys refetch on A B A and ignore an old A reply',
    () async {
      final h = _Harness();
      await h.init();
      h.watchAll();
      h.expectRequests(['owner-a']);

      await h.become('owner-b');
      h.expectRequests(['owner-a', 'owner-b']);
      h.complete(1, 200);
      await h.readAll();
      h.expectMarker(200);

      await h.become('owner-a');
      h.expectRequests(['owner-a', 'owner-b', 'owner-a']);
      h.complete(2, 300);
      await h.readAll();
      h.expectMarker(300);

      // This older request carries the same textual owner, so an ID-only check
      // would not be sufficient without Riverpod's rebuilt request generation.
      h.complete(0, 999);
      await h.container.pump();
      h.expectMarker(300);
      h.expectRequests(['owner-a', 'owner-b', 'owner-a']);
    },
  );

  test(
    'already cached personal results are hidden while the next owner reloads',
    () async {
      final h = _Harness();
      await h.init();
      h.watchAll();
      h.complete(0, 100);
      await h.readAll();
      h.expectMarker(100);

      await h.become('owner-b');
      expect(_rendered(h.container.read(myPointBalanceProvider)), isNull);
      expect(_rendered(h.container.read(myPointLedgerProvider)), isNull);
      expect(_rendered(h.container.read(myOrderSummaryProvider)), isNull);
      expect(_rendered(h.container.read(ownedPointShopKeysProvider)), isNull);
      h.complete(1, 200);
      await h.readAll();
      h.expectMarker(200);
    },
  );

  for (final sdk in <String?>['owner-b', null]) {
    test(
      'auth and observed SDK mismatch $sdk performs no private network requests',
      () async {
        final h = _Harness()..sdkOwner = sdk;
        await h.init(observedOwner: sdk);
        h.watchAll();
        await h.readAll();
        h.expectEmpty();
        h.expectRequests([]);
        verifyNever(() => h.billing.getMyPointBalance());
        verifyNever(() => h.billing.getMyPointLedger());
        verifyNever(() => h.orders.fetchMyOrderSummary());
        verifyNever(() => h.shop.loadOwnedKeys());
      },
    );
  }

  test(
    'logout empties every private result and rejects late network responses',
    () async {
      final h = _Harness();
      await h.init();
      h.watchAll();
      h.expectRequests(['owner-a']);
      await h.become(null);
      await h.readAll();
      h.expectEmpty();
      h.complete(0, 999);
      await h.container.pump();
      h.expectEmpty();
      h.expectRequests(['owner-a']);
    },
  );

  test(
    'owned keys additionally verify the repository SDK owner before querying',
    () async {
      final h = _Harness()..sdkOwner = 'owner-b';
      await h.init();
      h.container.listen(ownedPointShopKeysProvider, (_, _) {});
      expect(
        await h.container.read(ownedPointShopKeysProvider.future),
        isEmpty,
      );
      expect(h.ownedOwners, isEmpty);
      verifyNever(() => h.shop.loadOwnedKeys());
    },
  );
}

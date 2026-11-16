import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void become(String? owner) => state = owner;
}

final _ownerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

class _Request {
  _Request({required this.owner, required this.filter, required this.before});

  final String? owner;
  final PointLedgerFilter filter;
  final PointLedgerCursor? before;
  final result = Completer<PointLedgerPage>();
}

/// Repository I/O is controlled; the real history controller owns all state.
class _Repository extends Fake implements BillingRepository {
  _Repository(this.owner);

  final String? Function() owner;
  final requests = <_Request>[];

  @override
  Future<PointLedgerPage> getMyPointLedgerPage({
    PointLedgerFilter filter = PointLedgerFilter.all,
    int limit = 20,
    PointLedgerCursor? before,
  }) {
    final request = _Request(owner: owner(), filter: filter, before: before);
    requests.add(request);
    return request.result.future;
  }
}

class _Harness {
  _Harness() {
    repository = _Repository(() => container.read(_ownerProvider));
    container = ProviderContainer(
      overrides: [
        visibleOrderOwnerProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        billingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  }

  late final ProviderContainer container;
  late final _Repository repository;

  ProviderSubscription<PointLedgerHistoryState> watch([
    PointLedgerFilter filter = PointLedgerFilter.all,
  ]) => container.listen(pointLedgerHistoryProvider(filter), (_, _) {});

  PointLedgerHistoryState state([
    PointLedgerFilter filter = PointLedgerFilter.all,
  ]) => container.read(pointLedgerHistoryProvider(filter));

  PointLedgerHistoryController controller([
    PointLedgerFilter filter = PointLedgerFilter.all,
  ]) => container.read(pointLedgerHistoryProvider(filter).notifier);

  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
  }

  Future<void> become(String? owner) async {
    container.read(_ownerProvider.notifier).become(owner);
    await flush();
  }

  void complete(int request, List<int> ids, {PointLedgerCursor? nextCursor}) {
    repository.requests[request].result.complete(
      PointLedgerPage(
        entries: ids.map(_entry).toList(),
        nextCursor: nextCursor,
      ),
    );
  }

  List<int> ids([PointLedgerFilter filter = PointLedgerFilter.all]) =>
      state(filter).entries.map((entry) => entry.id).toList();
}

PointLedgerEntry _entry(int id) => PointLedgerEntry(
  id: id,
  createdAt: DateTime.utc(2026, 11, 11),
  amountDelta: -100,
  reason: 'DIGITAL_ITEM_PURCHASE',
);

PointLedgerCursor _cursor(int id) =>
    PointLedgerCursor(createdAtUtc: DateTime.utc(2026, 11, 11), id: id);

void main() {
  test(
    'initial page exposes loading then the server cursor and rows',
    () async {
      final h = _Harness();
      h.watch();

      expect(h.state().loading, isTrue);
      expect(h.state().hasError, isFalse);
      expect(h.ids(), isEmpty);
      await h.flush();
      expect(h.repository.requests, hasLength(1));
      expect(h.repository.requests.single.filter, PointLedgerFilter.all);
      expect(h.repository.requests.single.before, isNull);

      h.complete(0, [30, 29], nextCursor: _cursor(29));
      await h.flush();

      expect(h.ids(), [30, 29]);
      expect(h.state().loading, isFalse);
      expect(h.state().hasError, isFalse);
      expect(h.state().hasMore, isTrue);
      expect(h.state().nextCursor?.id, 29);
    },
  );

  test('next page appends older rows and stops after the final page', () async {
    final h = _Harness();
    h.watch();
    await h.flush();
    h.complete(0, [30, 29], nextCursor: _cursor(29));
    await h.flush();

    final next = h.controller().loadMore();
    expect(h.state().loading, isTrue);
    expect(h.ids(), [30, 29]);
    expect(h.repository.requests, hasLength(2));
    expect(h.repository.requests[1].before?.id, 29);
    expect(
      h.repository.requests[1].before?.createdAtUtc,
      DateTime.utc(2026, 11, 11),
    );
    h.complete(1, [28, 27]);
    await next;

    expect(h.ids(), [30, 29, 28, 27]);
    expect(h.state().loading, isFalse);
    expect(h.state().hasMore, isFalse);
    await h.controller().loadMore();
    expect(h.repository.requests, hasLength(2));
  });

  test('each filter queries its own first page and cursor', () async {
    final h = _Harness();
    h.watch(PointLedgerFilter.all);
    await h.flush();
    h.watch(PointLedgerFilter.spent);
    await h.flush();
    h.complete(1, [20], nextCursor: _cursor(20));
    h.complete(0, [30]);
    await h.flush();

    expect(h.ids(PointLedgerFilter.all), [30]);
    expect(h.ids(PointLedgerFilter.spent), [20]);
    final next = h.controller(PointLedgerFilter.spent).loadMore();
    expect(h.repository.requests[2].filter, PointLedgerFilter.spent);
    expect(h.repository.requests[2].before?.id, 20);
    h.complete(2, [10]);
    await next;
    expect(h.ids(PointLedgerFilter.spent), [20, 10]);
    expect(h.ids(PointLedgerFilter.all), [30]);

    h.watch(PointLedgerFilter.received);
    await h.flush();
    expect(h.repository.requests[3].filter, PointLedgerFilter.received);
    expect(h.repository.requests[3].before, isNull);
    expect(h.ids(PointLedgerFilter.received), isEmpty);
    h.complete(3, [40]);
    await h.flush();
    expect(h.ids(PointLedgerFilter.received), [40]);
  });

  test('first page failure can be retried by refresh', () async {
    final h = _Harness();
    h.watch();
    await h.flush();
    h.repository.requests[0].result.completeError(StateError('offline'));
    await h.flush();

    expect(h.state().hasError, isTrue);
    expect(h.state().loading, isFalse);
    expect(h.ids(), isEmpty);
    final retry = h.controller().refresh();
    expect(h.state().hasError, isFalse);
    expect(h.state().loading, isTrue);
    expect(h.repository.requests[1].before, isNull);
    h.complete(1, [30]);
    await retry;
    expect(h.ids(), [30]);
    expect(h.state().hasError, isFalse);
  });

  test('failed next page preserves rows and retries the same cursor', () async {
    final h = _Harness();
    h.watch();
    await h.flush();
    h.complete(0, [30, 29], nextCursor: _cursor(29));
    await h.flush();

    final failed = h.controller().loadMore();
    h.repository.requests[1].result.completeError(StateError('offline'));
    await failed;
    expect(h.ids(), [30, 29]);
    expect(h.state().hasMore, isTrue);
    expect(h.state().nextCursor?.id, 29);
    expect(h.state().loading, isFalse);
    expect(h.state().hasError, isTrue);

    final retry = h.controller().loadMore();
    expect(h.repository.requests[2].before?.id, 29);
    expect(h.state().hasError, isFalse);
    h.complete(2, [28]);
    await retry;
    expect(h.ids(), [30, 29, 28]);
    expect(h.state().hasError, isFalse);
  });

  test(
    'repeated loadMore calls issue one request while a page is pending',
    () async {
      final h = _Harness();
      h.watch();
      await h.flush();
      await h.controller().loadMore();
      expect(h.repository.requests, hasLength(1));
      h.complete(0, [30], nextCursor: _cursor(30));
      await h.flush();

      final first = h.controller().loadMore();
      final duplicate = h.controller().loadMore();
      expect(h.repository.requests, hasLength(2));
      h.complete(1, [29]);
      await Future.wait([first, duplicate]);
      expect(h.ids(), [30, 29]);
    },
  );

  test(
    'refresh resets history and rejects a pending next-page reply',
    () async {
      final h = _Harness();
      h.watch();
      await h.flush();
      h.complete(0, [30], nextCursor: _cursor(30));
      await h.flush();

      final stale = h.controller().loadMore();
      final refreshed = h.controller().refresh();
      expect(h.ids(), isEmpty);
      expect(h.state().nextCursor, isNull);
      expect(h.state().loading, isTrue);
      expect(h.repository.requests[2].before, isNull);
      h.complete(2, [40], nextCursor: _cursor(40));
      await refreshed;
      h.complete(1, [29]);
      await stale;

      expect(h.ids(), [40]);
      expect(h.state().nextCursor?.id, 40);
      expect(h.state().loading, isFalse);
      expect(h.state().hasError, isFalse);
    },
  );

  test('refresh rejects the previous pending first page', () async {
    final h = _Harness();
    h.watch();
    await h.flush();
    final refreshed = h.controller().refresh();
    h.complete(1, [40]);
    await refreshed;
    h.complete(0, [30]);
    await h.flush();
    expect(h.ids(), [40]);
    expect(h.state().loading, isFalse);
  });

  test(
    'refresh before queued initial fetch issues only the fresh request',
    () async {
      final h = _Harness();
      h.watch();
      final refreshed = h.controller().refresh();
      await h.flush();
      expect(h.repository.requests, hasLength(1));
      h.complete(0, [40]);
      await refreshed;
      expect(h.ids(), [40]);
    },
  );

  test(
    'owner A B A clears old rows and rejects the first A response',
    () async {
      final h = _Harness();
      h.watch();
      await h.flush();
      await h.become('owner-b');
      expect(h.ids(), isEmpty);
      h.complete(1, [20]);
      await h.flush();
      expect(h.ids(), [20]);

      await h.become('owner-a');
      expect(h.ids(), isEmpty);
      expect(h.state().loading, isTrue);
      h.complete(2, [40]);
      await h.flush();
      // The textual owner matches again; request identity must still reject it.
      h.complete(0, [999]);
      await h.flush();
      expect(h.ids(), [40]);
      expect(h.repository.requests.map((request) => request.owner), [
        'owner-a',
        'owner-b',
        'owner-a',
      ]);
    },
  );

  test(
    'logout hides history and does not send further private requests',
    () async {
      final h = _Harness();
      h.watch();
      await h.flush();
      h.complete(0, [30], nextCursor: _cursor(30));
      await h.flush();
      final stale = h.controller().loadMore();

      await h.become(null);
      expect(h.ids(), isEmpty);
      expect(h.state().hasMore, isFalse);
      expect(h.state().loading, isFalse);
      expect(h.state().hasError, isFalse);
      await h.controller().loadMore();
      await h.controller().refresh();
      h.complete(1, [999]);
      await stale;
      expect(h.ids(), isEmpty);
      expect(h.repository.requests, hasLength(2));
    },
  );

  test(
    'disposed history ignores a late reply after a new instance loads',
    () async {
      final h = _Harness();
      final subscription = h.watch();
      await h.flush();
      subscription.close();
      await h.flush();

      h.watch();
      await h.flush();
      expect(h.repository.requests, hasLength(2));
      h.complete(1, [40]);
      await h.flush();
      h.complete(0, [999]);
      await h.flush();
      expect(h.ids(), [40]);
      expect(h.state().hasError, isFalse);
    },
  );
}

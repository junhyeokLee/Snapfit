import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';

class _BillingRepository extends Mock implements BillingRepository {}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => _user('owner-a');

  void become(String id) => state = AsyncData(_user(id));
}

UserInfo _user(String id) =>
    UserInfo(id: id, name: 'Storage test user', provider: 'EMAIL');

StorageQuotaStatus _quota(String owner, int usedBytes) => StorageQuotaStatus(
  userId: owner,
  planCode: 'FREE',
  usedBytes: usedBytes,
  softLimitBytes: 1073741824,
  hardLimitBytes: 1073741824,
  softExceeded: false,
  hardExceeded: false,
  usagePercent: 0,
);

void main() {
  test(
    'account switch refetches quota and ignores a late previous response',
    () async {
      final auth = _Auth();
      final repository = _BillingRepository();
      final requests = <String?>[];
      final pending = <Completer<StorageQuotaStatus>>[];
      late ProviderContainer container;
      when(() => repository.getMyStorageQuota()).thenAnswer((_) {
        requests.add(container.read(authViewModelProvider).asData?.value?.id);
        final response = Completer<StorageQuotaStatus>();
        pending.add(response);
        return response.future;
      });
      container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(() => auth),
          billingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authViewModelProvider.future);
      final subscription = container.listen(myStorageQuotaProvider, (_, _) {});
      addTearDown(subscription.close);

      final first = container.read(myStorageQuotaProvider.future);
      expect(requests, ['owner-a']);
      pending[0].complete(_quota('owner-a', 100));
      expect((await first).userId, 'owner-a');

      // Leave an A refresh in flight when the authenticated account becomes B.
      container.invalidate(myStorageQuotaProvider);
      container.read(myStorageQuotaProvider);
      expect(requests, ['owner-a', 'owner-a']);
      auth.become('owner-b');
      await container.pump();
      final next = container.read(myStorageQuotaProvider.future);
      expect(requests, ['owner-a', 'owner-a', 'owner-b']);

      pending[2].complete(_quota('owner-b', 200));
      expect((await next).userId, 'owner-b');
      expect(
        container.read(myStorageQuotaProvider).requireValue.usedBytes,
        200,
      );

      pending[1].complete(_quota('owner-a', 999));
      await container.pump();
      final displayed = container.read(myStorageQuotaProvider).requireValue;
      expect(displayed.userId, 'owner-b');
      expect(displayed.usedBytes, 200);
      verify(() => repository.getMyStorageQuota()).called(3);
    },
  );
}

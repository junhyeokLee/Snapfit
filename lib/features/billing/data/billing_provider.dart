import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/storage_quota.dart';
import 'point_purchase_service.dart';
import 'billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});

final pointPurchaseServiceProvider = Provider<PointPurchaseService>((ref) {
  final service = PointPurchaseService(
    store: NativePointPurchaseStore(),
    storage: SecurePendingPointPurchaseStorage(),
    currentUserId: () => ref.read(supabaseClientProvider).auth.currentUser?.id,
    ensureServerAvailable: () => ref
        .read(billingRepositoryProvider)
        .ensurePointPurchaseAvailable(
          defaultTargetPlatform == TargetPlatform.android
              ? 'GOOGLE_PLAY'
              : 'APP_STORE',
        ),
    verify: (purchase) => ref
        .read(billingRepositoryProvider)
        .verifyPendingPointPurchase(purchase),
    onBalanceChanged: () {
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final myStorageQuotaProvider = FutureProvider<StorageQuotaStatus>((ref) async {
  try {
    return await ref
        .read(billingRepositoryProvider)
        .getMyStorageQuota()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return const StorageQuotaStatus(
      userId: '',
      planCode: 'FREE',
      usedBytes: 0,
      softLimitBytes: 1073741824,
      hardLimitBytes: 1073741824,
      softExceeded: false,
      hardExceeded: false,
      usagePercent: 0,
    );
  }
});

final myPointBalanceProvider = FutureProvider<int>((ref) async {
  return ref
      .watch(billingRepositoryProvider)
      .getMyPointBalance()
      .timeout(const Duration(seconds: 8));
});

final myPointLedgerProvider = FutureProvider<List<PointLedgerEntry>>((
  ref,
) async {
  return ref
      .watch(billingRepositoryProvider)
      .getMyPointLedger()
      .timeout(const Duration(seconds: 8));
});

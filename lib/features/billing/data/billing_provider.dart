import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../profile/domain/order_visibility_owner.dart';
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
  ref.watch(authViewModelProvider.select((auth) => auth.asData?.value?.id));
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
  final owner = ref.watch(visibleOrderOwnerProvider);
  if (owner == null) return 0;
  final value = await ref
      .watch(billingRepositoryProvider)
      .getMyPointBalance()
      .timeout(const Duration(seconds: 8));
  return ref.mounted && ref.read(visibleOrderOwnerProvider) == owner
      ? value
      : 0;
});

final isFirstAiDraftFreeProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    return await ref
        .watch(billingRepositoryProvider)
        .getIsFirstAiDraftFree()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return false;
  }
});

final myPointLedgerProvider = FutureProvider<List<PointLedgerEntry>>((
  ref,
) async {
  final owner = ref.watch(visibleOrderOwnerProvider);
  if (owner == null) return const [];
  final value = await ref
      .watch(billingRepositoryProvider)
      .getMyPointLedger()
      .timeout(const Duration(seconds: 8));
  return ref.mounted && ref.read(visibleOrderOwnerProvider) == owner
      ? value
      : const [];
});

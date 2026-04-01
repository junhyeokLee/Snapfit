import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/billing_plan.dart';
import '../domain/entities/storage_quota.dart';
import '../domain/entities/subscription_status.dart';
import 'billing_repository.dart';

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    dio: ref.read(dioProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

final billingPlansProvider = FutureProvider<List<BillingPlan>>((ref) async {
  return ref.read(billingRepositoryProvider).getPlans();
});

final mySubscriptionProvider = FutureProvider<SubscriptionStatusModel>((
  ref,
) async {
  try {
    return await ref
        .read(billingRepositoryProvider)
        .getMySubscription()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return const SubscriptionStatusModel(
      userId: '',
      planCode: null,
      status: 'INACTIVE',
      isActive: false,
    );
  }
});

final isSubscribedProvider = FutureProvider<bool>((ref) async {
  final state = await ref.watch(mySubscriptionProvider.future);
  return state.isActive;
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

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
  return ref.read(billingRepositoryProvider).getMySubscription();
});

final isSubscribedProvider = FutureProvider<bool>((ref) async {
  final state = await ref.watch(mySubscriptionProvider.future);
  return state.isActive;
});

final myStorageQuotaProvider = FutureProvider<StorageQuotaStatus>((ref) async {
  return ref.read(billingRepositoryProvider).getMyStorageQuota();
});

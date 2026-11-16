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
      ref.invalidate(pointLedgerHistoryProvider);
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

class PointLedgerHistoryState {
  const PointLedgerHistoryState({
    this.entries = const [],
    this.nextCursor,
    this.loading = false,
    this.hasError = false,
  });

  final List<PointLedgerEntry> entries;
  final PointLedgerCursor? nextCursor;
  final bool loading;
  final bool hasError;

  bool get hasMore => nextCursor != null;
}

final pointLedgerHistoryProvider = NotifierProvider.autoDispose
    .family<
      PointLedgerHistoryController,
      PointLedgerHistoryState,
      PointLedgerFilter
    >(PointLedgerHistoryController.new);

class PointLedgerHistoryController extends Notifier<PointLedgerHistoryState> {
  PointLedgerHistoryController(this.filter);

  final PointLedgerFilter filter;
  int _generation = 0;
  String? _owner;
  late BillingRepository _repository;

  bool _isCurrent(int generation) =>
      ref.mounted &&
      generation == _generation &&
      _owner != null &&
      ref.read(visibleOrderOwnerProvider) == _owner;

  @override
  PointLedgerHistoryState build() {
    final generation = ++_generation;
    _owner = ref.watch(visibleOrderOwnerProvider);
    _repository = ref.watch(billingRepositoryProvider);
    ref.onDispose(() => _generation++);
    if (_owner == null) return const PointLedgerHistoryState();

    // State must exist before an immediately completed request can update it.
    Future<void>.microtask(() => _fetchPage(generation));
    return const PointLedgerHistoryState(loading: true);
  }

  Future<void> loadMore() async {
    if (!_isCurrent(_generation) || state.loading || !state.hasMore) return;
    final generation = _generation;
    final before = state.nextCursor;
    state = PointLedgerHistoryState(
      entries: state.entries,
      nextCursor: before,
      loading: true,
    );
    await _fetchPage(generation, before: before);
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    // A refresh supersedes both the initial request and a pending older page.
    final generation = ++_generation;
    state = PointLedgerHistoryState(loading: _owner != null);
    await _fetchPage(generation);
  }

  Future<void> _fetchPage(int generation, {PointLedgerCursor? before}) async {
    if (!_isCurrent(generation)) return;
    try {
      final page = await _repository
          .getMyPointLedgerPage(filter: filter, before: before)
          .timeout(const Duration(seconds: 8));
      if (!_isCurrent(generation)) return;
      state = PointLedgerHistoryState(
        entries: List.unmodifiable([
          if (before != null) ...state.entries,
          ...page.entries,
        ]),
        nextCursor: page.nextCursor,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      // Keep the last successful cursor so the failed page can be retried.
      state = PointLedgerHistoryState(
        entries: state.entries,
        nextCursor: state.nextCursor,
        hasError: true,
      );
    }
  }
}

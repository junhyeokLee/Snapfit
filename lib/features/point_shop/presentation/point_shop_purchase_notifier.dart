import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../billing/data/billing_provider.dart';
import '../data/point_shop_provider.dart';
import '../domain/point_shop_product.dart';

enum PurchaseAction { buy, topUp }

typedef PurchaseOutcome = ({bool granted, PointShopPurchase? purchase});
final pointShopTimeoutsProvider = Provider(
  (ref) => (
    access: const Duration(seconds: 12),
    purchase: const Duration(seconds: 20),
  ),
);
final pointShopPurchaseProvider =
    NotifierProvider<PointShopPurchaseNotifier, bool>(
      PointShopPurchaseNotifier.new,
      dependencies: [pointShopRepositoryProvider, pointShopTimeoutsProvider],
    );

/// Server-authoritative purchase orchestration. No BuildContext/navigation.
/// A single provider-scoped lock covers confirmation and recharge as well as IO.
class PointShopPurchaseNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void _refresh() {
    ref.invalidate(pointShopCatalogProvider);
    ref.invalidate(ownedPointShopKeysProvider);
    ref.invalidate(myPointBalanceProvider);
    ref.invalidate(myPointLedgerProvider);
  }

  Future<PurchaseOutcome> request({
    required String productKey,
    required bool Function() isActive,
    required Future<PurchaseAction?> Function(PointShopAccess) confirm,
    required Future<void> Function() topUp,
  }) async {
    const cancelled = (granted: false, purchase: null);
    if (state) return cancelled;
    state = true;
    try {
      final repository = ref.read(pointShopRepositoryProvider);
      final userId = repository.currentUserId;
      final timeouts = ref.read(pointShopTimeoutsProvider);
      bool active() => ref.mounted && isActive();
      void checkAccount() {
        if (userId != repository.currentUserId)
          throw const PointShopException('account_changed');
      }

      while (active()) {
        checkAccount();
        final access = await repository
            .getAccess(productKey)
            .timeout(timeouts.access);
        if (!active()) return cancelled;
        checkAccount();
        if (access.productKey != productKey)
          throw const PointShopException('invalid_response');
        if (access.owned) return (granted: true, purchase: null);
        if (!access.available)
          throw const PointShopException('point_shop_product_unavailable');
        if (access.isFree) return (granted: true, purchase: null);
        if (userId == null)
          throw const PointShopException('authentication_required');
        final price = access.pointPrice;
        if (price == null || price <= 0)
          throw const PointShopException('invalid_response');
        final action = await confirm(access);
        if (!active() || action == null) return cancelled;
        checkAccount();
        if (action == PurchaseAction.topUp) {
          await topUp();
          if (!active()) return cancelled;
          checkAccount();
          _refresh();
          continue;
        }
        final result = await repository
            .purchase(productKey, price)
            .timeout(timeouts.purchase);
        if (!active()) return cancelled;
        checkAccount();
        if (result.productKey != productKey ||
            (!result.owned && !result.isFree))
          throw const PointShopException('invalid_purchase_response');
        _refresh();
        return (granted: true, purchase: result);
      }
      return cancelled;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

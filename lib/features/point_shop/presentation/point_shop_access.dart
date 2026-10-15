import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/views/billing_management_screen.dart';
import '../data/point_shop_provider.dart';
import '../domain/point_shop_product.dart';
import 'point_shop_purchase_sheet.dart';

typedef PointShopAccessGate =
    Future<bool> Function(
      BuildContext context,
      WidgetRef ref, {
      required String productKey,
      required String title,
    });

final pointShopAccessGateProvider = Provider<PointShopAccessGate>(
  (ref) => _requestAccess,
);

Future<bool> ensurePointShopAccess(
  BuildContext context,
  WidgetRef ref, {
  required String productKey,
  required String title,
}) => ref.read(pointShopAccessGateProvider)(
  context,
  ref,
  productKey: productKey,
  title: title,
);

typedef PointShopTopUp = Future<void> Function(BuildContext context);
final pointShopTopUpProvider = Provider<PointShopTopUp>(
  (ref) => (context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const BillingManagementScreen()),
    );
  },
);

Future<bool> _requestAccess(
  BuildContext context,
  WidgetRef ref, {
  required String productKey,
  required String title,
}) async {
  final owner = ModalRoute.of(context);
  bool active() => context.mounted && (owner?.isCurrent ?? true);
  if (!active()) return false;
  final coordinator = ref.read(pointShopPurchaseCoordinatorProvider);
  if (coordinator.busy) return false;
  coordinator.busy = true;
  try {
    final repository = ref.read(pointShopRepositoryProvider);
    final userId = repository.currentUserId;
    while (active()) {
      // Always re-read the server price/ownership, including after returning from recharge.
      final access = await repository
          .getAccess(productKey)
          .timeout(const Duration(seconds: 12));
      if (!active()) return false;
      if (userId != repository.currentUserId)
        throw const PointShopException('account_changed');
      if (access.productKey != productKey)
        throw const PointShopException('invalid_response');
      if (access.owned) return true;
      if (!access.available)
        throw const PointShopException('point_shop_product_unavailable');
      if (access.isFree) return true;
      if (userId == null)
        throw const PointShopException('authentication_required');
      final price = access.pointPrice;
      if (price == null || price <= 0)
        throw const PointShopException('invalid_response');
      final action = await showPointShopPurchaseSheet(
        context,
        access: access,
        title: title,
      );
      if (!active() || action == null) return false;
      if (userId != repository.currentUserId)
        throw const PointShopException('account_changed');
      if (action == PointShopPurchaseAction.topUp) {
        await ref.read(pointShopTopUpProvider)(context);
        if (!active()) return false;
        refreshPointShop(ref);
        continue;
      }
      final result = await repository
          .purchase(productKey, price)
          .timeout(const Duration(seconds: 20));
      if (!active()) return false;
      if (userId != repository.currentUserId)
        throw const PointShopException('account_changed');
      if (result.productKey != productKey ||
          (!result.owned && !result.isFree)) {
        throw const PointShopException('invalid_purchase_response');
      }
      refreshPointShop(ref);
      final useNow = await showPointShopPurchaseReceipt(
        context,
        access: access,
        purchase: result,
        title: title,
      );
      if (userId != repository.currentUserId) {
        throw const PointShopException('account_changed');
      }
      return active() && useNow;
    }
    return false;
  } catch (error) {
    if (active()) {
      final message = error is PointShopException
          ? error.message
          : '구매 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  } finally {
    coordinator.busy = false;
  }
}

class PointShopProductBadge extends ConsumerWidget {
  const PointShopProductBadge({
    super.key,
    required this.productKey,
    this.freeLabel = '무료',
    this.unlistedLabel,
    this.compact = true,
  });
  final String productKey, freeLabel;
  final String? unlistedLabel;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned =
        ref.watch(ownedPointShopKeysProvider).asData?.value ?? const <String>{};
    final label = owned.contains(productKey)
        ? '구매 완료'
        : catalog.when(
            loading: () => '가격 확인 중',
            error: (_, __) => '가격 확인 필요',
            data: (items) {
              final matches = items.where(
                (item) => item.productKey == productKey,
              );
              if (matches.isEmpty) return unlistedLabel ?? freeLabel;
              final product = matches.first;
              if (!product.isActive || product.pointPrice == null)
                return '판매 준비 중';
              return product.pointPrice == 0
                  ? freeLabel
                  : '${product.pointPrice}P';
            },
          );
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: compact ? colors.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 15,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

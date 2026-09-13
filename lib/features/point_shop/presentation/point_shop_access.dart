import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/views/billing_management_screen.dart';
import '../data/point_shop_provider.dart';
import '../domain/point_shop_product.dart';

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

enum _PurchaseAction { buy, topUp }

Future<bool> _requestAccess(
  BuildContext context,
  WidgetRef ref, {
  required String productKey,
  required String title,
}) async {
  final coordinator = ref.read(pointShopPurchaseCoordinatorProvider);
  if (coordinator.busy) return false;
  coordinator.busy = true;
  try {
    final repository = ref.read(pointShopRepositoryProvider);
    final userId = repository.currentUserId;
    while (context.mounted) {
      // Always re-read the server price/ownership, including after returning from recharge.
      final access = await repository
          .getAccess(productKey)
          .timeout(const Duration(seconds: 12));
      if (!context.mounted) return false;
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
      final insufficient = access.remainingBalance < price;
      final action = await showDialog<_PurchaseAction>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(insufficient ? '포인트가 부족해요' : '포인트로 구매'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(access.title ?? title),
              const SizedBox(height: 12),
              Text('구매 가격 ${price}P'),
              Text('보유 포인트 ${access.remainingBalance}P'),
              const SizedBox(height: 12),
              Text(
                insufficient
                    ? '${price - access.remainingBalance}P가 더 필요해요. 충전 후 여기서 이어서 구매할 수 있어요.'
                    : '한 번 구매하면 이 계정에서 계속 사용할 수 있어요.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                insufficient ? _PurchaseAction.topUp : _PurchaseAction.buy,
              ),
              child: Text(insufficient ? '포인트 충전' : '${price}P로 구매'),
            ),
          ],
        ),
      );
      if (!context.mounted || action == null) return false;
      if (userId != repository.currentUserId)
        throw const PointShopException('account_changed');
      if (action == _PurchaseAction.topUp) {
        await ref.read(pointShopTopUpProvider)(context);
        if (!context.mounted) return false;
        refreshPointShop(ref);
        continue;
      }
      final result = await repository
          .purchase(productKey, price)
          .timeout(const Duration(seconds: 20));
      if (!context.mounted) return false;
      if (userId != repository.currentUserId)
        throw const PointShopException('account_changed');
      if (result.productKey != productKey ||
          (!result.owned && !result.isFree)) {
        throw const PointShopException('invalid_purchase_response');
      }
      refreshPointShop(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyOwned ? '이미 구매한 상품이에요.' : '구매했어요. 이제 사용할 수 있어요.',
          ),
        ),
      );
      return true;
    }
    return false;
  } catch (error) {
    if (context.mounted) {
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
  });
  final String productKey, freeLabel;

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
              if (matches.isEmpty) return freeLabel;
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

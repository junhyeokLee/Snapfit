import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/views/billing_management_screen.dart';
import '../data/point_shop_provider.dart';
import '../domain/point_shop_product.dart';
import 'point_shop_purchase_notifier.dart';

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
  try {
    final outcome = await ref
        .read(pointShopPurchaseProvider.notifier)
        .request(
          productKey: productKey,
          isActive: () => context.mounted,
          topUp: () => ref.read(pointShopTopUpProvider)(context),
          confirm: (access) {
            final price = access.pointPrice!;
            final insufficient = access.remainingBalance < price;
            return showDialog<PurchaseAction>(
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
                      insufficient ? PurchaseAction.topUp : PurchaseAction.buy,
                    ),
                    child: Text(insufficient ? '포인트 충전' : '${price}P로 구매'),
                  ),
                ],
              ),
            );
          },
        );
    if (!context.mounted) return false;
    final result = outcome.purchase;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alreadyOwned ? '이미 구매한 상품이에요.' : '구매했어요. 이제 사용할 수 있어요.',
          ),
        ),
      );
    }
    return outcome.granted;
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
    final label = ref.watch(
      pointShopBadgeLabelProvider((key: productKey, freeLabel: freeLabel)),
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

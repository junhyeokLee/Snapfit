import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../data/store_discovery_provider.dart';
import '../../domain/store_product_discovery.dart';
import '../../../../shared/widgets/experience_icon.dart';

class StoreProductBadge extends ConsumerWidget {
  const StoreProductBadge({super.key, required this.productKey});
  final String productKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(storeDiscoveryClockProvider);
    final metadata =
        ref.watch(storeDiscoveryProvider).asData?.value ??
        bundledStoreDiscovery;
    final item = metadata[productKey];
    final fresh = item?.isNewAt(now) == true;
    final best = item?.isBest == true;
    if (!fresh && !best) return const SizedBox.shrink();
    final label = fresh ? 'NEW' : 'BEST';
    final description = fresh
        ? StoreProductDiscovery.newDescription
        : StoreProductDiscovery.bestDescription;
    return Tooltip(
      message: '$label · $description',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: '$label, $description',
        child: ExcludeSemantics(
          child: Container(
            key: ValueKey('store-badge-$productKey-$label'),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: fresh
                  ? SnapFitColors.actionAccent
                  : const Color(0xFF76541B),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: .5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoreBadgeRulesButton extends StatelessWidget {
  const StoreBadgeRulesButton({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void showRules() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NEW · BEST 기준'),
        scrollable: true,
        content: const Text(
          'NEW\n최초 공개 후 14일 동안 표시해요. 디자인 수정이나 재배포로 기간을 늘리지 않아요.\n\n'
          'BEST\n최근 30일간 10명 이상이 포인트로 소장한 상품 중 템플릿·프레임·스티커·문구별 상위 5개예요. 같은 사람은 한 번만 집계하며 기준에 못 미치면 표시하지 않아요.\n\n'
          'NEW와 BEST를 모두 충족하면 NEW를 먼저 표시해요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return compact
        ? IconButton(
            key: const ValueKey('store-badge-rules'),
            tooltip: 'NEW · BEST 배지 기준',
            onPressed: showRules,
            icon: const ExperienceIcon('Info', size: 18),
          )
        : TextButton.icon(
            key: const ValueKey('store-badge-rules'),
            icon: const ExperienceIcon('Info', size: 16),
            label: const Text('배지 기준'),
            onPressed: showRules,
          );
  }
}

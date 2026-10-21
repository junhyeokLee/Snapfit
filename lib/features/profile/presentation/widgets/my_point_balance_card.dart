import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../billing/data/billing_provider.dart';

class MyPointBalanceCard extends ConsumerWidget {
  const MyPointBalanceCard({
    super.key,
    required this.onCharge,
    this.compact = false,
  });
  final VoidCallback onCharge;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myPointBalanceProvider);
    final label = Text(
      '내 포인트',
      style: ExperienceFormStyle.text(
        context,
        12,
        weight: FontWeight.w600,
        color: ExperienceFormStyle.selectionInk(context),
      ),
    );
    final amount = balance.when(
      data: (value) => Text(
        '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')} P',
        style: ExperienceFormStyle.text(
          context,
          compact ? 17 : 24,
          weight: FontWeight.w600,
        ),
      ),
      loading: () => Text('확인 중', style: ExperienceFormStyle.text(context, 14)),
      error: (_, __) => TextButton(
        onPressed: () => ref.invalidate(myPointBalanceProvider),
        child: const Text('다시 확인'),
      ),
    );
    final charge = OutlinedButton(
      key: const ValueKey('my-point-charge'),
      onPressed: onCharge,
      style: OutlinedButton.styleFrom(
        foregroundColor: ExperienceFormStyle.selectionInk(context),
        side: BorderSide(color: ExperienceFormStyle.selectionInk(context).withOpacity(.4)),
        textStyle: ExperienceStyle.text(14),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('충전'),
          SizedBox(width: 6),
          ExperienceIcon('ArrowRight', size: 16),
        ],
      ),
    );
    return Container(
      key: const ValueKey('my-point-balance-card'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(SnapFitRadius.lg),
        border: Border.all(color: ExperienceFormStyle.line(context)),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          if (compact &&
              bounds.maxWidth >= 260 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20) {
            return Row(
              children: [
                label,
                const SizedBox(width: 12),
                Expanded(child: amount),
                charge,
              ],
            );
          }
          if (bounds.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: label),
                    charge,
                  ],
                ),
                const SizedBox(height: 4),
                amount,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 4), amount],
                ),
              ),
              charge,
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../billing/data/billing_provider.dart';

class MyPointBalanceCard extends ConsumerWidget {
  const MyPointBalanceCard({super.key, required this.onCharge});
  final VoidCallback onCharge;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myPointBalanceProvider);
    return Container(
      key: const ValueKey('my-point-balance-card'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ExperienceFormStyle.line(context)),
          bottom: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내 포인트',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
                const SizedBox(height: 4),
                balance.when(
                  data: (v) => Text(
                    '${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} P',
                    style: ExperienceFormStyle.text(
                      context,
                      24,
                      weight: FontWeight.w600,
                    ),
                  ),
                  loading: () => Text(
                    '확인 중',
                    style: ExperienceFormStyle.text(context, 14),
                  ),
                  error: (_, __) => TextButton(
                    onPressed: () => ref.invalidate(myPointBalanceProvider),
                    child: const Text('다시 확인'),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('my-point-charge'),
            onPressed: onCharge,
            style: TextButton.styleFrom(
              foregroundColor: ExperienceFormStyle.selectionInk(context),
              textStyle: ExperienceStyle.text(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('충전'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 19),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

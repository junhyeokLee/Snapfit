import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../billing/data/billing_provider.dart';

class MyPointBalanceCard extends ConsumerWidget {
  const MyPointBalanceCard({super.key, required this.onCharge});
  final VoidCallback onCharge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(myPointBalanceProvider);
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('my-point-balance-card'),
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 포인트'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: balance.when(
                    data: (value) => Text(
                      '${value}P',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    loading: () => const Text('잔액 확인 중…'),
                    error: (_, __) => TextButton.icon(
                      onPressed: () => ref.invalidate(myPointBalanceProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('잔액 다시 확인'),
                    ),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('my-point-charge'),
                  onPressed: onCharge,
                  child: const Text('충전하기'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('마음에 드는 템플릿·스티커·문구·프레임에 사용하세요.'),
          ],
        ),
      ),
    );
  }
}

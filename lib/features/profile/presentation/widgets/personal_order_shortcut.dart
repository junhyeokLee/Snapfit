import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../data/order_repository.dart';

class PersonalOrderShortcut extends StatelessWidget {
  const PersonalOrderShortcut({
    super.key,
    required this.summary,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<OrderSummaryResult> summary;
  final VoidCallback onOpen, onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: ExperienceFormStyle.surface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      side: BorderSide(color: ExperienceFormStyle.line(context)),
    ),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ExperienceIcon('BookOpen', size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '인쇄 주문 내역',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const ExperienceIcon('ChevronRight', size: 19),
              ],
            ),
            const SizedBox(height: 16),
            summary.when(
              loading: () => Text(
                '주문 현황 확인 중',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
              error: (_, __) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const ExperienceIcon('RefreshCw', size: 16),
                  label: const Text('주문 현황 다시 확인'),
                ),
              ),
              data: (value) => Row(
                children: [
                  for (final entry in [
                    ('결제·준비', value.paymentPending + value.paymentCompleted),
                    ('제작 중', value.inProduction),
                    ('배송 중', value.shipping),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.$2}',
                            style: ExperienceFormStyle.text(
                              context,
                              22,
                              weight: FontWeight.w500,
                              color: entry.$2 > 0
                                  ? ExperienceFormStyle.selectionInk(context)
                                  : ExperienceFormStyle.ink(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.$1,
                            style: ExperienceFormStyle.text(
                              context,
                              11,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

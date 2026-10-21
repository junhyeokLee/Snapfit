import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../domain/entities/order_history_item.dart';

/// Uses confirmed order states, never a cosmetic or estimated completion rate.
class OrderJourneyProgress extends StatelessWidget {
  const OrderJourneyProgress({super.key, required this.order});
  final OrderHistoryItem order;

  @override
  Widget build(BuildContext context) {
    final active = switch (order.status) {
      'PAYMENT_PENDING' => 0,
      'PAYMENT_COMPLETED' => order.paymentConfirmedAt == null ? 0 : 1,
      'IN_PRODUCTION' || 'PRINTING' => 1,
      'SHIPPING' => 2,
      'DELIVERED' => 3,
      _ => null,
    };
    if (active == null) return const SizedBox.shrink();
    const labels = ['결제', '제작', '배송', '완료'];
    final ink = ExperienceFormStyle.selectionInk(context);
    final line = ExperienceFormStyle.line(context);
    final onInk = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF063740)
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                label:
                    '${labels[i]}, ${i < active || order.status == 'DELIVERED'
                        ? '완료'
                        : i == active
                        ? '현재 단계'
                        : '진행 전'}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 20,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    height: 1,
                                    color: i == 0
                                        ? Colors.transparent
                                        : i <= active
                                        ? ink
                                        : line,
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    height: 1,
                                    color: i == labels.length - 1
                                        ? Colors.transparent
                                        : i < active
                                        ? ink
                                        : line,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= active
                                  ? ink
                                  : ExperienceFormStyle.surface(context),
                              border: Border.all(
                                color: i <= active ? ink : line,
                              ),
                            ),
                            child: i < active || order.status == 'DELIVERED'
                                ? ExperienceIcon(
                                    'Check',
                                    size: 12,
                                    color: onInk,
                                  )
                                : Center(
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == active ? onInk : line,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      labels[i],
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        weight: i == active ? FontWeight.w600 : FontWeight.w400,
                        secondary: i > active,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

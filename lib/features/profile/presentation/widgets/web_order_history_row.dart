import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';
import '../../domain/entities/order_history_item.dart';

/// Customer order facts remain readable in a table or a narrow browser row.
class WebOrderHistoryRow extends StatelessWidget {
  const WebOrderHistoryRow({
    super.key,
    required this.order,
    required this.amountLabel,
    required this.dateLabel,
    required this.artwork,
    required this.onTap,
  });

  final OrderHistoryItem order;
  final String amountLabel, dateLabel;
  final Widget artwork;
  final VoidCallback onTap;

  static bool useTable(BuildContext context, double width) =>
      width >= 820 && MediaQuery.textScalerOf(context).scale(14) <= 18;

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final shipment = [
      if (order.courier?.trim().isNotEmpty == true) order.courier!.trim(),
      if (order.trackingNumber?.trim().isNotEmpty == true)
        order.trackingNumber!.trim(),
    ].join(' · ');
    final delivery = shipment.isNotEmpty
        ? shipment
        : order.status.toUpperCase() == 'SHIPPING'
        ? '운송장 등록 대기'
        : null;
    final product =
        '${order.printProductLabel}\n${order.pageCount ?? '—'}페이지 · 1권';
    final title = Text(
      order.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
    );
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 54, height: 64, child: artwork),
    );
    final status = _status(context);
    Widget deliveryText() => Text(
      delivery!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
    );
    return LayoutBuilder(
      builder: (context, bounds) => InkWell(
        onTap: onTap,
        hoverColor: palette.background,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.line)),
          ),
          child: useTable(context, bounds.maxWidth)
              ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          thumbnail,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 6),
                                Text(
                                  order.orderId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Text(
                          product,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.7,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        dateLabel,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        amountLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          status,
                          if (delivery != null) ...[
                            const SizedBox(height: 8),
                            deliveryText(),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: palette.muted),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        thumbnail,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: 6),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                amountLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: palette.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    status,
                    const SizedBox(height: 10),
                    Text(
                      product.replaceAll('\n', ' · '),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: palette.muted,
                      ),
                    ),
                    if (delivery != null) ...[
                      const SizedBox(height: 8),
                      deliveryText(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final palette = WebPalette.of(context);
    final status = order.status.toUpperCase();
    final canceled = const {
      'CANCELED',
      'CANCELLED',
      'PREPARATION_CANCELED',
    }.contains(status);
    final completed = status == 'DELIVERED';
    final attention =
        order.requiresPrintAttention || status == 'PAYMENT_PENDING';
    final ink = canceled
        ? palette.muted
        : completed
        ? palette.success
        : attention
        ? palette.warning
        : palette.brandInk;
    final fill = canceled
        ? palette.canvas
        : completed
        ? palette.successSurface
        : attention
        ? palette.warningSurface
        : palette.softBrand;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('web-order-status'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          order.customerStatusLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
      ),
    );
  }
}

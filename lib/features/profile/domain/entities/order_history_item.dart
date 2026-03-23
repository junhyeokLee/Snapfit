class OrderHistoryItem {
  final String orderId;
  final String title;
  final int amount;
  final String status;
  final String statusLabel;
  final double progress;
  final DateTime orderedAt;

  const OrderHistoryItem({
    required this.orderId,
    required this.title,
    required this.amount,
    required this.status,
    required this.statusLabel,
    required this.progress,
    required this.orderedAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return OrderHistoryItem(
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '주문',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'PAYMENT_PENDING',
      statusLabel: json['statusLabel']?.toString() ?? '결제대기',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      orderedAt:
          DateTime.tryParse(json['orderedAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

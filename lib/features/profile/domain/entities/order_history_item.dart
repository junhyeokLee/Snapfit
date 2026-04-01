class OrderHistoryItem {
  final String orderId;
  final String title;
  final int amount;
  final int? pageCount;
  final String status;
  final String statusLabel;
  final double progress;
  final DateTime orderedAt;
  final int? albumId;
  final String? recipientName;
  final String? recipientPhone;
  final String? zipCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? deliveryMemo;
  final String? paymentMethod;
  final String? courier;
  final String? trackingNumber;
  final String? printVendor;
  final String? printVendorOrderId;
  final DateTime? paymentConfirmedAt;
  final DateTime? printSubmittedAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  const OrderHistoryItem({
    required this.orderId,
    required this.title,
    required this.amount,
    this.pageCount,
    required this.status,
    required this.statusLabel,
    required this.progress,
    required this.orderedAt,
    this.albumId,
    this.recipientName,
    this.recipientPhone,
    this.zipCode,
    this.addressLine1,
    this.addressLine2,
    this.deliveryMemo,
    this.paymentMethod,
    this.courier,
    this.trackingNumber,
    this.printVendor,
    this.printVendorOrderId,
    this.paymentConfirmedAt,
    this.printSubmittedAt,
    this.shippedAt,
    this.deliveredAt,
  });

  factory OrderHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseOptionalDate(String key) =>
        _parseServerDateTime(json[key]?.toString());

    return OrderHistoryItem(
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '주문',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'PAYMENT_PENDING',
      statusLabel: json['statusLabel']?.toString() ?? '결제대기',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      orderedAt: _parseServerDateTime(json['orderedAt']?.toString()) ??
          DateTime.now(),
      albumId: (json['albumId'] as num?)?.toInt(),
      recipientName: json['recipientName']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      zipCode: json['zipCode']?.toString(),
      addressLine1: json['addressLine1']?.toString(),
      addressLine2: json['addressLine2']?.toString(),
      deliveryMemo: json['deliveryMemo']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      courier: json['courier']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      printVendor: json['printVendor']?.toString(),
      printVendorOrderId: json['printVendorOrderId']?.toString(),
      paymentConfirmedAt: parseOptionalDate('paymentConfirmedAt'),
      printSubmittedAt: parseOptionalDate('printSubmittedAt'),
      shippedAt: parseOptionalDate('shippedAt'),
      deliveredAt: parseOptionalDate('deliveredAt'),
    );
  }

  static DateTime? _parseServerDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    // 서버가 LocalDateTime(타임존 없는 문자열)로 내려줄 때는 UTC 기준으로 저장된 값으로 간주하고 KST로 변환한다.
    if (!text.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(text)) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      ).add(const Duration(hours: 9));
    }
    return parsed.toLocal();
  }
}

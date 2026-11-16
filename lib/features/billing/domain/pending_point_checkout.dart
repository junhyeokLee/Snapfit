/// A native store request remains unresolved until its own result is confirmed.
/// Receipts stay in their original secure-storage format and key.
class PendingPointCheckout {
  const PendingPointCheckout({
    required this.ownerId,
    required this.productId,
    required this.startedAt,
    this.existingReceiptKeys = const {},
    this.receiptKey,
    this.receiptVerified = false,
  });

  factory PendingPointCheckout.fromJson(Map<String, dynamic> json) {
    final owner = json['ownerId'];
    final product = json['productId'];
    final started = DateTime.tryParse('${json['startedAt'] ?? ''}');
    final existing = json['existingReceiptKeys'];
    final receipt = json['receiptKey'];
    if (owner is! String ||
        owner.trim().isEmpty ||
        product is! String ||
        product.isEmpty ||
        started == null ||
        existing is! List ||
        existing.any((key) => key is! String) ||
        receipt != null && receipt is! String ||
        json['receiptVerified'] != null && json['receiptVerified'] is! bool) {
      throw const FormatException('pending_point_checkout_invalid');
    }
    return PendingPointCheckout(
      ownerId: owner.trim().toLowerCase(),
      productId: product,
      startedAt: started.toUtc(),
      existingReceiptKeys: existing.cast<String>().toSet(),
      receiptKey: receipt as String?,
      receiptVerified: json['receiptVerified'] == true,
    );
  }

  final String ownerId, productId;
  final DateTime startedAt;
  final Set<String> existingReceiptKeys;
  final String? receiptKey;
  final bool receiptVerified;

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'productId': productId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'existingReceiptKeys': existingReceiptKeys.toList(),
    'receiptKey': receiptKey,
    'receiptVerified': receiptVerified,
  };
}

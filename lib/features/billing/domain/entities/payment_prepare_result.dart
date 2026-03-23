class PaymentPrepareResult {
  final String orderId;
  final String planCode;
  final String provider;
  final int amount;
  final String currency;
  final String checkoutUrl;
  final String? successUrl;
  final String? failUrl;
  final DateTime? expiresAt;
  final bool isMock;

  const PaymentPrepareResult({
    required this.orderId,
    required this.planCode,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.checkoutUrl,
    required this.isMock,
    this.successUrl,
    this.failUrl,
    this.expiresAt,
  });

  factory PaymentPrepareResult.fromJson(Map<String, dynamic> json) {
    return PaymentPrepareResult(
      orderId: json['orderId']?.toString() ?? '',
      planCode: json['planCode']?.toString() ?? 'SNAPFIT_PRO_MONTHLY',
      provider: json['provider']?.toString() ?? 'TOSS_NAVERPAY',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'KRW',
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
      successUrl: json['successUrl']?.toString(),
      failUrl: json['failUrl']?.toString(),
      expiresAt: DateTime.tryParse(
        json['expiresAt']?.toString() ?? '',
      )?.toLocal(),
      isMock: json['isMock'] == true,
    );
  }
}

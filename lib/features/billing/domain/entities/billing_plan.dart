class BillingPlan {
  final String planCode;
  final String title;
  final int amount;
  final String currency;
  final int periodDays;
  final String provider;

  const BillingPlan({
    required this.planCode,
    required this.title,
    required this.amount,
    required this.currency,
    required this.periodDays,
    required this.provider,
  });

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      planCode: json['planCode']?.toString() ?? 'SNAPFIT_PRO_MONTHLY',
      title: json['title']?.toString() ?? 'SnapFit Pro 월간 구독',
      amount: (json['amount'] as num?)?.toInt() ?? 4900,
      currency: json['currency']?.toString() ?? 'KRW',
      periodDays: (json['periodDays'] as num?)?.toInt() ?? 30,
      provider: json['provider']?.toString() ?? 'NAVERPAY',
    );
  }
}

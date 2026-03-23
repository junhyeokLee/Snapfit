class SubscriptionStatusModel {
  final String userId;
  final String? planCode;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? nextBillingAt;
  final bool isActive;

  const SubscriptionStatusModel({
    required this.userId,
    required this.planCode,
    required this.status,
    required this.isActive,
    this.startedAt,
    this.expiresAt,
    this.nextBillingAt,
  });

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return SubscriptionStatusModel(
      userId: json['userId']?.toString() ?? '',
      planCode: json['planCode']?.toString(),
      status: json['status']?.toString() ?? 'INACTIVE',
      isActive: json['isActive'] == true,
      startedAt: parseDate(json['startedAt']),
      expiresAt: parseDate(json['expiresAt']),
      nextBillingAt: parseDate(json['nextBillingAt']),
    );
  }
}

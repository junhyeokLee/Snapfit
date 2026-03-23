class StorageQuotaStatus {
  final String userId;
  final String planCode;
  final int usedBytes;
  final int softLimitBytes;
  final int hardLimitBytes;
  final bool softExceeded;
  final bool hardExceeded;
  final int usagePercent;
  final DateTime? measuredAt;

  const StorageQuotaStatus({
    required this.userId,
    required this.planCode,
    required this.usedBytes,
    required this.softLimitBytes,
    required this.hardLimitBytes,
    required this.softExceeded,
    required this.hardExceeded,
    required this.usagePercent,
    this.measuredAt,
  });

  bool get isNearLimit => usagePercent >= 80;

  factory StorageQuotaStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    final used = (json['usedBytes'] as num?)?.toInt() ?? 0;
    final soft = (json['softLimitBytes'] as num?)?.toInt() ?? 0;
    final hard = (json['hardLimitBytes'] as num?)?.toInt() ?? 0;
    final computedPercent = hard > 0 ? ((used * 100) ~/ hard).clamp(0, 999) : 0;

    return StorageQuotaStatus(
      userId: json['userId']?.toString() ?? '',
      planCode: json['planCode']?.toString() ?? 'FREE',
      usedBytes: used,
      softLimitBytes: soft,
      hardLimitBytes: hard,
      softExceeded: json['softExceeded'] == true,
      hardExceeded: json['hardExceeded'] == true,
      usagePercent: (json['usagePercent'] as num?)?.toInt() ?? computedPercent,
      measuredAt: parseDate(json['measuredAt']),
    );
  }
}

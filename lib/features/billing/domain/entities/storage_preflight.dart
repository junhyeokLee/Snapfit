class StoragePreflightStatus {
  final String userId;
  final String planCode;
  final int incomingBytes;
  final int usedBytes;
  final int projectedBytes;
  final int hardLimitBytes;
  final int remainingBytes;
  final bool allowed;
  final String reason;
  final DateTime? measuredAt;

  const StoragePreflightStatus({
    required this.userId,
    required this.planCode,
    required this.incomingBytes,
    required this.usedBytes,
    required this.projectedBytes,
    required this.hardLimitBytes,
    required this.remainingBytes,
    required this.allowed,
    required this.reason,
    this.measuredAt,
  });

  factory StoragePreflightStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return StoragePreflightStatus(
      userId: json['userId']?.toString() ?? '',
      planCode: json['planCode']?.toString() ?? 'FREE',
      incomingBytes: (json['incomingBytes'] as num?)?.toInt() ?? 0,
      usedBytes: (json['usedBytes'] as num?)?.toInt() ?? 0,
      projectedBytes: (json['projectedBytes'] as num?)?.toInt() ?? 0,
      hardLimitBytes: (json['hardLimitBytes'] as num?)?.toInt() ?? 0,
      remainingBytes: (json['remainingBytes'] as num?)?.toInt() ?? 0,
      allowed: json['allowed'] == true,
      reason: json['reason']?.toString() ?? 'UNKNOWN',
      measuredAt: parseDate(json['measuredAt']),
    );
  }
}

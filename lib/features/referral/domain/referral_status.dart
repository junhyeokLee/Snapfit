class ReferralStatus {
  const ReferralStatus({
    required this.ownCode,
    required this.inviterPoints,
    required this.inviteePoints,
    required this.registrationWindowDays,
    required this.rewardLimit,
    required this.monthlyRewardedCount,
    required this.remaining,
    required this.invitedCount,
    required this.totalEarned,
    required this.balance,
    required this.canRedeem,
    required this.redeemed,
    required this.eligibleUntil,
    required this.serverTime,
    required this.claimed,
    required this.awardedPoints,
    required this.rewardMonth,
    required this.timezone,
    this.ineligibleReason,
  });

  final String ownCode, rewardMonth, timezone;
  final int inviterPoints, inviteePoints, registrationWindowDays, rewardLimit;
  final int monthlyRewardedCount, remaining, invitedCount, totalEarned;
  final int balance, awardedPoints;
  final bool canRedeem, redeemed, claimed;
  final DateTime eligibleUntil, serverTime;
  final String? ineligibleReason;
  String get code => ownCode;

  factory ReferralStatus.fromJson(Map<String, dynamic> json) {
    Never invalid() => throw const FormatException('초대 정보를 확인하지 못했어요.');
    int integer(String key, {bool signed = false}) {
      final value = json[key];
      if (value is! num || !value.isFinite || value != value.roundToDouble()) {
        return invalid();
      }
      final result = value.toInt();
      if (!signed && result < 0) return invalid();
      return result;
    }

    bool boolean(String key) =>
        json[key] is bool ? json[key] as bool : invalid();
    String string(String key) =>
        json[key] is String ? json[key] as String : invalid();
    DateTime instant(String key) {
      final raw = string(key);
      if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) return invalid();
      return DateTime.tryParse(raw)?.toUtc() ?? invalid();
    }

    final code = string('ownCode');
    final inviter = integer('inviterPoints'),
        invitee = integer('inviteePoints');
    final window = integer('registrationWindowDays'),
        limit = integer('rewardLimit');
    final monthly = integer('monthlyRewardedCount'),
        remaining = integer('remaining');
    final invited = integer('invitedCount'), earned = integer('totalEarned');
    final canRedeem = boolean('canRedeem'), redeemed = boolean('redeemed');
    final claimed = boolean('claimed'), awarded = integer('awardedPoints');
    final until = instant('eligibleUntil'), time = instant('serverTime');
    final month = string('rewardMonth'), zone = string('timezone');
    final reason = json['ineligibleReason'];
    final korea = time.add(const Duration(hours: 9));
    final expectedMonth =
        '${korea.year}-${korea.month.toString().padLeft(2, '0')}';
    if (!RegExp(r'^[A-HJKMNP-Z2-9]{10}$').hasMatch(code) ||
        inviter <= 0 ||
        invitee <= 0 ||
        window <= 0 ||
        limit <= 0 ||
        monthly > limit ||
        remaining != limit - monthly ||
        invited < monthly ||
        zone != 'Asia/Seoul' ||
        month != expectedMonth ||
        (reason != null && reason is! String) ||
        (canRedeem && (redeemed || !until.isAfter(time) || reason != null)) ||
        (redeemed && canRedeem) ||
        (claimed && (!redeemed || awarded != invitee)) ||
        (!claimed && awarded != 0))
      return invalid();
    return ReferralStatus(
      ownCode: code,
      inviterPoints: inviter,
      inviteePoints: invitee,
      registrationWindowDays: window,
      rewardLimit: limit,
      monthlyRewardedCount: monthly,
      remaining: remaining,
      invitedCount: invited,
      totalEarned: earned,
      balance: integer('balance', signed: true),
      canRedeem: canRedeem,
      redeemed: redeemed,
      eligibleUntil: until,
      serverTime: time,
      claimed: claimed,
      awardedPoints: awarded,
      rewardMonth: month,
      timezone: zone,
      ineligibleReason: reason as String?,
    );
  }
}

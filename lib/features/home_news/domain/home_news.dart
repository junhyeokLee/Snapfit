enum HomeNewsKind { monthlyDesign, attendance, referral, monthReview }

enum HomeNewsInteraction { dismiss, click }

class HomeNewsCampaign {
  const HomeNewsCampaign({
    required this.kind,
    this.enabled = true,
    this.startsAt,
    this.endsAt,
    required this.sortOrder,
    this.updatedAt,
  });

  factory HomeNewsCampaign.fromJson(Map<String, dynamic> json) {
    final kind = _kind(json['kind']);
    final enabled = json['enabled'];
    final order = json['sortOrder'];
    final startsAt = _optionalInstant(json['startsAt']);
    final endsAt = _optionalInstant(json['endsAt']);
    if (enabled is! bool ||
        order is! int ||
        order < -1000 ||
        order > 1000 ||
        (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt))) {
      throw const FormatException('소식 운영 정보를 확인할 수 없어요.');
    }
    return HomeNewsCampaign(
      kind: kind,
      enabled: enabled,
      startsAt: startsAt,
      endsAt: endsAt,
      sortOrder: order,
      updatedAt: _optionalInstant(json['updatedAt']),
    );
  }

  final HomeNewsKind kind;
  final bool enabled;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int sortOrder;
  final DateTime? updatedAt;

  bool isActiveAt(DateTime serverNow) =>
      enabled &&
      (startsAt == null || !serverNow.isBefore(startsAt!)) &&
      (endsAt == null || serverNow.isBefore(endsAt!));

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'enabled': enabled,
    'startsAt': startsAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
    'sortOrder': sortOrder,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

const defaultHomeNewsCampaigns = [
  HomeNewsCampaign(kind: HomeNewsKind.monthReview, sortOrder: 0),
  HomeNewsCampaign(kind: HomeNewsKind.monthlyDesign, sortOrder: 1),
  HomeNewsCampaign(kind: HomeNewsKind.attendance, sortOrder: 2),
  HomeNewsCampaign(kind: HomeNewsKind.referral, sortOrder: 3),
];

class HomeNewsDeliveryClaim {
  const HomeNewsDeliveryClaim({
    required this.claimed,
    this.deliveryId,
    this.campaignIds = const [],
  });

  final bool claimed;
  final String? deliveryId;
  final List<String> campaignIds;
}

class HomeNewsDeliveryRecord {
  const HomeNewsDeliveryRecord({required this.id, required this.shownAt});

  factory HomeNewsDeliveryRecord.fromJson(Map<String, dynamic> json) =>
      HomeNewsDeliveryRecord(
        id: _uuid(json['id']),
        shownAt: _instant(json['shownAt']),
      );

  final String id;
  final DateTime shownAt;
}

class HomeNewsCover {
  const HomeNewsCover({required this.url, required this.ratio});

  final String url;
  final double ratio;
}

/// Display content is assembled from the current catalogue and account state.
/// It is never persisted in the delivery history, especially private photos.
class HomeNewsItem {
  const HomeNewsItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.month,
    this.rewardPoints,
    this.covers = const [],
    this.autoEligible = true,
  });

  final String id;
  final HomeNewsKind kind;
  final String title;
  final String subtitle;
  final String actionLabel;
  final DateTime month;
  final int? rewardPoints;
  final List<HomeNewsCover> covers;
  final bool autoEligible;
}

class HomeNewsExposure {
  const HomeNewsExposure({
    required this.id,
    required this.kind,
    required this.month,
    required this.shownAt,
    this.dismissedAt,
    this.clickedAt,
    this.deliveryId,
  });

  factory HomeNewsExposure.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kindName = json['kind'];
    final kind = HomeNewsKind.values
        .where((kind) => kind.name == kindName)
        .firstOrNull;
    if (id is! String || id.isEmpty || kind == null) {
      throw const FormatException('새 소식 기록을 확인할 수 없어요.');
    }
    final month = _date(json['month']);
    final shownAt = _instant(json['shownAt']);
    final dismissedAt = _optionalInstant(json['dismissedAt']);
    final clickedAt = _optionalInstant(json['clickedAt']);
    final koreanShownAt = shownAt.add(const Duration(hours: 9));
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final expectedId = switch (kind) {
      HomeNewsKind.monthlyDesign => 'monthly-design:$monthKey',
      HomeNewsKind.attendance => 'attendance-benefit:v1',
      HomeNewsKind.referral => 'referral-benefit:v1',
      HomeNewsKind.monthReview => 'month-review:$monthKey',
    };
    if (month.day != 1 ||
        id != expectedId ||
        month.year != koreanShownAt.year ||
        month.month != koreanShownAt.month ||
        (dismissedAt != null && dismissedAt.isBefore(shownAt)) ||
        (clickedAt != null && clickedAt.isBefore(shownAt))) {
      throw const FormatException('새 소식 기록을 다시 확인해 주세요.');
    }
    return HomeNewsExposure(
      id: id,
      kind: kind,
      month: month,
      shownAt: shownAt,
      dismissedAt: dismissedAt,
      clickedAt: clickedAt,
      deliveryId: json['deliveryId'] == null ? null : _uuid(json['deliveryId']),
    );
  }

  final String id;
  final HomeNewsKind kind;
  final DateTime month;
  final DateTime shownAt;
  final DateTime? dismissedAt;
  final DateTime? clickedAt;
  final String? deliveryId;
}

/// Quotas are calculated by the server, using Korean dates and Monday weeks.
class HomeNewsExposureState {
  const HomeNewsExposureState({
    required this.serverNow,
    required this.serverDate,
    required this.weekStart,
    required this.dailyCount,
    required this.weeklyCount,
    required this.history,
    this.timezone = 'Asia/Seoul',
    this.hasAttendanceEver = false,
    this.hasReferralReward = false,
    this.campaigns = defaultHomeNewsCampaigns,
    this.deliveries = const [],
  });

  factory HomeNewsExposureState.fromJson(Map<String, dynamic> json) {
    final serverNow = _instant(json['serverNow']);
    final serverDate = _date(json['serverDate']);
    final weekStart = _date(json['weekStart']);
    final dailyCount = json['dailyCount'];
    final weeklyCount = json['weeklyCount'];
    final rows = json['history'];
    if (json['timezone'] != 'Asia/Seoul' ||
        dailyCount is! int ||
        dailyCount < 0 ||
        dailyCount > 1 ||
        weeklyCount is! int ||
        weeklyCount < dailyCount ||
        weeklyCount > 2 ||
        rows is! List ||
        json['hasAttendanceEver'] is! bool ||
        json['hasReferralReward'] is! bool) {
      throw const FormatException('새 소식 노출 정보를 확인할 수 없어요.');
    }
    final history = rows
        .map(
          (row) =>
              HomeNewsExposure.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
    final campaignRows = json['campaigns'];
    final deliveryRows = json['deliveries'];
    if ((campaignRows != null && campaignRows is! List) ||
        (deliveryRows != null && deliveryRows is! List)) {
      throw const FormatException('소식 운영 기록을 확인할 수 없어요.');
    }
    final campaigns = campaignRows == null
        ? defaultHomeNewsCampaigns
        : (campaignRows as List)
              .map(
                (row) => HomeNewsCampaign.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList(growable: false);
    final deliveries = deliveryRows == null
        ? const <HomeNewsDeliveryRecord>[]
        : (deliveryRows as List)
              .map(
                (row) => HomeNewsDeliveryRecord.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList(growable: false);
    final deliveryById = {
      for (final delivery in deliveries) delivery.id: delivery,
    };
    final koreanNow = serverNow.toUtc().add(const Duration(hours: 9));
    final expectedDate = DateTime.utc(
      koreanNow.year,
      koreanNow.month,
      koreanNow.day,
    );
    final expectedWeek = expectedDate.subtract(
      Duration(days: expectedDate.weekday - DateTime.monday),
    );
    final dayStart = expectedDate.subtract(const Duration(hours: 9));
    final weekInstant = expectedWeek.subtract(const Duration(hours: 9));
    if (serverDate != expectedDate ||
        weekStart != expectedWeek ||
        history.map((row) => row.id).toSet().length != history.length ||
        campaigns.length != HomeNewsKind.values.length ||
        campaigns.map((row) => row.kind).toSet().length != campaigns.length ||
        deliveryById.length != deliveries.length ||
        deliveries.any((row) => row.shownAt.isAfter(serverNow)) ||
        history.any(
          (row) =>
              row.shownAt.isAfter(serverNow) ||
              (row.dismissedAt?.isAfter(serverNow) ?? false) ||
              (row.clickedAt?.isAfter(serverNow) ?? false) ||
              (row.deliveryId != null &&
                  (deliveryById[row.deliveryId] == null ||
                      row.shownAt.isBefore(
                        deliveryById[row.deliveryId]!.shownAt,
                      ))),
        ) ||
        dailyCount !=
            history
                    .where(
                      (row) =>
                          row.deliveryId == null &&
                          !row.shownAt.isBefore(dayStart),
                    )
                    .length +
                deliveries
                    .where((row) => !row.shownAt.isBefore(dayStart))
                    .length ||
        weeklyCount !=
            history
                    .where(
                      (row) =>
                          row.deliveryId == null &&
                          !row.shownAt.isBefore(weekInstant),
                    )
                    .length +
                deliveries
                    .where((row) => !row.shownAt.isBefore(weekInstant))
                    .length) {
      throw const FormatException('최신 새 소식 상태를 다시 확인해 주세요.');
    }
    return HomeNewsExposureState(
      serverNow: serverNow,
      serverDate: serverDate,
      weekStart: weekStart,
      dailyCount: dailyCount,
      weeklyCount: weeklyCount,
      history: List.unmodifiable(history),
      hasAttendanceEver: json['hasAttendanceEver'] as bool,
      hasReferralReward: json['hasReferralReward'] as bool,
      campaigns: List.unmodifiable(campaigns),
      deliveries: List.unmodifiable(deliveries),
    );
  }

  final DateTime serverNow;

  /// UTC date-only values whose components represent the server's Korean date.
  final DateTime serverDate;
  final DateTime weekStart;
  final String timezone;
  final int dailyCount;
  final int weeklyCount;
  final List<HomeNewsExposure> history;
  final bool hasAttendanceEver;
  final bool hasReferralReward;
  final List<HomeNewsCampaign> campaigns;
  final List<HomeNewsDeliveryRecord> deliveries;

  bool get canAutoShow => dailyCount < 1 && weeklyCount < 2;

  bool hasSeen(String campaignId) => history.any((row) => row.id == campaignId);

  HomeNewsCampaign? campaignFor(HomeNewsKind kind) =>
      campaigns.where((campaign) => campaign.kind == kind).firstOrNull;
}

HomeNewsKind _kind(dynamic value) {
  final kind = HomeNewsKind.values
      .where((kind) => kind.name == value)
      .firstOrNull;
  if (kind == null) throw const FormatException('소식 종류를 확인할 수 없어요.');
  return kind;
}

String _uuid(dynamic value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('소식 노출 기록을 확인할 수 없어요.');
  }
  return value;
}

DateTime _date(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('새 소식 날짜를 확인할 수 없어요.');
  }
  final date = DateTime.parse('${value}T00:00:00Z');
  if (date.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('새 소식 날짜를 확인할 수 없어요.');
  }
  return date;
}

DateTime _instant(dynamic value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('새 소식 서버 시간을 확인할 수 없어요.');
  }
  return DateTime.parse(value).toUtc();
}

DateTime? _optionalInstant(dynamic value) =>
    value == null ? null : _instant(value);

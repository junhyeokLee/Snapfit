/// A server-confirmed attendance day, expressed as a date in Korea.
class AttendanceRecord {
  const AttendanceRecord({
    required this.date,
    required this.points,
    required this.cycleDay,
    required this.streak,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final cycleDay = _integer(json, 'cycleDay');
    final points = _integer(json, 'points');
    final streak = _integer(json, 'streak');
    if (cycleDay < 1 || cycleDay > 7 || points <= 0 || streak < 1) {
      throw const FormatException('출석 기록을 확인할 수 없어요.');
    }
    return AttendanceRecord(
      date: _date(json['date']),
      points: points,
      cycleDay: cycleDay,
      streak: streak,
    );
  }

  final DateTime date;
  final int points, cycleDay, streak;
}

class AttendanceStatus {
  const AttendanceStatus({
    required this.serverTime,
    required this.serverDate,
    required this.timezone,
    required this.nextResetAt,
    required this.checkedInToday,
    required this.currentStreak,
    required this.cycleDay,
    required this.todayReward,
    required this.weeklyRewards,
    required this.month,
    required this.monthPoints,
    required this.monthAttendanceCount,
    required this.history,
    required this.claimed,
    required this.awardedPoints,
    required this.balance,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    final rewards = (json['weeklyRewards'] as List)
        .map((value) {
          if (value is! int || value <= 0) {
            throw const FormatException('출석 보상표를 확인할 수 없어요.');
          }
          return value;
        })
        .toList(growable: false);
    final cycle = _integer(json, 'cycleDay');
    final todayReward = _integer(json, 'todayReward');
    final streak = _integer(json, 'currentStreak');
    final awarded = _integer(json, 'awardedPoints');
    final monthPoints = _integer(json, 'monthPoints');
    final count = _integer(json, 'monthAttendanceCount');
    final date = _date(json['serverDate']);
    final serverTime = _instant(json['serverTime']);
    final nextResetAt = _instant(json['nextResetAt']);
    final koreanNow = serverTime.toUtc().add(const Duration(hours: 9));
    final history = (json['history'] as List)
        .map(
          (row) =>
              AttendanceRecord.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
    final month = json['month'] as String;
    final checked = json['checkedInToday'] == true;
    if (json['timezone'] != 'Asia/Seoul' ||
        rewards.length != 7 ||
        cycle < 1 ||
        cycle > 7 ||
        todayReward != rewards[cycle - 1] ||
        streak < 0 ||
        awarded < 0 ||
        count != history.length ||
        monthPoints !=
            history.fold<int>(0, (sum, record) => sum + record.points) ||
        month != '${date.year}-${date.month.toString().padLeft(2, '0')}' ||
        history.any(
          (record) =>
              record.date.year != date.year ||
              record.date.month != date.month ||
              record.date.isAfter(date),
        ) ||
        history.map((record) => record.date).toSet().length != history.length ||
        json['checkedInToday'] is! bool ||
        json['claimed'] is! bool ||
        history.any((record) => record.date == date) != checked ||
        (checked && (streak < 1 || cycle != ((streak - 1) % 7) + 1)) ||
        (!checked && cycle != (streak % 7) + 1) ||
        koreanNow.year != date.year ||
        koreanNow.month != date.month ||
        koreanNow.day != date.day ||
        nextResetAt.toUtc() !=
            DateTime.utc(date.year, date.month, date.day, 15) ||
        !nextResetAt.isAfter(serverTime) ||
        (json['claimed'] == true &&
            (json['checkedInToday'] != true || awarded != todayReward)) ||
        (json['claimed'] != true && awarded != 0)) {
      throw const FormatException('최신 출석 상태를 다시 확인해 주세요.');
    }
    return AttendanceStatus(
      serverTime: serverTime,
      serverDate: date,
      timezone: json['timezone'] as String,
      nextResetAt: nextResetAt,
      checkedInToday: json['checkedInToday'] as bool,
      currentStreak: streak,
      cycleDay: cycle,
      todayReward: todayReward,
      weeklyRewards: List.unmodifiable(rewards),
      month: month,
      monthPoints: monthPoints,
      monthAttendanceCount: count,
      history: List.unmodifiable(history),
      claimed: json['claimed'] as bool,
      awardedPoints: awarded,
      balance: _integer(json, 'balance'),
    );
  }

  final DateTime serverTime, serverDate, nextResetAt;
  final String timezone, month;
  final bool checkedInToday, claimed;
  final int currentStreak, cycleDay, todayReward;
  final int monthPoints, monthAttendanceCount, awardedPoints, balance;
  final List<int> weeklyRewards;
  final List<AttendanceRecord> history;

  int get completedCycleDays => checkedInToday ? cycleDay : cycleDay - 1;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw const FormatException('출석 정보를 확인할 수 없어요.');
  return value;
}

DateTime _date(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('출석 날짜를 확인할 수 없어요.');
  }
  final date = DateTime.parse('${value}T00:00:00Z');
  if (date.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('출석 날짜를 확인할 수 없어요.');
  }
  return date;
}

DateTime _instant(dynamic value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('서버의 출석 시간을 확인할 수 없어요.');
  }
  return DateTime.parse(value);
}

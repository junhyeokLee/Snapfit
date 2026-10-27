import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';

const _rewards = [10, 10, 20, 10, 10, 10, 30];

Map<String, dynamic> _record(
  String date, {
  int cycle = 1,
  int streak = 1,
  int points = 10,
}) => {'date': date, 'cycleDay': cycle, 'streak': streak, 'points': points};

Map<String, dynamic> _wire({
  String date = '2026-10-26',
  bool checked = false,
  bool claimed = false,
  int cycle = 1,
  int streak = 0,
}) {
  final history = [
    if (checked)
      _record(date, cycle: cycle, streak: streak, points: _rewards[cycle - 1]),
  ];
  return {
    'serverTime': '${date}T03:00:00Z',
    'serverDate': date,
    'timezone': 'Asia/Seoul',
    'nextResetAt': '${date}T15:00:00Z',
    'checkedInToday': checked,
    'currentStreak': streak,
    'cycleDay': cycle,
    'todayReward': _rewards[cycle - 1],
    'weeklyRewards': [..._rewards],
    'month': date.substring(0, 7),
    'monthPoints': checked ? _rewards[cycle - 1] : 0,
    'monthAttendanceCount': history.length,
    'history': history,
    'claimed': claimed,
    'awardedPoints': claimed ? _rewards[cycle - 1] : 0,
    'balance': -40,
  };
}

Map<String, dynamic> _withHistory(
  Map<String, dynamic> wire,
  List<Map<String, dynamic>> history,
) => wire
  ..['history'] = history
  ..['monthAttendanceCount'] = history.length
  ..['monthPoints'] = history.fold<int>(
    0,
    (sum, row) => sum + (row['points'] as int),
  );

void main() {
  test(
    'server credit and already-claimed status are distinct while debt balance is preserved',
    () {
      final credited = AttendanceStatus.fromJson(
        _wire(checked: true, claimed: true, streak: 1),
      );
      final duplicate = AttendanceStatus.fromJson(
        _wire(checked: true, streak: 1),
      );
      expect(credited.claimed, isTrue);
      expect(credited.awardedPoints, 10);
      expect(credited.balance, -40);
      expect(duplicate.checkedInToday, isTrue);
      expect(duplicate.claimed, isFalse);
      expect(duplicate.awardedPoints, 0);
      expect(duplicate.completedCycleDays, 1);
      expect(credited.history.single.date, DateTime.utc(2026, 10, 26));
    },
  );

  test(
    'a seven-day completion becomes a fresh first-day indicator on day eight',
    () {
      final history = List.generate(
        7,
        (index) => _record(
          '2026-10-${20 + index}',
          cycle: index + 1,
          streak: index + 1,
          points: _rewards[index],
        ),
      );
      final seventh = AttendanceStatus.fromJson(
        _withHistory(_wire(checked: true, cycle: 7, streak: 7), history),
      );
      final eighth = AttendanceStatus.fromJson(
        _withHistory(_wire(date: '2026-10-27', cycle: 1, streak: 7), history),
      );
      expect(seventh.completedCycleDays, 7);
      expect(seventh.monthPoints, 100);
      expect(eighth.currentStreak, 7);
      expect(eighth.cycleDay, 1);
      expect(eighth.completedCycleDays, 0);
      expect(eighth.todayReward, 10);
    },
  );

  test(
    'the Korean month rolls at UTC 15:00 while a streak can span months',
    () {
      final monthStart = _wire(date: '2026-11-01', cycle: 4, streak: 31)
        ..['serverTime'] = '2026-10-31T15:00:00Z';
      final status = AttendanceStatus.fromJson(monthStart);
      expect(status.serverDate, DateTime.utc(2026, 11, 1));
      expect(status.month, '2026-11');
      expect(status.monthAttendanceCount, 0);
      expect(status.currentStreak, 31);
      expect(status.cycleDay, 4);
      expect(status.nextResetAt, DateTime.utc(2026, 11, 1, 15));
      final earned = AttendanceStatus.fromJson(
        _wire(
          date: '2026-11-01',
          checked: true,
          claimed: true,
          cycle: 4,
          streak: 32,
        ),
      );
      expect(earned.monthPoints, 10);
      expect(earned.monthAttendanceCount, 1);
      expect(earned.history.single.date.month, 11);
    },
  );

  test(
    'equivalent explicit timezone offsets and a real leap day are accepted',
    () {
      final wire = _wire(date: '2028-02-29')
        ..['serverTime'] = '2028-02-29T12:00:00+09:00'
        ..['nextResetAt'] = '2028-03-01T00:00:00+09:00';
      final status = AttendanceStatus.fromJson(wire);
      expect(status.serverTime.toUtc(), DateTime.utc(2028, 2, 29, 3));
      expect(status.nextResetAt.toUtc(), DateTime.utc(2028, 2, 29, 15));
      expect(status.serverDate.day, 29);
    },
  );

  test(
    'calendar totals reject duplicated, future, foreign-month or incomplete records',
    () {
      final invalid = <Map<String, dynamic>>[
        _withHistory(_wire(), [_record('2026-10-25'), _record('2026-10-25')]),
        _withHistory(_wire(), [_record('2026-10-27')]),
        _withHistory(_wire(), [_record('2026-09-30')]),
        _wire(checked: true, streak: 1)..['monthPoints'] = 11,
        _wire(checked: true, streak: 1)..['monthAttendanceCount'] = 2,
        _withHistory(_wire(), [_record('2026-10-26')]),
        _withHistory(_wire(checked: true, streak: 1), []),
        _wire()..['month'] = '2026-11',
      ];
      for (var index = 0; index < invalid.length; index++) {
        expect(
          () => AttendanceStatus.fromJson(invalid[index]),
          throwsFormatException,
          reason: 'calendar contract $index',
        );
      }
    },
  );

  test(
    'a reset time cannot be local, stale, another midnight or another server day',
    () {
      final invalid = <Map<String, dynamic>>[
        _wire()..['serverTime'] = '2026-10-26T03:00:00',
        _wire()..['nextResetAt'] = '2026-10-26T15:00:00',
        _wire()..['nextResetAt'] = '2026-10-27T15:00:00Z',
        _wire()..['nextResetAt'] = '2026-10-26T00:00:00Z',
        _wire()..['serverTime'] = '2026-10-26T15:00:00Z',
        _wire()..['timezone'] = 'UTC',
      ];
      for (var index = 0; index < invalid.length; index++) {
        expect(
          () => AttendanceStatus.fromJson(invalid[index]),
          throwsFormatException,
          reason: 'server clock contract $index',
        );
      }
    },
  );

  test(
    'malformed claims or inconsistent streak cycles cannot appear as an award',
    () {
      final invalid = <Map<String, dynamic>>[
        _wire()..['awardedPoints'] = 10,
        _wire()..['claimed'] = true,
        _wire(checked: true, claimed: true, streak: 1)..['awardedPoints'] = 20,
        _wire(checked: true, streak: 1)..['currentStreak'] = 0,
        _wire(cycle: 2, streak: 0),
        _wire(checked: true, cycle: 2, streak: 1),
        _wire()..['currentStreak'] = -1,
      ];
      for (var index = 0; index < invalid.length; index++) {
        expect(
          () => AttendanceStatus.fromJson(invalid[index]),
          throwsFormatException,
          reason: 'award contract $index',
        );
      }
    },
  );

  test('the reward table is server supplied and must agree with today', () {
    final wire = _wire()
      ..['weeklyRewards'] = [5, 5, 15, 5, 5, 5, 25]
      ..['todayReward'] = 5;
    expect(AttendanceStatus.fromJson(wire).todayReward, 5);
    for (final rewards in <List<num>>[
      [10, 10, 20, 10, 10, 30],
      [10, 10, 20, 10, 10, 10, 0],
      [10, 10, 20, 10, 10, 10, 1.5],
      [5, 5, 15, 5, 5, 5, 25],
    ]) {
      expect(
        () => AttendanceStatus.fromJson(_wire()..['weeklyRewards'] = rewards),
        throwsFormatException,
      );
    }
  });

  test(
    'wire values are strict and a calendar date never silently normalizes',
    () {
      for (final patch in <Map<String, dynamic>>[
        {'balance': '100'},
        {'balance': 100.5},
        {'checkedInToday': 0},
        {'serverDate': '2026-02-30'},
        {'serverDate': '2026-2-03'},
      ]) {
        expect(
          () => AttendanceStatus.fromJson(_wire()..addAll(patch)),
          throwsFormatException,
        );
      }
      expect(
        () => AttendanceRecord.fromJson(_record('2026-02-29')),
        throwsFormatException,
      );
      expect(
        () => AttendanceRecord.fromJson(_record('2028-02-29')),
        returnsNormally,
      );
      expect(
        () => AttendanceRecord.fromJson(_record('2026-10-26', cycle: 0)),
        throwsFormatException,
      );
      expect(
        () => AttendanceRecord.fromJson(_record('2026-10-26', streak: 0)),
        throwsFormatException,
      );
      expect(
        () => AttendanceRecord.fromJson(_record('2026-10-26', points: 0)),
        throwsFormatException,
      );
    },
  );

  test('calendar and reward collections cannot mutate after confirmation', () {
    final wire = _wire(checked: true, streak: 1);
    final status = AttendanceStatus.fromJson(wire);
    (wire['weeklyRewards'] as List)[0] = 999;
    (wire['history'] as List).clear();
    expect(status.weeklyRewards.first, 10);
    expect(status.history, hasLength(1));
    expect(() => status.weeklyRewards.add(999), throwsUnsupportedError);
    expect(status.history.clear, throwsUnsupportedError);
  });
}

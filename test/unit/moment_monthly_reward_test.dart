import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';

Map<String, dynamic> _journal() => {
  'today': '2026-11-11',
  'weekStart': '2026-11-09',
  'month': '2026-11-01',
  'records': <Object>[],
  'weekPhotoCount': 0,
};

void main() {
  test('missing server reward policy stays unknown', () {
    expect(MomentJournal.fromJson(_journal()).monthlyReward, isNull);
  });

  test(
    'server qualifying days are preserved separately from journal records',
    () {
      final journal = MomentJournal.fromJson({
        ..._journal(),
        'monthlyReward': {
          'points': 1000,
          'recordedDays': 9,
          'daysInMonth': 30,
          'awarded': false,
          'canComplete': false,
          'awardedAt': null,
        },
      });
      final reward = journal.monthlyReward!;
      expect(reward.points, 1000);
      expect(reward.recordedDays, 9);
      expect(reward.daysInMonth, 30);
      expect(reward.awarded, isFalse);
      expect(reward.canComplete, isFalse);
      expect(journal.withRecords(const []).monthlyReward, same(reward));
    },
  );

  test('awarded reward survives later removal of a journal record', () {
    final journal = MomentJournal.fromJson({
      ..._journal(),
      'monthlyReward': {
        'points': 1000,
        'recordedDays': 29,
        'daysInMonth': 30,
        'awarded': true,
        'canComplete': true,
        'awardedAt': '2026-11-30T14:59:00Z',
      },
    });
    expect(journal.monthlyReward!.awarded, isTrue);
    expect(
      journal.monthlyReward!.awardedAt,
      DateTime.utc(2026, 11, 30, 14, 59),
    );
  });

  test('malformed server reward does not fabricate a payable status', () {
    expect(
      () => MomentJournal.fromJson({
        ..._journal(),
        'monthlyReward': {
          'points': 1000,
          'recordedDays': 31,
          'daysInMonth': 28,
          'awarded': false,
          'canComplete': true,
        },
      }),
      throwsFormatException,
    );
  });

  test('past photo restriction has a specific recovery message', () {
    expect(
      momentServerError('moment_day_locked', 'P0001'),
      '사진은 한국 시간 기준 당일에만 추가하거나 바꿀 수 있어요. 지난 기록은 글만 수정할 수 있어요.',
    );
  });

  test('monthly completion credit is named in point history', () {
    final entry = PointLedgerEntry.fromJson({
      'id': 1,
      'amount_delta': 1000,
      'reason': 'MONTHLY_MOMENT_COMPLETION',
    });
    expect(entry.title, '월간 기록 완주 적립');
    expect(entry.subtitle, '달력의 모든 날을 사진으로 채워 받은 포인트');
  });
}

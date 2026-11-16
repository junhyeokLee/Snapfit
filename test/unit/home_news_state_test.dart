import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';

Map<String, dynamic> _exposure({
  String id = 'monthly-design:2026-10',
  String kind = 'monthlyDesign',
  String month = '2026-10-01',
  String shownAt = '2026-10-26T14:59:59Z',
}) => {
  'id': id,
  'kind': kind,
  'month': month,
  'shownAt': shownAt,
  'dismissedAt': null,
  'clickedAt': null,
};

Map<String, dynamic> _state({
  String now = '2026-10-26T15:00:00Z',
  String date = '2026-10-27',
  String week = '2026-10-26',
  int daily = 0,
  int weekly = 1,
  List<Map<String, dynamic>>? history,
}) => {
  'serverNow': now,
  'serverDate': date,
  'weekStart': week,
  'timezone': 'Asia/Seoul',
  'dailyCount': daily,
  'weeklyCount': weekly,
  'hasAttendanceEver': false,
  'hasReferralReward': false,
  'history': history ?? [_exposure()],
};

void main() {
  test(
    'Korean midnight leaves the previous exposure in the same Monday week',
    () {
      final state = HomeNewsExposureState.fromJson(_state());
      expect(state.serverNow, DateTime.utc(2026, 10, 26, 15));
      expect(state.serverDate, DateTime.utc(2026, 10, 27));
      expect(state.weekStart, DateTime.utc(2026, 10, 26));
      expect(state.canAutoShow, isTrue);
      expect(state.hasSeen('monthly-design:2026-10'), isTrue);
      expect(state.hasSeen('attendance-benefit:v1'), isFalse);
      expect(() => state.history.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Korean Monday resets weekly counts while all campaign history remains',
    () {
      final state = HomeNewsExposureState.fromJson(
        _state(
          now: '2026-11-01T15:00:00Z',
          date: '2026-11-02',
          week: '2026-11-02',
          weekly: 0,
        ),
      );
      expect(state.canAutoShow, isTrue);
      expect(state.hasSeen('monthly-design:2026-10'), isTrue);
    },
  );

  test('daily and weekly statistics no longer suppress home-entry display', () {
    expect(
      HomeNewsExposureState.fromJson(
        _state(daily: 1, history: [_exposure(shownAt: '2026-10-26T15:00:00Z')]),
      ).canAutoShow,
      isTrue,
    );
    expect(
      HomeNewsExposureState.fromJson(
        _state(
          now: '2026-10-28T03:00:00Z',
          date: '2026-10-28',
          weekly: 2,
          history: [
            _exposure(),
            _exposure(
              id: 'attendance-benefit:v1',
              kind: 'attendance',
              shownAt: '2026-10-27T03:00:00Z',
            ),
          ],
        ),
      ).canAutoShow,
      isTrue,
    );
  });

  test(
    'rejects forged date/week, inconsistent statistics and history duplicates',
    () {
      for (final invalid in [
        _state(date: '2026-10-26'),
        _state(week: '2026-10-25'),
        _state(daily: 2, weekly: 2),
        _state(weekly: 3),
        _state(daily: 1),
        _state(weekly: 0),
        _state(history: [_exposure(), _exposure()], weekly: 2),
        {..._state(), 'timezone': 'UTC'},
        {..._state(), 'serverNow': '2026-10-26T15:00:00'},
        {..._state(), 'hasAttendanceEver': 'false'},
        {..._state(), 'hasReferralReward': null},
      ]) {
        expect(
          () => HomeNewsExposureState.fromJson(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'exposure IDs, campaign month, kind, and interactions must match server history',
    () {
      for (final invalid in [
        _exposure(id: 'unregistered-campaign'),
        _exposure(kind: 'referral'),
        _exposure(kind: 'unknown'),
        _exposure(month: '2026-10-02'),
        _exposure(month: '2026-09-01', id: 'monthly-design:2026-09'),
        {..._exposure(), 'clickedAt': '2026-10-26T14:59:58Z'},
        {..._exposure(), 'dismissedAt': '2026-10-26T14:59:58Z'},
      ]) {
        expect(() => HomeNewsExposure.fromJson(invalid), throwsFormatException);
      }
      expect(
        () => HomeNewsExposureState.fromJson(
          _state(history: [_exposure(shownAt: '2026-10-26T15:00:01Z')]),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'permanent attendance and referral flags are retained from actual server eligibility',
    () {
      final state = HomeNewsExposureState.fromJson({
        ..._state(),
        'hasAttendanceEver': true,
        'hasReferralReward': true,
      });
      expect(state.hasAttendanceEver, isTrue);
      expect(state.hasReferralReward, isTrue);
    },
  );

  test(
    'older server snapshots receive four enabled default campaigns in the agreed priority order',
    () {
      final state = HomeNewsExposureState.fromJson(_state());
      expect(state.campaigns.map((campaign) => campaign.kind), [
        HomeNewsKind.monthReview,
        HomeNewsKind.monthlyDesign,
        HomeNewsKind.attendance,
        HomeNewsKind.referral,
      ]);
      expect(state.campaigns.map((campaign) => campaign.sortOrder), [
        0,
        1,
        2,
        3,
      ]);
      expect(state.campaigns.every((campaign) => campaign.enabled), isTrue);
      expect(state.deliveries, isEmpty);
      expect(state.campaignFor(HomeNewsKind.monthlyDesign)?.sortOrder, 1);
    },
  );

  test(
    'campaign scheduling uses inclusive starts, exclusive ends and absolute server instants',
    () {
      final campaign = HomeNewsCampaign.fromJson({
        'kind': 'attendance',
        'enabled': true,
        'startsAt': '2026-10-27T09:00:00+09:00',
        'endsAt': '2026-10-27T10:00:00+09:00',
        'sortOrder': -3,
        'updatedAt': '2026-10-26T00:00:00Z',
      });
      expect(campaign.isActiveAt(DateTime.utc(2026, 10, 26, 23, 59)), isFalse);
      expect(campaign.isActiveAt(DateTime.utc(2026, 10, 27)), isTrue);
      expect(campaign.isActiveAt(DateTime.utc(2026, 10, 27, 1)), isFalse);
      expect(campaign.startsAt, DateTime.utc(2026, 10, 27));
      expect(campaign.toJson()['startsAt'], '2026-10-27T00:00:00.000Z');
      final disabled = HomeNewsCampaign.fromJson({
        ...campaign.toJson(),
        'enabled': false,
      });
      expect(disabled.isActiveAt(DateTime.utc(2026, 10, 27)), isFalse);
      for (final invalid in [
        {...campaign.toJson(), 'kind': 'unknown'},
        {...campaign.toJson(), 'enabled': 'true'},
        {...campaign.toJson(), 'sortOrder': 1001},
        {...campaign.toJson(), 'startsAt': '2026-10-27T01:00:00Z'},
      ]) {
        expect(() => HomeNewsCampaign.fromJson(invalid), throwsFormatException);
      }
    },
  );

  test(
    'four seen cards from one delivery consume one daily and weekly popup',
    () {
      const deliveryId = '44444444-4444-4444-8444-444444444444';
      final history = [
        _exposure(shownAt: '2026-10-26T15:00:00Z'),
        _exposure(
          id: 'attendance-benefit:v1',
          kind: 'attendance',
          shownAt: '2026-10-26T15:00:00Z',
        ),
        _exposure(
          id: 'referral-benefit:v1',
          kind: 'referral',
          shownAt: '2026-10-26T15:00:00Z',
        ),
        _exposure(
          id: 'month-review:2026-10',
          kind: 'monthReview',
          shownAt: '2026-10-26T15:00:00Z',
        ),
      ].map((row) => {...row, 'deliveryId': deliveryId}).toList();
      final json = {
        ..._state(daily: 1, weekly: 1, history: history),
        'deliveries': [
          {'id': deliveryId, 'shownAt': '2026-10-26T15:00:00Z'},
        ],
      };
      final state = HomeNewsExposureState.fromJson(json);
      expect(state.history, hasLength(4));
      expect(state.deliveries, hasLength(1));
      expect(state.canAutoShow, isTrue);
      expect(
        () => HomeNewsExposureState.fromJson({...json, 'dailyCount': 0}),
        throwsFormatException,
      );
      expect(
        () => HomeNewsExposureState.fromJson({...json, 'deliveries': []}),
        throwsFormatException,
      );
      expect(
        () => HomeNewsExposureState.fromJson({...json, 'campaigns': []}),
        throwsFormatException,
      );
      expect(
        () => HomeNewsExposureState.fromJson({...json, 'campaigns': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => HomeNewsExposureState.fromJson({...json, 'deliveries': 'bad'}),
        throwsFormatException,
      );
    },
  );

  test(
    'legacy impressions and new deliveries both count without double-counting viewed cards',
    () {
      const deliveryId = '44444444-4444-4444-8444-444444444444';
      final state = HomeNewsExposureState.fromJson({
        ..._state(
          now: '2026-10-27T03:00:00Z',
          daily: 1,
          weekly: 2,
          history: [
            _exposure(),
            {
              ..._exposure(
                id: 'attendance-benefit:v1',
                kind: 'attendance',
                shownAt: '2026-10-27T03:00:00Z',
              ),
              'deliveryId': deliveryId,
            },
          ],
        ),
        'deliveries': [
          {'id': deliveryId, 'shownAt': '2026-10-27T03:00:00Z'},
        ],
      });
      expect(state.dailyCount, 1);
      expect(state.weeklyCount, 2);
      expect(state.canAutoShow, isTrue);
    },
  );

  test(
    'today-hide alone suppresses home entry until the exact next Korean midnight',
    () {
      final hidden = HomeNewsExposureState.fromJson({
        ..._state(),
        'hiddenForToday': true,
        'hiddenUntil': '2026-10-27T15:00:00Z',
      });
      expect(hidden.canAutoShow, isFalse);
      expect(hidden.hiddenUntil, DateTime.utc(2026, 10, 27, 15));
      for (final invalid in [
        {..._state(), 'hiddenForToday': true},
        {
          ..._state(),
          'hiddenForToday': true,
          'hiddenUntil': '2026-10-27T14:59:59Z',
        },
        {
          ..._state(),
          'hiddenForToday': false,
          'hiddenUntil': '2026-10-27T15:00:00Z',
        },
        {..._state(), 'hiddenForToday': 'true'},
      ]) {
        expect(
          () => HomeNewsExposureState.fromJson(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'bounded omitted counters retain exact statistics without limiting repeated entry',
    () {
      final json = {
        ..._state(daily: 80, weekly: 81),
        'omittedDailyCount': 80,
        'omittedWeeklyCount': 80,
      };
      final state = HomeNewsExposureState.fromJson(json);
      expect(state.dailyCount, 80);
      expect(state.weeklyCount, 81);
      expect(state.canAutoShow, isTrue);
      for (final invalid in [
        {...json, 'omittedDailyCount': 79},
        {...json, 'omittedWeeklyCount': 79},
        {...json, 'omittedDailyCount': -1},
        {...json, 'omittedWeeklyCount': '80'},
      ]) {
        expect(
          () => HomeNewsExposureState.fromJson(invalid),
          throwsFormatException,
        );
      }
    },
  );
}

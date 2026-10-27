import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';
import 'package:snap_fit/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/referral/domain/referral_status.dart';
import 'package:snap_fit/features/referral/presentation/providers/referral_providers.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

final _today = DateTime.utc(2026, 10, 27);
final _testOwnerProvider = NotifierProvider<_TestOwner, String?>(
  _TestOwner.new,
);

class _TestOwner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void change(String? value) => state = value;
}

HomeNewsExposureState _state({
  DateTime? date,
  bool attended = false,
  bool referred = false,
  List<HomeNewsExposure> history = const [],
  List<HomeNewsCampaign> campaigns = defaultHomeNewsCampaigns,
}) {
  final today = date ?? _today;
  final week = momentWeekStart(today);
  final dayInstant = today.subtract(const Duration(hours: 9));
  final weekInstant = week.subtract(const Duration(hours: 9));
  return HomeNewsExposureState(
    serverNow: today.add(const Duration(hours: 3)),
    serverDate: today,
    weekStart: week,
    dailyCount: history
        .where((row) => !row.shownAt.isBefore(dayInstant))
        .length,
    weeklyCount: history
        .where((row) => !row.shownAt.isBefore(weekInstant))
        .length,
    history: history,
    hasAttendanceEver: attended,
    hasReferralReward: referred,
    campaigns: campaigns,
  );
}

AttendanceStatus _attendance({bool checked = false, int reward = 37}) =>
    AttendanceStatus(
      serverTime: _today.add(const Duration(hours: 3)),
      serverDate: _today,
      timezone: 'Asia/Seoul',
      nextResetAt: _today.add(const Duration(hours: 15)),
      checkedInToday: checked,
      currentStreak: checked ? 1 : 0,
      cycleDay: 1,
      todayReward: reward,
      weeklyRewards: [reward, 10, 20, 10, 10, 10, 30],
      month: '2026-10',
      monthPoints: checked ? reward : 0,
      monthAttendanceCount: checked ? 1 : 0,
      history: [
        if (checked)
          AttendanceRecord(
            date: _today,
            points: reward,
            cycleDay: 1,
            streak: 1,
          ),
      ],
      claimed: false,
      awardedPoints: 0,
      balance: 0,
    );

ReferralStatus _referral({
  int reward = 175,
  int invited = 0,
  int remaining = 20,
}) => ReferralStatus(
  ownCode: 'ABCD2345XY',
  inviterPoints: reward,
  inviteePoints: 100,
  registrationWindowDays: 7,
  rewardLimit: 20,
  monthlyRewardedCount: 20 - remaining,
  remaining: remaining,
  invitedCount: invited,
  totalEarned: invited * reward,
  balance: 0,
  canRedeem: true,
  redeemed: false,
  eligibleUntil: _today.add(const Duration(days: 7)),
  serverTime: _today.add(const Duration(hours: 3)),
  claimed: false,
  awardedPoints: 0,
  rewardMonth: '2026-10',
  timezone: 'Asia/Seoul',
);

MomentRecord _record({String owner = 'owner', int photos = 1}) => MomentRecord(
  id: '$owner-record',
  recordDate: _today,
  caption: '남겨 둔 순간',
  revision: 1,
  photos: [
    for (var index = 0; index < photos; index++)
      MomentPhoto(
        id: '$owner-photo-$index',
        path: '$owner/moments/photo-$index.png',
        width: 1200,
        height: 900,
      ),
  ],
);

MomentJournal _journal({
  DateTime? month,
  List<MomentRecord>? records,
  int? albumId,
}) => MomentJournal(
  today: _today,
  weekStart: momentWeekStart(_today),
  month: month ?? momentMonth(_today),
  records: records ?? [_record()],
  weekPhotoCount: 1,
  monthlyAlbumId: albumId,
);

List<PremiumTemplate> _designs() => [publishedCreationTemplateById(-9471)!];

ProviderContainer _container({
  String? owner = 'owner',
  HomeNewsExposureState? state,
  List<PremiumTemplate>? designs,
  AttendanceStatus? attendance,
  ReferralStatus? referral,
  MomentJournal? journal,
  Future<AttendanceStatus> Function()? loadAttendance,
  Future<ReferralStatus> Function()? loadReferral,
  Future<MomentJournal> Function(DateTime)? loadJournal,
}) {
  final container = ProviderContainer(
    overrides: [
      homeNewsCurrentOwnerProvider.overrideWithValue(owner),
      homeNewsExposureStateProvider.overrideWith(
        (_) async => state ?? _state(),
      ),
      homeNewsDesignsProvider.overrideWith((_) async => designs ?? _designs()),
      attendanceStatusProvider.overrideWith(
        (_) =>
            loadAttendance?.call() ?? Future.value(attendance ?? _attendance()),
      ),
      referralStatusProvider.overrideWith(
        (_) => loadReferral?.call() ?? Future.value(referral ?? _referral()),
      ),
      momentsMonthProvider.overrideWith(
        (_, month) =>
            loadJournal?.call(month) ?? Future.value(journal ?? _journal()),
      ),
    ],
  );
  container.listen(homeNewsCatalogProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'four eligible stories prioritize the month review and use real rewards',
    () async {
      final container = _container(
        journal: _journal(records: [_record(photos: 2)]),
      );
      final items = await container.read(homeNewsCatalogProvider.future);

      expect(items.map((item) => item.kind), [
        HomeNewsKind.monthReview,
        HomeNewsKind.monthlyDesign,
        HomeNewsKind.attendance,
        HomeNewsKind.referral,
      ]);
      expect(items.map((item) => item.id), [
        'month-review:2026-10',
        'monthly-design:2026-10',
        'attendance-benefit:v1',
        'referral-benefit:v1',
      ]);
      expect(items.first.subtitle, contains('2장'));
      expect(
        items.first.covers.first.url,
        'supabase://album-assets/owner/moments/photo-0.png',
      );
      expect(items.first.covers.first.ratio, 4 / 3);
      expect(
        items[1].covers.single.url,
        'asset:assets/catalog_thumbnails/template_-9471.png',
      );
      expect(items[2].rewardPoints, 37);
      expect(items[2].subtitle, contains('37P'));
      expect(items[3].rewardPoints, 175);
      expect(items[3].subtitle, contains('175P'));
    },
  );

  test(
    'prior participation keeps all four browsable without automatic prompting',
    () async {
      var attendanceReads = 0;
      var referralReads = 0;
      final container = _container(
        state: _state(attended: true, referred: true),
        loadAttendance: () async {
          attendanceReads++;
          return _attendance();
        },
        loadReferral: () async {
          referralReads++;
          return _referral();
        },
      );
      final items = await container.read(homeNewsCatalogProvider.future);

      expect(items.map((item) => item.kind), [
        HomeNewsKind.monthReview,
        HomeNewsKind.monthlyDesign,
        HomeNewsKind.attendance,
        HomeNewsKind.referral,
      ]);
      expect(
        items.where((item) => !item.autoEligible).map((item) => item.kind),
        containsAll([HomeNewsKind.attendance, HomeNewsKind.referral]),
      );
      expect(attendanceReads, 1);
      expect(referralReads, 1);
    },
  );

  test(
    'completed benefits show honest current state and retain their destinations',
    () async {
      for (final referral in [
        _referral(invited: 1),
        _referral(invited: 20, remaining: 0),
      ]) {
        final container = _container(
          attendance: _attendance(checked: true),
          referral: referral,
        );
        final items = await container.read(homeNewsCatalogProvider.future);
        final attendanceItem = items.singleWhere(
          (item) => item.kind == HomeNewsKind.attendance,
        );
        final referralItem = items.singleWhere(
          (item) => item.kind == HomeNewsKind.referral,
        );
        expect(attendanceItem.autoEligible, isFalse);
        expect(attendanceItem.rewardPoints, isNull);
        expect(attendanceItem.actionLabel, '출석 기록 보기');
        expect(referralItem.autoEligible, isFalse);
        if (referral.remaining == 0) {
          expect(referralItem.rewardPoints, isNull);
          expect(referralItem.subtitle, contains('모두 받았어요'));
        }
      }
    },
  );

  test(
    'empty and already-made months remain browsable without an automatic trigger',
    () async {
      for (final journal in [
        _journal(records: []),
        _journal(records: [_record(photos: 0)]),
        _journal(albumId: 42),
        _journal(month: DateTime.utc(2026, 9)),
      ]) {
        final items = await _container(
          journal: journal,
        ).read(homeNewsCatalogProvider.future);
        final review = items.singleWhere(
          (item) => item.kind == HomeNewsKind.monthReview,
        );
        expect(review.autoEligible, isFalse);
        if (journal.monthlyAlbumId != null) {
          expect(review.actionLabel, '이번 달 앨범 보기');
        } else {
          expect(review.covers, isEmpty);
          expect(review.actionLabel, '나의 기록 시작하기');
        }
      }
    },
  );

  test(
    'outside the last seven days a private journal is never requested',
    () async {
      var reads = 0;
      final container = _container(
        state: _state(date: DateTime.utc(2026, 10, 24)),
        loadJournal: (_) async {
          reads++;
          return _journal();
        },
      );
      final items = await container.read(homeNewsCatalogProvider.future);
      expect(reads, 0);
      final review = items.singleWhere(
        (item) => item.kind == HomeNewsKind.monthReview,
      );
      expect(review.autoEligible, isFalse);
      expect(review.covers, isEmpty);
      expect(review.actionLabel, '나의 기록 시작하기');
    },
  );

  test(
    'last-seven-day eligibility includes short and leap February boundaries',
    () {
      for (final (date, eligible) in [
        (DateTime.utc(2027, 2, 21), false),
        (DateTime.utc(2027, 2, 22), true),
        (DateTime.utc(2027, 2, 28), true),
        (DateTime.utc(2028, 2, 22), false),
        (DateTime.utc(2028, 2, 23), true),
        (DateTime.utc(2028, 2, 29), true),
        (DateTime.utc(2026, 10, 24), false),
        (DateTime.utc(2026, 10, 25), true),
      ]) {
        expect(isHomeNewsMonthEnd(date), eligible, reason: '$date');
      }
    },
  );

  test(
    'manual catalogue retains dismissed stories despite automatic caps',
    () async {
      final state = _state(
        history: [
          HomeNewsExposure(
            id: 'month-review:2026-10',
            kind: HomeNewsKind.monthReview,
            month: momentMonth(_today),
            shownAt: _today.add(const Duration(hours: 2)),
            dismissedAt: _today.add(const Duration(hours: 2, minutes: 10)),
          ),
          HomeNewsExposure(
            id: 'monthly-design:2026-10',
            kind: HomeNewsKind.monthlyDesign,
            month: momentMonth(_today),
            shownAt: _today.subtract(const Duration(hours: 21)),
            dismissedAt: _today.subtract(const Duration(hours: 20)),
          ),
        ],
      );
      expect(state.canAutoShow, isFalse);
      expect(state.hasSeen('month-review:2026-10'), isTrue);
      final items = await _container(
        state: state,
      ).read(homeNewsCatalogProvider.future);
      expect(
        items.map((item) => item.id),
        containsAll(['month-review:2026-10', 'monthly-design:2026-10']),
      );
    },
  );

  test(
    'remote switches and schedules omit stories and skip private source reads',
    () async {
      var attendanceReads = 0, referralReads = 0, journalReads = 0;
      final state = _state(
        campaigns: [
          const HomeNewsCampaign(
            kind: HomeNewsKind.monthReview,
            enabled: false,
            sortOrder: 0,
          ),
          const HomeNewsCampaign(
            kind: HomeNewsKind.monthlyDesign,
            sortOrder: 1,
          ),
          HomeNewsCampaign(
            kind: HomeNewsKind.attendance,
            startsAt: _today.add(const Duration(days: 1)),
            sortOrder: 2,
          ),
          HomeNewsCampaign(
            kind: HomeNewsKind.referral,
            endsAt: _today,
            sortOrder: 3,
          ),
        ],
      );
      final container = _container(
        state: state,
        loadAttendance: () async {
          attendanceReads++;
          return _attendance();
        },
        loadReferral: () async {
          referralReads++;
          return _referral();
        },
        loadJournal: (_) async {
          journalReads++;
          return _journal();
        },
      );
      final items = await container.read(homeNewsCatalogProvider.future);
      expect(items.map((item) => item.kind), [HomeNewsKind.monthlyDesign]);
      expect([attendanceReads, referralReads, journalReads], [0, 0, 0]);
    },
  );

  test(
    'remote ordering and active switches refresh in the existing session',
    () async {
      var current = _state(
        campaigns: [
          for (final campaign in defaultHomeNewsCampaigns)
            HomeNewsCampaign(
              kind: campaign.kind,
              sortOrder: campaign.kind == HomeNewsKind.referral
                  ? -1
                  : campaign.sortOrder,
            ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          homeNewsCurrentOwnerProvider.overrideWithValue('owner'),
          homeNewsExposureStateProvider.overrideWith((_) async => current),
          homeNewsDesignsProvider.overrideWith((_) async => _designs()),
          attendanceStatusProvider.overrideWith((_) async => _attendance()),
          referralStatusProvider.overrideWith((_) async => _referral()),
          momentsMonthProvider.overrideWith((_, __) async => _journal()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeNewsCatalogProvider, (_, __) {});
      final first = await container.read(homeNewsCatalogProvider.future);
      expect(first.first.kind, HomeNewsKind.referral);
      current = _state(
        campaigns: [
          for (final campaign in defaultHomeNewsCampaigns)
            HomeNewsCampaign(
              kind: campaign.kind,
              enabled: campaign.kind != HomeNewsKind.referral,
              sortOrder: campaign.sortOrder,
            ),
        ],
      );
      container.invalidate(homeNewsExposureStateProvider);
      final updated = await container.read(homeNewsCatalogProvider.future);
      expect(
        updated.map((item) => item.kind),
        isNot(contains(HomeNewsKind.referral)),
      );
    },
  );

  test(
    'optional source outages never invent reward amounts or private photos',
    () async {
      final items = await _container(
        loadAttendance: () => Future.error(StateError('offline')),
        loadReferral: () => Future.error(StateError('offline')),
        loadJournal: (_) => Future.error(StateError('offline')),
      ).read(homeNewsCatalogProvider.future);
      expect(items.length, 4);
      for (final item in items.where(
        (item) => item.kind != HomeNewsKind.monthlyDesign,
      )) {
        expect(item.autoEligible, isFalse);
        expect(item.rewardPoints, isNull);
        expect(item.covers, isEmpty);
      }
    },
  );

  test('a replacement account never receives a late private journal', () async {
    final oldJournal = Completer<MomentJournal>();
    final requested = Completer<void>();
    final observed = <List<HomeNewsItem>>[];
    final container = ProviderContainer(
      overrides: [
        homeNewsCurrentOwnerProvider.overrideWith(
          (ref) => ref.watch(_testOwnerProvider),
        ),
        homeNewsExposureStateProvider.overrideWith((_) async => _state()),
        homeNewsDesignsProvider.overrideWith((_) async => const []),
        attendanceStatusProvider.overrideWith((_) async => _attendance()),
        referralStatusProvider.overrideWith((_) async => _referral()),
        momentsMonthProvider.overrideWith((ref, _) {
          final owner = ref.watch(_testOwnerProvider);
          if (owner == 'owner-a') {
            if (!requested.isCompleted) requested.complete();
            return oldJournal.future;
          }
          return Future.value(_journal(records: [_record(owner: 'owner-b')]));
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeNewsCatalogProvider, (_, next) {
      final data = next.asData?.value;
      if (data != null) observed.add(data);
    });
    final firstRequest = container.read(homeNewsCatalogProvider.future);
    await requested.future;
    container.read(_testOwnerProvider.notifier).change('owner-b');
    await container.pump();
    final current = await container.read(homeNewsCatalogProvider.future);
    expect(current.first.covers.single.url, contains('owner-b/moments/'));

    oldJournal.complete(_journal(records: [_record(owner: 'owner-a')]));
    final firstResult = await firstRequest;
    await container.pump();
    final allCovers = [
      ...firstResult,
      for (final snapshot in observed) ...snapshot,
      ...await container.read(homeNewsCatalogProvider.future),
    ].expand((item) => item.covers).map((cover) => cover.url);
    expect(allCovers.any((url) => url.contains('owner-a/moments/')), isFalse);
  });

  test(
    'monthly designs only contain active products with valid quoted prices',
    () async {
      PointShopProduct product(
        String key, {
        bool active = true,
        int? price = 0,
      }) => PointShopProduct(
        productKey: 'template:$key',
        kind: 'template',
        assetId: key,
        title: key,
        pointPrice: price,
        isActive: active,
      );
      final container = ProviderContainer(
        overrides: [
          homeNewsExposureStateProvider.overrideWith(
            (_) async => _state(date: DateTime.utc(2026, 11, 10)),
          ),
          pointShopCatalogProvider.overrideWith(
            (_) async => [
              product('alley-afternoon'),
              product('taste-archive', price: 1800),
              product('our-family-year', active: false),
              product('a-day-with-you', price: null),
              product('seasonal-table', price: -1),
              product('unpublished-design'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(homeNewsDesignsProvider, (_, _) {});
      final designs = await container.read(homeNewsDesignsProvider.future);
      expect(
        designs.map((template) => template.id),
        unorderedEquals([-9471, -9422]),
      );
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/attendance/data/attendance_repository.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';
import 'package:snap_fit/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:snap_fit/features/attendance/presentation/views/attendance_screen.dart';
import 'package:snap_fit/features/home_news/data/home_news_repository.dart';
import 'package:snap_fit/features/home_news/data/home_news_today_store.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_today_providers.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/home_news_navigation.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/home_news/presentation/views/monthly_designs_screen.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/moments_navigation.dart';
import 'package:snap_fit/features/moments/presentation/views/monthly_moment_preview_screen.dart';
import 'package:snap_fit/features/referral/data/referral_repository.dart';
import 'package:snap_fit/features/referral/domain/referral_status.dart';
import 'package:snap_fit/features/referral/presentation/providers/referral_providers.dart';
import 'package:snap_fit/features/referral/presentation/views/referral_screen.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

final _ownerProvider = StateProvider<String?>((_) => 'owner');
final _today = DateTime.utc(2026, 10, 27);
final _month = DateTime.utc(2026, 10);
const _asset = 'asset:assets/snapfit_home_square.jpg';

HomeNewsExposureState _state({bool hidden = false}) => HomeNewsExposureState(
  hiddenForToday: hidden,
  hiddenUntil: hidden ? _today.add(const Duration(hours: 15)) : null,
  serverNow: _today.add(const Duration(hours: 3)),
  serverDate: _today,
  weekStart: DateTime.utc(2026, 10, 26),
  dailyCount: 1,
  weeklyCount: 2,
  history: [
    HomeNewsExposure(
      id: 'monthly-design:2026-10',
      kind: HomeNewsKind.monthlyDesign,
      month: _month,
      shownAt: _today.add(const Duration(hours: 2)),
    ),
    HomeNewsExposure(
      id: 'referral-benefit:v1',
      kind: HomeNewsKind.referral,
      month: _month,
      shownAt: _today.subtract(const Duration(hours: 22)),
    ),
  ],
);

HomeNewsItem _item(HomeNewsKind kind) => HomeNewsItem(
  id: switch (kind) {
    HomeNewsKind.monthlyDesign => 'monthly-design:2026-10',
    HomeNewsKind.attendance => 'attendance-benefit:v1',
    HomeNewsKind.referral => 'referral-benefit:v1',
    HomeNewsKind.monthReview => 'month-review:2026-10',
  },
  kind: kind,
  title: '지금 만나볼 스냅핏의 소식',
  subtitle: '사진과 함께 남기는 이번 달의 순간',
  actionLabel: '소식 자세히 보기',
  month: _month,
  rewardPoints: kind == HomeNewsKind.attendance ? 10 : 100,
  covers: const [HomeNewsCover(url: _asset, ratio: 1)],
);

class _NewsRepository
    implements
        HomeNewsRepository,
        HomeNewsDeliveryRepository,
        HomeNewsTodayRepository {
  String? owner = 'owner';
  final claims = <String>[];
  final interactions = <({String id, HomeNewsInteraction interaction})>[];
  final views = <({String deliveryId, String campaignId})>[];
  Completer<bool>? pendingView;
  int hides = 0;
  bool hideFails = false;
  Completer<HomeNewsExposureState>? pendingHide;

  @override
  Future<HomeNewsExposureState> hideForToday() async {
    hides++;
    if (hideFails) throw StateError('offline');
    return pendingHide?.future ?? _state(hidden: true);
  }

  @override
  Future<HomeNewsDeliveryClaim> claimDelivery(List<String> campaignIds) async =>
      const HomeNewsDeliveryClaim(claimed: false);

  @override
  Future<bool> recordDeliveryView(String deliveryId, String campaignId) {
    views.add((deliveryId: deliveryId, campaignId: campaignId));
    return pendingView?.future ?? Future.value(true);
  }

  @override
  String? get currentUserId => owner;
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<HomeNewsExposureState> getExposureState() async => _state();
  @override
  Future<List<HomeNewsExposure>> getHistory() async => const [];
  @override
  Future<bool> claimExposure(String campaignId) async {
    claims.add(campaignId);
    return true;
  }

  @override
  Future<void> recordInteraction(
    String campaignId,
    HomeNewsInteraction interaction,
  ) async => interactions.add((id: campaignId, interaction: interaction));
}

class _AttendanceRepository implements AttendanceRepository {
  int reads = 0, claims = 0;
  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<AttendanceStatus> fetchStatus() async {
    reads++;
    return AttendanceStatus.fromJson({
      'serverTime': '2026-10-27T03:00:00Z',
      'serverDate': '2026-10-27',
      'timezone': 'Asia/Seoul',
      'nextResetAt': '2026-10-27T15:00:00Z',
      'checkedInToday': false,
      'currentStreak': 0,
      'cycleDay': 1,
      'todayReward': 10,
      'weeklyRewards': [10, 10, 20, 10, 10, 10, 30],
      'month': '2026-10',
      'monthPoints': 0,
      'monthAttendanceCount': 0,
      'history': [],
      'claimed': false,
      'awardedPoints': 0,
      'balance': 500,
    });
  }

  @override
  Future<AttendanceStatus> claim() {
    claims++;
    return fetchStatus();
  }
}

class _ReferralRepository implements ReferralRepository {
  int reads = 0, redemptions = 0;
  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<ReferralStatus> fetchStatus() async {
    reads++;
    return ReferralStatus.fromJson({
      'ownCode': 'ABCD2345XY',
      'inviterPoints': 100,
      'inviteePoints': 100,
      'registrationWindowDays': 7,
      'rewardLimit': 20,
      'monthlyRewardedCount': 0,
      'remaining': 20,
      'invitedCount': 0,
      'totalEarned': 0,
      'balance': 500,
      'canRedeem': true,
      'redeemed': false,
      'eligibleUntil': '2026-11-03T03:00:00Z',
      'serverTime': '2026-10-27T03:00:00Z',
      'claimed': false,
      'awardedPoints': 0,
      'rewardMonth': '2026-10',
      'timezone': 'Asia/Seoul',
      'ineligibleReason': null,
    });
  }

  @override
  Future<ReferralStatus> redeem(String code) {
    redemptions++;
    return fetchStatus();
  }
}

class _MomentsRepository implements MomentsRepository {
  int reads = 0, creates = 0, appends = 0;
  final fetchedAlbums = <int>[];
  final records = [
    MomentRecord(
      id: 'saved-record',
      recordDate: DateTime.utc(2026, 10, 8),
      caption: '간직한 사진',
      revision: 2,
      photos: const [
        MomentPhoto(
          id: 'saved-photo',
          path: 'owner/moments/saved-photo.jpg',
          url: _asset,
          width: 600,
          height: 600,
        ),
      ],
    ),
  ];

  MomentJournal get journal => MomentJournal(
    today: _today,
    weekStart: DateTime.utc(2026, 10, 26),
    month: _month,
    records: records,
    weekPhotoCount: 0,
    monthlyAlbumId: 42,
    monthlyAlbumPhotoIds: const ['saved-photo'],
  );

  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<MomentJournal> listMonth(DateTime? month) async {
    reads++;
    return journal;
  }

  @override
  Future<Album> fetchAlbum(int id) async {
    fetchedAlbums.add(id);
    return Album(
      id: id,
      userId: 'owner',
      title: '이미 만든 10월 앨범',
      coverLayersJson:
          '{"pages":[{"isCover":true,"backgroundColor":4294967295,"layers":[]}]}',
    );
  }

  @override
  Future<Album> createMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
    required String title,
  }) async {
    creates++;
    throw StateError('Navigation must not create an album.');
  }

  @override
  Future<Album> appendMonthlyAlbum({
    required DateTime month,
    required List<MomentRecord> selectedRecords,
    required List<String> selectedPhotoIds,
  }) async {
    appends++;
    throw StateError('Navigation must not append album pages.');
  }

  @override
  Future<void> delete(MomentRecord record) async =>
      throw StateError('Navigation must not delete a record.');

  @override
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  }) async => throw StateError('Navigation must not change a record.');
}

class _EngagementRepository implements MomentEngagementRepository {
  @override
  Future<MomentEngagement> load() async =>
      const MomentEngagement(reminder: MomentReminder(), hasRecords: true);
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async => true;
  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) async =>
      MomentEngagement(reminder: reminder, hasRecords: true);
}

class _Observer extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
}

class _Harness extends ConsumerWidget {
  const _Harness(this.item, {this.items, this.automatic = false});
  final HomeNewsItem item;
  final List<HomeNewsItem>? items;
  final bool automatic;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open-manual-home-news'),
        onPressed: () async => openHomeNews(
          context,
          ref,
          item,
          automatic: automatic,
          carouselItems: items,
          deliveryId: automatic ? '11111111-1111-4111-8111-111111111111' : null,
        ),
        child: const Text('소식 다시 보기'),
      ),
    ),
  );
}

class _TodayStore implements HomeNewsTodayStore {
  final values = <String, DateTime>{};
  final writes = <String>[];
  @override
  Future<DateTime?> readUntil(String owner) async => values[owner];
  @override
  void rememberUntil(String owner, DateTime until) => values[owner] = until;
  @override
  Future<void> persistUntil(String owner, DateTime until) async {
    values[owner] = until;
    writes.add(owner);
  }
}

class _Fixture {
  _Fixture(this.item, {List<HomeNewsItem>? items, this.automatic = false}) {
    catalog = List.of(items ?? [item]);
    container = ProviderContainer(
      overrides: [
        homeNewsCurrentOwnerProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        homeNewsRepositoryProvider.overrideWithValue(news),
        homeNewsTodayStoreProvider.overrideWithValue(todayStore),
        homeNewsExposureStateProvider.overrideWith((ref) async => _state()),
        homeNewsCatalogProvider.overrideWith((ref) async {
          await ref.watch(homeNewsExposureStateProvider.future);
          return List.of(catalog);
        }),
        homeNewsDesignsProvider.overrideWith(
          (_) async => [publishedCreationTemplateById(-9471)!],
        ),
        attendanceRepositoryProvider.overrideWithValue(attendance),
        referralRepositoryProvider.overrideWithValue(referral),
        momentsRepositoryProvider.overrideWithValue(moments),
        momentEngagementRepositoryProvider.overrideWithValue(
          _EngagementRepository(),
        ),
        momentDraftSummariesForOwnerProvider.overrideWith(
          (ref, owner) async => [],
        ),
      ],
    );
  }

  final HomeNewsItem item;
  final bool automatic;
  late List<HomeNewsItem> catalog;
  final news = _NewsRepository();
  final todayStore = _TodayStore();
  final attendance = _AttendanceRepository();
  final referral = _ReferralRepository();
  final moments = _MomentsRepository();
  final observer = _Observer();
  final navigator = GlobalKey<NavigatorState>();
  late final ProviderContainer container;

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: _Harness(item, items: catalog, automatic: automatic),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-manual-home-news')));
    await _settleImages(tester);
    expect(
      find.byKey(const ValueKey('home-news-action')).hitTestable(),
      findsOneWidget,
    );
    expect(news.claims, isEmpty);
  }

  Future<void> chooseAction(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('home-news-action')).hitTestable(),
    );
    await _settleImages(tester);
  }

  void expectReadOnly() {
    expect(news.claims, isEmpty);
    expect(attendance.claims, 0);
    expect(referral.redemptions, 0);
    expect(moments.creates, 0);
    expect(moments.appends, 0);
  }

  void expectClicked() => expect(news.interactions, [
    (id: item.id, interaction: HomeNewsInteraction.click),
  ]);
}

Future<void> _settleImages(WidgetTester tester) async {
  if (kIsWeb) {
    // Browser decoding needs rendered frames. Waiting on precacheImage while
    // the test frame clock is paused can leave the image future suspended.
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    return;
  }
  for (var frame = 0; frame < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        if (!image.urlOrGs.startsWith('asset:')) continue;
        await precacheImage(
          ResizeImage.resizeIfNeeded(
            image.memCacheWidth,
            image.memCacheHeight,
            AssetImage(image.urlOrGs.substring(6)),
          ),
          tester.element(find.byType(SnapfitImage).first),
        );
      }
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
          image.image,
          tester.element(find.byType(Image).first),
        );
      }
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual attendance story opens its route without claiming points',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.attendance));
      await fixture.mount(tester);
      await fixture.chooseAction(tester);

      expect(find.byType(AttendanceScreen), findsOneWidget);
      expect(
        (fixture.observer.pushes.last.settings as WebAppRouteSettings).location,
        WebAppLocation.attendance,
      );
      expect(fixture.attendance.reads, greaterThan(0));
      fixture.expectClicked();
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manual referral story opens its route without awarding points', (
    tester,
  ) async {
    final fixture = _Fixture(_item(HomeNewsKind.referral));
    await fixture.mount(tester);
    await fixture.chooseAction(tester);

    expect(find.byType(ReferralScreen), findsOneWidget);
    expect(
      (fixture.observer.pushes.last.settings as WebAppRouteSettings).location,
      WebAppLocation.referral,
    );
    expect(fixture.referral.reads, greaterThan(0));
    fixture.expectClicked();
    fixture.expectReadOnly();
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly design story opens the real curated design collection', (
    tester,
  ) async {
    final fixture = _Fixture(_item(HomeNewsKind.monthlyDesign));
    await fixture.mount(tester);
    await fixture.chooseAction(tester);

    expect(find.byType(MonthlyDesignsScreen), findsOneWidget);
    expect(find.text('이달의 디자인'), findsOneWidget);
    expect(find.byKey(const ValueKey('monthly-design--9471')), findsOneWidget);
    fixture.expectClicked();
    fixture.expectReadOnly();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'month review forwards a fresh journal and existing import guards',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.monthReview));
      await fixture.mount(tester);
      await fixture.chooseAction(tester);

      final preview = tester.widget<MonthlyMomentPreviewScreen>(
        find.byType(MonthlyMomentPreviewScreen),
      );
      expect(preview.month, fixture.moments.journal.month);
      expect(preview.today, fixture.moments.journal.today);
      expect(preview.records, same(fixture.moments.records));
      expect(preview.existingAlbumId, 42);
      expect(preview.importedPhotoIds, ['saved-photo']);
      expect(fixture.moments.reads, greaterThan(0));
      expect(fixture.moments.fetchedAlbums, [42]);
      fixture.expectClicked();
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in HomeNewsKind.values) {
    testWidgets('four-story carousel selects the ${kind.name} destination', (
      tester,
    ) async {
      final items = HomeNewsKind.values.map(_item).toList();
      final fixture = _Fixture(items.first, items: items);
      await fixture.mount(tester);
      expect(find.text('1 / 4').hitTestable(), findsOneWidget);
      final index = items.indexWhere((item) => item.kind == kind);
      for (var page = 0; page < index; page++) {
        await tester.drag(
          find.byKey(const ValueKey('home-news-pages')),
          const Offset(-350, 0),
        );
        await _settleImages(tester);
      }
      expect(find.text('${index + 1} / 4').hitTestable(), findsOneWidget);
      await fixture.chooseAction(tester);
      switch (kind) {
        case HomeNewsKind.monthlyDesign:
          expect(find.byType(MonthlyDesignsScreen), findsOneWidget);
        case HomeNewsKind.attendance:
          expect(find.byType(AttendanceScreen), findsOneWidget);
        case HomeNewsKind.referral:
          expect(find.byType(ReferralScreen), findsOneWidget);
        case HomeNewsKind.monthReview:
          expect(find.byType(MonthlyMomentPreviewScreen), findsOneWidget);
      }
      expect(fixture.news.interactions, [
        (id: items[index].id, interaction: HomeNewsInteraction.click),
      ]);
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'switching a campaign off while the sheet is open blocks its CTA',
    (tester) async {
      final fixture = _Fixture(
        _item(HomeNewsKind.attendance),
        items: [_item(HomeNewsKind.attendance), _item(HomeNewsKind.referral)],
      );
      await fixture.mount(tester);
      fixture.catalog = [_item(HomeNewsKind.referral)];
      await fixture.chooseAction(tester);
      expect(find.byType(AttendanceScreen), findsNothing);
      expect(find.byType(ReferralScreen), findsNothing);
      expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
      expect(find.text('종료된 소식이에요. 다른 소식을 확인해 주세요.'), findsOneWidget);
      expect(
        fixture.container.read(homeNewsPresentationCoordinatorProvider).busy,
        false,
      );
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a month story without saved photographs opens the real moments destination',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.monthReview));
      fixture.moments.records.clear();
      await fixture.mount(tester);
      await fixture.chooseAction(tester);
      expect(find.byType(MomentsDestination), findsOneWidget);
      expect(find.byType(MonthlyMomentPreviewScreen), findsNothing);
      expect(
        (fixture.observer.pushes.last.settings as WebAppRouteSettings).location,
        WebAppLocation.moments,
      );
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in [false, true]) {
    testWidgets(
      'pending delivery tracking does not delay ${action ? 'navigation' : 'closing'}',
      (tester) async {
        final fixture = _Fixture(
          _item(HomeNewsKind.attendance),
          automatic: true,
          items: [_item(HomeNewsKind.attendance), _item(HomeNewsKind.referral)],
        );
        final pending = Completer<bool>();
        fixture.news.pendingView = pending;
        await fixture.mount(tester);
        expect(fixture.news.views, hasLength(1));
        if (action) {
          await fixture.chooseAction(tester);
          expect(find.byType(AttendanceScreen), findsOneWidget);
        } else {
          await tester.tap(
            find.byKey(const ValueKey('home-news-close')).hitTestable(),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
          expect(
            fixture.container
                .read(homeNewsPresentationCoordinatorProvider)
                .busy,
            false,
          );
        }
        expect(fixture.news.interactions, isEmpty);
        pending.complete(true);
        await tester.pumpAndSettle();
        expect(fixture.news.interactions, [
          (
            id: fixture.item.id,
            interaction: action
                ? HomeNewsInteraction.click
                : HomeNewsInteraction.dismiss,
          ),
        ]);
        fixture.expectReadOnly();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dismissing a replay records dismissal and opens no destination',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.attendance));
      await fixture.mount(tester);
      await tester.tap(find.byKey(const ValueKey('home-news-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
      expect(find.byType(AttendanceScreen), findsNothing);
      expect(find.byType(ReferralScreen), findsNothing);
      expect(find.byType(MonthlyDesignsScreen), findsNothing);
      expect(find.byType(MonthlyMomentPreviewScreen), findsNothing);
      expect(
        fixture.observer.pushes.whereType<MaterialPageRoute>(),
        hasLength(1),
      );
      expect(fixture.news.interactions, [
        (id: fixture.item.id, interaction: HomeNewsInteraction.dismiss),
      ]);
      expect(
        fixture.container.read(homeNewsPresentationCoordinatorProvider).busy,
        isFalse,
      );
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'today text closes immediately, persists to server and device, and manual replay stays available',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.attendance));
      await fixture.mount(tester);
      await tester.tap(find.text('오늘 하루 안 보기').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
      expect(fixture.news.hides, 1);
      expect(
        fixture.todayStore.values['owner'],
        _today.add(const Duration(hours: 15)),
      );
      expect(
        await fixture.container.read(homeNewsTodayHiddenProvider.future),
        isTrue,
      );
      expect(fixture.news.interactions, isEmpty);
      expect(
        fixture.container.read(homeNewsPresentationCoordinatorProvider).busy,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('open-manual-home-news')));
      await _settleImages(tester);
      expect(find.text('오늘 하루 안 보기').hitTestable(), findsOneWidget);
      fixture.expectReadOnly();
    },
  );

  testWidgets(
    'offline today-hide still suppresses locally without delaying closing',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.attendance));
      fixture.news.hideFails = true;
      await fixture.mount(tester);
      await tester.tap(find.text('오늘 하루 안 보기').hitTestable());
      await tester.pumpAndSettle();
      expect(
        await fixture.container.read(homeNewsTodayHiddenProvider.future),
        isTrue,
      );
      expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
      expect(
        fixture.container.read(homeNewsPresentationCoordinatorProvider).busy,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late hide response cannot suppress a replacement account', (
    tester,
  ) async {
    final fixture = _Fixture(_item(HomeNewsKind.attendance));
    final pending = Completer<HomeNewsExposureState>();
    fixture.news.pendingHide = pending;
    await fixture.mount(tester);
    await tester.tap(find.text('오늘 하루 안 보기').hitTestable());
    await tester.pumpAndSettle();
    fixture.news.owner = 'replacement';
    fixture.container.read(_ownerProvider.notifier).state = 'replacement';
    pending.complete(_state(hidden: true));
    await tester.pumpAndSettle();
    expect(fixture.todayStore.values['owner'], isNotNull);
    expect(fixture.todayStore.values['replacement'], isNull);
    expect(
      await fixture.container.read(homeNewsTodayHiddenProvider.future),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing accounts removes the manual private sheet immediately',
    (tester) async {
      final fixture = _Fixture(_item(HomeNewsKind.monthReview));
      await fixture.mount(tester);
      fixture.news.owner = 'replacement';
      fixture.container.read(_ownerProvider.notifier).state = 'replacement';
      await tester.pump();

      expect(find.byKey(const ValueKey('home-news-action')), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(MonthlyMomentPreviewScreen), findsNothing);
      expect(fixture.news.interactions, isEmpty);
      fixture.expectReadOnly();
      expect(tester.takeException(), isNull);
    },
  );
}

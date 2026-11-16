import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/home_news/data/home_news_repository.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_today_providers.dart';
import 'package:snap_fit/features/onboarding/presentation/widgets/first_home_guide.dart';
import 'package:snap_fit/features/home_news/presentation/widgets/home_news_gate.dart';
import 'package:snap_fit/features/home_news/presentation/views/monthly_designs_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';

import '../helpers/first_visit_fixtures.dart';

final _ownerProvider = StateProvider<String?>((ref) => null);
final _recoveryProvider = StateProvider<bool>((ref) => false);
final _localHiddenProvider = StateProvider<bool>((ref) => false);
final _exposureProvider = StateProvider<HomeNewsExposureState>(
  (ref) => _state(),
);
final _catalogProvider = StateProvider<List<HomeNewsItem>>((ref) => [_item()]);
final _monthlySheet = find.byKey(const ValueKey('home-news-monthlyDesign'));
final _reviewSheet = find.byKey(const ValueKey('home-news-monthReview'));

HomeNewsExposureState _state({
  int daily = 0,
  int weekly = 0,
  bool hidden = false,
  List<HomeNewsExposure> history = const [],
}) => HomeNewsExposureState(
  serverNow: DateTime.utc(2026, 10, 27, 3),
  serverDate: DateTime.utc(2026, 10, 27),
  weekStart: DateTime.utc(2026, 10, 26),
  dailyCount: daily,
  weeklyCount: weekly,
  history: history,
  hiddenForToday: hidden,
);

HomeNewsItem _item({
  HomeNewsKind kind = HomeNewsKind.monthlyDesign,
  bool autoEligible = true,
}) => HomeNewsItem(
  id: kind == HomeNewsKind.monthReview
      ? 'month-review:2026-10'
      : 'monthly-design:2026-10',
  kind: kind,
  autoEligible: autoEligible,
  title: kind == HomeNewsKind.monthReview ? '10월의 순간을 한 권으로' : '가을의 순간을 한 권으로',
  subtitle: '사진을 크게 담는 스냅핏의 앨범',
  actionLabel: '디자인 둘러보기',
  month: DateTime.utc(2026, 10),
  covers: const [
    HomeNewsCover(url: 'asset:assets/snapfit_home_square.jpg', ratio: 1),
  ],
);

class _Repository implements HomeNewsRepository, HomeNewsDeliveryRepository {
  _Repository(this.owner);

  String? owner;
  bool canClaim = true;
  Completer<bool>? pendingClaim;
  final claims = <String>[];
  final interactions = <String>[];
  final deliveries = <List<String>>[];
  final views = <String>[];

  @override
  Future<HomeNewsDeliveryClaim> claimDelivery(List<String> ids) async {
    deliveries.add(ids);
    final claimed = await claimExposure(ids.first);
    return HomeNewsDeliveryClaim(
      claimed: claimed,
      deliveryId: claimed ? "11111111-1111-4111-8111-111111111111" : null,
      campaignIds: claimed ? ids : const [],
    );
  }

  @override
  Future<bool> recordDeliveryView(String deliveryId, String id) async {
    views.add(id);
    return true;
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
    return pendingClaim == null ? canClaim : pendingClaim!.future;
  }

  @override
  Future<void> recordInteraction(
    String campaignId,
    HomeNewsInteraction interaction,
  ) async => interactions.add('$campaignId:${interaction.name}');
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.navigatorKey,
    this.initiallyActive = true,
    this.respectFirstVisitGuide = false,
    this.mountGuideAnchor = true,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final bool initiallyActive;
  final bool respectFirstVisitGuide;
  final bool mountGuideAnchor;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late bool active = widget.initiallyActive;
  int generation = 0;

  void setActive(bool value) => setState(() => active = value);
  void remount() => setState(() => generation++);
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: widget.navigatorKey,
    home: Scaffold(
      body: HomeNewsGate(
        key: ValueKey(generation),
        active: active,
        respectFirstVisitGuide: widget.respectFirstVisitGuide,
        child: Center(
          child: widget.respectFirstVisitGuide && widget.mountGuideAnchor
              ? FirstHomeGuide(onRecord: () {}, onCreate: () {})
              : const Text('내 앨범 메인'),
        ),
      ),
    ),
  );
}

class _Fixture {
  _Fixture({
    required String owner,
    HomeNewsExposureState? exposure,
    List<HomeNewsItem>? items,
    bool recoveryBlocked = false,
    bool locallyHidden = false,
    this.initiallyActive = true,
    this.respectFirstVisitGuide = false,
    this.mountGuideAnchor = true,
    int firstVisitFlags = 3,
  }) : repository = _Repository(owner) {
    container = ProviderContainer(
      overrides: [
        _ownerProvider.overrideWith((ref) => owner),
        _recoveryProvider.overrideWith((ref) => recoveryBlocked),
        _localHiddenProvider.overrideWith((ref) => locallyHidden),
        _exposureProvider.overrideWith((ref) => exposure ?? _state()),
        _catalogProvider.overrideWith((ref) => items ?? [_item()]),
        homeNewsCurrentOwnerProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        homeNewsExposureStateProvider.overrideWith((ref) async {
          ref.watch(_ownerProvider);
          return ref.watch(_exposureProvider);
        }),
        homeNewsCatalogProvider.overrideWith((ref) async {
          ref.watch(_ownerProvider);
          return ref.watch(_catalogProvider);
        }),
        homeNewsRecoveryBlockProvider.overrideWith(
          (ref) async => ref.watch(_recoveryProvider),
        ),
        homeNewsDesignsProvider.overrideWith((ref) async => const []),
        homeNewsTodayHiddenProvider.overrideWith(
          (ref) async => ref.watch(_localHiddenProvider),
        ),
        homeNewsRepositoryProvider.overrideWithValue(repository),
        homeNewsReadyDelayProvider.overrideWithValue(Duration.zero),
        firstVisitStoreProvider.overrideWithValue(
          MemoryFirstVisitStore(firstVisitFlags),
        ),
      ],
    );
  }

  late final ProviderContainer container;
  final _Repository repository;
  final bool initiallyActive;
  final bool respectFirstVisitGuide;
  final bool mountGuideAnchor;
  final navigatorKey = GlobalKey<NavigatorState>();
  final harnessKey = GlobalKey<_HarnessState>();

  void switchOwner(String? owner) {
    repository.owner = owner;
    container.read(_ownerProvider.notifier).state = owner;
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Harness(
          key: harnessKey,
          navigatorKey: navigatorKey,
          initiallyActive: initiallyActive,
          respectFirstVisitGuide: respectFirstVisitGuide,
          mountGuideAnchor: mountGuideAnchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void pushOtherRoute() => navigatorKey.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (context) =>
          const Scaffold(body: Center(child: Text('다른 화면 유지'))),
    ),
  );
}

void main() {
  testWidgets('home shows one claimed sheet and close records dismissal', (
    tester,
  ) async {
    final fixture = _Fixture(owner: 'gate-show-owner');
    await fixture.mount(tester);
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, ['monthly-design:2026-10']);
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsNothing);
    expect(fixture.repository.interactions, ['monthly-design:2026-10:dismiss']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one delivery preserves configured card order and tracks actual swipes',
    (tester) async {
      final fixture = _Fixture(
        owner: 'carousel-owner',
        items: [
          _item(kind: HomeNewsKind.monthReview, autoEligible: false),
          _item(),
        ],
      );
      await fixture.mount(tester);
      expect(fixture.repository.deliveries, [
        ['month-review:2026-10', 'monthly-design:2026-10'],
      ]);
      expect(fixture.repository.views, ['month-review:2026-10']);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('home-news-pages')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(fixture.repository.views, [
        'month-review:2026-10',
        'monthly-design:2026-10',
      ]);
      expect(fixture.repository.claims.length, 1);
      await tester.tap(
        find.byKey(const ValueKey('home-news-close')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(fixture.repository.interactions, [
        'monthly-design:2026-10:dismiss',
      ]);
    },
  );

  testWidgets('completed or generic stories also show on main entry', (
    tester,
  ) async {
    final fixture = _Fixture(
      owner: 'no-trigger-owner',
      items: [
        _item(autoEligible: false),
        _item(kind: HomeNewsKind.monthReview, autoEligible: false),
      ],
    );
    await fixture.mount(tester);
    expect(fixture.repository.deliveries, hasLength(1));
    expect(find.byKey(const ValueKey('home-news-carousel')), findsOneWidget);
  });

  testWidgets('old daily and weekly counts do not suppress main entry', (
    tester,
  ) async {
    for (final (owner, exposure) in [
      ('gate-daily-owner', _state(daily: 1, weekly: 1)),
      ('gate-weekly-owner', _state(weekly: 2)),
    ]) {
      final fixture = _Fixture(owner: owner, exposure: exposure);
      await fixture.mount(tester);
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'saved-work recovery defers the same entry until recovery clears',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-recovery-owner',
        recoveryBlocked: true,
      );
      await fixture.mount(tester);
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, isEmpty);
      fixture.container.read(_recoveryProvider.notifier).state = false;
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets(
    'the actual first-visit guide closes before deferred news opens',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-guide-owner',
        respectFirstVisitGuide: true,
        firstVisitFlags: 1,
      );
      await fixture.mount(tester);
      expect(find.byKey(const ValueKey('first-home-guide')), findsOneWidget);
      expect(fixture.container.read(firstHomeGuideVisibleProvider), isTrue);
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, isEmpty);
      await tester.tap(find.byTooltip('안내 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets('old introduction flags cannot suppress required main news', (
    tester,
  ) async {
    final fixture = _Fixture(
      owner: 'gate-old-intro-owner',
      respectFirstVisitGuide: true,
      firstVisitFlags: 0,
    );
    await fixture.mount(tester);
    expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, hasLength(1));
  });

  testWidgets(
    'a pending guide whose anchor is not mounted cannot suppress news',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-unmounted-guide-owner',
        respectFirstVisitGuide: true,
        mountGuideAnchor: false,
        firstVisitFlags: 1,
      );
      await fixture.mount(tester);
      expect(
        (await fixture.container.read(
          firstVisitProvider.future,
        )).shouldShowHomeGuide,
        isTrue,
      );
      expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets(
    'normal close stays closed through rebuilds and reopens on the next tab entry',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-tab-entry-owner');
      await fixture.mount(tester);
      await tester.tap(find.byKey(const ValueKey('home-news-close')));
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.rebuild();
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, hasLength(1));
      fixture.harnessKey.currentState!.setActive(false);
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(2));
    },
  );

  testWidgets('main remount and external route return each get a new popup', (
    tester,
  ) async {
    final fixture = _Fixture(owner: 'gate-remount-owner');
    await fixture.mount(tester);
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    fixture.harnessKey.currentState!.remount();
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    fixture.pushOtherRoute();
    await tester.pumpAndSettle();
    fixture.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, hasLength(3));
  });

  testWidgets(
    'today hidden by server or local storage suppresses later main entries',
    (tester) async {
      for (final fixture in [
        _Fixture(owner: 'server-hidden-owner', exposure: _state(hidden: true)),
        _Fixture(owner: 'local-hidden-owner', locallyHidden: true),
      ]) {
        await fixture.mount(tester);
        expect(_monthlySheet, findsNothing);
        fixture.harnessKey.currentState!.setActive(false);
        await tester.pumpAndSettle();
        fixture.harnessKey.currentState!.setActive(true);
        await tester.pumpAndSettle();
        expect(_monthlySheet, findsNothing);
        expect(fixture.repository.claims, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'next Korean day removes yesterday suppression on the next entry',
    (tester) async {
      final fixture = _Fixture(
        owner: 'next-day-owner',
        exposure: _state(hidden: true),
      );
      await fixture.mount(tester);
      expect(_monthlySheet, findsNothing);
      fixture.harnessKey.currentState!.setActive(false);
      await tester.pumpAndSettle();
      fixture.container.read(_exposureProvider.notifier).state = _state();
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets('background return shows once and closing does not loop', (
    tester,
  ) async {
    final fixture = _Fixture(owner: 'gate-resume-owner');
    await fixture.mount(tester);
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('home-news-close')));
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsNothing);
    expect(fixture.repository.claims, hasLength(2));
  });

  testWidgets(
    'returning from a news destination shows one new popup and closing stays closed',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-own-action-owner');
      await fixture.mount(tester);
      await tester.tap(find.byKey(const ValueKey('home-news-action')));
      await tester.pumpAndSettle();
      expect(find.byType(MonthlyDesignsScreen), findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
      fixture.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('home-news-close')));
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.rebuild();
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, hasLength(2));
      fixture.harnessKey.currentState!.setActive(false);
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(3));
    },
  );

  testWidgets('a late login state still gets the first main popup', (
    tester,
  ) async {
    final fixture = _Fixture(owner: 'gate-late-owner');
    fixture.switchOwner(null);
    await fixture.mount(tester);
    expect(fixture.repository.claims, isEmpty);
    fixture.switchOwner('gate-late-owner');
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.claims, hasLength(1));
  });

  testWidgets('all events switched off produce no empty popup', (tester) async {
    final fixture = _Fixture(owner: 'all-off-owner', items: const []);
    await fixture.mount(tester);
    expect(_monthlySheet, findsNothing);
    expect(fixture.repository.claims, isEmpty);
  });

  testWidgets('a server rejection never opens a sheet', (tester) async {
    final fixture = _Fixture(owner: 'gate-claim-denied-owner');
    fixture.repository.canClaim = false;
    await fixture.mount(tester);
    expect(fixture.repository.claims, hasLength(1));
    expect(_monthlySheet, findsNothing);
    expect(fixture.repository.interactions, isEmpty);
  });

  testWidgets(
    'hidden home and a home covered by another route cannot claim or show',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-covered-owner',
        initiallyActive: false,
      );
      await fixture.mount(tester);
      expect(fixture.repository.claims, isEmpty);
      expect(_monthlySheet, findsNothing);
      fixture.pushOtherRoute();
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pumpAndSettle();
      expect(find.text('다른 화면 유지'), findsOneWidget);
      expect(fixture.repository.claims, isEmpty);
      expect(_monthlySheet, findsNothing);
      fixture.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets(
    'first activation after a hidden mount gets one delivery opportunity',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-first-activation-owner',
        initiallyActive: false,
      );
      await fixture.mount(tester);
      expect(fixture.repository.claims, isEmpty);
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets(
    'leaving during an awaited claim cancels it and returning starts a fresh visit',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-active-transition-owner');
      final reply = Completer<bool>();
      fixture.repository.pendingClaim = reply;
      await fixture.mount(tester);
      expect(fixture.repository.claims, hasLength(1));
      fixture.harnessKey.currentState!.setActive(false);
      await tester.pump();
      fixture.harnessKey.currentState!.setActive(true);
      await tester.pump();
      reply.complete(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsOneWidget);
      expect(fixture.repository.claims, hasLength(2));
    },
  );

  testWidgets('a pointer gesture does not cancel required main news', (
    tester,
  ) async {
    final fixture = _Fixture(owner: 'gate-pointer-cancel-owner');
    final reply = Completer<bool>();
    fixture.repository.pendingClaim = reply;
    await fixture.mount(tester);
    expect(fixture.repository.claims, hasLength(1));
    await tester.tap(find.text('내 앨범 메인'));
    reply.complete(true);
    await tester.pumpAndSettle();
    expect(_monthlySheet, findsOneWidget);
    expect(fixture.repository.interactions, isEmpty);
  });

  testWidgets(
    'account switch removes a private month-review sheet while preserving a covering route',
    (tester) async {
      final fixture = _Fixture(
        owner: 'gate-private-review-owner',
        items: [_item(kind: HomeNewsKind.monthReview)],
      );
      await fixture.mount(tester);
      expect(_reviewSheet, findsOneWidget);
      fixture.pushOtherRoute();
      await tester.pumpAndSettle();
      fixture.switchOwner(null);
      await tester.pumpAndSettle();
      expect(_reviewSheet, findsNothing);
      expect(find.text('다른 화면 유지'), findsOneWidget);
      expect(fixture.navigatorKey.currentState!.canPop(), isTrue);
      fixture.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('내 앨범 메인'), findsOneWidget);
      expect(_reviewSheet, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late successful claim from an old account never displays its content',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-late-claim-owner');
      final reply = Completer<bool>();
      fixture.repository.pendingClaim = reply;
      await fixture.mount(tester);
      expect(fixture.repository.claims, hasLength(1));
      fixture.switchOwner(null);
      reply.complete(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.interactions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

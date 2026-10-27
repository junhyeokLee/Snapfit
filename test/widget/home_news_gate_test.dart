import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/home_news/data/home_news_repository.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/home_news/presentation/widgets/home_news_gate.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';

import '../helpers/first_visit_fixtures.dart';

final _ownerProvider = StateProvider<String?>((ref) => null);
final _monthlySheet = find.byKey(const ValueKey('home-news-monthlyDesign'));
final _reviewSheet = find.byKey(const ValueKey('home-news-monthReview'));

HomeNewsExposureState _state({int daily = 0, int weekly = 0}) =>
    HomeNewsExposureState(
      serverNow: DateTime.utc(2026, 10, 27, 3),
      serverDate: DateTime.utc(2026, 10, 27),
      weekStart: DateTime.utc(2026, 10, 26),
      dailyCount: daily,
      weeklyCount: weekly,
      history: const [],
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
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final bool initiallyActive;
  final bool respectFirstVisitGuide;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late bool active = widget.initiallyActive;
  int generation = 0;

  void setActive(bool value) => setState(() => active = value);
  void remount() => setState(() => generation++);

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: widget.navigatorKey,
    home: Scaffold(
      body: HomeNewsGate(
        key: ValueKey(generation),
        active: active,
        respectFirstVisitGuide: widget.respectFirstVisitGuide,
        child: const Center(child: Text('내 앨범 메인')),
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
    this.initiallyActive = true,
    this.respectFirstVisitGuide = false,
    int firstVisitFlags = 3,
  }) : repository = _Repository(owner) {
    container = ProviderContainer(
      overrides: [
        _ownerProvider.overrideWith((ref) => owner),
        homeNewsCurrentOwnerProvider.overrideWith(
          (ref) => ref.watch(_ownerProvider),
        ),
        homeNewsExposureStateProvider.overrideWith((ref) async {
          ref.watch(_ownerProvider);
          return exposure ?? _state();
        }),
        homeNewsCatalogProvider.overrideWith((ref) async {
          ref.watch(_ownerProvider);
          return items ?? [_item()];
        }),
        homeNewsRecoveryBlockProvider.overrideWith(
          (ref) async => recoveryBlocked,
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
    'one automatic delivery includes every enabled story and tracks actual swipes',
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
        ['monthly-design:2026-10', 'month-review:2026-10'],
      ]);
      expect(fixture.repository.views, ['monthly-design:2026-10']);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('home-news-pages')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(fixture.repository.views, [
        'monthly-design:2026-10',
        'month-review:2026-10',
      ]);
      expect(fixture.repository.claims.length, 1);
      await tester.tap(
        find.byKey(const ValueKey('home-news-close')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(fixture.repository.interactions, ['month-review:2026-10:dismiss']);
    },
  );

  testWidgets('browsable stories alone do not trigger an automatic popup', (
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
    expect(fixture.repository.deliveries, isEmpty);
    expect(find.byKey(const ValueKey('home-news-carousel')), findsNothing);
  });

  testWidgets('daily and weekly limits skip the server claim and modal', (
    tester,
  ) async {
    for (final (owner, exposure) in [
      ('gate-daily-owner', _state(daily: 1, weekly: 1)),
      ('gate-weekly-owner', _state(weekly: 2)),
    ]) {
      final fixture = _Fixture(owner: owner, exposure: exposure);
      await fixture.mount(tester);
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'saved-work recovery and pending first-visit guide take priority',
    (tester) async {
      for (final fixture in [
        _Fixture(owner: 'gate-recovery-owner', recoveryBlocked: true),
        _Fixture(
          owner: 'gate-first-guide-owner',
          respectFirstVisitGuide: true,
          firstVisitFlags: 1,
        ),
      ]) {
        await fixture.mount(tester);
        expect(_monthlySheet, findsNothing);
        expect(fixture.repository.claims, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'a closed sheet cannot return after tab switches or gate remounts in one session',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-remount-owner');
      await fixture.mount(tester);
      await tester.tap(find.byKey(const ValueKey('home-news-close')));
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.setActive(false);
      await tester.pumpAndSettle();
      fixture.harnessKey.currentState!.setActive(true);
      fixture.harnessKey.currentState!.remount();
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets('a lost app/web exposure race never opens a sheet', (
    tester,
  ) async {
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
    'leaving and returning during an awaited claim cancels its late popup',
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
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.claims, hasLength(1));
    },
  );

  testWidgets(
    'a pointer gesture cancels content arriving after the person starts using home',
    (tester) async {
      final fixture = _Fixture(owner: 'gate-pointer-cancel-owner');
      final reply = Completer<bool>();
      fixture.repository.pendingClaim = reply;
      await fixture.mount(tester);
      expect(fixture.repository.claims, hasLength(1));
      await tester.tap(find.text('내 앨범 메인'));
      reply.complete(true);
      await tester.pumpAndSettle();
      expect(_monthlySheet, findsNothing);
      expect(fixture.repository.interactions, isEmpty);
    },
  );

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

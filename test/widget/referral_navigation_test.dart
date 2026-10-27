import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/referral/data/pending_referral.dart';
import 'package:snap_fit/features/referral/data/referral_repository.dart';
import 'package:snap_fit/features/referral/domain/referral_link.dart';
import 'package:snap_fit/features/referral/domain/referral_status.dart';
import 'package:snap_fit/features/referral/presentation/providers/referral_providers.dart';
import 'package:snap_fit/features/referral/presentation/views/referral_screen.dart';
import 'package:snap_fit/features/referral/presentation/widgets/referral_entry_card.dart';
import 'package:snap_fit/features/referral/presentation/widgets/referral_link_router.dart';

const _one = 'ABCD2345XY';
const _two = 'JKMP2345XY';

class _Repository implements ReferralRepository {
  _Repository({this.actor});
  String? actor;
  int reads = 0, registrations = 0;
  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<ReferralStatus> fetchStatus() async {
    reads++;
    return ReferralStatus.fromJson({
      'ownCode': 'PQRS2345XY',
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
      'eligibleUntil': '2026-10-30T03:00:00Z',
      'serverTime': '2026-10-26T03:00:00Z',
      'claimed': false,
      'awardedPoints': 0,
      'rewardMonth': '2026-10',
      'timezone': 'Asia/Seoul',
      'ineligibleReason': null,
    });
  }

  @override
  Future<ReferralStatus> redeem(String code) {
    registrations++;
    return fetchStatus();
  }
}

class _Store extends PendingReferralStore {
  Future<PendingReferral?> Function()? restore;
  int reads = 0;
  @override
  Future<PendingReferral?> read() async {
    reads++;
    return restore == null ? null : await restore!();
  }

  @override
  Future<void> write(PendingReferral? referral) async {}
}

class _AlbumStore extends PendingAlbumInviteStore {
  @override
  Future<PendingAlbumInvite?> read() async => null;
  @override
  Future<void> write(PendingAlbumInvite? invite) async {}
}

class _Observer extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes.add(route);
  List<Route<dynamic>> get referrals => pushes
      .where(
        (route) =>
            route.settings is WebAppRouteSettings &&
            (route.settings as WebAppRouteSettings).location.page ==
                WebAppPage.referral,
      )
      .toList();
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  required _Repository repository,
  required _Store store,
  required _Observer observer,
  required GlobalKey<NavigatorState> navigator,
  bool nested = false,
  bool entry = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      referralRepositoryProvider.overrideWithValue(repository),
      pendingReferralStoreProvider.overrideWithValue(store),
      pendingAlbumInviteStoreProvider.overrideWithValue(_AlbumStore()),
    ],
  );
  Widget home = Scaffold(
    body: entry
        ? const ReferralEntryCard()
        : const Center(child: Text('현재 작업 화면')),
  );
  if (!entry) {
    if (nested) home = ReferralLinkRouter(child: home);
    home = ReferralLinkRouter(child: home);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light().copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _unmount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the friend entry opens its public route without granting points',
    (tester) async {
      final repository = _Repository(actor: 'owner');
      final observer = _Observer();
      final container = await _mount(
        tester,
        repository: repository,
        store: _Store(),
        observer: observer,
        navigator: GlobalKey<NavigatorState>(),
        entry: true,
      );
      await tester.tap(find.byKey(const ValueKey('referral-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      expect(observer.referrals, hasLength(1));
      expect(
        (observer.referrals.single.settings as WebAppRouteSettings).location,
        WebAppLocation.referral,
      );
      expect(WebAppLocation.referral.isPublic, isTrue);
      expect(repository.reads, greaterThan(0));
      expect(repository.registrations, 0);
      await _unmount(tester, container);
    },
  );

  testWidgets(
    'new native invitations update one preview and a dismissed code stays dismissed',
    (tester) async {
      final repository = _Repository();
      final observer = _Observer();
      final navigator = GlobalKey<NavigatorState>();
      final container = await _mount(
        tester,
        repository: repository,
        store: _Store(),
        observer: observer,
        navigator: navigator,
      );
      final controller = container.read(pendingReferralProvider.notifier);
      controller.receive(referralShareUri(_one));
      await tester.pumpAndSettle();
      expect(find.text(_one), findsOneWidget);
      controller.receive(Uri.parse('snapfit://friends?code=$_two'));
      await tester.pumpAndSettle();
      expect(find.text(_one), findsNothing);
      expect(find.text(_two), findsOneWidget);
      expect(observer.referrals, hasLength(1));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ReferralScreen), findsNothing);
      expect(find.text('현재 작업 화면'), findsOneWidget);
      expect(container.read(pendingReferralProvider)?.code, _two);
      controller.receive(referralShareUri(_two));
      await tester.pumpAndSettle();
      expect(find.text(_two), findsOneWidget);
      expect(observer.referrals, hasLength(2));
      expect(repository.reads, 0);
      expect(repository.registrations, 0);
      await _unmount(tester, container);
    },
  );

  testWidgets(
    'an album collaboration invitation takes priority until its flow finishes',
    (tester) async {
      final repository = _Repository();
      final observer = _Observer();
      final container = await _mount(
        tester,
        repository: repository,
        store: _Store(),
        observer: observer,
        navigator: GlobalKey<NavigatorState>(),
      );
      final albums = container.read(pendingAlbumInviteProvider.notifier);
      albums.receive(Uri.parse('snapfit://invite?token=collaboration-one'));
      container
          .read(pendingReferralProvider.notifier)
          .receive(referralShareUri(_one));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsNothing);
      expect(observer.referrals, isEmpty);
      albums.clearIfCurrent(container.read(pendingAlbumInviteProvider)!);
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      expect(find.text(_one), findsOneWidget);
      expect(observer.referrals, hasLength(1));
      expect(repository.registrations, 0);
      await _unmount(tester, container);
    },
  );

  testWidgets(
    'a saved code restores after app restart into an unclaimed preview',
    (tester) async {
      final restored = Completer<PendingReferral?>();
      final store = _Store()..restore = () => restored.future;
      final repository = _Repository();
      final observer = _Observer();
      final container = await _mount(
        tester,
        repository: repository,
        store: store,
        observer: observer,
        navigator: GlobalKey<NavigatorState>(),
      );
      expect(find.byType(ReferralScreen), findsNothing);
      restored.complete(PendingReferral(_one, DateTime.now()));
      await tester.pumpAndSettle();
      expect(find.text(_one), findsOneWidget);
      expect(observer.referrals, hasLength(1));
      expect(store.reads, 1);
      expect(repository.registrations, 0);
      await _unmount(tester, container);
    },
  );

  testWidgets(
    'nested auth gates share one invitation route without reopening on dismissal',
    (tester) async {
      final repository = _Repository();
      final observer = _Observer();
      final navigator = GlobalKey<NavigatorState>();
      final container = await _mount(
        tester,
        repository: repository,
        store: _Store(),
        observer: observer,
        navigator: navigator,
        nested: true,
      );
      container
          .read(pendingReferralProvider.notifier)
          .receive(referralShareUri(_one));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      expect(observer.referrals, hasLength(1));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ReferralScreen), findsNothing);
      expect(observer.referrals, hasLength(1));
      expect(repository.registrations, 0);
      await _unmount(tester, container);
    },
  );
}

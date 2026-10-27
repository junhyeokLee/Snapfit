import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/my_point_balance_card.dart';
import 'package:snap_fit/features/profile/presentation/widgets/personal_collection_shelf.dart';
import 'package:snap_fit/features/profile/presentation/widgets/personal_order_shortcut.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_personal_area.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';

const _account = UserInfo(
  id: 'owner-a',
  name: '개인 계정 이름',
  email: 'private.owner@example.test',
  provider: 'EMAIL',
);
const _profile = SocialProfile(
  userId: 'owner-a',
  displayName: '공개한 이름',
  handle: 'public.handle',
);
const _summary = OrderSummaryResult(
  paymentPending: 0,
  paymentCompleted: 1,
  inProduction: 2,
  shipping: 3,
  delivered: 0,
  canceled: 0,
  latestUpdatedAt: null,
);

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => _account;
  void owner(String? id) =>
      state = AsyncData(id == null ? null : _account.copyWith(id: id));
}

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => const [];
}

class _PendingHome extends HomeViewModel {
  final pending = Completer<List<Album>>();
  @override
  FutureOr<List<Album>> build() => pending.future;
}

class _Orders extends Mock implements OrderRepository {}

List<Override> _overrides({
  _Auth? auth,
  HomeViewModel? home,
  FutureOr<SocialProfile?> Function(Ref)? profile,
  FutureOr<int> Function(Ref)? balance,
  FutureOr<OrderSummaryResult> Function(Ref)? summary,
  _Orders? orders,
  String? actor = 'owner-a',
}) => [
  authViewModelProvider.overrideWith(() => auth ?? _Auth()),
  socialCurrentUserIdProvider.overrideWith((_) => actor),
  ownSocialProfileProvider.overrideWith(profile ?? (_) async => _profile),
  socialProfileWorksPageProvider(
    const SocialProfileWorksQuery('owner-a'),
  ).overrideWith(
    (_) async => const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
  ),
  homeViewModelProvider.overrideWith(() => home ?? _Home()),
  myPointBalanceProvider.overrideWith(balance ?? (_) async => 700),
  myPointLedgerProvider.overrideWith((_) async => const []),
  myStorageQuotaProvider.overrideWith(
    (_) async => const StorageQuotaStatus(
      userId: 'owner-a',
      planCode: 'FREE',
      usedBytes: 1024,
      softLimitBytes: 100000,
      hardLimitBytes: 200000,
      softExceeded: false,
      hardExceeded: false,
      usagePercent: 1,
    ),
  ),
  myOrderSummaryProvider.overrideWith(summary ?? (_) async => _summary),
  ownedPointShopKeysProvider.overrideWith((_) async => const {}),
  pointShopCatalogProvider.overrideWith((_) async => const []),
  momentsSessionProvider.overrideWith((_) => Stream.value(null)),
  if (orders != null) orderRepositoryProvider.overrideWithValue(orders),
];

Widget _app(Widget home, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
    splashFactory: NoSplash.splashFactory,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> _mount(
  WidgetTester tester,
  ProviderContainer container, {
  Widget? page,
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _app(
        page ?? const SocialProfileScreen(),
        dark: dark,
        scale: scale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'verified owner sees collections wallet login identity and one order shortcut',
    (tester) async {
      final container = ProviderContainer(overrides: _overrides());
      addTearDown(container.dispose);
      await _mount(tester, container);
      expect(find.text('공개한 이름'), findsOneWidget);
      expect(find.text('@public.handle'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SocialProfileIdentity),
          matching: find.text('private.owner@example.test'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-private-account')),
        findsNothing,
      );
      expect(find.textContaining('나에게만 표시돼요'), findsNothing);
      expect(find.byType(MyPointBalanceCard), findsOneWidget);
      expect(find.text('700 P'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-point-charge')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-point-history')), findsOneWidget);
      expect(find.byType(PersonalAlbumShelf), findsOneWidget);
      expect(find.byType(OwnedDesignShelf), findsOneWidget);
      expect(find.byType(PersonalOrderShortcut), findsOneWidget);
      expect(find.text('인쇄 주문 내역'), findsOneWidget);
      expect(find.text('공유된 앨범'), findsOneWidget);
      expect(find.text('내 저장 공간'), findsOneWidget);
      expect(find.text('포인트와 결제'), findsNothing);
      expect(find.text('계정 설정'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accountCycle in [false, true]) {
    testWidgets(
      'album shortcut waits for current albums and rechecks owner cycle=$accountCycle',
      (tester) async {
        final auth = _Auth();
        final home = _PendingHome();
        final container = ProviderContainer(
          overrides: _overrides(auth: auth, home: home),
        );
        addTearDown(container.dispose);
        await _mount(tester, container);
        final shortcut = find.byKey(const ValueKey('profile-shortcut-albums'));
        await tester.ensureVisible(shortcut);
        await tester.pumpAndSettle();
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(find.byType(AlbumCategoryScreen), findsNothing);
        if (accountCycle) {
          auth.owner('owner-b');
          await tester.pumpAndSettle();
          auth.owner('owner-a');
          await tester.pumpAndSettle();
        }
        home.pending.complete(const [
          Album(id: 42, userId: 'owner-a', title: '새로 불러온 앨범'),
        ]);
        await tester.pumpAndSettle();
        if (accountCycle) {
          expect(find.byType(AlbumCategoryScreen), findsNothing);
        } else {
          expect(find.byType(AlbumCategoryScreen), findsOneWidget);
          expect(
            tester
                .widget<AlbumCategoryScreen>(find.byType(AlbumCategoryScreen))
                .initialAlbums
                .single
                .id,
            42,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final state in ['missing', 'error', 'loading']) {
    testWidgets('private controls remain usable with $state public profile', (
      tester,
    ) async {
      final pending = Completer<SocialProfile?>();
      final container = ProviderContainer(
        overrides: _overrides(
          profile: (_) {
            if (state == 'error')
              throw StateError('public profile unavailable');
            if (state == 'loading') return pending.future;
            return null;
          },
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _app(const SocialProfileScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SocialProfilePersonalArea), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-private-account')),
        findsNothing,
      );
      expect(find.byType(PersonalAlbumShelf), findsOneWidget);
      expect(find.byType(PersonalOrderShortcut), findsOneWidget);
      expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (!pending.isCompleted) pending.complete(null);
      await tester.pump();
    });
  }

  testWidgets('public self profile omits the private login ID', (tester) async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    await _mount(
      tester,
      container,
      page: const SocialProfileScreen(userId: 'owner-a'),
    );
    expect(find.text('@public.handle'), findsOneWidget);
    expect(find.text('private.owner@example.test'), findsNothing);
    expect(find.byKey(const ValueKey('social-profile-login-id')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public visitor does not even load owner-only data', (
    tester,
  ) async {
    var balances = 0, summaries = 0;
    final container = ProviderContainer(
      overrides: [
        ..._overrides(
          balance: (_) async {
            balances++;
            return 700;
          },
          summary: (_) async {
            summaries++;
            return _summary;
          },
        ),
        socialProfileProvider('other').overrideWith(
          (_) async => const SocialProfile(
            userId: 'other',
            displayName: '다른 사람',
            handle: 'other',
          ),
        ),
        socialProfileWorksPageProvider(
          const SocialProfileWorksQuery('other'),
        ).overrideWith(
          (_) async =>
              const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
        ),
        socialBlockedProfilesProvider.overrideWith((_) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await _mount(
      tester,
      container,
      page: const SocialProfileScreen(userId: 'other'),
    );
    expect(find.text('다른 사람'), findsOneWidget);
    expect(find.text('private.owner@example.test'), findsNothing);
    expect(find.byType(SocialProfilePersonalArea), findsNothing);
    expect(find.byType(PersonalAlbumShelf), findsNothing);
    expect(find.byType(MyPointBalanceCard), findsNothing);
    expect(balances, 0);
    expect(summaries, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mismatched SDK owner masks cached personal details and menus', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    await _mount(tester, container);
    expect(find.text('private.owner@example.test'), findsOneWidget);
    container.read(orderSessionOwnerProvider.notifier).observe('owner-b');
    await tester.pumpAndSettle();
    expect(find.text('공개한 이름'), findsOneWidget);
    expect(find.text('private.owner@example.test'), findsNothing);
    expect(find.byType(PersonalAlbumShelf), findsNothing);
    expect(find.text('700 P'), findsNothing);
    expect(find.byType(PersonalOrderShortcut), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a pending order seen marker cannot navigate after account A B A',
    (tester) async {
      final orders = _Orders();
      final seen = Completer<void>();
      when(
        () => orders.markOrderSummarySeen(userId: 'owner-a', summary: _summary),
      ).thenAnswer((_) => seen.future);
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: _overrides(auth: auth, orders: orders),
      );
      addTearDown(container.dispose);
      await _mount(tester, container);
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-order-shortcut')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-order-shortcut')));
      await tester.pump();
      auth.owner('owner-b');
      await tester.pump();
      expect(find.byType(PersonalOrderShortcut), findsNothing);
      auth.owner('owner-a');
      await tester.pumpAndSettle();
      seen.complete();
      await tester.pumpAndSettle();
      verify(
        () => orders.markOrderSummarySeen(userId: 'owner-a', summary: _summary),
      ).called(1);
      expect(find.byType(OrderHistoryScreen), findsNothing);
      expect(find.byType(SocialProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a wallet error does not hide collections and other private entries',
    (tester) async {
      final container = ProviderContainer(
        overrides: _overrides(
          balance: (_) => throw StateError('wallet unavailable'),
        ),
      );
      addTearDown(container.dispose);
      await _mount(tester, container);
      expect(find.text('다시 확인'), findsOneWidget);
      expect(find.byType(PersonalAlbumShelf), findsOneWidget);
      expect(find.byType(OwnedDesignShelf), findsOneWidget);
      expect(find.byKey(const ValueKey('moments-entry')), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance-entry')), findsOneWidget);
      expect(find.byKey(const ValueKey('referral-entry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('private account and actions fit narrow dark large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    await _mount(tester, container, dark: true, scale: 1.8);
    for (final key in [
      'my-point-charge',
      'my-point-history',
      'social-profile-login-id',
      'profile-order-shortcut',
      'profile-shared-albums',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wallet offers separate charge and ledger callbacks', (
    tester,
  ) async {
    var charge = 0, history = 0;
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    await _mount(
      tester,
      container,
      page: Scaffold(
        body: MyPointBalanceCard(
          onCharge: () => charge++,
          onHistory: () => history++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('my-point-charge')));
    await tester.tap(find.byKey(const ValueKey('my-point-history')));
    expect(charge, 1);
    expect(history, 1);
    expect(tester.takeException(), isNull);
  });
}

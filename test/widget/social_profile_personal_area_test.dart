import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/presentation/providers/private_moment_archive_providers.dart';
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
import 'package:snap_fit/features/social/presentation/widgets/my_moment_archive.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

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
  _Home([this.albums = const []]);

  final List<Album> albums;

  @override
  FutureOr<List<Album>> build() => albums;

  void replaceAlbums(List<Album> albums) => state = AsyncData(albums);

  // Riverpod가 실제 갱신 중 유지하는 복합 상태를 위젯 경계에 재현한다.
  void refreshKeepingPrevious() =>
      // ignore: invalid_use_of_internal_member
      state = const AsyncLoading<List<Album>>().copyWithPrevious(state);

  void failKeepingPrevious() => state = AsyncError<List<Album>>(
    StateError('album list unavailable'),
    StackTrace.current,
    // ignore: invalid_use_of_internal_member
  ).copyWithPrevious(state);
}

class _PendingHome extends HomeViewModel {
  final pending = Completer<List<Album>>();
  @override
  FutureOr<List<Album>> build() => pending.future;
}

class _RetryHome extends _PendingHome {
  final retry = Completer<List<Album>>();
  int attempts = 0;

  @override
  FutureOr<List<Album>> build() =>
      attempts++ == 0 ? pending.future : retry.future;
}

class _Orders extends Mock implements OrderRepository {}

class _MomentOwner extends Fake implements MomentsRepository {
  @override
  String? get currentUserId => 'owner-a';
  @override
  Stream<String?> get authChanges => const Stream.empty();
}

class _ArchiveOwner extends Fake implements PrivateMomentArchiveRepository {
  @override
  String? get currentUserId => 'owner-a';
  @override
  int get sessionRevision => 0;
  @override
  Stream<int> get sessionChanges => const Stream.empty();
}

List<Override> _overrides({
  _Auth? auth,
  HomeViewModel? home,
  FutureOr<SocialProfile?> Function(Ref)? profile,
  FutureOr<int> Function(Ref)? balance,
  FutureOr<OrderSummaryResult> Function(Ref)? summary,
  _Orders? orders,
  String? actor = 'owner-a',
  List<SocialWork> works = const [],
  bool emptyMoments = true,
  List<MomentMonthSummary> privateMonths = const [],
  FutureOr<List<MomentMonthSummary>> Function(PrivateMomentMonthsQuery)?
  monthArchive,
}) => [
  authViewModelProvider.overrideWith(() => auth ?? _Auth()),
  socialCurrentUserIdProvider.overrideWith((_) => actor),
  ownSocialProfileProvider.overrideWith(profile ?? (_) async => _profile),
  if (emptyMoments)
    socialProfileMomentsPageProvider.overrideWith(
      (_, _) async =>
          const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
    ),
  if (emptyMoments)
    socialProfileMomentMonthsPageProvider.overrideWith(
      (_, _) async => const SocialMomentMonthsPage(
        items: [],
        hasMore: false,
        nextOffset: 0,
      ),
    ),
  socialProfileWorksPageProvider(
    const SocialProfileWorksQuery('owner-a'),
  ).overrideWith(
    (_) async =>
        SocialWorkPage(items: works, hasMore: false, nextOffset: works.length),
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
  momentsRepositoryProvider.overrideWithValue(_MomentOwner()),
  privateMomentArchiveRepositoryProvider.overrideWithValue(_ArchiveOwner()),
  privateMomentMonthsProvider.overrideWith(
    (_, query) async =>
        monthArchive?.call(query) ??
        privateMonths
            .where(
              (month) =>
                  query.beforeMonth == null ||
                  month.month.isBefore(query.beforeMonth!),
            )
            .take(query.limit)
            .toList(),
  ),
  if (orders != null) orderRepositoryProvider.overrideWithValue(orders),
];

/// A bundled photo for isolated source-widget captures. Real private-photo
/// security tests below keep the unmodified [MomentPhoto] storage URI.
class _AssetReviewPhoto extends MomentPhoto {
  const _AssetReviewPhoto({
    required super.id,
    required super.path,
    required super.width,
    required super.height,
    required this.assetPath,
  });

  final String assetPath;

  @override
  String get storageUri => 'asset:$assetPath';
}

/// Reuses owner-scoped fixtures in source-widget screenshot exports.
List<Override> profilePersonalReviewOverrides({
  bool emptyMoments = true,
  HomeViewModel? home,
}) => [
  ..._overrides(
    home: home,
    emptyMoments: emptyMoments,
    privateMonths: emptyMoments
        ? const []
        : [
            for (var offset = 0; offset < 3; offset++)
              MomentMonthSummary(
                month: DateTime.utc(
                  momentToday().year,
                  momentToday().month - offset,
                ),
                recordCount: 8 + offset,
                photoCount: 12 + offset,
                coverPhoto: _AssetReviewPhoto(
                  id: 'review-photo-$offset',
                  path: 'owner-a/moments/review-$offset/cover.png',
                  width: 1536,
                  height: 1024,
                  assetPath: switch (offset) {
                    1 =>
                      'assets/templates/original_editorial/images/travel_coast.png',
                    2 =>
                      'assets/templates/original_editorial/images/pet_cat.png',
                    _ =>
                      'assets/templates/original_editorial/images/daily_book.png',
                  },
                ),
              ),
          ],
  ),
];

Widget profilePersonalReviewApp(
  Widget home, {
  bool dark = false,
  double scale = 1,
}) => _app(home, dark: dark, scale: scale);

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
    'verified owner keeps shortcuts and wallet without duplicate shelves or order cards',
    (tester) async {
      final container = ProviderContainer(overrides: _overrides());
      addTearDown(container.dispose);
      await _mount(tester, container);
      expect(find.text('공개한 이름'), findsOneWidget);
      expect(find.text('@public.handle'), findsOneWidget);
      expect(find.text('공개 기록 0'), findsOneWidget);
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
      expect(find.byType(MyMomentArchive), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-current-month-empty')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(MyPointBalanceCard));
      await tester.pumpAndSettle();
      expect(find.text('700 P'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-point-summary')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('my-point-charge')), findsNothing);
      expect(find.byKey(const ValueKey('my-point-history')), findsNothing);
      expect(find.byType(PersonalAlbumShelf), findsNothing);
      expect(find.byType(OwnedDesignShelf), findsNothing);
      expect(find.byType(PersonalOrderShortcut), findsNothing);
      await tester.ensureVisible(find.byTooltip('인쇄 주문 내역'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('인쇄 주문 내역').hitTestable(), findsOneWidget);
      expect(
        find
            .byKey(const ValueKey('profile-header-notifications'))
            .hitTestable(),
        kIsWeb ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-collection-moments')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-collection-albums')),
        findsNothing,
      );
      expect(find.text('공개 작품'), findsNothing);
      expect(find.text('공개한 작품'), findsNothing);
      expect(find.byKey(const ValueKey('profile-manage-works')), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-shortcut-albums')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-shortcut-library')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-shortcut-orders')),
        findsNothing,
      );
      expect(find.text('내 앨범'), findsOneWidget);
      expect(find.text('내 보관함'), findsOneWidget);
      expect(find.text('알림'), findsNothing);
      expect(find.text('공유된 앨범'), findsOneWidget);
      expect(find.text('내 저장 공간'), findsOneWidget);
      expect(find.text('포인트와 결제'), findsNothing);
      expect(find.text('계정 설정'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hasCurrent in [true, false]) {
    testWidgets(
      'my ${hasCurrent ? 'current' : 'latest earlier'} private month precedes points and stays out of the public profile',
      (tester) async {
        final now = momentMonth(momentToday());
        final month = DateTime.utc(now.year, now.month - (hasCurrent ? 0 : 1));
        final photoKey = hasCurrent
            ? 'my-current-month-photo'
            : 'my-featured-month-photo-${momentDateKey(month)}';
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            ..._overrides(
              monthArchive: (_) async {
                reads++;
                return [
                  MomentMonthSummary(
                    month: month,
                    recordCount: 8,
                    photoCount: 12,
                    coverPhoto: const MomentPhoto(
                      id: 'private-first',
                      path: 'owner-a/moments/private-first/photo.png',
                      width: 1200,
                      height: 1600,
                    ),
                  ),
                ];
              },
            ),
            myMomentArchivePhotoResolverProvider.overrideWithValue(
              (_) async => 'asset:assets/cover/cover1.png',
            ),
          ],
        );
        addTearDown(container.dispose);
        SnapfitImage.storageOwnerForTesting = () => 'owner-a';
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          SnapfitImage.storageOwnerForTesting = null;
        });
        await _mount(tester, container);
        expect(find.byKey(ValueKey(photoKey)), findsOneWidget);
        expect(find.text('기록 8개 · 사진 12장'), findsOneWidget);
        expect(find.text('${month.year}년 ${month.month}월'), findsOneWidget);
        if (!hasCurrent) {
          expect(
            find.byKey(const ValueKey('my-current-month-prompt')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('my-current-month-empty')),
            findsNothing,
          );
        }
        final photo = tester.getRect(find.byKey(ValueKey(photoKey)));
        final wallet = tester.getRect(find.byType(MyPointBalanceCard));
        expect(photo.height, greaterThan(300));
        expect(wallet.top, greaterThan(photo.bottom));
        final public = find.byKey(const ValueKey('profile-open-public'));
        await tester.ensureVisible(public);
        await tester.pumpAndSettle();
        await tester.tap(public);
        await tester.pumpAndSettle();
        expect(find.byType(MyMomentArchive), findsNothing);
        expect(find.byKey(ValueKey(photoKey)), findsNothing);
        expect(find.text('private.owner@example.test'), findsNothing);
        expect(
          find.byKey(const ValueKey('profile-collection-moments')),
          findsOneWidget,
        );
        expect(reads, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shared albums do not confirm zero before the first load', (
    tester,
  ) async {
    final home = _PendingHome();
    final container = ProviderContainer(overrides: _overrides(home: home));
    addTearDown(container.dispose);
    await _mount(tester, container);

    final row = tester.widget<ListTile>(
      find.byKey(const ValueKey('profile-shared-albums')),
    );
    expect((row.subtitle! as Text).data, '앨범을 확인하고 있어요');
    expect(find.text('0개의 함께 만든 앨범'), findsNothing);
    expect(row.onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared album load failure retries from its row and opens albums',
    (tester) async {
      final home = _RetryHome();
      final container = ProviderContainer(overrides: _overrides(home: home));
      addTearDown(container.dispose);
      await _mount(tester, container);
      home.pending.completeError(StateError('album list unavailable'));
      await tester.pumpAndSettle();

      final entry = find.byKey(const ValueKey('profile-shared-albums'));
      final row = tester.widget<ListTile>(entry);
      expect((row.subtitle! as Text).data, '확인 실패 · 다시 시도');
      expect(find.text('0개의 함께 만든 앨범'), findsNothing);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(home.attempts, 2);
      expect(find.byType(AlbumCategoryScreen), findsNothing);

      home.retry.complete(const [
        Album(id: 1, userId: 'owner-a', title: '내 앨범'),
        Album(id: 2, userId: 'owner-b', title: '함께 만든 앨범'),
        Album(id: 3, userId: '', title: '소유자 미확인'),
      ]);
      await tester.pumpAndSettle();
      final page = tester.widget<AlbumCategoryScreen>(
        find.byType(AlbumCategoryScreen),
      );
      expect(page.category, AlbumCategory.shared);
      expect(page.currentUserId, 'owner-a');
      expect(page.initialAlbums.map((album) => album.id), [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared album refresh preserves its last confirmed count', (
    tester,
  ) async {
    final home = _Home(const [
      Album(id: 1, userId: 'owner-b'),
      Album(id: 2, userId: 'owner-c'),
    ]);
    final container = ProviderContainer(overrides: _overrides(home: home));
    addTearDown(container.dispose);
    await _mount(tester, container);
    expect(find.text('2개의 함께 만든 앨범'), findsOneWidget);

    // Riverpod retains successful data while refreshing; the count must not reset.
    home.refreshKeepingPrevious();
    await tester.pumpAndSettle();
    expect(container.read(homeViewModelProvider).isLoading, isTrue);
    expect(find.text('2개의 함께 만든 앨범'), findsOneWidget);
    expect(find.text('0개의 함께 만든 앨범'), findsNothing);
    expect(find.text('앨범을 확인하고 있어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared album refresh does not confirm a retained empty list', (
    tester,
  ) async {
    final home = _Home();
    final container = ProviderContainer(overrides: _overrides(home: home));
    addTearDown(container.dispose);
    await _mount(tester, container);
    home.refreshKeepingPrevious();
    await tester.pumpAndSettle();

    final value = container.read(homeViewModelProvider);
    expect(value.isLoading, isTrue);
    expect(value.hasValue, isTrue);
    final row = tester.widget<ListTile>(
      find.byKey(const ValueKey('profile-shared-albums')),
    );
    expect((row.subtitle! as Text).data, '앨범을 확인하고 있어요');
    expect(find.text('0개의 함께 만든 앨범'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final retainedCount in [0, 2]) {
    testWidgets(
      'shared album error stays recoverable with retained count=$retainedCount',
      (tester) async {
        final home = _Home([
          for (var id = 0; id < retainedCount; id++)
            Album(id: id, userId: 'owner-b'),
        ]);
        final container = ProviderContainer(overrides: _overrides(home: home));
        addTearDown(container.dispose);
        await _mount(tester, container);
        home.failKeepingPrevious();
        await tester.pumpAndSettle();

        final value = container.read(homeViewModelProvider);
        expect(value.hasError, isTrue);
        expect(value.hasValue, isTrue);
        final entry = find.byKey(const ValueKey('profile-shared-albums'));
        final row = tester.widget<ListTile>(entry);
        expect((row.subtitle! as Text).data, '확인 실패 · 다시 시도');
        expect(
          find.descendant(of: entry, matching: find.byIcon(Icons.refresh)),
          findsOneWidget,
        );
        expect(row.onTap, isNotNull);
        expect(find.text('0개의 함께 만든 앨범'), findsNothing);
        expect(find.text('2개의 함께 만든 앨범'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'shared album count excludes own and unknown owners and confirms empty',
    (tester) async {
      final home = _Home(const [
        Album(id: 1, userId: 'owner-a'),
        Album(id: 2, userId: ''),
        Album(id: 3, userId: '   '),
        Album(id: 4, userId: 'owner-b'),
        Album(id: 5, userId: 'owner-c'),
      ]);
      final container = ProviderContainer(overrides: _overrides(home: home));
      addTearDown(container.dispose);
      await _mount(tester, container);
      expect(find.text('2개의 함께 만든 앨범'), findsOneWidget);

      home.replaceAlbums(const []);
      await tester.pumpAndSettle();
      expect(find.text('0개의 함께 만든 앨범'), findsOneWidget);
      expect(find.text('앨범을 확인하고 있어요'), findsNothing);
      expect(find.text('확인 실패 · 다시 시도'), findsNothing);
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
      expect(find.byType(PersonalAlbumShelf), findsNothing);
      expect(find.byType(PersonalOrderShortcut), findsNothing);
      expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (!pending.isCompleted) pending.complete(null);
      await tester.pump();
    });
  }

  testWidgets('public self profile omits the private login ID', (tester) async {
    var privateReads = 0;
    final container = ProviderContainer(
      overrides: _overrides(
        monthArchive: (_) async {
          privateReads++;
          return [];
        },
      ),
    );
    addTearDown(container.dispose);
    await _mount(
      tester,
      container,
      page: const SocialProfileScreen(userId: 'owner-a'),
    );
    expect(find.text('@public.handle'), findsOneWidget);
    expect(find.text('private.owner@example.test'), findsNothing);
    expect(find.byKey(const ValueKey('social-profile-login-id')), findsNothing);
    expect(find.byKey(const ValueKey('profile-header-orders')), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-header-notifications')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('profile-header-settings')), findsNothing);
    expect(find.byType(SocialProfilePersonalArea), findsNothing);
    expect(find.byType(MyMomentArchive), findsNothing);
    expect(privateReads, 0);
    expect(find.byType(MyPointBalanceCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public visitor does not even load owner-only data', (
    tester,
  ) async {
    var balances = 0, summaries = 0, privateReads = 0;
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
          monthArchive: (_) async {
            privateReads++;
            return [];
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
    expect(find.byType(MyMomentArchive), findsNothing);
    expect(find.byType(PersonalAlbumShelf), findsNothing);
    expect(find.byType(MyPointBalanceCard), findsNothing);
    expect(find.byKey(const ValueKey('profile-header-orders')), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-header-notifications')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('profile-header-settings')), findsNothing);
    expect(balances, 0);
    expect(summaries, 0);
    expect(privateReads, 0);
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
    expect(find.byKey(const ValueKey('profile-header-orders')), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-header-notifications')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('profile-header-settings')), findsNothing);
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
        find.byKey(const ValueKey('profile-header-orders')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-header-orders')));
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
    'a wallet error does not hide shortcuts and other private entries',
    (tester) async {
      final container = ProviderContainer(
        overrides: _overrides(
          balance: (_) => throw StateError('wallet unavailable'),
        ),
      );
      addTearDown(container.dispose);
      await _mount(tester, container);
      expect(find.text('잔액 확인 필요'), findsOneWidget);
      expect(find.byType(PersonalAlbumShelf), findsNothing);
      expect(find.byType(OwnedDesignShelf), findsNothing);
      expect(find.byType(MyMomentArchive), findsOneWidget);
      expect(find.byKey(const ValueKey('my-first-moment')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-shortcut-albums')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-shortcut-library')),
        findsOneWidget,
      );
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
      'my-point-summary',
      'social-profile-login-id',
      'profile-header-orders',
      if (!kIsWeb) 'profile-header-notifications',
      'profile-header-settings',
      'profile-shared-albums',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: key);
    }
    await tester.ensureVisible(find.byKey(const ValueKey('my-point-summary')));
    await tester.tap(find.byKey(const ValueKey('my-point-summary')));
    await tester.pumpAndSettle();
    for (final key in ['my-point-charge', 'my-point-history']) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder.hitTestable(), findsOneWidget, reason: key);
    }
    await tester.tap(find.byKey(const ValueKey('my-point-close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'my first private photograph is visible before scrolling without distorting its source',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final container = ProviderContainer(
        overrides: [
          ..._overrides(
            privateMonths: [
              MomentMonthSummary(
                month: momentMonth(momentToday()),
                recordCount: 1,
                photoCount: 1,
                coverPhoto: const MomentPhoto(
                  id: 'first-photo',
                  path: 'owner-a/moments/first-photo/cover.png',
                  width: 900,
                  height: 1200,
                ),
              ),
            ],
          ),
          myMomentArchivePhotoResolverProvider.overrideWithValue(
            (_) async => 'asset:assets/cover/cover1.png',
          ),
        ],
      );
      addTearDown(container.dispose);
      SnapfitImage.storageOwnerForTesting = () => 'owner-a';
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        SnapfitImage.storageOwnerForTesting = null;
      });
      await _mount(tester, container);
      final artwork = find.byKey(const ValueKey('my-current-month-photo'));
      final frame = tester.getRect(artwork);
      expect(frame.top, lessThan(kIsWeb ? 640 : 550));
      expect(frame.width, greaterThanOrEqualTo(350));
      // A square album frame contains the whole original portrait without
      // stretching or cropping the photograph.
      expect(frame.width / frame.height, closeTo(1, .001));
      final source = tester.widget<SnapfitImage>(
        find.descendant(of: artwork, matching: find.byType(SnapfitImage)),
      );
      expect(
        source.urlOrGs,
        'supabase://album-assets/owner-a/moments/first-photo/cover.png',
      );
      expect(source.fit, BoxFit.contain);
      expect(source.fallbackSources, isEmpty);
      expect(844 - (kIsWeb ? 0 : 80) - frame.top, greaterThanOrEqualTo(200));
      expect(
        tester.getRect(find.byType(MyPointBalanceCard)).top,
        greaterThan(frame.bottom),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('my-point-balance-card')))
            .height,
        lessThanOrEqualTo(76),
      );
      for (final id in ['albums', 'library']) {
        final shortcut = find.byKey(ValueKey('profile-shortcut-$id'));
        await tester.ensureVisible(shortcut);
        await tester.pumpAndSettle();
        expect(shortcut.hitTestable(), findsOneWidget);
        expect(tester.getSize(shortcut).height, greaterThanOrEqualTo(48));
      }
      expect(
        find.byKey(const ValueKey('profile-collection-albums')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact wallet preserves long balances and both actions at large type',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var charge = 0, history = 0;
      final container = ProviderContainer(
        overrides: _overrides(balance: (_) async => 1234567890),
      );
      addTearDown(container.dispose);
      await _mount(
        tester,
        container,
        dark: true,
        scale: 1.8,
        page: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: MyPointBalanceCard(
              compact: true,
              onCharge: () => charge++,
              onHistory: () => history++,
            ),
          ),
        ),
      );
      expect(find.text('1,234,567,890 P'), findsOneWidget);
      for (final id in ['charge', 'history']) {
        await tester.tap(find.byKey(const ValueKey('my-point-summary')));
        await tester.pumpAndSettle();
        final action = find.byKey(ValueKey('my-point-$id'));
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(charge, 1);
      expect(history, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'header order action opens the order history and marks its current summary seen',
    (tester) async {
      final orders = _Orders();
      when(
        () => orders.markOrderSummarySeen(userId: 'owner-a', summary: _summary),
      ).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: _overrides(orders: orders),
      );
      addTearDown(container.dispose);
      await _mount(tester, container);
      await tester.tap(find.byKey(const ValueKey('profile-header-orders')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderHistoryScreen), findsOneWidget);
      verify(
        () => orders.markOrderSummarySeen(userId: 'owner-a', summary: _summary),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );

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
    for (final id in ['charge', 'history']) {
      await tester.tap(find.byKey(const ValueKey('my-point-summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('my-point-$id')));
      await tester.pumpAndSettle();
    }
    expect(charge, 1);
    expect(history, 1);
    expect(tester.takeException(), isNull);
  });
}

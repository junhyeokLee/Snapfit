import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/memory_moment_draft_store.dart';
import '../helpers/first_visit_fixtures.dart';

class _PendingHome extends HomeViewModel {
  _PendingHome(this.albums);
  final Future<List<Album>> albums;
  @override
  Future<List<Album>> build() => albums;
}

MomentJournal _emptyJournal() => MomentJournal(
  today: DateTime.utc(2026, 11, 4),
  weekStart: DateTime.utc(2026, 11, 2),
  month: DateTime.utc(2026, 11),
  records: const [],
  weekPhotoCount: 0,
);

void main() {
  setUpAll(loadCreationFonts);

  testWidgets(
    'the collection footer keeps the guide pending until the cover home opens',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryFirstVisitStore(1);
      await tester.pumpWidget(
        reviewApp(
          const HomeScreen(),
          overrides: [
            firstVisitStoreProvider.overrideWithValue(store),
            homeUiStateProvider.overrideWith(
              () => HomeUiStateNotifier(initialIndex: 1),
            ),
            momentEntryJournalProvider.overrideWithValue(
              AsyncData(_emptyJournal()),
            ),
            momentsSessionProvider.overrideWith((_) => Stream.value(null)),
            momentsCurrentUserIdProvider.overrideWith((_) => null),
            albumCreationDraftStoreProvider.overrideWithValue(
              MemoryCreationDraftStore(),
            ),
            notificationUnreadCountProvider.overrideWith((_) async => 0),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await container.read(firstVisitProvider.future);
      expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
      expect(store.flags, 1);
      container.read(homeUiStateProvider.notifier).setBottomNavIndex(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-home-guide')), findsOneWidget);
      expect(store.flags, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the first guide waits for the loaded home body with a cached journal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryFirstVisitStore(1);
      final albums = Completer<List<Album>>();
      addTearDown(() {
        if (!albums.isCompleted) albums.complete([]);
      });
      await tester.pumpWidget(
        reviewApp(
          ProviderScope(
            overrides: [
              homeViewModelProvider.overrideWith(
                () => _PendingHome(albums.future),
              ),
            ],
            child: const HomeScreen(),
          ),
          overrides: [
            firstVisitStoreProvider.overrideWithValue(store),
            momentEntryJournalProvider.overrideWithValue(
              AsyncData(_emptyJournal()),
            ),
            momentsSessionProvider.overrideWith((_) => Stream.value(null)),
            momentsCurrentUserIdProvider.overrideWith((_) => null),
            albumCreationDraftStoreProvider.overrideWithValue(
              MemoryCreationDraftStore(),
            ),
            notificationUnreadCountProvider.overrideWith((_) async => 0),
          ],
        ),
      );
      // Album shimmer deliberately remains active until the final body is ready.
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
      expect(store.flags, 1);
      albums.complete([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first-home-guide')), findsOneWidget);
      expect(store.flags, 3);
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (name: 'loading', state: const AsyncLoading<MomentJournal?>()),
    (
      name: 'error',
      state: AsyncError<MomentJournal?>(
        StateError('journal unavailable'),
        StackTrace.empty,
      ),
    ),
    (name: 'guest', state: const AsyncData<MomentJournal?>(null)),
  ]) {
    testWidgets(
      'an unavailable journal keeps the first guide pending: ${sample.name}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = MemoryFirstVisitStore(1);
        await tester.pumpWidget(
          reviewApp(
            const HomeScreen(),
            overrides: [
              firstVisitStoreProvider.overrideWithValue(store),
              momentEntryJournalProvider.overrideWithValue(sample.state),
              momentsSessionProvider.overrideWith((_) => Stream.value(null)),
              momentsCurrentUserIdProvider.overrideWith((_) => null),
              albumCreationDraftStoreProvider.overrideWithValue(
                MemoryCreationDraftStore(),
              ),
              notificationUnreadCountProvider.overrideWith((_) async => 0),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        await container.read(firstVisitProvider.future);
        expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
        expect(store.flags, 1);
        expect(store.writes, isEmpty);
        container.read(firstVisitProvider.notifier).requestHomeGuide();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('first-home-guide')), findsNothing);
        expect(
          container.read(firstVisitProvider).requireValue.homeGuideRequested,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'real home and profile replay share one guide without mounting the store',
    (tester) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        SharedPreferences.setMockInitialValues({
          PreferencesFirstVisitStore.key: 1,
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const captureKey = ValueKey('first-visit-root-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: reviewApp(
              const HomeScreen(),
              overrides: [
                socialCurrentUserIdProvider.overrideWith((_) => 'qa'),
                socialAuthStateProvider.overrideWith(
                  (_) => const Stream<String?>.empty(),
                ),
                ownSocialProfileProvider.overrideWith(
                  (_) async => const SocialProfile(
                    userId: 'qa',
                    displayName: '나의 공개 기록',
                    handle: 'my.public',
                  ),
                ),
                socialProfileWorksPageProvider(
                  const SocialProfileWorksQuery('qa'),
                ).overrideWith(
                  (_) async => const SocialWorkPage(
                    items: [],
                    hasMore: false,
                    nextOffset: 0,
                  ),
                ),
                socialOwnWorksPageProvider(
                  const SocialOwnWorksQuery(),
                ).overrideWith(
                  (_) async => const SocialWorkPage(
                    items: [],
                    hasMore: false,
                    nextOffset: 0,
                  ),
                ),
                momentsSessionProvider.overrideWith((_) => Stream.value(null)),
                momentsCurrentUserIdProvider.overrideWith((_) => null),
                // A cached journal must wait for the final home body, too.
                momentEntryJournalProvider.overrideWithValue(
                  AsyncData(_emptyJournal()),
                ),
                momentDraftStoreProvider.overrideWithValue(
                  MemoryMomentDraftStore(),
                ),
                albumCreationDraftStoreProvider.overrideWithValue(
                  MemoryCreationDraftStore(),
                ),
                notificationUnreadCountProvider.overrideWith((_) async => 0),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final guide = find.byKey(const ValueKey('first-home-guide'));
        expect(guide, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HomeMomentSummaryCard),
            matching: guide,
          ),
          findsOneWidget,
        );
        expect(
          tester.getRect(guide).bottom,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('home-monthly-feed-week')))
                .top,
          ),
        );
        expect(find.byType(HomeEmptyState), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        expect(container.exists(storeTemplateFeedProvider), isFalse);
        expect(container.read(firstVisitProvider).requireValue.flags, 3);
        await tester.runAsync(() async {
          for (final asset in [
            'ocean_shore',
            'spring_flowers',
            'alpine_lake',
          ]) {
            await precacheImage(
              ResizeImage(
                AssetImage('assets/frame_preview/$asset.jpg'),
                width: 512,
              ),
              tester.element(find.byType(HomeEmptyState)),
            );
          }
        });
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(captureKey),
          matchesGoldenFile('goldens/first_home_guide_390x844.png'),
        );
        // A replay must bring the inline guide back after a scrolled home visit.
        await tester.drag(
          find
              .descendant(
                of: find.byType(HomeEmptyState),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(guide.hitTestable(), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(HomeBottomNavigationBar),
            matching: find.byTooltip('마이'),
          ),
        );
        await tester.pumpAndSettle();
        expect(guide, findsNothing);
        expect(find.byType(SocialProfileScreen), findsOneWidget);
        expect(find.byType(MyPageScreen), findsNothing);
        expect(container.read(homeUiStateProvider).bottomNavIndex, 4);
        expect(container.exists(storeTemplateFeedProvider), isFalse);
        expect(container.read(socialCurrentUserIdProvider), 'qa');
        expect(container.read(authViewModelProvider).requireValue?.id, 'qa');
        expect(container.read(visibleOrderOwnerProvider), 'qa');
        expect(find.byTooltip('설정').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('설정'));
        await tester.pumpAndSettle();
        expect(find.byType(MyPageScreen), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('앱 사용 가이드'),
          250,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('profile-menu-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('앱 사용 가이드'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('메인 안내 다시 보기'));
        await tester.pumpAndSettle();
        expect(find.byType(MyPageScreen), findsNothing);
        expect(container.read(homeUiStateProvider).bottomNavIndex, 0);
        expect(find.byType(HomeEmptyState), findsOneWidget);
        expect(guide, findsOneWidget);
        expect(guide.hitTestable(), findsOneWidget);
        expect(find.byTooltip('안내 닫기').hitTestable(), findsOneWidget);
        expect(container.exists(storeTemplateFeedProvider), isFalse);
        expect(container.read(firstVisitProvider).requireValue.flags, 3);
        expect(
          container.read(firstVisitProvider).requireValue.homeGuideRequested,
          isFalse,
        );
        await tester.tap(find.byTooltip('안내 닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('앨범 목록'));
        await tester.pumpAndSettle();
        expect(guide, findsNothing);
        await tester.tap(find.byTooltip('표지로 보기'));
        await tester.pumpAndSettle();
        expect(guide, findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = previousShadows;
      }
    },
  );
}

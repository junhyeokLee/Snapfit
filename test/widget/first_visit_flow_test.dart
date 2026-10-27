import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/memory_moment_draft_store.dart';

void main() {
  setUpAll(loadCreationFonts);

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
        const captureKey = ValueKey('first-visit-root-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: ProviderScope(
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
                momentDraftStoreProvider.overrideWithValue(
                  MemoryMomentDraftStore(),
                ),
                albumCreationDraftStoreProvider.overrideWithValue(
                  MemoryCreationDraftStore(),
                ),
                notificationUnreadCountProvider.overrideWith((_) async => 0),
              ],
              child: reviewApp(const HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final guide = find.byKey(const ValueKey('first-home-guide'));
        expect(guide, findsOneWidget);
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

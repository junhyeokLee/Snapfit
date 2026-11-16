import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_works_manage_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';

class _Repository extends Mock implements SocialRepository {}

SocialWork _album({bool restricted = true, bool staleImages = false}) =>
    SocialWork(
      id: 'limited-album',
      author: const SocialProfile(
        userId: 'owner',
        displayName: '앨범 주인',
        handle: 'owner',
      ),
      title: '보관할 원본 앨범',
      caption: '다른 사람에게 보여주면 안 되는 제한된 소개',
      createdAt: DateTime.utc(2026, 10, 28),
      status: 'private',
      isRestricted: restricted,
      imageUrls: staleImages
          ? const ['https://fixture.invalid/stale-limited.png']
          : const [],
    );

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository, {
  required Widget screen,
  required SocialWork Function() work,
  String actor = 'owner',
  bool darkLarge = false,
  void Function()? onComments,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = darkLarge
      ? const Size(320, 568)
      : const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWithValue(actor),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository),
      socialWorkProvider.overrideWith((_, _) async => work()),
      socialOwnWorksPageProvider.overrideWith(
        (_, _) async =>
            SocialWorkPage(items: [work()], hasMore: false, nextOffset: 1),
      ),
      socialCommentsPageProvider.overrideWith((_, _) async {
        onComments?.call();
        return const SocialCommentPage(
          items: [],
          hasMore: false,
          nextOffset: 0,
        );
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: darkLarge ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(darkLarge ? 1.8 : 1)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final darkLarge in [false, true]) {
    testWidgets(
      'restricted owner publication has no image retry or republish action darkLarge=$darkLarge',
      (tester) async {
        final repository = _Repository();
        await _mount(
          tester,
          repository,
          screen: const SocialWorksManageScreen(),
          work: () => _album(),
          darkLarge: darkLarge,
        );
        expect(find.text('공개 제한 · 원본은 그대로 보관돼요.'), findsOneWidget);
        final visibility = find.byKey(
          const ValueKey('social-manage-visibility-limited-album'),
        );
        expect(tester.widget<OutlinedButton>(visibility).onPressed, isNull);
        expect(find.text('공개 제한 중'), findsOneWidget);
        expect(find.byType(SocialWorkImage), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        verifyNever(() => repository.setWorkVisibility(any(), true));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a held old republish callback rechecks the latest restriction before opening a confirmation',
    (tester) async {
      final repository = _Repository();
      var restricted = false;
      final container = await _mount(
        tester,
        repository,
        screen: const SocialWorksManageScreen(),
        work: () => _album(restricted: restricted),
      );
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(
              const ValueKey('social-manage-visibility-limited-album'),
            ),
          )
          .onPressed!;
      restricted = true;
      container.invalidate(socialOwnWorksPageProvider);
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(find.text('이 공개본을 다시 공개할까요?'), findsNothing);
      verifyNever(() => repository.setWorkVisibility(any(), true));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restriction arriving during confirmation blocks the previously selected republish',
    (tester) async {
      final repository = _Repository();
      var restricted = false;
      final container = await _mount(
        tester,
        repository,
        screen: const SocialWorksManageScreen(),
        work: () => _album(restricted: restricted),
      );
      await tester.tap(
        find.byKey(const ValueKey('social-manage-visibility-limited-album')),
      );
      await tester.pumpAndSettle();
      restricted = true;
      container.invalidate(socialOwnWorksPageProvider);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '다시 공개'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.setWorkVisibility(any(), true));
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey('social-manage-visibility-limited-album'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'owner detail explains restriction and ignores even a retained old snapshot URL',
    (tester) async {
      var comments = 0;
      await _mount(
        tester,
        _Repository(),
        screen: const SocialWorkDetailScreen(
          workId: 'limited-album',
          showComments: true,
        ),
        work: () => _album(staleImages: true),
        onComments: () => comments++,
      );
      expect(find.text('공개가 제한된 앨범이에요. 원본은 그대로 보관돼요.'), findsOneWidget);
      expect(find.byType(SocialArtworkPlaceholder), findsOneWidget);
      expect(find.byType(SocialWorkImage), findsNothing);
      expect(find.byTooltip('앨범 크게 보기'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(comments, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restricted owner snapshots are not disclosed to another account',
    (tester) async {
      await _mount(
        tester,
        _Repository(),
        screen: const SocialWorkDetailScreen(workId: 'limited-album'),
        actor: 'visitor',
        work: () => _album(staleImages: true),
      );
      expect(find.text('보관할 원본 앨범'), findsNothing);
      expect(find.text('다른 사람에게 보여주면 안 되는 제한된 소개'), findsNothing);
      expect(find.byType(SocialWorkImage), findsNothing);
      expect(find.byType(SocialEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared cards render restricted snapshots without starting stale image requests',
    (tester) async {
      final work = _album(staleImages: true);
      await _mount(
        tester,
        _Repository(),
        work: () => work,
        screen: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SocialWorkTile(work: work, onTap: () {}),
                SocialProfileWorkTile(work: work, onTap: () {}),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(SocialWorkImage), findsNothing);
      expect(find.text('공개 제한'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}

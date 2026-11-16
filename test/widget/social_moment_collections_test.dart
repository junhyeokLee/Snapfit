import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_moment_month_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover.dart';

class _Guest extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => null;
}

const _person = SocialProfile(
  userId: 'author',
  displayName: '순간 수집가',
  handle: 'moments',
  worksCount: 1,
  momentsCount: 31,
);
SocialWork _record(String id, DateTime month) => SocialWork(
  id: id,
  kind: 'moment',
  author: _person,
  title: '기록 $id',
  recordDate: DateTime.utc(month.year, month.month, 18),
  createdAt: DateTime.utc(2026, 10, 28),
);
SocialMomentMonth _month(DateTime month, {int count = 31}) => SocialMomentMonth(
  month: month,
  recordCount: count,
  cover: _record('cover-${socialMomentMonthKey(month)}', month),
);
final _album = SocialWork(
  id: 'album',
  author: _person,
  title: '공개한 여행 앨범',
  createdAt: DateTime.utc(2026, 10, 27),
);

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  bool paginated = false,
  bool Function()? hidden,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(_Guest.new),
        socialCurrentUserIdProvider.overrideWith((_) => null),
        socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
        socialProfileProvider.overrideWith((_, __) async => _person),
        socialProfileWorksPageProvider.overrideWith(
          (_, __) async =>
              SocialWorkPage(items: [_album], hasMore: false, nextOffset: 1),
        ),
        socialProfileMomentMonthsPageProvider.overrideWith(
          (_, q) async => SocialMomentMonthsPage(
            items: hidden?.call() == true
                ? []
                : q.offset == 0
                ? [_month(DateTime.utc(2026, 10))]
                : [
                    _month(DateTime.utc(2026, 10)),
                    _month(DateTime.utc(2025, 10), count: 4),
                  ],
            hasMore: paginated && q.offset == 0,
            nextOffset: q.offset + 6,
          ),
        ),
        socialMomentMonthPageProvider.overrideWith(
          (_, q) async => SocialWorkPage(
            items: [_record('first', q.month)],
            hasMore: false,
            nextOffset: 1,
          ),
        ),
      ],
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SocialProfileScreen(userId: 'author'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '31 public records occupy one monthly book and open that calendar month',
    (tester) async {
      await _mount(tester);
      expect(find.byType(SocialMomentMonthCover), findsOneWidget);
      expect(find.text('공개 기록 31개'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('social-profile-work-first')),
        findsNothing,
      );
      expect(find.text(_album.title), findsNothing);
      expect(find.text('포인트'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('social-moment-month-2026-10-01')),
      );
      await tester.pumpAndSettle();
      final screen = tester.widget<SocialMomentMonthScreen>(
        find.byType(SocialMomentMonthScreen),
      );
      expect(screen.userId, 'author');
      expect(screen.month, DateTime.utc(2026, 10));
      expect(find.text('기록 first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'month pagination deduplicates a repeated month and distinguishes the same month in another year',
    (tester) async {
      await _mount(tester, paginated: true);
      final more = find.byKey(const ValueKey('social-profile-more-moments'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialMomentMonthCover), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('social-moment-month-2026-10-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-moment-month-2025-10-01')),
        findsOneWidget,
      );
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'published albums remain separate from the monthly record collection',
    (tester) async {
      await _mount(tester);
      await tester.tap(find.byKey(const ValueKey('profile-collection-albums')));
      await tester.pumpAndSettle();
      expect(find.text(_album.title), findsOneWidget);
      expect(find.byType(SocialMomentMonthCover), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('profile-collection-moments')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SocialMomentMonthCover), findsOneWidget);
      expect(find.text(_album.title), findsNothing);
    },
  );
  testWidgets(
    'withdrawing the last public record removes its month without showing a private cover',
    (tester) async {
      var hidden = false;
      await _mount(tester, hidden: () => hidden);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialProfileScreen)),
      );
      hidden = true;
      container.invalidate(socialProfileMomentMonthsPageProvider);
      await tester.pumpAndSettle();
      expect(find.byType(SocialMomentMonthCover), findsNothing);
      expect(find.text('아직 공개한 기록이 없어요.'), findsOneWidget);
      expect(find.text('나만 보는 활동'), findsNothing);
    },
  );
  for (final size in [const Size(320, 568), const Size(1440, 1000)]) {
    testWidgets(
      'monthly book stays square and readable at $size with large dark text',
      (tester) async {
        await _mount(tester, size: size, scale: 2.2, dark: true);
        final cover = find.byType(SocialMomentMonthCover);
        expect(cover, findsOneWidget);
        expect(find.text('공개 기록 31개'), findsOneWidget);
        final square = find
            .descendant(of: cover, matching: find.byType(AspectRatio))
            .first;
        expect(tester.getSize(square).aspectRatio, closeTo(1, .001));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

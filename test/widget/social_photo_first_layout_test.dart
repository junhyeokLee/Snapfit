import 'dart:ui' show SemanticsAction;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_search_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_page_header.dart';
import 'package:snap_fit/shared/web/web_design.dart';

class _Guest extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => null;
}

const _author = SocialProfile(
  userId: 'author',
  displayName: '오늘을 담아요',
  handle: 'today',
);
final _work = SocialWork(
  id: 'photo-first',
  kind: 'moment',
  author: _author,
  title: '오후의 기록',
  createdAt: DateTime.utc(2026, 10, 28),
);

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(_Guest.new),
        socialCurrentUserIdProvider.overrideWith((_) => null),
        socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
        socialFeedProvider.overrideWith(
          (_, __) async =>
              SocialWorkPage(items: [_work], hasMore: false, nextOffset: 1),
        ),
        socialWorkProvider.overrideWith((_, __) async => _work),
      ],
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: WebNavigationScope(
            onNavigate: (_) {},
            onNotifications: () {},
            child: child!,
          ),
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final exceptionReporter = reportTestException;
  setUpAll(() {
    reportTestException = (details, description) {
      // Browser console formatting can omit these details in CLI reporters.
      // ignore: avoid_print
      print('Layout failure: ${details.exceptionAsString()}');
      exceptionReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  testWidgets(
    'the first feed photograph starts early enough to be visible before scrolling',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, const SocialFeedScreen());
        final art = find.byKey(
          const ValueKey('social-feed-artwork-photo-first'),
        );
        expect(tester.getTopLeft(art).dy, lessThan(kIsWeb ? 320 : 240));
        expect(tester.getSize(art).width, greaterThan(340));
        expect(tester.getBottomLeft(art).dy, lessThan(844));
        expect(find.text('다른 사람의 시선에서, 내 앨범의 영감을 만나보세요.'), findsNothing);
        expect(find.text('작품 자세히 보기'), findsNothing);
        expect(find.byTooltip('기록·앨범·사용자 검색').hitTestable(), findsOneWidget);
        expect(find.byTooltip('저장한 기록·앨범').hitTestable(), findsOneWidget);
        expect(find.byTooltip('한 장의 기록 남기기').hitTestable(), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('오후의 기록, 기록 자세히 보기'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final screen in [
    const SocialFeedScreen(),
    const SocialSearchScreen(),
    const SocialWorkDetailScreen(workId: 'photo-first'),
  ]) {
    testWidgets(
      '${screen.runtimeType} uses the same toolbar and stays readable in narrow large text',
      (tester) async {
        await _mount(
          tester,
          screen,
          size: const Size(320, 568),
          scale: 2,
          dark: true,
        );
        expect(find.byType(SocialPageHeader), findsOneWidget);
        expect(
          tester
              .widget<SocialPageHeader>(find.byType(SocialPageHeader))
              .preferredSize
              .height,
          60,
        );
        expect(tester.takeException(), isNull);
        if (screen is! SocialFeedScreen)
          expect(find.byTooltip('뒤로가기').hitTestable(), findsOneWidget);
      },
    );
  }
}

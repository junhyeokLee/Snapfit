import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:snap_fit/features/onboarding/presentation/first_visit_controller.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'experience_detail_redesign_test.dart' show reviewApp;
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;
  bool logoutCalled = false;

  @override
  FutureOr<UserInfo?> build() => user;

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

void main() {
  setUpAll(loadCreationFonts);
  testWidgets(
    'usage help replays intro and requests the main guide without resetting flags',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        PreferencesFirstVisitStore.key: 3,
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int? destination;
      await tester.pumpWidget(
        reviewApp(
          ExperienceNavigationScope(
            onNavigate: (index) => destination = index,
            onBack: () {},
            child: const MyPageScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> openHelp() async {
        await tester.scrollUntilVisible(
          find.text('앱 사용 가이드'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('앱 사용 가이드'));
        await tester.pumpAndSettle();
      }

      await openHelp();
      await tester.tap(find.text('앱 소개 다시 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AppIntroductionScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('intro-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(MyPageScreen), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          PreferencesFirstVisitStore.key,
        ),
        3,
      );
      await openHelp();
      await tester.tap(find.text('메인 안내 다시 보기'));
      await tester.pumpAndSettle();
      expect(destination, 0);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyPageScreen)),
      );
      expect(
        container.read(firstVisitProvider).requireValue.homeGuideRequested,
        isTrue,
      );
      expect(container.read(firstVisitProvider).requireValue.flags, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'settings keeps only settings and help with safe access after rotation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(reviewApp(const MyPageScreen()));
      await tester.pumpAndSettle();
      expect(find.text('설정 및 도움말'), findsOneWidget);
      expect(find.text('내 앨범'), findsNothing);
      expect(find.text('내 보관함'), findsNothing);
      expect(find.text('내 포인트'), findsNothing);
      expect(find.text('인쇄 주문 내역'), findsNothing);
      expect(find.text('snapfit@example.com'), findsNothing);
      for (final size in [const Size(648, 320), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        tester.view.padding = size.width > size.height
            ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
            : const FakeViewPadding(bottom: 24);
        await tester.pumpAndSettle();
        final scroll = find
            .descendant(
              of: find.byKey(const PageStorageKey('profile-menu-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        for (final title in ['화면 테마', '고객센터', '앱 사용 가이드', '이용 안내']) {
          await tester.scrollUntilVisible(
            find.text(title),
            160,
            scrollable: scroll,
          );
          await tester.ensureVisible(find.text(title));
          await tester.pumpAndSettle();
          expect(find.text(title).hitTestable(), findsOneWidget);
          final rect = tester.getRect(find.text(title));
          expect(
            rect.left,
            greaterThanOrEqualTo(size.width > size.height ? 44 : 0),
          );
          expect(
            rect.right,
            lessThan(size.width - (size.width > size.height ? 24 : 0)),
          );
          expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('profile opens account settings with a cancellable logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final fake = FakeAuthViewModel(
      const UserInfo(
        id: '1',
        name: 'Tester',
        provider: 'kakao',
        email: 'test@example.com',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(() => fake)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: MyPageScreen()),
        ),
      ),
    );

    await tester.tap(find.byTooltip('계정 설정'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsScreen), findsOneWidget);
    final logoutButton = find.text('로그아웃');
    await tester.scrollUntilVisible(
      logoutButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(fake.logoutCalled, isFalse);
    expect(find.byType(AccountSettingsScreen), findsOneWidget);
  });
}

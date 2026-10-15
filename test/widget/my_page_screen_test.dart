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
    'profile keeps expanded sections and safe menu access after rotation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(reviewApp(const MyPageScreen()));
      await tester.pumpAndSettle();
      final activity = find.byKey(const PageStorageKey('profile-activity'));
      await tester.scrollUntilVisible(
        activity,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('앨범 활동 및 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('앨범 활동 및 관리'));
      await tester.pumpAndSettle();
      expect(find.text('앨범과 저장 공간'), findsOneWidget);
      tester.view.physicalSize = const Size(648, 320);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 24,
        bottom: 24,
      );
      await tester.pumpAndSettle();
      final menus = find.byKey(const PageStorageKey('profile-menu-scroll'));
      expect(tester.getTopLeft(menus).dx, greaterThan(44));
      await tester.scrollUntilVisible(
        activity,
        180,
        scrollable: find
            .descendant(of: menus, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('앨범과 저장 공간'), findsOneWidget);
      final menuState = tester.state<ScrollableState>(
        find.descendant(of: menus, matching: find.byType(Scrollable)).first,
      );
      menuState.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('화면 테마'),
        160,
        scrollable: find
            .descendant(of: menus, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(find.text('화면 테마')).dy, lessThan(296));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        activity,
        180,
        scrollable: find
            .descendant(of: menus, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('앨범과 저장 공간'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

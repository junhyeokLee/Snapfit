import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';

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
  testWidgets('logout button calls auth logout and shows snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final fake = FakeAuthViewModel(
      const UserInfo(
        id: 1,
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

    final logoutButton = find.widgetWithText(TextButton, '로그아웃');
    await tester.scrollUntilVisible(
      logoutButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    final buttonWidget = tester.widget<TextButton>(logoutButton);
    buttonWidget.onPressed?.call();
    await tester.pumpAndSettle();

    expect(fake.logoutCalled, isTrue);
  });
}

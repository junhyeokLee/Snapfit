import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';
import 'package:snap_fit/core/navigation/app_root_route_observer.dart';
import 'package:snap_fit/features/onboarding/data/first_visit_store.dart';
import 'package:snap_fit/features/onboarding/presentation/app_introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel(this.user);

  final UserInfo? user;

  @override
  FutureOr<UserInfo?> build() => user;
}

class _SlowAuthViewModel extends AuthViewModel {
  _SlowAuthViewModel(this.result);
  final Future<UserInfo?> result;
  @override
  Future<UserInfo?> build() => result;
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      PreferencesFirstVisitStore.key: 3,
    }),
  );
  testWidgets('first introduction never waits for a slow account response', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = Completer<UserInfo?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(
            () => _SlowAuthViewModel(auth.future),
          ),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(auth.isCompleted, isFalse);
    expect(find.byType(AppIntroductionScreen), findsOneWidget);
    auth.complete(null);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('SplashScreen navigates to LoginScreen after minimum delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => FakeAuthViewModel(null)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: SplashScreen()),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'first install shows intro before auth root; skip persists across restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var roots = 0;
      final observer = AppRootRouteObserver(onReady: () => roots++);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeAuthViewModel(null)),
          ],
          child: MaterialApp(
            home: const SplashScreen(),
            navigatorObservers: [observer],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(find.byType(AppIntroductionScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(roots, 0);
      await tester.tap(find.byKey(const ValueKey('intro-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(roots, 1);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          PreferencesFirstVisitStore.key,
        ),
        3,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => FakeAuthViewModel(null)),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(find.byType(AppIntroductionScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}

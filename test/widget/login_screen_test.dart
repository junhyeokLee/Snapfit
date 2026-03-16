import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({
    this.user,
    Completer<void>? kakaoCompleter,
    Completer<void>? googleCompleter,
  }) : _kakaoCompleter = kakaoCompleter ?? Completer<void>(),
       _googleCompleter = googleCompleter ?? Completer<void>();

  final UserInfo? user;
  final Completer<void> _kakaoCompleter;
  final Completer<void> _googleCompleter;
  bool kakaoCalled = false;
  bool googleCalled = false;

  @override
  FutureOr<UserInfo?> build() => user;

  @override
  Future<void> loginWithKakao() async {
    kakaoCalled = true;
    await _kakaoCompleter.future;
  }

  @override
  Future<void> loginWithGoogle() async {
    googleCalled = true;
    await _googleCompleter.future;
  }

  void completeKakao() => _kakaoCompleter.complete();

  void completeGoogle() => _googleCompleter.complete();
}

void main() {
  testWidgets('kakao login button triggers loading and calls auth', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(() => fake)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: LoginScreen()),
        ),
      ),
    );

    await tester.tap(find.text('카카오로 시작'));
    await tester.pump();

    expect(fake.kakaoCalled, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fake.completeKakao();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('google login button triggers loading and calls auth', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(() => fake)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => const MaterialApp(home: LoginScreen()),
        ),
      ),
    );

    await tester.tap(find.text('구글로 시작'));
    await tester.pump();

    expect(fake.googleCalled, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fake.completeGoogle();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

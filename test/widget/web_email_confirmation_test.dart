import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'login_screen_test.dart'
    show FakeAuthViewModel, FakeTokenStorage, fillSignUp;

class _OtpAuth extends FakeAuthViewModel {
  final attempts = <({String email, String token, Completer<void> result})>[];
  Object? loginError;

  @override
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    await super.loginWithEmail(email: email, password: password);
    if (loginError != null) throw loginError!;
  }

  @override
  Future<void> verifyEmailConfirmation({
    required String email,
    required String token,
  }) async {
    final result = Completer<void>();
    attempts.add((email: email, token: token, result: result));
    await result.future;
  }
}

final _code = find.byKey(const ValueKey('auth-field-인증번호'));
final _verify = find.byKey(const ValueKey('auth-confirmation-verify'));
final _resend = find.byKey(const ValueKey('auth-confirmation-resend'));

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _mount(WidgetTester tester, _OtpAuth auth) async {
  tester.view.physicalSize = kIsWeb
      ? const Size(1280, 900)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        authServiceProvider.overrideWith(
          (_) => throw StateError('Real authentication is forbidden.'),
        ),
        supabaseClientProvider.overrideWith(
          (_) => throw StateError('Backend access is forbidden.'),
        ),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => const MaterialApp(home: LoginScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _signup(WidgetTester tester, _OtpAuth auth) async {
  await _mount(tester, auth);
  await fillSignUp(tester);
  await _tap(tester, find.byKey(const ValueKey('auth-signup-submit')));
  await tester.pumpAndSettle();
}

void main() {
  test('executes the requested browser platform', () {
    expect(kIsWeb, const bool.fromEnvironment('SNAPFIT_EXPECT_WEB'));
  });

  testWidgets(
    'unconfirmed web email login opens code recovery without signup or automatic resend',
    (tester) async {
      final auth = _OtpAuth()
        ..loginError = const AuthException(
          'private-fixture',
          code: 'email_not_confirmed',
        );
      await _mount(tester, auth);
      await _tap(tester, find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'existing@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호 입력'),
        'fixture-password',
      );
      await _tap(tester, find.byKey(const ValueKey('auth-email-submit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('signup_confirmation_email')),
            )
            .data,
        'existing@example.com',
      );
      expect(_code, findsOneWidget);
      expect(auth.emailSignUpCalled, isFalse);
      expect(auth.confirmationResendCalls, 0);
      expect(tester.widget<OutlinedButton>(_resend).onPressed, isNotNull);
      await _tap(tester, _resend);
      await tester.pumpAndSettle();
      expect(auth.resentEmail, 'existing@example.com');
      await tester.enterText(_code, '01234567');
      await _tap(tester, _verify);
      expect(auth.attempts.single.email, 'existing@example.com');
      auth.attempts.single.result.complete();
      await tester.pumpAndSettle();
      expect(auth.emailSignUpCalled, isFalse);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'web verification validates eight digits and blocks repeated submission',
    (tester) async {
      final auth = _OtpAuth();
      await _signup(tester, auth);
      expect(find.text('인증 완료'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_resend).onPressed, isNull);
      await tester.enterText(_code, '12ab34');
      expect(tester.widget<TextFormField>(_code).controller!.text, '1234');
      await _tap(tester, _verify);
      expect(auth.attempts, isEmpty);
      expect(find.text('메일의 8자리 인증번호를 입력해주세요.'), findsOneWidget);

      await tester.enterText(_code, '01234567');
      final submit = tester.widget<ElevatedButton>(_verify).onPressed!;
      submit();
      await tester.pump();
      submit();
      await tester.pump();
      expect(auth.attempts, hasLength(1));
      expect(auth.attempts.single.email, 'album@example.com');
      expect(auth.attempts.single.token, '01234567');
      expect(tester.widget<TextFormField>(_code).enabled, isFalse);
      expect(tester.widget<ElevatedButton>(_verify).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(_resend).onPressed, isNull);
      auth.attempts.single.result.completeError(
        const AuthException('private-fixture', code: 'otp_expired'),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(_code).enabled, isTrue);
      expect(tester.widget<ElevatedButton>(_verify).onPressed, isNotNull);
      expect(find.textContaining('private-fixture'), findsNothing);
      expect(auth.emailLoginCalled, isFalse);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'web verification retries after a network failure without inventing a signed-in user',
    (tester) async {
      final auth = _OtpAuth();
      await _signup(tester, auth);
      await tester.enterText(_code, '01234567');
      await _tap(tester, _verify);
      auth.attempts.single.result.completeError(
        TimeoutException('private-fixture'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private-fixture'), findsNothing);
      expect(tester.widget<ElevatedButton>(_verify).onPressed, isNotNull);
      expect(tester.widget<TextFormField>(_code).controller!.text, '01234567');
      await _tap(tester, _verify);
      expect(auth.attempts, hasLength(2));
      auth.attempts.last.result.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(_code).controller!.text, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(auth.emailLoginCalled, isFalse);
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'successful resend clears the previous code and keeps its cooldown',
    (tester) async {
      final auth = _OtpAuth();
      await _signup(tester, auth);
      await tester.enterText(_code, '01234567');
      await tester.pump(const Duration(seconds: 60));
      await _tap(tester, _resend);
      await tester.pumpAndSettle();
      expect(auth.confirmationResendCalls, 1);
      expect(auth.resentEmail, 'album@example.com');
      expect(tester.widget<TextFormField>(_code).controller!.text, isEmpty);
      expect(tester.widget<OutlinedButton>(_resend).onPressed, isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'correcting the signup address discards the code and rejects a stale submit action',
    (tester) async {
      final auth = _OtpAuth();
      await _signup(tester, auth);
      await tester.enterText(_code, '01234567');
      final oldSubmit = tester.widget<ElevatedButton>(_verify).onPressed!;
      await _tap(tester, find.text('이메일을 잘못 입력했어요'));
      await tester.pumpAndSettle();
      oldSubmit();
      await tester.pump();
      expect(auth.attempts, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'corrected@example.com',
      );
      await _tap(tester, find.byKey(const ValueKey('auth-signup-submit')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const Key('signup_confirmation_email')),
            )
            .data,
        'corrected@example.com',
      );
      expect(tester.widget<TextFormField>(_code).controller!.text, isEmpty);
      expect(auth.attempts, isEmpty);
    },
    skip: !kIsWeb,
  );

  testWidgets('native confirmation keeps the existing email-link flow', (
    tester,
  ) async {
    final auth = _OtpAuth();
    await _signup(tester, auth);
    expect(_code, findsNothing);
    expect(_verify, findsNothing);
    expect(
      find.widgetWithText(ElevatedButton, '인증 후 이메일로 로그인'),
      findsOneWidget,
    );
  }, skip: kIsWeb);
}

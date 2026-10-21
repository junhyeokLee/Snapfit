import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

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
  bool emailSignUpCalled = false;
  bool emailLoginCalled = false;
  bool passwordResetRequested = false;
  bool confirmationResent = false;
  int confirmationResendCalls = 0;
  bool passwordUpdated = false;
  String? signedUpEmail;
  String? signedUpName;
  bool? signedUpMarketing;
  String? loggedInEmail;
  String? passwordResetEmail;
  String? resentEmail;
  Object? signUpError;
  Object? passwordResetError;
  Object? confirmationResendError;

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

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    emailSignUpCalled = true;
    signedUpEmail = email;
    signedUpName = name;
    signedUpMarketing = marketingOptIn;
    if (signUpError != null) throw signUpError!;
  }

  @override
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emailLoginCalled = true;
    loggedInEmail = email;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetRequested = true;
    passwordResetEmail = email;
    if (passwordResetError != null) throw passwordResetError!;
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    confirmationResent = true;
    confirmationResendCalls++;
    resentEmail = email;
    if (confirmationResendError != null) throw confirmationResendError!;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwordUpdated = true;
  }
}

class FakeTokenStorage extends TokenStorage {
  @override
  Future<bool> hasRequiredConsent({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    return true;
  }

  @override
  Future<void> saveConsent({
    required String termsVersion,
    required String privacyVersion,
    required bool marketingOptIn,
    required String agreedAtIso,
  }) async {}
}

Future<void> pumpLoginScreen(
  WidgetTester tester,
  FakeAuthViewModel fake, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() => fake),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder socialButton(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(ElevatedButton),
  );
}

class _ControlledEmailAuth extends FakeAuthViewModel {
  final login = Completer<void>();

  @override
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    emailLoginCalled = true;
    loggedInEmail = email;
    await login.future;
  }
}

Future<void> fillSignUp(WidgetTester tester) async {
  await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
  await tester.tap(find.text('이메일로 새 계정 만들기'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, '앨범에 표시할 이름'),
    '우리앨범',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'snapfit@example.com'),
    'album@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, '8자 이상'),
    'album1234',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, '한 번 더 입력'),
    'album1234',
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < 2; i++) {
    await tester.ensureVisible(find.byType(Checkbox).at(i));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(i));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(i)).value, isTrue);
  }
}

void main() {
  testWidgets(
    'rejected signup delivery stays editable without claiming mail sent',
    (tester) async {
      final fake = FakeAuthViewModel()
        ..signUpError = const AuthException(
          'Email address not authorized',
          code: 'email_address_not_authorized',
        );
      await pumpLoginScreen(tester, fake);
      await fillSignUp(tester);
      await tester.ensureVisible(find.text('계정 만들기'));
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();

      expect(fake.emailSignUpCalled, isTrue);
      expect(find.byKey(const Key('signup_confirmation_email')), findsNothing);
      expect(find.text('가입 메일 확인'), findsNothing);
      expect(
        find.text('이메일 발송을 이용할 수 없는 상태예요. 다른 로그인 방법을 이용하거나 고객센터에 문의해주세요.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '계정 만들기'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('failed resend clears the prior successful delivery notice', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake);
    await fillSignUp(tester);
    await tester.ensureVisible(find.text('계정 만들기'));
    await tester.tap(find.text('계정 만들기'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 60));
    await tester.ensureVisible(find.text('인증 메일 다시 보내기'));
    await tester.tap(find.text('인증 메일 다시 보내기'));
    await tester.pumpAndSettle();
    expect(
      find.text('방금 인증 메일을 다시 보냈어요. 가장 최근 메일의 링크를 열어주세요.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 60));
    fake.confirmationResendError = const AuthException(
      'Error sending confirmation email',
      code: 'unexpected_failure',
      statusCode: '500',
    );
    await tester.ensureVisible(find.text('인증 메일 다시 보내기'));
    await tester.tap(find.text('인증 메일 다시 보내기'));
    await tester.pumpAndSettle();

    expect(fake.confirmationResendCalls, 2);
    expect(find.text('인증 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.'), findsOneWidget);
    expect(find.text('방금 인증 메일을 다시 보냈어요. 가장 최근 메일의 링크를 열어주세요.'), findsNothing);
    expect(find.text('인증 메일을 다시 보냈어요.'), findsNothing);
    expect(find.text('이메일 인증을 먼저 완료해주세요.'), findsNothing);
  });

  testWidgets(
    'failed password reset delivery does not show success or login error',
    (tester) async {
      final fake = FakeAuthViewModel()
        ..passwordResetError = const AuthException(
          'Error sending recovery email',
          code: 'unexpected_failure',
        );
      await pumpLoginScreen(tester, fake);
      await tester.ensureVisible(find.text('이메일로 로그인'));
      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('비밀번호를 잊으셨나요?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'album@example.com',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fake.passwordResetRequested, isTrue);
      expect(
        find.text('비밀번호 재설정 메일을 보내지 못했어요. 잠시 후 다시 시도해주세요.'),
        findsOneWidget,
      );
      expect(find.text('비밀번호 재설정 메일을 보냈어요.'), findsNothing);
      expect(find.text('이메일 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '재설정 메일 보내기'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    testWidgets(
      'signup and verification remain reachable with large text, keyboard and system insets at $size',
      (tester) async {
        tester.view.padding = FakeViewPadding(
          top: 24,
          bottom: 24,
          right: size.width > size.height ? 24 : 0,
          left: size.width > size.height ? 44 : 0,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 160);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final fake = FakeAuthViewModel();
        await pumpLoginScreen(tester, fake, size: size, textScale: 1.5);
        await fillSignUp(tester);
        await tester.ensureVisible(find.text('계정 만들기'));
        await tester.tap(find.text('계정 만들기'));
        await tester.pumpAndSettle();
        expect(fake.emailSignUpCalled, isTrue);
        expect(find.text('album@example.com'), findsOneWidget);
        await tester.ensureVisible(find.text('인증 후 이메일로 로그인'));
        await tester.tap(find.text('인증 후 이메일로 로그인'));
        await tester.pumpAndSettle();
        expect(find.text('이메일로 계속하기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'nickname and required consents are enough; marketing remains optional',
    (tester) async {
      final fake = FakeAuthViewModel();
      await pumpLoginScreen(tester, fake);
      await fillSignUp(tester);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).last).value,
        isFalse,
      );
      await tester.ensureVisible(find.text('계정 만들기'));
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();
      expect(fake.signedUpName, '우리앨범');
      expect(fake.signedUpMarketing, isFalse);
      expect(find.text('album@example.com'), findsOneWidget);
      expect(
        find.byKey(const Key('signup_confirmation_email')),
        findsOneWidget,
      );
      expect(
        find.text('메일의 인증 링크를 열면 가입이 완료돼요. 메일이 보이지 않으면 스팸함도 확인해주세요.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('password indicators track the existing validation rules', (
    tester,
  ) async {
    await pumpLoginScreen(tester, FakeAuthViewModel());
    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();
    final password = find.widgetWithText(TextFormField, '8자 이상');
    bool satisfied(String rule) => find
        .descendant(
          of: find.byKey(ValueKey('password-rule-$rule')),
          matching: find.byIcon(Icons.check_circle_outline),
        )
        .evaluate()
        .isNotEmpty;
    await tester.enterText(password, 'abcdefg');
    await tester.pump();
    expect(satisfied('8자 이상'), isFalse);
    expect(satisfied('영문·숫자'), isFalse);
    expect(satisfied('공백 없이'), isTrue);
    await tester.enterText(password, 'abcdefg1');
    await tester.pump();
    expect(satisfied('8자 이상'), isTrue);
    expect(satisfied('영문·숫자'), isTrue);
    await tester.enterText(password, 'abcdefg1 ');
    await tester.pump();
    expect(satisfied('공백 없이'), isFalse);
    expect(find.text('비밀번호에는 공백을 사용할 수 없어요.'), findsOneWidget);
  });

  testWidgets(
    'verification resend is paced, and email login keeps the recipient',
    (tester) async {
      final fake = FakeAuthViewModel();
      await pumpLoginScreen(tester, fake);
      await fillSignUp(tester);
      await tester.ensureVisible(find.text('계정 만들기'));
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 60));
      await tester.ensureVisible(find.text('인증 메일 다시 보내기'));
      await tester.tap(find.text('인증 메일 다시 보내기'));
      await tester.pumpAndSettle();
      expect(fake.confirmationResendCalls, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('인증 후 이메일로 로그인'));
      await tester.tap(find.text('인증 후 이메일로 로그인'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'snapfit@example.com'),
            )
            .controller
            ?.text,
        'album@example.com',
      );
      expect(find.text('이메일로 계속하기'), findsOneWidget);
    },
  );

  testWidgets(
    'mistyped verification address returns to editable signup, not a fake account update',
    (tester) async {
      await pumpLoginScreen(tester, FakeAuthViewModel());
      await fillSignUp(tester);
      await tester.ensureVisible(find.text('계정 만들기'));
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('이메일을 잘못 입력했어요'));
      await tester.tap(find.text('이메일을 잘못 입력했어요'));
      await tester.pumpAndSettle();
      expect(find.text('새 계정 만들기'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'snapfit@example.com'),
            )
            .controller
            ?.text,
        'album@example.com',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, '앨범에 표시할 이름'),
            )
            .controller
            ?.text,
        '우리앨범',
      );
      expect(find.byKey(const Key('signup_confirmation_email')), findsNothing);
    },
  );

  testWidgets(
    'keyboard submit locks inputs, keeps errors inline, and allows retry',
    (tester) async {
      final fake = _ControlledEmailAuth();
      await pumpLoginScreen(tester, fake);
      await tester.ensureVisible(find.text('이메일로 로그인'));
      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'album@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '비밀번호 입력'),
        'album1234',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fake.emailLoginCalled, isTrue);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == '소셜 로그인으로 돌아가기',
              ),
            )
            .onPressed,
        isNull,
      );
      fake.login.completeError(Exception('invalid credentials'));
      await tester.pumpAndSettle();
      expect(find.text('이메일 또는 비밀번호가 올바르지 않아요.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isTrue);
      }
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'snapfit@example.com'),
            )
            .controller
            ?.text,
        'album@example.com',
      );
    },
  );

  testWidgets(
    'reset email shows pacing and cannot be requested twice immediately',
    (tester) async {
      final fake = FakeAuthViewModel();
      await pumpLoginScreen(tester, fake);
      await tester.ensureVisible(find.text('이메일로 로그인'));
      await tester.tap(find.text('이메일로 로그인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('비밀번호를 잊으셨나요?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'album@example.com',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.passwordResetRequested, isTrue);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '60초 후 다시 보내기'),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 60));
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '재설정 메일 다시 보내기'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('kakao login button triggers loading and calls auth', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.tap(socialButton('카카오로 계속하기'));
    await tester.pump();

    expect(fake.kakaoCalled, isTrue);
    expect(find.text('로그인 중…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    fake.completeKakao();
  });

  testWidgets('login screen renders in portrait and landscape', (tester) async {
    final fake = FakeAuthViewModel();

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => fake),
            tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, __) => MaterialApp(
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              home: const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpAt(const Size(390, 844));
    expect(find.text('SnapFit'), findsOneWidget);
    expect(find.text('내 앨범으로 계속하기'), findsOneWidget);

    await pumpAt(const Size(844, 390));
    expect(find.text('SnapFit'), findsOneWidget);
    expect(find.text('내 앨범으로 계속하기'), findsOneWidget);
  });

  testWidgets('signup form stays renderable on compact landscape phones', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake, size: const Size(844, 390));

    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('새 계정 만들기'), findsOneWidget);
    expect(find.text('계정 만들기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('google login button triggers loading and calls auth', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.tap(socialButton('Google로 계속하기'));
    await tester.pump();

    expect(fake.googleCalled, isTrue);
    expect(find.text('로그인 중…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    fake.completeGoogle();
  });

  testWidgets('loading spinner appears only on the selected provider button', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.tap(socialButton('카카오로 계속하기'));
    await tester.pump();

    final kakaoButton = find.ancestor(
      of: find.text('카카오로 계속하기'),
      matching: find.byType(ElevatedButton),
    );
    final googleButton = find.ancestor(
      of: find.text('Google로 계속하기'),
      matching: find.byType(ElevatedButton),
    );

    expect(
      find.descendant(
        of: kakaoButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: googleButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);

    fake.completeKakao();
  });

  testWidgets('email signup form renders and requires terms before submit', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('새 계정 만들기'), findsOneWidget);
    expect(find.text('닉네임'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('비밀번호 확인'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '계정 만들기'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox).at(0), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1), warnIfMissed: false);
    await tester.pump();

    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '계정 만들기'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('valid email signup submits through auth view model', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '앨범에 표시할 이름'),
      '준자',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'snapfit@example.com'),
      'junja@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '8자 이상'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '한 번 더 입력'),
      'password123',
    );
    await tester.tap(find.byType(Checkbox).at(0), warnIfMissed: false);
    await tester.tap(find.byType(Checkbox).at(1), warnIfMissed: false);
    await tester.pump();
    final createButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '계정 만들기'),
    );
    expect(createButton.onPressed, isNotNull);
    createButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.emailSignUpCalled, isTrue);
    expect(fake.signedUpEmail, 'junja@example.com');
    expect(find.text('가입 메일 확인'), findsOneWidget);
  });

  testWidgets('signup enforces stronger password rules', (tester) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake, size: const Size(390, 1200));

    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '8자 이상'),
      'password',
    );
    await tester.tap(find.byType(Checkbox).at(0), warnIfMissed: false);
    await tester.tap(find.byType(Checkbox).at(1), warnIfMissed: false);
    await tester.pump();
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '계정 만들기'))
        .onPressed!();
    await tester.pump();

    expect(find.text('비밀번호는 영문과 숫자를 함께 사용해주세요.'), findsOneWidget);
  });

  testWidgets('email login submits through auth view model', (tester) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake, size: const Size(390, 1000));

    await tester.ensureVisible(find.text('이메일로 로그인'));
    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('이메일로 계속하기'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'snapfit@example.com'),
      'junja@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '비밀번호 입력'),
      'password123',
    );
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '이메일로 로그인'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.emailLoginCalled, isTrue);
    expect(fake.loggedInEmail, 'junja@example.com');
  });

  testWidgets('forgot password sends reset email request', (tester) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake, size: const Size(390, 1000));

    await tester.ensureVisible(find.text('이메일로 로그인'));
    await tester.tap(find.text('이메일로 로그인'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'snapfit@example.com'),
      'junja@example.com',
    );
    await tester.tap(find.text('비밀번호를 잊으셨나요?'));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호 찾기'), findsOneWidget);
    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '재설정 메일 보내기'),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.passwordResetRequested, isTrue);
    expect(fake.passwordResetEmail, 'junja@example.com');
    expect(find.text('비밀번호 재설정 메일을 보냈어요.'), findsOneWidget);
  });

  testWidgets('signup confirmation can resend verification email', (
    tester,
  ) async {
    final fake = FakeAuthViewModel();
    await pumpLoginScreen(tester, fake, size: const Size(390, 1200));

    await tester.ensureVisible(find.text('이메일로 새 계정 만들기'));
    await tester.tap(find.text('이메일로 새 계정 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '앨범에 표시할 이름'),
      '준자',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'snapfit@example.com'),
      'junja@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '8자 이상'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '한 번 더 입력'),
      'password123',
    );
    await tester.tap(find.byType(Checkbox).at(0), warnIfMissed: false);
    await tester.tap(find.byType(Checkbox).at(1), warnIfMissed: false);
    await tester.pump();
    tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '계정 만들기'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '60초 후 다시 보내기'),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 60));
    tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '인증 메일 다시 보내기'),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.confirmationResent, isTrue);
    expect(fake.resentEmail, 'junja@example.com');
  });

  testWidgets('password recovery mode updates password', (tester) async {
    final fake = FakeAuthViewModel();
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => fake),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const LoginScreen(startInPasswordReset: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('새 비밀번호 설정'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '8자 이상, 영문+숫자'),
      'newpass123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '한 번 더 입력'),
      'newpass123',
    );
    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, '비밀번호 변경하기'),
        )
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.passwordUpdated, isTrue);
    expect(find.text('비밀번호가 변경되었어요.'), findsOneWidget);
  });
}

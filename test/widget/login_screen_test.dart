import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
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
  bool emailSignUpCalled = false;
  String? signedUpEmail;

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

void main() {
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
    expect(find.text('추억을 한 권의 앨범으로'), findsOneWidget);
    expect(find.text('내 앨범으로 계속하기'), findsOneWidget);

    await pumpAt(const Size(844, 390));
    expect(find.text('추억을 한 권의 앨범으로'), findsOneWidget);
    expect(find.text('내 앨범으로 계속하기'), findsOneWidget);
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

    expect(find.text('Snapfit 계정 만들기'), findsOneWidget);
    expect(find.text('이름'), findsOneWidget);
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
    expect(find.text('확인 메일을 보냈어요'), findsOneWidget);
  });
}

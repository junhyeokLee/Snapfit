import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
// video_player가 사용하는 플랫폼 경계를 테스트에서만 교체한다.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';

import '../support/auth_video_platform_fake.dart';
import 'login_screen_test.dart' show FakeAuthViewModel, FakeTokenStorage;

const recoveryAccount = UserInfo(
  id: 'recovery-owner',
  name: '복구 검토 계정',
  provider: 'EMAIL',
);

class RecoveryFlowAuth extends FakeAuthViewModel {
  RecoveryFlowAuth({super.user});
  int updates = 0;
  final resetRecipients = <String>[];
  Completer<void>? pendingUpdate, pendingReset;
  Object? updateError;

  @override
  Future<void> updatePassword(String password) async {
    updates++;
    await pendingUpdate?.future;
    if (updateError != null) throw updateError!;
    passwordUpdated = true;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetRecipients.add(email);
    await pendingReset?.future;
    passwordResetRequested = true;
    passwordResetEmail = email;
  }

  void loadingSession() {
    // 실제 갱신처럼 이전 사용자를 보존해도 로그인 완료로 취급하면 안 된다.
    // ignore: invalid_use_of_internal_member
    state = const AsyncLoading<UserInfo?>().copyWithPrevious(state);
  }
}

/// 앱 테마·실제 입력 화면을 사용하고 인증 요청은 메모리에서만 확인한다.
class RecoveryFlowFixture {
  RecoveryFlowFixture({
    RecoveryFlowAuth? auth,
    this.videoState = AuthVideoState.failed,
  }) : auth = auth ?? RecoveryFlowAuth();

  final RecoveryFlowAuth auth;
  final AuthVideoState videoState;
  final navigator = GlobalKey<NavigatorState>();
  late AuthVideoPlatformFake video;
  late ProviderContainer container;

  Future<void> mount(
    WidgetTester tester, {
    bool password = true,
    bool pushed = false,
    bool dark = false,
    Size size = const Size(390, 844),
    double scale = 1,
    GlobalKey? capture,
  }) async {
    final previousVideo = video_platform.VideoPlayerPlatform.instance;
    video = AuthVideoPlatformFake(videoState);
    video_platform.VideoPlayerPlatform.instance = video;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    container = ProviderContainer(
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      ],
    );
    addTearDown(() async {
      // 컨트롤러의 타이머·구독 해제 후 원래 플랫폼을 복원한다.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();
      video_platform.VideoPlayerPlatform.instance = previousVideo;
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: capture == null
                  ? child!
                  : RepaintBoundary(key: capture, child: child!),
            ),
            home: pushed
                ? const Scaffold(body: Center(child: Text('복귀 기준 화면')))
                : LoginScreen(startInPasswordReset: password),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (pushed) {
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => LoginScreen(startInPasswordReset: password),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
  }
}

Finder recoveryKey(String id) => find.byKey(ValueKey(id));

Future<void> recoveryTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<VoidCallback> preparePasswordChange(WidgetTester tester) async {
  await tester.enterText(recoveryKey('auth-field-새 비밀번호'), 'newpass123');
  await tester.enterText(recoveryKey('auth-field-새 비밀번호 확인'), 'newpass123');
  final submit = recoveryKey('auth-password-submit');
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  return tester.widget<ElevatedButton>(submit).onPressed!;
}

void main() {
  for (final dark in [false, true]) {
    for (final videoState in AuthVideoState.values) {
      testWidgets(
        'recovery regression: reset form uses its theme with video=$videoState dark=$dark',
        (tester) async {
          final fixture = RecoveryFlowFixture(videoState: videoState);
          await fixture.mount(tester, dark: dark);
          final scaffold = tester.widget<Scaffold>(
            find.descendant(
              of: find.byType(LoginScreen),
              matching: find.byType(Scaffold),
            ),
          );
          final expected = (dark ? SnapFitTheme.dark() : SnapFitTheme.light())
              .scaffoldBackgroundColor;
          expect(scaffold.backgroundColor, expected);
          expect(
            recoveryKey('auth-field-새 비밀번호').hitTestable(),
            findsOneWidget,
          );
          if (videoState == AuthVideoState.initialized) {
            expect(fixture.video.played, isNotEmpty);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final signup in [false, true]) {
      testWidgets(
        'recovery regression: ${signup ? 'signup' : 'email'} form leaves video chrome in dark=$dark',
        (tester) async {
          final fixture = RecoveryFlowFixture(
            videoState: AuthVideoState.initialized,
          );
          await fixture.mount(tester, dark: dark, password: false);
          expect(fixture.video.played, isNotEmpty);
          await recoveryTap(
            tester,
            find.text(signup ? '이메일로 새 계정 만들기' : '이메일로 로그인'),
          );
          final scaffold = tester.widget<Scaffold>(
            find.descendant(
              of: find.byType(LoginScreen),
              matching: find.byType(Scaffold),
            ),
          );
          final expected = (dark ? SnapFitTheme.dark() : SnapFitTheme.light())
              .scaffoldBackgroundColor;
          expect(scaffold.backgroundColor, expected);
          expect(recoveryKey('auth-field-이메일').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'recovery regression: a loading video never hides ordinary login actions',
    (tester) async {
      final fixture = RecoveryFlowFixture(videoState: AuthVideoState.loading);
      await fixture.mount(tester, password: false);
      final email = find.text('이메일로 로그인');
      await tester.ensureVisible(email);
      await tester.pumpAndSettle();
      // 투명한 위젯도 hit test는 가능하므로 실제 표시 목표값을 함께 확인한다.
      final visibility = tester.widget<AnimatedOpacity>(
        find.ancestor(of: email, matching: find.byType(AnimatedOpacity)),
      );
      expect(visibility.opacity, 1);
      expect(email.hitTestable(), findsOneWidget);
      await recoveryTap(tester, email);
      expect(recoveryKey('auth-field-비밀번호').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: confirmed password completion clears credentials and returns its route once',
    (tester) async {
      final fixture = RecoveryFlowFixture(
        auth: RecoveryFlowAuth(user: recoveryAccount),
      );
      await fixture.mount(tester, pushed: true);
      final first = tester
          .widget<TextFormField>(recoveryKey('auth-field-새 비밀번호'))
          .controller!;
      final second = tester
          .widget<TextFormField>(recoveryKey('auth-field-새 비밀번호 확인'))
          .controller!;
      final staleSubmit = await preparePasswordChange(tester);
      staleSubmit();
      await tester.pumpAndSettle();
      expect(first.text, isEmpty);
      expect(second.text, isEmpty);
      expect(recoveryKey('auth-field-새 비밀번호'), findsNothing);
      expect(find.text('다시 변경하기'), findsNothing);
      expect(find.text('스냅핏으로 돌아가기'), findsOneWidget);
      staleSubmit();
      await tester.pumpAndSettle();
      expect(fixture.auth.updates, 1);
      await recoveryTap(tester, recoveryKey('auth-password-complete'));
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('복귀 기준 화면'), findsOneWidget);
      expect(fixture.auth.updates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: standalone completion offers login without inventing a session',
    (tester) async {
      final fixture = RecoveryFlowFixture();
      await fixture.mount(tester);
      final submit = await preparePasswordChange(tester);
      submit();
      await tester.pumpAndSettle();
      expect(recoveryKey('auth-field-새 비밀번호'), findsNothing);
      await recoveryTap(tester, recoveryKey('auth-password-complete'));
      expect(find.text('이메일로 계속하기'), findsOneWidget);
      expect(
        fixture.container.read(authViewModelProvider).asData?.value,
        isNull,
      );
      expect(fixture.auth.updates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: loading cached identity cannot close completion as a verified login',
    (tester) async {
      final fixture = RecoveryFlowFixture(
        auth: RecoveryFlowAuth(user: recoveryAccount),
      );
      await fixture.mount(tester, pushed: true);
      final submit = await preparePasswordChange(tester);
      submit();
      await tester.pumpAndSettle();
      fixture.auth.loadingSession();
      await tester.pumpAndSettle();
      expect(find.text('스냅핏으로 돌아가기'), findsNothing);
      await recoveryTap(tester, recoveryKey('auth-password-complete'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('이메일로 계속하기'), findsOneWidget);
      expect(fixture.auth.updates, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: failed password update keeps both inputs and permits retry',
    (tester) async {
      final fixture = RecoveryFlowFixture();
      fixture.auth.updateError = StateError('fixture update failed');
      await fixture.mount(tester);
      final submit = await preparePasswordChange(tester);
      submit();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(recoveryKey('auth-field-새 비밀번호'))
            .controller!
            .text,
        'newpass123',
      );
      expect(recoveryKey('auth-password-complete'), findsNothing);
      fixture.auth.updateError = null;
      await recoveryTap(tester, recoveryKey('auth-password-submit'));
      expect(fixture.auth.updates, 2);
      expect(recoveryKey('auth-password-complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery regression: editing a reset recipient clears stale delivery copy without bypassing cooldown',
    (tester) async {
      final fixture = RecoveryFlowFixture();
      await fixture.mount(tester, password: false);
      await recoveryTap(tester, find.text('이메일로 로그인'));
      await recoveryTap(tester, find.text('비밀번호를 잊으셨나요?'));
      await tester.enterText(
        recoveryKey('auth-field-이메일'),
        'first@example.test',
      );
      await recoveryTap(tester, recoveryKey('auth-reset-submit'));
      expect(fixture.auth.resetRecipients, ['first@example.test']);
      await tester.enterText(
        recoveryKey('auth-field-이메일'),
        'second@example.test',
      );
      await tester.pumpAndSettle();
      expect(find.text('입력한 이메일로 재설정 링크를 보냈어요. 메일함을 확인해주세요.'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(recoveryKey('auth-reset-submit'))
            .onPressed,
        isNull,
      );
      expect(fixture.auth.resetRecipients, ['first@example.test']);
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      await recoveryTap(tester, recoveryKey('auth-reset-submit'));
      expect(fixture.auth.resetRecipients, [
        'first@example.test',
        'second@example.test',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

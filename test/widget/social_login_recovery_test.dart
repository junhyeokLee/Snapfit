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
    show FakeAuthViewModel, FakeTokenStorage, socialButton;

class _SocialAuth extends FakeAuthViewModel {
  final attempts = <Completer<void>>[];

  @override
  Future<void> loginWithKakao() async {
    final attempt = Completer<void>();
    attempts.add(attempt);
    await attempt.future;
  }

  @override
  Future<void> syncConsentIfPresent() async {}
}

Future<void> _pump(
  WidgetTester tester,
  _SocialAuth auth,
  ValueNotifier<String?> notice,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() => auth),
        authServiceProvider.overrideWith(
          (_) => throw StateError(
            'Real authentication is forbidden in this test.',
          ),
        ),
        supabaseClientProvider.overrideWith(
          (_) => throw StateError('Backend access is forbidden in this test.'),
        ),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: ValueListenableBuilder<String?>(
            valueListenable: notice,
            builder: (_, message, __) => LoginScreen(authNotice: message),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('executes the expected VM or actual browser platform', () {
    expect(kIsWeb, const bool.fromEnvironment('SNAPFIT_EXPECT_WEB'));
  });

  testWidgets(
    'completed social launch without a session releases the login buttons',
    (tester) async {
      final auth = _SocialAuth();
      final notice = ValueNotifier<String?>(null);
      addTearDown(notice.dispose);
      await _pump(tester, auth, notice);
      await tester.tap(socialButton('카카오로 계속하기'));
      await tester.pump();
      expect(find.text('로그인 중…'), findsOneWidget);

      auth.attempts.single.complete();
      await tester.pumpAndSettle();
      expect(find.text('로그인 중…'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(socialButton('카카오로 계속하기')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<ElevatedButton>(socialButton('Google로 계속하기')).onPressed,
        isNotNull,
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets('failed social login releases busy state and can be retried', (
    tester,
  ) async {
    final auth = _SocialAuth();
    final notice = ValueNotifier<String?>(null);
    addTearDown(notice.dispose);
    await _pump(tester, auth, notice);
    await tester.tap(socialButton('카카오로 계속하기'));
    await tester.pump();
    auth.attempts.single.completeError(
      const AuthException('fixture-private-detail'),
    );
    await tester.pumpAndSettle();
    expect(find.text('로그인 중…'), findsNothing);
    expect(find.textContaining('카카오 로그인을 완료하지 못했어요'), findsOneWidget);
    expect(find.textContaining('fixture-private-detail'), findsNothing);
    await tester.tap(socialButton('카카오로 계속하기'));
    await tester.pump();
    expect(auth.attempts, hasLength(2));
    auth.attempts.last.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'callback failure releases an old attempt and late completion cannot change the retry',
    (tester) async {
      final auth = _SocialAuth();
      final notice = ValueNotifier<String?>(null);
      addTearDown(notice.dispose);
      await _pump(tester, auth, notice);
      await tester.tap(socialButton('카카오로 계속하기'));
      await tester.pump();

      notice.value = '로그인 확인을 완료하지 못했어요. 다시 로그인해주세요.';
      await tester.pumpAndSettle();
      expect(find.text('로그인 중…'), findsNothing);
      expect(find.text(notice.value!), findsOneWidget);
      await tester.tap(socialButton('카카오로 계속하기'));
      await tester.pump();
      expect(auth.attempts, hasLength(2));
      expect(find.text(notice.value!), findsNothing);

      auth.attempts.first.completeError(
        const AuthException('stale-private-detail'),
      );
      await tester.pump();
      expect(find.text('로그인 중…'), findsOneWidget);
      expect(find.textContaining('카카오 로그인을 완료하지 못했어요'), findsNothing);
      auth.attempts.last.complete();
      await tester.pumpAndSettle();
      expect(find.text('로그인 중…'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(socialButton('카카오로 계속하기')).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

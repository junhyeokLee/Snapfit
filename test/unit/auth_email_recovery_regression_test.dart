import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email signup confirmation uses Snapfit auth callback redirect', () {
    final source = File(
      'lib/features/auth/domain/auth_service.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<AuthResponse?> signUpWithEmail');
    final end = source.indexOf('Future<void> requestPasswordReset', start);
    final methodSource = source.substring(start, end);

    expect(methodSource, contains('emailRedirectTo: Env.authRedirectUrl'));
  });

  test('auth callback syncs saved consent after email confirmation', () {
    final source = File(
      'lib/features/auth/presentation/viewmodels/auth_view_model.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<String?> handleAuthCallback');
    final end = source.indexOf('Future<void> updatePassword', start);
    final methodSource = source.substring(start, end);

    expect(methodSource, contains('await syncConsentIfPresent();'));
  });

  test(
    'social logins require a verified provider email before saving auth',
    () {
      final source = File(
        'lib/features/auth/domain/auth_service.dart',
      ).readAsStringSync();

      final kakaoStart = source.indexOf(
        'Future<AuthResponse> loginWithKakaoToken',
      );
      final kakaoEnd = source.indexOf(
        'Future<AuthResponse> loginWithGoogleIdToken',
        kakaoStart,
      );
      final kakaoSource = source.substring(kakaoStart, kakaoEnd);
      expect(kakaoSource, contains('_requireVerifiedProviderEmail'));
      expect(kakaoSource, contains("provider: '카카오'"));

      final googleStart = source.indexOf(
        'Future<AuthResponse> loginWithGoogleIdToken',
      );
      final googleEnd = source.indexOf(
        'Future<AuthResponse> loginWithEmail',
        googleStart,
      );
      final googleSource = source.substring(googleStart, googleEnd);
      expect(googleSource, contains('_requireVerifiedProviderEmail'));
      expect(googleSource, contains("provider: '구글'"));

      final gateStart = source.indexOf(
        'Future<void> _requireVerifiedProviderEmail',
      );
      final gateEnd = source.indexOf(
        'Future<void> _upsertSupabaseProfile',
        gateStart,
      );
      final gateSource = source.substring(gateStart, gateEnd);
      expect(gateSource, contains("claims['email_verified']"));
      expect(gateSource, contains("claims['verified_email']"));
      expect(gateSource, contains('await supabase?.auth.signOut()'));
      expect(gateSource, contains('인증된 이메일이 필요합니다'));
    },
  );

  test('email auth does not persist before Supabase email confirmation', () {
    final source = File(
      'lib/features/auth/domain/auth_service.dart',
    ).readAsStringSync();

    expect(source, contains('bool _hasConfirmedEmail(User user)'));
    expect(source, contains('user.emailConfirmedAt?.trim().isNotEmpty'));
    expect(source, contains('Future<void> _requireConfirmedEmailSession'));
    expect(source, contains('이메일 인증을 완료한 뒤 다시 로그인해주세요.'));

    final signupStart = source.indexOf('Future<AuthResponse?> signUpWithEmail');
    final signupEnd = source.indexOf(
      'Future<void> requestPasswordReset',
      signupStart,
    );
    final signupSource = source.substring(signupStart, signupEnd);
    expect(
      signupSource,
      contains('await _requireConfirmedEmailSession(session);'),
    );

    final callbackStart = source.indexOf('Future<String?> handleAuthCallback');
    final callbackEnd = source.indexOf(
      'Future<AuthResponse> updatePassword',
      callbackStart,
    );
    final callbackSource = source.substring(callbackStart, callbackEnd);
    expect(
      callbackSource,
      contains('await _requireConfirmedEmailSession(response.session);'),
    );
  });
}

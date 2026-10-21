import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:snap_fit/features/auth/domain/native_kakao_login.dart';
import 'package:snap_fit/features/auth/domain/web_oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

void main() {
  final token = OAuthToken('fixture', DateTime(2030), null, null, null);

  test('Talk startup failure falls back to account login once', () async {
    var attempts = 0;
    final result = await loginWithNativeKakao(
      talkInstalled: () async => true,
      talkLogin: () async => throw PlatformException(code: 'NOT_SUPPORTED'),
      accountLogin: () async {
        attempts++;
        return token;
      },
    );
    expect(result, same(token));
    expect(attempts, 1);
  });

  test('cancellation never opens another login screen', () async {
    for (final error in [
      PlatformException(code: 'CANCELED'),
      KakaoClientException(ClientErrorCause.cancelled, 'fixture'),
      KakaoAuthException(AuthErrorCause.accessDenied, 'fixture'),
    ]) {
      var attempts = 0;
      await expectLater(
        loginWithNativeKakao(
          talkInstalled: () async => true,
          talkLogin: () async => throw error,
          accountLogin: () async {
            attempts++;
            return token;
          },
        ),
        throwsA(same(error)),
      );
      expect(attempts, 0);
      expect(socialAuthErrorMessage(error), contains('취소'));
    }
  });

  test('no Talk app uses account login and successful Talk skips it', () async {
    for (final installed in [false, true]) {
      var accountAttempts = 0, talkAttempts = 0;
      expect(
        await loginWithNativeKakao(
          talkInstalled: () async => installed,
          talkLogin: () async {
            talkAttempts++;
            return token;
          },
          accountLogin: () async {
            accountAttempts++;
            return token;
          },
        ),
        same(token),
      );
      expect(talkAttempts, installed ? 1 : 0);
      expect(accountAttempts, installed ? 0 : 1);
    }
  });

  test('account-login failure is returned without repeated fallback', () async {
    final failure = PlatformException(code: 'CONFIGURATION_ERROR');
    var attempts = 0;
    await expectLater(
      loginWithNativeKakao(
        talkInstalled: () async => true,
        talkLogin: () async => throw PlatformException(code: 'NOT_SUPPORTED'),
        accountLogin: () async {
          attempts++;
          throw failure;
        },
      ),
      throwsA(same(failure)),
    );
    expect(attempts, 1);
  });

  group('existing customer email consent', () {
    final idToken = OAuthToken(
      'fixture',
      DateTime(2030),
      null,
      null,
      null,
      idToken: 'fixture-id-token',
    );

    test(
      'missing email consent requests email and a replacement ID token',
      () async {
        final requests = <List<String>>[];
        final result = await ensureNativeKakaoEmailConsent(
          idToken,
          emailNeedsAgreement: () async => true,
          requestScopes: (scopes) async {
            requests.add(scopes);
            return token;
          },
        );
        expect(requests, [
          ['openid', 'account_email'],
        ]);
        expect(result, same(token));
      },
    );

    test(
      'confirmed email consent never forces another consent screen',
      () async {
        var requests = 0;
        final result = await ensureNativeKakaoEmailConsent(
          idToken,
          emailNeedsAgreement: () async => false,
          requestScopes: (_) async {
            requests++;
            return token;
          },
        );
        expect(result, same(idToken));
        expect(requests, 0);
      },
    );

    test(
      'missing ID token requests openid without repeating agreed email',
      () async {
        final requests = <List<String>>[];
        await ensureNativeKakaoEmailConsent(
          token,
          emailNeedsAgreement: () async => false,
          requestScopes: (scopes) async {
            requests.add(scopes);
            return idToken;
          },
        );
        expect(requests, [
          ['openid'],
        ]);
      },
    );

    test(
      'an ID token with granted email scope needs no consent lookup',
      () async {
        final granted = OAuthToken('fixture', DateTime(2030), null, null, [
          'account_email',
        ], idToken: 'fixture-id-token');
        var lookups = 0, requests = 0;
        final result = await ensureNativeKakaoEmailConsent(
          granted,
          emailNeedsAgreement: () async {
            lookups++;
            return true;
          },
          requestScopes: (_) async {
            requests++;
            return token;
          },
        );
        expect(result, same(granted));
        expect(lookups, 0);
        expect(requests, 0);
      },
    );

    test(
      'cancelled email consent is returned without retrying or signing in',
      () async {
        final cancelled = KakaoClientException(
          ClientErrorCause.cancelled,
          'fixture',
        );
        var requests = 0;
        await expectLater(
          ensureNativeKakaoEmailConsent(
            idToken,
            emailNeedsAgreement: () async => true,
            requestScopes: (_) async {
              requests++;
              throw cancelled;
            },
          ),
          throwsA(same(cancelled)),
        );
        expect(requests, 1);
      },
    );
  });

  test(
    'unverified email and missing OIDC remain explicit, bounded failures',
    () {
      expect(
        socialAuthErrorMessage(
          const AuthException(
            'private-token',
            code: 'provider_email_needs_verification',
          ),
        ),
        contains('인증된 이메일'),
      );
      expect(
        socialAuthErrorMessage(
          const AuthException('private-token', code: 'kakao_oidc_unavailable'),
        ),
        contains('카카오 로그인 연결 설정'),
      );
      expect(
        socialAuthErrorMessage(
          const AuthException('private-token', code: 'kakao_oidc_unavailable'),
        ),
        isNot(contains('private-token')),
      );
    },
  );

  test(
    'SDK configuration and consent errors expose no provider response details',
    () {
      for (final reason in [
        AuthErrorCause.invalidClient,
        AuthErrorCause.misconfigured,
        AuthErrorCause.unauthorized,
      ]) {
        final message = socialAuthErrorMessage(
          KakaoAuthException(reason, 'fixture-private-key'),
        );
        expect(message, contains('연결 설정'));
        expect(message, isNot(contains('fixture-private-key')));
      }
      expect(
        socialAuthErrorMessage(
          KakaoAuthException(
            AuthErrorCause.invalidScope,
            'fixture-private-key',
          ),
        ),
        contains('이메일 동의 설정'),
      );
      expect(
        socialAuthErrorMessage(
          const AuthException(
            'Unacceptable audience in id_token: fixture-private-key',
          ),
        ),
        contains('연결 설정'),
      );
      expect(
        socialAuthErrorMessage(
          const AuthException('Bad ID token fixture-private-key'),
        ),
        isNot(contains('fixture-private-key')),
      );
    },
  );
}

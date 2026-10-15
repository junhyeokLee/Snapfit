import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:snap_fit/features/auth/domain/web_oauth.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';

class _Tokens extends TokenStorage {
  dto.AuthResponse? saved;
  dto.UserInfo? profile;
  int saves = 0, clears = 0;
  @override
  Future<void> saveAuth(dto.AuthResponse auth) async {
    saved = auth;
    profile = auth.user;
    saves++;
  }

  @override
  Future<void> saveUserInfo(dto.UserInfo user) async => profile = user;
  @override
  Future<dto.UserInfo?> getUserInfo() async => profile;
  @override
  Future<String?> getUserId() async => profile?.id;
  @override
  Future<String?> getResolvedUserId() async => profile?.id;
  @override
  Future<void> clear() async {
    clears++;
    saved = null;
    profile = null;
  }

  @override
  Future<ConsentSnapshot?> getConsent() async => null;
}

Map<String, dynamic> _user({String owner = _owner, bool confirmed = true}) => {
  'id': owner,
  'email': 'test@example.com',
  'email_confirmed_at': confirmed ? '2026-10-15T00:00:00Z' : null,
  'aud': 'authenticated',
  'created_at': '2026-10-01T00:00:00Z',
  'app_metadata': {'provider': 'google'},
  'user_metadata': {'name': 'Provider Name', 'email_verified': true},
};

Future<void> _session(SupabaseClient client, {String owner = _owner}) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))}.fixture';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': _user(owner: owner),
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('browser OAuth redirect boundary', () {
    test(
      'current app origin replaces path/query/fragment with an exact callback',
      () {
        for (final origin in [
          'http://127.0.0.1:7357',
          'http://localhost:7357',
          'https://app.example.com',
        ]) {
          expect(
            webAuthRedirectUri(
              Uri.parse('$origin/album?next=https://other.example/#private'),
            ).toString(),
            '$origin/?auth_callback=1',
          );
        }
      },
    );
    test(
      'cross-origin, userinfo, wildcard and insecure non-local redirects fail closed',
      () {
        final current = Uri.parse('https://app.example.com/');
        for (final redirect in [
          'https://other.example/?auth_callback=1',
          'https://user@app.example.com/?auth_callback=1',
          'https://app.example.com/?auth_callback=1&next=other',
          'https://app.example.com/**',
          'https://app.example.com/?auth_callback=1#code=secret',
          '/',
        ]) {
          expect(
            () => webAuthRedirectUri(current, configured: redirect),
            throwsA(isA<WebOAuthException>()),
          );
        }
        expect(
          () => webAuthRedirectUri(Uri.parse('http://app.example.com/')),
          throwsA(isA<WebOAuthException>()),
        );
        expect(
          () => webAuthRedirectUri(Uri.parse('file:///tmp/app')),
          throwsA(isA<WebOAuthException>()),
        );
      },
    );
    test(
      'SDK detects only the trusted callback; invites and payment codes cannot exchange sessions',
      () {
        final current = Uri.parse('http://127.0.0.1:7357/');
        bool accepts(String url) =>
            isTrustedAuthCallback(Uri.parse(url), current: current);
        expect(
          accepts('http://127.0.0.1:7357/?auth_callback=1&code=fixture'),
          isTrue,
        );
        expect(
          accepts('http://127.0.0.1:7357/?auth_callback=1#error=access_denied'),
          isTrue,
        );
        for (final url in [
          'http://127.0.0.1:7357/?code=invite',
          'http://127.0.0.1:7357/payment-return?code=payment',
          'http://localhost:7357/?auth_callback=1&code=fixture',
          'https://other.example/?auth_callback=1&code=fixture',
          'http://127.0.0.1:7357/?auth_callback=1',
          'snapfit://auth/callback?code=fixture',
        ]) {
          expect(accepts(url), isFalse);
        }
      },
    );
    test('native email callback keeps its exact existing scheme/host/path', () {
      final current = Uri.parse('file:///native');
      expect(
        isTrustedAuthCallback(
          Uri.parse('snapfit://auth/callback?code=fixture'),
          current: current,
        ),
        isTrue,
      );
      expect(
        isTrustedAuthCallback(
          Uri.parse('snapfit://auth/other?code=fixture'),
          current: current,
        ),
        isFalse,
      );
      expect(
        isTrustedAuthCallback(
          Uri.parse('other://auth/callback?code=fixture'),
          current: current,
        ),
        isFalse,
      );
    });
    test(
      'configuration errors give useful bounded text without echoing response details',
      () {
        expect(
          socialAuthErrorMessage(
            const WebOAuthException('web_auth_provider_disabled'),
            provider: 'Google',
          ),
          contains('아직 연결되지'),
        );
        expect(
          socialAuthErrorMessage(
            const WebOAuthException('web_auth_redirect_invalid'),
          ),
          contains('주소'),
        );
        expect(
          socialAuthErrorMessage(
            const AuthException('private-token', code: 'access_denied'),
          ),
          contains('취소'),
        );
        expect(
          socialAuthErrorMessage(const AuthException('private-token')),
          isNot(contains('private-token')),
        );
      },
    );
  });

  group('web login launch and verified Supabase session synchronization', () {
    late SupabaseClient client;
    late _Tokens tokens;
    late List<http.Request> requests;
    late Map<String, dynamic> verifiedUser;
    late int userStatus;
    late List<Map<String, dynamic>> existingProfiles;
    Completer<void>? userGate;
    setUp(() {
      tokens = _Tokens();
      requests = [];
      verifiedUser = _user();
      userStatus = 200;
      existingProfiles = [];
      userGate = null;
      client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/user') {
            if (userGate != null) await userGate!.future;
            return http.Response(
              jsonEncode(
                userStatus == 200 ? verifiedUser : {'msg': 'Invalid session'},
              ),
              userStatus,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode(request.method == 'GET' ? existingProfiles : []),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
    });
    tearDown(() async => client.dispose());
    test(
      'launches Supabase Google/Kakao only and does not fake user/token success',
      () async {
        final launches = <String>[];
        final service = AuthService(
          tokenStorage: tokens,
          supabase: client,
          browserUri: () => Uri.parse('http://127.0.0.1:7357/'),
          webProviderEnabled: (_) async => true,
          webOAuthLauncher: (provider, redirect) async {
            launches.add('${provider.name}|$redirect');
            return true;
          },
        );
        await service.loginWithWebProvider(OAuthProvider.google);
        await service.loginWithWebProvider(OAuthProvider.kakao);
        expect(launches, [
          'google|http://127.0.0.1:7357/?auth_callback=1',
          'kakao|http://127.0.0.1:7357/?auth_callback=1',
        ]);
        expect(tokens.saves, 0);
        expect(client.auth.currentSession, isNull);
        expect(requests, isEmpty);
      },
    );
    test('disabled provider never launches a browser or saves auth', () async {
      var launched = false;
      final service = AuthService(
        tokenStorage: tokens,
        supabase: client,
        browserUri: () => Uri.parse('http://localhost:7357/'),
        webProviderEnabled: (_) async => false,
        webOAuthLauncher: (_, __) async {
          launched = true;
          return true;
        },
      );
      await expectLater(
        service.loginWithWebProvider(OAuthProvider.google),
        throwsA(isA<WebOAuthException>()),
      );
      expect(launched, isFalse);
      expect(tokens.saves, 0);
    });
    test('browser launch failure cannot become a signed-in state', () async {
      final service = AuthService(
        tokenStorage: tokens,
        supabase: client,
        browserUri: () => Uri.parse('http://localhost:7357/'),
        webProviderEnabled: (_) async => true,
        webOAuthLauncher: (_, __) async => false,
      );
      await expectLater(
        service.loginWithWebProvider(OAuthProvider.google),
        throwsA(isA<WebOAuthException>()),
      );
      expect(tokens.saves, 0);
    });
    test(
      'only a server-verified, confirmed session writes the correct user and profile',
      () async {
        await _session(client);
        existingProfiles = [
          {
            'name': 'Edited SnapFit Name',
            'avatar_url': 'https://fixture.invalid/custom-avatar.png',
          },
        ];
        final result = await AuthService(
          tokenStorage: tokens,
          supabase: client,
        ).synchronizeSupabaseSession();
        expect(result!.user.id, _owner);
        expect(result.user.provider, 'GOOGLE');
        expect(result.user.name, 'Edited SnapFit Name');
        expect(
          result.user.profileImageUrl,
          'https://fixture.invalid/custom-avatar.png',
        );
        expect(tokens.saves, 1);
        expect(tokens.saved!.user.id, _owner);
        expect(requests.first.url.path, '/auth/v1/user');
        final profileWrite = requests.singleWhere(
          (r) => r.method == 'POST' && r.url.path == '/rest/v1/profiles',
        );
        expect((jsonDecode(profileWrite.body) as Map)['id'], _owner);
      },
    );
    test(
      'stale cached user without a Supabase session is cleared, never restored as login',
      () async {
        tokens.profile = const dto.UserInfo(
          id: _owner,
          name: 'Old',
          provider: 'GOOGLE',
        );
        expect(
          await AuthService(
            tokenStorage: tokens,
            supabase: client,
          ).synchronizeSupabaseSession(),
          isNull,
        );
        expect(tokens.profile, isNull);
        expect(tokens.clears, 1);
        expect(requests, isEmpty);
      },
    );
    test(
      'unconfirmed email cannot bypass the gate using edited user metadata',
      () async {
        await _session(client);
        verifiedUser = _user(confirmed: false);
        await expectLater(
          AuthService(
            tokenStorage: tokens,
            supabase: client,
          ).synchronizeSupabaseSession(),
          throwsA(isA<AuthException>()),
        );
        expect(tokens.saves, 0);
        expect(
          requests.where((r) => r.url.path == '/rest/v1/profiles'),
          isEmpty,
        );
        expect(client.auth.currentSession, isNull);
      },
    );
    test('getUser rejection cannot save a cached session', () async {
      await _session(client);
      userStatus = 401;
      await expectLater(
        AuthService(
          tokenStorage: tokens,
          supabase: client,
        ).synchronizeSupabaseSession(),
        throwsA(isA<AuthException>()),
      );
      expect(tokens.saves, 0);
    });
    test(
      'an account change during server verification cannot write the previous profile/tokens',
      () async {
        await _session(client);
        userGate = Completer<void>();
        final pending = AuthService(
          tokenStorage: tokens,
          supabase: client,
        ).synchronizeSupabaseSession();
        await Future<void>.delayed(Duration.zero);
        await _session(client, owner: _other);
        userGate!.complete();
        await expectLater(pending, throwsA(isA<WebOAuthException>()));
        expect(tokens.saves, 0);
        expect(
          requests.where((r) => r.url.path == '/rest/v1/profiles'),
          isEmpty,
        );
      },
    );
  });

  test(
    'profile bytes refuse empty/unsupported input before uploading a file',
    () async {
      final tokens = _Tokens()
        ..profile = const dto.UserInfo(
          id: _owner,
          name: 'Test',
          provider: 'EMAIL',
        );
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('[]', 200, request: request);
        }),
      );
      await _session(client);
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          supabaseClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await client.dispose();
      });
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);
      await expectLater(
        vm.updateProfileImageBytes(base64Decode('')),
        throwsException,
      );
      await expectLater(
        vm.updateProfileImageBytes(base64Decode('bm90IGFuIGltYWdl')),
        throwsException,
      );
      expect(requests, isEmpty);
    },
  );
}

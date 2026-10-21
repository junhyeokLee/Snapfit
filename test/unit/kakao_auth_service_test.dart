import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:snap_fit/features/auth/domain/web_oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _KakaoTokens extends TokenStorage {
  int saves = 0;
  String? owner;
  @override
  Future<void> saveAuth(dto.AuthResponse auth) async {
    owner = auth.user.id;
    saves++;
  }

  @override
  Future<String?> getUserId() async => owner;

  @override
  Future<void> clear() async => owner = null;
}

String _jwt(Map<String, Object?> claims) =>
    '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.fixture';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late _KakaoTokens tokens;
  late List<http.Request> requests;
  Object? verified;
  String? canonicalEmail;
  bool emailConfirmed = true;
  var profileStatus = 200;

  setUp(() {
    tokens = _KakaoTokens();
    requests = [];
    verified = true;
    canonicalEmail = 'fixture@example.com';
    emailConfirmed = true;
    profileStatus = 200;
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final headers = {'content-type': 'application/json'};
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': _jwt({
                'sub': 'fixture-owner',
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
              }),
              'refresh_token': 'fixture-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'fixture-owner',
                'email': canonicalEmail,
                'email_confirmed_at': verified == false || !emailConfirmed
                    ? null
                    : '2026-10-15T00:00:00Z',
                'aud': 'authenticated',
                'created_at': '2026-10-01T00:00:00Z',
                'app_metadata': {'provider': 'kakao'},
                'user_metadata': {
                  'name': 'Fixture',
                  if (verified != null) 'email_verified': verified,
                },
              },
            }),
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path == '/auth/v1/logout')
          return http.Response('', 204, request: request);
        return http.Response(
          profileStatus == 200
              ? '[]'
              : '{"code":"42501","message":"fixture-private-detail"}',
          profileStatus,
          headers: headers,
          request: request,
        );
      }),
    );
  });
  tearDown(() async => client.dispose());

  AuthService service() => AuthService(tokenStorage: tokens, supabase: client);
  String idToken() =>
      _jwt({'sub': 'fixture-kakao-sub', 'email': 'fixture@example.com'});

  test(
    'provider metadata cannot replace a missing canonical confirmed email',
    () async {
      for (final missingEmail in [true, false]) {
        canonicalEmail = missingEmail ? null : 'fixture@example.com';
        emailConfirmed = missingEmail;
        await expectLater(
          service().loginWithKakaoToken('fixture-access', idToken: idToken()),
          throwsA(
            isA<AuthException>().having(
              (error) => error.code,
              'code',
              'email_not_confirmed',
            ),
          ),
        );
        expect(client.auth.currentSession, isNull);
        expect(tokens.saves, 0);
      }
      expect(requests.where((r) => r.url.path == '/rest/v1/profiles'), isEmpty);
    },
  );

  test(
    'Kakao exchanges the matching SDK access and ID tokens for server validation',
    () async {
      final identity = idToken();
      final result = await service().loginWithKakaoToken(
        'fixture-access',
        idToken: identity,
      );
      final request = requests.singleWhere(
        (r) => r.url.path == '/auth/v1/token',
      );
      final body = jsonDecode(request.body) as Map;
      expect(body['provider'], 'kakao');
      expect(body['access_token'], 'fixture-access');
      expect(body['id_token'], identity);
      expect(result.user.provider, 'KAKAO');
      expect(tokens.saves, 1);
    },
  );

  test('empty access token cannot reach Supabase or save an account', () async {
    await expectLater(
      service().loginWithKakaoToken(' ', idToken: idToken()),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
    expect(tokens.saves, 0);
  });

  test(
    'false or absent email verification cannot save a Kakao account',
    () async {
      for (final value in [false, null, 'false', 0]) {
        verified = value;
        await expectLater(
          service().loginWithKakaoToken('fixture-access', idToken: idToken()),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              'provider_email_needs_verification',
            ),
          ),
        );
        expect(tokens.saves, 0);
      }
      expect(requests.where((r) => r.url.path == '/rest/v1/profiles'), isEmpty);
    },
  );

  test(
    'server boolean and supported verified-email representations are accepted',
    () async {
      for (final value in [true, 'true', 1]) {
        verified = value;
        await service().loginWithKakaoToken(
          'fixture-access',
          idToken: idToken(),
        );
      }
      expect(tokens.saves, 3);
    },
  );

  test(
    'profile failure stays a failure with a bounded account-information message',
    () async {
      profileStatus = 403;
      try {
        await service().loginWithKakaoToken(
          'fixture-access',
          idToken: idToken(),
        );
        fail('A profile error must not save a successful login.');
      } catch (error) {
        expect(error, isA<PostgrestException>());
        final message = socialAuthErrorMessage(error);
        expect(message, contains('계정 정보'));
        expect(message, isNot(contains('fixture-private-detail')));
      }
      expect(tokens.saves, 0);
    },
  );
}

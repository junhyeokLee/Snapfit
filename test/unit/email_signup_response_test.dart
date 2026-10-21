import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _email = 'album@example.com';
const _userId = '11111111-1111-4111-8111-111111111111';

class _Tokens extends TokenStorage {
  int saves = 0;
  @override
  Future<void> saveAuth(dto.AuthResponse auth) async => saves++;
}

class _PkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
}

Map<String, dynamic> _identity(String provider) => {
  'id': _userId,
  'identity_id': 'identity-$provider',
  'user_id': _userId,
  'provider': provider,
};

Map<String, dynamic> _user({List<String> providers = const ['email']}) => {
  'id': _userId,
  'aud': 'authenticated',
  'email': _email,
  'created_at': '2026-10-15T00:00:00Z',
  'confirmation_sent_at': '2026-10-15T00:00:00Z',
  'app_metadata': {'provider': 'email', 'providers': providers},
  'user_metadata': {'name': 'Album'},
  'identities': providers.map(_identity).toList(),
};

void main() {
  late SupabaseClient client;
  late AuthService service;
  late _Tokens tokens;
  late Map<String, dynamic> response;
  late int responseStatus;
  late List<http.Request> requests;

  setUp(() {
    response = _user();
    responseStatus = 200;
    requests = [];
    tokens = _Tokens();
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-public-key',
      authOptions: AuthClientOptions(pkceAsyncStorage: _PkceStorage()),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/v1/signup');
        return http.Response(
          jsonEncode(response),
          responseStatus,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
          request: request,
        );
      }),
    );
    service = AuthService(tokenStorage: tokens, supabase: client);
  });
  tearDown(() async {
    expect(tokens.saves, 0);
    expect(client.auth.currentSession, isNull);
    expect(requests, hasLength(1));
    await client.dispose();
  });

  Future<dto.AuthResponse?> signUp() => service.signUpWithEmail(
    name: 'Album',
    email: ' $_email ',
    password: 'album1234',
  );

  Matcher authError(String code) =>
      throwsA(isA<AuthException>().having((error) => error.code, 'code', code));

  test(
    'real unconfirmed email identity waits for confirmation without auth writes',
    () async {
      expect(await signUp(), isNull);
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['email'], _email);
    },
  );

  test(
    'obfuscated duplicate is rejected despite its fresh ID and sent timestamp',
    () async {
      // Current Auth sanitizes both confirmed password and OAuth accounts this
      // way. The original provider is deliberately not disclosed to the caller.
      response = _user()..['identities'] = <Map<String, dynamic>>[];
      await expectLater(signUp(), authError('user_already_exists'));
    },
  );

  test(
    'confirmed email account without session does not claim a fresh email',
    () async {
      response['email_confirmed_at'] = '2026-10-14T00:00:00Z';
      await expectLater(signUp(), authError('user_already_exists'));
    },
  );

  test(
    'Google-only identity cannot masquerade as a pending email signup',
    () async {
      response = _user(providers: ['google']);
      await expectLater(signUp(), authError('user_already_exists'));
    },
  );

  test('explicit server duplicate errors are preserved', () async {
    responseStatus = 422;
    response = {
      'code': 'user_already_exists',
      'msg': 'User already registered',
    };
    await expectLater(signUp(), authError('user_already_exists'));
  });

  for (final malformed in [
    'missing user',
    'missing identities',
    'different email',
  ]) {
    test('$malformed cannot show email confirmation as success', () async {
      switch (malformed) {
        case 'missing user':
          response = {};
        case 'missing identities':
          response.remove('identities');
        case 'different email':
          response['email'] = 'other@example.com';
      }
      await expectLater(signUp(), authError('signup_response_invalid'));
    });
  }
}

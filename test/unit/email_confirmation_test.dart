import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _email = 'album@example.com';
const _id = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';

class _Tokens extends TokenStorage {
  dto.AuthResponse? saved;
  @override
  Future<void> saveAuth(dto.AuthResponse auth) async => saved = auth;
  @override
  Future<String?> getUserId() async => saved?.user.id;
  @override
  Future<void> clear() async => saved = null;
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

Map<String, dynamic> _user({
  String id = _id,
  String email = _email,
  bool confirmed = true,
}) => {
  'id': id,
  'email': email,
  if (confirmed) 'email_confirmed_at': '2026-10-16T00:00:00Z',
  'aud': 'authenticated',
  'created_at': '2026-10-16T00:00:00Z',
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  // A metadata claim is deliberately also present in the unconfirmed fixture.
  'user_metadata': {'name': 'Album', 'email_verified': true},
  'identities': [
    {
      'id': id,
      'identity_id': 'identity-$id',
      'user_id': id,
      'provider': 'email',
    },
  ],
};

Map<String, dynamic> _session(Map<String, dynamic> user) {
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': user['id'], 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture';
  return {
    'access_token': jwt,
    'refresh_token': 'fixture-refresh',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': user,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AuthService service;
  late _Tokens tokens;
  late List<http.Request> requests;
  late Map<String, dynamic> verificationUser;
  late Map<String, dynamic> serverUser;
  var verificationStatus = 200;
  var serverStatus = 200;
  String? verificationCode;
  Completer<void>? serverGate;
  late Completer<void> serverStarted;

  setUp(() {
    requests = [];
    tokens = _Tokens();
    verificationUser = _user();
    serverUser = _user();
    verificationStatus = 200;
    serverStatus = 200;
    verificationCode = null;
    serverGate = null;
    serverStarted = Completer<void>();
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-public-key',
      authOptions: AuthClientOptions(pkceAsyncStorage: _PkceStorage()),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body = {};
        var status = 200;
        switch (request.url.path) {
          case '/auth/v1/signup':
            body = _user(confirmed: false);
          case '/auth/v1/verify':
            status = verificationStatus;
            body = status == 200
                ? _session(verificationUser)
                : {'msg': 'private-detail', 'code': verificationCode};
          case '/auth/v1/user':
            if (!serverStarted.isCompleted) serverStarted.complete();
            await serverGate?.future;
            status = serverStatus;
            body = status == 200 ? serverUser : {'msg': 'temporary failure'};
          case '/auth/v1/token':
            status = 400;
            body = {
              'msg': 'Email not confirmed',
              'code': 'email_not_confirmed',
            };
          case '/auth/v1/logout':
            return http.Response('', 204, request: request);
          case '/rest/v1/profiles':
            body = [];
          case '/auth/v1/resend':
            body = {};
          default:
            throw StateError('Unexpected fixture request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          status,
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
    if (serverGate?.isCompleted == false) serverGate!.complete();
    await client.dispose();
  });

  Future<void> signUp() async {
    expect(
      await service.signUpWithEmail(
        name: 'Album',
        email: _email,
        password: 'fixture1234',
      ),
      isNull,
    );
  }

  Future<dto.AuthResponse> verify({
    String email = _email,
    String code = '12345678',
  }) => service.verifyEmailConfirmation(email: email, token: code);

  Iterable<http.Request> path(String value) =>
      requests.where((request) => request.url.path == value);

  Matcher errorCode(String code) =>
      throwsA(isA<AuthException>().having((error) => error.code, 'code', code));

  test(
    'signup OTP validates canonical server user before profile and cache',
    () async {
      await signUp();
      final auth = await verify(
        email: ' ALBUM@example.com ',
        code: ' 12345678 ',
      );
      expect(auth.user.id, _id);
      expect(auth.user.email, _email);
      expect(auth.user.provider, 'EMAIL');
      expect(tokens.saved?.user.id, _id);
      final body = jsonDecode(path('/auth/v1/verify').single.body);
      expect(body['email'], _email);
      expect(body['token'], '12345678');
      expect(body['type'], 'signup');
      expect(path('/auth/v1/user'), hasLength(1));
      expect(path('/rest/v1/profiles'), hasLength(1));
      expect(
        requests.indexOf(path('/auth/v1/user').single),
        lessThan(requests.indexOf(path('/rest/v1/profiles').single)),
      );
    },
  );

  test(
    'existing unconfirmed signup can verify after reopening without memory',
    () async {
      final auth = await verify();
      expect(auth.user.id, _id);
      expect(tokens.saved?.user.id, _id);
    },
  );

  for (final code in [
    '',
    '123456',
    '123456789',
    '1234 5678',
    '１２３４５６７８',
    'abcdefgh',
  ]) {
    test(
      'malformed confirmation code is refused without network: $code',
      () async {
        await expectLater(
          verify(code: code),
          errorCode('email_confirmation_code_invalid'),
        );
        expect(requests, isEmpty);
        expect(tokens.saved, isNull);
      },
    );
  }

  test(
    'current signup email cannot be switched by the confirmation form',
    () async {
      await signUp();
      await expectLater(
        verify(email: 'other@example.com'),
        errorCode('email_confirmation_email_changed'),
      );
      expect(path('/auth/v1/verify'), isEmpty);
      expect(tokens.saved, isNull);
    },
  );

  test(
    'existing login email_not_confirmed can replace an older signup context',
    () async {
      await signUp();
      await expectLater(
        service.loginWithEmail(
          email: 'other@example.com',
          password: 'fixture1234',
        ),
        errorCode('email_not_confirmed'),
      );
      verificationUser = _user(id: _other, email: 'other@example.com');
      serverUser = verificationUser;
      expect((await verify(email: 'other@example.com')).user.id, _other);
    },
  );

  test(
    'recovery or expired OTP remains a signup-only server rejection',
    () async {
      verificationStatus = 403;
      verificationCode = 'otp_expired';
      await expectLater(verify(), errorCode('otp_expired'));
      final body = jsonDecode(path('/auth/v1/verify').single.body);
      expect(body['type'], 'signup');
      expect(path('/auth/v1/user'), isEmpty);
      expect(path('/rest/v1/profiles'), isEmpty);
      expect(tokens.saved, isNull);
      expect(client.auth.currentSession, isNull);
    },
  );

  test(
    'HTTP 429 retains the provider rate-limit code without saving auth',
    () async {
      verificationStatus = 429;
      verificationCode = 'over_request_rate_limit';
      await expectLater(verify(), errorCode('over_request_rate_limit'));
      expect(tokens.saved, isNull);
      expect(path('/rest/v1/profiles'), isEmpty);
    },
  );

  for (final mismatch in [
    'signup owner',
    'response email',
    'unconfirmed canonical email',
    'server owner',
    'server email',
  ]) {
    test('$mismatch cannot complete confirmation or write a profile', () async {
      await signUp();
      switch (mismatch) {
        case 'signup owner':
          verificationUser = _user(id: _other);
        case 'response email':
          verificationUser = _user(email: 'other@example.com');
        case 'unconfirmed canonical email':
          verificationUser = _user(confirmed: false);
        case 'server owner':
          serverUser = _user(id: _other);
        case 'server email':
          serverUser = _user(email: 'other@example.com');
      }
      await expectLater(
        verify(),
        errorCode('email_confirmation_response_invalid'),
      );
      expect(tokens.saved, isNull);
      expect(path('/rest/v1/profiles'), isEmpty);
      expect(client.auth.currentSession, isNull);
    });
  }

  test(
    'a different signed-in account cannot be overwritten by an OTP',
    () async {
      await client.auth.setInitialSession(
        jsonEncode(_session(_user(id: _other, email: 'other@example.com'))),
      );
      await expectLater(
        verify(),
        errorCode('email_confirmation_session_changed'),
      );
      expect(path('/auth/v1/verify'), isEmpty);
      expect(client.auth.currentUser?.id, _other);
    },
  );

  test(
    'temporary getUser outage keeps the server-issued session for recovery',
    () async {
      serverStatus = 503;
      await expectLater(verify(), throwsA(isA<AuthRetryableFetchException>()));
      expect(client.auth.currentUser?.id, _id);
      expect(tokens.saved, isNull);
      expect(path('/auth/v1/logout'), isEmpty);
      expect(path('/rest/v1/profiles'), isEmpty);
    },
  );

  testWidgets('session synchronization times out without clearing valid auth', (
    tester,
  ) async {
    await client.auth.setInitialSession(jsonEncode(_session(_user())));
    serverGate = Completer<void>();
    final result = service.synchronizeSupabaseSession();
    final assertion = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await assertion;
    expect(client.auth.currentUser?.id, _id);
    expect(path('/auth/v1/logout'), isEmpty);
    expect(tokens.saved, isNull);
  });

  test(
    'a late verification cannot overwrite a newer signed-in owner',
    () async {
      serverGate = Completer<void>();
      final pending = verify();
      final assertion = expectLater(pending, throwsA(anything));
      await serverStarted.future;
      await client.auth.setInitialSession(
        jsonEncode(_session(_user(id: _other, email: 'other@example.com'))),
      );
      serverGate!.complete();
      await assertion;
      expect(client.auth.currentUser?.id, _other);
      expect(tokens.saved, isNull);
      expect(path('/rest/v1/profiles'), isEmpty);
    },
  );
}

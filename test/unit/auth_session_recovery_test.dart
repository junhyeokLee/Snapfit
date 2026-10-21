import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _old = '11111111-1111-4111-8111-111111111111';
const _new = '22222222-2222-4222-8222-222222222222';
var _sessionRevision = 0;

class _Tokens extends TokenStorage {
  String? owner;
  int saves = 0, clears = 0;
  Completer<void>? clearGate;
  final clearStarted = Completer<void>();

  @override
  Future<String?> getUserId() async => owner;

  @override
  Future<void> saveAuth(dto.AuthResponse auth) async {
    owner = auth.user.id;
    saves++;
  }

  @override
  Future<void> clear() async {
    if (!clearStarted.isCompleted) clearStarted.complete();
    await clearGate?.future;
    owner = null;
    clears++;
  }
}

Map<String, dynamic> _user(String owner) => {
  'id': owner,
  'email': 'fixture@example.com',
  'email_confirmed_at': '2026-10-15T00:00:00Z',
  'aud': 'authenticated',
  'created_at': '2026-10-01T00:00:00Z',
  'app_metadata': {'provider': 'kakao'},
  'user_metadata': {'name': 'Fixture', 'email_verified': true},
};

Map<String, dynamic> _sessionData(String owner) {
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'fixture_revision': ++_sessionRevision})))}.fixture';
  return {
    'access_token': jwt,
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': _user(owner),
  };
}

Future<void> _session(SupabaseClient client, String owner) async {
  await client.auth.setInitialSession(jsonEncode(_sessionData(owner)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late _Tokens tokens;
  late List<http.Request> requests;
  var status = 200;
  String? errorCode;
  Completer<void>? verificationGate;
  Completer<void>? logoutGate;
  late Completer<void> verificationStarted;

  setUp(() {
    tokens = _Tokens()..owner = _old;
    requests = [];
    status = 200;
    errorCode = null;
    verificationGate = null;
    logoutGate = null;
    verificationStarted = Completer<void>();
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/user') {
          if (!verificationStarted.isCompleted) verificationStarted.complete();
          await verificationGate?.future;
          final body = status == 200
              ? _user(client.auth.currentSession!.user.id)
              : {
                  'msg': 'fixture-private-detail',
                  if (errorCode != null) 'code': errorCode,
                };
          return http.Response(
            jsonEncode(body),
            status,
            headers: {
              'content-type': 'application/json',
              'x-supabase-api-version': '2024-01-01',
            },
            request: request,
          );
        }
        if (request.url.path == '/auth/v1/logout') {
          await logoutGate?.future;
          return http.Response('', 204, request: request);
        }
        if (request.url.path == '/auth/v1/token' &&
            request.url.queryParameters['grant_type'] == 'refresh_token') {
          return http.Response(
            jsonEncode(_sessionData(_old)),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  tearDown(() async {
    if (logoutGate?.isCompleted == false) logoutGate!.complete();
    await client.dispose();
  });

  AuthService service() => AuthService(tokenStorage: tokens, supabase: client);

  for (final rejection in [
    (401, 'session_expired'),
    (403, 'session_not_found'),
    (404, 'user_not_found'),
  ]) {
    test(
      'rejected ${rejection.$2} session clears without waiting for logout',
      () async {
        await _session(client, _old);
        status = rejection.$1;
        errorCode = rejection.$2;
        logoutGate = Completer<void>();
        await expectLater(
          service().synchronizeSupabaseSession(),
          throwsA(isA<AuthException>()),
        );
        expect(client.auth.currentSession, isNull);
        expect(tokens.owner, isNull);
        expect(tokens.clears, 1);
        expect(tokens.saves, 0);
        expect(
          requests.where((request) => request.url.path == '/rest/v1/profiles'),
          isEmpty,
        );
      },
    );
  }

  test(
    'temporary Auth outage preserves current SDK and stored account',
    () async {
      await _session(client, _old);
      status = 503;
      await expectLater(
        service().synchronizeSupabaseSession(),
        throwsA(isA<AuthRetryableFetchException>()),
      );
      expect(client.auth.currentSession?.user.id, _old);
      expect(tokens.owner, _old);
      expect(tokens.clears, 0);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/logout'),
        isEmpty,
      );
    },
  );

  test(
    'an expired access token alone does not delete a refreshable session',
    () async {
      await _session(client, _old);
      final previousToken = client.auth.currentSession!.accessToken;
      final auth = service();
      status = 401;
      errorCode = 'bad_jwt';
      await expectLater(
        auth.synchronizeSupabaseSession(),
        throwsA(isA<AuthException>()),
      );
      expect(client.auth.currentSession?.user.id, _old);
      expect(tokens.owner, _old);
      expect(tokens.clears, 0);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/logout'),
        isEmpty,
      );
      await client.auth.refreshSession();
      expect(client.auth.currentSession!.accessToken, isNot(previousToken));
      status = 200;
      errorCode = null;
      expect((await auth.synchronizeSupabaseSession())?.user.id, _old);
      expect(tokens.owner, _old);
      expect(tokens.saves, 1);
      expect(tokens.clears, 0);
    },
  );

  test('a delayed rejected account cannot sign out a newer account', () async {
    await _session(client, _old);
    status = 404;
    errorCode = 'user_not_found';
    verificationGate = Completer<void>();
    final pending = service().synchronizeSupabaseSession();
    final rejected = expectLater(pending, throwsA(isA<AuthException>()));
    await verificationStarted.future;
    await _session(client, _new);
    tokens.owner = _new;
    verificationGate!.complete();
    await rejected;
    expect(client.auth.currentSession?.user.id, _new);
    expect(tokens.owner, _new);
    expect(tokens.clears, 0);
    expect(
      requests.where((request) => request.url.path == '/auth/v1/logout'),
      isEmpty,
    );
  });

  test(
    'a delayed logout preserves a newer session for the same account',
    () async {
      await _session(client, _old);
      final gate = Completer<void>();
      final auth = AuthService(
        tokenStorage: tokens,
        supabase: client,
        prepareLogout: () => gate.future,
      );
      final previousToken = client.auth.currentSession!.accessToken;
      final loggingOut = auth.logout();
      await _session(client, _old);
      final newToken = client.auth.currentSession!.accessToken;
      expect(newToken, isNot(previousToken));
      gate.complete();
      await loggingOut;
      expect(client.auth.currentSession?.accessToken, newToken);
      expect(tokens.owner, _old);
      expect(tokens.clears, 0);
      expect(
        requests.where((request) => request.url.path == '/auth/v1/logout'),
        isEmpty,
      );
    },
  );

  test(
    'a clear already in progress finishes before the newer login is saved',
    () async {
      final auth = service();
      tokens.clearGate = Completer<void>();
      final signedOut = auth.synchronizeSupabaseSession();
      await tokens.clearStarted.future;
      await _session(client, _new);
      final signedIn = auth.synchronizeSupabaseSession();
      await verificationStarted.future;
      tokens.clearGate!.complete();
      expect(await signedOut, isNull);
      expect((await signedIn)?.user.id, _new);
      expect(tokens.owner, _new);
      expect(tokens.clears, 1);
      expect(tokens.saves, 1);
    },
  );
}

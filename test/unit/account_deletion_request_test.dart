import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/domain/account_deletion_request.dart';
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends TokenStorage {
  int clears = 0;
  @override
  Future<void> clear() async {
    clears++;
  }
}

Map<String, dynamic> _accepted({bool existing = false}) => {
  'requestAccepted': true,
  'accountDeleted': false,
  'alreadyRequested': existing,
  'reference': 'DEL-12',
};

Future<void> _session(SupabaseClient client) => client.auth.setInitialSession(
  jsonEncode({
    'access_token':
        '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': '11111111-1111-4111-8111-111111111111', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.fixture',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'email': 'fixture@example.invalid',
      'created_at': '2026-10-01T00:00:00Z',
    },
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'acceptance is distinct from deletion and rejects old or malformed success responses',
    () {
      expect(AccountDeletionRequest.fromJson(_accepted()).reference, 'DEL-12');
      expect(
        AccountDeletionRequest.fromJson(
          _accepted(existing: true),
        ).alreadyRequested,
        isTrue,
      );
      for (final value in [
        {'success': true},
        {..._accepted(), 'accountDeleted': true},
        {..._accepted(), 'requestAccepted': false},
        {..._accepted(), 'reference': 'DEL-0'},
        {..._accepted(), 'alreadyRequested': 'true'},
      ]) {
        expect(
          () => AccountDeletionRequest.fromJson(value),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'a real client preserves its session and tokens after review acceptance',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(_accepted()),
            202,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await _session(client);
      final before = client.auth.currentSession;
      final tokens = _Tokens();
      var logoutPreparation = 0;
      final service = AuthService(
        tokenStorage: tokens,
        supabase: client,
        prepareLogout: () async {
          logoutPreparation++;
        },
      );
      final result = await service.requestAccountDeletion();
      expect(result.reference, 'DEL-12');
      expect(client.auth.currentSession, same(before));
      expect(tokens.clears, 0);
      expect(logoutPreparation, 0);
      expect(requests.length, 1);
      expect(requests.single.url.path, '/functions/v1/account-delete');
      expect(jsonDecode(requests.single.body), {'action': 'REQUEST_REVIEW'});
      await expectLater(service.deleteAccount(), throwsException);
      expect(requests.length, 1);
    },
  );

  test(
    'server failure never clears the account and offers the actual contact address',
    () async {
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":"private-detail"}',
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await _session(client);
      final before = client.auth.currentSession;
      final tokens = _Tokens();
      final service = AuthService(tokenStorage: tokens, supabase: client);
      await expectLater(
        service.requestAccountDeletion(),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('junhyeoklee616@gmail.com') &&
                !error.toString().contains('private-detail'),
          ),
        ),
      );
      expect(client.auth.currentSession, same(before));
      expect(tokens.clears, 0);
    },
  );
}

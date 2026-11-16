import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/supabase/auth_request_http_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _base = 'https://fixture.supabase.co';
final _tokenUri = Uri.parse('$_base/auth/v1/token?grant_type=refresh_token');

class _Client extends http.BaseClient {
  _Client(this.handle);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handle(request);
  @override
  void close() => closed = true;
}

http.StreamedResponse _response(String body, {http.BaseRequest? request}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

String _jwt({required int expiresAt, required String marker}) {
  String part(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': '11111111-1111-4111-8111-111111111111', 'aud': 'authenticated', 'exp': expiresAt, 'marker': marker})}.fixture-signature';
}

Map<String, dynamic> _session(String token, String refresh) => {
  'access_token': token,
  'refresh_token': refresh,
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': '11111111-1111-4111-8111-111111111111',
    'aud': 'authenticated',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-11-01T00:00:00Z',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'auth JSON preserves exact body, headers, redirects and response metadata',
    () async {
      late http.BaseRequest sent;
      final inner = _Client((request) async {
        sent = request;
        expect(
          await request.finalize().toBytes(),
          utf8.encode('{"refresh_token":"한글-token"}'),
        );
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"ok":true}')),
          201,
          contentLength: 11,
          request: request,
          headers: {
            'content-type': 'application/json',
            'x-auth-test': 'preserved',
          },
          isRedirect: true,
          persistentConnection: false,
          reasonPhrase: 'Created',
        );
      });
      final client = AuthRequestHttpClient(supabaseUrl: _base, inner: inner);
      final request = http.Request('POST', _tokenUri)
        ..headers.addAll({
          'authorization': 'Bearer fixture',
          'apikey': 'public-fixture',
          'content-type': 'application/json; charset=utf-8',
        })
        ..bodyBytes = utf8.encode('{"refresh_token":"한글-token"}')
        ..followRedirects = false
        ..maxRedirects = 2
        ..persistentConnection = false;
      final response = await client.send(request);
      expect(sent, isA<http.AbortableRequest>());
      expect(sent.url, request.url);
      expect(sent.method, 'POST');
      expect(sent.headers, request.headers);
      expect(sent.followRedirects, isFalse);
      expect(sent.maxRedirects, 2);
      expect(sent.persistentConnection, isFalse);
      expect(request.finalized, isTrue);
      expect(await response.stream.bytesToString(), '{"ok":true}');
      expect(response.statusCode, 201);
      expect(response.contentLength, 11);
      expect(response.headers['x-auth-test'], 'preserved');
      expect(response.isRedirect, isTrue);
      expect(response.persistentConnection, isFalse);
      expect(response.reasonPhrase, 'Created');
      client.close();
      expect(inner.closed, isTrue);
    },
  );

  for (final lateError in [false, true]) {
    test(
      'a header deadline aborts only Auth and discards its late ${lateError ? 'failure' : 'response'}',
      () {
        fakeAsync((clock) {
          final pending = Completer<http.StreamedResponse>();
          var aborted = false, lateBodyCancelled = false;
          final inner = _Client((request) {
            unawaited(
              (request as http.Abortable).abortTrigger!.then((_) {
                aborted = true;
              }),
            );
            return pending.future;
          });
          final client = AuthRequestHttpClient(
            supabaseUrl: _base,
            inner: inner,
          );
          Object? error;
          var successes = 0;
          unawaited(
            client
                .send(http.Request('POST', _tokenUri))
                .then<void>(
                  (_) {
                    successes++;
                  },
                  onError: (Object failure) {
                    error = failure;
                  },
                ),
          );
          clock.flushMicrotasks();
          clock.elapse(const Duration(seconds: 20));
          clock.flushMicrotasks();
          expect(error, isA<http.ClientException>());
          expect(aborted, isTrue);
          expect(
            inner.closed,
            isFalse,
            reason: 'Other Supabase requests must remain alive.',
          );
          if (lateError) {
            pending.completeError(http.ClientException('late network failure'));
          } else {
            final stream = StreamController<List<int>>(
              onCancel: () {
                lateBodyCancelled = true;
              },
            );
            pending.complete(http.StreamedResponse(stream.stream, 200));
            clock.flushMicrotasks();
            expect(lateBodyCancelled, isTrue);
            unawaited(stream.close());
          }
          clock.flushMicrotasks();
          expect(successes, 0);
          expect(clock.nonPeriodicTimerCount, 0);
          client.close();
        });
      },
    );
  }

  test(
    'headers and body share one total deadline while unrelated reads continue',
    () {
      fakeAsync((clock) {
        final headers = Completer<http.StreamedResponse>();
        final read = Completer<http.StreamedResponse>();
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () {
            cancelled = true;
          },
        );
        final inner = _Client(
          (request) => request.url.path.startsWith('/auth/')
              ? headers.future
              : read.future,
        );
        final client = AuthRequestHttpClient(supabaseUrl: _base, inner: inner);
        Object? error;
        var authReturned = false, ordinaryReadReturned = false;
        unawaited(
          client
              .send(http.Request('GET', Uri.parse('$_base/auth/v1/user')))
              .then<void>(
                (_) {
                  authReturned = true;
                },
                onError: (Object failure) {
                  error = failure;
                },
              ),
        );
        unawaited(
          client
              .send(http.Request('GET', Uri.parse('$_base/rest/v1/albums')))
              .then<void>((_) {
                ordinaryReadReturned = true;
              }),
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 12));
        headers.complete(http.StreamedResponse(body.stream, 200));
        clock.flushMicrotasks();
        body.add(utf8.encode('{"partial":'));
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 7));
        expect(error, isNull);
        expect(
          authReturned,
          isFalse,
          reason: 'SDK must not receive headers before the full JSON body.',
        );
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        expect(error, isA<http.ClientException>());
        expect(cancelled, isTrue);
        expect(inner.closed, isFalse);
        read.complete(_response('[]'));
        clock.flushMicrotasks();
        expect(ordinaryReadReturned, isTrue);
        expect(authReturned, isFalse);
        unawaited(body.close());
        client.close();
        clock.flushMicrotasks();
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    'REST, storage uploads, functions, external origins and streamed requests pass through unchanged',
    () async {
      final seen = <http.BaseRequest>[];
      final responses = <http.StreamedResponse>[];
      final inner = _Client((request) async {
        seen.add(request);
        final response = _response('{}');
        responses.add(response);
        return response;
      });
      final client = AuthRequestHttpClient(supabaseUrl: _base, inner: inner);
      final requests = <http.BaseRequest>[
        http.Request('GET', Uri.parse('$_base/rest/v1/albums')),
        http.Request(
          'POST',
          Uri.parse('$_base/storage/v1/object/photos/picture.png'),
        ),
        http.Request('POST', Uri.parse('$_base/functions/v1/print-package')),
        http.Request('POST', Uri.parse('https://other.example/auth/v1/token')),
        http.Request('POST', Uri.parse('$_base/auth/v10/token')),
        http.Request('GET', Uri.parse('/auth/v1/user')),
        http.MultipartRequest('POST', Uri.parse('$_base/auth/v1/avatar')),
        http.StreamedRequest('POST', _tokenUri),
      ];
      for (final request in requests) {
        expect(await client.send(request), same(responses.last));
        expect(seen.last, same(request));
        expect(request.finalized, isFalse);
      }
      client.close();
    },
  );

  test(
    'an existing caller abort signal remains connected to the auth request',
    () async {
      final abort = Completer<void>();
      final inner = _Client((request) async {
        await (request as http.Abortable).abortTrigger;
        throw http.RequestAbortedException(request.url);
      });
      final client = AuthRequestHttpClient(supabaseUrl: _base, inner: inner);
      final request = http.AbortableRequest(
        'POST',
        _tokenUri,
        abortTrigger: abort.future,
      );
      final pending = client.send(request);
      final failure = expectLater(
        pending,
        throwsA(isA<http.RequestAbortedException>()),
      );
      abort.complete();
      await failure;
      client.close();
    },
  );

  test(
    'the real Supabase SDK recovers a shared expired-session refresh and ignores an obsolete late token',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expired = _jwt(expiresAt: now - 3600, marker: 'expired');
      final fresh = _jwt(expiresAt: now + 3600, marker: 'fresh');
      final stale = _jwt(expiresAt: now + 3600, marker: 'obsolete-late-token');
      final oldResponse = Completer<http.Response>();
      http.Request? firstRefresh;
      var refreshes = 0;
      final privateReadHeaders = <String?>[];
      final inner = MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          refreshes++;
          if (refreshes == 1) {
            firstRefresh = request;
            return oldResponse.future;
          }
          return http.Response(
            jsonEncode(_session(fresh, 'fresh-refresh-token')),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.startsWith('/rest/v1/')) {
          privateReadHeaders.add(request.headers['authorization']);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected fixture request: ${request.url.path}');
      });
      final transport = AuthRequestHttpClient(
        supabaseUrl: _base,
        inner: inner,
        timeout: const Duration(milliseconds: 50),
      );
      final client = SupabaseClient(
        _base,
        'public-fixture-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final events = <AuthChangeEvent>[];
      final errors = <Object>[];
      final subscription = client.auth.onAuthStateChange.listen(
        (state) => events.add(state.event),
        onError: (Object error) => errors.add(error),
      );
      addTearDown(() async {
        await subscription.cancel();
        await client.dispose();
        transport.close();
      });
      await client.auth.setInitialSession(
        jsonEncode(_session(expired, 'initial-refresh-token')),
      );
      final session = client.auth.getSession();
      Future<dynamic> albums() async => client.from('albums').select();
      final privateRead = albums();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        refreshes,
        1,
        reason: 'Concurrent private reads must share one pending refresh.',
      );
      expect(privateReadHeaders, isEmpty);
      final values = await Future.wait<Object?>([
        session,
        privateRead,
      ]).timeout(const Duration(seconds: 4));
      expect((values.first as Session).accessToken, fresh);
      expect(values.last, isEmpty);
      expect(
        refreshes,
        2,
        reason:
            'The timed-out HTTP request must allow the SDK retry to send a new one.',
      );
      expect(privateReadHeaders, ['Bearer $fresh']);
      await client.from('profiles').select();
      expect(refreshes, 2);
      expect(privateReadHeaders.last, 'Bearer $fresh');
      oldResponse.complete(
        http.Response(
          jsonEncode(_session(stale, 'obsolete-refresh-token')),
          200,
          request: firstRefresh,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(client.auth.currentSession!.accessToken, fresh);
      expect(client.auth.currentSession!.refreshToken, 'fresh-refresh-token');
      await client.auth.refreshSession('initial-refresh-token');
      expect(
        refreshes,
        3,
        reason:
            'The completed shared refresh must not remain in the SDK pending map.',
      );
      expect(events, isNot(contains(AuthChangeEvent.signedOut)));
      expect(errors, isEmpty);
    },
  );
}

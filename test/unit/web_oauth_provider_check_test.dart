import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:snap_fit/features/auth/domain/web_oauth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

class _Tokens extends TokenStorage {
  int saves = 0;
  @override
  Future<void> saveAuth(dto.AuthResponse auth) async => saves++;
}

class _SettingsAdapter implements HttpClientAdapter {
  _SettingsAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(Object? body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Matcher _code(String code) => throwsA(
  isA<WebOAuthException>().having((error) => error.code, 'code', code),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late _Tokens tokens;
  late List<({OAuthProvider provider, String redirect, String? scopes})>
  launches;
  final dios = <Dio>[];
  var launchSucceeds = true;

  Dio transport(_SettingsAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    dios.add(dio);
    return dio;
  }

  AuthService service(
    Dio dio, {
    Uri? browserUri,
    Duration deadline = const Duration(seconds: 3),
  }) => AuthService(
    tokenStorage: tokens,
    supabase: client,
    browserUri: () => browserUri ?? Uri.parse('https://snapfit.example/login'),
    webProviderEnabled: (provider) =>
        isWebOAuthProviderEnabled(provider, client: dio),
    webProviderCheckTimeout: deadline,
    webOAuthLauncher: (provider, redirect, scopes) async {
      launches.add((provider: provider, redirect: redirect, scopes: scopes));
      return launchSucceeds;
    },
  );

  setUp(() {
    client = SupabaseClient(
      'https://fixture.supabase.test',
      'fixture-public-key',
      httpClient: MockClient((_) async {
        throw StateError('availability checks cannot authenticate a user');
      }),
    );
    tokens = _Tokens();
    launches = [];
    launchSucceeds = true;
  });
  tearDown(() async {
    for (final dio in dios) {
      dio.close(force: true);
    }
    dios.clear();
    expect(tokens.saves, 0);
    expect(client.auth.currentSession, isNull);
    await client.dispose();
  });

  test(
    'explicitly enabled providers launch once with the safe callback',
    () async {
      final adapter = _SettingsAdapter(
        (_) async => _response({
          'external': {'google': true, 'kakao': true},
        }),
      );
      final auth = service(transport(adapter));
      await auth.loginWithWebProvider(OAuthProvider.google);
      await auth.loginWithWebProvider(OAuthProvider.kakao);
      expect(adapter.requests, 2);
      expect(launches, [
        (
          provider: OAuthProvider.google,
          redirect: 'https://snapfit.example/?auth_callback=1',
          scopes: null,
        ),
        (
          provider: OAuthProvider.kakao,
          redirect: 'https://snapfit.example/?auth_callback=1',
          scopes: 'account_email',
        ),
      ]);
    },
  );

  test('explicitly disabled Google never launches', () async {
    final adapter = _SettingsAdapter(
      (_) async => _response({
        'external': {'google': false},
      }),
    );
    await expectLater(
      service(transport(adapter)).loginWithWebProvider(OAuthProvider.google),
      _code('web_auth_provider_disabled'),
    );
    expect(adapter.requests, 1);
    expect(launches, isEmpty);
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    test(
      'transport $type is unknown and starts one server OAuth flow',
      () async {
        final adapter = _SettingsAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: type,
            error: StateError('fixture-private-transport-detail'),
          );
        });
        final dio = transport(adapter);
        await expectLater(
          isWebOAuthProviderEnabled(OAuthProvider.google, client: dio),
          _code('web_auth_provider_status_unknown'),
        );
        await service(dio).loginWithWebProvider(OAuthProvider.google);
        expect(launches, hasLength(1));
        expect(launches.single.provider, OAuthProvider.google);
      },
    );
  }

  for (final status in [401, 403, 500]) {
    test('HTTP $status is a closed configuration failure', () async {
      final adapter = _SettingsAdapter(
        (_) async => _response({
          'message': 'fixture-private-response-detail',
        }, status: status),
      );
      await expectLater(
        service(transport(adapter)).loginWithWebProvider(OAuthProvider.google),
        _code('web_auth_configuration_unavailable'),
      );
      expect(launches, isEmpty);
    });
  }

  for (final body in <Object?>[
    null,
    [],
    {'external': 'google'},
    {'external': <String, Object>{}},
    {
      'external': {'google': 'true'},
    },
    {
      'external': {'google': 1},
    },
  ]) {
    test('malformed configuration $body never launches', () async {
      final adapter = _SettingsAdapter((_) async => _response(body));
      await expectLater(
        service(transport(adapter)).loginWithWebProvider(OAuthProvider.google),
        _code('web_auth_configuration_unavailable'),
      );
      expect(launches, isEmpty);
    });
  }

  for (final type in [
    DioExceptionType.cancel,
    DioExceptionType.badCertificate,
    DioExceptionType.unknown,
  ]) {
    test(
      'non-transport $type remains a closed configuration failure',
      () async {
        final adapter = _SettingsAdapter((options) async {
          throw DioException(requestOptions: options, type: type);
        });
        await expectLater(
          service(
            transport(adapter),
          ).loginWithWebProvider(OAuthProvider.google),
          _code('web_auth_configuration_unavailable'),
        );
        expect(launches, isEmpty);
      },
    );
  }

  test(
    'origin and supported-provider checks run before any settings request',
    () async {
      final adapter = _SettingsAdapter(
        (_) async => _response({
          'external': {'google': true},
        }),
      );
      final dio = transport(adapter);
      await expectLater(
        service(
          dio,
          browserUri: Uri.parse('http://untrusted.example/login'),
        ).loginWithWebProvider(OAuthProvider.google),
        _code('web_auth_origin_invalid'),
      );
      await expectLater(
        service(dio).loginWithWebProvider(OAuthProvider.github),
        _code('web_auth_provider_unsupported'),
      );
      expect(adapter.requests, 0);
      expect(launches, isEmpty);
    },
  );

  for (final lateEnabled in [false, true]) {
    test(
      'a check deadline launches once and ignores late $lateEnabled',
      () async {
        final late = Completer<ResponseBody>();
        final adapter = _SettingsAdapter((_) => late.future);
        await service(
          transport(adapter),
          deadline: const Duration(milliseconds: 20),
        ).loginWithWebProvider(OAuthProvider.google);
        expect(adapter.requests, 1);
        expect(launches, hasLength(1));
        late.complete(
          _response({
            'external': {'google': lateEnabled},
          }),
        );
        await Future<void>.delayed(Duration.zero);
        expect(launches, hasLength(1));
        expect(launches.single.provider, OAuthProvider.google);
      },
    );
  }

  test(
    'unknown availability cannot turn a blocked browser launch into login',
    () async {
      final adapter = _SettingsAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      launchSucceeds = false;
      await expectLater(
        service(transport(adapter)).loginWithWebProvider(OAuthProvider.google),
        _code('web_auth_launch_failed'),
      );
      expect(launches, hasLength(1));
    },
  );
}

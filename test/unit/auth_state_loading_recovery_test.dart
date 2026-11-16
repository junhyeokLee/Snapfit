import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart' as dto;
import 'package:snap_fit/features/auth/domain/auth_service.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

class _Tokens extends TokenStorage {
  late Future<dto.UserInfo?> Function() read;
  int clears = 0;
  @override
  Future<dto.UserInfo?> getUserInfo() => read();
  @override
  Future<void> clear() async => clears++;
}

class _Service extends AuthService {
  _Service(_Tokens tokens, SupabaseClient client)
    : super(tokenStorage: tokens, supabase: client);
  late Future<dto.AuthResponse?> Function() load;
  var reads = 0;
  final consent = Completer<void>();
  @override
  Future<dto.AuthResponse?> synchronizeSupabaseSession() {
    reads++;
    return load();
  }

  @override
  Future<void> syncConsentIfPresent() => consent.future;
  @override
  Future<void> logout() => supabase!.auth.signOut(scope: SignOutScope.local);
}

dto.UserInfo _info(String owner, [String name = 'Current']) => dto.UserInfo(
  id: owner,
  name: name,
  email: 'fixture@example.test',
  provider: 'EMAIL',
);

dto.AuthResponse _auth(dto.UserInfo info) => dto.AuthResponse(
  accessToken: 'fixture',
  refreshToken: 'fixture-refresh',
  expiresIn: 3600,
  user: info,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late _Tokens tokens;
  late _Service service;
  ProviderContainer? container;
  var revision = 0;

  Future<void> session(String owner) => client.auth
      .setInitialSession(
        jsonEncode({
          'access_token':
              '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
              '${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'revision': ++revision})))}.fixture',
          'refresh_token': 'fixture-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'email': 'fixture@example.test',
            'created_at': '2026-10-01T00:00:00Z',
            'email_confirmed_at': '2026-10-01T00:00:00Z',
            'app_metadata': {'provider': 'email'},
            'user_metadata': {},
          },
        }),
      )
      .then((_) {});

  ProviderContainer mount({Duration timeout = const Duration(seconds: 2)}) {
    final result = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        tokenStorageProvider.overrideWithValue(tokens),
        authServiceProvider.overrideWithValue(service),
        authStateLoadTimeoutProvider.overrideWithValue(timeout),
      ],
    );
    result.listen(authViewModelProvider, (_, _) {});
    return container = result;
  }

  setUp(() async {
    client = SupabaseClient(
      'https://fixture.supabase.test',
      'fixture-public-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{}',
          request.url.path.endsWith('/logout') ? 204 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    await session(_a);
    tokens = _Tokens()
      ..read = () async {
        final owner = client.auth.currentUser?.id;
        return owner == null ? null : _info(owner);
      };
    service = _Service(tokens, client)
      ..load = () async {
        final owner = client.auth.currentUser?.id;
        return owner == null ? null : _auth(_info(owner));
      };
  });

  tearDown(() async {
    if (!service.consent.isCompleted) service.consent.complete();
    container?.dispose();
    container = null;
    await client.dispose();
  });

  test(
    'a stalled initial account read ends in a retryable error and ignores late data',
    () async {
      final stalled = Completer<dto.UserInfo?>();
      tokens.read = () => stalled.future;
      service.load = () =>
          stalled.future.then((user) => user == null ? null : _auth(user));
      final scope = mount(timeout: const Duration(milliseconds: 30));
      await expectLater(
        scope.read(authViewModelProvider.future),
        throwsA(isA<TimeoutException>()),
      );
      expect(scope.read(authViewModelProvider).hasError, isTrue);
      expect(scope.read(authViewModelProvider).isLoading, isFalse);
      stalled.complete(_info(_a, 'late old profile'));
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(authViewModelProvider).hasError, isTrue);
      tokens.read = () async => _info(_a, 'recovered');
      service.load = () async => _auth(_info(_a, 'recovered'));
      await scope.read(authViewModelProvider.notifier).refresh();
      expect(scope.read(authViewModelProvider).requireValue?.name, 'recovered');
      expect(client.auth.currentUser?.id, _a);
      expect(tokens.clears, 0);
    },
  );

  test(
    'a failed account refresh leaves loading and permits another retry',
    () async {
      final scope = mount();
      await scope.read(authViewModelProvider.future);
      tokens.read = () => Future.error(StateError('storage unavailable'));
      service.load = () => Future.error(StateError('profile unavailable'));
      await scope.read(authViewModelProvider.notifier).refresh();
      expect(scope.read(authViewModelProvider).hasError, isTrue);
      expect(scope.read(authViewModelProvider).isLoading, isFalse);
      tokens.read = () async => _info(_a);
      service.load = () async => _auth(_info(_a));
      await scope.read(authViewModelProvider.notifier).refresh();
      expect(scope.read(authViewModelProvider).requireValue?.id, _a);
    },
  );

  test(
    'default container stops after one account deadline until explicit retry',
    () async {
      final stalled = Completer<dto.UserInfo?>();
      var reads = 0;
      Future<dto.UserInfo?> read() {
        reads++;
        return stalled.future;
      }

      tokens.read = read;
      service.load = () =>
          read().then((user) => user == null ? null : _auth(user));
      final scope = mount(timeout: const Duration(milliseconds: 30));
      await expectLater(
        scope.read(authViewModelProvider.future),
        throwsA(isA<TimeoutException>()),
      );
      // The default container would schedule its first hidden retry at 200ms.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      final failed = scope.read(authViewModelProvider);
      expect(reads, 1);
      expect(failed.hasError, isTrue);
      expect(failed.isLoading, isFalse);
      expect(failed.retrying, isFalse);
      expect(failed.asData, isNull);
      expect(tokens.clears, 0);
      tokens.read = () async => _info(_a, 'explicit retry');
      service.load = () async => _auth(_info(_a, 'explicit retry'));
      await scope.read(authViewModelProvider.notifier).refresh();
      expect(
        scope.read(authViewModelProvider).requireValue?.name,
        'explicit retry',
      );
      stalled.complete(_info(_a, 'obsolete timed-out account'));
      await Future<void>.delayed(Duration.zero);
      expect(
        scope.read(authViewModelProvider).requireValue?.name,
        'explicit retry',
      );
    },
  );

  for (final fail in [false, true]) {
    test(
      'initial account future resolves after same-owner token refresh: fail=$fail',
      () async {
        final initial = Completer<dto.UserInfo?>();
        final newest = Completer<dto.AuthResponse?>();
        tokens.read = () => initial.future;
        var calls = 0;
        service.load = () => ++calls == 1 && kIsWeb
            ? initial.future.then((user) => user == null ? null : _auth(user))
            : newest.future;
        final scope = mount(timeout: const Duration(milliseconds: 50));
        final first = scope.read(authViewModelProvider.future);
        final result = fail
            ? expectLater(first, throwsA(isA<TimeoutException>()))
            : expectLater(
                first,
                completion(
                  isA<dto.UserInfo>().having(
                    (user) => user.name,
                    'name',
                    'new token account',
                  ),
                ),
              );
        await session(_a);
        final synchronization = scope
            .read(authViewModelProvider.notifier)
            .synchronizeSupabaseSession();
        if (!fail) newest.complete(_auth(_info(_a, 'new token account')));
        await synchronization;
        await result;
        expect(scope.read(authViewModelProvider).isLoading, isFalse);
        if (fail) {
          expect(scope.read(authViewModelProvider).hasError, isTrue);
          expect(scope.read(authViewModelProvider).asData, isNull);
          newest.complete(_auth(_info(_a, 'obsolete newest response')));
        } else {
          expect(
            scope.read(authViewModelProvider).requireValue?.name,
            'new token account',
          );
        }
        initial.complete(_info(_a, 'obsolete initial response'));
        await Future<void>.delayed(Duration.zero);
        expect(scope.read(authViewModelProvider).isLoading, isFalse);
        if (fail) {
          expect(scope.read(authViewModelProvider).hasError, isTrue);
        } else {
          expect(
            scope.read(authViewModelProvider).requireValue?.name,
            'new token account',
          );
        }
        expect(client.auth.currentUser?.id, _a);
        expect(tokens.clears, 0);
      },
    );
  }

  test(
    'same-owner background sync coalesces and retains verified data on a temporary timeout',
    () async {
      final scope = mount();
      await scope.read(authViewModelProvider.future);
      final stalled = Completer<dto.AuthResponse?>();
      service.load = () => stalled.future;
      final before = service.reads;
      final vm = scope.read(authViewModelProvider.notifier);
      final first = vm.synchronizeSupabaseSession();
      final second = vm.synchronizeSupabaseSession();
      expect(second, same(first));
      expect(service.reads, before + 1);
      expect(scope.read(authViewModelProvider).isLoading, isFalse);
      expect(scope.read(authViewModelProvider).requireValue?.id, _a);
      stalled.completeError(TimeoutException('temporary connection delay'));
      await first;
      expect(scope.read(authViewModelProvider).requireValue?.id, _a);
      expect(client.auth.currentUser?.id, _a);
      expect(tokens.clears, 0);
    },
  );

  test(
    'a server-rejected session does not retain a previously visible account',
    () async {
      final scope = mount();
      await scope.read(authViewModelProvider.future);
      service.load = () async {
        await client.auth.signOut(scope: SignOutScope.local);
        throw const AuthException('server rejected owner', code: 'user_banned');
      };
      await scope
          .read(authViewModelProvider.notifier)
          .synchronizeSupabaseSession();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(authViewModelProvider).asData?.value, isNull);
      expect(client.auth.currentUser, isNull);
    },
  );

  test('an initial A request cannot overwrite a newer A after A B A', () async {
    final old = Completer<dto.UserInfo?>();
    var reads = 0;
    Future<dto.UserInfo?> read() async {
      if (++reads == 1) return old.future;
      final owner = client.auth.currentUser?.id;
      return owner == null ? null : _info(owner, 'fresh account');
    }

    tokens.read = read;
    service.load = () =>
        read().then((user) => user == null ? null : _auth(user));
    final scope = mount();
    await Future<void>.delayed(Duration.zero);
    await session(_b);
    await session(_a);
    await scope.read(authViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);
    old.complete(_info(_a, 'obsolete initial profile'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(scope.read(authViewModelProvider).requireValue?.id, _a);
    expect(
      scope.read(authViewModelProvider).requireValue?.name,
      'fresh account',
    );
    expect(reads, greaterThan(1));
  });

  test(
    'logout resolves a pending initial build immediately and discards its late reply',
    () async {
      final old = Completer<dto.UserInfo?>();
      tokens.read = () => old.future;
      service.load = () =>
          old.future.then((user) => user == null ? null : _auth(user));
      final scope = mount();
      final initial = scope.read(authViewModelProvider.future);
      await scope.read(authViewModelProvider.notifier).logout();
      expect(await initial, isNull);
      old.complete(_info(_a));
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(authViewModelProvider).asData?.value, isNull);
    },
  );

  test('consent bookkeeping cannot block a completed account sync', () async {
    final scope = mount();
    await scope.read(authViewModelProvider.future);
    await scope
        .read(authViewModelProvider.notifier)
        .synchronizeSupabaseSession();
    expect(service.consent.isCompleted, isFalse);
    expect(scope.read(authViewModelProvider).requireValue?.id, _a);
  });
  test(
    'same-owner SDK token updates do not invalidate a visible account',
    () async {
      final scope = mount();
      await scope.read(authViewModelProvider.future);
      final before = service.reads;
      tokens.read = () => Future.error(StateError('unexpected storage reload'));
      service.load = () => Future.error(StateError('unexpected auth reload'));
      await session(_a);
      await Future<void>.delayed(Duration.zero);
      expect(scope.read(authViewModelProvider).requireValue?.id, _a);
      expect(scope.read(authViewModelProvider).isLoading, isFalse);
      expect(service.reads, before);
    },
  );

  test(
    'login consent bookkeeping itself has a non-blocking deadline',
    () async {
      final scope = mount(timeout: const Duration(milliseconds: 30));
      await scope.read(authViewModelProvider.future);
      await scope.read(authViewModelProvider.notifier).syncConsentIfPresent();
      expect(service.consent.isCompleted, isFalse);
      expect(scope.read(authViewModelProvider).requireValue?.id, _a);
      expect(client.auth.currentUser?.id, _a);
      expect(tokens.clears, 0);
    },
  );
}

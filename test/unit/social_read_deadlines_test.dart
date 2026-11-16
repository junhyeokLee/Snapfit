import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _work = '22222222-2222-4222-8222-222222222222';
const _deadline = Duration(seconds: 25);

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-token',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

Map<String, dynamic> _profile(String name, {bool avatar = false}) => {
  'userId': _owner,
  'displayName': name,
  'handle': 'fixture.owner',
  'bio': '',
  if (avatar) 'avatarPath': '$_owner/$_work.png',
};

Map<String, dynamic> _page(int offset) => {
  'items': <dynamic>[],
  'hasMore': false,
  'nextOffset': offset,
};

http.Response _response(dynamic value, {http.BaseRequest? request}) =>
    http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );

class _Result<T> {
  _Result(Future<T> future) {
    unawaited(
      future.then<void>(
        (result) {
          value = result;
          settled = true;
        },
        onError: (Object failure) {
          error = failure;
          settled = true;
        },
      ),
    );
  }
  bool settled = false;
  T? value;
  Object? error;
}

void main() {
  late _Client client;
  late SocialRepository repository;
  late Future<dynamic> Function(String action) rpc;
  late Future<http.Response> Function(http.Request request) sign;
  late List<String> actions;
  late int signs;

  setUp(() {
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(
      User(
        id: _owner,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-11-02',
      ),
    );
    actions = [];
    signs = 0;
    rpc = (_) async => null;
    sign = (request) async {
      final paths = (jsonDecode(request.body) as Map)['paths'] as List;
      return _response([
        for (final path in paths)
          {'path': path, 'signedURL': '/object/sign/fixture/$path?token=test'},
      ]);
    };
    client = _Client(
      auth,
      MockClient((request) async {
        if (request.url.path.endsWith('/rpc/social_api')) {
          final action =
              (jsonDecode(request.body) as Map)['p_action'] as String;
          actions.add(action);
          return _response(await rpc(action), request: request);
        }
        if (request.url.path.contains('/object/sign/')) {
          signs++;
          final response = await sign(request);
          return http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }
        throw StateError('Unexpected fixture request ${request.url.path}');
      }),
    );
    repository = SocialRepository(client);
  });
  tearDown(() async => client.dispose());

  final reads = <String, Future<dynamic> Function(SocialRepository)>{
    'feed': (r) => r.fetchFeed(),
    'feed with cursor': (r) => r.fetchFeedPage(
      const SocialFeedQuery(cursor: {'createdAt': '2026-11-01', 'id': _work}),
    ),
    'profile': (r) => r.fetchProfile(_owner),
    'profile albums': (r) => r.fetchProfileWorksPage(_owner),
    'profile moments': (r) => r.fetchProfileMomentsPage(_owner),
    'profile months': (r) => r.fetchProfileMomentMonthsPage(_owner),
    'profile month detail': (r) =>
        r.fetchProfileMomentMonthPage(_owner, DateTime(2026, 11)),
  };
  for (final entry in reads.entries) {
    test(
      '${entry.key} stops waiting for an unresponsive RPC without retrying',
      () {
        fakeAsync((clock) {
          final pending = Completer<dynamic>();
          rpc = (_) => pending.future;
          final result = _Result(entry.value(repository));
          clock.flushMicrotasks();
          expect(actions, hasLength(1));
          clock.elapse(_deadline - const Duration(milliseconds: 1));
          expect(result.settled, isFalse);
          clock.elapse(const Duration(milliseconds: 1));
          clock.flushMicrotasks();
          expect(result.error, isA<TimeoutException>());
          expect(actions, hasLength(1));
        });
      },
    );
  }

  test(
    'feed retry keeps its fresh page when the timed-out RPC completes late',
    () {
      fakeAsync((clock) {
        final old = Completer<dynamic>();
        rpc = (_) => actions.length == 1 ? old.future : Future.value(_page(12));
        final container = ProviderContainer(
          overrides: [
            socialRepositoryProvider.overrideWithValue(repository),
            socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
          ],
        );
        final provider = socialFeedProvider(const SocialFeedQuery());
        final subscription = container.listen(provider, (_, __) {});
        final first = _Result(container.read(provider.future));
        clock.flushMicrotasks();
        clock.elapse(_deadline);
        clock.flushMicrotasks();
        expect(first.error, isA<TimeoutException>());
        expect(container.read(provider).hasError, isTrue);

        container.invalidate(provider);
        final retry = _Result(container.read(provider.future));
        clock.flushMicrotasks();
        expect(retry.value?.nextOffset, 12);
        expect(actions, ['feed', 'feed']);

        old.complete(_page(99));
        clock.flushMicrotasks();
        expect(first.error, isA<TimeoutException>());
        expect(container.read(provider).requireValue.nextOffset, 12);
        subscription.close();
        container.dispose();
        clock.flushMicrotasks();
      });
    },
  );

  test(
    'profile deadline includes avatar signing and retry rejects its old result',
    () {
      fakeAsync((clock) {
        final rpcResponse = Completer<dynamic>();
        final oldSign = Completer<http.Response>();
        rpc = (_) => actions.length == 1
            ? rpcResponse.future
            : Future.value(_profile('새 프로필'));
        sign = (_) => oldSign.future;
        final container = ProviderContainer(
          overrides: [
            socialRepositoryProvider.overrideWithValue(repository),
            socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
          ],
        );
        final provider = socialProfileProvider(_owner);
        final subscription = container.listen(provider, (_, __) {});
        final first = _Result(container.read(provider.future));
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 20));
        rpcResponse.complete(_profile('늦은 프로필', avatar: true));
        clock.flushMicrotasks();
        expect(signs, 1);
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(first.error, isA<TimeoutException>());

        container.invalidate(provider);
        final retry = _Result(container.read(provider.future));
        clock.flushMicrotasks();
        expect(retry.value?.displayName, '새 프로필');
        oldSign.complete(
          _response([
            {
              'path': '$_owner/$_work.png',
              'signedURL': '/object/sign/fixture/old.png?token=test',
            },
          ]),
        );
        clock.flushMicrotasks();
        expect(container.read(provider).requireValue?.displayName, '새 프로필');
        expect(container.read(provider).requireValue?.avatarUrl, isNull);
        subscription.close();
        container.dispose();
        clock.flushMicrotasks();
      });
    },
  );

  test('legacy feed snapshot signing shares the complete page deadline', () {
    fakeAsync((clock) {
      final oldSign = Completer<http.Response>();
      rpc = (_) async => {
        ..._page(1),
        'items': [
          {
            'id': _work,
            'title': '예전 공개 앨범',
            'author': _profile('프로필'),
            'createdAt': '2026-11-01T00:00:00Z',
            'imagePaths': ['$_owner/$_work/0.png'],
          },
        ],
      };
      sign = (_) => oldSign.future;
      final first = _Result(repository.fetchFeed());
      clock.flushMicrotasks();
      expect(signs, 1);
      clock.elapse(_deadline);
      clock.flushMicrotasks();
      expect(first.error, isA<TimeoutException>());
      rpc = (_) async => _page(0);
      final retry = _Result(repository.fetchFeed());
      clock.flushMicrotasks();
      expect(retry.value?.items, isEmpty);
      oldSign.complete(
        _response([
          {
            'path': '$_owner/$_work/0.png',
            'signedURL': '/object/sign/fixture/old.png?token=test',
          },
        ]),
      );
      clock.flushMicrotasks();
      expect(first.error, isA<TimeoutException>());
      expect(actions, ['feed', 'feed']);
    });
  });

  test('a timed-out profile read never starts a late ensureProfile write', () {
    fakeAsync((clock) {
      final old = Completer<dynamic>();
      rpc = (_) => old.future;
      final result = _Result(repository.ensureOwnProfile());
      clock.flushMicrotasks();
      clock.elapse(_deadline);
      clock.flushMicrotasks();
      expect(result.error, isA<TimeoutException>());
      old.complete(null);
      clock.flushMicrotasks();
      expect(actions, ['profile']);
    });
  });

  test('follow writes retain their original lifetime and never auto retry', () {
    fakeAsync((clock) {
      final pending = Completer<dynamic>();
      rpc = (_) => pending.future;
      final result = _Result(repository.setFollowing(_work, true));
      clock.flushMicrotasks();
      clock.elapse(_deadline * 2);
      clock.flushMicrotasks();
      expect(result.settled, isFalse);
      expect(actions, ['setFollowing']);
      pending.complete(true);
      clock.flushMicrotasks();
      expect(result.value, isTrue);
      expect(result.error, isNull);
      expect(actions, ['setFollowing']);
    });
  });
}

import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/data/repositories/supabase_album_repository.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_edit_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client httpClient)
    : super(
        'https://fixture.test',
        'fixture-key',
        httpClient: httpClient,
        accessToken: () async => 'fixture-token',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

const _userId = '00000000-0000-0000-0000-000000000001';
Map<String, dynamic> _row(int id, {String owner = 'other'}) => {
  'id': id,
  'owner_id': owner,
  'title': 'Album $id',
  'updated_at': '2026-10-25T01:02:03.123456Z',
};

void main() {
  late _Client client;
  late SupabaseAlbumRepository repository;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> memberships;
  late Object albums;
  late bool memberFailure;
  late _Auth auth;
  Map<String, dynamic>? rpcError;
  Completer<void>? responseGate;

  setUp(() {
    requests = [];
    memberships = [];
    albums = [];
    memberFailure = false;
    auth = _Auth();
    rpcError = null;
    responseGate = null;
    when(() => auth.currentUser).thenReturn(
      User(
        id: _userId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-08',
      ),
    );
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('album_members')) {
          if (memberFailure)
            return http.Response(
              jsonEncode({'message': 'fixture failure'}),
              403,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          final single =
              request.headers['Accept']?.contains('object') == true ||
              request.headers['accept']?.contains('object') == true;
          return http.Response(
            jsonEncode(single ? memberships.firstOrNull : memberships),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (responseGate != null) await responseGate!.future;
        if ((request.url.path.endsWith('save_album_document') ||
                request.url.path.endsWith('create_album_document')) &&
            rpcError != null) {
          return http.Response(
            jsonEncode(rpcError),
            409,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(albums),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    repository = SupabaseAlbumRepository(client, tokenStorage: _Tokens());
  });
  tearDown(() async => client.dispose());

  const seed = CreateAlbumRequest(
    ratio: '1.0',
    title: '첫 앨범',
    coverLayersJson: '{"layers":[]}',
    coverImageUrl: '',
    coverThumbnailUrl: '',
  );
  const creationId = '11111111-1111-4111-8111-111111111111';
  test(
    'creation refuses an unpersisted identity without a network insert',
    () async {
      await expectLater(
        repository.createAlbum(seed),
        throwsA(isA<AlbumCreationRecoveryRequired>()),
      );
      expect(requests, isEmpty);
    },
  );
  test(
    'creation only sends fixed seed and owner to idempotent RPC, preserving raw revision',
    () async {
      albums = _row(71, owner: _userId);
      final created = await repository.createAlbum(
        seed,
        requestId: creationId,
        expectedUserId: _userId,
      );
      final repeated = await repository.createAlbum(
        seed,
        requestId: creationId,
        expectedUserId: _userId,
      );
      expect(created.id, 71);
      expect(repeated.updatedAt, '2026-10-25T01:02:03.123456Z');
      expect(requests, hasLength(2));
      expect(
        requests.every(
          (request) => request.url.path.endsWith('/rpc/create_album_document'),
        ),
        isTrue,
      );
      final body = jsonDecode(requests.first.body) as Map;
      expect(body['p_request_id'], creationId);
      expect(body['p_expected_actor_id'], _userId);
      expect((body['p_album'] as Map)['title'], seed.title);
      expect((body['p_album'] as Map).containsKey('owner_id'), isFalse);
      expect(requests.first.body, requests.last.body);
    },
  );
  test(
    'creation keeps deleted and conflicting identities as explicit recovery errors',
    () async {
      for (final (code, message, matcher) in [
        (
          'PT409',
          'album_creation_request_conflict',
          isA<AlbumCreationRequestConflict>(),
        ),
        ('PT410', 'album_creation_deleted', isA<AlbumCreationDeleted>()),
      ]) {
        rpcError = {'code': code, 'message': message};
        await expectLater(
          repository.createAlbum(
            seed,
            requestId: creationId,
            expectedUserId: _userId,
          ),
          throwsA(matcher),
        );
      }
      expect(requests, hasLength(2));
    },
  );
  test(
    'creation directly fences A to B to A even without an active UI provider',
    () async {
      final events = StreamController<AuthState>.broadcast(sync: true);
      addTearDown(events.close);
      User user(String id) => User(
        id: id,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-29',
      );
      var current = user(_userId);
      when(() => auth.currentUser).thenAnswer((_) => current);
      when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
      albums = _row(71, owner: _userId);
      responseGate = Completer<void>();
      final saving = repository.createAlbum(
        seed,
        requestId: creationId,
        expectedUserId: _userId,
      );
      final rejected = expectLater(
        saving,
        throwsA(isA<AlbumEditSessionChanged>()),
      );
      for (var i = 0; i < 100 && requests.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(requests, hasLength(1));
      current = user('00000000-0000-0000-0000-000000000002');
      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(accessToken: 'fixture-b', tokenType: 'bearer', user: current),
        ),
      );
      current = user(_userId);
      events.add(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(accessToken: 'fixture-a', tokenType: 'bearer', user: current),
        ),
      );
      responseGate!.complete();
      await rejected;
      expect(requests, hasLength(1));
    },
  );

  test(
    'my albums includes accepted shared albums and their real access roles',
    () async {
      memberships = [
        {'album_id': 7, 'role': 'VIEWER'},
        {'album_id': 8, 'role': 'EDITOR'},
      ];
      albums = [_row(1, owner: _userId), _row(7), _row(8)];
      final result = await repository.fetchMyAlbums();
      expect(result.map((a) => a.memberRole), ['OWNER', 'VIEWER', 'EDITOR']);
      expect(result.map((a) => a.allowsEditing), [true, false, true]);
      expect(result.map((a) => a.allowsManagement), [true, false, false]);
      expect(requests.first.url.queryParameters['user_id'], 'eq.$_userId');
      expect(requests.first.url.queryParameters['status'], 'eq.ACCEPTED');
      expect(
        requests.last.url.queryParameters['or'],
        '(owner_id.eq.$_userId,id.in.(7,8))',
      );
      expect(
        requests.last.url.queryParameters['order'],
        'sort_order.asc.nullslast,updated_at.desc.nullslast',
      );
    },
  );

  test('no memberships keeps the original owner-only filter', () async {
    albums = [_row(1, owner: _userId)];
    final result = await repository.fetchMyAlbums();
    expect(result.single.memberRole, 'OWNER');
    expect(requests.last.url.queryParameters['owner_id'], 'eq.$_userId');
    expect(requests.last.url.queryParameters['or'], isNull);
  });

  test('membership failure does not silently hide shared albums', () async {
    memberFailure = true;
    await expectLater(
      repository.fetchMyAlbums(),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests.length, 1);
  });

  test(
    'single album resolves viewer and editing rights without serializing role',
    () async {
      albums = _row(7);
      memberships = [
        {'role': 'VIEWER', 'status': 'ACCEPTED'},
      ];
      final viewer = await repository.fetchAlbum('7');
      expect(viewer.allowsEditing, isFalse);
      expect(viewer.toJson().containsKey('memberRole'), isFalse);
      expect(requests.last.url.queryParameters['user_id'], 'eq.$_userId');
      memberships = [
        {'role': 'EDITOR', 'status': 'PENDING'},
      ];
      expect((await repository.fetchAlbum('7')).allowsEditing, isFalse);
    },
  );

  test('owner fetch needs no extra membership request', () async {
    albums = _row(7, owner: _userId);
    expect((await repository.fetchAlbum('7')).memberRole, 'OWNER');
    expect(requests.length, 1);
  });

  test(
    'shared editor saves raw revision, expected actor and immutable request key through CAS RPC',
    () async {
      albums = _row(7);
      memberships = [
        {'role': 'EDITOR', 'status': 'ACCEPTED'},
      ];
      final album = await repository.updateAlbum(
        7,
        const CreateAlbumRequest(
          title: 'Updated',
          ratio: '1',
          coverLayersJson: '{}',
          coverImageUrl: '',
          coverThumbnailUrl: '',
        ),
        expectedUpdatedAt: '2026-10-25T01:02:03.123456Z',
        requestId: 'request-id',
        expectedUserId: _userId,
      );
      expect(album.memberRole, 'EDITOR');
      expect(requests.first.method, 'POST');
      expect(requests.first.url.path, endsWith('/rpc/save_album_document'));
      final payload = jsonDecode(requests.first.body) as Map;
      expect(payload['p_album_id'], 7);
      expect(payload['p_expected_updated_at'], '2026-10-25T01:02:03.123456Z');
      expect(payload['p_expected_actor_id'], _userId);
      expect(payload['p_request_id'], 'request-id');
      expect(payload['p_changes']['owner_id'], isNull);
    },
  );
  const changes = CreateAlbumRequest(
    ratio: '1',
    coverLayersJson: '{}',
    coverImageUrl: '',
    coverThumbnailUrl: '',
  );
  test(
    'missing base revision refuses saving before any network request',
    () async {
      await expectLater(
        repository.updateAlbum(7, changes),
        throwsA(isA<AlbumRevisionRequired>()),
      );
      expect(requests, isEmpty);
    },
  );
  for (final code in ['PT409', '42501']) {
    test(
      'server $code keeps conflict and permission failures distinct',
      () async {
        rpcError = {
          'code': code,
          'message': code == 'PT409'
              ? 'album_revision_conflict'
              : 'album_permission_denied',
        };
        await expectLater(
          repository.updateAlbum(7, changes, expectedUpdatedAt: 'raw-revision'),
          throwsA(
            code == 'PT409'
                ? isA<AlbumRevisionConflict>()
                : isA<AlbumEditAccessRevoked>(),
          ),
        );
      },
    );
  }
  test(
    'nonowner legacy OWNER membership never grants editing or management',
    () async {
      memberships = [
        {'album_id': 7, 'role': 'OWNER', 'status': 'ACCEPTED'},
      ];
      albums = _row(7);
      final single = await repository.fetchAlbum('7');
      expect(single.memberRole, 'VIEWER');
      expect(single.allowsEditing, isFalse);
      expect(single.allowsManagement, isFalse);
      albums = [_row(7)];
      expect((await repository.fetchMyAlbums()).single.memberRole, 'VIEWER');
    },
  );
  test('replaced account cannot adopt the old save response', () async {
    albums = _row(7, owner: _userId);
    responseGate = Completer<void>();
    final save = repository.updateAlbum(
      7,
      changes,
      expectedUpdatedAt: 'raw-revision',
      expectedUserId: _userId,
    );
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    when(() => auth.currentUser).thenReturn(null);
    responseGate!.complete();
    await expectLater(save, throwsA(isA<AlbumEditSessionChanged>()));
  });
}

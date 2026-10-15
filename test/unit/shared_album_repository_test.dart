import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/data/repositories/supabase_album_repository.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
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
};

void main() {
  late _Client client;
  late SupabaseAlbumRepository repository;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> memberships;
  late Object albums;
  late bool memberFailure;

  setUp(() {
    requests = [];
    memberships = [];
    albums = [];
    memberFailure = false;
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(
      User(
        id: _userId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-08',
      ),
    );
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
    'shared editor saves use role-checked server RLS, not owner-only restriction',
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
      );
      expect(album.memberRole, 'EDITOR');
      expect(requests.first.method, 'PATCH');
      expect(requests.first.url.queryParameters['id'], 'eq.7');
      expect(requests.first.url.queryParameters['owner_id'], isNull);
      expect(jsonDecode(requests.first.body)['owner_id'], isNull);
    },
  );
}

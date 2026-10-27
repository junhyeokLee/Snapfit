import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/data/repositories/supabase_album_member_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends Mock implements TokenStorage {}

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.test',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-token',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

const _owner = '11111111-1111-4111-8111-111111111111';
const _member = '22222222-2222-4222-8222-222222222222';

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-25',
);

void main() {
  late _Client client;
  late SupabaseAlbumMemberRepository repository;
  late String? actor;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> members;
  late int revokedCount;

  setUp(() {
    actor = _owner;
    requests = [];
    members = [];
    revokedCount = 2;
    final auth = _Auth();
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/functions/v1/album-invites') {
          final action = (jsonDecode(request.body) as Map)['action'];
          return http.Response(
            jsonEncode(
              action == 'create'
                  ? {
                      'albumId': 7,
                      'token': 'one',
                      'link': 'https://snapfit-c719d.web.app/invite/one',
                    }
                  : {'albumId': 7, 'role': 'EDITOR', 'success': true},
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path != '/rest/v1/rpc/album_collaboration') {
          throw StateError('Unexpected request: ${request.url.path}');
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            body['p_action'] == 'members'
                ? members
                : body['p_action'] == 'revokeInvites'
                ? revokedCount
                : true,
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = SupabaseAlbumMemberRepository(client, tokenStorage: _Tokens());
  });
  tearDown(() async => client.dispose());

  test(
    'member list preserves real identities and safe names without private profile lookups',
    () async {
      members = [
        {
          'userId': _owner,
          'displayName': '앨범을 만든 사람',
          'isOwner': true,
          'role': 'OWNER',
          'status': 'ACCEPTED',
          'email': 'private-owner@fixture.invalid',
          'avatarUrl': 'https://fixture.invalid/private-avatar.png',
        },
        {
          'id': 48,
          'userId': _member,
          'displayName': '함께 남기는 기록',
          'isOwner': false,
          'role': 'VIEWER',
          'status': 'ACCEPTED',
        },
      ];

      final result = await repository.fetchMembers(7);

      expect(result.map((member) => member.userUuid), [_owner, _member]);
      expect(result.map((member) => member.userName), [
        '앨범을 만든 사람',
        '함께 남기는 기록',
      ]);
      expect(result.map((member) => member.isOwner), [true, false]);
      expect(result.map((member) => member.role), ['OWNER', 'VIEWER']);
      expect(result.map((member) => member.status), ['ACCEPTED', 'ACCEPTED']);
      expect(result.last.id, 48);
      expect(result.first.userId, isNot(result.last.userId));
      for (final member in result) {
        expect(member.userEmail, isNull);
        expect(member.profileImageUrl, isNull);
      }
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.queryParameters, isEmpty);
      expect(jsonDecode(requests.single.body), {
        'p_action': 'members',
        'p_payload': {'albumId': 7, 'expectedActorId': _owner},
      });
    },
  );

  test(
    'member mutations send raw UUIDs and the desired role to the atomic RPC',
    () async {
      await repository.setMemberRole(7, _member, 'VIEWER');
      await repository.setMemberRole(7, _member, 'EDITOR');
      await repository.removeMember(7, _member);
      await repository.leave(7);

      expect(requests.map((request) => jsonDecode(request.body)), [
        {
          'p_action': 'setMemberRole',
          'p_payload': {
            'albumId': 7,
            'userId': _member,
            'role': 'VIEWER',
            'expectedActorId': _owner,
          },
        },
        {
          'p_action': 'setMemberRole',
          'p_payload': {
            'albumId': 7,
            'userId': _member,
            'role': 'EDITOR',
            'expectedActorId': _owner,
          },
        },
        {
          'p_action': 'removeMember',
          'p_payload': {
            'albumId': 7,
            'userId': _member,
            'expectedActorId': _owner,
          },
        },
        {
          'p_action': 'leave',
          'p_payload': {'albumId': 7, 'expectedActorId': _owner},
        },
      ]);
      expect(requests.every((request) => request.method == 'POST'), isTrue);
    },
  );

  test(
    'revoking unused invitations returns the count and preserves actor scope',
    () async {
      expect(await repository.revokeInvites(7), 2);
      revokedCount = 0;
      expect(await repository.revokeInvites(7), 0);
      for (final request in requests) {
        expect(jsonDecode(request.body), {
          'p_action': 'revokeInvites',
          'p_payload': {'albumId': 7, 'expectedActorId': _owner},
        });
      }
    },
  );

  test(
    'create accept and member requests retain the actor that started them',
    () async {
      final creating = repository.invite(7);
      actor = _member;
      await creating;
      expect(
        (jsonDecode(requests.last.body) as Map)['expectedActorId'],
        _owner,
      );
      actor = _owner;
      final accepting = repository.acceptInvite('one');
      actor = _member;
      await accepting;
      expect(
        (jsonDecode(requests.last.body) as Map)['expectedActorId'],
        _owner,
      );
      actor = _owner;
      final leaving = repository.leave(7);
      actor = _member;
      await leaving;
      expect(
        (jsonDecode(requests.last.body) as Map)['p_payload']['expectedActorId'],
        _owner,
      );
    },
  );

  test(
    'owner and unknown role changes are rejected before requesting the server',
    () async {
      for (final role in ['OWNER', 'ADMIN', 'PENDING', 'editor', '']) {
        await expectLater(
          repository.setMemberRole(7, _member, role),
          throwsFormatException,
        );
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'anonymous member reads and mutations fail without any API request',
    () async {
      actor = null;
      await expectLater(repository.fetchMembers(7), throwsException);
      await expectLater(
        repository.setMemberRole(7, _member, 'VIEWER'),
        throwsException,
      );
      await expectLater(repository.removeMember(7, _member), throwsException);
      await expectLater(repository.leave(7), throwsException);
      await expectLater(repository.revokeInvites(7), throwsException);
      expect(requests, isEmpty);
    },
  );
}

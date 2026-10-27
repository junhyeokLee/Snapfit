import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _work = '44444444-4444-4444-8444-444444444444';
Map<String, dynamic> _profile(String id) => {
  'userId': id,
  'displayName': '공개 이름',
  'handle': 'public.name',
  'bio': '',
};
User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-25',
);
Uint8List _png({int width = 100, int height = 100}) {
  final bytes = Uint8List(24);
  bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
  ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Auth auth;
  late String? actor;
  late List<http.Request> requests;
  late Future<dynamic> Function(String, Map<String, dynamic>) rpc;
  late SocialRepository repository;
  late Future<http.Response?> Function(http.Request) storage;
  setUp(() {
    actor = _a;
    requests = [];
    auth = _Auth();
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    rpc = (action, payload) async => null;
    storage = (_) async => null;
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        final storageResponse = await storage(request);
        if (storageResponse != null) return storageResponse;
        if (request.url.path.endsWith('/rpc/social_api')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              await rpc(
                body['p_action'] as String,
                Map<String, dynamic>.from(body['p_payload'] as Map),
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.contains('/object/sign/')) {
          final bucket = request.url.path.split('/').last;
          final body = jsonDecode(request.body) as Map;
          return http.Response(
            jsonEncode(
              (body['paths'] as List)
                  .map(
                    (path) => {
                      'path': path,
                      'signedURL': '/object/sign/$bucket/$path?token=fixture',
                    },
                  )
                  .toList(),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = SocialRepository(client);
  });
  tearDown(() async => client.dispose());

  test(
    'official source reads return only verified product identity and title',
    () async {
      rpc = (action, payload) async {
        expect(action, anyOf('albumTemplateSource', 'resolveWorkTemplate'));
        return {'productKey': 'template:lightbound', 'title': '빛의 기록'};
      };
      final own = await repository.fetchAlbumTemplateSource(42);
      final public = await repository.resolveWorkTemplate(_work);
      expect(own!.productKey, 'template:lightbound');
      expect(public!.title, '빛의 기록');
      expect((jsonDecode(requests.first.body) as Map)['p_payload'], {
        'albumId': 42,
      });
      expect((jsonDecode(requests.last.body) as Map)['p_payload'], {
        'id': _work,
      });
      actor = null;
      await expectLater(
        repository.fetchAlbumTemplateSource(42),
        throwsStateError,
      );
      expect(
        (await repository.resolveWorkTemplate(_work))!.productKey,
        own.productKey,
      );
    },
  );

  test(
    'publication source option defaults off and forwards explicit consent',
    () async {
      final choices = <bool>[];
      rpc = (action, payload) async {
        expect(action, 'beginPublication');
        choices.add(payload['includeSourceTemplate'] as bool);
        expect(payload.containsKey('sourceTemplate'), isFalse);
        return {
          'id': _work,
          'pageIndexes': [0],
          'status': 'draft',
        };
      };
      await repository.beginPublication(
        albumId: 42,
        pageIndexes: [0],
        title: '기록',
      );
      await repository.beginPublication(
        albumId: 42,
        pageIndexes: [0],
        title: '기록',
        includeSourceTemplate: true,
      );
      expect(choices, [false, true]);
    },
  );

  test('source resolution never navigates across a changed account', () async {
    final pending = Completer<Map<String, dynamic>>();
    rpc = (_, _) => pending.future;
    final result = repository.resolveWorkTemplate(_work);
    await Future<void>.delayed(Duration.zero);
    actor = _b;
    pending.complete({'productKey': 'template:lightbound', 'title': '빛의 기록'});
    await expectLater(result, throwsStateError);
  });

  test(
    'paged work APIs preserve the page cursor, status filter and signed snapshots',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      rpc = (action, payload) async {
        calls.add((action, payload));
        return {
          'items': [
            {
              'id': _work,
              'author': _profile(_a),
              'title': '사진 작품',
              'createdAt': '2026-10-26T00:00:00Z',
              'imagePaths': ['$_a/$_work/0.png'],
            },
          ],
          'hasMore': true,
          'nextOffset': 36,
        };
      };
      final pages = [
        await repository.fetchOwnWorksPage(status: 'private', offset: 24),
        await repository.fetchSavedWorksPage(offset: 24),
        await repository.fetchProfileWorksPage(_b, offset: 24),
        await repository.searchPage(' 여행 ', offset: 24),
      ];
      expect(calls.map((c) => c.$1), [
        'ownWorksPage',
        'savedWorksPage',
        'profileWorksPage',
        'searchPage',
      ]);
      expect(
        calls.every((c) => c.$2['offset'] == 24 && c.$2['limit'] == 12),
        isTrue,
      );
      expect(calls.first.$2['status'], 'private');
      expect(calls[2].$2['userId'], _b);
      expect(calls.last.$2['query'], '여행');
      for (final page in pages) {
        expect(page.hasMore, isTrue);
        expect(page.nextOffset, 36);
        expect(
          page.items.single.imageUrls.single,
          contains('/social-snapshots/'),
        );
      }
    },
  );

  test(
    'creator and relation pages keep independent offsets and public profiles',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      rpc = (action, payload) async {
        calls.add((action, payload));
        return {
          'items': [_profile(_b)],
          'hasMore': false,
          'nextOffset': 31,
        };
      };
      final search = await repository.searchProfilesPage(' 여행 ', offset: 30);
      final relations = await repository.fetchRelationsPage(
        _a,
        followers: false,
        offset: 30,
      );
      expect(search.items.single.userId, _b);
      expect(relations.nextOffset, 31);
      expect(relations.hasMore, isFalse);
      expect(calls.first.$1, 'searchProfilesPage');
      expect(calls.first.$2, {'query': '여행', 'offset': 30, 'limit': 12});
      expect(calls.last.$1, 'relationsPage');
      expect(calls.last.$2, {
        'userId': _a,
        'followers': false,
        'offset': 30,
        'limit': 12,
      });
    },
  );

  test(
    'older comment transport addresses the work and retains the next offset',
    () async {
      rpc = (action, payload) async {
        expect(action, 'commentsPage');
        expect(payload, {'id': _work, 'offset': 100, 'limit': 12});
        return {
          'items': [
            {
              'id': _b,
              'body': '이전 이야기',
              'author': _profile(_a),
              'createdAt': '2026-10-26T00:00:00Z',
            },
          ],
          'hasMore': false,
          'nextOffset': 101,
        };
      };
      final page = await repository.fetchCommentsPage(_work, offset: 100);
      expect(page.items.single.body, '이전 이야기');
      expect(page.nextOffset, 101);
      expect(page.hasMore, isFalse);
    },
  );

  test('guest collection pages fail before transport', () async {
    actor = null;
    expect(() => repository.fetchOwnWorksPage(), throwsStateError);
    expect(() => repository.fetchSavedWorksPage(), throwsStateError);
    expect(requests, isEmpty);
  });
  test(
    'safe own profile creation never fetches private account fields',
    () async {
      rpc = (action, payload) async =>
          action == 'profile' ? null : _profile(_a);
      final profile = await repository.ensureOwnProfile();
      expect(profile.userId, _a);
      expect(requests.length, 2);
      expect(
        requests.every((r) => r.url.path.endsWith('/rpc/social_api')),
        isTrue,
      );
      final ensure = jsonDecode(requests.last.body) as Map;
      expect(ensure['p_action'], 'ensureProfile');
      expect(ensure['p_payload'], isEmpty);
    },
  );
  test('anonymous mutations fail before sending an API request', () async {
    actor = null;
    await expectLater(repository.toggleFollow(_b), throwsStateError);
    await expectLater(repository.setFollowing(_b, true), throwsStateError);
    await expectLater(repository.setLiked(_work, true), throwsStateError);
    await expectLater(repository.setSaved(_work, true), throwsStateError);
    await expectLater(
      repository.upsertOwnProfile(displayName: 'name', handle: 'name', bio: ''),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
  test('follow transport preserves the desired state when repeated', () async {
    var following = false;
    rpc = (action, payload) async {
      expect(action, 'setFollowing');
      expect(payload['userId'], _b);
      following = payload['following'] as bool;
      return following;
    };
    expect(await repository.setFollowing(_b, true), isTrue);
    expect(await repository.setFollowing(_b, true), isTrue);
    expect(await repository.setFollowing(_b, false), isFalse);
    expect(await repository.setFollowing(_b, false), isFalse);
    expect(requests.length, 4);
  });
  test(
    'like and save transport keep the desired state on repeated requests',
    () async {
      rpc = (action, payload) async {
        expect(payload['id'], _work);
        expect(['setLiked', 'setSaved'], contains(action));
        return payload[action == 'setLiked' ? 'liked' : 'saved'];
      };
      for (final desired in [true, true, false, false]) {
        expect(await repository.setLiked(_work, desired), desired);
        expect(await repository.setSaved(_work, desired), desired);
      }
      expect(requests.length, 8);
      expect((jsonDecode(requests[2].body) as Map)['p_payload'], {
        'id': _work,
        'liked': true,
      });
    },
  );
  test('comment retries retain an explicit key and normalized body', () async {
    rpc = (action, payload) async {
      expect(action, 'addComment');
      return {
        'id': payload['requestId'],
        'body': payload['body'],
        'author': _profile(_a),
        'createdAt': '2026-10-25T00:00:00Z',
      };
    };
    for (var attempt = 0; attempt < 2; attempt++) {
      final comment = await repository.addComment(
        _work,
        '  함께 본 기록  ',
        requestId: _b,
      );
      expect(comment.id, _b);
      expect(comment.body, '함께 본 기록');
    }
    expect(
      (jsonDecode(requests.first.body) as Map)['p_payload'],
      (jsonDecode(requests.last.body) as Map)['p_payload'],
    );
  });
  test('account change discards a late profile response', () async {
    final response = Completer<dynamic>();
    final started = Completer<void>();
    rpc = (action, payload) {
      started.complete();
      return response.future;
    };
    final future = repository.fetchProfile(_a);
    await started.future;
    actor = _b;
    response.complete(_profile(_a));
    await expectLater(future, throwsStateError);
  });
  test(
    'nested public profile photos are signed once with a short lifetime',
    () async {
      final path = '$_a/$_work.png';
      rpc = (_, __) async => [
        {..._profile(_a), 'avatarPath': path},
        {..._profile(_a), 'avatarPath': path},
      ];
      final profiles = await repository.fetchRelations(_b);
      expect(
        profiles.map((p) => p.avatarUrl),
        everyElement(contains('/social-profile-photos/')),
      );
      expect(requests.length, 2);
      final signed = jsonDecode(requests.last.body) as Map;
      expect(signed['paths'], [path]);
      expect(signed['expiresIn'], 60);
    },
  );
  test(
    'private avatar URLs and another owner path are never accepted',
    () async {
      rpc = (_, __) async => {
        ..._profile(_a),
        'avatarUrl': 'https://private/photo',
      };
      expect((await repository.fetchProfile(_a))!.avatarUrl, isNull);
      rpc = (_, __) async => {..._profile(_a), 'avatarPath': '$_b/$_work.png'};
      await expectLater(repository.fetchProfile(_a), throwsFormatException);
      expect(
        requests.every((r) => r.url.path.endsWith('/rpc/social_api')),
        isTrue,
      );
    },
  );
  test('withdrawn profile photo gracefully falls back to initials', () async {
    rpc = (_, __) async => {..._profile(_a), 'avatarPath': '$_a/$_work.png'};
    storage = (request) async => request.url.path.contains('/object/sign/')
        ? http.Response(
            '{"message":"not found","statusCode":"404","error":"not_found"}',
            404,
          )
        : null;
    expect((await repository.fetchProfile(_a))!.avatarUrl, isNull);
  });
  test('account change while signing discards a late public photo', () async {
    final response = Completer<http.Response?>();
    final started = Completer<void>();
    rpc = (_, __) async => {..._profile(_a), 'avatarPath': '$_a/$_work.png'};
    storage = (request) {
      if (!request.url.path.contains('/object/sign/'))
        return Future.value(null);
      started.complete();
      return response.future;
    };
    final future = repository.fetchProfile(_a);
    await started.future;
    actor = _b;
    response.complete(
      http.Response('[]', 200, headers: {'content-type': 'application/json'}),
    );
    await expectLater(future, throwsStateError);
  });
  test(
    'photo publication uploads a fresh PNG before changing the pointer and cleaning the old file',
    () async {
      final oldPath = '$_a/$_work.png';
      String? newPath;
      rpc = (action, payload) async {
        if (action == 'profile')
          return {..._profile(_a), 'avatarPath': oldPath};
        expect(action, 'setProfilePhoto');
        newPath = payload['path'] as String;
        expect(newPath, startsWith('$_a/'));
        expect(newPath, isNot(oldPath));
        expect(
          requests.any(
            (r) => r.url.path.contains('/object/social-profile-photos/'),
          ),
          isTrue,
        );
        return {..._profile(_a), 'avatarPath': newPath};
      };
      storage = (request) async {
        if (request.method == 'DELETE') return http.Response('[]', 200);
        if (request.url.path.contains('/object/social-profile-photos/')) {
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          expect(request.headers['x-upsert'], 'false');
          final multipart = latin1.decode(request.bodyBytes);
          expect(multipart.toLowerCase(), contains('content-type: image/png'));
          expect(
            multipart,
            contains(String.fromCharCodes([137, 80, 78, 71, 13, 10, 26, 10])),
          );
          return http.Response('{"Key":"fixture"}', 200);
        }
        return null;
      };
      final photo = await File(
        'assets/templates/original_editorial/images/travel_harbor.png',
      ).readAsBytes();
      final profile = await repository.updateOwnPhoto(photo);
      expect(profile.avatarPath, newPath);
      expect(profile.avatarUrl, contains(newPath!));
      expect(requests.last.method, 'DELETE');
      expect((jsonDecode(requests.last.body) as Map)['prefixes'], [oldPath]);
    },
  );
  test(
    'a lost photo response only attempts pending-file cleanup and preserves the failure',
    () async {
      String? uploadedPath;
      rpc = (action, payload) async {
        if (action == 'profile') return _profile(_a);
        uploadedPath = payload['path'] as String;
        throw http.ClientException('lost response');
      };
      storage = (request) async {
        if (request.method == 'DELETE') {
          // A committed pointer is protected by server RLS; cleanup is best effort.
          return http.Response(
            '{"message":"referenced","statusCode":"403","error":"forbidden"}',
            403,
          );
        }
        if (request.url.path.contains('/object/social-profile-photos/'))
          return http.Response('{"Key":"fixture"}', 200);
        return null;
      };
      final photo = await File(
        'assets/templates/original_editorial/images/travel_harbor.png',
      ).readAsBytes();
      await expectLater(
        repository.updateOwnPhoto(photo),
        throwsA(isA<http.ClientException>()),
      );
      expect(requests.last.method, 'DELETE');
      expect((jsonDecode(requests.last.body) as Map)['prefixes'], [
        uploadedPath,
      ]);
    },
  );
  test('private source paths cannot be turned into image URLs', () async {
    rpc = (action, payload) async => {
      'id': _work,
      'author': _profile(_a),
      'title': 'work',
      'createdAt': '2026-10-25T00:00:00Z',
      'imagePaths': ['album-assets/private/photo.jpg'],
    };
    await expectLater(repository.fetchWork(_work), throwsFormatException);
    expect(requests.length, 1);
  });
  test(
    'public raster paths are signed only in the isolated bucket for 60 seconds',
    () async {
      final paths = ['$_a/$_work/1.png', '$_a/$_work/0.png'];
      rpc = (action, payload) async => {
        'id': _work,
        'author': _profile(_a),
        'title': 'work',
        'aspectRatio': 0.75,
        'createdAt': '2026-10-25T00:00:00Z',
        'imagePaths': paths,
      };
      final work = await repository.fetchWork(_work);
      expect(work!.imageUrls.first, contains('/1.png?'));
      expect(work.aspectRatio, 0.75);
      expect(work.allowsStyleImport, isFalse);
      expect(
        requests.last.url.path,
        '/storage/v1/object/sign/social-snapshots',
      );
      expect((jsonDecode(requests.last.body) as Map)['expiresIn'], 60);
    },
  );
  test(
    'publication forwards the retained request key and resumes an uploaded slot',
    () async {
      rpc = (action, payload) async {
        if (action == 'beginPublication')
          return {
            'id': _work,
            'pageIndexes': [0, 2],
            'status': 'draft',
          };
        return {'path': '$_a/$_work/0.png', 'uploaded': true};
      };
      final draft = await repository.beginPublication(
        albumId: 10,
        pageIndexes: [0, 2],
        title: 'Title',
        requestId: _work,
      );
      expect(draft.pageIndexes, [0, 2]);
      expect(draft.status, 'draft');
      expect(
        ((jsonDecode(requests.first.body) as Map)['p_payload']
            as Map)['requestId'],
        _work,
      );
      await repository.uploadPublicationPage(draft.id, 0, _png());
      expect(requests.length, 2);
      expect(requests.every((r) => r.url.path.contains('/rpc/')), isTrue);
    },
  );
  test('only bounded raster headers pass the upload boundary', () async {
    expect(
      isSocialPng(Uint8List.fromList(utf8.encode('{"source":"private"}'))),
      isFalse,
    );
    expect(isSocialPng(_png(width: 0)), isFalse);
    expect(isSocialPng(_png(width: 8001)), isFalse);
    expect(isSocialPng(_png(width: 8000, height: 8000)), isFalse);
    expect(isSocialPng(_png()), isTrue);
    await expectLater(
      repository.uploadPublicationPage(_work, 0, Uint8List(32)),
      throwsFormatException,
    );
    expect(requests, isEmpty);
  });
}

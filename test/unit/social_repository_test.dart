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
String _mediaToken({String viewer = _a, int epoch = 1}) =>
    'v1.1793174460.$epoch.$viewer.${List.filled(64, 'a').join()}';
Map<String, dynamic> _v2Work({int count = 1}) => {
  'id': _work,
  'kind': 'moment',
  'author': _profile(_b),
  'title': '오늘의 한 장',
  'recordDate': '2026-10-28',
  'createdAt': '2026-10-28T00:00:00Z',
  'imagePaths': List.generate(count, (index) => '$_b/$_work/$index.png'),
  'mediaVersion': 2,
  'mediaTokens': List.generate(
    count,
    (index) => {
      'position': index,
      'token': _mediaToken(epoch: index + 1),
      'expiresAt': '2026-10-28T12:01:00Z',
    },
  ),
};
Map<String, dynamic> _reportJson({String status = 'open', int revision = 1}) =>
    {
      'id': _work,
      'targetKind': 'comment',
      'targetId': _b,
      'targetWorkId': _work,
      'reason': 'privacy',
      'details': '사진에 개인정보가 있어요',
      'status': status,
      'revision': revision,
      'createdAt': '2026-10-28T00:00:00Z',
      'resolvedAt': null,
      'resolutionNote': null,
      'targetPreview': null,
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
    'v2 media URLs use only the project gateway and never sign Storage or embed a JWT',
    () async {
      rpc = (_, _) async => {
        ..._v2Work(count: 2),
        // Neither an old source URL nor a response-supplied host is trusted.
        'imageUrls': ['https://untrusted.invalid/private.jpg?jwt=private-jwt'],
        'mediaOrigin': 'https://untrusted.invalid',
      };
      final work = (await repository.fetchWork(_work))!;
      expect(work.imageUrls, hasLength(2));
      for (var index = 0; index < work.imageUrls.length; index++) {
        final url = Uri.parse(work.imageUrls[index]);
        expect(url.origin, 'https://fixture.supabase.co');
        expect(url.path, '/functions/v1/social-media');
        expect(url.queryParameters, {
          'work': _work,
          'position': '$index',
          'token': _mediaToken(epoch: index + 1),
        });
        expect(url.userInfo, isEmpty);
        expect(url.fragment, isEmpty);
        expect(url.toString(), isNot(contains('fixture-token')));
        expect(url.toString(), isNot(contains('fixture-public-key')));
        expect(url.toString(), isNot(contains('private-jwt')));
        expect(url.toString(), isNot(contains('untrusted.invalid')));
      }
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/social_api');
      expect(
        requests.where((request) => request.url.path.startsWith('/storage/')),
        isEmpty,
      );

      actor = null;
      rpc = (_, _) async => {
        ..._v2Work(),
        'mediaTokens': [
          {'position': 0, 'token': _mediaToken(viewer: '-')},
        ],
      };
      final guest = (await repository.fetchWork(_work))!;
      expect(
        Uri.parse(guest.imageUrls.single).queryParameters['token'],
        _mediaToken(viewer: '-'),
      );
      expect(requests, hasLength(2));
    },
  );

  test(
    'restricted owner albums preserve healthy management rows without any image request',
    () async {
      rpc = (action, payload) async {
        expect(action, 'ownWorksPage');
        return {
          'items': [
            {..._v2Work(), 'kind': 'album', 'author': _profile(_a)},
            {
              ..._v2Work(count: 0),
              'id': _b,
              'kind': 'album',
              'author': _profile(_a),
              'status': 'private',
              'isRestricted': true,
              'imageUrls': ['https://untrusted.invalid/old-private-image'],
            },
          ],
          'hasMore': false,
          'nextOffset': 2,
        };
      };
      final page = await repository.fetchOwnWorksPage();
      expect(page.items, hasLength(2));
      expect(page.items.first.isRestricted, isFalse);
      expect(page.items.first.imageUrls, hasLength(1));
      expect(page.items.last.id, _b);
      expect(page.items.last.isRestricted, isTrue);
      expect(page.items.last.imageUrls, isEmpty);
      expect(page.items.last.status, 'private');
      expect(page.nextOffset, 2);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/rest/v1/rpc/social_api');
    },
  );

  test(
    'restricted metadata is accepted only for its authenticated owner',
    () async {
      final raw = {
        ..._v2Work(count: 0),
        'author': _profile(_a),
        'status': 'private',
        'isRestricted': true,
      };
      rpc = (_, _) async => raw;
      for (final viewer in [_b, null]) {
        actor = viewer;
        await expectLater(repository.fetchWork(_work), throwsFormatException);
      }
      actor = _a;
      expect((await repository.fetchWork(_work))!.isRestricted, isTrue);
      expect(requests, hasLength(3));
    },
  );

  test(
    'restriction flags never excuse a missing or mismatched media capability',
    () async {
      for (final restricted in [null, false, true]) {
        rpc = (_, _) async => {
          ..._v2Work(),
          'author': _profile(_a),
          if (restricted != null) 'isRestricted': restricted,
          'mediaTokens': <dynamic>[],
        };
        await expectLater(repository.fetchWork(_work), throwsFormatException);
      }
      rpc = (_, _) async => {
        ..._v2Work(count: 0),
        'author': _profile(_a),
        'isRestricted': true,
        'mediaTokens': [
          {'position': 0, 'token': _mediaToken()},
        ],
      };
      await expectLater(repository.fetchWork(_work), throwsFormatException);
      expect(requests, hasLength(4));
      expect(
        requests.every(
          (request) => request.url.path.endsWith('/rpc/social_api'),
        ),
        isTrue,
      );
    },
  );

  test(
    'v2 malformed capabilities and mismatched positions fail closed',
    () async {
      final invalid = <Map<String, dynamic>>[
        for (final token in [
          'https://untrusted.invalid/photo.png',
          'fixture-token',
          '${_mediaToken()}&access_token=private-jwt',
          'v1.1793174460.1.$_a.short-signature',
        ])
          {
            'mediaTokens': [
              {'position': 0, 'token': token},
            ],
          },
        {
          'mediaTokens': [
            {'position': 1, 'token': _mediaToken()},
          ],
        },
        {
          'mediaTokens': [
            {'position': '0', 'token': _mediaToken()},
          ],
        },
        {'mediaTokens': <dynamic>[]},
        {'mediaTokens': 'not-a-list'},
        {'id': 'https://untrusted.invalid/work'},
      ];
      for (final change in invalid) {
        rpc = (_, _) async => {..._v2Work(), ...change};
        await expectLater(repository.fetchWork(_work), throwsFormatException);
      }
      rpc = (_, _) async => _v2Work(count: 21);
      await expectLater(repository.fetchWork(_work), throwsFormatException);
      expect(requests, hasLength(invalid.length + 1));
      expect(
        requests.every(
          (request) => request.url.path.endsWith('/rpc/social_api'),
        ),
        isTrue,
      );
    },
  );

  test(
    'reports retain retry identity, moderation CAS and paging metadata',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      rpc = (action, payload) async {
        calls.add((action, payload));
        if (action == 'ownReportsPage' || action == 'adminReportsPage') {
          return {
            'items': [_reportJson()],
            'hasMore': true,
            'nextOffset': 24,
          };
        }
        if (action == 'resolveReport') {
          return {
            ..._reportJson(status: 'hidden', revision: 4),
            'resolvedAt': '2026-10-28T01:00:00Z',
            'resolutionNote': '검토 완료',
            'targetPreview': {'body': '공개 댓글', 'author': _profile(_b)},
          };
        }
        return _reportJson();
      };
      for (var retry = 0; retry < 2; retry++) {
        final report = await repository.reportContent(
          targetKind: 'comment',
          targetId: _b,
          reason: 'privacy',
          details: '  사진에 개인정보가 있어요  ',
          requestId: _work,
        );
        expect(report.targetWorkId, _work);
        expect(report.resolutionNote, isNull);
        expect(report.targetPreview, isNull);
      }
      expect(calls[0].$1, 'reportContent');
      expect(calls[0].$1, calls[1].$1);
      expect(calls[0].$2, calls[1].$2);
      expect(calls.first.$2, {
        'targetKind': 'comment',
        'targetId': _b,
        'reason': 'privacy',
        'details': '사진에 개인정보가 있어요',
        'requestId': _work,
      });
      final own = await repository.fetchOwnReportsPage(offset: 12);
      final admin = await repository.fetchAdminReportsPage(
        status: 'dismissed',
        offset: 12,
        limit: 6,
      );
      expect(calls[2].$1, 'ownReportsPage');
      expect(calls[2].$2, {'offset': 12, 'limit': 12});
      expect(calls[3].$1, 'adminReportsPage');
      expect(calls[3].$2, {'status': 'dismissed', 'offset': 12, 'limit': 6});
      expect(own.hasMore, isTrue);
      expect(own.nextOffset, 24);
      expect(admin.items.single.id, _work);
      final resolved = await repository.resolveReport(
        id: _work,
        decision: 'hide',
        expectedRevision: 3,
        note: '  검토 완료  ',
      );
      expect(calls.last.$1, 'resolveReport');
      expect(calls.last.$2, {
        'id': _work,
        'decision': 'hide',
        'expectedRevision': 3,
        'note': '검토 완료',
      });
      expect(resolved.revision, 4);
      expect(resolved.status, 'hidden');
      expect(resolved.resolvedAt, DateTime.utc(2026, 10, 28, 1));
      expect(resolved.targetPreview!['body'], '공개 댓글');
    },
  );

  test(
    'month cover and own record use owner RPCs without public source signing',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      rpc = (action, payload) async {
        calls.add((action, payload));
        if (action == 'ownMomentRecord') {
          return {
            'id': _b,
            'record_date': '2026-10-28',
            'caption': '원본 기록',
            'revision': 7,
            'photos': [
              {
                'id': _work,
                'path': '$_a/private-original.jpg',
                'width': 1200,
                'height': 1600,
              },
            ],
          };
        }
        return {'month': '2026-10-01', 'selectedWorkId': payload['workId']};
      };
      await repository.setMomentMonthCover(DateTime(2026, 10, 28), _work);
      await repository.setMomentMonthCover(DateTime.utc(2026, 10, 1), null);
      final record = (await repository.fetchOwnMomentRecord(_work))!;
      expect(calls.map((call) => call.$1), [
        'setMomentMonthCover',
        'setMomentMonthCover',
        'ownMomentRecord',
      ]);
      expect(calls.map((call) => call.$2), [
        {'month': '2026-10-01', 'workId': _work},
        {'month': '2026-10-01', 'workId': null},
        {'workId': _work},
      ]);
      expect(record.id, _b);
      expect(record.revision, 7);
      expect(record.recordDate, DateTime.utc(2026, 10, 28));
      expect(record.photos.single.path, '$_a/private-original.jpg');
      expect(record.photos.single.url, isEmpty);
      expect(requests, hasLength(3));
      rpc = (_, _) async => null;
      expect(await repository.fetchOwnMomentRecord(_work), isNull);
    },
  );

  test(
    'safety and private record APIs reject guests before transport',
    () async {
      actor = null;
      final operations = <Future<dynamic> Function()>[
        () => repository.reportContent(
          targetKind: 'work',
          targetId: _work,
          reason: 'privacy',
          requestId: _b,
        ),
        () => repository.fetchOwnReportsPage(),
        () => repository.fetchAdminReportsPage(),
        () => repository.resolveReport(
          id: _work,
          decision: 'dismiss',
          expectedRevision: 1,
        ),
        () => repository.fetchOwnMomentRecord(_work),
        () => repository.setMomentMonthCover(DateTime.utc(2026, 10), _work),
      ];
      for (final operation in operations) {
        await expectLater(operation(), throwsStateError);
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'safety and own record replies are discarded after an account change',
    () async {
      final operations = <Future<dynamic> Function()>[
        () => repository.reportContent(
          targetKind: 'work',
          targetId: _work,
          reason: 'privacy',
          requestId: _b,
        ),
        () => repository.fetchOwnReportsPage(),
        () => repository.fetchAdminReportsPage(),
        () => repository.resolveReport(
          id: _work,
          decision: 'dismiss',
          expectedRevision: 1,
        ),
        () => repository.fetchOwnMomentRecord(_work),
        () => repository.setMomentMonthCover(DateTime.utc(2026, 10), _work),
      ];
      for (final operation in operations) {
        actor = _a;
        final started = Completer<void>();
        final response = Completer<dynamic>();
        rpc = (_, _) {
          started.complete();
          return response.future;
        };
        final result = operation();
        await started.future;
        final rejected = expectLater(result, throwsStateError);
        actor = _b;
        response.complete(null);
        await rejected;
      }
      expect(requests, hasLength(operations.length));
    },
  );

  test(
    'feed keyset requests and first-page responses preserve server cursors',
    () async {
      const cursor = {'publishedAt': '2026-10-28T00:00:00Z', 'id': _work};
      const next = {'publishedAt': '2026-10-27T00:00:00Z', 'id': _b};
      final calls = <Map<String, dynamic>>[];
      rpc = (action, payload) async {
        expect(action, 'feed');
        calls.add(payload);
        return {
          'items': [_v2Work()],
          'hasMore': true,
          'nextOffset': 24,
          'nextCursor': next,
        };
      };
      final first = await repository.fetchFeedPage(
        const SocialFeedQuery(following: true, topic: '일상'),
      );
      final page = await repository.fetchFeedPage(
        const SocialFeedQuery(
          following: true,
          topic: '일상',
          offset: 24,
          limit: 6,
          cursor: cursor,
        ),
      );
      expect(calls.first, {
        'following': true,
        'topic': '일상',
        'offset': 0,
        'limit': 12,
      });
      expect(calls.last, {
        'following': true,
        'topic': '일상',
        'offset': 0,
        'limit': 6,
        'cursor': cursor,
      });
      expect(first.nextCursor, next);
      expect(page.nextCursor, next);
      expect(page.nextOffset, 24);
      expect(() => page.nextCursor!['id'] = _a, throwsUnsupportedError);
    },
  );

  test(
    'month summary and detail retain distinct keyset payloads and next cursors',
    () async {
      actor = _b;
      const monthCursor = {'month': '2026-11-01'};
      const detailCursor = {'recordDate': '2026-10-28', 'id': _work};
      const nextMonth = {'month': '2026-10-01'};
      const nextDetail = {'recordDate': '2026-10-27', 'id': _b};
      rpc = (action, payload) async {
        if (action == 'profileMomentMonthsPage') {
          expect(payload, {
            'userId': _b,
            'offset': 0,
            'limit': 6,
            'cursor': monthCursor,
          });
          return {
            'items': [
              {
                'month': '2026-10-01',
                'recordCount': 31,
                'cover': _v2Work(),
                'selectedWorkId': _work,
              },
            ],
            'hasMore': true,
            'nextOffset': 6,
            'nextCursor': nextMonth,
          };
        }
        expect(action, 'profileMomentMonthPage');
        expect(payload, {
          'userId': _b,
          'month': '2026-10-01',
          'offset': 0,
          'limit': 6,
          'cursor': detailCursor,
        });
        return {
          'items': [_v2Work()],
          'hasMore': true,
          'nextOffset': 12,
          'nextCursor': nextDetail,
        };
      };
      final months = await repository.fetchProfileMomentMonthsPage(
        _b,
        cursor: monthCursor,
      );
      final details = await repository.fetchProfileMomentMonthPage(
        _b,
        DateTime(2026, 10, 28),
        limit: 6,
        cursor: detailCursor,
      );
      expect(months.items.single.recordCount, 31);
      expect(months.items.single.selectedWorkId, _work);
      expect(months.nextCursor, nextMonth);
      expect(details.nextCursor, nextDetail);
      expect(details.nextOffset, 12);
      expect(
        () => months.nextCursor!['month'] = '2026-09-01',
        throwsUnsupportedError,
      );
      expect(() => details.nextCursor!['id'] = _a, throwsUnsupportedError);
    },
  );

  test(
    'monthly covers use complete server counts and hydrate only public snapshots',
    () async {
      rpc = (action, payload) async {
        expect(action, 'profileMomentMonthsPage');
        expect(payload, {'userId': _b, 'offset': 6, 'limit': 6});
        return {
          'items': [
            {
              'month': '2026-10-01',
              'recordCount': 31,
              'cover': {
                'id': _work,
                'kind': 'moment',
                'author': _profile(_b),
                'title': '10월의 기록',
                'recordDate': '2026-10-28',
                'createdAt': '2026-10-28T00:00:00Z',
                'imagePaths': ['$_b/$_work/0.png'],
              },
            },
          ],
          'hasMore': true,
          'nextOffset': 12,
        };
      };
      final result = await repository.fetchProfileMomentMonthsPage(
        _b,
        offset: 6,
      );
      expect(result.items.single.recordCount, 31);
      expect(result.items.single.month, DateTime.utc(2026, 10));
      expect(
        result.items.single.cover.imageUrls.single,
        contains('/social-snapshots/'),
      );
      expect(result.hasMore, isTrue);
      expect(result.nextOffset, 12);
    },
  );

  test(
    'monthly covers reject a private, mismatched-month or different-author cover',
    () async {
      for (final change in [
        {'status': 'private'},
        {'recordDate': '2026-09-30'},
        {'author': _profile(_a)},
      ]) {
        rpc = (_, _) async => {
          'items': [
            {
              'month': '2026-10-01',
              'recordCount': 4,
              'cover': {
                'id': _work,
                'kind': 'moment',
                'author': _profile(_b),
                'title': '월간 기록',
                'recordDate': '2026-10-28',
                'createdAt': '2026-10-28T00:00:00Z',
                ...change,
              },
            },
          ],
          'hasMore': false,
          'nextOffset': 1,
        };
        await expectLater(
          repository.fetchProfileMomentMonthsPage(_b),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'monthly detail queries and cache identity normalize calendar dates',
    () async {
      rpc = (action, payload) async {
        expect(action, 'profileMomentMonthPage');
        expect(payload, {
          'userId': _b,
          'month': '2026-10-01',
          'offset': 12,
          'limit': 12,
        });
        return {'items': [], 'hasMore': false, 'nextOffset': 12};
      };
      await repository.fetchProfileMomentMonthPage(
        _b,
        DateTime(2026, 10, 28),
        offset: 12,
      );
      expect(
        SocialMomentMonthQuery(_b, DateTime(2026, 10, 28)),
        SocialMomentMonthQuery(_b, DateTime.utc(2026, 10)),
      );
      expect(
        SocialMomentMonthQuery(_b, DateTime.utc(2025, 10)),
        isNot(SocialMomentMonthQuery(_b, DateTime.utc(2026, 10))),
      );
    },
  );

  test(
    'moment publication sends only explicit record/photo consent and revision',
    () async {
      rpc = (action, payload) async {
        expect(action, 'beginMomentPublication');
        expect(payload, {
          'recordId': _work,
          'photoId': _b,
          'expectedRevision': 3,
          'requestId': _a,
        });
        return {
          'id': _work,
          'pageIndexes': [0],
          'status': 'draft',
          'publicationRevision': 8,
        };
      };
      final draft = await repository.beginMomentPublication(
        recordId: _work,
        photoId: _b,
        expectedRevision: 3,
        requestId: _a,
      );
      expect(draft.publicationRevision, 8);
      expect(draft.pageIndexes, [0]);
      actor = null;
      await expectLater(
        repository.beginMomentPublication(
          recordId: _work,
          photoId: _b,
          expectedRevision: 3,
          requestId: _a,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'moment visibility requires its consent revision and preserves ordinary visibility contract',
    () async {
      rpc = (action, payload) async {
        expect(action, 'visibility');
        expect(payload, {
          'id': _work,
          'published': false,
          'expectedPublicationRevision': 8,
        });
        return true;
      };
      await repository.setMomentPublicationVisibility(
        _work,
        false,
        expectedPublicationRevision: 8,
      );
      rpc = (action, payload) async {
        expect(payload, {'id': _work, 'published': false});
        return true;
      };
      await repository.setWorkVisibility(_work, false);
    },
  );

  test('public moment collections use a separate paginated endpoint', () async {
    rpc = (action, payload) async {
      expect(action, 'profileMomentsPage');
      expect(payload, {'userId': _b, 'offset': 12, 'limit': 12});
      return {'items': [], 'hasMore': false, 'nextOffset': 12};
    };
    final page = await repository.fetchProfileMomentsPage(_b, offset: 12);
    expect(page.items, isEmpty);
    expect(page.nextOffset, 12);
  });

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
  test(
    'comment replies retain their parent on retry and hydrate context',
    () async {
      rpc = (action, payload) async {
        expect(action, 'addComment');
        expect(payload['parentCommentId'], _work);
        return {
          'id': payload['requestId'],
          'body': payload['body'],
          'author': _profile(_a),
          'createdAt': '2026-10-25T00:00:00Z',
          'parentCommentId': _work,
          'rootCommentId': _work,
          'parentAuthor': _profile(_b),
          'mentions': [_profile(_b)],
        };
      };
      for (var attempt = 0; attempt < 2; attempt++) {
        final comment = await repository.addComment(
          _work,
          '  @public.name 함께 본 기록  ',
          requestId: _b,
          parentCommentId: _work,
        );
        expect(comment.isReply, isTrue);
        expect(comment.rootCommentId, _work);
        expect(comment.parentAuthor?.userId, _b);
        expect(comment.mentions.single.userId, _b);
      }
      expect(
        (jsonDecode(requests.first.body) as Map)['p_payload'],
        (jsonDecode(requests.last.body) as Map)['p_payload'],
      );
    },
  );
  test('legacy comments and deleted parents keep safe optional defaults', () {
    final legacy = {
      'id': _work,
      'body': '기록',
      'author': _profile(_a),
      'createdAt': '2026-10-25T00:00:00Z',
    };
    final comment = SocialComment.fromJson(legacy);
    expect(comment.isReply, isFalse);
    expect(comment.mentions, isEmpty);
    final reply = SocialComment.fromJson({
      ...legacy,
      'parentCommentId': _b,
      'rootCommentId': _b,
      'parentAuthor': null,
      'mentions': [],
    });
    expect(reply.isReply, isTrue);
    expect(reply.parentAuthor, isNull);
    expect(reply.rootCommentId, _b);
  });
  test(
    'translated comment failures retain a machine-readable error code',
    () async {
      rpc = (_, _) async => throw const PostgrestException(
        message: 'social_comment_parent_unavailable',
      );
      await expectLater(
        repository.addComment(_work, '답글', parentCommentId: _b),
        throwsA(
          isA<SocialActionException>()
              .having(
                (error) => error.code,
                'code',
                'social_comment_parent_unavailable',
              )
              .having((error) => error.message, 'message', contains('답글')),
        ),
      );
      expect(const SocialActionException('기존 오류').code, isNull);
    },
  );
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

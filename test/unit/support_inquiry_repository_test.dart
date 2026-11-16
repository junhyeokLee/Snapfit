import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/domain/support_inquiry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

class _Auth extends Mock implements GoTrueClient {}

class _Tokens extends Mock implements TokenStorage {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-key',
        httpClient: transport,
        accessToken: () async => 'fixture-token',
      );

  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-11-12T00:00:00Z',
);

Map<String, Object> _row(
  int id, {
  String owner = _a,
  String category = 'GENERAL',
  String status = 'OPEN',
}) => {
  'id': id,
  'user_id': owner,
  'category': category,
  'subject': '사진 편집 문의 $id',
  'message': '프레임에 넣은 사진이 적용되지 않아요.',
  'status': status,
  'created_at': '2026-11-12T01:02:03+00:00',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? actor;
  late _Auth auth;
  late _Tokens tokens;
  late _Client client;
  late StreamController<AuthState> events;
  late SupportInquiryRepository repository;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  void change(String? next) {
    actor = next;
    events.add(
      AuthState(
        next == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        next == null
            ? null
            : Session(
                accessToken: 'fixture-token',
                tokenType: 'bearer',
                user: _user(next),
              ),
      ),
    );
  }

  setUp(() {
    actor = _a;
    events = StreamController<AuthState>.broadcast(sync: true);
    auth = _Auth();
    tokens = _Tokens();
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => tokens.getResolvedUserId()).thenAnswer((_) async => actor);
    requests = [];
    respond = (_) async => response([_row(4)]);
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        final result = await respond(request);
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    );
    repository = SupportInquiryRepository(
      tokenStorage: tokens,
      supabase: client,
    );
  });

  tearDown(() async {
    await events.close();
    await client.dispose();
  });

  test(
    'own history requests only customer fields with a stable id cursor',
    () async {
      final page = await repository.fetchMyInquiries(ownerId: _a, beforeId: 8);
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/support_inquiries');
      expect(
        request.url.queryParameters['select'],
        'id,user_id,category,subject,message,status,created_at',
      );
      expect(request.url.queryParameters['user_id'], 'eq.$_a');
      expect(request.url.queryParameters['id'], 'lt.8');
      expect(request.url.queryParameters['order'], 'id.desc.nullslast');
      expect(request.url.queryParameters['limit'], '21');
      expect(page.items.single.id, 4);
      expect(page.items.single.message, '프레임에 넣은 사진이 적용되지 않아요.');
      expect(page.items.single.createdAt, DateTime.utc(2026, 11, 12, 1, 2, 3));
      expect(page.hasMore, isFalse);
      expect(page.nextBeforeId, isNull);
      expect(() => page.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'one extra row signals more history and never consumes its cursor',
    () async {
      respond = (_) async => response([_row(8), _row(7), _row(6)]);
      final page = await repository.fetchMyInquiries(ownerId: _a, limit: 2);
      expect(page.items.map((item) => item.id), [8, 7]);
      expect(page.hasMore, isTrue);
      expect(page.nextBeforeId, 7);
      expect(requests.single.url.queryParameters['limit'], '3');
    },
  );

  test('confirmed empty history is different from a failed request', () async {
    respond = (_) async => response([]);
    final empty = await repository.fetchMyInquiries(ownerId: _a);
    expect(empty.items, isEmpty);
    expect(empty.hasMore, isFalse);
    respond = (_) async => response({'message': 'temporary outage'}, 503);
    await expectLater(
      repository.fetchMyInquiries(ownerId: _a),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'a returned foreign row is rejected instead of exposed or silently empty',
    () async {
      respond = (_) async => response([_row(4, owner: _b)]);
      await expectLater(
        repository.fetchMyInquiries(ownerId: _a),
        throwsStateError,
      );
    },
  );

  test(
    'guests and mismatched SDK or resolved owners start no private read',
    () async {
      await expectLater(
        repository.fetchMyInquiries(ownerId: _b),
        throwsStateError,
      );
      when(() => tokens.getResolvedUserId()).thenAnswer((_) async => _b);
      await expectLater(
        repository.fetchMyInquiries(ownerId: _a),
        throwsStateError,
      );
      change(null);
      await expectLater(
        repository.fetchMyInquiries(ownerId: _a),
        throwsStateError,
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'owner changes while resolving stored identity start no request',
    () async {
      final pending = Completer<String?>();
      when(() => tokens.getResolvedUserId()).thenAnswer((_) => pending.future);
      final read = repository.fetchMyInquiries(ownerId: _a);
      await Future<void>.delayed(Duration.zero);
      change(_b);
      change(_a);
      final failure = expectLater(read, throwsStateError);
      pending.complete(_a);
      await failure;
      expect(requests, isEmpty);
    },
  );

  test('late own history is discarded after account A B A', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final read = repository.fetchMyInquiries(ownerId: _a);
    await Future<void>.delayed(Duration.zero);
    expect(requests.length, 1);
    change(_b);
    change(_a);
    final failure = expectLater(read, throwsStateError);
    pending.complete(response([_row(4)]));
    await failure;
  });

  test('resolved owner is checked again after the response', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final read = repository.fetchMyInquiries(ownerId: _a);
    await Future<void>.delayed(Duration.zero);
    when(() => tokens.getResolvedUserId()).thenAnswer((_) async => _b);
    final failure = expectLater(read, throwsStateError);
    pending.complete(response([_row(4)]));
    await failure;
  });

  for (final rows in [
    [_row(4), _row(4)],
    [_row(4), _row(5)],
    [_row(8)],
    [_row(9)],
  ]) {
    test(
      'invalid ordering or a nonadvancing cursor is rejected: ${rows.map((row) => row['id']).toList()}',
      () async {
        respond = (_) async => response(rows);
        await expectLater(
          repository.fetchMyInquiries(ownerId: _a, beforeId: 8),
          throwsStateError,
        );
      },
    );
  }

  test(
    'malformed server records fail instead of becoming plausible history',
    () async {
      respond = (_) async => response([
        {..._row(4), 'created_at': 'not-a-date'},
      ]);
      await expectLater(
        repository.fetchMyInquiries(ownerId: _a),
        throwsFormatException,
      );
      respond = (_) async => response([_row(0)]);
      await expectLater(
        repository.fetchMyInquiries(ownerId: _a),
        throwsFormatException,
      );
    },
  );

  test('an auth stream error invalidates a pending private read', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final read = repository.fetchMyInquiries(ownerId: _a);
    await Future<void>.delayed(Duration.zero);
    events.addError(StateError('session observation failed'));
    final failure = expectLater(read, throwsStateError);
    pending.complete(response([_row(4)]));
    await failure;
  });

  for (final input in [(0, null), (51, null), (20, 0), (20, -1)]) {
    test('invalid history pagination starts no request: $input', () async {
      await expectLater(
        repository.fetchMyInquiries(
          ownerId: _a,
          limit: input.$1,
          beforeId: input.$2,
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    });
  }

  test(
    'creation keeps trimmed customer content and the existing void contract',
    () async {
      respond = (_) async => response([], 201);
      await repository.createInquiry(
        category: ' BUG ',
        subject: '  사진 문의  ',
        message: '  내용입니다.  ',
      );
      expect(requests.single.method, 'POST');
      expect(jsonDecode(requests.single.body), {
        'user_id': _a,
        'category': 'BUG',
        'subject': '사진 문의',
        'message': '내용입니다.',
      });
    },
  );

  test(
    'account deletion inquiries remain visible without claiming an answer',
    () async {
      respond = (_) async =>
          response([_row(4, category: 'ACCOUNT_DELETION', status: 'RESOLVED')]);
      final inquiry = (await repository.fetchMyInquiries(
        ownerId: _a,
      )).items.single;
      expect(inquiry.categoryLabel, '계정 삭제 요청');
      expect(inquiry.statusLabel, '처리 완료');
      expect(inquiry.statusLabel, isNot(contains('답변')));
    },
  );

  test(
    'future server statuses remain explicit instead of appearing completed',
    () {
      final inquiry = SupportInquiry.fromJson(
        _row(4, category: 'NEW_KIND', status: 'PENDING_REVIEW'),
      );
      expect(inquiry.categoryLabel, '기타');
      expect(inquiry.statusLabel, '상태 확인 필요');
    },
  );
}

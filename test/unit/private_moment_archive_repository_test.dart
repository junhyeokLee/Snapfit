import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/moments/data/private_moment_archive_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/private_moment_archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const photoId = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000002';

class _Auth extends Mock implements GoTrueClient {}

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

User user(String owner) => User(
  id: owner,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-30T00:00:00Z',
);
Object summary() => [
  {
    'month': '2026-10-01',
    'recordCount': 4,
    'photoCount': 7,
    'latestRecordDate': '2026-10-30',
    'coverPhoto': {
      'id': photoId,
      'path': '$a/moments/record/$photoId.jpg',
      'width': 1600,
      'height': 1200,
    },
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? actor;
  late StreamController<AuthState> authEvents;
  late _Auth auth;
  late _Client client;
  late SupabasePrivateMomentArchiveRepository repository;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  void change(String? owner) {
    actor = owner;
    authEvents.add(
      AuthState(
        owner == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        owner == null
            ? null
            : Session(
                accessToken: 'fixture-token',
                tokenType: 'bearer',
                user: user(owner),
              ),
      ),
    );
  }

  setUp(() {
    actor = a;
    requests = [];
    authEvents = StreamController<AuthState>.broadcast(sync: true);
    auth = _Auth();
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : user(actor!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents.stream);
    respond = (_) async => response(summary());
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
    repository = SupabasePrivateMomentArchiveRepository(client);
  });
  tearDown(() async {
    repository.dispose();
    await authEvents.close();
    await client.dispose();
  });

  test(
    'month cursor is date-only and owner is never sent as a server selector',
    () async {
      final records = await repository.listMonths(
        ownerId: a,
        beforeMonth: DateTime(2026, 11, 19),
        limit: 6,
      );
      expect(requests.single.url.path, '/rest/v1/rpc/get_my_moment_months');
      expect(jsonDecode(requests.single.body), {
        'p_before_month': '2026-11-01',
        'p_limit': 6,
      });
      expect(records.single.month, DateTime.utc(2026, 10));
      expect(records.single.photoCount, 7);
      expect(
        records.single.coverPhoto!.storageUri,
        'supabase://album-assets/$a/moments/record/$photoId.jpg',
      );
      expect(() => records.clear(), throwsUnsupportedError);
    },
  );

  test('guest or mismatched owner starts no private network request', () async {
    await expectLater(
      repository.listMonths(ownerId: b),
      throwsA(isA<MomentException>()),
    );
    change(null);
    await expectLater(
      repository.listMonths(ownerId: a),
      throwsA(isA<MomentException>()),
    );
    expect(requests, isEmpty);
  });

  test('late month data is rejected after A to B to A', () async {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final read = repository.listMonths(ownerId: a);
    await Future<void>.delayed(Duration.zero);
    change(b);
    change(a);
    pending.complete(response(summary()));
    await expectLater(read, throwsA(isA<MomentException>()));
    expect(repository.sessionRevision, 2);
  });

  test(
    'offline auth-stream errors invalidate old reads without an unhandled exception',
    () async {
      final pending = Completer<http.Response>();
      respond = (_) => pending.future;
      final revisions = <int>[];
      final subscription = repository.sessionChanges.listen(revisions.add);
      final read = repository.listMonths(ownerId: a);
      await Future<void>.delayed(Duration.zero);
      authEvents.addError(StateError('offline refresh'), StackTrace.current);
      pending.complete(response(summary()));
      await expectLater(read, throwsA(isA<MomentException>()));
      expect(revisions, [1]);
      await subscription.cancel();
    },
  );

  test(
    'weekly selection writes only that week and preserves caller data',
    () async {
      respond = (_) async => response([photoId]);
      final selection = [photoId];
      await repository.saveWeeklyPhotoChoices(
        ownerId: a,
        weekStart: DateTime.utc(2026, 10, 26),
        photoIds: selection,
      );
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/save_moment_week_photo_choices',
      );
      expect(jsonDecode(requests.single.body), {
        'p_week_start': '2026-10-26',
        'p_photo_ids': [photoId],
      });
      expect(selection, [photoId]);
    },
  );

  test(
    'invalid duplicate and excessive choices never reach the server',
    () async {
      for (final values in [
        [photoId, photoId],
        ['a', 'b', 'c', 'd'],
      ]) {
        await expectLater(
          repository.saveWeeklyPhotoChoices(
            ownerId: a,
            weekStart: DateTime.utc(2026, 10, 26),
            photoIds: values,
          ),
          throwsA(isA<MomentException>()),
        );
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'clearing a week is explicit and reads use separate week and month endpoints',
    () async {
      respond = (_) async => response(<String>[]);
      await repository.saveWeeklyPhotoChoices(
        ownerId: a,
        weekStart: DateTime.utc(2026, 10, 26),
        photoIds: [],
      );
      expect(jsonDecode(requests.last.body)['p_photo_ids'], isEmpty);
      expect(
        await repository.weeklyPhotoChoices(
          ownerId: a,
          weekStart: DateTime.utc(2026, 10, 26),
        ),
        isEmpty,
      );
      expect(
        requests.last.url.path,
        '/rest/v1/rpc/get_moment_week_photo_choices',
      );
      expect(
        await repository.monthlyPhotoChoices(
          ownerId: a,
          month: DateTime.utc(2026, 11, 17),
        ),
        isEmpty,
      );
      expect(
        requests.last.url.path,
        '/rest/v1/rpc/get_moment_month_photo_choices',
      );
      expect(jsonDecode(requests.last.body), {'p_month': '2026-11-01'});
    },
  );

  test(
    'a failed request can retry and a disposed repository cannot expose a late result',
    () async {
      var attempt = 0;
      respond = (_) async => ++attempt == 1
          ? response({'code': 'XX000', 'message': 'temporary'}, 500)
          : response(summary());
      await expectLater(
        repository.listMonths(ownerId: a),
        throwsA(isA<MomentException>()),
      );
      expect((await repository.listMonths(ownerId: a)).single.recordCount, 4);
      final pending = Completer<http.Response>();
      respond = (_) => pending.future;
      final read = repository.listMonths(ownerId: a);
      await Future<void>.delayed(Duration.zero);
      repository.dispose();
      pending.complete(response(summary()));
      await expectLater(read, throwsA(isA<MomentException>()));
    },
  );

  test('query keys isolate owners while normalizing month calendar values', () {
    expect(
      PrivateMomentMonthsQuery(a, beforeMonth: DateTime(2026, 10, 17)),
      PrivateMomentMonthsQuery(a, beforeMonth: DateTime.utc(2026, 10)),
    );
    expect(
      MomentPhotoChoicesQuery(a, DateTime(2026, 10, 19)),
      MomentPhotoChoicesQuery(a, DateTime.utc(2026, 10)),
    );
    expect(
      MomentWeeklyChoicesQuery(a, DateTime(2026, 10, 26)),
      MomentWeeklyChoicesQuery(a, DateTime.utc(2026, 10, 26)),
    );
    expect(
      MomentPhotoChoicesQuery(a, DateTime.utc(2026, 10)),
      isNot(MomentPhotoChoicesQuery(b, DateTime.utc(2026, 10))),
    );
  });
}

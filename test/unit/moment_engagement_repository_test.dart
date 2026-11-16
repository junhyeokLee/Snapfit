import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

void main() {
  late _Auth auth;
  late _Client client;
  late SupabaseMomentEngagementRepository repository;
  late StreamController<AuthState> events;
  late String? actor;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  User user(String id) => User(
    id: id,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-26T00:00:00Z',
  );
  final value = {
    'hasRecords': true,
    'reminder': {'enabled': false, 'weekday': 7, 'hour': 20, 'minute': 0},
  };
  http.Response response(Object? value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  void change(String? id) {
    actor = id;
    events.add(
      AuthState(
        id == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
        id == null
            ? null
            : Session(
                accessToken: 'fixture-token',
                tokenType: 'bearer',
                user: user(id),
              ),
      ),
    );
  }

  setUp(() {
    actor = 'owner-a';
    auth = _Auth();
    events = StreamController<AuthState>.broadcast(sync: true);
    requests = [];
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : user(actor!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    respond = (_) async => response(value);
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
    repository = SupabaseMomentEngagementRepository(client);
  });
  tearDown(() async {
    repository.dispose();
    await events.close();
    await client.dispose();
  });
  test('signed-out reads and settings writes never reach API', () async {
    change(null);
    await expectLater(repository.load(), throwsA(isA<MomentException>()));
    await expectLater(
      repository.saveReminder(const MomentReminder(enabled: true)),
      throwsA(isA<MomentException>()),
    );
    expect(await repository.recordActivity(MomentActivity.recapViewed), false);
    expect(requests, isEmpty);
  });
  test(
    'preferences start disabled and only saved values reach server',
    () async {
      final loaded = await repository.load();
      expect(loaded.reminder.enabled, false);
      expect(loaded.hasRecords, true);
      await repository.saveReminder(
        const MomentReminder(enabled: true, weekday: 2, hour: 19, minute: 30),
      );
      expect(requests.last.url.path, endsWith('save_moment_reminder'));
      expect(jsonDecode(requests.last.body), {
        'p_enabled': true,
        'p_weekday': 2,
        'p_hour': 19,
        'p_minute': 30,
      });
    },
  );
  test('invalid weekday and resting-hour times fail before network', () async {
    for (final reminder in [
      const MomentReminder(weekday: 0),
      const MomentReminder(weekday: 8),
      const MomentReminder(hour: 7),
      const MomentReminder(hour: 22),
      const MomentReminder(minute: 60),
    ]) {
      await expectLater(
        repository.saveReminder(reminder),
        throwsA(isA<MomentException>()),
      );
    }
    expect(requests, isEmpty);
  });
  test(
    'A to B to A hides previous session preferences and acknowledgement',
    () async {
      for (final save in [false, true]) {
        final pending = Completer<http.Response>();
        respond = (_) => pending.future;
        final result = save
            ? repository.saveReminder(const MomentReminder())
            : repository.load();
        await Future<void>.delayed(Duration.zero);
        change('owner-b');
        change('owner-a');
        pending.complete(response(value));
        await expectLater(result, throwsA(isA<MomentException>()));
      }
    },
  );
  test(
    'measurement contains an enum event, random id and normalized month only',
    () async {
      respond = (_) async => response(true);
      expect(
        await repository.recordActivity(
          MomentActivity.rewardViewed,
          month: DateTime.utc(2026, 10, 26),
        ),
        true,
      );
      final payload = jsonDecode(requests.single.body) as Map;
      expect(payload.keys.toSet(), {'p_event_id', 'p_event', 'p_month'});
      expect(payload['p_event'], 'reward_viewed');
      expect(payload['p_month'], '2026-10-01');
      expect(payload['p_event_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    },
  );
  test(
    'auth refresh errors invalidate pending preferences without signing out and permit a fresh retry',
    () async {
      for (final save in [false, true]) {
        final pending = Completer<http.Response>();
        respond = (_) => pending.future;
        final result = save
            ? repository.saveReminder(const MomentReminder())
            : repository.load();
        final failure = expectLater(result, throwsA(isA<MomentException>()));
        await Future<void>.delayed(Duration.zero);
        events.addError(
          AuthRetryableFetchException(message: 'fixture offline refresh'),
          StackTrace.current,
        );
        pending.complete(response(value));
        await failure;
        expect(actor, 'owner-a');
        expect(client.auth.currentUser?.id, 'owner-a');
        respond = (_) async => response(value);
        expect((await repository.load()).hasRecords, isTrue);
      }
    },
  );
  test(
    'a pending activity stays nonblocking after an auth refresh error',
    () async {
      final pending = Completer<http.Response>();
      respond = (_) => pending.future;
      final result = repository.recordActivity(MomentActivity.recapViewed);
      await Future<void>.delayed(Duration.zero);
      events.addError(
        AuthRetryableFetchException(message: 'fixture offline refresh'),
        StackTrace.current,
      );
      pending.complete(response(true));
      expect(await result, isFalse);
      expect(actor, 'owner-a');
      respond = (_) async => response(true);
      expect(
        await repository.recordActivity(MomentActivity.recapViewed),
        isTrue,
      );
    },
  );
  test('measurement errors do not interrupt the user flow', () async {
    respond = (_) async =>
        response({'message': 'offline', 'code': 'offline'}, 503);
    expect(
      await repository.recordActivity(MomentActivity.monthlyPreviewed),
      false,
    );
    await expectLater(repository.load(), throwsA(isA<MomentException>()));
  });
}

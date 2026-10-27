import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/attendance/data/attendance_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-access-token',
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
  createdAt: '2026-10-26T00:00:00Z',
);

Map<String, dynamic> _status({bool checked = false, bool claimed = false}) => {
  'serverTime': '2026-10-26T03:00:00Z',
  'serverDate': '2026-10-26',
  'timezone': 'Asia/Seoul',
  'nextResetAt': '2026-10-26T15:00:00Z',
  'checkedInToday': checked,
  'currentStreak': checked ? 1 : 0,
  'cycleDay': 1,
  'todayReward': 10,
  'weeklyRewards': [10, 10, 20, 10, 10, 10, 30],
  'month': '2026-10',
  'monthPoints': checked ? 10 : 0,
  'monthAttendanceCount': checked ? 1 : 0,
  'history': [
    if (checked)
      {'date': '2026-10-26', 'points': 10, 'cycleDay': 1, 'streak': 1},
  ],
  'claimed': claimed,
  'awardedPoints': claimed ? 10 : 0,
  'balance': checked ? 110 : 100,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late SupabaseAttendanceRepository repository;
  late StreamController<AuthState> authEvents;
  late String? actor;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  http.Response jsonResponse(
    http.Request request,
    Object value, {
    int code = 200,
  }) => http.Response(
    jsonEncode(value),
    code,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  void emitActor(String? next, [AuthChangeEvent? event]) {
    actor = next;
    authEvents.add(
      AuthState(
        event ??
            (next == null
                ? AuthChangeEvent.signedOut
                : AuthChangeEvent.signedIn),
        next == null
            ? null
            : Session(
                accessToken: 'fixture-access-token',
                tokenType: 'bearer',
                user: _user(next),
              ),
      ),
    );
  }

  setUp(() {
    actor = _a;
    requests = [];
    authEvents = StreamController<AuthState>.broadcast(sync: true);
    auth = _Auth();
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    when(() => auth.onAuthStateChange).thenAnswer((_) => authEvents.stream);
    respond = (request) async => jsonResponse(request, _status());
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = SupabaseAttendanceRepository(client);
  });

  tearDown(() async {
    repository.dispose();
    await authEvents.close();
    await client.dispose();
  });

  test('status uses an authenticated argument-free server RPC', () async {
    final status = await repository.fetchStatus();
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/rpc/get_attendance_status');
    expect(request.url.queryParameters, isEmpty);
    // Supabase serializes absent RPC arguments as JSON null. Neither the
    // account, local date, reward, streak nor balance is supplied by the app.
    expect(jsonDecode(request.body), isNull);
    expect(request.headers['authorization'], 'Bearer fixture-access-token');
    expect(status.serverDate, DateTime.utc(2026, 10, 26));
    expect(status.nextResetAt, DateTime.utc(2026, 10, 26, 15));
    expect(status.balance, 100);
    expect(status.checkedInToday, isFalse);
  });

  test('signed-out status and claim fail before any HTTP call', () async {
    emitActor(null);
    await expectLater(repository.fetchStatus(), throwsStateError);
    await expectLater(repository.claim(), throwsStateError);
    expect(requests, isEmpty);
  });

  test(
    'first credit and repeated claim retain distinct authoritative results',
    () async {
      var claimCalls = 0;
      respond = (request) async {
        expect(request.url.path, '/rest/v1/rpc/claim_daily_attendance');
        expect(jsonDecode(request.body), isNull);
        return jsonResponse(
          request,
          _status(checked: true, claimed: claimCalls++ == 0),
        );
      };
      final earned = await repository.claim();
      final repeated = await repository.claim();
      expect(earned.claimed, isTrue);
      expect(earned.awardedPoints, 10);
      expect(earned.balance, 110);
      expect(repeated.claimed, isFalse);
      expect(repeated.awardedPoints, 0);
      expect(repeated.checkedInToday, isTrue);
      expect(repeated.balance, earned.balance);
      expect(requests, hasLength(2));
    },
  );

  test(
    'a lost claim reply stays uncertain until an explicit safe retry',
    () async {
      var calls = 0;
      respond = (request) async {
        if (calls++ == 0)
          throw http.ClientException('Committed reply was lost');
        return jsonResponse(request, _status(checked: true));
      };
      await expectLater(
        repository.claim(),
        throwsA(isA<http.ClientException>()),
      );
      expect(requests, hasLength(1));
      final confirmed = await repository.claim();
      expect(confirmed.checkedInToday, isTrue);
      expect(confirmed.claimed, isFalse);
      expect(confirmed.awardedPoints, 0);
      expect(confirmed.balance, 110);
      expect(requests, hasLength(2));
    },
  );

  test(
    'permission denial is propagated without a fabricated successful claim',
    () async {
      respond = (request) async => jsonResponse(request, {
        'code': '42501',
        'message': 'attendance_personal_account_required',
      }, code: 403);
      await expectLater(
        repository.claim(),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            '42501',
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'a malformed reward response cannot become a confirmed credit',
    () async {
      respond = (request) async => jsonResponse(
        request,
        _status(checked: true, claimed: true)..['awardedPoints'] = 1000,
      );
      await expectLater(repository.claim(), throwsFormatException);
      expect(requests, hasLength(1));
    },
  );

  test(
    'a fresh status re-reads the server instead of reusing a prior claim balance',
    () async {
      respond = (request) async => jsonResponse(
        request,
        request.url.path.endsWith('claim_daily_attendance')
            ? _status(checked: true, claimed: true)
            : (_status(checked: true)..['balance'] = -40),
      );
      expect((await repository.claim()).balance, 110);
      // Existing purchase refunds can leave a debt. Attendance must retain the
      // server balance rather than replacing it with a locally computed award.
      expect((await repository.fetchStatus()).balance, -40);
      expect(requests, hasLength(2));
    },
  );

  for (final claim in [false, true]) {
    test(
      '${claim ? 'claim' : 'status'} rejects a late A to B to A response',
      () async {
        final started = Completer<void>();
        final response = Completer<http.Response>();
        respond = (request) {
          started.complete();
          return response.future;
        };
        final pending = claim ? repository.claim() : repository.fetchStatus();
        final rejected = expectLater(pending, throwsStateError);
        await started.future;
        emitActor(_b);
        emitActor(_a);
        response.complete(
          jsonResponse(requests.single, _status(checked: true, claimed: claim)),
        );
        await rejected;
        expect(repository.currentUserId, _a);
        expect(requests, hasLength(1));
      },
    );
  }

  test(
    'a late signed-out response is discarded before returning a balance',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      respond = (request) {
        started.complete();
        return response.future;
      };
      final pending = repository.fetchStatus();
      final rejected = expectLater(pending, throwsStateError);
      await started.future;
      emitActor(null);
      response.complete(jsonResponse(requests.single, _status()));
      await rejected;
    },
  );

  test(
    'same-user token refresh does not discard a valid server response',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      respond = (request) {
        started.complete();
        return response.future;
      };
      final pending = repository.fetchStatus();
      await started.future;
      emitActor(_a, AuthChangeEvent.tokenRefreshed);
      response.complete(jsonResponse(requests.single, _status()));
      expect((await pending).balance, 100);
    },
  );

  test(
    'auth changes emit distinct account identities including logout',
    () async {
      final identities = <String?>[];
      final subscription = repository.authChanges.listen(identities.add);
      emitActor(_a);
      emitActor(_a, AuthChangeEvent.tokenRefreshed);
      emitActor(_b);
      emitActor(null);
      emitActor(_a);
      await Future<void>.delayed(Duration.zero);
      expect(identities, [_a, _b, null, _a]);
      await subscription.cancel();
    },
  );

  testWidgets(
    'a stalled claim times out after 15 seconds and a retry can reconcile it',
    (tester) async {
      final response = Completer<http.Response>();
      var calls = 0;
      respond = (request) {
        if (calls++ == 0) return response.future;
        return Future.value(jsonResponse(request, _status(checked: true)));
      };
      final timedOut = expectLater(
        repository.claim(),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      expect(requests, hasLength(1));
      await tester.pump(const Duration(seconds: 15));
      await timedOut;
      response.complete(
        jsonResponse(requests.first, _status(checked: true, claimed: true)),
      );
      await tester.pump();
      final reconciled = repository.claim();
      await tester.pump();
      expect((await reconciled).awardedPoints, 0);
      expect(requests, hasLength(2));
    },
  );
}

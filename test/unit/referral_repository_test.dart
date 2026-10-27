import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/referral/data/referral_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _code = 'ABCD2345XY';

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

Map<String, dynamic> _status({bool redeemed = false, bool claimed = false}) => {
  'ownCode': 'JKMP2345XY',
  'inviterPoints': 100,
  'inviteePoints': 100,
  'registrationWindowDays': 7,
  'rewardLimit': 20,
  'monthlyRewardedCount': 0,
  'remaining': 20,
  'invitedCount': 0,
  'totalEarned': redeemed ? 100 : 0,
  'balance': redeemed ? 600 : 500,
  'canRedeem': !redeemed,
  'redeemed': redeemed,
  'eligibleUntil': '2026-10-30T03:00:00Z',
  'serverTime': '2026-10-26T03:00:00Z',
  'claimed': claimed,
  'awardedPoints': claimed ? 100 : 0,
  'rewardMonth': '2026-10',
  'timezone': 'Asia/Seoul',
  'ineligibleReason': redeemed ? 'already_redeemed' : null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late SupabaseReferralRepository repository;
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
    repository = SupabaseReferralRepository(client);
  });

  tearDown(() async {
    repository.dispose();
    await authEvents.close();
    await client.dispose();
  });

  test(
    'opening the screen fetches status without registering or sending a reward',
    () async {
      final status = await repository.fetchStatus();
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/get_referral_status');
      expect(request.url.queryParameters, isEmpty);
      expect(jsonDecode(request.body), isNull);
      expect(request.headers['authorization'], 'Bearer fixture-access-token');
      expect(status.canRedeem, isTrue);
      expect(status.balance, 500);
    },
  );

  test(
    'registration sends only a normalized friend code to the server',
    () async {
      respond = (request) async =>
          jsonResponse(request, _status(redeemed: true, claimed: true));
      final result = await repository.redeem('  abcd2345xy ');
      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/redeem_referral_code');
      expect(jsonDecode(request.body), {'p_code': _code});
      expect(request.url.queryParameters, isEmpty);
      expect(result.awardedPoints, 100);
      expect(result.balance, 600);
    },
  );

  test(
    'invalid codes fail before HTTP and cannot be coerced into another friend',
    () {
      for (final value in ['', 'ABCD2345X0', 'ABCD2345XYextra', 'ABCD 345XY']) {
        expect(() => repository.redeem(value), throwsFormatException);
      }
      expect(requests, isEmpty);
    },
  );

  test('signed-out status and registration are rejected before HTTP', () async {
    emitActor(null);
    await expectLater(repository.fetchStatus(), throwsStateError);
    await expectLater(repository.redeem(_code), throwsStateError);
    expect(requests, isEmpty);
  });

  test(
    'a repeated registration retains completion without reporting another reward',
    () async {
      var calls = 0;
      respond = (request) async =>
          jsonResponse(request, _status(redeemed: true, claimed: calls++ == 0));
      final first = await repository.redeem(_code);
      final second = await repository.redeem(_code);
      expect(first.claimed, isTrue);
      expect(first.awardedPoints, 100);
      expect(second.claimed, isFalse);
      expect(second.awardedPoints, 0);
      expect(second.redeemed, isTrue);
      expect(second.balance, first.balance);
    },
  );

  test(
    'a lost reply remains uncertain until a deliberate idempotent retry',
    () async {
      var calls = 0;
      respond = (request) async {
        if (calls++ == 0)
          throw http.ClientException('Committed response was lost');
        return jsonResponse(request, _status(redeemed: true));
      };
      await expectLater(
        repository.redeem(_code),
        throwsA(isA<http.ClientException>()),
      );
      expect(requests, hasLength(1));
      final reconciled = await repository.redeem(_code);
      expect(reconciled.redeemed, isTrue);
      expect(reconciled.claimed, isFalse);
      expect(reconciled.awardedPoints, 0);
      expect(reconciled.balance, 600);
      expect(requests, hasLength(2));
    },
  );

  test(
    'server eligibility refusals are propagated without a fabricated balance',
    () async {
      respond = (request) async => jsonResponse(request, {
        'code': 'P0001',
        'message': 'REFERRAL_LIMIT_REACHED',
      }, code: 400);
      await expectLater(
        repository.redeem(_code),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.message,
            'message',
            'REFERRAL_LIMIT_REACHED',
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'malformed server rewards cannot be displayed as a successful registration',
    () async {
      respond = (request) async => jsonResponse(
        request,
        _status(redeemed: true, claimed: true)..['awardedPoints'] = 999,
      );
      await expectLater(repository.redeem(_code), throwsFormatException);
    },
  );

  test(
    'wallet refresh reads the server balance including existing refund debt',
    () async {
      respond = (request) async => jsonResponse(
        request,
        request.url.path.endsWith('redeem_referral_code')
            ? _status(redeemed: true, claimed: true)
            : (_status(redeemed: true)..['balance'] = -40),
      );
      expect((await repository.redeem(_code)).balance, 600);
      expect((await repository.fetchStatus()).balance, -40);
    },
  );

  for (final redeem in [false, true]) {
    test(
      '${redeem ? 'registration' : 'status'} rejects an obsolete A to B to A response',
      () async {
        final started = Completer<void>();
        final reply = Completer<http.Response>();
        respond = (request) {
          started.complete();
          return reply.future;
        };
        final pending = redeem
            ? repository.redeem(_code)
            : repository.fetchStatus();
        final rejected = expectLater(pending, throwsStateError);
        await started.future;
        emitActor(_b);
        emitActor(_a);
        reply.complete(
          jsonResponse(
            requests.single,
            _status(redeemed: true, claimed: redeem),
          ),
        );
        await rejected;
        expect(repository.currentUserId, _a);
      },
    );
  }

  test(
    'a logged-out response is rejected before exposing account points',
    () async {
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      respond = (request) {
        started.complete();
        return reply.future;
      };
      final rejected = expectLater(repository.fetchStatus(), throwsStateError);
      await started.future;
      emitActor(null);
      reply.complete(jsonResponse(requests.single, _status()));
      await rejected;
    },
  );

  test('same-user token refresh preserves a valid status response', () async {
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    respond = (request) {
      started.complete();
      return reply.future;
    };
    final pending = repository.fetchStatus();
    await started.future;
    emitActor(_a, AuthChangeEvent.tokenRefreshed);
    reply.complete(jsonResponse(requests.single, _status()));
    expect((await pending).balance, 500);
  });

  test(
    'identity changes remain distinct across refresh, logout and re-login',
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
    'a stalled registration times out and an explicit retry reconciles payment',
    (tester) async {
      final reply = Completer<http.Response>();
      var calls = 0;
      respond = (request) {
        if (calls++ == 0) return reply.future;
        return Future.value(jsonResponse(request, _status(redeemed: true)));
      };
      final timedOut = expectLater(
        repository.redeem(_code),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      expect(requests, hasLength(1));
      await tester.pump(const Duration(seconds: 15));
      await timedOut;
      reply.complete(
        jsonResponse(requests.first, _status(redeemed: true, claimed: true)),
      );
      await tester.pump();
      final reconciled = repository.redeem(_code);
      await tester.pump();
      expect((await reconciled).awardedPoints, 0);
      expect(requests, hasLength(2));
    },
  );
}

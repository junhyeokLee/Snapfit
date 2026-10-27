import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
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

User _user(String id, {bool admin = true, bool anonymous = false}) => User(
  id: id,
  appMetadata: {'role': admin ? 'admin' : 'user'},
  userMetadata: {'role': 'admin'},
  aud: 'authenticated',
  createdAt: '2026-10-26T00:00:00Z',
  isAnonymous: anonymous,
);

Map<String, dynamic> _snapshot({String owner = _a}) => {
  'userId': owner,
  'serverNow': '2026-10-27T03:00:00Z',
  'campaigns': [
    for (final campaign in defaultHomeNewsCampaigns) campaign.toJson(),
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late SupabaseAdminHomeNewsRepository repository;
  late StreamController<AuthState> events;
  late User? actor;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  http.Response jsonResponse(http.Request request, Object value) =>
      http.Response(
        jsonEncode(value),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  void emitActor(User? next) {
    actor = next;
    events.add(
      AuthState(
        next == null
            ? AuthChangeEvent.signedOut
            : AuthChangeEvent.tokenRefreshed,
        next == null
            ? null
            : Session(
                accessToken: 'fixture-access-token',
                tokenType: 'bearer',
                user: next,
              ),
      ),
    );
  }

  setUp(() {
    actor = _user(_a);
    requests = [];
    events = StreamController<AuthState>.broadcast(sync: true);
    auth = _Auth();
    when(() => auth.currentUser).thenAnswer((_) => actor);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    respond = (request) async => jsonResponse(request, _snapshot());
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = SupabaseAdminHomeNewsRepository(client);
  });

  tearDown(() async {
    repository.dispose();
    await events.close();
    await client.dispose();
  });

  test(
    'admin fetch uses an authenticated owner-verified RPC and all four settings',
    () async {
      final result = await repository.getCampaigns();
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/get_admin_home_news_campaigns',
      );
      expect(
        requests.single.headers['authorization'],
        'Bearer fixture-access-token',
      );
      expect(jsonDecode(requests.single.body), isNull);
      expect(
        result.campaigns.map((item) => item.kind),
        defaultHomeNewsCampaigns.map((item) => item.kind),
      );
      expect(result.serverNow, DateTime.utc(2026, 10, 27, 3));
    },
  );

  test(
    'signed-out, anonymous and user-editable metadata cannot authorize admin RPCs',
    () async {
      for (final next in [
        null,
        _user(_a, admin: false),
        _user(_a, anonymous: true),
      ]) {
        emitActor(next);
        await expectLater(repository.getCampaigns(), throwsStateError);
        await expectLater(
          repository.updateCampaign(defaultHomeNewsCampaigns.first),
          throwsStateError,
        );
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'update sends only known kind, enabled, UTC schedule and order',
    () async {
      await repository.updateCampaign(
        HomeNewsCampaign(
          kind: HomeNewsKind.attendance,
          enabled: false,
          startsAt: DateTime.parse('2026-10-28T09:00:00+09:00'),
          endsAt: DateTime.parse('2026-10-29T18:30:00+09:00'),
          sortOrder: 0,
        ),
      );
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/update_admin_home_news_campaign',
      );
      expect(jsonDecode(requests.single.body), {
        'p_kind': 'attendance',
        'p_enabled': false,
        'p_starts_at': '2026-10-28T00:00:00.000Z',
        'p_ends_at': '2026-10-29T09:30:00.000Z',
        'p_sort_order': 0,
      });
      expect(
        () => repository.updateCampaign(
          HomeNewsCampaign(kind: HomeNewsKind.attendance, sortOrder: 1001),
        ),
        throwsArgumentError,
      );
      expect(
        () => repository.updateCampaign(
          HomeNewsCampaign(
            kind: HomeNewsKind.attendance,
            sortOrder: 0,
            startsAt: DateTime.utc(2026, 10, 29),
            endsAt: DateTime.utc(2026, 10, 28),
          ),
        ),
        throwsArgumentError,
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'a response from a different account or an incomplete campaign set is rejected',
    () async {
      respond = (request) async => jsonResponse(request, _snapshot(owner: _b));
      await expectLater(repository.getCampaigns(), throwsFormatException);
      respond = (request) async =>
          jsonResponse(request, {..._snapshot(), 'campaigns': []});
      await expectLater(repository.getCampaigns(), throwsFormatException);
    },
  );

  test(
    'late A to B to A results and same-owner role revocation are rejected',
    () async {
      final started = Completer<void>();
      final pending = Completer<http.Response>();
      respond = (request) {
        started.complete();
        return pending.future;
      };
      final result = repository.getCampaigns();
      final assertion = expectLater(result, throwsStateError);
      await started.future;
      emitActor(_user(_b));
      emitActor(_user(_a));
      pending.complete(jsonResponse(requests.single, _snapshot()));
      await assertion;

      final startedAgain = Completer<void>();
      final pendingAgain = Completer<http.Response>();
      respond = (request) {
        startedAgain.complete();
        return pendingAgain.future;
      };
      final second = repository.getCampaigns();
      final secondAssertion = expectLater(second, throwsStateError);
      await startedAgain.future;
      emitActor(_user(_a, admin: false));
      emitActor(_user(_a));
      pendingAgain.complete(jsonResponse(requests.last, _snapshot()));
      await secondAssertion;
    },
  );
}

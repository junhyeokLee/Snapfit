import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/home_news/data/home_news_repository.dart';
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

User _user(String id, {bool anonymous = false}) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-26T00:00:00Z',
  isAnonymous: anonymous,
);

Map<String, dynamic> _state({String owner = _a, bool claimed = false}) => {
  'userId': owner,
  'serverNow': '2026-10-27T03:00:00Z',
  'serverDate': '2026-10-27',
  'weekStart': '2026-10-26',
  'timezone': 'Asia/Seoul',
  'dailyCount': claimed ? 1 : 0,
  'weeklyCount': claimed ? 1 : 0,
  'hasAttendanceEver': false,
  'hasReferralReward': false,
  'claimed': claimed,
  'history': [
    if (claimed)
      {
        'id': 'monthly-design:2026-10',
        'kind': 'monthlyDesign',
        'month': '2026-10-01',
        'shownAt': '2026-10-27T03:00:00Z',
        'dismissedAt': null,
        'clickedAt': null,
      },
  ],
};

const _deliveryId = '44444444-4444-4444-8444-444444444444';
const _campaignIds = [
  'monthly-design:2026-10',
  'attendance-benefit:v1',
  'referral-benefit:v1',
  'month-review:2026-10',
];

Map<String, dynamic> _deliveryState({bool claimed = true}) {
  final state = _state(claimed: claimed);
  return {
    ...state,
    'deliveryId': claimed ? _deliveryId : null,
    'allowedCampaignIds': claimed ? _campaignIds : const <String>[],
    'deliveries': [
      if (claimed) {'id': _deliveryId, 'shownAt': '2026-10-27T03:00:00Z'},
    ],
    'history': [
      for (final row in state['history'] as List)
        {...Map<String, dynamic>.from(row as Map), 'deliveryId': _deliveryId},
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Client client;
  late SupabaseHomeNewsRepository repository;
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
        next == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
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
    respond = (request) async => jsonResponse(request, _state());
    client = _Client(
      auth,
      MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    );
    repository = SupabaseHomeNewsRepository(client);
  });

  tearDown(() async {
    repository.dispose();
    await events.close();
    await client.dispose();
  });

  test(
    'exposure state uses owner-verified authenticated argument-free RPC',
    () async {
      final state = await repository.getExposureState();
      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/get_home_news_state');
      expect(request.headers['authorization'], 'Bearer fixture-access-token');
      expect(jsonDecode(request.body), isNull);
      expect(state.serverDate, DateTime.utc(2026, 10, 27));
      expect(state.canAutoShow, isTrue);
    },
  );

  test(
    'signed-out and anonymous accounts make no state, claim or interaction requests',
    () async {
      for (final next in [null, _user(_a, anonymous: true)]) {
        emitActor(next);
        expect(repository.currentUserId, isNull);
        await expectLater(repository.getExposureState(), throwsStateError);
        await expectLater(
          repository.claimExposure('attendance-benefit:v1'),
          throwsStateError,
        );
        await expectLater(
          repository.recordInteraction(
            'attendance-benefit:v1',
            HomeNewsInteraction.dismiss,
          ),
          throwsStateError,
        );
      }
      expect(requests, isEmpty);
    },
  );

  test(
    'claim and interaction send only campaign and action, with no account, clock, points or photos',
    () async {
      respond = (request) async => jsonResponse(request, _state(claimed: true));
      expect(await repository.claimExposure('monthly-design:2026-10'), isTrue);
      expect(requests.last.url.path, '/rest/v1/rpc/claim_home_news_exposure');
      expect(jsonDecode(requests.last.body), {
        'p_campaign_id': 'monthly-design:2026-10',
      });
      await repository.recordInteraction(
        'monthly-design:2026-10',
        HomeNewsInteraction.click,
      );
      expect(
        requests.last.url.path,
        '/rest/v1/rpc/record_home_news_interaction',
      );
      expect(jsonDecode(requests.last.body), {
        'p_campaign_id': 'monthly-design:2026-10',
        'p_interaction': 'click',
      });
      expect(await repository.getHistory(), hasLength(1));
    },
  );

  test(
    'late response is discarded after account switch and after sign-out/sign-in to the same account',
    () async {
      for (final switchBack in [false, true]) {
        emitActor(_user(_a));
        final reply = Completer<http.Response>();
        final started = Completer<http.Request>();
        respond = (request) {
          started.complete(request);
          return reply.future;
        };
        final response = repository.getExposureState();
        final expectation = expectLater(response, throwsStateError);
        final request = await started.future;
        emitActor(null);
        emitActor(_user(switchBack ? _a : _b));
        reply.complete(jsonResponse(request, _state()));
        await expectation;
      }
    },
  );

  test('another owner or an inconsistent claim result is rejected', () async {
    respond = (request) async => jsonResponse(request, _state(owner: _b));
    await expectLater(repository.getExposureState(), throwsFormatException);
    respond = (request) async =>
        jsonResponse(request, {..._state(), 'claimed': true});
    await expectLater(
      repository.claimExposure('monthly-design:2026-10'),
      throwsFormatException,
    );
    respond = (request) async => jsonResponse(request, _state(claimed: true));
    await expectLater(
      repository.claimExposure('referral-benefit:v1'),
      throwsFormatException,
    );
  });

  test(
    'base repository capability dispatches a real four-card delivery RPC in production',
    () async {
      respond = (request) async => jsonResponse(request, _deliveryState());
      final HomeNewsRepository base = repository;
      final delivery = await base.claimDelivery(_campaignIds);
      expect(delivery.claimed, isTrue);
      expect(delivery.deliveryId, _deliveryId);
      expect(delivery.campaignIds, _campaignIds);
      expect(requests.single.url.path, '/rest/v1/rpc/claim_home_news_delivery');
      expect(jsonDecode(requests.single.body), {
        'p_campaign_ids': _campaignIds,
      });
      expect(() => delivery.campaignIds.clear(), throwsUnsupportedError);
    },
  );

  test(
    'swiped cards use an owned delivery view RPC and preserve authoritative rejection',
    () async {
      respond = (request) async => jsonResponse(request, {
        ..._deliveryState(),
        'claimed': false,
        'viewed': true,
      });
      final HomeNewsRepository base = repository;
      expect(
        await base.recordDeliveryView(_deliveryId, _campaignIds[1]),
        isTrue,
      );
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/record_home_news_delivery_view',
      );
      expect(jsonDecode(requests.single.body), {
        'p_delivery_id': _deliveryId,
        'p_campaign_id': _campaignIds[1],
      });
      respond = (request) async =>
          jsonResponse(request, {..._deliveryState(), 'viewed': false});
      expect(
        await base.recordDeliveryView(_deliveryId, _campaignIds[1]),
        isFalse,
      );
    },
  );

  test(
    'delivery inputs and unexpected first/allowed/delivery IDs fail closed',
    () async {
      await expectLater(repository.claimDelivery([]), throwsFormatException);
      await expectLater(
        repository.claimDelivery([_campaignIds.first, _campaignIds.first]),
        throwsFormatException,
      );
      expect(requests, isEmpty);
      for (final invalid in [
        {
          ..._deliveryState(),
          'deliveryId': '55555555-5555-4555-8555-555555555555',
        },
        {
          ..._deliveryState(),
          'allowedCampaignIds': [_campaignIds[1], _campaignIds.first],
        },
        {
          ..._deliveryState(),
          'allowedCampaignIds': [_campaignIds.first, 'unrequested'],
        },
        {
          ..._deliveryState(),
          'allowedCampaignIds': [_campaignIds.first, _campaignIds.first],
        },
        {..._deliveryState(claimed: false), 'deliveryId': _deliveryId},
      ]) {
        respond = (request) async => jsonResponse(request, invalid);
        await expectLater(
          repository.claimDelivery(_campaignIds),
          throwsFormatException,
        );
      }
    },
  );
}

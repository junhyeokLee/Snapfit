import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_fit/features/attendance/data/attendance_repository.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/home_news/data/home_news_repository.dart';
import 'package:snap_fit/features/home_news/domain/home_news.dart';
import 'package:snap_fit/features/referral/data/referral_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';

String _jwt(String owner, String marker) {
  String part(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'aud': 'authenticated', 'marker': marker})}.fixture';
}

Map<String, dynamic> _referral() => {
  'ownCode': 'JKMP2345XY',
  'inviterPoints': 100,
  'inviteePoints': 100,
  'registrationWindowDays': 7,
  'rewardLimit': 20,
  'monthlyRewardedCount': 0,
  'remaining': 20,
  'invitedCount': 0,
  'totalEarned': 0,
  'balance': 500,
  'canRedeem': true,
  'redeemed': false,
  'eligibleUntil': '2026-10-30T03:00:00Z',
  'serverTime': '2026-10-26T03:00:00Z',
  'claimed': false,
  'awardedPoints': 0,
  'rewardMonth': '2026-10',
  'timezone': 'Asia/Seoul',
  'ineligibleReason': null,
};

Map<String, dynamic> _attendance() => {
  'serverTime': '2026-10-26T03:00:00Z',
  'serverDate': '2026-10-26',
  'timezone': 'Asia/Seoul',
  'nextResetAt': '2026-10-26T15:00:00Z',
  'checkedInToday': false,
  'currentStreak': 0,
  'cycleDay': 1,
  'todayReward': 10,
  'weeklyRewards': [10, 10, 20, 10, 10, 10, 30],
  'month': '2026-10',
  'monthPoints': 0,
  'monthAttendanceCount': 0,
  'history': [],
  'claimed': false,
  'awardedPoints': 0,
  'balance': 100,
};

Map<String, dynamic> _news(String owner) => {
  'userId': owner,
  'serverNow': '2026-10-27T03:00:00Z',
  'serverDate': '2026-10-27',
  'weekStart': '2026-10-26',
  'timezone': 'Asia/Seoul',
  'dailyCount': 0,
  'weeklyCount': 0,
  'hasAttendanceEver': false,
  'hasReferralReward': false,
  'claimed': false,
  'history': [],
};

Map<String, dynamic> _admin(String owner) => {
  'userId': owner,
  'serverNow': '2026-10-27T03:00:00Z',
  'campaigns': [
    for (final campaign in defaultHomeNewsCampaigns) campaign.toJson(),
  ],
};

class _Fixture {
  late final http.Client transport;
  late final SupabaseClient client;
  late final SupabaseReferralRepository referral;
  late final SupabaseAttendanceRepository attendance;
  late final SupabaseHomeNewsRepository news;
  late final SupabaseAdminHomeNewsRepository admin;
  Future<http.Response> Function(http.Request)? respond;
  final requests = <http.Request>[];
  final authEvents = <AuthChangeEvent>[];
  final referralOwners = <String?>[],
      attendanceOwners = <String?>[],
      newsOwners = <String?>[];
  final subscriptions = <StreamSubscription<dynamic>>[];

  Object payload(String path, [String owner = _a]) =>
      switch (path.split('/').last) {
        'get_referral_status' || 'redeem_referral_code' => _referral(),
        'get_attendance_status' || 'claim_daily_attendance' => _attendance(),
        'get_home_news_state' || 'claim_home_news_exposure' => _news(owner),
        'get_admin_home_news_campaigns' ||
        'update_admin_home_news_campaign' => _admin(owner),
        _ => throw StateError('Unexpected fixture RPC'),
      };

  http.Response response(http.Request request, Object body) => http.Response(
    jsonEncode(body),
    200,
    request: request,
    headers: {'content-type': 'application/json'},
  );

  Future<void> initialize() async {
    transport = MockClient((request) async {
      requests.add(request);
      if (respond case final handler?) return handler(request);
      return response(
        request,
        payload(request.url.path, client.auth.currentUser!.id),
      );
    });
    client = SupabaseClient(
      'https://fixture.supabase.co',
      'public-fixture-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    subscriptions.add(
      client.auth.onAuthStateChange.listen(
        (state) => authEvents.add(state.event),
        onError: (Object _, StackTrace __) {},
      ),
    );
    await actor(_a);
    referral = SupabaseReferralRepository(client);
    attendance = SupabaseAttendanceRepository(client);
    news = SupabaseHomeNewsRepository(client);
    admin = SupabaseAdminHomeNewsRepository(client);
    // Deliberately no onError: repository account streams must consume transient
    // auth failures instead of crashing an otherwise valid-account consumer.
    subscriptions.add(referral.authChanges.listen(referralOwners.add));
    subscriptions.add(attendance.authChanges.listen(attendanceOwners.add));
    subscriptions.add(news.authChanges.listen(newsOwners.add));
    // GoTrue can deliver an initial-session event to a new subscriber. Record
    // that valid baseline before checking that a network error changes nothing.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> actor(String owner, {bool isAdmin = true}) async {
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': _jwt(owner, '${authEvents.length}-$isAdmin'),
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {'role': isAdmin ? 'admin' : 'user'},
          'user_metadata': {},
          'created_at': '2026-11-01T00:00:00Z',
        },
      }),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> gatewayFailure() async {
    // Simulate the SDK's documented auth-stream error path without network or
    // changing its actual current session. Production code never injects this.
    // ignore: invalid_use_of_internal_member
    client.auth.notifyException(
      AuthRetryableFetchException(
        message: 'temporary auth refresh gateway timeout',
        statusCode: '504',
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<List<Object>> readAll() => Future.wait<Object>([
    referral.fetchStatus(),
    attendance.fetchStatus(),
    news.getExposureState(),
    admin.getCampaigns(),
  ]);

  Future<void> close() async {
    for (final subscription in subscriptions) await subscription.cancel();
    referral.dispose();
    attendance.dispose();
    news.dispose();
    admin.dispose();
    await client.dispose();
    transport.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    fixture = _Fixture();
    await fixture.initialize();
  });
  tearDown(() => fixture.close());

  test(
    'all four repositories consume a real SDK 504 stream error and retain the same authenticated session',
    () async {
      final session = fixture.client.auth.currentSession;
      final referralBefore = List<String?>.of(fixture.referralOwners);
      final attendanceBefore = List<String?>.of(fixture.attendanceOwners);
      final newsBefore = List<String?>.of(fixture.newsOwners);
      await fixture.gatewayFailure();
      expect(fixture.client.auth.currentSession, same(session));
      expect(fixture.referral.currentUserId, _a);
      expect(fixture.attendance.currentUserId, _a);
      expect(fixture.news.currentUserId, _a);
      expect(fixture.admin.currentUserId, _a);
      expect(fixture.referralOwners, referralBefore);
      expect(fixture.attendanceOwners, attendanceBefore);
      expect(fixture.newsOwners, newsBefore);
      expect([
        ...referralBefore,
        ...attendanceBefore,
        ...newsBefore,
      ], everyElement(_a));
      expect(await fixture.readAll(), hasLength(4));
      expect(fixture.authEvents, isNot(contains(AuthChangeEvent.signedOut)));
      expect(
        fixture.requests.every(
          (request) =>
              request.headers['authorization'] ==
              'Bearer ${session!.accessToken}',
        ),
        isTrue,
      );
    },
  );

  final operations = <String, Future<Object> Function(_Fixture)>{
    'referral read': (f) => f.referral.fetchStatus(),
    'attendance read': (f) => f.attendance.fetchStatus(),
    'home news read': (f) => f.news.getExposureState(),
    'admin settings read': (f) => f.admin.getCampaigns(),
    'referral redemption reply': (f) => f.referral.redeem('ABCD2345XY'),
    'attendance claim reply': (f) => f.attendance.claim(),
    'home exposure claim reply': (f) =>
        f.news.claimExposure('monthly-design:2026-10'),
    'admin settings update reply': (f) =>
        f.admin.updateCampaign(defaultHomeNewsCampaigns.first),
  };
  for (final operation in operations.entries) {
    test(
      'a 504 invalidates an outstanding ${operation.key} and permits a fresh owner-checked retry',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<http.Request>();
        fixture.respond = (request) {
          started.complete(request);
          return pending.future;
        };
        final result = operation.value(fixture);
        final rejected = expectLater(
          result,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'visible retry reason',
              contains('연결'),
            ),
          ),
        );
        final request = await started.future;
        final session = fixture.client.auth.currentSession;
        await fixture.gatewayFailure();
        pending.complete(
          fixture.response(request, fixture.payload(request.url.path)),
        );
        await rejected;
        expect(fixture.client.auth.currentSession, same(session));
        fixture.respond = null;
        expect(await fixture.readAll(), hasLength(4));
        expect(fixture.authEvents, isNot(contains(AuthChangeEvent.signedOut)));
      },
    );
  }

  test(
    'connection recovery preserves A B A rejection for every pending private repository read',
    () async {
      final referralBefore = List<String?>.of(fixture.referralOwners);
      final attendanceBefore = List<String?>.of(fixture.attendanceOwners);
      final newsBefore = List<String?>.of(fixture.newsOwners);
      final pending = <http.Request, Completer<http.Response>>{};
      final started = Completer<void>();
      fixture.respond = (request) {
        final response = Completer<http.Response>();
        pending[request] = response;
        if (pending.length == 4) started.complete();
        return response.future;
      };
      final reads = [
        fixture.referral.fetchStatus(),
        fixture.attendance.fetchStatus(),
        fixture.news.getExposureState(),
        fixture.admin.getCampaigns(),
      ];
      final failures = [
        for (final read in reads) expectLater(read, throwsStateError),
      ];
      await started.future;
      await fixture.actor(_b);
      await fixture.actor(_a);
      for (final entry in pending.entries) {
        entry.value.complete(
          fixture.response(entry.key, fixture.payload(entry.key.url.path)),
        );
      }
      await Future.wait(failures);
      expect(fixture.referralOwners, [...referralBefore, _b, _a]);
      expect(fixture.attendanceOwners, [...attendanceBefore, _b, _a]);
      expect(fixture.newsOwners, [...newsBefore, _b, _a]);
      fixture.respond = null;
      expect(await fixture.readAll(), hasLength(4));
    },
  );

  test(
    'a stream failure never grants admin access or accepts another owners private state',
    () async {
      await fixture.actor(_a, isAdmin: false);
      await fixture.gatewayFailure();
      expect(fixture.admin.currentUserId, isNull);
      final requestsBefore = fixture.requests.length;
      await expectLater(fixture.admin.getCampaigns(), throwsStateError);
      expect(fixture.requests.length, requestsBefore);
      fixture.respond = (request) async => fixture.response(request, _news(_b));
      await expectLater(fixture.news.getExposureState(), throwsFormatException);
      await fixture.actor(_a);
      fixture.respond = (request) async =>
          fixture.response(request, _admin(_b));
      await expectLater(fixture.admin.getCampaigns(), throwsFormatException);
      expect(fixture.client.auth.currentUser!.id, _a);
    },
  );
}

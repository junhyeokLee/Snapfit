import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/web_point_topup_repository.dart';
import 'package:snap_fit/features/billing/domain/pending_point_purchase.dart';
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth extends Mock implements GoTrueClient {}

class _Tokens extends Mock implements TokenStorage {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.supabase.co',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-session',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

const _a = '11111111-1111-4111-8111-111111111111';
const _b = '22222222-2222-4222-8222-222222222222';
const _id = 'SFPTT_33333333-3333-4333-8333-333333333333';
const _other = 'SFPTT_44444444-4444-4444-8444-444444444444';
const _product = WebPointProduct(
  id: 'snapfit_points_2500',
  title: '2,500P',
  points: 2500,
  amount: 2200,
);
Map<String, dynamic> _session({String status = 'PREPARED'}) => {
  'paymentId': _id,
  'ownerId': _a,
  'productId': _product.id,
  'title': _product.title,
  'points': _product.points,
  'totalAmount': _product.amount,
  'currency': 'KRW',
  'status': status,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'sdkStartedAt': status == 'PENDING'
      ? DateTime.now().toUtc().toIso8601String()
      : null,
  'verifiedAt': null,
  'refundedAt': null,
  'serverVerified': false,
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'realPointsGranted': 0,
  'storeId': webPointTestStoreId,
  'channelKey': webPointTestChannelKey,
  'canLaunch': status == 'PREPARED',
};
const _receipt = PendingPointPurchase(
  ownerId: _a,
  productId: 'snapfit_points_2500',
  transactionId: 'store-order',
  source: 'google_play',
  serverData: 'store-token',
  localData: 'store-local',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? actor;
  late _Client client;
  late WebPointTopupRepository web;
  late BillingRepository native;
  late List<Map<String, dynamic>> calls;
  late Future<http.Response> Function(Map<String, dynamic>) respond;
  http.Response json(Object? data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );
  setUp(() {
    actor = _a;
    calls = [];
    final auth = _Auth();
    when(() => auth.currentUser).thenAnswer(
      (_) => actor == null
          ? null
          : User(
              id: actor!,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-10-29',
            ),
    );
    respond = (_) async => json(_session());
    client = _Client(
      auth,
      MockClient((request) async {
        expect(request.url.origin, 'https://fixture.supabase.co');
        expect(
          request.url.path,
          anyOf('/functions/v1/web-point-topup', '/functions/v1/iap-verify'),
        );
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        calls.add(body);
        return respond(body);
      }),
    );
    web = WebPointTopupRepository(client);
    native = BillingRepository(tokenStorage: _Tokens(), supabase: client);
  });
  tearDown(() async => client.dispose());

  test('web live checkout stays closed before transport', () async {
    expect(webPointTopupLiveCheckoutReleased, isFalse);
    await expectLater(
      web.prepare(_a, _b, _product, environment: 'live'),
      throwsA(
        isA<WebPointTopupException>().having(
          (e) => e.code,
          'code',
          'web_point_checkout_closed',
        ),
      ),
    );
    expect(calls, isEmpty);
  });

  test(
    'web prepare preserves request identity and exact catalog price across retries',
    () async {
      final first = await web.prepare(_a, _b, _product);
      final second = await web.prepare(_a, _b, _product);
      expect(first.paymentId, second.paymentId);
      expect(calls, [
        {
          'action': 'prepare',
          'requestId': _b,
          'productId': _product.id,
          'expectedAmount': 2200,
          'expectedPoints': 2500,
          'environment': 'test',
        },
        {
          'action': 'prepare',
          'requestId': _b,
          'productId': _product.id,
          'expectedAmount': 2200,
          'expectedPoints': 2500,
          'environment': 'test',
        },
      ]);
      expect(first.serverVerified, isFalse);
      expect(first.canLaunch, isTrue);
      expect(first.isTest, isTrue);
    },
  );

  test(
    'web prepare rejects a changed amount or another customers invoice',
    () async {
      respond = (_) async => json({..._session(), 'totalAmount': 2300});
      await expectLater(
        web.prepare(_a, _b, _product),
        throwsA(
          isA<WebPointTopupException>().having(
            (e) => e.code,
            'code',
            'web_point_price_changed',
          ),
        ),
      );
      respond = (_) async => json({..._session(), 'ownerId': _b});
      await expectLater(
        web.prepare(_a, _b, _product),
        throwsA(
          isA<WebPointTopupException>().having(
            (e) => e.code,
            'code',
            'web_point_owner_changed',
          ),
        ),
      );
    },
  );

  test(
    'web SDK authorization binds the invoice, product, amount and server-approved route',
    () async {
      final prepared = WebPointTopup.fromJson(_session());
      respond = (_) async =>
          json({..._session(status: 'PENDING'), 'sdkLaunchAuthorized': true});
      final request = await web.authorizeLaunch(_a, prepared);
      expect(calls.single, {'action': 'launch', 'paymentId': _id});
      expect(request.toBrowserJson(), {
        'storeId': webPointTestStoreId,
        'channelKey': webPointTestChannelKey,
        'paymentId': _id,
        'orderName': '스냅핏 2500P TEST 충전',
        'totalAmount': 2200,
        'currency': 'KRW',
        'payMethod': 'CARD',
      });
      for (final change in <Map<String, dynamic>>[
        {'paymentId': _other},
        {'totalAmount': 2300},
        {'points': 2600},
        {'productId': 'snapfit_points_9000'},
        {'ownerId': _b},
        {'storeId': 'store-attacker-route'},
        {'sdkLaunchAuthorized': false},
        {
          'expiresAt': DateTime.now()
              .toUtc()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        },
      ]) {
        respond = (_) async => json({
          ..._session(status: 'PENDING'),
          'sdkLaunchAuthorized': true,
          ...change,
        });
        await expectLater(
          web.authorizeLaunch(_a, prepared),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'web confirm never assumes SDK success and checks the original invoice identity',
    () async {
      respond = (_) async => json(_session(status: 'PENDING'));
      final pending = await web.confirm(_a, _id);
      expect(pending.serverVerified, isFalse);
      expect(pending.needsRecovery, isTrue);
      expect(pending.pending, isTrue);
      expect(calls.single, {'action': 'confirm', 'paymentId': _id});
      for (final action in [web.status, web.confirm]) {
        respond = (_) async => json({..._session(), 'paymentId': _other});
        await expectLater(action(_a, _id), throwsFormatException);
      }
    },
  );

  test(
    'web status parses verified test, cancellation and refund without real point credit',
    () async {
      for (final status in ['VERIFIED_TEST', 'VOIDED', 'REFUNDED']) {
        respond = (_) async => json({
          ..._session(),
          'status': status,
          'verifiedAt': status == 'VOIDED'
              ? null
              : DateTime.now().toUtc().toIso8601String(),
          'serverVerified': status != 'VOIDED',
          'refundedAt': status == 'VERIFIED_TEST'
              ? null
              : DateTime.now().toUtc().toIso8601String(),
          'canLaunch': false,
        });
        final row = await web.status(_a, _id);
        expect(row.status, status);
        expect(row.pending, isFalse);
        expect(row.canLaunch, isFalse);
        expect(row.isTest, isTrue);
        expect(row.statusLabel, contains(status == 'VOIDED' ? '취소' : 'TEST'));
      }
    },
  );

  test('web history rejects another owner and bounds the response', () async {
    respond = (_) async => json({
      'liveCheckoutReleased': false,
      'topups': [_session()],
    });
    expect((await web.history(_a)).single.paymentId, _id);
    respond = (_) async => json({
      'liveCheckoutReleased': false,
      'topups': [
        {..._session(), 'ownerId': _b},
      ],
    });
    await expectLater(web.history(_a), throwsA(isA<WebPointTopupException>()));
    respond = (_) async => json({
      'liveCheckoutReleased': false,
      'topups': List.generate(51, (_) => _session()),
    });
    await expectLater(web.history(_a), throwsFormatException);
  });

  test(
    'web account changes reject both new calls and a late successful response',
    () async {
      actor = _b;
      await expectLater(
        web.status(_a, _id),
        throwsA(isA<WebPointTopupException>()),
      );
      expect(calls, isEmpty);
      actor = _a;
      final response = Completer<http.Response>(), started = Completer<void>();
      respond = (_) {
        started.complete();
        return response.future;
      };
      final pending = web.status(_a, _id);
      await started.future;
      final rejected = expectLater(
        pending,
        throwsA(isA<WebPointTopupException>()),
      );
      actor = _b;
      response.complete(json(_session()));
      await rejected;
    },
  );

  test(
    'native verification forwards receipt identity and accepts only server-confirmed grants',
    () async {
      respond = (_) async => json({
        'status': 'VERIFIED',
        'pointPurchase': {
          'productId': _receipt.productId,
          'grantedPoints': 0,
          'remainingBalance': 2500,
          'alreadyGranted': true,
        },
      });
      final result = await native.verifyPendingPointPurchase(_receipt);
      expect(result.alreadyGranted, isTrue);
      expect(result.grantedPoints, 0);
      expect(calls.single, {
        'platform': 'GOOGLE_PLAY',
        'productId': _receipt.productId,
        'transactionId': 'store-order',
        'purchaseToken': 'store-token',
        'receiptData': 'store-local',
        'verificationSource': 'google_play',
        'purchaseType': 'POINTS',
      });
      for (final body in [
        {'status': 'PENDING'},
        {
          'status': 'VERIFIED',
          'pointPurchase': {
            'productId': 'different',
            'grantedPoints': 2500,
            'remainingBalance': 2500,
          },
        },
        {
          'status': 'VERIFIED',
          'pointPurchase': {
            'productId': _receipt.productId,
            'grantedPoints': '2500',
            'remainingBalance': 2500,
          },
        },
      ]) {
        respond = (_) async => json(body);
        await expectLater(
          native.verifyPendingPointPurchase(_receipt),
          throwsStateError,
        );
      }
    },
  );

  test(
    'native wrong account never transports and revoked receipts are nonretryable',
    () async {
      actor = _b;
      await expectLater(
        native.verifyPendingPointPurchase(_receipt),
        throwsStateError,
      );
      expect(calls, isEmpty);
      actor = _a;
      respond = (_) async => json({'error': 'purchase_revoked'}, 409);
      await expectLater(
        native.verifyPendingPointPurchase(_receipt),
        throwsA(
          isA<PointPurchaseVerificationException>()
              .having((e) => e.code, 'code', 'purchase_revoked')
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
      respond = (_) async => json({'error': 'provider_unavailable'}, 503);
      await expectLater(
        native.verifyPendingPointPurchase(_receipt),
        throwsA(
          isA<PointPurchaseVerificationException>().having(
            (e) => e.retryable,
            'retryable',
            isTrue,
          ),
        ),
      );
    },
  );
}

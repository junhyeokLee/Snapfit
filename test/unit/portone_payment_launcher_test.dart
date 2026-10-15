import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher_native.dart'
    show buildPortOneMobilePaymentRequest;
import 'package:snap_fit/features/profile/domain/portone_payment.dart';

Map<String, dynamic> _prepared() => {
  'status': 'PREPARED',
  'environment': 'test',
  'paymentId': 'SFPGT_00000000-0000-4000-8000-000000000000',
  'storeId': 'store-00000000-0000-4000-8000-000000000001',
  'channelKey': 'channel-key-00000000-0000-4000-8000-000000000002',
  'orderName': '스냅핏 개발 결제 테스트',
  'totalAmount': 49900,
  'currency': 'KRW',
};

void main() {
  test(
    'production requires explicit READY server request and rejects test invoice IDs',
    () {
      final live = {
        ..._prepared(),
        'status': 'READY',
        'environment': 'production',
        'paymentId': 'SFP_00000000-0000-4000-8000-000000000000',
      };
      expect(
        PortOnePaymentRequest.fromProductionReady(live).environment,
        'production',
      );
      for (final patch in [
        {'environment': 'test'},
        {'status': 'PREPARED'},
        {'paymentId': _prepared()['paymentId']},
        {'totalAmount': 0},
        {'currency': 'USD'},
      ]) {
        expect(
          () => PortOnePaymentRequest.fromProductionReady({...live, ...patch}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'only a prepared test request can enter the SDK and production is rejected',
    () {
      final request = PortOnePaymentRequest.fromPrepared(_prepared());
      expect(request.environment, 'test');
      expect(request.appScheme, 'snapfit');
      for (final patch in [
        {'environment': 'production'},
        {'status': 'PAID'},
        {'currency': 'USD'},
        {'totalAmount': 0},
        {'totalAmount': 49900.0},
        {'paymentId': 'customer-order'},
        {'storeId': ''},
        {'channelKey': ''},
      ]) {
        expect(
          () => PortOnePaymentRequest.fromPrepared({..._prepared(), ...patch}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mobile official SDK and browser SDK receive identical original price and identity',
    () {
      final request = PortOnePaymentRequest.fromPrepared(_prepared());
      final browser = request.toBrowserJson();
      final mobile = buildPortOneMobilePaymentRequest(request).toJson();
      for (final key in [
        'storeId',
        'channelKey',
        'paymentId',
        'orderName',
        'totalAmount',
        'currency',
        'payMethod',
        'appScheme',
      ]) {
        expect(mobile[key], browser[key], reason: key);
      }
      expect(browser['currency'], 'KRW');
      expect(browser['totalAmount'], 49900);
      expect(browser.keys, isNot(contains('customer')));
      expect(browser.keys, isNot(contains('environment')));
      expect(browser.keys, isNot(contains('apiSecret')));
    },
  );

  test('callback identity is matched but never represents a paid receipt', () {
    final request = PortOnePaymentRequest.fromPrepared(_prepared());
    final result = PortOneSdkResult.fromCallback({
      'paymentId': request.paymentId,
      'txId': 'attempt',
    }, request);
    expect(result.status, PortOneSdkStatus.returned);
    expect(result.requiresServerVerification, isTrue);
    expect(result.paymentId, request.paymentId);
    expect(result.reasonCode, isNull);
    expect(
      PortOneSdkResult.fromCallback({
        'paymentId': 'other-payment',
      }, request).status,
      PortOneSdkStatus.failed,
    );
    expect(
      PortOneSdkResult.fromCallback({'success': true}, request).status,
      PortOneSdkStatus.failed,
    );
  });

  test('cancellation and errors discard raw SDK messages and tokens', () {
    final request = PortOnePaymentRequest.fromPrepared(_prepared());
    expect(
      PortOneSdkResult.fromCallback(null, request).status,
      PortOneSdkStatus.canceled,
    );
    final canceled = PortOneSdkResult.fromCallback({
      'code': 'PAY_PROCESS_CANCELED',
      'message': 'private response',
    }, request);
    expect(canceled.status, PortOneSdkStatus.canceled);
    expect(canceled.requiresServerVerification, isTrue);
    expect(canceled.paymentId, isNull);
    final failed = PortOneSdkResult.fromCallback({
      'code': 'PG_ERROR',
      'message': 'private response',
      'paymentToken': 'private-token',
    }, request);
    expect(failed.status, PortOneSdkStatus.failed);
    expect(failed.requiresServerVerification, isTrue);
    expect(failed.reasonCode, 'sdk_rejected');
    expect(failed.paymentId, isNull);
  });

  test(
    'redirect allows HTTPS or local test origins and rejects credential-bearing URLs',
    () {
      for (final redirect in [
        'https://snapfit.app/payment-return',
        'http://127.0.0.1:7358/',
      ]) {
        final request = PortOnePaymentRequest.fromPrepared({
          ..._prepared(),
          'redirectUrl': redirect,
        });
        expect(request.toBrowserJson()['redirectUrl'], redirect);
      }
      for (final redirect in [
        'http://example.com/payment',
        'javascript:alert(1)',
        'https://user:password@example.com/',
      ]) {
        expect(
          () => PortOnePaymentRequest.fromPrepared({
            ..._prepared(),
            'redirectUrl': redirect,
          }),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'desktop native platform returns unsupported without opening a payment view',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      PortOneSdkResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await launchPortOnePayment(
                context,
                PortOnePaymentRequest.fromPrepared(_prepared()),
              ),
              child: const Text('Open test'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open test'));
      await tester.pumpAndSettle();
      expect(result?.status, PortOneSdkStatus.failed);
      expect(result?.reasonCode, 'sdk_platform_unsupported');
      expect(find.text('개발 결제 테스트'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

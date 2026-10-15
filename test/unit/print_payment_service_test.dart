import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/data/print_prepayment_package_service.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/portone_payment.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class _Orders extends Mock implements OrderRepository {}

class _Packages extends Mock implements PrintPrepaymentPackageService {}

const requestId = '00000000-0000-4000-8000-000000000000';
const paymentId = 'SFP_00000000-0000-4000-8000-000000000000';
const specRevision =
    '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a';
const request = PrintCheckoutRequest(
  albumId: 7,
  reviewedRevision: 'reviewed',
  reviewedSpecRevision: specRevision,
  amount: 49900,
  recipientName: '합성 수령인',
  recipientPhone: '01000000000',
  zipCode: '12345',
  addressLine1: '합성 도로 1',
  addressLine2: '테스트',
  deliveryMemo: '합성 메모',
);

PrintPaymentInvoice invoice({
  String status = 'PREPARED',
  bool paid = false,
  bool unpaid = false,
  String specHash = specRevision,
  bool requestHold = false,
  bool packageReady = true,
}) => PrintPaymentInvoice.fromJson({
  'environment': 'production',
  'orderId': 'owned-order',
  'requestId': requestId,
  'paymentId': paymentId,
  'albumId': 7,
  'totalAmount': 49900,
  'status': status,
  'verifiedPaid': paid,
  'verifiedUnpaid': unpaid,
  'reviewedSpecRevision': specHash,
  'customerRequestHold': requestHold,
  'printPackageReady': packageReady,
  if (status == 'PREPARED')
    'sdkRequest': {
      'status': 'READY',
      'environment': 'production',
      'storeId': 'store-00000000-0000-4000-8000-000000000001',
      'channelKey': 'channel-key-00000000-0000-4000-8000-000000000002',
      'paymentId': paymentId,
      'orderName': '스냅핏 앨범',
      'totalAmount': 49900,
      'currency': 'KRW',
    },
});

PrintPaidReceipt receipt() => PrintPaidReceipt.fromOrder(
  OrderHistoryItem(
    orderId: 'owned-order',
    title: '합성 앨범',
    amount: 49900,
    albumId: 7,
    status: 'PAYMENT_COMPLETED',
    statusLabel: '결제완료',
    progress: .25,
    orderedAt: DateTime.utc(2026, 10, 14),
    paymentConfirmedAt: DateTime.utc(2026, 10, 14, 1),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Orders orders;
  late PrintPaymentService service;
  late String owner;
  setUpAll(() {
    registerFallbackValue(request);
    registerFallbackValue(invoice());
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    owner = 'owner-a';
    when(() => orders.printPaymentOwnerId()).thenAnswer((_) async => owner);
    when(
      () => orders.preparePrintPayment(
        requestId: requestId,
        request: any(named: 'request'),
      ),
    ).thenAnswer((_) async => invoice());
    when(
      () => orders.fetchPrintPaymentStatus(paymentId: paymentId),
    ).thenAnswer((_) async => invoice());
    when(
      () => orders.fetchPrintPaymentStatus(requestId: requestId),
    ).thenAnswer((_) async => invoice());
    when(
      () => orders.confirmPrintPayment(paymentId),
    ).thenAnswer((_) async => invoice(status: 'PAYMENT_COMPLETED', paid: true));
    when(
      () => orders.fetchPrintPaidReceipt(
        orderId: 'owned-order',
        albumId: 7,
        expectedAmount: 49900,
        expectedPaymentId: paymentId,
      ),
    ).thenAnswer((_) async => receipt());
    service = PrintPaymentService(
      repository: orders,
      requestId: () => requestId,
    );
  });

  for (final result in ['returned', 'canceled', 'failed', 'thrown']) {
    test(
      'SDK $result always verifies original payment ID before paid receipt',
      () async {
        final outcome = await service.pay(request, (sdk) async {
          expect(sdk.paymentId, paymentId);
          expect(sdk.environment, 'production');
          if (result == 'thrown') throw StateError('interrupted');
          if (result == 'canceled') return const PortOneSdkResult.canceled();
          if (result == 'failed')
            return const PortOneSdkResult.failed('timeout');
          return PortOneSdkResult.fromCallback({'paymentId': paymentId}, sdk);
        });
        expect(outcome.receipt?.orderId, 'owned-order');
        verify(() => orders.confirmPrintPayment(paymentId)).called(1);
        verify(
          () => orders.fetchPrintPaidReceipt(
            orderId: 'owned-order',
            albumId: 7,
            expectedAmount: 49900,
            expectedPaymentId: paymentId,
          ),
        ).called(1);
        expect(await service.pending(), isNull);
      },
    );
  }

  test(
    'PDF upload and server inspection complete before the first SDK starts',
    () async {
      final packages = _Packages();
      final events = <String>[];
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice(packageReady: false));
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        events.add('files-ready');
        return invoice();
      });
      service = PrintPaymentService(
        repository: orders,
        requestId: () => requestId,
        prepaymentPackages: packages,
      );
      final outcome = await service.pay(request, (_) async {
        events.add('sdk');
        expect((await service.pending())?.sdkStarted, isTrue);
        return const PortOneSdkResult.canceled();
      });
      expect(events, ['files-ready', 'sdk']);
      expect(outcome.receipt?.orderId, 'owned-order');
    },
  );

  test(
    'unfinished package never launches SDK even if an SDK envelope was returned',
    () async {
      final packages = _Packages();
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice(packageReady: false));
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => invoice(packageReady: false));
      service = PrintPaymentService(
        repository: orders,
        requestId: () => requestId,
        prepaymentPackages: packages,
      );
      var launches = 0;
      final outcome = await service.pay(request, (_) async {
        launches++;
        return const PortOneSdkResult.canceled();
      });
      expect(outcome.pending, isTrue);
      expect(launches, 0);
      expect((await service.pending())?.sdkStarted, isFalse);
      verifyNever(() => orders.confirmPrintPayment(paymentId));
    },
  );

  test(
    'lost file finalization leaves original refs unstarted and resumes same package on explicit retry',
    () async {
      final packages = _Packages();
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice(packageReady: false));
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(StateError('upload_response_lost'));
      service = PrintPaymentService(
        repository: orders,
        requestId: () => requestId,
        prepaymentPackages: packages,
      );
      var launches = 0;
      final first = await service.pay(request, (_) async {
        launches++;
        return const PortOneSdkResult.canceled();
      });
      expect(first.pending, isTrue);
      expect(first.preparationError, 'print_package_prepare_failed');
      expect((await service.pending())?.paymentId, paymentId);
      expect((await service.pending())?.sdkStarted, isFalse);
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: paymentId),
      ).thenAnswer((_) async => invoice(packageReady: false));
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => invoice());
      final restarted = PrintPaymentService(
        repository: orders,
        requestId: () => throw StateError('must reuse original UUID'),
        prepaymentPackages: packages,
      );
      final second = await restarted.pay(request, (_) async {
        launches++;
        return const PortOneSdkResult.canceled();
      });
      expect(second.receipt?.orderId, 'owned-order');
      expect(launches, 1);
      verify(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).called(2);
    },
  );

  test(
    'unknown confirmation survives restart and never starts a second SDK charge',
    () async {
      when(
        () => orders.confirmPrintPayment(paymentId),
      ).thenThrow(StateError('offline'));
      var opens = 0;
      final first = await service.pay(request, (_) async {
        opens++;
        return const PortOneSdkResult.canceled();
      });
      expect(first.pending, isTrue);
      expect((await service.pending())?.sdkStarted, isTrue);
      final restarted = PrintPaymentService(
        repository: orders,
        requestId: () => throw StateError('must reuse'),
      );
      final second = await restarted.pay(request, (_) async {
        opens++;
        return const PortOneSdkResult.canceled();
      });
      expect(second.pending, isTrue);
      expect(opens, 1);
      final unavailable = await restarted.recover();
      expect(unavailable.pending, isTrue);
      expect(unavailable.verificationUnavailable, isTrue);
      expect(unavailable.noCharge, isFalse);
      when(() => orders.confirmPrintPayment(paymentId)).thenAnswer(
        (_) async => invoice(status: 'PAYMENT_COMPLETED', paid: true),
      );
      expect((await restarted.recover()).receipt?.orderId, 'owned-order');
      expect(await restarted.pending(), isNull);
    },
  );

  test(
    'lost prepare response recovers original UUID without PII stored',
    () async {
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenThrow(StateError('response_lost'));
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      final stored = await service.pending();
      expect(stored?.requestId, requestId);
      expect(stored?.paymentId, isNull);
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(prefs.getKeys().single)!;
      expect(
        jsonDecode(encoded).keys,
        unorderedEquals([
          'requestId',
          'albumId',
          'amount',
          'orderId',
          'paymentId',
          'sdkStarted',
        ]),
      );
      expect(encoded, isNot(contains(request.recipientName)));
      expect(encoded, isNot(contains(request.addressLine1)));
      final restarted = PrintPaymentService(repository: orders);
      expect((await restarted.recover()).pending, isTrue);
      expect(opens, 0);
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice());
      expect(
        (await restarted.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).receipt,
        isNotNull,
      );
      expect(opens, 1);
      verify(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).called(2);
    },
  );

  test(
    '404 preserves both an unissued placeholder and an issued invoice without claiming unpaid',
    () async {
      final store = service.store;
      when(
        () => orders.fetchPrintPaymentStatus(requestId: requestId),
      ).thenThrow(
        const PrintCheckoutApiException('print_checkout_not_found', 404),
      );
      await store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 7,
          amount: 49900,
        ),
      );
      final missing = await service.recover();
      expect(missing.pending, isTrue);
      expect(missing.noCharge, isFalse);
      expect(await service.pending(), isNotNull);
      await store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 7,
          amount: 49900,
          paymentId: paymentId,
          sdkStarted: false,
        ),
      );
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: paymentId),
      ).thenThrow(
        const PrintCheckoutApiException('print_checkout_not_found', 404),
      );
      expect((await service.recover()).pending, isTrue);
      expect(await service.pending(), isNotNull);
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      expect(opens, 0);
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      );
    },
  );

  test(
    'explicit same-UUID prepare retries only a never-issued matching placeholder after owned 404',
    () async {
      when(
        () => orders.fetchPrintPaymentStatus(requestId: requestId),
      ).thenThrow(
        const PrintCheckoutApiException('print_checkout_not_found', 404),
      );
      await service.store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 7,
          amount: 49900,
        ),
      );
      var opens = 0;
      final outcome = await service.pay(request, (_) async {
        opens++;
        return const PortOneSdkResult.canceled();
      });
      expect(outcome.receipt, isNotNull);
      expect(opens, 1);
      verify(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).called(1);
    },
  );

  test(
    'an unresolved cancellation hold never re-prepares or reopens the existing SDK invoice',
    () async {
      await service.store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 7,
          amount: 49900,
          paymentId: paymentId,
        ),
      );
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: paymentId),
      ).thenAnswer((_) async => invoice(requestHold: true));
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      expect(opens, 0);
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      );
      expect((await service.pending())?.paymentId, paymentId);
    },
  );

  test(
    'a missing placeholder for another album remains pending without any prepare or new charge',
    () async {
      when(
        () => orders.fetchPrintPaymentStatus(requestId: requestId),
      ).thenThrow(
        const PrintCheckoutApiException('print_checkout_not_found', 404),
      );
      await service.store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 99,
          amount: 49900,
        ),
      );
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      expect(opens, 0);
      expect((await service.pending())?.albumId, 99);
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      );
    },
  );

  test(
    'authoritative canceled state permits retry but time-only expiry does not',
    () async {
      when(
        () => orders.confirmPrintPayment(paymentId),
      ).thenAnswer((_) async => invoice(status: 'EXPIRED'));
      expect(
        (await service.pay(
          request,
          (_) async => const PortOneSdkResult.canceled(),
        )).pending,
        isTrue,
      );
      when(
        () => orders.confirmPrintPayment(paymentId),
      ).thenAnswer((_) async => invoice(status: 'CANCELED', unpaid: true));
      expect((await service.recover()).noCharge, isTrue);
      expect(await service.pending(), isNull);
    },
  );

  test(
    'account switch after SDK cannot verify or reveal previous owner order',
    () async {
      final result = await service.pay(request, (_) async {
        owner = 'owner-b';
        return const PortOneSdkResult.canceled();
      });
      expect(result.receipt, isNull);
      verifyNever(() => orders.confirmPrintPayment(paymentId));
      expect((await service.recover()).receipt, isNull);
      expect(await service.pending(), isNull);
      owner = 'owner-a';
      expect((await service.pending())?.paymentId, paymentId);
    },
  );

  test(
    'overlapping taps keep service locked until server confirmation finishes',
    () async {
      final sdk = Completer<PortOneSdkResult>();
      var opens = 0;
      final first = service.pay(request, (_) {
        opens++;
        return sdk.future;
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.busy, isTrue);
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      sdk.complete(const PortOneSdkResult.canceled());
      expect((await first).receipt, isNotNull);
      expect(opens, 1);
      expect(service.busy, isFalse);
    },
  );

  test(
    'verifiedPaid flag cannot bypass authenticated paid receipt lookup',
    () async {
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'owned-order',
          albumId: 7,
          expectedAmount: 49900,
          expectedPaymentId: paymentId,
        ),
      ).thenThrow(const FormatException('production_receipt_required'));
      expect(
        (await service.pay(
          request,
          (_) async => const PortOneSdkResult.canceled(),
        )).receipt,
        isNull,
      );
      expect((await service.pending())?.sdkStarted, isTrue);
    },
  );
  test(
    'resuming an unstarted invoice rechecks frozen delivery fingerprint before SDK',
    () async {
      await service.store.write(
        owner,
        const PendingPrintPayment(
          requestId: requestId,
          albumId: 7,
          amount: 49900,
          orderId: 'owned-order',
          paymentId: paymentId,
        ),
      );
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenThrow(
        const PrintCheckoutApiException('print_checkout_request_conflict', 409),
      );
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      expect(opens, 0);
      expect((await service.pending())?.sdkStarted, isFalse);
      verify(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).called(1);
    },
  );
  test(
    'an invoice with a different approved geometry cannot enter SDK even at the same price',
    () async {
      when(
        () => orders.preparePrintPayment(
          requestId: requestId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice(specHash: List.filled(64, 'a').join()));
      var opens = 0;
      expect(
        (await service.pay(request, (_) async {
          opens++;
          return const PortOneSdkResult.canceled();
        })).pending,
        isTrue,
      );
      expect(opens, 0);
      expect((await service.pending())?.sdkStarted, isFalse);
    },
  );
}

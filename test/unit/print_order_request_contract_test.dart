import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_order_request_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/data/print_prepayment_package_service.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/portone_payment.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/domain/print_order_request.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const checkoutId = '22222222-2222-4222-8222-222222222222';
const orderId = 'ordp_33333333-3333-4333-8333-333333333333';
const paymentId = 'SFP_44444444-4444-4444-8444-444444444444';
Map<String, dynamic> requestJson({
  String status = 'REQUESTED',
  String resolution = 'NONE',
  bool replacement = false,
  String payment = paymentId,
  bool preSdkAbortVerified = false,
}) => {
  'requestId': requestId,
  'checkoutRequestId': checkoutId,
  'orderId': orderId,
  'paymentId': payment,
  'type': 'CANCEL',
  'status': status,
  'resolution': resolution,
  'replacementAllowed': replacement,
  'createdAt': '2026-10-14T01:00:00Z',
  'updatedAt': '2026-10-14T02:00:00Z',
  'message': '기존 주문의 처리 결과를 확인합니다.',
  'preSdkAbortVerified': preSdkAbortVerified,
};

class Orders extends Mock implements OrderRepository {}

class Packages extends Mock implements PrintPrepaymentPackageService {}

class Requests extends PrintOrderRequestRepository {
  Requests(super.orders);
  PrintOrderRequestResult result = PrintOrderRequestResult.fromJson(
    requestJson(),
  );
  void Function()? afterRead;
  @override
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    afterRead?.call();
    return result;
  }
}

void main() {
  const nextCheckoutId = '55555555-5555-4555-8555-555555555555';
  const nextPaymentId = 'SFP_66666666-6666-4666-8666-666666666666';
  final nextRequest = PrintCheckoutRequest(
    albumId: 7,
    amount: 49900,
    reviewedRevision:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    reviewedSpecRevision: printSpecRevision(const {}),
    recipientName: '합성 수령인',
    recipientPhone: '01000000000',
    zipCode: '12345',
    addressLine1: '합성 주소',
    addressLine2: '',
  );
  final nextInvoice = PrintPaymentInvoice.fromJson({
    'environment': 'production',
    'status': 'PREPARED',
    'orderId': 'ordp_77777777-7777-4777-8777-777777777777',
    'requestId': nextCheckoutId,
    'paymentId': nextPaymentId,
    'albumId': 7,
    'totalAmount': 49900,
    'reviewedRevision': nextRequest.reviewedRevision,
    'reviewedSpecRevision': nextRequest.reviewedSpecRevision,
    'printPackageReady': false,
  });
  setUpAll(() {
    registerFallbackValue(nextRequest);
    registerFallbackValue(nextInvoice);
  });
  test(
    'checkout UUID and random provider payment ID stay independent while request identity remains bound',
    () {
      final result = PrintOrderRequestResult.fromJson(requestJson());
      expect(
        PrintOrderRequestTarget.checkout(checkoutId).matches(result),
        true,
      );
      expect(PrintOrderRequestTarget.payment(paymentId).matches(result), true);
      expect(PrintOrderRequestTarget.order(orderId).matches(result), true);
      expect(result.canReplace, false);
      expect(result.label, '요청 접수됨');
    },
  );
  test(
    'request and unknown provider states cannot claim cancellation or replacement',
    () {
      for (final changes in [
        {'replacementAllowed': true},
        {'resolution': 'REFUNDED_FULL'},
        {'status': 'PAID'},
        {'checkoutRequestId': 'not-owned-checkout-id'},
        {'createdAt': 'not-a-date'},
        {
          'type': 'GENERAL',
          'status': 'COMPLETED',
          'resolution': 'REFUNDED_FULL',
          'replacementAllowed': true,
        },
      ]) {
        expect(
          () =>
              PrintOrderRequestResult.fromJson({...requestJson(), ...changes}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'pre-SDK cancellation requires its separate server proof and never means a refunded payment',
    () {
      final valid = requestJson(
        status: 'COMPLETED',
        resolution: 'PRE_SDK_ABORTED',
        replacement: true,
        preSdkAbortVerified: true,
      );
      final result = PrintOrderRequestResult.fromJson(valid);
      expect(result.canReplace, isTrue);
      expect(result.label, '결제 전 준비 주문 취소됨');
      for (final changed in [
        {'preSdkAbortVerified': false},
        {'preSdkAbortVerified': 'true'},
        {'status': 'WAITING_PROVIDER'},
        {'resolution': 'NONE'},
        {'type': 'GENERAL'},
      ]) {
        expect(
          () => PrintOrderRequestResult.fromJson({...valid, ...changed}),
          throwsFormatException,
        );
      }
      final revoked = PrintOrderRequestResult.fromJson({
        ...valid,
        'replacementAllowed': false,
        'preSdkAbortVerified': false,
      });
      expect(revoked.canReplace, isFalse);
      expect(revoked.label, '준비 주문 처리 결과 확인 필요');
    },
  );

  for (final started in [false, true]) {
    test(
      'pre-SDK replacement ${started ? 'preserves a locally started payment' : 'clears only its exact unstarted attempt'}',
      () async {
        SharedPreferences.setMockInitialValues({});
        final orders = Orders();
        when(
          () => orders.printPaymentOwnerId(),
        ).thenAnswer((_) async => 'fixture-owner');
        final requests = Requests(orders)
          ..result = PrintOrderRequestResult.fromJson(
            requestJson(
              status: 'COMPLETED',
              resolution: 'PRE_SDK_ABORTED',
              replacement: true,
              preSdkAbortVerified: true,
            ),
          );
        final store = PrintPaymentRecoveryStore();
        await store.write(
          'fixture-owner',
          PendingPrintPayment(
            requestId: checkoutId,
            albumId: 7,
            amount: 49900,
            orderId: orderId,
            paymentId: paymentId,
            sdkStarted: started,
          ),
        );
        final service = PrintPaymentService(
          repository: orders,
          store: store,
          orderRequests: requests,
        );
        expect(await service.applyConfirmedReplacement(requestId), !started);
        expect(await store.read('fixture-owner'), started ? isNotNull : isNull);
        verifyNever(() => orders.confirmPrintPayment(any()));
      },
    );
  }

  test(
    'a revoked or wrong-ID pre-SDK cancellation cannot clear the stored order',
    () async {
      SharedPreferences.setMockInitialValues({});
      final orders = Orders();
      when(
        () => orders.printPaymentOwnerId(),
      ).thenAnswer((_) async => 'fixture-owner');
      final requests = Requests(orders);
      final store = PrintPaymentRecoveryStore();
      await store.write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: checkoutId,
          albumId: 7,
          amount: 49900,
          orderId: orderId,
          paymentId: paymentId,
        ),
      );
      final service = PrintPaymentService(
        repository: orders,
        store: store,
        orderRequests: requests,
      );
      requests.result = PrintOrderRequestResult.fromJson(
        requestJson(
          status: 'COMPLETED',
          resolution: 'PRE_SDK_ABORTED',
          replacement: true,
          preSdkAbortVerified: true,
          payment: nextPaymentId,
        ),
      );
      expect(await service.applyConfirmedReplacement(requestId), isFalse);
      requests.result = PrintOrderRequestResult.fromJson(
        requestJson(
          status: 'COMPLETED',
          resolution: 'PRE_SDK_ABORTED',
          replacement: false,
          preSdkAbortVerified: false,
        ),
      );
      expect(await service.applyConfirmedReplacement(requestId), isFalse);
      expect((await store.read('fixture-owner'))?.paymentId, paymentId);
    },
  );

  test(
    'confirmed unstarted preparation cancellation permits a new UUID without opening payment',
    () async {
      SharedPreferences.setMockInitialValues({});
      final orders = Orders(), packages = Packages();
      when(
        () => orders.printPaymentOwnerId(),
      ).thenAnswer((_) async => 'fixture-owner');
      when(
        () => orders.preparePrintPayment(
          requestId: nextCheckoutId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => nextInvoice);
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(
        const PrintPreflightException('print_checkout_pdf_too_large', []),
      );
      final requests = Requests(orders)
        ..result = PrintOrderRequestResult.fromJson(
          requestJson(
            status: 'COMPLETED',
            resolution: 'PRE_SDK_ABORTED',
            replacement: true,
            preSdkAbortVerified: true,
          ),
        );
      final store = PrintPaymentRecoveryStore();
      await store.write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: checkoutId,
          albumId: 7,
          amount: 49900,
          orderId: orderId,
          paymentId: paymentId,
        ),
      );
      final service = PrintPaymentService(
        repository: orders,
        store: store,
        orderRequests: requests,
        prepaymentPackages: packages,
        requestId: () => nextCheckoutId,
      );
      expect(await service.applyConfirmedReplacement(requestId), isTrue);
      var launches = 0;
      final outcome = await service.pay(nextRequest, (_) async {
        launches++;
        return const PortOneSdkResult.canceled();
      });
      expect(launches, 0);
      expect(outcome.preparationError, 'print_checkout_pdf_too_large');
      expect((await store.read('fixture-owner'))?.requestId, nextCheckoutId);
      verify(
        () => orders.preparePrintPayment(
          requestId: nextCheckoutId,
          request: any(named: 'request'),
        ),
      ).called(1);
    },
  );
  test(
    'only a fresh confirmed resolution for the same owner and stored IDs clears recovery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final orders = Orders();
      when(
        () => orders.printPaymentOwnerId(),
      ).thenAnswer((_) async => 'fixture-owner');
      final requests = Requests(orders);
      final store = PrintPaymentRecoveryStore();
      await store.write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: checkoutId,
          albumId: 7,
          amount: 49900,
          orderId: orderId,
          paymentId: paymentId,
          sdkStarted: true,
        ),
      );
      final service = PrintPaymentService(
        repository: orders,
        store: store,
        orderRequests: requests,
      );
      expect(await service.applyConfirmedReplacement(requestId), false);
      expect(await store.read('fixture-owner'), isNotNull);
      requests.result = PrintOrderRequestResult.fromJson(
        requestJson(
          status: 'COMPLETED',
          resolution: 'REFUNDED_FULL',
          replacement: true,
          payment: 'SFP_55555555-5555-4555-8555-555555555555',
        ),
      );
      expect(await service.applyConfirmedReplacement(requestId), false);
      expect(await store.read('fixture-owner'), isNotNull);
      requests.result = PrintOrderRequestResult.fromJson(
        requestJson(
          status: 'COMPLETED',
          resolution: 'REFUNDED_FULL',
          replacement: true,
        ),
      );
      expect(await service.applyConfirmedReplacement(requestId), true);
      expect(await store.read('fixture-owner'), isNull);
      verifyNever(() => orders.fetchMyOrders());
    },
  );
  test(
    'response loss before prepare still matches the owned checkout UUID without deriving a payment ID',
    () async {
      SharedPreferences.setMockInitialValues({});
      final orders = Orders();
      when(
        () => orders.printPaymentOwnerId(),
      ).thenAnswer((_) async => 'fixture-owner');
      final requests = Requests(orders)
        ..result = PrintOrderRequestResult.fromJson(
          requestJson(
            status: 'COMPLETED',
            resolution: 'CANCELLED_UNPAID',
            replacement: true,
          ),
        );
      final store = PrintPaymentRecoveryStore();
      await store.write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: checkoutId,
          albumId: 7,
          amount: 49900,
        ),
      );
      expect(
        await PrintPaymentService(
          repository: orders,
          store: store,
          orderRequests: requests,
        ).applyConfirmedReplacement(requestId),
        true,
      );
      expect(await store.read('fixture-owner'), isNull);
    },
  );
  test(
    'an account switch during resolution preserves the original owner recovery record',
    () async {
      SharedPreferences.setMockInitialValues({});
      final orders = Orders();
      var owner = 'original-owner';
      when(() => orders.printPaymentOwnerId()).thenAnswer((_) async => owner);
      final requests = Requests(orders)
        ..result = PrintOrderRequestResult.fromJson(
          requestJson(
            status: 'COMPLETED',
            resolution: 'CANCELLED_UNPAID',
            replacement: true,
          ),
        )
        ..afterRead = () => owner = 'another-owner';
      final store = PrintPaymentRecoveryStore();
      await store.write(
        owner,
        const PendingPrintPayment(
          requestId: checkoutId,
          albumId: 7,
          amount: 49900,
          paymentId: paymentId,
        ),
      );
      await expectLater(
        PrintPaymentService(
          repository: orders,
          store: store,
          orderRequests: requests,
        ).applyConfirmedReplacement(requestId),
        throwsStateError,
      );
      expect(await store.read('original-owner'), isNotNull);
    },
  );
}

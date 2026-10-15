import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_complete_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/data/print_prepayment_package_service.dart';
import 'package:snap_fit/features/profile/data/print_order_request_repository.dart';
import 'package:snap_fit/features/profile/domain/print_order_request.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/portone_payment.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import '../unit/print_order_request_contract_test.dart' as requests_fixture;

class _Orders extends Mock implements OrderRepository {}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'fixture-owner',
    name: '고객',
    email: 'owner@example.com',
    provider: 'EMAIL',
  );
}

class _Packages extends Mock implements PrintPrepaymentPackageService {}

class _PreparationRequests extends PrintOrderRequestRepository {
  _PreparationRequests(super.orders);
  PrintOrderRequestResult? current;
  @override
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    if (current == null)
      throw const PrintOrderRequestException(
        'print_order_request_not_found',
        404,
      );
    return current!;
  }

  @override
  Future<PrintOrderRequestResult> create({
    required PrintOrderRequestTarget target,
    required String requestId,
    required String type,
    required String reason,
  }) async {
    return current = PrintOrderRequestResult.fromJson({
      ...requests_fixture.requestJson(
        status: 'COMPLETED',
        resolution: 'PRE_SDK_ABORTED',
        replacement: true,
        preSdkAbortVerified: true,
      ),
      'requestId': requestId,
      'type': type,
    });
  }
}

OrderQuoteResult _quote({int amount = 49900}) => OrderQuoteResult.fromJson({
  'amount': amount,
  'pageCount': 20,
  'basePages': 20,
  'basePrice': amount,
  'sourcePageCount': 20,
  'addedBlankPageCount': 0,
  'productCode': 'REDP_200X150_SOFT',
  'supplierCostVerified': true,
  'shippingCostVerified': true,
  'packagingCostVerified': true,
  'shippingIncluded': true,
  'pricePolicyVersion': 'confirmed-test-v1',
});

Map<String, dynamic> _snapshot({String text = 'Our album'}) => {
  'album': {
    'id': 7,
    'title': 'Our album',
    'cover_layers_json': {
      'pages': [
        {
          'index': 0,
          'layers': [
            {'text': text},
          ],
        },
      ],
    },
  },
  'pages': [],
};

PrintCheckoutReadiness _readiness({bool canPay = false, int amount = 49900}) =>
    PrintCheckoutReadiness(
      canPay: canPay,
      status: canPay ? 'READY' : 'PREPARING',
      reasonCode: canPay ? '' : 'print_sales_not_ready',
      message: '정식 주문 서비스를 준비하고 있어요.',
      quote: _quote(amount: amount),
      environment: canPay ? 'production' : 'unavailable',
    );

PrintPaidReceipt _receipt() => PrintPaidReceipt.fromOrder(
  OrderHistoryItem(
    orderId: 'paid-order',
    title: 'Our album',
    amount: 49900,
    albumId: 7,
    status: 'PAYMENT_COMPLETED',
    statusLabel: '결제완료',
    progress: .25,
    orderedAt: DateTime.utc(2026, 10, 13),
    paymentConfirmedAt: DateTime.utc(2026, 10, 13, 1),
  ),
);

void main() {
  late _Orders orders;
  setUpAll(
    () => registerFallbackValue(
      const PrintCheckoutRequest(
        albumId: 7,
        reviewedRevision: '',
        amount: 49900,
        recipientName: '',
        recipientPhone: '',
        zipCode: '',
        addressLine1: '',
        addressLine2: '',
      ),
    ),
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    when(() => orders.fetchMyPrintOrderProgress('paid-order')).thenAnswer(
      (_) async => const PrintOrderProgress(
        orderId: 'paid-order',
        customerStage: 'PAID',
        preflightPassed: false,
        requiresAction: false,
      ),
    );
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'fixture-owner');
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 7),
    ).thenAnswer((_) async => _snapshot());
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: 7),
    ).thenAnswer((_) async => _readiness());
  });

  Future<void> pump(
    WidgetTester tester, {
    Future<PrintPaidReceipt?> Function(PrintCheckoutRequest request)? onPay,
    PortOnePaymentLauncher? launch,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    PrintPrepaymentPackageService? packages,
    PrintOrderRequestRepository? orderRequests,
    String Function()? requestId,
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          authViewModelProvider.overrideWith(_Auth.new),
          if (orderRequests != null)
            printOrderRequestRepositoryProvider.overrideWithValue(
              orderRequests,
            ),
          if (launch != null)
            portOnePaymentLauncherProvider.overrideWithValue(launch),
          printPaymentServiceProvider.overrideWith(
            (ref) => PrintPaymentService(
              repository: orders,
              requestId:
                  requestId ?? () => '00000000-0000-4000-8000-000000000000',
              prepaymentPackages: packages,
              orderRequests: orderRequests,
            ),
          ),
        ],
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : null,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home:
              home ??
              PrintOrderCheckoutScreen(
                albumId: 7,
                albumTitle: 'Our album',
                initialQuote: _quote(),
                reviewedRevision: printCheckoutRevision(_snapshot()),
                onPay: onPay,
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.enterText(finder, value);
    await tester.pump();
  }

  Future<void> validDelivery(WidgetTester tester) async {
    await field(tester, 'print-recipient-name', '테스트 수령인');
    await field(tester, 'print-recipient-phone', '01000000000');
    await field(tester, 'print-zip-code', '12345');
    await field(tester, 'print-address-line1', '서울 테스트도로 1');
    await field(tester, 'print-address-line2', '테스트 동 호수');
  }

  Future<void> review(WidgetTester tester) async {
    await tester.ensureVisible(find.text('주문 내용 확인하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주문 내용 확인하기'));
    await tester.pumpAndSettle();
  }

  Future<void> agree(WidgetTester tester) async {
    final checkbox = find.byKey(const ValueKey('print-checkout-agreement'));
    if (checkbox.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        checkbox,
        120,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(checkbox);
    await tester.pump();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    testWidgets(
      'checkout delivery and consent stay safe in short landscape $size',
      (tester) async {
        tester.view.padding = const FakeViewPadding(
          left: 44,
          right: 24,
          bottom: 24,
        );
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        await pump(tester, size: size, textScale: 1.5, dark: true);
        tester.view.viewInsets = const FakeViewPadding(bottom: 140);
        await tester.pumpAndSettle();
        await validDelivery(tester);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await review(tester);
        await agree(tester);
        final payment = find.byKey(const ValueKey('print-checkout-payment'));
        await tester.ensureVisible(payment);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(payment).onPressed, isNull);
        expect(find.text('결제 준비 중'), findsOneWidget);
        expect(
          tester.getBottomRight(payment).dy,
          lessThanOrEqualTo(size.height - 24),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'oversized PDF can cancel its unissued preparation and return directly to album editing without payment',
    (tester) async {
      final invoice = PrintPaymentInvoice.fromJson({
        'environment': 'production',
        'status': 'PREPARED',
        'orderId': requests_fixture.orderId,
        'requestId': requests_fixture.checkoutId,
        'paymentId': requests_fixture.paymentId,
        'albumId': 7,
        'totalAmount': 49900,
        'reviewedRevision': printCheckoutRevision(_snapshot()),
        'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
        'printPackageReady': false,
      });
      registerFallbackValue(invoice);
      final packages = _Packages(), requests = _PreparationRequests(orders);
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      when(
        () => orders.preparePrintPayment(
          requestId: requests_fixture.checkoutId,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice);
      when(
        () => orders.fetchPrintPaymentStatus(
          paymentId: requests_fixture.paymentId,
        ),
      ).thenAnswer((_) async => invoice);
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(
        const PrintPreflightException('print_checkout_pdf_too_large', []),
      );
      var sdkLaunches = 0;
      String? returned;
      await pump(
        tester,
        packages: packages,
        orderRequests: requests,
        requestId: () => requests_fixture.checkoutId,
        launch: (context, sdk) async {
          sdkLaunches++;
          return const PortOneSdkResult.canceled();
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                returned = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrintOrderCheckoutScreen(
                      albumId: 7,
                      albumTitle: 'Our album',
                      initialQuote: _quote(),
                      reviewedRevision: printCheckoutRevision(_snapshot()),
                    ),
                  ),
                );
              },
              child: const Text('앨범 제작하기'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('앨범 제작하기'));
      await tester.pumpAndSettle();
      await validDelivery(tester);
      await review(tester);
      await agree(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-checkout-payment')),
      );
      await tester.tap(find.byKey(const ValueKey('print-checkout-payment')));
      await tester.pumpAndSettle();
      expect(sdkLaunches, 0);
      expect(find.textContaining('표지는 최대 150MB, 내지는 최대 500MB'), findsOneWidget);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.sdkStarted,
        isFalse,
      );
      await tester.ensureVisible(find.text('준비 주문 취소 요청'));
      await tester.tap(find.text('준비 주문 취소 요청'));
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('print-order-request-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('결제 전 준비 주문 취소됨'), findsOneWidget);
      await tester.ensureVisible(find.text('앨범 다시 편집하기'));
      await tester.tap(find.text('앨범 다시 편집하기'));
      await tester.pumpAndSettle();
      expect(returned, 'edit_album');
      expect(await PrintPaymentRecoveryStore().read('fixture-owner'), isNull);
      expect(sdkLaunches, 0);
      verifyNever(() => orders.confirmPrintPayment(any()));
    },
  );

  testWidgets(
    'an interrupted PDF preparation restores the frozen order on the same visit and permits explicit same-order retry',
    (tester) async {
      const rid = '00000000-0000-4000-8000-000000000000';
      const pid = 'SFP_00000000-0000-4000-8000-000000000000';
      final prepared = PrintPaymentInvoice.fromJson({
        'environment': 'production',
        'status': 'PREPARED',
        'orderId': 'prepared-order',
        'requestId': rid,
        'paymentId': pid,
        'albumId': 7,
        'totalAmount': 49900,
        'reviewedRevision': printCheckoutRevision(_snapshot()),
        'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
        'printPackageReady': false,
        'recipient': {
          'name': '확정 수령인',
          'phone': '01000000000',
          'zipCode': '12345',
          'addressLine1': '확정 도로명 주소',
          'addressLine2': '확정 상세',
          'deliveryMemo': '',
        },
      });
      registerFallbackValue(prepared);
      final packages = _Packages();
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      when(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => prepared);
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: pid),
      ).thenAnswer((_) async => prepared);
      when(
        () => packages.prepare(
          invoice: any(named: 'invoice'),
          request: any(named: 'request'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenThrow(StateError('finalization_response_lost'));
      var sdkLaunches = 0;
      await pump(
        tester,
        packages: packages,
        launch: (_, sdk) async {
          sdkLaunches++;
          return const PortOneSdkResult.canceled();
        },
      );
      await validDelivery(tester);
      await review(tester);
      await agree(tester);
      final payment = find.byKey(const ValueKey('print-checkout-payment'));
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(sdkLaunches, 0);
      expect(find.textContaining('같은 주문으로 준비를 다시 시도'), findsOneWidget);
      expect(find.textContaining('확정 수령인'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '수정'))
            .onPressed,
        isNull,
      );
      expect(tester.widget<FilledButton>(payment).onPressed, isNull);
      await agree(tester);
      expect(tester.widget<FilledButton>(payment).onPressed, isNotNull);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.requestId,
        rid,
      );
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.sdkStarted,
        isFalse,
      );
      verify(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      ).called(1);
      verifyNever(() => orders.confirmPrintPayment(any()));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'default checkout launches once and recovers a started invoice after restart without a fresh PDF gate',
    (tester) async {
      const pid = 'SFP_00000000-0000-4000-8000-000000000000';
      const rid = '00000000-0000-4000-8000-000000000000';
      PrintPaymentInvoice invoice({bool paid = false}) =>
          PrintPaymentInvoice.fromJson({
            'orderId': 'paid-order',
            'paymentId': pid,
            'requestId': rid,
            'albumId': 7,
            'totalAmount': 49900,
            'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
            'environment': 'production',
            'printPackageReady': true,
            'status': paid ? 'PAYMENT_COMPLETED' : 'PREPARED',
            'verifiedPaid': paid,
            if (!paid)
              'sdkRequest': {
                'status': 'READY',
                'environment': 'production',
                'printPackageReady': true,
                'storeId': 'store-00000000-0000-4000-8000-000000000001',
                'channelKey':
                    'channel-key-00000000-0000-4000-8000-000000000002',
                'paymentId': pid,
                'orderName': '스냅핏 앨범',
                'totalAmount': 49900,
                'currency': 'KRW',
              },
          });
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      when(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => invoice());
      when(
        () => orders.confirmPrintPayment(pid),
      ).thenThrow(StateError('response_lost'));
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: pid),
      ).thenAnswer((_) async => invoice());
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'paid-order',
          albumId: 7,
          expectedAmount: 49900,
          expectedPaymentId: pid,
        ),
      ).thenAnswer((_) async => _receipt());
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'paid-order',
          albumId: 7,
          expectedAmount: 49900,
        ),
      ).thenAnswer((_) async => _receipt());
      when(() => orders.fetchMyPrintOrder('paid-order')).thenAnswer(
        (_) async => OrderHistoryItem(
          orderId: 'paid-order',
          title: 'Our album',
          amount: 49900,
          albumId: 7,
          status: 'PAYMENT_COMPLETED',
          statusLabel: '결제완료',
          progress: .25,
          orderedAt: DateTime.utc(2026, 10, 13),
          paymentConfirmedAt: DateTime.utc(2026, 10, 13, 1),
        ),
      );
      var launches = 0;
      await pump(
        tester,
        launch: (context, sdk) async {
          launches++;
          expect(sdk.paymentId, pid);
          return const PortOneSdkResult.failed('sdk_unknown');
        },
      );
      await validDelivery(tester);
      await review(tester);
      await agree(tester);
      final payment = find.byKey(const ValueKey('print-checkout-payment'));
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(launches, 1);
      expect(find.byType(PrintOrderCompleteScreen), findsNothing);
      expect(tester.widget<FilledButton>(payment).onPressed, isNull);
      expect(find.textContaining('이전 결제 결과를 확인하고'), findsOneWidget);
      when(
        () => orders.confirmPrintPayment(pid),
      ).thenAnswer((_) async => invoice(paid: true));
      await tester.pumpWidget(const SizedBox());
      await pump(
        tester,
        launch: (context, sdk) async {
          launches++;
          return const PortOneSdkResult.failed('must_not_launch_again');
        },
      );
      expect(find.byType(PrintOrderCompleteScreen), findsOneWidget);
      expect(launches, 1);
      verify(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      ).called(1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'checkout becoming READY can prepare files through the durable payment service',
    (tester) async {
      var ready = false;
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: ready));
      await pump(tester, onPay: (_) async => null);
      await validDelivery(tester);
      ready = true;
      await review(tester);
      expect(find.text('주문 내용 확인'), findsOneWidget);
      expect(find.textContaining('결제 전에 인쇄 PDF를 만들고'), findsOneWidget);
      expect(find.text('인쇄 미리보기 다시 확인'), findsNothing);
      expect(find.byType(PrintOrderCompleteScreen), findsNothing);
    },
  );

  testWidgets(
    'closed checkout reviews delivery and price without payment or a fabricated order',
    (tester) async {
      var paymentCalls = 0;
      await pump(
        tester,
        onPay: (_) async {
          paymentCalls++;
          return _receipt();
        },
      );
      await validDelivery(tester);
      await review(tester);
      expect(find.text('주문 내용 확인'), findsOneWidget);
      expect(find.text('49,900원'), findsOneWidget);
      expect(find.text('기본 배송비 포함'), findsOneWidget);
      await agree(tester);
      final payment = find.byKey(const ValueKey('print-checkout-payment'));
      await tester.ensureVisible(payment);
      expect(tester.widget<FilledButton>(payment).onPressed, isNull);
      expect(find.text('결제 준비 중'), findsOneWidget);
      expect(find.byType(PrintOrderCompleteScreen), findsNothing);
      expect(paymentCalls, 0);
      verifyNever(() => orders.fetchMyOrders());
      await tester.ensureVisible(find.text('수정'));
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('print-recipient-name')),
            )
            .controller!
            .text,
        '테스트 수령인',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('print-address-line2')),
            )
            .controller!
            .text,
        '테스트 동 호수',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'an unstarted recovered invoice restores server delivery and requires fresh consent before same-UUID resume',
    (tester) async {
      const rid = '00000000-0000-4000-8000-000000000000';
      const pid = 'SFP_00000000-0000-4000-8000-000000000000';
      final prepared = PrintPaymentInvoice.fromJson({
        'printPackageReady': true,
        'orderId': 'paid-order',
        'paymentId': pid,
        'requestId': rid,
        'albumId': 7,
        'totalAmount': 49900,
        'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
        'environment': 'production',
        'status': 'PREPARED',
        'verifiedPaid': false,
        'reviewedRevision': printCheckoutRevision(_snapshot()),
        'recipient': {
          'name': '서버 저장 합성 수령인',
          'phone': '01000000000',
          'zipCode': '12345',
          'addressLine1': '합성 도로 1',
          'addressLine2': '합성 상세',
          'deliveryMemo': '',
        },
        'sdkRequest': {
          'status': 'READY',
          'environment': 'production',
          'storeId': 'store-00000000-0000-4000-8000-000000000001',
          'channelKey': 'channel-key-00000000-0000-4000-8000-000000000002',
          'paymentId': pid,
          'orderName': '스냅핏 앨범',
          'totalAmount': 49900,
          'currency': 'KRW',
        },
      });
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: rid,
          albumId: 7,
          amount: 49900,
          paymentId: pid,
          orderId: 'paid-order',
        ),
      );
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      when(
        () => orders.fetchPrintPaymentStatus(paymentId: pid),
      ).thenAnswer((_) async => prepared);
      when(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      ).thenAnswer((_) async => prepared);
      when(() => orders.confirmPrintPayment(pid)).thenAnswer(
        (_) async => PrintPaymentInvoice.fromJson({
          'orderId': 'paid-order',
          'paymentId': pid,
          'requestId': rid,
          'albumId': 7,
          'totalAmount': 49900,
          'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
          'environment': 'production',
          'status': 'PAYMENT_COMPLETED',
          'verifiedPaid': true,
        }),
      );
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'paid-order',
          albumId: 7,
          expectedAmount: 49900,
          expectedPaymentId: pid,
        ),
      ).thenAnswer((_) async => _receipt());
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'paid-order',
          albumId: 7,
          expectedAmount: 49900,
        ),
      ).thenAnswer((_) async => _receipt());
      var opens = 0;
      await pump(
        tester,
        launch: (_, sdk) async {
          opens++;
          return const PortOneSdkResult.canceled();
        },
      );
      expect(find.textContaining('서버 저장 합성 수령인'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '수정'))
            .onPressed,
        isNull,
      );
      final payment = find.byKey(const ValueKey('print-checkout-payment'));
      expect(tester.widget<FilledButton>(payment).onPressed, isNull);
      expect(opens, 0);
      await agree(tester);
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.byType(PrintOrderCompleteScreen), findsOneWidget);
      final captured =
          verify(
                () => orders.preparePrintPayment(
                  requestId: rid,
                  request: captureAny(named: 'request'),
                ),
              ).captured.single
              as PrintCheckoutRequest;
      expect(captured.recipientName, '서버 저장 합성 수령인');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a changed frozen unstarted order offers cancellation and explicit checks without endless polling or a new charge',
    (tester) async {
      const rid = '00000000-0000-4000-8000-000000000000';
      const pid = 'SFP_00000000-0000-4000-8000-000000000000';
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: rid,
          albumId: 7,
          amount: 49900,
          paymentId: pid,
          orderId: 'paid-order',
        ),
      );
      when(() => orders.fetchPrintPaymentStatus(paymentId: pid)).thenAnswer(
        (_) async => PrintPaymentInvoice.fromJson({
          'orderId': 'paid-order',
          'paymentId': pid,
          'requestId': rid,
          'albumId': 7,
          'totalAmount': 49900,
          'environment': 'production',
          'status': 'PREPARED',
          'verifiedPaid': false,
          'reviewedRevision': 'previous-frozen-revision',
          'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
          'recipient': {'name': '기존 합성 수령인'},
        }),
      );
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      var opens = 0;
      await pump(
        tester,
        launch: (_, sdk) async {
          opens++;
          return const PortOneSdkResult.canceled();
        },
      );
      expect(find.textContaining('현재 앨범·금액이 달라요'), findsOneWidget);
      expect(find.text('준비 주문 취소 요청'), findsOneWidget);
      await tester.pump(const Duration(minutes: 2));
      verify(() => orders.fetchPrintPaymentStatus(paymentId: pid)).called(2);
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      );
      expect(opens, 0);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.paymentId,
        pid,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a never-issued placeholder after owned not-found can review the current form for the same UUID without claiming canceled',
    (tester) async {
      const rid = '00000000-0000-4000-8000-000000000000';
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(requestId: rid, albumId: 7, amount: 49900),
      );
      when(() => orders.fetchPrintPaymentStatus(requestId: rid)).thenThrow(
        const PrintCheckoutApiException('print_checkout_not_found', 404),
      );
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      await pump(tester);
      expect(find.textContaining('같은 주문번호로 준비를 다시 시도'), findsOneWidget);
      expect(find.textContaining('취소 확인됨'), findsNothing);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.requestId,
        rid,
      );
      await validDelivery(tester);
      await review(tester);
      expect(
        find.byKey(const ValueKey('print-checkout-agreement')),
        findsOneWidget,
      );
      verifyNever(
        () => orders.preparePrintPayment(
          requestId: rid,
          request: any(named: 'request'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a server customer-request hold prevents restoring payment consent and offers existing request review',
    (tester) async {
      const rid = '00000000-0000-4000-8000-000000000000';
      const pid = 'SFP_00000000-0000-4000-8000-000000000000';
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: rid,
          albumId: 7,
          amount: 49900,
          paymentId: pid,
          orderId: 'paid-order',
        ),
      );
      when(() => orders.fetchPrintPaymentStatus(paymentId: pid)).thenAnswer(
        (_) async => PrintPaymentInvoice.fromJson({
          'orderId': 'paid-order',
          'paymentId': pid,
          'requestId': rid,
          'albumId': 7,
          'totalAmount': 49900,
          'environment': 'production',
          'status': 'PREPARED',
          'verifiedPaid': false,
          'reviewedRevision': printCheckoutRevision(_snapshot()),
          'reviewedSpecRevision': printSpecRevision(_quote().printSpec),
          'recipient': {'name': '기존 합성 수령인'},
          'customerRequestHold': true,
        }),
      );
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      var opens = 0;
      await pump(
        tester,
        launch: (_, sdk) async {
          opens++;
          return const PortOneSdkResult.canceled();
        },
      );
      expect(find.textContaining('취소·환불 요청을 처리하고 있어요'), findsOneWidget);
      expect(find.textContaining('배송지와 앨범 내용을 확인하면 같은 주문으로 결제'), findsNothing);
      expect(find.text('준비 주문 취소 요청'), findsOneWidget);
      expect(opens, 0);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.paymentId,
        pid,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid recipient phone and postal code cannot reach final review',
    (tester) async {
      await pump(tester);
      await field(tester, 'print-recipient-name', '테스트');
      await field(tester, 'print-recipient-phone', '0212345678');
      await field(tester, 'print-zip-code', '123');
      await review(tester);
      expect(find.text('주문 내용 확인'), findsNothing);
      expect(find.text('010으로 시작하는 휴대폰 번호 11자리를 입력해주세요.'), findsOneWidget);
      expect(find.text('우편번호 5자리를 입력해주세요.'), findsOneWidget);
      expect(find.text('도로명 주소를 입력해주세요.'), findsOneWidget);
      verify(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).called(1);
    },
  );

  testWidgets(
    'revised album blocks the old review and leaves delivery details intact',
    (tester) async {
      var snapshot = _snapshot();
      when(
        () => orders.fetchPrintPreviewSnapshot(albumId: 7),
      ).thenAnswer((_) async => snapshot);
      await pump(tester);
      await validDelivery(tester);
      snapshot = _snapshot(text: 'Changed content');
      await review(tester);
      expect(find.textContaining('앨범 내용이나 제작 구성이 바뀌었어요'), findsOneWidget);
      expect(find.text('인쇄 미리보기 다시 확인'), findsOneWidget);
      expect(find.text('주문 내용 확인'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('print-recipient-name')),
            )
            .controller!
            .text,
        '테스트 수령인',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '주문 내용 확인하기'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('a new price resets consent while preserving delivery', (
    tester,
  ) async {
    var amount = 49900;
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: 7),
    ).thenAnswer((_) async => _readiness(canPay: true, amount: amount));
    await pump(tester, onPay: (_) async => _receipt());
    await validDelivery(tester);
    await review(tester);
    await agree(tester);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('print-checkout-agreement')),
          )
          .value,
      isTrue,
    );
    amount = 50900;
    await tester.tap(find.byTooltip('최신 주문 정보 확인'));
    await tester.pumpAndSettle();
    expect(find.text('50,900원'), findsOneWidget);
    expect(find.textContaining('제작 금액이 갱신되었습니다'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('print-checkout-agreement')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('print-checkout-payment')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('테스트 수령인'), findsOneWidget);
  });
  testWidgets(
    'a changed approved print geometry requires a new visual review even at the same price',
    (tester) async {
      await pump(tester);
      await validDelivery(tester);
      await review(tester);
      await agree(tester);
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer(
        (_) async => PrintCheckoutReadiness(
          canPay: true,
          status: 'READY',
          reasonCode: '',
          message: '',
          quote: OrderQuoteResult.fromJson({
            'amount': 49900,
            'pageCount': 20,
            'sourcePageCount': 20,
            'productCode': 'REDP_200X150_SOFT',
            'spec': {
              'specVersion': 'changed-cover-template',
              'cover': {'widthMm': 999},
            },
          }),
        ),
      );
      await tester.tap(find.byTooltip('최신 주문 정보 확인'));
      await tester.pumpAndSettle();
      expect(find.text('인쇄 미리보기 다시 확인'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('print-checkout-agreement')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('print-checkout-payment')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'a payment callback cannot display completion until the server order is paid',
    (tester) async {
      final serverReceipt = Completer<PrintPaidReceipt>();
      when(
        () => orders.fetchPrintCheckoutReadiness(albumId: 7),
      ).thenAnswer((_) async => _readiness(canPay: true));
      when(
        () => orders.fetchPrintPaidReceipt(
          orderId: 'paid-order',
          albumId: 7,
          expectedAmount: 49900,
        ),
      ).thenAnswer((_) => serverReceipt.future);
      var paymentCalls = 0;
      await pump(
        tester,
        onPay: (_) async {
          paymentCalls++;
          return _receipt();
        },
      );
      await validDelivery(tester);
      await review(tester);
      await agree(tester);
      final payment = find.byKey(const ValueKey('print-checkout-payment'));
      await tester.ensureVisible(payment);
      await tester.tap(payment);
      await tester.pump();
      await tester.pump();
      expect(paymentCalls, 1);
      expect(find.byType(PrintOrderCompleteScreen), findsNothing);
      expect(tester.widget<FilledButton>(payment).onPressed, isNull);
      serverReceipt.completeError(
        const FormatException('print_payment_not_confirmed'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrintOrderCompleteScreen), findsNothing);
      expect(find.textContaining('결제 결과를 확인하지 못했습니다'), findsOneWidget);
      expect(paymentCalls, 1);
    },
  );

  testWidgets('only a paid order read back from the server opens completion', (
    tester,
  ) async {
    when(() => orders.fetchMyPrintOrder('paid-order')).thenAnswer(
      (_) async => OrderHistoryItem(
        orderId: 'paid-order',
        title: 'Our album',
        amount: 49900,
        albumId: 7,
        status: 'PAYMENT_COMPLETED',
        statusLabel: '결제완료',
        progress: .25,
        orderedAt: DateTime.utc(2026, 10, 13),
        paymentConfirmedAt: DateTime.utc(2026, 10, 13, 1),
      ),
    );
    when(
      () => orders.fetchPrintCheckoutReadiness(albumId: 7),
    ).thenAnswer((_) async => _readiness(canPay: true));
    when(
      () => orders.fetchPrintPaidReceipt(
        orderId: 'paid-order',
        albumId: 7,
        expectedAmount: 49900,
      ),
    ).thenAnswer((_) async => _receipt());
    PrintCheckoutRequest? request;
    await pump(
      tester,
      onPay: (value) async {
        request = value;
        return _receipt();
      },
    );
    await validDelivery(tester);
    await review(tester);
    await agree(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('print-checkout-payment')),
    );
    await tester.tap(find.byKey(const ValueKey('print-checkout-payment')));
    await tester.pumpAndSettle();
    expect(find.byType(PrintOrderCompleteScreen), findsOneWidget);
    expect(find.text('결제가 확인됐어요'), findsOneWidget);
    expect(find.text('paid-order'), findsOneWidget);
    expect(request?.amount, 49900);
    expect(request?.recipientPhone, '01000000000');
    verify(
      () => orders.fetchPrintPaidReceipt(
        orderId: 'paid-order',
        albumId: 7,
        expectedAmount: 49900,
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard in a small phone keeps manual address entry scrollable',
    (tester) async {
      await pump(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await field(tester, 'print-address-line2', '테스트 상세 주소');
      await tester.ensureVisible(find.text('주문 내용 확인하기'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed readiness can retry without discarding the delivery form',
    (tester) async {
      var failing = true;
      when(() => orders.fetchPrintCheckoutReadiness(albumId: 7)).thenAnswer((
        _,
      ) async {
        if (failing) throw StateError('unavailable');
        return _readiness();
      });
      await pump(tester);
      expect(find.textContaining('주문 준비 상태를 확인하지 못했습니다'), findsOneWidget);
      await validDelivery(tester);
      await review(tester);
      expect(find.text('주문 내용 확인'), findsNothing);
      failing = false;
      await tester.tap(find.byTooltip('최신 주문 정보 확인'));
      await tester.pumpAndSettle();
      expect(find.textContaining('주문 준비 상태를 확인하지 못했습니다'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('print-recipient-name')),
            )
            .controller!
            .text,
        '테스트 수령인',
      );
      await review(tester);
      expect(find.text('주문 내용 확인'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('print-checkout-payment')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'address-search failure permits direct entry and never sends entered delivery data',
    (tester) async {
      when(
        () => orders.searchAddress(keyword: '테스트도로'),
      ).thenThrow(StateError('unavailable'));
      await pump(tester);
      await tester.ensureVisible(find.text('주소 검색'));
      await tester.tap(find.text('주소 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('print-address-search-keyword')),
        '테스트도로',
      );
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      expect(find.textContaining('배송지 화면에서 직접 입력해주세요'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await validDelivery(tester);
      await review(tester);
      expect(find.text('주문 내용 확인'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('print-checkout-payment')),
            )
            .onPressed,
        isNull,
      );
      verify(() => orders.searchAddress(keyword: '테스트도로')).called(1);
      verifyNever(() => orders.fetchMyOrders());
      expect(tester.takeException(), isNull);
    },
  );
}

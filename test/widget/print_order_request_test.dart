import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_order_request_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/domain/print_order_request.dart';
import 'package:snap_fit/features/profile/presentation/views/print_order_request_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';
import '../unit/print_order_request_contract_test.dart' as fixture;

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

class _Requests extends PrintOrderRequestRepository {
  _Requests(super.orders);
  final attempts = <({String id, String reason, String type})>[];
  PrintOrderRequestResult? current;
  bool loseCreate = false;
  bool abortOnCreate = false;
  String missingCode = 'print_order_request_not_found';
  @override
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    if (current == null) throw PrintOrderRequestException(missingCode, 404);
    return current!;
  }

  @override
  Future<PrintOrderRequestResult> create({
    required PrintOrderRequestTarget target,
    required String requestId,
    required String type,
    required String reason,
  }) async {
    attempts.add((id: requestId, reason: reason, type: type));
    if (loseCreate) throw StateError('private response lost');
    return current = PrintOrderRequestResult.fromJson({
      ...fixture.requestJson(),
      'requestId': requestId,
      'type': type,
      if (abortOnCreate) ...{
        'status': 'COMPLETED',
        'resolution': 'PRE_SDK_ABORTED',
        'replacementAllowed': true,
        'preSdkAbortVerified': true,
      },
    });
  }
}

void main() {
  late _Orders orders;
  late _Requests requests;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    requests = _Requests(orders);
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'fixture-owner');
  });
  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          authViewModelProvider.overrideWith(_Auth.new),
          printOrderRequestRepositoryProvider.overrideWithValue(requests),
          printPaymentServiceProvider.overrideWith(
            (ref) => PrintPaymentService(
              repository: orders,
              orderRequests: requests,
            ),
          ),
        ],
        child: MaterialApp(
          home:
              child ??
              PrintOrderRequestScreen(
                target: PrintOrderRequestTarget.order(fixture.orderId),
                initialType: 'CANCEL',
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'order-linked cancellation submits once and displays a request rather than a refund receipt',
    (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('print-order-request-reason')),
        '제작 전 취소를 요청합니다.',
      );
      await tester.pump();
      final button = find.byKey(const ValueKey('print-order-request-submit'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(requests.attempts.length, 1);
      expect(requests.attempts.single.type, 'CANCEL');
      expect(find.text('요청 접수됨'), findsOneWidget);
      expect(find.text('전액 환불 확인됨'), findsNothing);
      expect(find.text('미결제 주문 취소 확인됨'), findsNothing);
      expect(
        find.byKey(const ValueKey('print-order-request-submit')),
        findsNothing,
      );
      expect(find.textContaining('새 결제를 진행하지 않습니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a lost submission queries the same request and retries identical UUID and body only after not-found',
    (tester) async {
      requests.loseCreate = true;
      await pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('print-order-request-reason')),
        '준비한 주문을 확인해주세요.',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.tap(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('새 요청을 보내기 전에 같은 요청의 결과'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-order-request-refresh')),
      );
      await tester.tap(
        find.byKey(const ValueKey('print-order-request-refresh')),
      );
      await tester.pumpAndSettle();
      requests.loseCreate = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.tap(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.pumpAndSettle();
      expect(requests.attempts.length, 2);
      expect(requests.attempts.first, requests.attempts.last);
      expect(find.text('요청 접수됨'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'existing unresolved refund shows server review and never offers new payment or replacement',
    (tester) async {
      requests.current = PrintOrderRequestResult.fromJson({
        ...fixture.requestJson(status: 'REVIEW_REQUIRED'),
        'type': 'REFUND',
      });
      await pump(tester);
      expect(find.text('담당자 확인 필요'), findsOneWidget);
      expect(find.text('확인하고 돌아가기'), findsNothing);
      expect(
        find.byKey(const ValueKey('print-order-request-submit')),
        findsNothing,
      );
      expect(requests.attempts, isEmpty);
    },
  );
  testWidgets(
    'legacy order inquiries keep the order number and use existing support without a payment request',
    (tester) async {
      await pump(
        tester,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  openPrintOrderRequest(context, orderId: 'SF-LEGACY-001'),
              child: const Text('문의'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('문의'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('support-subject')),
            )
            .controller!
            .text,
        '주문 SF-LEGACY-001 문의',
      );
      expect(find.byType(PrintOrderRequestScreen), findsNothing);
      expect(requests.attempts, isEmpty);
    },
  );

  testWidgets(
    'server checkout not-found cannot enable a cancellation for an unknown order',
    (tester) async {
      requests.missingCode = 'print_checkout_not_found';
      await pump(
        tester,
        child: PrintOrderRequestScreen(
          target: PrintOrderRequestTarget.order(fixture.orderId),
          initialReason: '준비를 취소합니다.',
        ),
      );
      final button = find.byKey(const ValueKey('print-order-request-submit'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(requests.attempts, isEmpty);
    },
  );

  testWidgets(
    'completed preparation cancellation clears unstarted recovery only after fresh confirmation',
    (tester) async {
      requests.abortOnCreate = true;
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: fixture.checkoutId,
          albumId: 7,
          amount: 49900,
          orderId: fixture.orderId,
          paymentId: fixture.paymentId,
        ),
      );
      String? outcome;
      await pump(
        tester,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrintOrderRequestScreen(
                      target: PrintOrderRequestTarget.order(fixture.orderId),
                      initialType: 'CANCEL',
                      initialReason: '인쇄 파일을 다시 준비합니다.',
                      returnToAlbumEditing: true,
                    ),
                  ),
                );
              },
              child: const Text('준비 주문 취소'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('준비 주문 취소'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('print-order-request-reason')),
            )
            .controller
            ?.text,
        '인쇄 파일을 다시 준비합니다.',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.tap(
        find.byKey(const ValueKey('print-order-request-submit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('결제 전 준비 주문 취소됨'), findsOneWidget);
      expect(
        await PrintPaymentRecoveryStore().read('fixture-owner'),
        isNotNull,
      );
      await tester.ensureVisible(find.text('앨범 다시 편집하기'));
      await tester.tap(find.text('앨범 다시 편집하기'));
      await tester.pumpAndSettle();
      expect(outcome, 'preparation_aborted');
      expect(await PrintPaymentRecoveryStore().read('fixture-owner'), isNull);
      expect(requests.attempts.length, 1);
    },
  );

  testWidgets(
    'a locally started payment cannot leave through pre-SDK cancellation',
    (tester) async {
      requests.current = PrintOrderRequestResult.fromJson(
        fixture.requestJson(
          status: 'COMPLETED',
          resolution: 'PRE_SDK_ABORTED',
          replacement: true,
          preSdkAbortVerified: true,
        ),
      );
      await PrintPaymentRecoveryStore().write(
        'fixture-owner',
        const PendingPrintPayment(
          requestId: fixture.checkoutId,
          albumId: 7,
          amount: 49900,
          orderId: fixture.orderId,
          paymentId: fixture.paymentId,
          sdkStarted: true,
        ),
      );
      await pump(
        tester,
        child: PrintOrderRequestScreen(
          target: PrintOrderRequestTarget.order(fixture.orderId),
          returnToAlbumEditing: true,
        ),
      );
      await tester.ensureVisible(find.text('앨범 다시 편집하기'));
      await tester.tap(find.text('앨범 다시 편집하기'));
      await tester.pumpAndSettle();
      expect(find.byType(PrintOrderRequestScreen), findsOneWidget);
      expect(find.textContaining('새로운 결제는 아직'), findsOneWidget);
      expect(
        (await PrintPaymentRecoveryStore().read('fixture-owner'))?.sdkStarted,
        isTrue,
      );
    },
  );
}

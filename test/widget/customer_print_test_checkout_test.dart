import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_checkout_screen.dart';
import 'package:snap_fit/features/profile/data/customer_print_test_checkout.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/portone_payment_launcher.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/domain/portone_payment.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';

import '../unit/customer_print_test_checkout_test.dart' as customer;
import '../unit/print_dev_checkout_test.dart' as fixture;

class _Orders extends Mock implements OrderRepository {}

class _Tests extends Mock implements CustomerPrintTestCheckoutService {}

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'fixture-owner';
  void change(String? owner) => state = owner;
}

final _testOwnerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

void main() {
  late _Orders orders;
  late _Tests tests;
  late bool allowed, started;
  late PrintDevCheckoutSession? saved;
  late int launches;
  late Map<String, String>? recipient;

  final quote = OrderQuoteResult.fromJson({
    'amount': 159900,
    'pageCount': 80,
    'sourcePageCount': 80,
    'productCode': 'REDP_300_HARD',
    'supplierCostVerified': true,
    'shippingIncluded': true,
    'spec': fixture.devSpec,
  });

  setUpAll(() {
    registerFallbackValue(
      PrintDevCheckoutSession.fromJson(fixture.devResponse()),
    );
  });

  setUp(() {
    orders = _Orders();
    tests = _Tests();
    allowed = true;
    started = false;
    saved = null;
    launches = 0;
    recipient = null;
    when(
      () => orders.fetchPrintPreviewSnapshot(albumId: 69),
    ).thenAnswer((_) async => fixture.devSnapshot);
    when(() => orders.fetchPrintCheckoutReadiness(albumId: 69)).thenAnswer(
      (_) async => PrintCheckoutReadiness(
        canPay: false,
        status: 'PREPARING',
        reasonCode: 'print_sales_not_ready',
        message: '정식 결제는 준비 중입니다.',
        quote: quote,
      ),
    );
    when(
      () =>
          tests.capability(albumId: 69, reviewedRevision: fixture.devRevision),
    ).thenAnswer(
      (_) async => allowed
          ? CustomerPrintTestCapability.fromJson(
              customer.customerTestCapability(),
            )
          : null,
    );
    when(() => tests.resume()).thenAnswer((_) async => saved);
    when(() => tests.sdkStarted()).thenAnswer((_) async => started);
    when(
      () => tests.prepare(
        albumId: 69,
        reviewedRevision: fixture.devRevision,
        recipient: any(named: 'recipient'),
      ),
    ).thenAnswer((call) async {
      recipient = Map<String, String>.from(
        call.namedArguments[#recipient] as Map,
      );
      return saved = PrintDevCheckoutSession.fromJson({
        ...fixture.devResponse(),
        'recipient': recipient,
      });
    });
    when(
      () => tests.prepareFiles(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer(
      (_) async => saved = PrintDevCheckoutSession.fromJson({
        ...fixture.devResponse(packageState: 'READY'),
        'recipient': recipient,
      }),
    );
    when(() => tests.authorize(any())).thenAnswer((_) async {
      started = true;
      return saved = PrintDevCheckoutSession.fromJson({
        ...fixture.devResponse(packageState: 'READY', sdk: fixture.devSdk()),
        'recipient': recipient,
        'sdkIssuedAt': '2026-10-15T07:00:00Z',
      });
    });
    when(() => tests.assertCanLaunch(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {ValueChanged<String>? onOpen}) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderRepositoryProvider.overrideWithValue(orders),
          visibleOrderOwnerProvider.overrideWith(
            (ref) => ref.watch(_testOwnerProvider),
          ),
          customerPrintTestCheckoutServiceProvider.overrideWithValue(tests),
          portOnePaymentLauncherProvider.overrideWithValue((
            context,
            sdk,
          ) async {
            launches++;
            expect(sdk.paymentId, fixture.devPayment);
            expect(sdk.channelKey, PrintDevCheckoutSession.testChannelKey);
            return const PortOneSdkResult.canceled();
          }),
        ],
        child: MaterialApp(
          home: PrintOrderCheckoutScreen(
            albumId: 69,
            albumTitle: 'TEST 80페이지 앨범',
            initialQuote: quote,
            reviewedRevision: fixture.devRevision,
            testMode: true,
            onOpenTestOrder: onOpen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('print-checkout-content')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    for (final entry in {
      'print-recipient-name': 'TEST 수령인',
      'print-recipient-phone': '01000000000',
      'print-zip-code': '12345',
      'print-address-line1': 'TEST 도로 1',
      'print-address-line2': 'TEST 상세',
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await visible(tester, field);
      await tester.enterText(field, entry.value);
    }
    await visible(tester, find.text('주문 내용 확인하기'));
    await tester.tap(find.text('주문 내용 확인하기'));
    await tester.pumpAndSettle();
    for (final key in [
      'print-checkout-agreement',
      'print-checkout-policy-agreement',
      'print-checkout-custom-production-agreement',
    ]) {
      final agreement = find.byKey(ValueKey(key));
      await visible(tester, agreement);
      await tester.tap(agreement);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'normal delivery and review use only strict TEST pipeline; SDK return is never payment evidence',
    (tester) async {
      String? historyRun;
      await pump(tester, onOpen: (id) => historyRun = id);
      await review(tester);
      expect(find.text('159,900원 TEST 결제하기'), findsOneWidget);
      final pay = find.byKey(const ValueKey('print-checkout-payment'));
      expect(tester.widget<FilledButton>(pay).onPressed, isNotNull);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      expect(launches, 1);
      expect(recipient?['addressLine1'], 'TEST 도로 1');
      expect(tester.widget<FilledButton>(pay).onPressed, isNull);
      await tester.drag(
        find.byKey(const PageStorageKey('print-checkout-content')),
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('앱을 닫아도 TEST 결제 확인'), findsOneWidget);
      expect(find.textContaining('서버에서 포트원 TEST 승인 내역을 확인했습니다.'), findsNothing);
      final history = find.byKey(const ValueKey('print-test-order-history'));
      await visible(tester, history);
      await tester.tap(history);
      expect(historyRun, fixture.devRun);
      verifyNever(() => orders.confirmPrintPayment(any()));
      verifyNever(
        () => orders.fetchPrintPaidReceipt(
          orderId: any(named: 'orderId'),
          albumId: any(named: 'albumId'),
          expectedAmount: any(named: 'expectedAmount'),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'caller TEST flag alone cannot open payment without server capability',
    (tester) async {
      allowed = false;
      await pump(tester);
      await review(tester);
      final pay = find.byKey(const ValueKey('print-checkout-payment'));
      expect(tester.widget<FilledButton>(pay).onPressed, isNull);
      expect(launches, 0);
      verifyNever(
        () => tests.prepare(
          albumId: any(named: 'albumId'),
          reviewedRevision: any(named: 'reviewedRevision'),
          recipient: any(named: 'recipient'),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reopening restores frozen delivery and reads the same started TEST order without relaunch',
    (tester) async {
      started = true;
      saved = PrintDevCheckoutSession.fromJson({
        ...fixture.devResponse(packageState: 'READY'),
        'sdkIssuedAt': '2026-10-15T07:00:00Z',
        'recipient': {
          'name': '동일 주문 수령인',
          'phone': '01000000000',
          'zipCode': '12345',
          'addressLine1': '동일 주문 도로',
          'addressLine2': '동일 상세',
        },
      });
      await pump(tester);
      expect(find.textContaining('동일 주문 수령인'), findsOneWidget);
      final pay = find.byKey(const ValueKey('print-checkout-payment'));
      expect(tester.widget<FilledButton>(pay).onPressed, isNull);
      expect(launches, 0);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      verify(() => tests.resume()).called(2);
      verifyNever(() => tests.authorize(any()));
      verifyNever(() => orders.confirmPrintPayment(any()));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account changes immediately hide a restored address and stop TEST reads',
    (tester) async {
      started = true;
      saved = PrintDevCheckoutSession.fromJson({
        ...fixture.devResponse(packageState: 'READY'),
        'sdkIssuedAt': '2026-10-15T07:00:00Z',
        'recipient': {'name': '첫 계정 수령인', 'addressLine1': '첫 계정 비공개 주소'},
      });
      await pump(tester);
      expect(find.textContaining('첫 계정 수령인'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PrintOrderCheckoutScreen)),
      );
      container.read(_testOwnerProvider.notifier).change('second-owner');
      await tester.pumpAndSettle();
      expect(find.textContaining('첫 계정 수령인'), findsNothing);
      expect(find.textContaining('첫 계정 비공개 주소'), findsNothing);
      expect(
        find.byKey(const ValueKey('print-checkout-payment')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      verify(() => tests.resume()).called(1);
      expect(launches, 0);
      container.read(_testOwnerProvider.notifier).change('fixture-owner');
      await tester.pumpAndSettle();
      expect(find.textContaining('첫 계정 수령인'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('print-checkout-payment')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

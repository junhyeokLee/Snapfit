import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/customer_print_test_checkout.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_dev_checkout.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/order_history_screen.dart';

class _Orders extends Mock implements OrderRepository {}

class _TestOrders extends Mock implements CustomerPrintTestCheckoutService {}

class _Auth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => const UserInfo(
    id: 'owner',
    name: '테스트 고객',
    email: 'owner@example.com',
    provider: 'EMAIL',
  );
}

const _run = '11111111-1111-4111-8111-111111111111';
const _payment = 'SFPGT_33333333-3333-4333-8333-333333333333';

CustomerPrintTestOrder _order({
  String stage = 'READY',
  bool paid = false,
  bool detail = false,
}) => CustomerPrintTestOrder.fromJson({
  'environment': 'test',
  'isTest': true,
  'productionApproved': false,
  'runId': _run,
  'orderId': 'ordp_$_run',
  'paymentId': _payment,
  'requestId': '22222222-2222-4222-8222-222222222222',
  'albumId': 69,
  'totalAmount': 159900,
  'reviewedRevision': 'a' * 64,
  'reviewedSpecRevision': 'b' * 64,
  'status': paid ? 'VERIFIED_TEST' : 'PREPARED',
  'stage': stage,
  'packageState': 'READY',
  'sdkIssuedAt': '2026-10-15T04:00:00Z',
  'albumTitle': '일반 화면 TEST 앨범',
  'createdAt': '2026-10-15T03:00:00Z',
  if (paid)
    'receipt': {
      'provider': 'PORTONE',
      'version': 'V2',
      'status': 'PAID',
      'environment': 'test',
      'isTest': true,
      'paymentId': _payment,
      'amount': 159900,
      'currency': 'KRW',
      'storeId': PrintDevCheckoutSession.testStoreId,
      'channelKey': PrintDevCheckoutSession.testChannelKey,
      'transactionId': 'test-transaction',
      'paidAt': '2026-10-15T04:01:00Z',
    },
  if (stage == 'FILE_CHECKED')
    'vendorStatus': {
      'fileProcessYn': 'Y',
      'statusCode': 'PGS_06',
      'statusCodeOrg': 'PGS_05',
    },
  if (stage == 'FILE_CHECKED' || stage == 'UNKNOWN')
    'devOrderNum': 'SFD11111111111141118111111111111111',
  if (detail)
    'recipient': {
      'name': 'TEST 수령인',
      'phone': '01000000000',
      'zipCode': '12345',
      'addressLine1': '테스트 전용 도로 1',
      'addressLine2': '시험 주소',
      'deliveryMemo': '',
    },
});

void main() {
  late _Orders production;
  late _TestOrders tests;
  late CustomerPrintTestOrder current;
  var reads = 0;
  var fail = false;
  setUp(() {
    production = _Orders();
    tests = _TestOrders();
    current = _order(detail: true);
    reads = 0;
    fail = false;
    when(
      () => production.fetchMyOrdersPage(
        statuses: any(named: 'statuses'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer(
      (_) async => const OrderPageResult(
        items: [],
        page: 0,
        size: 20,
        totalPages: 0,
        totalElements: 0,
        hasNext: false,
      ),
    );
    when(() => tests.history()).thenAnswer((_) async => [_order()]);
    when(() => tests.detail(_run)).thenAnswer((_) async {
      reads++;
      if (fail) throw StateError('offline');
      return current;
    });
  });

  Future<void> mount(
    WidgetTester tester, {
    bool admin = true,
    bool initial = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          orderRepositoryProvider.overrideWithValue(production),
          printDevAdminAccessProvider.overrideWithValue(admin),
          customerPrintTestCheckoutServiceProvider.overrideWithValue(tests),
        ],
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          home: OrderHistoryScreen(initialTestRunId: initial ? _run : null),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('TEST records are separate from default production history', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('일반 화면 TEST 앨범'), findsNothing);
    expect(find.byKey(const ValueKey('order-history-mode')), findsOneWidget);
    await tester.tap(find.text('TEST 주문'));
    await tester.pumpAndSettle();
    expect(find.text('일반 화면 TEST 앨범'), findsOneWidget);
    expect(find.textContaining('실제 청구·제작·배송 없음'), findsOneWidget);
    expect(find.text('TEST 수령인'), findsNothing);
    verifyNever(() => production.fetchMyPrintOrder(any()));
    await dispose(tester);
  });

  testWidgets(
    'non-admin cannot see TEST history or open requested TEST detail',
    (tester) async {
      await mount(tester, admin: false, initial: true);
      expect(find.byKey(const ValueKey('order-history-mode')), findsNothing);
      expect(
        find.byKey(const ValueKey('customer-test-order-detail')),
        findsNothing,
      );
      verifyNever(() => tests.history());
      verifyNever(() => tests.detail(any()));
      await dispose(tester);
    },
  );

  testWidgets(
    'initial TEST detail requires a successful server list permission check',
    (tester) async {
      when(
        () => tests.history(),
      ).thenThrow(const PrintDevCheckoutException('forbidden'));
      await mount(tester, initial: true);
      expect(find.byKey(const ValueKey('order-history-mode')), findsNothing);
      expect(
        find.byKey(const ValueKey('customer-test-order-detail')),
        findsNothing,
      );
      verifyNever(() => tests.detail(any()));
      await dispose(tester);
    },
  );

  testWidgets(
    'saved TEST detail follows confirmed payment and automatic file analysis',
    (tester) async {
      await mount(tester, initial: true);
      expect(find.text('TEST 결제 확인 중'), findsWidgets);
      expect(find.text('TEST 결제 확인 · 대기'), findsOneWidget);
      current = _order(stage: 'UNKNOWN', paid: true, detail: true);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('업체 접수 확인 중'), findsWidgets);
      expect(find.text('업체 개발 접수 · 대기'), findsOneWidget);
      current = _order(stage: 'FILE_CHECKED', paid: true, detail: true);
      await tester.tap(
        find.byKey(const ValueKey('customer-test-detail-refresh')),
      );
      await tester.pumpAndSettle();
      expect(find.text('업체 파일 확인 완료'), findsWidgets);
      expect(find.text('업체 파일 확인 · 완료'), findsOneWidget);
      expect(find.textContaining('앱을 닫아도'), findsOneWidget);
      expect(reads, 3);
      verifyNever(() => production.fetchMyPrintOrder(any()));
      expect(tester.takeException(), isNull);
      await dispose(tester);
    },
  );

  testWidgets(
    'failed detail reads do not invent a paid or accepted TEST order',
    (tester) async {
      await mount(tester, initial: true);
      fail = true;
      await tester.tap(
        find.byKey(const ValueKey('customer-test-detail-refresh')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('customer-test-detail-error')),
        findsOneWidget,
      );
      expect(find.text('TEST 결제 확인 · 대기'), findsOneWidget);
      expect(find.text('업체 개발 접수 · 대기'), findsOneWidget);
      expect(find.text('업체 파일 확인 완료'), findsNothing);
      await dispose(tester);
    },
  );

  testWidgets(
    'background suspends reads and resume queries the same TEST run',
    (tester) async {
      await mount(tester, initial: true);
      final before = reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 41));
      expect(reads, before);
      current = _order(stage: 'FILE_CHECKED', paid: true, detail: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, before + 1);
      expect(find.text('업체 파일 확인 완료'), findsWidgets);
      await dispose(tester);
    },
  );

  testWidgets(
    'SDK owner change hides TEST recipient before cached profile updates',
    (tester) async {
      await mount(tester, initial: true);
      await tester.scrollUntilVisible(
        find.text('TEST 수령인'),
        220,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('customer-test-order-detail')),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('TEST 수령인'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrderHistoryScreen)),
      );
      container
          .read(orderSessionOwnerProvider.notifier)
          .observe('another-owner');
      await tester.pumpAndSettle();
      expect(container.read(authViewModelProvider).asData?.value?.id, 'owner');
      expect(find.text('TEST 수령인'), findsNothing);
      expect(find.textContaining('테스트 전용 도로'), findsNothing);
      expect(find.text('일반 화면 TEST 앨범'), findsNothing);
      final before = reads;
      await tester.pump(const Duration(seconds: 40));
      expect(reads, before);
      await dispose(tester);
    },
  );
}

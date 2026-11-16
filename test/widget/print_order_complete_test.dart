import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_complete_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class _Orders extends Mock implements OrderRepository {}

void main() {
  late _Orders orders;
  setUp(() => orders = _Orders());
  Future<void> pump(WidgetTester tester, PrintOrderProgress progress) async {
    when(
      () => orders.fetchMyPrintOrderProgress('owned-order'),
    ).thenAnswer((_) async => progress);
    final receipt = PrintPaidReceipt.fromOrder(
      OrderHistoryItem(
        orderId: 'owned-order',
        albumId: 7,
        title: '합성 앨범',
        amount: 49900,
        status: 'PAYMENT_COMPLETED',
        statusLabel: '결제완료',
        progress: .25,
        orderedAt: DateTime.utc(2026, 10, 14),
        paymentConfirmedAt: DateTime.utc(2026, 10, 14, 1),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(orders)],
        child: MaterialApp(home: PrintOrderCompleteScreen(receipt: receipt)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> stage(WidgetTester tester, String label, bool confirmed) async {
    final row = find.byKey(ValueKey('print-progress-$label'));
    if (row.evaluate().isEmpty) {
      final toggle = find.byKey(
        const PageStorageKey('print-progress-timeline'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(row);
    await tester.pump();
    expect(
      find.descendant(of: row, matching: find.text(confirmed ? '확인 완료' : '대기')),
      findsOneWidget,
    );
  }

  testWidgets(
    'a paid receipt never implies files, vendor acceptance, production or shipment',
    (tester) async {
      await pump(
        tester,
        const PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'PAID',
          preflightPassed: false,
          requiresAction: false,
        ),
      );
      await stage(tester, '결제 확인', true);
      for (final label in [
        '인쇄 파일 생성',
        '인쇄 규격 검사',
        '제작사 주문 접수',
        '제작사 파일 확인',
        '책 제작',
        '택배 출고',
        '배송 완료',
      ]) {
        await stage(tester, label, false);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'vendor accepted timestamp cannot imply vendor file check or actual production',
    (tester) async {
      await pump(
        tester,
        PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'FILE_CHECKING',
          preflightPassed: true,
          requiresAction: false,
          filesReadyAt: DateTime.utc(2026, 10, 14, 2),
          vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
        ),
      );
      expect(find.text('제작사 파일 확인 중'), findsOneWidget);
      await stage(tester, '제작사 주문 접수', true);
      await stage(tester, '제작사 파일 확인', false);
      await stage(tester, '책 제작', false);
      await stage(tester, '택배 출고', false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'shipment needs carrier, tracking and handoff timestamp and never means delivered',
    (tester) async {
      await pump(
        tester,
        PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'SHIPPING',
          preflightPassed: true,
          requiresAction: false,
          filesReadyAt: DateTime.utc(2026, 10, 14, 2),
          vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
          fileCheckedAt: DateTime.utc(2026, 10, 14, 4),
          productionStartedAt: DateTime.utc(2026, 10, 14, 5),
          shippedAt: DateTime.utc(2026, 10, 14, 6),
          courier: '테스트 택배',
          trackingNumber: '0000000000',
        ),
      );
      await stage(tester, '제작사 파일 확인', true);
      await stage(tester, '책 제작', true);
      await stage(tester, '택배 출고', true);
      await stage(tester, '배송 완료', false);
      expect(find.text('테스트 택배 · 0000000000'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'file errors show an action notice without marking file check done',
    (tester) async {
      await pump(
        tester,
        PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'REVIEW_REQUIRED',
          preflightPassed: true,
          requiresAction: true,
          vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
        ),
      );
      expect(find.textContaining('담당자가 확인하고 있습니다'), findsOneWidget);
      await stage(tester, '제작사 파일 확인', false);
      await stage(tester, '책 제작', false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'completion prioritizes the real current and next stage with the full timeline collapsed',
    (tester) async {
      await pump(
        tester,
        PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'FILE_CHECKING',
          preflightPassed: true,
          requiresAction: false,
          filesReadyAt: DateTime.utc(2026, 10, 14, 2),
          vendorAcceptedAt: DateTime.utc(2026, 10, 14, 3),
        ),
      );
      final current = find.byKey(const ValueKey('print-progress-current'));
      expect(current, findsOneWidget);
      expect(
        find.descendant(of: current, matching: find.text('제작사 파일 확인 중')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: current, matching: find.text('다음 예정 단계')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: current, matching: find.text('책 제작')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('print-progress-제작사 파일 확인')),
        findsNothing,
      );
      final toggle = find.byKey(
        const PageStorageKey('print-progress-timeline'),
      );
      expect(
        tester.getTopLeft(current).dy,
        lessThan(tester.getTopLeft(toggle).dy),
      );
      await stage(tester, '제작사 주문 접수', true);
      await stage(tester, '제작사 파일 확인', false);
      await stage(tester, '책 제작', false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'completion exposes amount and order number before optional timeline details',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        const PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'PAID',
          preflightPassed: false,
          requiresAction: false,
        ),
      );
      final amount = find.byKey(const ValueKey('print-receipt-amount'));
      expect(amount, findsOneWidget);
      expect(
        find.descendant(of: amount, matching: find.text('49,900원')),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.getBottomRight(amount).dy, lessThan(844));
      expect(
        tester.getBottomRight(find.byType(SelectableText)).dy,
        lessThan(844),
      );
      expect(find.byKey(const ValueKey('print-progress-책 제작')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final stageName in ['CANCELED', 'REVIEW_REQUIRED', 'REFUND_REQUESTED']) {
    testWidgets('completion does not predict production for $stageName', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        const PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'PAID',
          preflightPassed: false,
          requiresAction: false,
        ),
      );
      when(() => orders.fetchMyPrintOrderProgress('owned-order')).thenAnswer(
        (_) async => PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: stageName,
          preflightPassed: false,
          requiresAction: stageName == 'REVIEW_REQUIRED',
        ),
      );
      await tester.tap(find.byTooltip('진행 상황 새로고침'));
      await tester.pumpAndSettle();
      final current = find.byKey(const ValueKey('print-progress-current'));
      expect(current, findsOneWidget);
      expect(
        find.descendant(of: current, matching: find.text('다음 예정 단계')),
        findsNothing,
      );
      expect(find.text('환불 완료'), findsNothing);
      if (stageName == 'CANCELED')
        expect(find.text('주문이 취소됐어요'), findsOneWidget);
      if (stageName == 'REVIEW_REQUIRED')
        expect(find.textContaining('담당자가 확인하고 있습니다'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'completion keeps the paid receipt visible when the latest progress read fails',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        const PrintOrderProgress(
          orderId: 'owned-order',
          customerStage: 'PAID',
          preflightPassed: false,
          requiresAction: false,
        ),
      );
      when(
        () => orders.fetchMyPrintOrderProgress('owned-order'),
      ).thenThrow(StateError('synthetic progress read failure'));
      await tester.tap(find.byTooltip('진행 상황 새로고침'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('print-receipt-amount')),
        findsOneWidget,
      );
      expect(find.text('결제가 확인됐어요'), findsOneWidget);
      final current = find.byKey(const ValueKey('print-progress-current'));
      expect(
        find.descendant(of: current, matching: find.text('다음 예정 단계')),
        findsNothing,
      );
      expect(find.textContaining('진행 상황을 불러오지 못했어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

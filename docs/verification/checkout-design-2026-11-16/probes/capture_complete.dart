// Synthetic owned-order fixtures exercise the real completion widget without live requests.
import 'file:///tmp/snapfit-checkout-design-20261116/audit_support.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/views/print_order_complete_screen.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/domain/print_checkout.dart';

class _Orders extends Mock implements OrderRepository {}

void main() {
  setUpAll(auditFonts);
  late _Orders orders;
  setUp(() => orders = _Orders());

  Future<void> pump(
    WidgetTester tester,
    PrintOrderProgress progress, {
    Size size = const Size(390, 844),
    bool dark = false,
    double textScale = 1,
  }) async {
    auditViewport(tester, size: size);
    when(() => orders.fetchMyPrintOrderProgress('owned-order'))
        .thenAnswer((_) async => progress);
    final receipt = PrintPaidReceipt.fromOrder(
      OrderHistoryItem(
        orderId: 'owned-order',
        albumId: 7,
        title: '우리가 함께한 가을',
        amount: 49900,
        status: 'PAYMENT_COMPLETED',
        statusLabel: '결제완료',
        progress: .25,
        orderedAt: DateTime.utc(2026, 11, 16),
        paymentConfirmedAt: DateTime.utc(2026, 11, 16, 1),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(orders)],
        child: MaterialApp(
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: auditFrame(child!),
          ),
          home: PrintOrderCompleteScreen(receipt: receipt),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder progressScrollable() => find.descendant(
        of: find.byKey(const PageStorageKey('print-progress-content')),
        matching: find.byType(Scrollable),
      ).first;

  Future<void> show(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 160,
          scrollable: progressScrollable());
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  // Unmount before every test finishes so the screen's refresh timer is disposed.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  PrintOrderProgress fileChecking() => PrintOrderProgress(
        orderId: 'owned-order',
        customerStage: 'FILE_CHECKING',
        preflightPassed: true,
        requiresAction: false,
        filesReadyAt: DateTime.utc(2026, 11, 16, 2),
        vendorAcceptedAt: DateTime.utc(2026, 11, 16, 3),
      );

  testWidgets('capture complete file checking light phone 390x844',
      (tester) async {
    await pump(tester, fileChecking());
    await auditCapture(tester, '09-complete-file-checking-top-390-light');
    final current = find.byKey(const ValueKey('print-progress-current'));
    await show(tester, current);
    expect(find.byKey(const ValueKey('print-progress-책 제작')), findsNothing);
    await auditCapture(tester, '10-complete-current-next-collapsed-390-light');

    final timeline =
        find.byKey(const PageStorageKey('print-progress-timeline'));
    await show(tester, timeline);
    await tester.tap(timeline);
    await tester.pumpAndSettle();
    await show(tester, timeline);
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('print-progress-제작사 파일 확인')),
          matching: find.text('대기')),
      findsOneWidget,
    );
    await auditCapture(tester, '11-complete-expanded-timeline-390-light');
    await unmount(tester);
  });

  testWidgets('capture complete review required light phone 390x844',
      (tester) async {
    await pump(
      tester,
      PrintOrderProgress(
        orderId: 'owned-order',
        customerStage: 'REVIEW_REQUIRED',
        preflightPassed: true,
        requiresAction: true,
        filesReadyAt: DateTime.utc(2026, 11, 16, 2),
        vendorAcceptedAt: DateTime.utc(2026, 11, 16, 3),
      ),
    );
    await show(tester, find.byKey(const ValueKey('print-progress-current')));
    await auditCapture(tester, '12-complete-review-required-390-light');
    await unmount(tester);
  });

  testWidgets('capture complete paid small dark phone 320x568 scale 1.6',
      (tester) async {
    await pump(
      tester,
      const PrintOrderProgress(
        orderId: 'owned-order',
        customerStage: 'PAID',
        preflightPassed: false,
        requiresAction: false,
      ),
      size: const Size(320, 568),
      dark: true,
      textScale: 1.6,
    );
    await auditCapture(tester, '13-complete-paid-top-320-dark-text160');
    await show(tester, find.byKey(const ValueKey('print-progress-current')));
    await auditCapture(tester, '14-complete-paid-current-320-dark-text160');
    await unmount(tester);
  });

  testWidgets('capture complete file checking dark landscape 844x390 scale 1.8',
      (tester) async {
    await pump(tester, fileChecking(),
        size: const Size(844, 390), dark: true, textScale: 1.8);
    await auditCapture(tester, '15-complete-file-checking-844-dark-text180');
    await unmount(tester);
  });
}

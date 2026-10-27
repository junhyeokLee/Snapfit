import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_document.dart';

/// Asset reads and native workers use real time, outside the fake frame clock.
/// Await those jobs without waiting for a deliberately pending purchase spinner.
Future<void> flushStoreDetailDocuments(WidgetTester tester) async {
  for (
    var attempt = 0;
    attempt < 1000 && TemplateDetailDocuments.hasPendingWork;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(
    TemplateDetailDocuments.hasPendingWork,
    isFalse,
    reason: 'Detail document worker did not finish',
  );
  await tester.pump();
}

Future<void> settleStoreDetail(WidgetTester tester) async {
  // A confirmed edition keeps its action spinner until its native worker
  // finishes. Let real work progress before asking the fake clock to settle.
  await tester.pump();
  for (var frame = 0; frame < 30; frame++) {
    await flushStoreDetailDocuments(tester);
    if (!tester.binding.hasScheduledFrame) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// Drain native jobs before this test's fake clock is destroyed, including
/// navigation tests that intentionally leave during the entry transition.
void storeDetailTestWidgets(
  String description,
  Future<void> Function(WidgetTester) callback, {
  bool skip = false,
}) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await flushStoreDetailDocuments(tester);
    }
  }, skip: skip);
}

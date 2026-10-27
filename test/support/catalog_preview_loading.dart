import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

/// Native isolates complete outside widget tests' fake clock. Flush their
/// result back through that clock without assuming a device-specific duration.
Future<CatalogPreview?> loadCatalogPreview(
  WidgetTester tester,
  PremiumTemplate template,
) async {
  CatalogPreview? preview;
  var completed = false;
  final future = CatalogPreviews.request(template);
  future.then((value) {
    preview = value;
    completed = true;
  });
  for (var attempt = 0; attempt < 500 && !completed; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(completed, isTrue, reason: '${template.title} preview did not finish');
  expect(preview, isNotNull, reason: '${template.title} has no preview');
  await tester.pump();
  return preview;
}

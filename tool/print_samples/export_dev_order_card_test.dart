import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'redprinting_soft_sample.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('export synthetic source for the owned development album', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final target =
          Platform.environment['SNAPFIT_DEV_CARD_OUTPUT'] ??
          '/private/tmp/snapfit-dev-order-e2e-20261015/generated-test-card.png';
      if (!target.startsWith('/'))
        throw StateError('dev_card_absolute_path_required');
      final bytes = await generatedSampleTestCard();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, 4800);
          expect(frame.image.height, 3600);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      final output = File(target);
      output.parent.createSync(recursive: true);
      await output.writeAsBytes(bytes, flush: true);
      expect(output.lengthSync(), greaterThan(0));
    });
  });
}

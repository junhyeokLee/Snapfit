import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/utils/reader_image_quality.dart';

void main() {
  test(
    'dense screens gain detail while long books retain a fixed texture budget',
    () {
      for (final page in [const Size(180, 240), const Size(400, 300)]) {
        for (final count in [4, 26, 82]) {
          final ratio = readerCapturePixelRatio(page, count, 3);
          expect(ratio, greaterThan(0));
          expect(ratio, lessThanOrEqualTo(3));
          expect(
            page.width * page.height * count * ratio * ratio * 4,
            lessThanOrEqualTo(readerCaptureByteBudget + .01),
          );
          if (count <= 26) expect(ratio, greaterThan(1));
        }
      }
    },
  );

  test('one-density screens never allocate extra texture pixels', () {
    expect(readerCapturePixelRatio(const Size(180, 240), 26, 1), 1);
  });

  test('live page decode width follows physical pixels and stays bounded', () {
    expect(readerPageDecodeWidth(const Size(180, 240), 3), 720);
    expect(readerPageDecodeWidth(const Size(900, 1200), 3), 1600);
    expect(readerPageDecodeWidth(const Size(20, 20), 1), 128);
  });
}

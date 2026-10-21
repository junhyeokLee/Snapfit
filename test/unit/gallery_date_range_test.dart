import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/models/gallery_date_range.dart';

void main() {
  test('inclusive local dates cover the full last day and year boundary', () {
    final range = GalleryDateRange(
      DateTime(2023, 12, 31, 19, 30),
      DateTime(2024, 1, 1, 1),
    );
    expect(range.start, DateTime(2023, 12, 31));
    expect(range.end, DateTime(2024, 1, 1));
    expect(range.endExclusive, DateTime(2024, 1, 2));
    expect(range.lastInstant, DateTime(2024, 1, 1, 23, 59, 59, 999));
    expect(range.start.isUtc, isFalse);
    expect(range.endExclusive.isUtc, isFalse);
    expect(
      range,
      GalleryDateRange(DateTime(2023, 12, 31), DateTime(2024, 1, 1)),
    );
  });

  test('one day includes its evening, while reversed dates are rejected', () {
    final range = GalleryDateRange(
      DateTime(2024, 2, 29),
      DateTime(2024, 2, 29),
    );
    expect(range.endExclusive, DateTime(2024, 3, 1));
    expect(DateTime(2024, 2, 29, 23, 59).isBefore(range.endExclusive), isTrue);
    expect(
      () => GalleryDateRange(DateTime(2024, 3, 1), DateTime(2024, 2, 29)),
      throwsArgumentError,
    );
  });
}

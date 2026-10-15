import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';

import 'hardcover_print_export_test.dart' as official;

void main() {
  test(
    'decimal casewrap edges tolerate binary rounding for 36-page template',
    () {
      final source = PrintVendorSpec.fromJson(
        official.officialHardSpec('REDP_200X150_HARD'),
      );
      final cover = source.officialCoverGeometryForSpine(14.46);
      final spec = PrintVendorSpec.fromJson({
        ...source.toJson(),
        'pageCount': 36,
        'spineMm': 14.46,
        'cover': cover,
      });
      expect(spec.front.right, closeTo(spec.coverTrim.right, 1e-10));
      expect(spec.coverSize.width, closeTo(466.46, 1e-10));
      expect(spec.verified, isFalse);
    },
  );

  test('genuine cover trim overrun remains rejected', () {
    final source = PrintVendorSpec.fromJson(
      official.officialHardSpec('REDP_200X150_HARD'),
    );
    final cover = source.officialCoverGeometryForSpine(14.46);
    final trim = Map<String, dynamic>.from(cover['trim'] as Map);
    trim['widthMm'] = (trim['widthMm'] as num) - .0001;
    expect(
      () => PrintVendorSpec.fromJson({
        ...source.toJson(),
        'pageCount': 36,
        'cover': {...cover, 'trim': trim},
      }),
      throwsFormatException,
    );
  });
}

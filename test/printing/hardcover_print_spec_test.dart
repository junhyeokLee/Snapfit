import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'five_print_sizes_test.dart' as soft;
import 'hardcover_print_export_test.dart' as official;

// Synthetic validation fixture only. Production geometry comes from the vendor.
Map<String, dynamic> syntheticHardSpec(PrintProduct product) {
  final w = product.trimWidthMm, h = product.trimHeightMm;
  return {
    'id': product.id,
    'specVersion': '${product.id}_REVIEW_V3_TEST',
    'geometrySource': 'Synthetic test geometry; not a manufacturing template.',
    'pageCount': 20,
    'interior': {'trimWidthMm': w, 'trimHeightMm': h, 'bleedMm': 5},
    'cover': {
      'construction': 'casewrap',
      'bleedMm': 0,
      'widthMm': 2 * w + 70,
      'heightMm': h + 46,
      'trim': {'xMm': 0, 'yMm': 0, 'widthMm': 2 * w + 70, 'heightMm': h + 46},
      'back': {'xMm': 20, 'yMm': 20, 'widthMm': w + 3, 'heightMm': h + 6},
      'front': {'xMm': w + 47, 'yMm': 20, 'widthMm': w + 3, 'heightMm': h + 6},
    },
  };
}

void main() {
  test(
    'official spine adjustment shifts front/media/trim only without mutating source',
    () {
      final spec = PrintVendorSpec.fromJson(
        official.officialHardSpec('REDP_200X150_HARD'),
      );
      final adjusted = spec.officialCoverGeometryForSpine(9.77);
      expect(adjusted['widthMm'], closeTo(461.77, .001));
      expect(adjusted['front']['xMm'], closeTo(235.77, .001));
      expect(adjusted['trim']['widthMm'], closeTo(421.77, .001));
      expect(adjusted['back'], spec.toJson()['cover']['back']);
      expect(spec.front.left, closeTo(235.10, .001));
      final custom = PrintVendorSpec.fromJson({
        ...spec.toJson(),
        'coverGeometrySource': 'admin_override',
      });
      expect(
        () => custom.officialCoverGeometryForSpine(9.77),
        throwsFormatException,
      );
      expect(
        () => spec.officialCoverGeometryForSpine(double.nan),
        throwsFormatException,
      );
    },
  );
  for (final softId in soft.products) {
    final id = softId.replaceFirst('_SOFT', '_HARD');
    test(
      'hardcover $id retains type and requires distinct explicit wrap geometry',
      () {
        final product = PrintProduct.forId(id)!;
        expect(product.isHardcover, isTrue);
        expect(product.label, contains('하드커버'));
        final document = PrintAlbumDocument.fromSnapshot(
          soft.productSnapshot(product),
        );
        final raw = syntheticHardSpec(product);
        final spec = PrintVendorSpec.fromJson(raw);
        document.validateSpec(spec);
        expect(spec.front.width, product.trimWidthMm + 3);
        expect(spec.front.height, product.trimHeightMm + 6);
        expect(spec.coverTrim.width, spec.coverSize.width);
        expect(spec.coverBleedMm, 0);
        expect(spec.bleedMm, 5);
        expect(spec.productLabel, product.label);
        final wrong = soft.productSpec(PrintProduct.forId(softId)!);
        wrong['id'] = id;
        expect(() => PrintVendorSpec.fromJson(wrong), throwsFormatException);
        expect(
          () => document.validateSpec(
            PrintVendorSpec.fromJson(
              soft.productSpec(PrintProduct.forId(softId)!),
            ),
          ),
          throwsFormatException,
        );
        final outOfBounds = syntheticHardSpec(product);
        outOfBounds['cover']['trim']['widthMm'] = 999;
        expect(
          () => PrintVendorSpec.fromJson(outOfBounds),
          throwsFormatException,
        );
      },
    );
  }
}

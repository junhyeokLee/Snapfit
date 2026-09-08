import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'five_print_sizes_test.dart' as fixtures;
import 'print_album_export_test.dart' as artwork;

// Official PHBKMYB common review profile: board=trim+6mm, wrap20mm,
// spine=2.4+.67*(pages/2). All five 20p sizes and 300x300 80p guides checked.
// These are review PDFs; supplier production acceptance is still pending.
const measuredHard20p = {
  'REDP_200X150_HARD': (
    mediaWidth: 461.10,
    mediaHeight: 196.0,
    boardWidth: 206.0,
    boardHeight: 156.0,
    frontX: 235.10,
    spine: 9.10,
  ),
  'REDP_200_HARD': (
    mediaWidth: 461.10,
    mediaHeight: 246.0,
    boardWidth: 206.0,
    boardHeight: 206.0,
    frontX: 235.10,
    spine: 9.10,
  ),
  'REDP_250X200_HARD': (
    mediaWidth: 561.10,
    mediaHeight: 246.0,
    boardWidth: 256.0,
    boardHeight: 206.0,
    frontX: 285.10,
    spine: 9.10,
  ),
  'REDP_250_HARD': (
    mediaWidth: 561.10,
    mediaHeight: 296.0,
    boardWidth: 256.0,
    boardHeight: 256.0,
    frontX: 285.10,
    spine: 9.10,
  ),
  'REDP_300_HARD': (
    mediaWidth: 661.10,
    mediaHeight: 346.0,
    boardWidth: 306.0,
    boardHeight: 306.0,
    frontX: 335.10,
    spine: 9.10,
  ),
};

Map<String, dynamic> officialHardSpec(String id) {
  final product = PrintProduct.forId(id)!;
  final g = measuredHard20p[id]!;
  return {
    'id': id,
    'specVersion': '${id}_REVIEW_V3_OFFICIAL_20P',
    'geometrySource':
        'Redprinting PHBKMYB common review profile checked with official20p/80p guides, 2026-09-08',
    'coverGeometrySource': 'official_default',
    'templateFamily': 'REDP_PHBKMYB_CASEWRAP',
    'verified': false,
    'pageCount': 20,
    'spineMm': g.spine,
    'interior': {
      'trimWidthMm': product.trimWidthMm,
      'trimHeightMm': product.trimHeightMm,
      'bleedMm': 5,
    },
    'cover': {
      'construction': 'casewrap',
      'bleedMm': 20,
      'widthMm': g.mediaWidth,
      'heightMm': g.mediaHeight,
      'front': {
        'xMm': g.frontX,
        'yMm': 20,
        'widthMm': g.boardWidth,
        'heightMm': g.boardHeight,
      },
      'back': {
        'xMm': 20,
        'yMm': 20,
        'widthMm': g.boardWidth,
        'heightMm': g.boardHeight,
      },
      'trim': {
        'xMm': 20,
        'yMm': 20,
        'widthMm': g.mediaWidth - 40,
        'heightMm': g.mediaHeight - 40,
      },
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final id in measuredHard20p.keys) {
    testWidgets(
      'actual hardcover PDFs use verified board and wrap dimensions $id',
      (tester) async {
        await tester.runAsync(() async {
          final source = await artwork.sourceImage(size: 3000);
          final bytes = (await source.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          source.dispose();
          final product = PrintProduct.forId(id)!;
          final spec = PrintVendorSpec.fromJson(officialHardSpec(id));
          final output = await AlbumPrintExporter(
            assetLoader: (_) async => bytes,
          ).generate(snapshot: fixtures.productSnapshot(product), spec: spec);
          expect(output.report['coverType'], 'HARD');
          expect(output.report['productId'], id);
          expect(output.report['specVerified'], false);
          expect(output.interiorPageCount, 20);
          expect(output.report['blankPagesAdded'], 19);
          for (final item in [
            (output.coverPdf, spec.coverSize, spec.coverTrim, 1),
            (output.interiorPdf, spec.interiorSize, spec.interiorTrim, 20),
          ]) {
            final pdf = latin1.decode(item.$1);
            expect(RegExp(r'/Type /Page\b').allMatches(pdf).length, item.$4);
            final media = RegExp(
              r'/MediaBox \[0 0 ([\d.]+) ([\d.]+)\]',
            ).firstMatch(pdf)!;
            expect(
              double.parse(media[1]!) * 25.4 / 72,
              closeTo(item.$2.width, .001),
            );
            expect(
              double.parse(media[2]!) * 25.4 / 72,
              closeTo(item.$2.height, .001),
            );
            final trim = RegExp(
              r'/TrimBox \[([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)\]',
            ).firstMatch(pdf)!;
            expect(
              double.parse(trim[1]!) * 25.4 / 72,
              closeTo(item.$3.left, .001),
            );
            expect(
              (double.parse(trim[3]!) - double.parse(trim[1]!)) * 25.4 / 72,
              closeTo(item.$3.width, .001),
            );
            expect(
              (double.parse(trim[4]!) - double.parse(trim[2]!)) * 25.4 / 72,
              closeTo(item.$3.height, .001),
            );
            expect(pdf.contains('/ICCBased'), true);
          }
          final directory = Directory(
            'output/pdf/print-hardcover/${product.id}',
          )..createSync(recursive: true);
          File('${directory.path}/cover.pdf').writeAsBytesSync(output.coverPdf);
          File(
            '${directory.path}/interior.pdf',
          ).writeAsBytesSync(output.interiorPdf);
          File('${directory.path}/report.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(output.report),
          );
        });
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}

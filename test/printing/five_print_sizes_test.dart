import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'print_album_export_test.dart' as artwork;

const products = [
  'REDP_200X150_SOFT',
  'REDP_200_SOFT',
  'REDP_250X200_SOFT',
  'REDP_250_SOFT',
  'REDP_300_SOFT',
];

Map<String, dynamic> productSpec(PrintProduct product) {
  final w = product.trimWidthMm, h = product.trimHeightMm;
  return {
    'id': product.id,
    'specVersion': '${product.id}_REVIEW_V2_7.22',
    'pageCount': 20,
    'verified': false,
    'interior': {'trimWidthMm': w, 'trimHeightMm': h, 'bleedMm': 5},
    'cover': {
      'widthMm': 2 * w + 17.22,
      'heightMm': h + 10,
      'front': {'xMm': w + 12.22, 'yMm': 5, 'widthMm': w, 'heightMm': h},
      'back': {'xMm': 5, 'yMm': 5, 'widthMm': w, 'heightMm': h},
    },
  };
}

Map<String, dynamic> productSnapshot(PrintProduct product) {
  final result = artwork.snapshot();
  result['album'] = Map<String, dynamic>.from(result['album'] as Map);
  result['album']['ratio'] = product.aspectRatio;
  final document =
      jsonDecode(result['album']['cover_layers_json'] as String) as Map;
  document['printProduct'] = product.toJson();
  result['album']['cover_layers_json'] = document;
  result['printProduct'] = product.toJson();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'physical metadata is strict and legacy paid square retains its contract',
    () {
      for (final id in products) {
        final product = PrintProduct.forId(id)!;
        final doc = PrintAlbumDocument.fromSnapshot(productSnapshot(product));
        expect(doc.productForNewPreview.id, id);
        doc.validateSpec(PrintVendorSpec.fromJson(productSpec(product)));
        expect(
          () =>
              PrintProduct.fromJson({...product.toJson(), 'trimWidthMm': 199}),
          throwsFormatException,
        );
      }
      final large = productSnapshot(PrintProduct.forId('REDP_300_SOFT')!);
      final doc = PrintAlbumDocument.fromSnapshot(large);
      final square = productSpec(PrintProduct.forId('REDP_200_SOFT')!);
      expect(
        () => doc.validateSpec(PrintVendorSpec.fromJson(square)),
        throwsFormatException,
      );
      square['specVersion'] = 'REDP_200_SOFT_REVIEW_V1_7.22';
      doc.validateSpec(PrintVendorSpec.fromJson(square));
      expect(
        () => doc.validateSpec(
          PrintVendorSpec.fromJson(square),
          newPreview: true,
        ),
        throwsFormatException,
      );
      expect(
        () => PrintAlbumDocument.fromSnapshot(
          artwork.snapshot(),
        ).productForNewPreview,
        throwsFormatException,
      );
      final landscape = artwork.snapshot();
      landscape['album']['ratio'] = '4:3';
      expect(
        PrintAlbumDocument.fromSnapshot(landscape).productForNewPreview.id,
        'REDP_200X150_SOFT',
      );
      final malformed = productSnapshot(
        PrintProduct.forId('REDP_250X200_SOFT')!,
      );
      malformed['album']['ratio'] = 1;
      expect(
        () => PrintAlbumDocument.fromSnapshot(malformed).productForNewPreview,
        throwsFormatException,
      );
    },
  );

  for (final id in products) {
    testWidgets(
      'actual cover/interior PDFs preserve $id dimensions and original artwork',
      (tester) async {
        await tester.runAsync(() async {
          final product = PrintProduct.forId(id)!;
          final source = await artwork.sourceImage(size: 3000);
          final bytes = (await source.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          source.dispose();
          final spec = PrintVendorSpec.fromJson(productSpec(product));
          final output = await AlbumPrintExporter(
            assetLoader: (_) async => bytes,
          ).generate(snapshot: productSnapshot(product), spec: spec);
          expect(output.report['productId'], id);
          expect(output.report['trimMm'], [
            product.trimWidthMm,
            product.trimHeightMm,
          ]);
          expect(output.interiorPageCount, 20);
          expect(output.report['blankPagesAdded'], 19);
          for (final pair in [
            (output.coverPdf, spec.coverSize, 1),
            (output.interiorPdf, spec.interiorSize, 20),
          ]) {
            final pdf = latin1.decode(pair.$1);
            expect(RegExp(r'/Type /Page\b').allMatches(pdf).length, pair.$3);
            final media = RegExp(
              r'/MediaBox \[0 0 ([\d.]+) ([\d.]+)\]',
            ).firstMatch(pdf)!;
            expect(
              double.parse(media[1]!) * 25.4 / 72,
              closeTo(pair.$2.width, .001),
            );
            expect(
              double.parse(media[2]!) * 25.4 / 72,
              closeTo(pair.$2.height, .001),
            );
            final raster = RegExp(
              r'/Width (\d+) /Height (\d+)',
            ).firstMatch(pdf)!;
            // Floating-point ceil can add one final pixel at exact boundaries.
            expect(
              int.parse(raster[1]!),
              closeTo(pair.$2.width * 300 / 25.4, 1.001),
            );
            expect(
              int.parse(raster[2]!),
              closeTo(pair.$2.height * 300 / 25.4, 1.001),
            );
            expect(pdf, contains('/ICCBased'));
          }
          final directory = Directory('output/pdf/print-five-sizes/$id')
            ..createSync(recursive: true);
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

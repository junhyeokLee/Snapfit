import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';

import 'print_album_export_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('empty and non-font assets cannot be accepted as a print font', () {
    expect(printFontHeaderIsValid(ByteData(0)), false);
    expect(printFontHeaderIsValid(ByteData(128)), false);
  });
  test('an album using the existing empty FigmaHand font is blocked', () async {
    final source = fixture.snapshot();
    final album = source['album'] as Map<String, dynamic>;
    album['cover_layers_json'] = (album['cover_layers_json'] as String)
        .replaceAll('NotoSans', 'FigmaHand');
    await expectLater(
      AlbumPrintExporter(loadOnlyUsedFonts: true).verify(
        snapshot: source,
        spec: PrintVendorSpec.fromJson(fixture.specJson()),
      ),
      throwsA(
        isA<PrintPreflightException>().having(
          (error) => error.code,
          'code',
          'print_font_unavailable',
        ),
      ),
    );
  });
  test('the actual Korean print font has a valid header', () async {
    final actual = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    expect(printFontHeaderIsValid(actual), true);
  });
}

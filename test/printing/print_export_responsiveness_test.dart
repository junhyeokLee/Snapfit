import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';

import 'print_album_export_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress gives queued UI work a turn between padded pages', (
    tester,
  ) async {
    await tester.runAsync(() async {
      var lastUiUpdate = 0;
      final completedPages = <int>[];
      final output = await AlbumPrintExporter(loadOnlyUsedFonts: true).generate(
        snapshot: {
          'album': {
            'ratio': '1',
            'cover_layers_json': jsonEncode({
              'pages': [
                {'index': 0, 'isCover': true, 'layers': <Object>[]},
              ],
            }),
          },
        },
        spec: PrintVendorSpec.fromJson(fixtures.specJson()),
        onProgress: (completed, total) {
          // A microtask-only continuation starves timers while cached blank
          // pages are repeated. The browser needs an event-loop turn to paint
          // progress and receive input, even when no new raster is encoded.
          expect(lastUiUpdate, completed - 1);
          completedPages.add(completed);
          Timer.run(() => lastUiUpdate = completed);
          expect(total, 21);
        },
      );

      expect(completedPages, List.generate(21, (index) => index + 1));
      expect(lastUiUpdate, 21);
      expect(output.interiorPageCount, 20);
      expect(output.report['blankPagesAdded'], 20);
      expect(output.report['dpi'], 300);
      expect(output.report['imageEncoding'], 'JPEG quality 95');
      expect(output.report['iccProfileEmbedded'], true);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}

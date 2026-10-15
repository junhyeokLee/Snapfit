import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';

import 'print_album_export_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('empty and non-font assets cannot be accepted as a print font', () {
    expect(printFontHeaderIsValid(ByteData(0)), false);
    expect(printFontHeaderIsValid(ByteData(128)), false);
  });
  test(
    'an album using a corrupted font is blocked without a substitute',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'FontManifest.json') {
          return ByteData.sublistView(
            Uint8List.fromList(
              utf8.encode(
                jsonEncode([
                  {
                    'family': 'test-corrupted/NotoSans',
                    'fonts': [
                      {'asset': 'assets/fonts/NotoSansKR-Regular.ttf'},
                    ],
                  },
                  {
                    'family': 'test-corrupted/Figma Hand',
                    'fonts': [
                      {'asset': 'test-corrupted.ttf'},
                    ],
                  },
                ]),
              ),
            ),
          );
        }
        if (key == 'test-corrupted.ttf') return ByteData(0);
        if (key == 'assets/fonts/NotoSansKR-Regular.ttf') {
          return ByteData.sublistView(await File(key).readAsBytes());
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('FontManifest.json');
      });
      final source = fixture.snapshot();
      final album = source['album'] as Map<String, dynamic>;
      album['cover_layers_json'] = (album['cover_layers_json'] as String)
          .replaceAll('NotoSans', 'FigmaHand');
      await expectLater(
        AlbumPrintExporter(
          fontFamilyPrefix: 'test-corrupted/',
          loadOnlyUsedFonts: true,
        ).verify(
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
    },
  );
  test(
    'original Korean print fonts have valid headers and bundled license',
    () async {
      for (final file in [
        'NotoSansKR-Regular.ttf',
        'Hakgyoansim_GongryongalR.ttf',
      ]) {
        final actual = await rootBundle.load('assets/fonts/$file');
        expect(printFontHeaderIsValid(actual), true);
      }
      expect(
        await rootBundle.loadString(
          'assets/fonts/Hakgyoansim_GongryongalR-OFL.txt',
        ),
        contains('Copyright (c) 2025 by KERIS.'),
      );
    },
  );
  test(
    'used-font preparation preserves the exact Korean glyph matrix and skips unused font assets',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var prefix = 'test-selective-glyphs/';
      final reads = <String>[];
      const noto = 'assets/fonts/NotoSansKR-Regular.ttf';
      const figma = 'assets/fonts/Hakgyoansim_GongryongalR.ttf';
      const unused = 'test-unused-font.ttf';
      rootBundle.evict('FontManifest.json');
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'FontManifest.json') {
          return ByteData.sublistView(
            Uint8List.fromList(
              utf8.encode(
                jsonEncode([
                  for (final entry in {
                    'NotoSans': noto,
                    'FigmaHand': figma,
                    'Figma Hand': figma,
                    'UnusedForThisAlbum': unused,
                  }.entries)
                    {
                      'family': '$prefix${entry.key}',
                      'fonts': [
                        {'asset': entry.value},
                      ],
                    },
                ]),
              ),
            ),
          );
        }
        if ([noto, figma, unused].contains(key)) {
          reads.add(key);
          return ByteData.sublistView(
            await File(key == unused ? noto : key).readAsBytes(),
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('FontManifest.json');
      });
      final snapshot = fixture.snapshot();
      final document =
          jsonDecode(snapshot['album']['cover_layers_json'] as String)
              as Map<String, dynamic>;
      final pages = document['pages'] as List;
      final originalText = Map<String, dynamic>.from(
        (pages.first['layers'] as List).firstWhere(
              (layer) => layer['type'] == 'TEXT',
            )
            as Map,
      );
      for (final page in pages) {
        page['layers'] = <Map<String, dynamic>>[];
      }
      final families = ['NotoSans', 'FigmaHand', 'Figma Hand'];
      pages.first['layers'] = [
        for (final family in families)
          {
            ...originalText,
            'id': family,
            'payload': {
              ...originalText['payload'] as Map,
              'textStyle': {
                ...originalText['payload']['textStyle'] as Map,
                'fontFamily': family,
              },
            },
          },
      ];
      snapshot['album']['cover_layers_json'] = jsonEncode(document);
      final resolvedFamilies = PrintAlbumDocument.fromSnapshot(snapshot).pages
          .expand((page) => page.layers)
          .map((layer) => layer.textStyle!.fontFamily!)
          .toSet();
      // Both editor spellings intentionally resolve to the same actual family.
      expect(resolvedFamilies, {'NotoSans', 'Figma Hand'});
      final spec = PrintVendorSpec.fromJson(fixture.specJson());
      final selective = await AlbumPrintExporter(
        fontFamilyPrefix: prefix,
        loadOnlyUsedFonts: true,
      ).verify(snapshot: snapshot, spec: spec);
      expect(selective['missingAssets'], isEmpty);
      expect(reads, containsAll([noto, figma]));
      expect(reads, isNot(contains(unused)));
      Future<String> glyphHash(String family, ui.FontWeight weight) async {
        final builder = ui.ParagraphBuilder(
          ui.ParagraphStyle(fontFamily: family, fontSize: 24),
        )..pushStyle(ui.TextStyle(fontFamily: family, fontWeight: weight));
        builder.addText('스냅핏 우리 앨범 SnapFit 2026');
        final paragraph = builder.build()
          ..layout(const ui.ParagraphConstraints(width: 380));
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
        final picture = recorder.endRecording();
        final image = await picture.toImage(384, 80);
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final hash = sha256.convert(pixels!.buffer.asUint8List()).toString();
        image.dispose();
        picture.dispose();
        paragraph.dispose();
        return hash;
      }

      final before = <String, String>{};
      for (final family in resolvedFamilies) {
        for (final weight in [ui.FontWeight.w400, ui.FontWeight.w800]) {
          before['$family/$weight'] = await glyphHash(family, weight);
        }
      }
      prefix = 'test-full-glyphs/';
      rootBundle.evict('FontManifest.json');
      final complete = await AlbumPrintExporter(
        fontFamilyPrefix: prefix,
      ).verify(snapshot: snapshot, spec: spec);
      expect(complete['missingAssets'], isEmpty);
      expect(reads, contains(unused));
      for (final family in resolvedFamilies) {
        for (final weight in [ui.FontWeight.w400, ui.FontWeight.w800]) {
          expect(
            await glyphHash(family, weight),
            before['$family/$weight'],
            reason: '$family/$weight',
          );
        }
      }
    },
  );

  testWidgets(
    'restored exact original supports both Figma aliases and actual 20-page PDF',
    (tester) async {
      await tester.runAsync(() async {
        final image = await fixture.sourceImage(size: 3000);
        final imageBytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        final exporter = AlbumPrintExporter(
          loadOnlyUsedFonts: true,
          assetLoader: (_) async => imageBytes,
        );
        final spec = PrintVendorSpec.fromJson(fixture.specJson());
        for (final alias in ['FigmaHand', 'Figma Hand']) {
          final snapshot = fixture.snapshot();
          snapshot['album']['cover_layers_json'] =
              (snapshot['album']['cover_layers_json'] as String).replaceAll(
                'NotoSans',
                alias,
              );
          final report = await exporter.verify(snapshot: snapshot, spec: spec);
          expect(report['missingAssets'], isEmpty);
        }
        final snapshot = fixture.snapshot();
        snapshot['album']['cover_layers_json'] =
            (snapshot['album']['cover_layers_json'] as String).replaceAll(
              'NotoSans',
              'Figma Hand',
            );
        final result = await exporter.generate(snapshot: snapshot, spec: spec);
        expect(result.interiorPageCount, 20);
        expect(result.report['missingAssets'], isEmpty);
        expect(latin1.decode(result.coverPdf), contains('/ICCBased'));
        final directory = Directory(
          '/private/tmp/snapfit-gongryongal-restored-proof',
        )..createSync(recursive: true);
        File('${directory.path}/cover.pdf').writeAsBytesSync(result.coverPdf);
        File(
          '${directory.path}/interior.pdf',
        ).writeAsBytesSync(result.interiorPdf);
        File(
          '${directory.path}/report.json',
        ).writeAsStringSync(jsonEncode(result.report));
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

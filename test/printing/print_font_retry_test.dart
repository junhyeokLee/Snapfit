import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';

import 'print_album_export_test.dart' as fixture;

ByteData _jsonBytes(Object value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(value))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a failed print-font download can retry in the same tab and exporter',
    () async {
      const prefix = 'retry-in-same-tab/';
      const fontPath = 'retry-in-same-tab.ttf';
      var fontReads = 0;
      final font = await File(
        'assets/fonts/NotoSansKR-Regular.ttf',
      ).readAsBytes();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      rootBundle.evict('FontManifest.json');
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        if (path == 'FontManifest.json') {
          return _jsonBytes([
            {
              'family': '${prefix}NotoSans',
              'fonts': [
                {'asset': fontPath},
              ],
            },
          ]);
        }
        if (path == fontPath) {
          if (++fontReads == 1) return null;
          return ByteData.sublistView(font);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('FontManifest.json');
      });
      final snapshot = fixture.snapshot();
      final document =
          jsonDecode(snapshot['album']['cover_layers_json'] as String) as Map;
      for (final page in document['pages'] as List) {
        page['layers'] = [
          for (final layer in page['layers'] as List)
            if (layer['type'] == 'TEXT') layer,
        ];
      }
      snapshot['album']['cover_layers_json'] = jsonEncode(document);
      final exporter = AlbumPrintExporter(
        fontFamilyPrefix: prefix,
        loadOnlyUsedFonts: true,
        assetLoader: (_) =>
            throw StateError('Text-only verification must not load a photo'),
      );
      final spec = PrintVendorSpec.fromJson(fixture.specJson());
      await expectLater(
        exporter.verify(snapshot: snapshot, spec: spec),
        throwsA(isA<FlutterError>()),
      );
      final retry = await exporter.verify(snapshot: snapshot, spec: spec);
      expect(fontReads, 2);
      expect(retry['missingAssets'], isEmpty);
    },
  );

  test(
    'publication prepares known fallback families before synchronous capture',
    () async {
      const primary = 'SnapshotTestPrimary';
      const fallback = 'SnapshotTestFallback';
      const paths = {
        'NotoSans': 'snapshot-test-noto.ttf',
        primary: 'snapshot-test-primary.ttf',
        fallback: 'snapshot-test-fallback.ttf',
      };
      final font = await File(
        'assets/fonts/NotoSansKR-Regular.ttf',
      ).readAsBytes();
      final reads = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      rootBundle.evict('FontManifest.json');
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        if (path == 'FontManifest.json') {
          return _jsonBytes([
            for (final entry in paths.entries)
              {
                'family': entry.key,
                'fonts': [
                  {'asset': entry.value},
                ],
              },
          ]);
        }
        if (paths.values.contains(path)) {
          reads.add(path);
          return ByteData.sublistView(font);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('FontManifest.json');
      });
      await SocialSnapshotRenderer().prepareFonts([
        PrintAlbumPage(
          index: 0,
          isCover: true,
          canvasSize: const Size(400, 400),
          backgroundColor: Colors.white,
          layers: [
            LayerModel(
              id: 'fallback-caption',
              type: LayerType.text,
              position: Offset.zero,
              width: 300,
              height: 100,
              text: '스냅핏 SnapFit',
              textStyle: const TextStyle(
                fontFamily: primary,
                fontFamilyFallback: [fallback, 'Unbundled OS fallback'],
              ),
            ),
          ],
        ),
      ]);
      expect(reads, containsAll(paths.values));
      expect(reads, hasLength(paths.length));
    },
  );
}

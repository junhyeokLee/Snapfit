import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'export all sixteen native spreads per edition and ratio',
    () async {
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in fonts) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
      final output = Directory('output/premium-atelier-qa')
        ..createSync(recursive: true);
      final books = <String, dynamic>{};
      var redesigned = 0, preserved = 0;
      for (final e in AtelierEdition.values) {
        final doc = e.document(CollectionAspect.square);
        final pages = templateDocumentPages(doc).skip(1).toList();
        final roles = [
          for (final p in pages.where((p) => p['side'] == 'left'))
            p['role'] as String,
        ];
        bool retained(String role) =>
            [
              'prologue-',
              'specimen-',
              'invitation-',
              'shelves-',
            ].any(role.startsWith) ||
            e == AtelierEdition.privateCinema && role.startsWith('darkroom-');
        final unchanged = roles.where(retained).length;
        preserved += unchanged;
        redesigned += 16 - unchanged;
        final byValue = {
          for (final spec in studioDecorations) spec.insertionValue: spec,
          for (final spec in studioDecorations) spec.id: spec,
        };
        final materialUses = <String, int>{}, frames = <String>{};
        for (final p in pages) {
          final used = <String>{};
          for (final layer in (p['layers'] as List).cast<Map>()) {
            if (layer['type'] == 'image') {
              final frame = layer['frame'] as String?;
              if (frame != null && frame != 'none') frames.add(frame);
            } else if (layer['type'] == 'sticker' ||
                layer['type'] == 'decoration') {
              final spec =
                  byValue[layer['style']] ?? byValue[layer['imageUrl']];
              if (spec != null) used.add(spec.id);
            }
          }
          for (final key in used) {
            materialUses.update(key, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        books[e.id] = {
          'title': e.title,
          'chapters': e.chapters,
          'roles': roles,
          'redesignedSpreads': 16 - unchanged,
          'retainedSpreads': unchanged,
          'materialCount': templateVisualMaterialKeys(doc).length,
          'frameCount': frames.length,
          'materialPageUsage': materialUses,
          'signatureFrame': frames
              .where((f) => f.startsWith('signature'))
              .single,
          'typographyDirection': e.id,
        };
        for (final aspect in CollectionAspect.values) {
          const tileWidth = 460.0, gap = 24.0, margin = 36.0;
          final imageHeight = tileWidth / (2 * aspect.canvas.aspectRatio);
          final rowHeight = imageHeight + 60;
          const width = margin * 2 + tileWidth * 4 + gap * 3;
          final height = 110 + rowHeight * 4 + gap * 3;
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawColor(const Color(0xFFF1F5F3), BlendMode.src);
          void text(String value, Offset at, double size, double maxWidth) {
            final painter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: size,
                  color: const Color(0xFF203A2F),
                  letterSpacing: 0,
                ),
              ),
            )..layout(maxWidth: maxWidth);
            painter.paint(canvas, at);
            painter.dispose();
          }

          final label = switch (aspect) {
            CollectionAspect.portrait => '세로',
            CollectionAspect.square => '정사각형',
            CollectionAspect.landscape => '가로',
          };
          text(
            '${e.title} / $label / 내지 32쪽',
            const Offset(margin, 28),
            28,
            width - margin * 2,
          );
          for (var spread = 1; spread <= 16; spread++) {
            final at = Offset(
              margin + (spread - 1) % 4 * (tileWidth + gap),
              94 + (spread - 1) ~/ 4 * (rowHeight + gap),
            );
            final source = File(
              '${output.path}/${e.id}-${aspect.name}-$spread.png',
            );
            expect(source.existsSync(), true, reason: source.path);
            final codec = await ui.instantiateImageCodec(
              source.readAsBytesSync(),
            );
            final image = (await codec.getNextFrame()).image;
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              at & Size(tileWidth, imageHeight),
              Paint()..filterQuality = FilterQuality.high,
            );
            image.dispose();
            codec.dispose();
            text(
              '${spread * 2 - 1}–${spread * 2}쪽 / ${e.chapters[spread - 1]}',
              at + Offset(0, imageHeight + 10),
              17,
              tileWidth,
            );
          }
          final picture = recorder.endRecording();
          final image = await picture.toImage(width.ceil(), height.ceil());
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/${e.id}-${aspect.name}-overview.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
        debugPrint(
          '${e.id}: ${16 - unchanged} upgraded spreads; ${materialUses.length} decorative materials; ${frames.length} frames',
        );
      }
      final data = {
        'revision': '2026-10-16-signature-typography',
        'nativeRenderer': true,
        'redesignedSpreads': redesigned,
        'preservedSpreads': preserved,
        'printProofComplete': false,
        'physicalDeviceValidated': false,
        'commerceChanged': false,
        'books': books,
      };
      File(
        '${output.path}/interior-rhythm-review.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
      File(
        '${output.path}/gallery-data.js',
      ).writeAsStringSync('const atelierGalleryData = ${jsonEncode(books)};\n');
      expect(redesigned + preserved, 112);
    },
    skip: !const bool.fromEnvironment('EXPORT_ATELIER_RHYTHM'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

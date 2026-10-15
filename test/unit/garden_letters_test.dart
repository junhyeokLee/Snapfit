import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import '../widget/ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);
  test(
    'garden letters has 24 complete pages with readable type in every size',
    () {
      for (final aspect in CollectionAspect.values) {
        final doc = buildGardenLetters(aspect);
        final pages = templateDocumentPages(doc);
        expect(pages, hasLength(25));
        for (final page in pages) {
          final layers = DataTemplateEngine.buildLayersFromJson(
            page,
            aspect.canvas,
          );
          for (final layer in layers) {
            if (layer.type == LayerType.text) {
              final painter = TextPainter(
                text: TextSpan(text: layer.text, style: layer.textStyle),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: layer.width);
              expect(
                painter.height,
                lessThanOrEqualTo(layer.height + 1),
                reason: '${aspect.name}/${page['name']}/${layer.text}',
              );
              painter.dispose();
            }
          }
          for (final layer in page['layers'] as List) {
            final path = layer['imageUrl'];
            if (path is String && path.startsWith('asset:')) {
              expect(File(path.substring(6)).existsSync(), true, reason: path);
            }
          }
        }
      }
    },
  );
}

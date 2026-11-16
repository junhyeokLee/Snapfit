import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'freeze the actual editable word-art documents before refinement',
    () async {
      final output = File(
        'test/fixtures/material_word_art_before_20261102.json',
      );
      expect(
        output.existsSync(),
        isFalse,
        reason: 'The captured pre-refinement documents are immutable fixtures.',
      );
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in fonts.cast<Map>()) {
        final loader = FontLoader(font['family'] as String);
        for (final face in (font['fonts'] as List).cast<Map>()) {
          loader.addFont(rootBundle.load(face['asset'] as String));
        }
        await loader.load();
      }
      final documents = <String, Object?>{};
      for (final id in ['bold-cut', 'ticket-label', 'hand-note', 'diecut']) {
        final art = studioWordArtById(id)!;
        documents[id] = {
          'productKey': art.productKey,
          'favoriteKey': art.favoriteKey,
          'text': art.text,
          'sourceSize': [art.sourceSize.width, art.sourceSize.height],
          'previewLayers': [
            for (final layer in art.previewLayers())
              LayerExportMapper.toJson(layer, canvasSize: art.sourceSize),
          ],
          'inserted': {
            for (final aspect in CollectionAspect.printable)
              aspect.name: {
                'canvas': [aspect.canvas.width, aspect.canvas.height],
                'layers': [
                  for (final layer in art.buildLayers(aspect.canvas))
                    LayerExportMapper.toJson(layer, canvasSize: aspect.canvas),
                ],
              },
          },
        };
      }
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(documents),
      );
    },
    skip: !const bool.fromEnvironment('EXPORT_MATERIAL_WORD_ART_SNAPSHOT'),
  );
}

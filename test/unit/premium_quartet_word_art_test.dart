import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final families = {
      'BookMyungjo',
      ...premiumQuartetSpecsById.values.expand(
        (s) => [s.font, s.secondaryFont],
      ),
    };
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final item in manifest.cast<Map>().where(
      (m) => families.contains(m['family']),
    )) {
      final loader = FontLoader(item['family'] as String);
      for (final face in (item['fonts'] as List).cast<Map>())
        loader.addFont(rootBundle.load(face['asset'] as String));
      await loader.load();
      families.remove(item['family']);
    }
    expect(families, isEmpty);
  });
  test(
    'both editable phrases retain semantic line breaks after insertion at every sale ratio',
    () {
      for (final art in premiumQuartetWordArts) {
        for (final aspect in CollectionAspect.printable) {
          final layers = art.buildLayers(aspect.canvas);
          expect(
            layers.where((l) => l.type == LayerType.text).length,
            greaterThanOrEqualTo(2),
          );
          expect(
            layers.where(
              (l) => l.type == LayerType.image || l.type == LayerType.sticker,
            ),
            isEmpty,
          );
          for (final layer in layers) {
            expect(layer.position.dx, greaterThanOrEqualTo(0), reason: art.id);
            expect(layer.position.dy, greaterThanOrEqualTo(0), reason: art.id);
            expect(
              layer.position.dx + layer.width,
              lessThanOrEqualTo(aspect.canvas.width + .1),
              reason: art.id,
            );
            expect(
              layer.position.dy + layer.height,
              lessThanOrEqualTo(aspect.canvas.height + .1),
              reason: art.id,
            );
            if (layer.type != LayerType.text) continue;
            final painter = TextPainter(
              text: TextSpan(text: layer.text, style: layer.textStyle),
              textDirection: TextDirection.ltr,
              textAlign: layer.textAlign ?? TextAlign.left,
            )..layout(maxWidth: layer.width);
            expect(
              painter.height,
              lessThanOrEqualTo(layer.height + 1.25),
              reason: '${art.id}/${aspect.name}/${layer.text}',
            );
            if (layer.text == art.text)
              expect(
                painter.computeLineMetrics().length,
                art.text.split('\n').length,
                reason:
                    '${art.id}/${aspect.name}: preserve the authored phrase, without isolated glyph lines',
              );
            painter.dispose();
          }
        }
      }
    },
  );
}

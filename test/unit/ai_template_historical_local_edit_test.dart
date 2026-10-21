import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_design.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_paper_tone.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'historical Gemini book edits shared paper colors without changing its artwork',
    () async {
      // Historical synthetic model output, not a newly generated quality claim.
      // This test reads the retained fixture and never exports a preview or image.
      final report =
          jsonDecode(
                File(
                  'test/fixtures/ai_template_gemini_historical_book.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(report['mode'], 'historical_live');
      final entry = (report['results'] as List).single as Map;
      expect(entry['status'], 'accepted');
      final document = Map<String, Object?>.from(entry['document'] as Map);
      final typography = (document['artDirection'] as Map)['typography'] as Map;
      final families = typography.values
          .map((value) => (value as Map)['fontFamily'])
          .toSet();
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in manifest.cast<Map>()) {
        if (!families.contains(font['family'])) continue;
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load((asset as Map)['asset'] as String));
        }
        await loader.load();
      }
      final count = (entry['brief'] as Map)['pageCount'] as int;
      final original = AiTemplateDesign.fromJson(document, count);
      expect(original.pages, hasLength(21));
      expect(inspectAiTemplateText(original), isEmpty);

      for (final tone in [AiTemplatePaperTone.warm, AiTemplatePaperTone.cool]) {
        final adjusted = withAiTemplatePaperTone(original, tone);
        expect(
          adjusted.pages.indexed.any(
            (page) => page.$2.background != original.pages[page.$1].background,
          ),
          isTrue,
          reason: 'Shared white photo colors must not disable all paper edits',
        );
        expect(adjusted.artDirection!.palette.length, lessThanOrEqualTo(6));
        expect(inspectAiTemplateText(adjusted), isEmpty);
        for (final (index, page) in adjusted.pages.indexed) {
          expect(page.elements, same(original.pages[index].elements));
          for (final element in page.elements) {
            final hex =
                '#${element.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            expect(adjusted.artDirection!.palette, contains(hex));
          }
        }
        final before = original.buildLayers();
        final after = adjusted.buildLayers();
        for (var page = 0; page < before.length; page++) {
          final ids = original.pages[page].elements
              .map((element) => element.id)
              .toSet();
          final oldArtwork = before[page].where(
            (layer) => ids.contains(layer.id),
          );
          final newArtwork = after[page].where(
            (layer) => ids.contains(layer.id),
          );
          expect(
            newArtwork.map(
              (layer) => LayerExportMapper.toJson(
                layer,
                canvasSize: adjusted.canvasSize,
              ),
            ),
            oldArtwork.map(
              (layer) => LayerExportMapper.toJson(
                layer,
                canvasSize: original.canvasSize,
              ),
            ),
          );
        }
        expect(
          withAiTemplatePaperTone(
            original,
            AiTemplatePaperTone.original,
            current: adjusted,
          ).pages.map((page) => page.background),
          original.pages.map((page) => page.background),
        );
      }
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/free_template_material_policy.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/template_visual_material_inventory.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });

  test(
    'every catalog page fits with the actual bundled fonts in all formats',
    () {
      final results = <Map<String, dynamic>>[];
      final issues = <String>[];
      var pageCount = 0, textCount = 0;
      for (final template in publishedCreationTemplates) {
        final catalog =
            jsonDecode(template.templateJson!) as Map<String, dynamic>;
        final variants = catalog['variants'] as Map;
        final materialIssues = template.isPremium
            ? <String>{}
            : freeTemplateMaterialIssues(catalog);
        issues.addAll(materialIssues.map((key) => '${template.title}: $key'));
        final formats = <Map<String, dynamic>>[];
        for (final aspect in CollectionAspect.values) {
          final document = Map<String, dynamic>.from(
            variants[aspect.name] as Map,
          );
          final pages = templateDocumentPages(document);
          final ids = <String>{};
          var textLayers = 0;
          expect(pages.length, (document['innerPageCount'] as int) + 1);
          for (final entry in pages.indexed) {
            pageCount++;
            final page = entry.$2;
            final layers = DataTemplateEngine.buildLayersFromJson(
              page,
              aspect.canvas,
            );
            expect(layers.length, (page['layers'] as List).length);
            for (final layer in layers) {
              final label =
                  '${template.title}/${aspect.name}/${entry.$1}/${layer.id}';
              if (!ids.add(layer.id)) issues.add('$label: duplicate layer');
              final rect = layer.position & Size(layer.width, layer.height);
              if (!rect.isFinite ||
                  rect.left < -.1 ||
                  rect.top < -.1 ||
                  rect.right > aspect.canvas.width + .1 ||
                  rect.bottom > aspect.canvas.height + .1) {
                issues.add('$label: out of bounds $rect');
              }
              if (layer.imageUrl case final String url
                  when url.startsWith('asset:')) {
                if (!File(url.substring(6)).existsSync())
                  issues.add('$label: missing $url');
              }
              if (layer.type != LayerType.text) continue;
              textLayers++;
              textCount++;
              final painter = TextPainter(
                text: TextSpan(text: layer.text, style: layer.textStyle),
                textDirection: TextDirection.ltr,
                strutStyle: StrutStyle.fromTextStyle(
                  layer.textStyle!,
                  forceStrutHeight: true,
                ),
              )..layout(maxWidth: layer.width);
              if (painter.height > layer.height + .5 ||
                  painter.computeLineMetrics().any(
                    (line) => line.width > layer.width + .5,
                  )) {
                issues.add(
                  '$label: "${layer.text}" needs ${painter.height}, has ${layer.height}',
                );
              }
              painter.dispose();
            }
          }
          formats.add({
            'aspect': aspect.name,
            'pages': pages.length,
            'textLayers': textLayers,
          });
        }
        results.add({
          'catalogId': template.id,
          'title': template.title,
          'tier': template.isPremium ? 'premium' : 'free',
          'materials': templateVisualMaterialKeys(catalog).toList()..sort(),
          'formats': formats,
        });
      }
      if (const bool.fromEnvironment('EXPORT_CATALOG_DESIGN_AUDIT')) {
        final data = {
          'revision': '2026-10-16-legacy-review',
          'catalogCount': results.length,
          'freeCount': results.where((r) => r['tier'] == 'free').length,
          'premiumCount': results.where((r) => r['tier'] == 'premium').length,
          'pageCountAcrossFormats': pageCount,
          'textLayerCount': textCount,
          'issues': issues,
          'deviceOrPrintProof': false,
          'results': results,
        };
        File('output/premium-atelier-qa/catalog-design-audit.json')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
        File(
          'output/premium-atelier-qa/catalog-audit-data.js',
        ).writeAsStringSync(
          'const catalogDesignAudit = ${jsonEncode(data)};\n',
        );
      }
      expect(results, hasLength(68));
      expect(issues, isEmpty);
    },
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/templates/catalog_editorial_assets.g.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

// Pick a representative real spread without repeating the cover photograph.
Set<String> _photos(Map<String, dynamic> page) => {
  for (final layer in (page['layers'] as List? ?? const []).whereType<Map>())
    if (layer['type'] == 'image' && layer['imageUrl'] is String)
      layer['imageUrl'] as String,
};

int _representativeSpread(List<Map<String, dynamic>> pages) {
  final cover = _photos(pages.first);
  var selected = 1;
  var best = -100000;
  for (var p = 1; p + 1 < pages.length; p += 2) {
    final photos = {..._photos(pages[p]), ..._photos(pages[p + 1])};
    final score =
        photos.difference(cover).length.clamp(0, 2) * 4 -
        photos.intersection(cover).length * 12;
    if (score > best) {
      best = score;
      selected = p;
    }
  }
  return selected;
}

// Pre-render one spread, not whole books, for each catalog edition.
void main() {
  testWidgets(
    'export representative spreads for the editorial catalog',
    (tester) async {
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in fonts) {
        final loader = FontLoader(font['family'] as String);
        for (final file in font['fonts'] as List) {
          loader.addFont(rootBundle.load(file['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selectedIds = const String.fromEnvironment(
        'EXPORT_TEMPLATE_IDS',
      ).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      final partial = selectedIds.isNotEmpty;
      expect(
        selectedIds.difference(
          publishedCreationTemplates.map((t) => t.id).toSet(),
        ),
        isEmpty,
      );
      final assets = <int, String>{if (partial) ...catalogEditorialAssets};
      final firstPages = <int, int>{if (partial) ...catalogEditorialFirstPages};
      for (final template in publishedCreationTemplates.where(
        (t) => !partial || selectedIds.contains(t.id),
      )) {
        final document =
            jsonDecode(template.templateJson!) as Map<String, dynamic>;
        final metadata = document['metadata'] as Map? ?? const {};
        final canvas = Size(
          (document['designWidth'] as num? ??
                  metadata['designWidth'] as num? ??
                  500)
              .toDouble(),
          (document['designHeight'] as num? ??
                  metadata['designHeight'] as num? ??
                  500)
              .toDouble(),
        );
        final allPages = templateDocumentPages(document);
        final firstPage = _representativeSpread(allPages);
        final pages = allPages.skip(firstPage).take(2).toList();
        if (pages.length != 2) continue;
        final layers = [
          for (final page in pages)
            DataTemplateEngine.buildLayersFromJson({
              'strictLayout': true,
              'designWidth': canvas.width,
              'designHeight': canvas.height,
              'layers': page['layers'] ?? [],
            }, canvas),
        ];
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundary,
                    child: SizedBox(
                      width: 720,
                      height: 360 / canvas.aspectRatio,
                      child: ColoredBox(
                        color: Colors.white,
                        child: Row(
                          children: [
                            for (final page in layers)
                              Expanded(
                                child: FittedBox(
                                  child: TemplatePageRenderer(
                                    layers: page,
                                    width: canvas.width,
                                    height: canvas.height,
                                    designCanvasSize: canvas,
                                    preserveTypography: true,
                                    imageDecodeWidth: 720,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            Object? error;
            await precacheImage(
              (element.widget as Image).image,
              element,
              onError: (e, _) => error = e,
            );
            if (error != null) throw StateError('${template.id}: $error');
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: template.title);
        final path = 'assets/catalog_thumbnails/edition_${template.id}.png';
        await tester.runAsync(() async {
          final bitmap =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
        assets[template.id] = path;
        firstPages[template.id] = firstPage;
        debugPrint('Editorial spread: ${template.id} ${template.title}');
        await tester.pumpWidget(const SizedBox());
      }
      expect(assets.length, publishedCreationTemplates.length);
      File(
        'lib/core/templates/catalog_editorial_assets.g.dart',
      ).writeAsStringSync(
        '// Generated by test/tool/catalog_editorial_export_test.dart.\n'
        'const catalogEditorialAssets = <int, String>{\n'
        '${assets.entries.map((e) => "  ${e.key}: '${e.value}',").join('\n')}\n};\n'
        'const catalogEditorialFirstPages = <int, int>{\n'
        '${firstPages.entries.map((e) => "  ${e.key}: ${e.value},").join('\n')}\n};\n',
      );
    },
    skip: !const bool.fromEnvironment('EXPORT_EDITORIAL'),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

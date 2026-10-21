import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import '../widget/ai_album_start_step_test.dart' show wrapCreation;

Future<ui.Image> _page(
  WidgetTester tester,
  Map<String, dynamic> page,
  CollectionAspect aspect,
) async {
  final key = GlobalKey();
  final layers = DataTemplateEngine.buildLayersFromJson(page, aspect.canvas);
  expect(layers.length, (page['layers'] as List).length);
  await tester.pumpWidget(
    wrapCreation(
      Center(
        child: RepaintBoundary(
          key: key,
          child: TemplatePageRenderer(
            layers: layers,
            width: 260,
            height: 260 / aspect.canvas.aspectRatio,
            designCanvasSize: aspect.canvas,
            preserveTypography: true,
            imageDecodeWidth: 720,
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      Object? error;
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (e, _) => error = e,
      );
      expect(error, isNull);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return (await tester.runAsync(
    () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
        .toImage(),
  ))!;
}

void main() {
  testWidgets(
    'export all legacy books as native full-book contact sheets',
    (tester) async {
      final fonts =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final font in fonts) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in font['fonts'] as List) {
          loader.addFont(rootBundle.load(asset['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final output = Directory('output/premium-atelier-qa/legacy')
        ..createSync(recursive: true);
      final newIds = {
        ...AtelierEdition.values.map((e) => e.catalogId),
        ...StudioEdition.values.map((e) => e.catalogId),
      };
      final selected = const String.fromEnvironment(
        'EXPORT_LEGACY_IDS',
      ).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      expect(
        selected.difference(
          publishedCreationTemplates
              .where((t) => !newIds.contains(t.id))
              .map((t) => t.id)
              .toSet(),
        ),
        isEmpty,
      );
      final books = <Map<String, dynamic>>[];
      var renderedPages = 0;
      for (final template in publishedCreationTemplates.where(
        (t) => !newIds.contains(t.id),
      )) {
        final catalog =
            jsonDecode(template.templateJson!) as Map<String, dynamic>;
        final formats = <String, String>{};
        for (final aspect in CollectionAspect.values) {
          final document = Map<String, dynamic>.from(
            catalog['variants'][aspect.name] as Map,
          );
          final pages = templateDocumentPages(document);
          renderedPages += pages.length;
          formats[aspect.name] = 'legacy/${template.id}-${aspect.name}.png';
          if (selected.isNotEmpty && !selected.contains(template.id)) {
            expect(
              File(
                '${output.path}/${template.id}-${aspect.name}.png',
              ).existsSync(),
              true,
            );
            continue;
          }
          const margin = 28.0, gap = 24.0, tileWidth = 520.0;
          final tileHeight = 260 / aspect.canvas.aspectRatio;
          final rowHeight = tileHeight + 52;
          final tiles = 1 + (pages.length - 1) ~/ 2;
          final rows = (tiles / 3).ceil();
          const width = margin * 2 + tileWidth * 3 + gap * 2;
          final height = 84 + rows * rowHeight;
          final recorder = ui.PictureRecorder(), captures = <ui.Image>[];
          final canvas = Canvas(recorder)
            ..drawColor(const Color(0xFFF1F5F3), BlendMode.src);
          void label(String value, Offset at, double size) {
            final text = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: 'NotoSans',
                  fontSize: size,
                  color: const Color(0xFF203A2F),
                ),
              ),
            )..layout(maxWidth: width - margin * 2);
            text.paint(canvas, at);
            text.dispose();
          }

          label(
            '${template.title} / ${template.isPremium ? '유료' : '무료'} / ${aspect.name}',
            const Offset(margin, 22),
            24,
          );
          for (var tile = 0; tile < tiles; tile++) {
            final first = tile == 0 ? 0 : tile * 2 - 1;
            final at = Offset(
              margin + tile % 3 * (tileWidth + gap),
              72 + tile ~/ 3 * rowHeight,
            );
            for (var side = 0; side < (tile == 0 ? 1 : 2); side++) {
              final image = await _page(tester, pages[first + side], aspect);
              captures.add(image);
              canvas.drawImage(
                image,
                at + Offset(tile == 0 ? 130 : side * 260, 0),
                Paint(),
              );
            }
            label(
              tile == 0 ? '표지' : '$first–${first + 1}쪽',
              at + Offset(0, tileHeight + 10),
              17,
            );
          }
          final picture = recorder.endRecording();
          await tester.runAsync(() async {
            final sheet = await picture.toImage(width.ceil(), height.ceil());
            final bytes = await sheet.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '${output.path}/${template.id}-${aspect.name}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            sheet.dispose();
          });
          picture.dispose();
          for (final image in captures) {
            image.dispose();
          }
          formats[aspect.name] = 'legacy/${template.id}-${aspect.name}.png';
        }
        books.add({
          'catalogId': template.id,
          'title': template.title,
          'category': template.category,
          'tier': template.isPremium ? 'premium' : 'free',
          'innerPages': catalog['innerPageCount'],
          'formats': formats,
        });
        debugPrint('Legacy native review: ${template.title}');
      }
      await tester.pumpWidget(const SizedBox());
      expect(books, hasLength(51));
      File('output/premium-atelier-qa/legacy-data.js').writeAsStringSync(
        'const legacyCatalogReview = ${jsonEncode({'books': books, 'nativeRenderedPages': renderedPages, 'deviceOrPrintProof': false})};\n',
      );
    },
    skip: !const bool.fromEnvironment('EXPORT_LEGACY_REVIEW'),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_design.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_text_preflight.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_typography.g.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _input = String.fromEnvironment('AI_TEMPLATE_EVAL_RUN');
// Existing repository photos are local inspection material, never sent to AI.
const _photos = [
  'jeju_ocean.jpg',
  'jeju_seongsan.jpg',
  'jeju_aerial.jpg',
  'jeju_rocky_coast.jpg',
  'jeju_sunset.jpg',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'renders evaluated documents with actual fonts, photo pixels and saved layers',
    (tester) async {
      if (_input.isEmpty) return;
      final file = File(_input), directory = file.parent;
      final report =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (report['schemaVersion'] != 1 ||
          !['live', 'fixture'].contains(report['mode']))
        throw const FormatException('Invalid evaluation report');
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      final fonts = aiTemplateTypographyContract['fonts'] as Map;
      for (final entry in manifest.cast<Map>()) {
        if (!fonts.containsKey(entry['family']) &&
            entry['family'] != 'MaterialIcons')
          continue;
        final loader = FontLoader(entry['family'] as String);
        for (final font in entry['fonts'] as List) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1200, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.runAsync(() async {
        await Directory('${directory.path}/renders').create(recursive: true);
      });
      final rendered = <Map<String, Object?>>[];
      final failures = <String>[];
      for (final entry
          in (report['results'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['id'] as String;
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id))
          throw const FormatException('Invalid case id');
        if (entry['status'] != 'accepted') {
          rendered.add({'id': id, 'status': 'not_generated', 'pages': []});
          continue;
        }
        final pages = <Map<String, Object?>>[];
        final metrics = <Map<String, Object>>[];
        try {
          final brief = entry['brief'] as Map;
          final design = AiTemplateDesign.fromJson(
            Map<String, Object?>.from(entry['document'] as Map),
            brief['pageCount'] as int,
          );
          if (design.artDirection == null ||
              design.aspect.name != brief['aspect'])
            throw const FormatException('Design contract changed');
          final issues = inspectAiTemplateText(design);
          final layers = design.buildLayers();
          for (final (pageIndex, source) in layers.indexed) {
            final paths = <String, String>{};
            var photoCount = 0;
            for (final photos in [false, true]) {
              var photoIndex = pageIndex;
              final shown = source.map((layer) {
                if (!photos || layer.type != LayerType.image) return layer;
                return layer.copyWith(
                  imageUrl:
                      'asset:assets/templates/jeju_travel/images/sources/${_photos[photoIndex++ % _photos.length]}',
                );
              }).toList();
              final key = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: Center(
                      child: RepaintBoundary(
                        key: key,
                        child: TemplatePageRenderer(
                          layers: shown,
                          width: design.canvasSize.width,
                          height: design.canvasSize.height,
                          designCanvasSize: design.canvasSize,
                          preserveTypography: true,
                          showCanvasChrome: false,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.runAsync(() async {
                for (final element in find.byType(Image).evaluate()) {
                  await precacheImage((element.widget as Image).image, element);
                }
              });
              await tester.pumpAndSettle();
              final decoded = tester.widgetList<RawImage>(
                find.byType(RawImage),
              );
              photoCount = source
                  .where((l) => l.type == LayerType.image)
                  .length;
              expect(
                decoded.length,
                photos ? photoCount : 0,
                reason: '$id/$pageIndex decoded photo count',
              );
              expect(decoded.every((image) => image.image != null), isTrue);
              expect(tester.takeException(), isNull);
              final name =
                  'renders/${id}_${photos ? 'photo' : 'empty'}_$pageIndex.png';
              paths[photos ? 'photo' : 'empty'] = name;
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1.6);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '${directory.path}/$name',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            double drift = 0;
            for (final layer in source) {
              final restored = LayerExportMapper.fromJson(
                LayerExportMapper.toJson(layer, canvasSize: design.canvasSize),
                canvasSize: design.canvasSize * .8,
              );
              drift = math.max(
                drift,
                (restored.position.dx - layer.position.dx * .8).abs(),
              );
              drift = math.max(
                drift,
                (restored.position.dy - layer.position.dy * .8).abs(),
              );
              drift = math.max(
                drift,
                (restored.width - layer.width * .8).abs(),
              );
              drift = math.max(
                drift,
                (restored.height - layer.height * .8).abs(),
              );
              if (layer.type == LayerType.text) {
                expect(restored.text, layer.text);
                expect(
                  restored.textStyle!.fontFamily,
                  layer.textStyle!.fontFamily,
                );
                expect(
                  restored.textStyle!.fontWeight,
                  layer.textStyle!.fontWeight,
                );
                expect(restored.textStyle!.height, layer.textStyle!.height);
                drift = math.max(
                  drift,
                  (restored.textStyle!.fontSize! -
                          layer.textStyle!.fontSize! * .8)
                      .abs(),
                );
              }
            }
            expect(drift, lessThan(.001));
            metrics.add({
              'pageIndex': pageIndex,
              'photoCount': photoCount,
              'saveLoadMaxDrift': drift,
            });
            pages.add({
              'index': pageIndex,
              ...paths,
              'photoCount': photoCount,
              'purpose': design.pages[pageIndex].purpose,
            });
          }
          rendered.add({
            'id': id,
            'status': issues.isEmpty ? 'passed' : 'text_overflow',
            'canvas': {
              'width': design.canvasSize.width,
              'height': design.canvasSize.height,
            },
            'pages': pages,
            'textIssues': issues.map((e) => e.toJson()).toList(),
            'metrics': metrics,
            'humanVerdict': 'not_reviewed',
          });
          if (issues.isNotEmpty) failures.add('$id: text overflow');
        } catch (error) {
          rendered.add({
            'id': id,
            'status': 'render_failed',
            'pages': pages,
            'reason': error.toString(),
          });
          failures.add('$id: render failed');
        }
      }
      await tester.runAsync(() async {
        await File('${directory.path}/render.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'schemaVersion': 1,
            'runId': report['id'],
            'mode': report['mode'],
            'photoSource':
                'Local repository photos used only for render inspection; not AI-selected, not publishable assets.',
            'results': rendered,
          }),
        );
      });
      // Deliberate fixture defects must be reported, never hidden as a passing live run.
      if (report['mode'] == 'live')
        expect(failures, isEmpty, reason: failures.join('\n'));
      else {
        expect(
          rendered.singleWhere(
            (r) => r['id'] == 'fixture-font-overflow',
          )['status'],
          'text_overflow',
        );
        expect(rendered.where((r) => r['status'] == 'render_failed'), isEmpty);
      }
    },
    skip: _input.isEmpty,
  );
}

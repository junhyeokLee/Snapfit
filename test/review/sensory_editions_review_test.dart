import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _ids = [-9761, -9762];
const _export =
    bool.fromEnvironment('EXPORT_SENSORY_REVIEW') ||
    bool.fromEnvironment('EXPORT_STORE_QUALITY');
const _phase = String.fromEnvironment(
  'STORE_QUALITY_STAGE',
  defaultValue: String.fromEnvironment(
    'STORE_QUALITY_PHASE',
    defaultValue: 'after',
  ),
);
const _output = 'output/sensory-editions-20261103/templates';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Widget _page(Map<String, dynamic> source, CollectionAspect aspect) =>
    TemplatePageRenderer(
      layers: DataTemplateEngine.buildLayersFromJson(source, aspect.canvas),
      width: 500,
      height: 500 / aspect.canvas.aspectRatio,
      designCanvasSize: aspect.canvas,
      preserveTypography: true,
      normalizeToContentBounds: false,
      showCanvasChrome: false,
      imageDecodeWidth: 1200,
    );

Future<void> _capture(WidgetTester tester, Widget child, String name) async {
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      Object? failure;
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (error, _) => failure = error,
      );
      expect(failure, isNull, reason: name);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: name);
  final decoded = tester.widgetList<RawImage>(find.byType(RawImage));
  expect(decoded, isNotEmpty, reason: '$name must actually display its photos');
  expect(decoded.every((image) => image.image != null), isTrue, reason: name);
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_output/$_phase/$name.png').writeAsBytesSync(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  _PaintBinding();
  testWidgets(
    'render both new full books at all print ratios using actual photos and fonts',
    (tester) async {
      if (!_export) return;
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in manifest.cast<Map>()) {
        final loader = FontLoader(entry['family'] as String);
        for (final font in (entry['fonts'] as List).cast<Map>()) {
          loader.addFont(rootBundle.load(font['asset'] as String));
        }
        await loader.load();
      }
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        Directory('$_output/$_phase').createSync(recursive: true);
      });
      final documents = <String, dynamic>{};
      for (final id in _ids) {
        final template = publishedCreationTemplates.singleWhere(
          (t) => t.id == id,
        );
        final source =
            jsonDecode(template.templateJson!) as Map<String, dynamic>;
        documents['$id'] = source;
        for (final aspect in CollectionAspect.printable) {
          final document = Map<String, dynamic>.from(
            (source['variants'] as Map)[aspect.name] as Map,
          );
          await _capture(
            tester,
            _page(Map<String, dynamic>.from(document['cover'] as Map), aspect),
            '$id-${aspect.name}-cover',
          );
          final pages = document['pages'] as List;
          for (var spread = 0; spread < 12; spread++) {
            await _capture(
              tester,
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final index in [spread * 2, spread * 2 + 1])
                    _page(
                      Map<String, dynamic>.from(pages[index] as Map),
                      aspect,
                    ),
                ],
              ),
              '$id-${aspect.name}-spread-${spread + 1}',
            );
          }
        }
      }
      await tester.runAsync(() async {
        File(
          '$_output/$_phase/documents.json',
        ).writeAsStringSync(jsonEncode(documents));
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

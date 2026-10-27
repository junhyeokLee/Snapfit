import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Maker')
      ..addFont(rootBundle.load('assets/fonts/Maker.ttf'));
    await loader.load();
  });

  for (final width in [250.0, 500.0, 1000.0]) {
    testWidgets('preview preserves measured title tracking at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplatePageRenderer(
              width: width,
              height: width,
              designCanvasSize: const Size(500, 500),
              preserveTypography: true,
              layers: [
                LayerModel(
                  id: 'tracked-title',
                  type: LayerType.text,
                  position: const Offset(30, 30),
                  width: 400,
                  height: 110,
                  text: 'Small days,\nwell kept.',
                  textStyle: const TextStyle(
                    fontSize: 40,
                    height: 1.1,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Small days,\nwell kept.'));
      expect(text.style!.letterSpacing, -1.5 * width / 500);
      expect(text.style!.fontSize, 40 * width / 500);
      expect(text.textScaler, TextScaler.noScaling);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'actual Korean jacket stays on two lines at preview and zoom sizes',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = authoredCollections
          .singleWhere((c) => c.id == 'small-days')
          .document(CollectionAspect.square);
      final title = DataTemplateEngine.buildLayersFromJson(
        doc['cover'],
        const Size(500, 500),
      ).singleWhere((l) => l.id.endsWith('_signature_title'));
      for (final width in [250.0, 500.0, 1000.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TemplatePageRenderer(
                  layers: [title],
                  width: width,
                  height: width,
                  designCanvasSize: const Size(500, 500),
                  preserveTypography: true,
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title.text!),
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.text!.length),
        );
        expect(
          boxes
              .where((b) => b.right > b.left)
              .map((b) => (b.top * 10).round())
              .toSet(),
          hasLength(2),
          reason: 'Authored tracking must not disappear at width $width',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}

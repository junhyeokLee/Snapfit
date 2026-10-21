import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';

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
  testWidgets(
    'export the exact store application example for every atelier material',
    (tester) async {
      tester.view.physicalSize = const Size(600, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final output = Directory('output/premium-atelier-qa/materials')
        ..createSync(recursive: true);
      for (final spec in [
        ...atelierEditionDecorations,
        ...atelierWritingPapers,
      ]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: RepaintBoundary(
                key: key,
                child: MaterialApplicationPreview(
                  productKey: 'sticker:${spec.id}',
                  type: spec.category == StudioDecorationCategory.paper
                      ? '종이'
                      : '스티커',
                  material: StudioDecoration(spec: spec),
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
            if (error != null) throw StateError('${spec.id}: $error');
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: spec.id);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/${spec.id}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    skip: !const bool.fromEnvironment('EXPORT_ATELIER_MATERIALS'),
  );
}

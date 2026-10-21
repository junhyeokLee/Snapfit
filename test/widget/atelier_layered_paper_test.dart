import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/shared/widgets/atelier_layered_paper.dart';
import 'package:snap_fit/shared/widgets/studio_decoration.dart';

void main() {
  for (final spec in atelierLayeredDecorations) {
    testWidgets(
      '${spec.id}: native artwork has clean alpha and open photo windows',
      (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 320,
                  height: 320 / spec.aspectRatio,
                  child: StudioDecoration(spec: spec),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(AtelierLayeredPaper), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(double x, double y) => bytes.getUint8(
            ((y * image.height).floor() * image.width +
                        (x * image.width).floor()) *
                    4 +
                3,
          );
          var painted = 0;
          for (var i = 3; i < bytes.lengthInBytes; i += 4) {
            if (bytes.getUint8(i) > 50) painted++;
          }
          expect(painted, greaterThan(image.width * image.height * .08));
          expect(alpha(0, 0), lessThan(5));
          if (spec.id.endsWith('Mount')) {
            final window = atelierMountWindow(spec.id);
            expect(
              alpha(window.center.dx, window.center.dy),
              0,
              reason:
                  'Photographs must be visible through the real transparent opening.',
            );
            expect(alpha(.5, .055), greaterThan(100));
          } else {
            expect(alpha(.5, .5), greaterThan(100));
          }
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/widgets/atelier_edition_frame.dart';

void main() {
  for (final size in [
    const Size(220, 300),
    const Size(260, 260),
    const Size(320, 210),
  ]) {
    for (final style in [
      'atelierWeave',
      'atelierOxford',
      'atelierDeepMat',
      'atelierFolio',
    ]) {
      testWidgets('$style $size keeps frame ink out of the photograph', (
        tester,
      ) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox.fromSize(
                    size: size,
                    child: AtelierEditionFrame(
                      style: style,
                      child: const ColoredBox(color: Color(0xFFFA00C8)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final opening = AtelierEditionFrame.insets(
            style,
            size,
          ).deflateRect(Offset.zero & size);
          for (var x = opening.left.ceil() + 4; x < opening.right - 4; x += 3) {
            for (
              var y = opening.top.ceil() + 4;
              y < opening.bottom - 4;
              y += 3
            ) {
              final offset = (y * image.width + x) * 4;
              expect(bytes.sublist(offset, offset + 4), [
                250,
                0,
                200,
                255,
              ], reason: '$style photograph obscured at $x,$y');
            }
          }
          image.dispose();
        });
      });
    }
  }
}

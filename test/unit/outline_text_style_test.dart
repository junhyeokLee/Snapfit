import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/outline_text_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('paper-cut type preserves metrics and scales its neutral edge', () {
    const base = TextStyle(fontSize: 50, color: Colors.blue, height: 1.12);
    final a = paperCutTextStyle(base),
        b = paperCutTextStyle(base.copyWith(fontSize: 100));
    expect(base.shadows, isNull);
    expect(a.fontSize, base.fontSize);
    expect(a.height, base.height);
    expect(a.color, base.color);
    expect(a.shadows!.length, 21);
    expect(a.shadows!.any((s) => s.color == const Color(0xFF92293E)), false);
    for (var i = 0; i < a.shadows!.length; i++) {
      expect(b.shadows![i].offset, a.shadows![i].offset * 2);
      expect(b.shadows![i].blurRadius, a.shadows![i].blurRadius * 2);
    }
  });
  test(
    'die-cut type scales its edge without changing layout or source style',
    () {
      const base = TextStyle(fontSize: 50, color: Colors.red, height: 1.12);
      final a = stickerTextStyle(base),
          b = stickerTextStyle(base.copyWith(fontSize: 100));
      expect(base.shadows, isNull);
      expect(a.shadows!.length, 21);
      expect(a.fontSize, base.fontSize);
      expect(a.height, base.height);
      expect(a.color, base.color);
      for (var i = 0; i < a.shadows!.length; i++) {
        expect(b.shadows![i].offset, a.shadows![i].offset * 2);
        expect(a.shadows![i].blurRadius, 0);
      }
    },
  );
  test(
    'outline remains a proportional stroke without changing saved typography',
    () {
      const original = TextStyle(
        fontSize: 100,
        color: Color(0xFF982F42),
        height: 1.12,
        fontWeight: FontWeight.w800,
      );
      final outline = outlineTextStyle(original);
      expect(outline.foreground!.style, PaintingStyle.stroke);
      expect(outline.foreground!.color.toARGB32(), original.color!.toARGB32());
      expect(outline.foreground!.strokeWidth, closeTo(1.8, .001));
      expect(outline.fontSize, original.fontSize);
      expect(outline.height, original.height);
      expect(original.foreground, isNull);
      expect(
        outlineTextStyle(
          original.copyWith(fontSize: 200),
        ).foreground!.strokeWidth,
        closeTo(3.6, .001),
      );
    },
  );
  test(
    'outline paints hollow letter shapes instead of filled silhouettes',
    () async {
      Future<int> pixels(bool outline) async {
        const base = TextStyle(fontSize: 100, color: Colors.black);
        final painter = TextPainter(
          text: TextSpan(
            text: 'BOOK',
            style: outline ? outlineTextStyle(base) : base,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Offset(10, 10));
        final picture = recorder.endRecording(),
            image = await picture.toImage(400, 180);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        var count = 0;
        for (var i = 3; i < bytes.length; i += 4) {
          if (bytes[i] > 100) count++;
        }
        painter.dispose();
        picture.dispose();
        image.dispose();
        return count;
      }

      final hollow = await pixels(true), solid = await pixels(false);
      expect(hollow, greaterThan(100));
      expect(hollow, lessThan(solid * .65));
    },
  );
}

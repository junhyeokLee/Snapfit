import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Blank supports; captions are separate, editable word-art layers.
class AtelierCompositionPaper extends StatelessWidget {
  const AtelierCompositionPaper({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CompositionPaper(id),
    child: const SizedBox.expand(),
  );
}

class _CompositionPaper extends CustomPainter {
  const _CompositionPaper(this.id);
  final String id;
  @override
  void paint(Canvas c, Size s) {
    if (s.isEmpty) return;
    c.save();
    c.scale(s.width / 500);
    final h = s.height * 500 / s.width, r = Rect.fromLTWH(5, 5, 490, h - 10);
    void fill(Path p, Color color) => c.drawPath(p, Paint()..color = color);
    void line(Offset a, Offset b, Color color, [double width = 1]) =>
        c.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width,
        );
    void stroke(Path p, Color color, [double width = 1]) => c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width,
    );
    final paper = Path()..addRect(r);
    switch (id) {
      case 'atelierTitlePlate':
        fill(paper, const Color(0xFFF4F1E9));
        for (final d in [14.0, 20.0]) {
          stroke(
            Path()..addRRect(
              RRect.fromRectAndRadius(r.deflate(d), const Radius.circular(46)),
            ),
            const Color(0x88788B7C),
          );
        }
        line(Offset(210, 38), Offset(290, 38), const Color(0xFF607565));
      case 'atelierRibbonPlate':
        fill(
          Path()
            ..moveTo(5, h * .23)
            ..lineTo(70, h * .15)
            ..lineTo(80, h * .9)
            ..lineTo(5, h * .85)
            ..lineTo(28, h * .55)
            ..close(),
          const Color(0xFF6B7C75),
        );
        fill(
          Path()
            ..moveTo(495, h * .23)
            ..lineTo(430, h * .15)
            ..lineTo(420, h * .9)
            ..lineTo(495, h * .85)
            ..lineTo(472, h * .55)
            ..close(),
          const Color(0xFF6B7C75),
        );
        fill(
          Path()
            ..moveTo(48, 8)
            ..quadraticBezierTo(250, 28, 452, 8)
            ..lineTo(452, h - 26)
            ..quadraticBezierTo(250, h - 4, 48, h - 26)
            ..close(),
          const Color(0xFFADBFB4),
        );
        line(
          const Offset(56, 18),
          const Offset(56, 80),
          const Color(0x66FFFFFF),
        );
      case 'atelierBoardingStub':
        final holes = Path();
        for (var y = 8.0; y < h; y += 14) {
          holes.addOval(Rect.fromCircle(center: Offset(385, y), radius: 2.4));
        }
        for (final x in [5.0, 495.0]) {
          holes.addOval(Rect.fromCircle(center: Offset(x, h * .5), radius: 13));
        }
        fill(
          Path.combine(PathOperation.difference, paper, holes),
          const Color(0xFFE4EBD9),
        );
        line(
          const Offset(25, 46),
          const Offset(365, 46),
          const Color(0xFF516B4E),
          2,
        );
        line(Offset(25, h - 44), Offset(365, h - 44), const Color(0xFF516B4E));
        for (var i = 0; i < 18; i++) {
          line(
            Offset(402 + i * 4.1, h * .29),
            Offset(402 + i * 4.1, h * .73),
            const Color(0xFF3A4940),
            i % 3 == 0 ? 2 : .6,
          );
        }
      case 'atelierPostalBand':
        fill(paper, const Color(0xEDF4F1E8));
        c.save();
        c.clipRect(r);
        for (var x = -20.0; x < 540; x += 34) {
          line(Offset(x, 0), Offset(x + 25, h), const Color(0xB66C8498), 11);
          line(
            Offset(x + 16, 0),
            Offset(x + 41, h),
            const Color(0xB6955D69),
            6,
          );
        }
        c.restore();
        c.drawRect(
          Rect.fromLTWH(5, h * .27, 490, h * .46),
          Paint()..color = const Color(0xFFF5F3EA),
        );
      case 'atelierGridLeaf':
        final shape = Path()
          ..moveTo(5, 5)
          ..lineTo(495, 5)
          ..lineTo(495, h - 42)
          ..lineTo(452, h - 5)
          ..lineTo(5, h - 5)
          ..close();
        fill(shape, const Color(0xFFF2F3EA));
        c.save();
        c.clipPath(shape);
        for (var x = 18.0; x < 500; x += 22) {
          line(Offset(x, 0), Offset(x, h), const Color(0x33577D8C), .7);
        }
        for (var y = 16.0; y < h; y += 22) {
          line(Offset(0, y), Offset(500, y), const Color(0x33577D8C), .7);
        }
        c.restore();
        fill(
          Path()
            ..moveTo(452, h - 42)
            ..lineTo(495, h - 42)
            ..lineTo(452, h - 5)
            ..close(),
          const Color(0xFFCCD8CC),
        );
      case 'atelierArchiveSeal':
        for (final d in [8.0, 15.0, 30.0]) {
          stroke(
            Path()..addOval(r.deflate(d)),
            const Color(0xD94E6964),
            d == 15 ? 2 : .8,
          );
        }
        for (var i = 0; i < 100; i++) {
          final a = i * math.pi * 2 / 100;
          final p = Offset(
            250 + 218 * math.cos(a),
            h / 2 + (h / 2 - 27) * math.sin(a),
          );
          line(
            p,
            p + Offset(math.cos(a) * 5, math.sin(a) * 5),
            const Color(0xD94E6964),
            .7,
          );
        }
      case 'atelierColorSlips':
        fill(
          Path()
            ..moveTo(10, 16)
            ..lineTo(464, 5)
            ..lineTo(488, h - 19)
            ..lineTo(22, h - 5)
            ..close(),
          const Color(0xFFD5DBE7),
        );
        fill(
          Path()
            ..moveTo(26, 35)
            ..lineTo(490, 21)
            ..lineTo(471, h - 4)
            ..lineTo(6, h - 28)
            ..close(),
          const Color(0xFFE8DFBD),
        );
        fill(
          Path()
            ..moveTo(22, 22)
            ..lineTo(481, 40)
            ..lineTo(468, h - 22)
            ..lineTo(32, h - 9)
            ..close(),
          const Color(0xFFEAD1D1),
        );
      case 'atelierCornerBrackets':
        for (var i = 0; i < 4; i++) {
          c.save();
          c.translate(i == 1 || i == 2 ? 500 : 0, i >= 2 ? h : 0);
          c.scale(i == 1 || i == 2 ? -1 : 1, i >= 2 ? -1 : 1);
          fill(
            Path()
              ..moveTo(5, 5)
              ..lineTo(92, 5)
              ..lineTo(5, 92)
              ..close(),
            const Color(0xFF7C8EA0),
          );
          line(
            const Offset(9, 78),
            const Offset(78, 9),
            const Color(0xCCDDDEE2),
            2,
          );
          c.restore();
        }
    }
    if (id != 'atelierArchiveSeal' && id != 'atelierCornerBrackets') {
      c.save();
      c.clipRect(r);
      final random = math.Random(927);
      for (var i = 0; i < 520; i++) {
        final p = Offset(random.nextDouble() * 500, random.nextDouble() * h);
        line(p, p + const Offset(1.5, .4), const Color(0x0B384B46), .7);
      }
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_CompositionPaper old) => old.id != id;
}

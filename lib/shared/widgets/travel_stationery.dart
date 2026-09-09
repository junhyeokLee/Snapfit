import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Matte travel ephemera shared by the editor, picker and print renderer.
class TravelStationery extends StatelessWidget {
  const TravelStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TravelPaperPainter(id),
    child: const SizedBox.expand(),
  );
}

class _TravelPaperPainter extends CustomPainter {
  const _TravelPaperPainter(this.id);
  final String id;
  static const ink = Color(0xFF506B66);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Fixed material coordinates keep print detail identical at every zoom.
    const w = 300.0;
    final h = w * size.height / size.width;
    final r = Rect.fromLTWH(7, 7, w - 14, h - 14);
    final coaster = id == 'travelCafeCoaster';
    final pocket = id == 'travelDocumentPocket';
    final translucent = id == 'travelPhotoSleeve' || pocket;
    final market = id == 'travelMarketReceipt';
    var path = Path();
    if (coaster) {
      for (var i = 0; i <= 144; i++) {
        final a = i * math.pi * 2 / 144;
        final radius = 137 + math.sin(a * 24) * 1.4;
        final p = Offset(
          150 + math.cos(a) * radius,
          h / 2 + math.sin(a) * radius,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    } else if (pocket) {
      path.addRect(r);
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()
          ..addOval(Rect.fromCircle(center: Offset(150, r.top), radius: 19)),
      );
    } else if (id == 'travelStayTag') {
      path.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(46)));
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(150, 53), radius: 12)),
      );
    } else {
      final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      path.moveTo(r.left, r.top);
      for (var edge = 0; edge < 4; edge++) {
        final a = corners[edge], b = corners[(edge + 1) % 4];
        final horizontal = edge.isEven;
        final steps = ((b - a).distance / 6).round();
        for (var i = 1; i <= steps; i++) {
          final p = Offset.lerp(a, b, i / steps)!;
          final n = (id == 'travelCafeReceipt' || market) && horizontal
              ? (i.isEven ? 3.0 : -3.0)
              : math.sin(i * 3.19 + edge) * .65;
          path.lineTo(p.dx + (horizontal ? 0 : n), p.dy + (horizontal ? n : 0));
        }
      }
      path.close();
      if (id == 'travelNotebook') {
        final holes = Path();
        for (var x = 22.0; x < 290; x += 26) {
          holes.addOval(Rect.fromCircle(center: Offset(x, 16), radius: 4.5));
        }
        path = Path.combine(PathOperation.difference, path, holes);
      }
    }
    canvas.save();
    canvas.scale(size.width / w);
    if (!translucent)
      canvas.drawPath(
        path.shift(const Offset(.5, 1)),
        Paint()
          ..color = const Color(0x192D4844)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .9),
      );
    final color = switch (id) {
      'travelStayTag' => const Color(0xFFD3DFD7),
      'travelCafeReceipt' || 'travelMarketReceipt' => const Color(0xFFF6F5ED),
      'travelCafeCoaster' => const Color(0xFFE7E7DB),
      'travelPostcard' => const Color(0xFFF1F2E8),
      'travelLuggageLabel' => const Color(0xFFE0E9E2),
      'travelNotebook' => const Color(0xFFF0F3EB),
      'travelPhotoSleeve' => const Color(0x75F7F9F3),
      'travelDocumentPocket' => const Color(0xADF4F6EE),
      _ => const Color(0xFFD5E1DF),
    };
    canvas.drawPath(path, Paint()..color = color);
    canvas.save();
    canvas.clipPath(path);
    final line = Paint()
      ..color = const Color(0x705B7B74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    switch (id) {
      case 'travelDocumentPocket':
        canvas.drawPath(path, line..color = const Color(0x65758E82));
        canvas.drawPath(
          Path()
            ..moveTo(17, 9)
            ..lineTo(17, h - 15)
            ..lineTo(283, h - 15)
            ..lineTo(283, 9),
          line..color = const Color(0x40758E82),
        );
        canvas.drawRect(
          Rect.fromLTWH(7, h - 15, 286, 8),
          Paint()..color = const Color(0x36F4F6EE),
        );
        _dashes(canvas, line, Offset(26, h - 19), Offset(274, h - 19));
      case 'travelStayTag':
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(12), const Radius.circular(35)),
          line,
        );
        _text(
          canvas,
          'ROOM',
          Rect.fromLTWH(37, h * .25, 226, 30),
          19,
          center: true,
        );
        _text(
          canvas,
          '02',
          Rect.fromLTWH(30, h * .35, 240, 100),
          84,
          center: true,
          serif: true,
        );
        _text(
          canvas,
          'GUEST / KEY',
          Rect.fromLTWH(32, h * .75, 236, 24),
          13,
          center: true,
        );
      case 'travelCafeReceipt':
      case 'travelMarketReceipt':
        _text(
          canvas,
          market ? 'MARKET' : 'CAFE',
          const Rect.fromLTWH(28, 36, 244, 35),
          26,
          center: true,
          serif: true,
        );
        _text(
          canvas,
          market ? 'DAILY GOODS / NO. 02' : 'TABLE 02 / TWO GUESTS',
          const Rect.fromLTWH(28, 85, 244, 17),
          9,
          center: true,
        );
        _dashes(canvas, line, Offset(28, h * .25), Offset(272, h * .25));
        for (final row
            in (market
                    ? [('FRUIT', '1'), ('FLOWERS', '1')]
                    : [('COFFEE', '2'), ('PASTRY', '1')])
                .indexed) {
          final y = h * .34 + row.$1 * h * .10;
          _text(canvas, row.$2.$1, Rect.fromLTWH(30, y, 180, 22), 12);
          _text(canvas, row.$2.$2, Rect.fromLTWH(244, y, 25, 22), 12);
        }
        _dashes(canvas, line, Offset(28, h * .59), Offset(272, h * .59));
        _text(canvas, 'DATE', Rect.fromLTWH(30, h * .65, 210, 18), 8);
        canvas.drawLine(Offset(30, h * .74), Offset(270, h * .74), line);
        _barcode(canvas, Rect.fromLTWH(67, h * .83, 166, h * .065));
      case 'travelCafeCoaster':
        for (final radius in [122.0, 114.0, 79.0]) {
          canvas.drawCircle(Offset(150, h / 2), radius, line);
        }
        _text(
          canvas,
          'CAFE',
          Rect.fromLTWH(48, h / 2 - 24, 204, 48),
          37,
          center: true,
          serif: true,
        );
        _text(
          canvas,
          'POUR DEUX',
          Rect.fromLTWH(60, h / 2 + 31, 180, 20),
          9,
          center: true,
        );
      case 'travelPostcard':
        _text(
          canvas,
          'POST CARD',
          const Rect.fromLTWH(25, 22, 180, 22),
          13,
          serif: true,
        );
        canvas.drawLine(Offset(153, 58), Offset(153, h - 24), line);
        _dashes(canvas, line, const Offset(238, 23), const Offset(278, 23));
        canvas.drawRect(const Rect.fromLTWH(238, 23, 40, 47), line);
        for (var row = 0; row < 3; row++) {
          final y = h * .52 + row * h * .14;
          canvas.drawLine(Offset(174, y), Offset(273, y), line);
        }
      case 'travelLuggageLabel':
        canvas.drawRect(r.deflate(8), line);
        for (final x in [58.0, 235.0]) {
          _dashes(canvas, line, Offset(x, 12), Offset(x, h - 12));
        }
        _text(
          canvas,
          '02',
          Rect.fromLTWH(15, h * .3, 36, 34),
          27,
          serif: true,
          center: true,
        );
        _text(
          canvas,
          'BAGGAGE / RETURN',
          Rect.fromLTWH(73, h * .2, 150, 16),
          8,
        );
        _barcode(canvas, Rect.fromLTWH(77, h * .48, 144, h * .26));
        _text(
          canvas,
          '02',
          Rect.fromLTWH(244, h * .33, 33, 28),
          18,
          serif: true,
          center: true,
        );
      case 'travelNotebook':
        for (var y = 65.0; y < h - 25; y += 28) {
          canvas.drawLine(
            Offset(26, y),
            Offset(274, y),
            line..color = const Color(0x305B7B74),
          );
        }
        canvas.drawLine(
          const Offset(47, 40),
          Offset(47, h - 13),
          line..color = const Color(0x50899481),
        );
      case 'travelPhotoSleeve':
        canvas.drawRect(r.deflate(4), line..color = const Color(0x4098A29C));
        canvas.drawLine(Offset(7, h * .28), Offset(293, h * .28), line);
        canvas.drawPath(
          Path()
            ..moveTo(7, 7)
            ..lineTo(150, h * .27)
            ..lineTo(293, 7),
          line,
        );
        canvas.drawLine(
          Offset(21, h * .29),
          Offset(21, h - 12),
          line..color = const Color(0x2598A29C),
        );
      case 'travelContourSlip':
        canvas.save();
        canvas.scale(1, h / 366);
        for (var row = 0; row < 20; row++) {
          final y = -100.0 + row * 24;
          canvas.drawPath(
            Path()
              ..moveTo(-10, y)
              ..cubicTo(160, y + 20, 30, y + 150, 166, y + 154)
              ..cubicTo(220, y + 157, 253, y + 113, 315, y + 175),
            line
              ..color = const Color(0x665C8481)
              ..strokeWidth = row % 4 == 0 ? 1 : .55,
          );
        }
        _text(canvas, 'COAST / 01', const Rect.fromLTWH(29, 322, 160, 17), 9);
        canvas.restore();
    }
    // Fine deterministic fibers stay matte and do not shimmer while dragging.
    final random = math.Random(91);
    final fiber = Paint()..strokeWidth = .38;
    for (var i = 0; i < w * h / 95; i++) {
      final x = random.nextDouble() * w, y = random.nextDouble() * h;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 1.7, y + .3),
        fiber
          ..color = i.isEven
              ? const Color(0x30FFFFFF)
              : const Color(0x09516B65),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  void _dashes(Canvas c, Paint p, Offset a, Offset b) {
    final length = (b - a).distance;
    for (var d = 0.0; d < length; d += 7) {
      c.drawLine(
        Offset.lerp(a, b, d / length)!,
        Offset.lerp(a, b, math.min(d + 3, length) / length)!,
        p,
      );
    }
  }

  void _barcode(Canvas c, Rect r) {
    final paint = Paint()..color = const Color(0x90506B66);
    for (var i = 0; i < 45; i++) {
      paint.strokeWidth = r.width / 100 * (i % 3 == 0 ? 1.3 : .55);
      final x = r.left + r.width * i / 45;
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), paint);
    }
  }

  void _text(
    Canvas c,
    String value,
    Rect r,
    double size, {
    bool center = false,
    bool serif = false,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: ink,
          fontSize: size,
          fontFamily: serif ? 'Cormorant Garamond' : 'NotoSans',
          height: 1,
          letterSpacing: 0,
        ),
      ),
      maxLines: 1,
      textAlign: center ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: r.width, maxWidth: r.width);
    p.paint(c, r.topLeft);
    p.dispose();
  }

  @override
  bool shouldRepaint(_TravelPaperPainter oldDelegate) => oldDelegate.id != id;
}

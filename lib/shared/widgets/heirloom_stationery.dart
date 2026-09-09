import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Category-specific matte paper goods, shared with the real album editor.
class HeirloomStationery extends StatelessWidget {
  const HeirloomStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeirloomPainter(id),
    child: const SizedBox.expand(),
  );
}

class _HeirloomPainter extends CustomPainter {
  const _HeirloomPainter(this.id);
  final String id;
  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    const w = 300.0;
    final h = w * size.height / size.width;
    final rect = Rect.fromLTWH(7, 7, 286, h - 14);
    var edge = Path();
    if (id == 'heirloomVowSeal') {
      for (var i = 0; i <= 160; i++) {
        final a = i * math.pi * 2 / 160;
        final r = 133 + 2.4 * math.sin(a * 11) + 1.2 * math.cos(a * 7);
        final p = Offset(150 + math.cos(a) * r, h / 2 + math.sin(a) * r);
        if (i == 0) {
          edge.moveTo(p.dx, p.dy);
        } else {
          edge.lineTo(p.dx, p.dy);
        }
      }
      edge.close();
    } else if (id == 'heirloomPetTag') {
      edge
        ..moveTo(48, 7)
        ..lineTo(252, 7)
        ..lineTo(293, 64)
        ..lineTo(293, h - 24)
        ..quadraticBezierTo(293, h - 7, 276, h - 7)
        ..lineTo(24, h - 7)
        ..quadraticBezierTo(7, h - 7, 7, h - 24)
        ..lineTo(7, 64)
        ..close();
      edge = Path.combine(
        PathOperation.difference,
        edge,
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(150, 39), radius: 9)),
      );
    } else {
      edge.moveTo(7, 7);
      for (var x = 7.0; x <= 293; x += 2) {
        edge.lineTo(x, 7 + math.sin(x * 1.8) * .7);
      }
      edge.lineTo(293, h - 7);
      for (var x = 293.0; x >= 7; x -= 2) {
        edge.lineTo(x, h - 7 + math.sin(x * 1.2) * .9);
      }
      edge.close();
      if (id == 'heirloomCinemaStub') {
        edge = Path.combine(
          PathOperation.difference,
          edge,
          Path()
            ..addOval(Rect.fromCircle(center: Offset(7, h / 2), radius: 13))
            ..addOval(Rect.fromCircle(center: Offset(293, h / 2), radius: 13)),
        );
      }
    }
    c.save();
    c.scale(size.width / w);
    c.drawPath(
      edge.shift(const Offset(1, 1.2)),
      Paint()
        ..color = const Color(0x1837473F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    final stock = switch (id) {
      'heirloomLibraryCard' => const Color(0xFFE5EBE8),
      'heirloomGrowthRuler' => const Color(0xFFEBE7D9),
      'heirloomCinemaStub' => const Color(0xFFEBDADF),
      'heirloomPetTag' => const Color(0xFFD7DFBD),
      'heirloomVowSeal' => const Color(0xFFE2DEC8),
      'heirloomVowPlaceCard' => const Color(0xFFF8F7ED),
      _ => const Color(0xFFF3F2E9),
    };
    c.drawPath(edge, Paint()..color = stock);
    c.save();
    c.clipPath(edge);
    final pen = Paint()
      ..color = const Color(0x60627D70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65;
    switch (id) {
      case 'heirloomVowEnvelope':
        c.drawPath(
          Path()
            ..moveTo(8, 8)
            ..lineTo(150, h * .58)
            ..lineTo(292, 8)
            ..close(),
          Paint()..color = const Color(0xFFE8ECE1),
        );
        c.drawPath(
          Path()
            ..moveTo(8, h - 8)
            ..lineTo(118, h * .47)
            ..quadraticBezierTo(150, h * .36, 182, h * .47)
            ..lineTo(292, h - 8),
          pen,
        );
        c.drawPath(
          Path()
            ..moveTo(8, 8)
            ..lineTo(150, h * .58)
            ..lineTo(292, 8),
          pen,
        );
        c.drawLine(
          Offset(14, h - 14),
          Offset(286, h - 14),
          pen..color = const Color(0x30627D70),
        );
      case 'heirloomVowPlaceCard':
        c.drawRect(rect.deflate(7), pen..color = const Color(0x40627D70));
        c.drawLine(
          Offset(16, h * .48),
          Offset(284, h * .48),
          pen..color = const Color(0x20627D70),
        );
        c.drawLine(Offset(22, h - 20), Offset(74, h - 20), pen);
        c.drawLine(Offset(226, h - 20), Offset(278, h - 20), pen);
      case 'heirloomVowSeal':
        c.drawCircle(
          Offset(150, h / 2),
          109,
          pen
            ..color = const Color(0x807E896C)
            ..strokeWidth = 1.6,
        );
        c.drawCircle(
          Offset(150, h / 2 + 1.5),
          104,
          pen
            ..color = const Color(0x70FFFFFF)
            ..strokeWidth = 1.4,
        );
        c.drawPath(
          Path()
            ..moveTo(139, 184)
            ..quadraticBezierTo(159, 133, 141, 82),
          pen
            ..color = const Color(0x80808C70)
            ..strokeWidth = 2,
        );
        for (var i = 0; i < 5; i++) {
          final y = 99 + i * 16.0;
          c.save();
          c.translate(i.isEven ? 136 : 157, y);
          c.rotate(i.isEven ? -.65 : .65);
          c.drawOval(
            const Rect.fromLTWH(-8, -16, 16, 30),
            Paint()..color = const Color(0x557E896C),
          );
          c.restore();
        }
        label(
          c,
          'TOGETHER',
          Rect.fromLTWH(70, h - 100, 160, 22),
          13,
          center: true,
        );
      case 'heirloomVowPaper':
        c.drawRect(rect.deflate(10), pen);
        c.drawRect(rect.deflate(14), pen..color = const Color(0x30627D70));
        for (var y = 22.0; y < h - 20; y += 15) {
          c.drawLine(
            Offset(11, y),
            Offset(17, y + 4),
            pen..color = const Color(0x90627D70),
          );
        }
        label(c, 'VOWS', Rect.fromLTWH(42, 28, 216, 22), 13, center: true);
        c.drawLine(Offset(70, h - 51), Offset(230, h - 51), pen);
      case 'heirloomLibraryCard':
        label(
          c,
          'COLLECTION / RECORD',
          const Rect.fromLTWH(26, 30, 248, 22),
          11,
        );
        c.drawLine(const Offset(24, 72), const Offset(276, 72), pen);
        for (var y = 104.0; y < h - 27; y += 30) {
          c.drawLine(
            Offset(24, y),
            Offset(276, y),
            pen..color = const Color(0x40627D70),
          );
        }
        c.drawLine(const Offset(64, 72), Offset(64, h - 24), pen);
      case 'heirloomGrowthRuler':
        c.drawLine(Offset(18, h - 25), Offset(282, h - 25), pen);
        for (var i = 0; i <= 24; i++) {
          final x = 18 + i * 11.0;
          c.drawLine(
            Offset(x, h - 25),
            Offset(x, h - (i.isEven ? 37 : 31)),
            pen,
          );
          if (i.isEven)
            label(
              c,
              '${i ~/ 2}',
              Rect.fromLTWH(x - 8, 17, 16, 14),
              8,
              center: true,
            );
        }
      case 'heirloomTableLinen':
        final stripe = Paint()..color = const Color(0x22516B58);
        for (var x = 10.0; x < 300; x += 24) {
          c.drawRect(Rect.fromLTWH(x, 0, 10, h), stripe);
        }
        for (var y = 8.0; y < h; y += 24) {
          c.drawRect(Rect.fromLTWH(0, y, 300, 10), stripe);
        }
        for (var x = 10.0; x < 296; x += 3.3) {
          c.drawLine(
            Offset(x, 0),
            Offset(x, h),
            pen
              ..color = const Color(0x186C8172)
              ..strokeWidth = .35,
          );
        }
        c.drawRect(
          rect.deflate(5),
          pen
            ..color = const Color(0x70526958)
            ..strokeWidth = .65,
        );
      case 'heirloomCinemaStub':
        c.drawRect(rect.deflate(7), pen);
        for (var y = 10.0; y < h - 10; y += 5) {
          c.drawLine(Offset(224, y), Offset(224, y + 2), pen);
        }
        label(c, 'CINEMA / TWO SEATS', Rect.fromLTWH(27, 24, 185, 17), 10);
        label(c, 'ADMIT TWO', Rect.fromLTWH(27, h * .55, 185, 23), 17);
        label(c, '02', Rect.fromLTWH(232, h * .38, 48, 28), 26, center: true);
      case 'heirloomPetTag':
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(23, 79, 254, h - 109),
            const Radius.circular(8),
          ),
          pen,
        );
        label(
          c,
          'WALK / TOGETHER',
          Rect.fromLTWH(36, 108, 228, 18),
          12,
          center: true,
        );
        c.drawLine(Offset(61, h * .59), Offset(239, h * .59), pen);
        label(
          c,
          'EVERY DAY',
          Rect.fromLTWH(38, h - 83, 224, 18),
          10,
          center: true,
        );
    }
    final random = math.Random(131);
    for (var i = 0; i < w * h / 80; i++) {
      final p = Offset(random.nextDouble() * w, random.nextDouble() * h);
      c.drawLine(
        p,
        p + const Offset(1.9, .35),
        Paint()
          ..color = i.isEven ? const Color(0x22FFFFFF) : const Color(0x1051665B)
          ..strokeWidth = .38,
      );
    }
    c.restore();
    c.restore();
  }

  void label(
    Canvas c,
    String value,
    Rect r,
    double size, {
    bool center = false,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: size,
          letterSpacing: 0,
          height: 1,
          color: const Color(0xFF52665D),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: center ? TextAlign.center : TextAlign.left,
    )..layout(minWidth: r.width, maxWidth: r.width);
    text.paint(c, r.topLeft);
    text.dispose();
  }

  @override
  bool shouldRepaint(_HeirloomPainter old) => old.id != id;
}

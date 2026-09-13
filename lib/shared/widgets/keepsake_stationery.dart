import 'dart:math' as math;
import 'package:flutter/material.dart';

class KeepsakeStationery extends StatelessWidget {
  const KeepsakeStationery({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KeepsakePainter(id),
    child: const SizedBox.expand(),
  );
}

class _KeepsakePainter extends CustomPainter {
  const _KeepsakePainter(this.id);
  final String id;
  static const ink = Color(0xFF3A5550);

  @override
  void paint(Canvas c, Size size) {
    if (size.isEmpty) return;
    const w = 300.0;
    final h = w * size.height / size.width;
    final r = Rect.fromLTWH(7, 7, w - 14, h - 14);
    c.save();
    c.scale(size.width / w);
    final stock = switch (id) {
      'materialVellumBand' => const Color(0xB8EDF0EC),
      'materialContourMap' => const Color(0xFFE5EEEB),
      'materialTransitPunch' => const Color(0xFFD1E0E9),
      'materialSpecimenPocket' => const Color(0xFFE0E4DD),
      'materialScallopNote' => const Color(0xFFF3DFD9),
      'materialMonthDial' => const Color(0xFFECE8BF),
      'materialRecipeFoldout' => const Color(0xFFF1F2E9),
      'materialTicketDuo' => const Color(0xFFEFDEE3),
      'materialAirLetter' => const Color(0xFFF2EDF1),
      'materialWalkLedger' => const Color(0xFFDEE6CD),
      'materialNamePatch' => const Color(0xFFE3E8D7),
      _ => const Color(0xFFF7F6F0),
    };
    Path outline;
    if (id == 'materialMonthDial') {
      outline = Path()..addOval(r);
    } else if (id == 'materialNamePatch') {
      outline = Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(h * .33)));
    } else if (id == 'materialTransitPunch') {
      outline = Path()
        ..moveTo(40, 7)
        ..lineTo(260, 7)
        ..lineTo(293, 45)
        ..lineTo(293, h - 7)
        ..lineTo(7, h - 7)
        ..lineTo(7, 45)
        ..close();
      outline = Path.combine(
        PathOperation.difference,
        outline,
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(150, 39), radius: 11)),
      );
    } else if (id == 'materialScallopNote') {
      outline = Path()..moveTo(16, 10);
      for (var x = 16.0; x < 280; x += 22) {
        outline.quadraticBezierTo(x + 11, 1, x + 22, 10);
      }
      outline.lineTo(290, h - 14);
      for (var x = 290.0; x > 20; x -= 22) {
        outline.quadraticBezierTo(x - 11, h - 1, x - 22, h - 14);
      }
      outline.close();
    } else {
      outline = _deckle(r);
    }
    c.drawPath(outline, Paint()..color = stock);
    c.save();
    c.clipPath(outline);
    _grain(c, r, id.hashCode);
    switch (id) {
      case 'materialBlindEmboss':
        final frame = RRect.fromRectAndRadius(
          r.deflate(17),
          const Radius.circular(54),
        );
        c.drawRRect(
          frame.shift(const Offset(0, 1.3)),
          pen(const Color(0xFFC6CCBE), 1),
        );
        c.drawRRect(frame, pen(Colors.white, 1.5));
        c.drawRRect(frame.deflate(5), pen(const Color(0xFFD8DCD1), .6));
        for (var i = 0; i < 8; i++) {
          c.save();
          c.translate(150, 57);
          c.rotate(i * math.pi / 4);
          c.drawOval(
            const Rect.fromLTWH(-3, -18, 6, 14),
            pen(const Color(0xFFCDD3C7), .7),
          );
          c.restore();
        }
        _rule(c, 56, h - 55, 188, const Color(0xFFD1D8CD));
        _label(
          c,
          '날짜',
          Rect.fromLTWH(57, h - 45, 90, 17),
          9,
          const Color(0xFF819080),
        );
      case 'materialVellumBand':
        for (final x in [44.0, 256.0]) {
          c.drawLine(
            Offset(x, 7),
            Offset(x, h - 7),
            pen(const Color(0x4F7A968D), .7),
          );
          c.drawLine(
            Offset(x + 2, 7),
            Offset(x + 2, h - 7),
            pen(const Color(0x88FFFFFF), 1),
          );
        }
        for (var x = 12.0; x < 290; x += 7) {
          c.drawLine(
            Offset(x, 15),
            Offset(x + 3, 15),
            pen(const Color(0x54829389), .6),
          );
          c.drawLine(
            Offset(x, h - 15),
            Offset(x + 3, h - 15),
            pen(const Color(0x54829389), .6),
          );
        }
      case 'materialContourMap':
        for (var j = 0; j < 26; j++) {
          final p = Path();
          for (var x = -10.0; x <= 310; x += 3) {
            final y =
                13 +
                j * 8 +
                math.sin(x / 43 + j * .18) * 15 +
                math.cos(x / 21 - j * .14) * 7;
            if (x == -10) {
              p.moveTo(x, y);
            } else {
              p.lineTo(x, y);
            }
          }
          c.drawPath(
            p,
            pen(
              j % 5 == 0 ? const Color(0x95799B87) : const Color(0x43799B87),
              j % 5 == 0 ? .8 : .5,
            ),
          );
        }
        final route = Path()
          ..moveTo(46, h * .8)
          ..cubicTo(110, h * .7, 146, h * .15, 263, h * .3);
        c.drawPath(route, pen(const Color(0xFFB37263), 1.1));
        for (final point in [Offset(46, h * .8), Offset(263, h * .3)]) {
          c.drawCircle(point, 3.5, Paint()..color = const Color(0xFFF8F6E9));
          c.drawCircle(point, 3.5, pen(const Color(0xFFB37263), .9));
        }
        c.drawRect(
          Rect.fromLTWH(16, 16, 82, 30),
          Paint()..color = const Color(0xDDE5EEEB),
        );
        _label(c, 'FIELD / 01', const Rect.fromLTWH(23, 22, 70, 20), 9, ink);
        _fold(c, h, [100, 200]);
      case 'materialTransitPunch':
        c.drawOval(
          Rect.fromCircle(center: const Offset(150, 39), radius: 18),
          pen(const Color(0xFF72949D), 1.3),
        );
        _label(c, '여행 기록', const Rect.fromLTWH(35, 85, 230, 35), 19, ink);
        _label(
          c,
          'DEPARTURE / ARRIVAL',
          const Rect.fromLTWH(35, 131, 230, 20),
          9,
          ink,
        );
        for (var i = 0; i < 4; i++) {
          final y = 188 + i * (h - 245) / 4;
          _label(
            c,
            ['날짜', '출발', '도착', '기록'][i],
            Rect.fromLTWH(35, y, 70, 20),
            11,
            ink,
          );
          _rule(c, 35, y + 29, 230, const Color(0x658DA5A9));
        }
        for (var x = 26.0; x < 280; x += 9) {
          c.drawCircle(
            Offset(x, h - 40),
            1.3,
            Paint()..color = const Color(0xFFA9BFC4),
          );
        }
      case 'materialSpecimenPocket':
        c.drawRect(
          Rect.fromLTWH(24, 18, 252, h - 38),
          Paint()..color = const Color(0xFFF6F4EB),
        );
        _label(c, '모아 둔 것들', const Rect.fromLTWH(42, 37, 216, 26), 13, ink);
        for (var y = 83.0; y < h - 50; y += 24) {
          _rule(c, 42, y, 216, const Color(0x30838E88));
        }
        final flap = Path()
          ..moveTo(7, h * .39)
          ..lineTo(150, h * .65)
          ..lineTo(293, h * .39)
          ..lineTo(293, h - 7)
          ..lineTo(7, h - 7)
          ..close();
        c.drawPath(flap, Paint()..color = const Color(0xE1B7C7B8));
        c.drawPath(flap, pen(const Color(0x5580967F), .8));
        _label(
          c,
          'ARCHIVE',
          Rect.fromLTWH(27, h - 44, 170, 20),
          9,
          const Color(0xFF5B7561),
        );
      case 'materialIndexTabs':
        for (var i = 0; i < 4; i++) {
          final tab = Rect.fromLTWH(
            13 + i * 68.0,
            14 + i * 5.0,
            65,
            h - 38 - i * 5,
          );
          final color = [
            const Color(0xFFB9C9C5),
            const Color(0xFFF5F1DF),
            const Color(0xFFD6ABA1),
            const Color(0xFF464C4B),
          ][i];
          c.drawRRect(
            RRect.fromRectAndRadius(tab, const Radius.circular(6)),
            Paint()..color = color,
          );
          c.drawLine(
            Offset(tab.left + 5, tab.bottom - 14),
            Offset(tab.right - 5, tab.bottom - 14),
            pen(const Color(0x44797F75), .8),
          );
          _label(
            c,
            '0${i + 1}',
            Rect.fromLTWH(tab.left + 12, tab.top + 9, 42, 22),
            13,
            i == 3 ? Colors.white : ink,
          );
        }
      case 'materialScallopNote':
        c.drawRect(r.deflate(23), pen(const Color(0xFFCB9B91), .6));
        _label(
          c,
          '처음 남긴 기록',
          const Rect.fromLTWH(41, 36, 218, 29),
          14,
          const Color(0xFF9C6B68),
        );
        for (var y = 97.0; y < h - 42; y += 27) {
          _rule(c, 42, y, 216, const Color(0x50BB8B85));
        }
      case 'materialMonthDial':
        c.drawCircle(
          const Offset(150, 150),
          131,
          pen(const Color(0xFFABA66F), .8),
        );
        c.drawCircle(
          const Offset(150, 150),
          92,
          pen(const Color(0x75AAA67C), .8),
        );
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6 - math.pi / 2;
          final p = Offset(150 + math.cos(a) * 111, 150 + math.sin(a) * 111);
          _label(
            c,
            '${i + 1}',
            Rect.fromCenter(center: p, width: 28, height: 22),
            13,
            ink,
            centered: true,
          );
          c.drawLine(
            Offset(
              150 + math.cos(a + math.pi / 12) * 98,
              150 + math.sin(a + math.pi / 12) * 98,
            ),
            Offset(
              150 + math.cos(a + math.pi / 12) * 123,
              150 + math.sin(a + math.pi / 12) * 123,
            ),
            pen(const Color(0x75AAA67C), .6),
          );
        }
        _label(
          c,
          '첫 열두 달',
          const Rect.fromLTWH(84, 135, 132, 30),
          16,
          ink,
          centered: true,
        );
      case 'materialRecipeFoldout':
        _fold(c, h, [114]);
        c.drawRect(
          Rect.fromLTWH(15, 15, 91, h - 30),
          Paint()..color = const Color(0xFFD8E0D0),
        );
        _label(c, '재료', const Rect.fromLTWH(28, 28, 62, 24), 13, ink);
        _label(c, '함께 만든 한 접시', const Rect.fromLTWH(130, 25, 147, 27), 13, ink);
        for (var y = 69.0; y < h - 25; y += 23) {
          c.drawCircle(Offset(28, y - 3), 2, pen(const Color(0xFF7E957D), .6));
          _rule(c, 38, y, 53, const Color(0x7095A28E));
          _rule(c, 130, y, 147, const Color(0x50808D76));
        }
      case 'materialCrossStitchBand':
        for (var x = 14.0; x < 289; x += 8) {
          for (final y in [19.0, h - 22]) {
            c.drawLine(
              Offset(x, y),
              Offset(x + 4, y + 4),
              pen(const Color(0xFFAE7565), .9),
            );
            c.drawLine(
              Offset(x + 4, y),
              Offset(x, y + 4),
              pen(const Color(0xFFAE7565), .9),
            );
          }
        }
        c.drawRect(
          Rect.fromLTWH(7, h / 2 - 3, 286, 6),
          Paint()..color = const Color(0x558197A9),
        );
      case 'materialTicketDuo':
        c.drawRect(
          Rect.fromLTWH(7, 7, 286, 28),
          Paint()..color = const Color(0xFF704C58),
        );
        for (final x in [27.0, 166.0]) {
          _label(
            c,
            'ADMIT ONE',
            Rect.fromLTWH(x, 13, 110, 17),
            9,
            const Color(0xFFF4E7E7),
          );
          _label(
            c,
            x == 27 ? '01' : '02',
            Rect.fromLTWH(x, 50, 105, 45),
            32,
            const Color(0xFF704C58),
          );
          _rule(c, x, h - 44, 106, const Color(0x88906B78));
          _label(
            c,
            'ROW  /  SEAT',
            Rect.fromLTWH(x, h - 33, 106, 15),
            8,
            const Color(0xFF704C58),
          );
        }
        for (var y = 10.0; y < h - 8; y += 7) {
          c.drawCircle(
            Offset(150, y),
            1,
            Paint()..color = const Color(0xFF9B7F87),
          );
        }
      case 'materialAirLetter':
        for (var x = -10.0; x < 310; x += 22) {
          for (final y in [7.0, h - 16]) {
            c.drawPath(
              Path()
                ..moveTo(x, y)
                ..lineTo(x + 12, y)
                ..lineTo(x + 20, y + 9)
                ..lineTo(x + 8, y + 9)
                ..close(),
              Paint()
                ..color = (x ~/ 22).isEven
                    ? const Color(0xFFB38388)
                    : const Color(0xFF84939E),
            );
          }
        }
        for (final y in [h / 3, h * 2 / 3]) {
          c.drawLine(
            Offset(7, y),
            Offset(293, y),
            pen(const Color(0x338D838E), 1),
          );
          c.drawLine(
            Offset(7, y + 1),
            Offset(293, y + 1),
            pen(const Color(0xCCFFFFFF), 1),
          );
        }
        _label(
          c,
          '너에게',
          const Rect.fromLTWH(36, 42, 220, 24),
          16,
          const Color(0xFF876776),
        );
        for (var y = 101.0; y < h - 51; y += 28) {
          _rule(c, 36, y, 228, const Color(0x358F7E8A));
        }
      case 'materialWalkLedger':
        c.drawRect(
          Rect.fromLTWH(7, 7, 26, h - 14),
          Paint()..color = const Color(0xFF899C78),
        );
        for (var y = 25.0; y < h - 15; y += 24) {
          c.drawOval(
            Rect.fromCenter(center: Offset(20, y), width: 8, height: 3),
            Paint()..color = const Color(0xFFEBEBDD),
          );
        }
        _label(c, '오늘의 산책', const Rect.fromLTWH(48, 33, 218, 33), 18, ink);
        _label(
          c,
          '날짜         날씨         함께 걸은 길',
          const Rect.fromLTWH(48, 82, 218, 18),
          9,
          ink,
        );
        for (var y = 124.0; y < h - 31; y += 28) {
          _rule(c, 48, y, 218, const Color(0x618B9D7D));
        }
      case 'materialNamePatch':
        final inset = RRect.fromRectAndRadius(
          r.deflate(10),
          Radius.circular(h * .27),
        );
        for (final metric in (Path()..addRRect(inset)).computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 6) {
            c.drawPath(
              metric.extractPath(d, math.min(d + 3.2, metric.length)),
              pen(const Color(0xFF758663), 1.5),
            );
          }
        }
        _label(
          c,
          '이름',
          Rect.fromLTWH(40, h * .32, 80, 18),
          10,
          const Color(0xFF7C8B6D),
        );
        _rule(c, 40, h * .64, 220, const Color(0xFF9AAA88));
    }
    c.restore();
    c.restore();
  }

  static Paint pen(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static void _rule(Canvas c, double x, double y, double w, Color color) =>
      c.drawLine(Offset(x, y), Offset(x + w, y), pen(color, .65));
  static Path _deckle(Rect r) {
    final p = Path()..moveTo(r.left, r.top);
    for (var x = r.left; x <= r.right; x += 2) {
      p.lineTo(x, r.top + math.sin(x * 1.7) * .7);
    }
    p.lineTo(r.right, r.bottom);
    for (var x = r.right; x >= r.left; x -= 2) {
      p.lineTo(x, r.bottom + math.sin(x * 1.3) * .8);
    }
    return p..close();
  }

  static void _grain(Canvas c, Rect r, int seed) {
    final random = math.Random(seed);
    for (var i = 0; i < r.width * r.height / 55; i++) {
      final p = Offset(
        r.left + random.nextDouble() * r.width,
        r.top + random.nextDouble() * r.height,
      );
      c.drawLine(
        p,
        p + Offset(.5 + random.nextDouble(), .4),
        pen(i.isEven ? const Color(0x22FFFFFF) : const Color(0x0E526554), .3),
      );
    }
  }

  static void _fold(Canvas c, double h, List<double> xs) {
    for (final x in xs) {
      c.drawLine(
        Offset(x, 7),
        Offset(x, h - 7),
        pen(const Color(0x25909A8B), 1),
      );
      c.drawLine(
        Offset(x + 1.5, 7),
        Offset(x + 1.5, h - 7),
        pen(const Color(0xACFFFFFF), 1),
      );
    }
  }

  static void _label(
    Canvas c,
    String value,
    Rect r,
    double size,
    Color color, {
    bool centered = false,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: size,
          height: 1.2,
          color: color,
          letterSpacing: 0,
        ),
      ),
      maxLines: 1,
      ellipsis: '',
      textDirection: TextDirection.ltr,
      textAlign: centered ? TextAlign.center : TextAlign.left,
    )..layout(maxWidth: r.width);
    t.paint(c, Offset(r.left, r.top + (r.height - t.height) / 2));
    t.dispose();
  }

  @override
  bool shouldRepaint(_KeepsakePainter old) => old.id != id;
}
